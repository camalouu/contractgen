#!/usr/bin/env python3
"""Create same-flow result or testcase sets from contract result evidence.

The filter processes one test result at a time, so multi-gigabyte input files do
not need to fit in memory. The source is never modified; output is committed
atomically after the complete JSON document has been written successfully.

Testcase JSON does not contain runtime control-flow evidence. To filter a
testcase array, pass the corresponding result JSON with ``--results``; entries
are matched by their testcase ``index``.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


STRUCTURAL_OBSERVATIONS = {
    "FORMAT",
    "OPCODE",
    "FUNCT3",
    "FUNCT7",
    "IS_BRANCH",
}

CONTROL_FLOW_OBSERVATIONS = {
    "BRANCH_TAKEN",
    "NEW_PC",
}


class JsonStream:
    def __init__(self, source, chunk_size: int = 1024 * 1024):
        self.source = source
        self.chunk_size = chunk_size
        self.buffer = ""
        self.position = 0
        self.eof = False

    def compact(self) -> None:
        if self.position:
            self.buffer = self.buffer[self.position :]
            self.position = 0

    def read_more(self) -> bool:
        self.compact()
        chunk = self.source.read(self.chunk_size)
        if not chunk:
            self.eof = True
            return False
        self.buffer += chunk
        return True

    def ensure(self) -> bool:
        return self.position < len(self.buffer) or self.read_more()

    def skip_whitespace(self) -> None:
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace():
                self.position += 1
            if self.position < len(self.buffer) or not self.read_more():
                return

    def decode_value(self, decoder: json.JSONDecoder):
        while True:
            self.skip_whitespace()
            try:
                value, end = decoder.raw_decode(self.buffer, self.position)
                self.position = end
                return value
            except json.JSONDecodeError:
                if self.eof or not self.read_more():
                    raise


def reject_reason(result: dict, exclude_control_flow: bool = False) -> str | None:
    if result.get("distinguishingInstructions"):
        return "distinguishingInstructions"
    for observation in result.get("observations", []):
        if observation.get("observation") in STRUCTURAL_OBSERVATIONS:
            return "structuralObservation"
        if exclude_control_flow and observation.get("observation") in CONTROL_FLOW_OBSERVATIONS:
            return "controlFlowObservation"
    return None


def process_results(
    source_path: Path,
    output_path: Path | None,
    progress_every: int,
    exclude_control_flow: bool,
) -> tuple[dict[str, int], set[int], set[int]]:
    temporary_path = output_path.with_name(output_path.name + ".tmp") if output_path else None
    counts = {
        "input": 0,
        "kept": 0,
        "rejectedDistinguishingInstructions": 0,
        "rejectedStructuralObservation": 0,
        "rejectedControlFlowObservation": 0,
    }
    rejected_indices: set[int] = set()
    seen_indices: set[int] = set()
    decoder = json.JSONDecoder()
    output = None

    try:
        with source_path.open("r", encoding="utf-8") as source:
            if temporary_path is not None:
                output = temporary_path.open("w", encoding="utf-8")
            stream = JsonStream(source)
            marker = '"testResults"'
            prefix = ""
            while marker not in prefix:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    raise ValueError("Input has no testResults field")
                prefix += chunk
                if len(prefix) > 8 * 1024 * 1024:
                    raise ValueError("testResults field was not found near the beginning of the input")

            marker_position = prefix.index(marker)
            array_position = prefix.find("[", marker_position + len(marker))
            if array_position < 0:
                while array_position < 0:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        raise ValueError("testResults is not an array")
                    prefix += chunk
                    array_position = prefix.find("[", marker_position + len(marker))

            if output is not None:
                output.write(prefix[: array_position + 1])
            stream.buffer = prefix[array_position + 1 :]
            first_output = True

            while True:
                stream.skip_whitespace()
                if not stream.ensure():
                    raise ValueError("Unexpected end of file inside testResults")
                current = stream.buffer[stream.position]
                if current == "]":
                    stream.position += 1
                    break
                if current == ",":
                    stream.position += 1

                result = stream.decode_value(decoder)
                if not isinstance(result, dict):
                    raise ValueError("testResults contains a non-object value")

                counts["input"] += 1
                index = result.get("index")
                if not isinstance(index, int):
                    raise ValueError("test result has no integer index")
                seen_indices.add(index)
                reason = reject_reason(result, exclude_control_flow)
                if reason is None:
                    if output is not None:
                        if not first_output:
                            output.write(",")
                        output.write("\n    ")
                        json.dump(result, output, separators=(",", ":"))
                    first_output = False
                    counts["kept"] += 1
                else:
                    rejected_indices.add(index)
                    if reason == "distinguishingInstructions":
                        counts["rejectedDistinguishingInstructions"] += 1
                    elif reason == "structuralObservation":
                        counts["rejectedStructuralObservation"] += 1
                    else:
                        counts["rejectedControlFlowObservation"] += 1

                if progress_every and counts["input"] % progress_every == 0:
                    print(
                        f"processed={counts['input']} kept={counts['kept']} "
                        f"rejected={counts['input'] - counts['kept']}",
                        flush=True,
                    )

            if output is not None:
                output.write("\n  ]")
                output.write(stream.buffer[stream.position :])
                while True:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        break
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
                output.close()
                output = None

        if temporary_path is not None and output_path is not None:
            os.replace(temporary_path, output_path)
    except BaseException:
        if output is not None:
            output.close()
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()
        raise

    return counts, rejected_indices, seen_indices


def filter_results(
    source_path: Path,
    output_path: Path,
    progress_every: int,
    exclude_control_flow: bool = False,
) -> dict[str, int]:
    counts, _, _ = process_results(
        source_path, output_path, progress_every, exclude_control_flow
    )
    return counts


def filter_testcases(
    source_path: Path,
    output_path: Path,
    rejected_indices: set[int],
    seen_indices: set[int],
    progress_every: int,
) -> dict[str, int]:
    temporary_path = output_path.with_name(output_path.name + ".tmp")
    counts = {
        "input": 0,
        "kept": 0,
        "rejectedByResult": 0,
        "withoutResult": 0,
    }
    decoder = json.JSONDecoder()

    try:
        with source_path.open("r", encoding="utf-8") as source, temporary_path.open(
            "w", encoding="utf-8"
        ) as output:
            stream = JsonStream(source)
            stream.skip_whitespace()
            if not stream.ensure() or stream.buffer[stream.position] != "[":
                raise ValueError("Testcase input must be a top-level JSON array")
            stream.position += 1
            output.write("[")
            first_output = True

            while True:
                stream.skip_whitespace()
                if not stream.ensure():
                    raise ValueError("Unexpected end of testcase array")
                current = stream.buffer[stream.position]
                if current == "]":
                    stream.position += 1
                    break
                if current == ",":
                    stream.position += 1

                testcase = stream.decode_value(decoder)
                if not isinstance(testcase, dict):
                    raise ValueError("Testcase array contains a non-object value")
                index = testcase.get("index")
                if not isinstance(index, int):
                    raise ValueError("testcase has no integer index")

                counts["input"] += 1
                if index in rejected_indices:
                    counts["rejectedByResult"] += 1
                else:
                    if index not in seen_indices:
                        counts["withoutResult"] += 1
                    if not first_output:
                        output.write(",")
                    output.write("\n  ")
                    json.dump(testcase, output, separators=(",", ":"))
                    first_output = False
                    counts["kept"] += 1

                if progress_every and counts["input"] % progress_every == 0:
                    print(
                        f"processed={counts['input']} kept={counts['kept']} "
                        f"rejected={counts['rejectedByResult']}",
                        flush=True,
                    )

            stream.skip_whitespace()
            if stream.ensure():
                raise ValueError("Unexpected content after testcase array")
            output.write("\n]\n")
            output.flush()
            os.fsync(output.fileno())

        os.replace(temporary_path, output_path)
    except BaseException:
        if temporary_path.exists():
            temporary_path.unlink()
        raise

    return counts


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Stream-filter a contract results JSON, or filter a testcase array "
            "using a corresponding result JSON as runtime evidence."
        )
    )
    parser.add_argument("source", type=Path, help="input results object or testcase array JSON")
    parser.add_argument("output", type=Path, help="new filtered JSON")
    parser.add_argument(
        "--results",
        type=Path,
        help="runtime result JSON used when source is a testcase array",
    )
    parser.add_argument(
        "--exclude-control-flow",
        action="store_true",
        help="also reject results containing BRANCH_TAKEN or NEW_PC",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=100_000,
        help="print progress after this many input results; use 0 to disable",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="replace the output if it already exists",
    )
    args = parser.parse_args()

    if args.source.resolve() == args.output.resolve():
        raise ValueError("Source and output paths must differ")
    if args.output.exists() and not args.force:
        raise FileExistsError(f"Output already exists: {args.output}; pass --force to replace it")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.source.open("r", encoding="utf-8") as source:
        first = ""
        while not first:
            first = source.read(1)
            if not first:
                raise ValueError("Input JSON is empty")
            if first.isspace():
                first = ""

    if first == "{":
        if args.results is not None:
            raise ValueError("--results is only valid when source is a testcase array")
        counts = filter_results(
            args.source,
            args.output,
            args.progress_every,
            args.exclude_control_flow,
        )
    elif first == "[":
        if args.results is None:
            raise ValueError(
                "Filtering testcase JSON requires --results with runtime evidence"
            )
        _, rejected_indices, seen_indices = process_results(
            args.results,
            None,
            args.progress_every,
            args.exclude_control_flow,
        )
        counts = filter_testcases(
            args.source,
            args.output,
            rejected_indices,
            seen_indices,
            args.progress_every,
        )
    else:
        raise ValueError("Input must be a JSON object or array")
    print(json.dumps(counts, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
