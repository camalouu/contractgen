# AGENTS.md

## Purpose

This repository implements a contract-synthesis toolchain for RISC-V processors. It generates paired ISA-level tests, runs them against RTL models of supported cores, extracts attacker-visible divergences via RVFI or custom extractors, and synthesizes hardware-software leakage contracts with an ILP-based updater.

The codebase is a mix of:

- Java orchestration and synthesis logic in `src/main/java/contractgen`
- RTL, harnesses, and compile scripts in `src/main/resources`
- Research notes and paper context in top-level Markdown and text files

Use this file as the default operating guide when making changes in this repo.

## What Matters Most

- Preserve the research pipeline: test generation -> simulation -> extraction -> contract update/statistics.
- Treat supported cores as first-class integration targets: Ibex, CVA6, Hazard3, Sodor 2/5, DarkRISCV 2/3.
- Prefer small, targeted changes. Full end-to-end runs are expensive and can generate very large artifacts.
- Treat Docker rebuild triggers as expensive changes. Do not casually change or delete the Dockerfile, base-image tags/digests, Compose build settings, or other files that invalidate the Docker build cache. Before making such a change, warn the user that a full Docker rebuild may be required, explain the expected cost/time, and ask for confirmation when the change is not essential. If a rebuild is required, remind the user of the exact command (for example, `docker compose build yosys` or `docker compose up --build`) and do not claim the image was rebuilt unless it was actually run.
- Do not assume generated JSON/CSV/TXT artifacts belong in version control. `.gitignore` excludes most of them.

## Key Entry Points

- `src/main/java/contractgen/Main.java`
  Picocli CLI with subcommands such as `synthesize`, `analyze`, `evaluate`, `replay`, `stats`, and export utilities.
- `src/main/java/contractgen/ContractGen.java`
  Legacy orchestration entrypoint for full configured evaluations and statistics generation.
- `src/main/java/contractgen/CONFIG.java`
  Preset experiment configurations and results directory naming.
- `src/main/java/contractgen/MARCH.java`
  Core abstraction for microarchitecture integrations.
- `src/main/java/contractgen/updater/ILPUpdater.java`
  Contract synthesis backend using OR-Tools.
- `src/main/java/contractgen/riscv/isa/contract/RISCV_OBSERVATION_TYPE.java`
  Central contract atom/observation definition point.

## Repository Map

- `src/main/java/contractgen`
  Shared abstractions such as `Contract`, `ISA`, `MARCH`, `Generator`, `Evaluator`, `Extractor`, and CLI/config code.
- `src/main/java/contractgen/riscv/isa`
  RISC-V ISA model, instructions, programs, tests, and contract types.
- `src/main/java/contractgen/riscv/isa/tests`
  Test generation strategies and testcase I/O.
- `src/main/java/contractgen/riscv/isa/extractor`
  Trace/RVFI extraction logic. Update this when adding new observations that must be recognized from traces.
- `src/main/java/contractgen/riscv/{ibex,cva6,hazard3,sodor,darkriscv}`
  Per-core Java integrations.
- `src/main/resources/<core>`
  Per-core RTL, verification harnesses, compile scripts, and simulator-specific support files.
- `src/main/resources/docker-compose.yml`
  Containerized environment for heavier runs.
- Top-level docs such as `README.md`, `GEMINI.md`, and `paper.txt`
  Project intent, methodology, and terminology.

## Working Rules

- If you change contract expressiveness, inspect all three layers:
  1. Observation/type definitions
  2. Extractor logic
  3. Tests or synthesis/statistics code that consume those observations
- If you change a core integration, verify both the Java integration class and the corresponding resource directory.
- Prefer preserving CLI behavior. This repo already has scripts and result files built around the existing commands.
- Keep new documentation grounded in the paper terminology: contract atoms, distinguishability, attacker observations, false positives, precision.

## Build And Validation

Start with the cheapest checks first.

- Build:
  `mvn clean package`
- Run tests, if present:
  `mvn test`
- Show CLI help:
  `mvn -q exec:java -Dexec.mainClass=contractgen.Main -Dexec.args='--help'`

Use heavier commands only when needed and only after checking tool availability:

- One-shot synthesis via CLI:
  `mvn -q exec:java -Dexec.mainClass=contractgen.Main -Dexec.args='synthesize ...'`
- Legacy configured run:
  `mvn -q exec:java -Dexec.mainClass=contractgen.ContractGen`

## Environment Assumptions

The Java/Maven side is straightforward; the simulation side is not. Full runs may require:

- Java 18 as configured in `pom.xml`
- Maven
- `iverilog`
- `verilator`
- `yosys`
- `sv2v`
- Docker for the containerized path

Do not claim end-to-end validation unless the required simulator/toolchain pieces were actually available and used.

## Change-Specific Guidance

### Adding a new leakage observation

- Start in `RISCV_OBSERVATION_TYPE.java`.
- Update any contract/test-result logic that depends on the new type.
- Extend the appropriate extractor so the observation can actually be surfaced from traces.
- Check whether test generation should produce programs that can distinguish the new atom.
- Verify text output/JSON output still serializes cleanly.

### Adding a new core

- Add a Java integration class under the relevant `contractgen.riscv.*` package.
- Add a matching resource directory under `src/main/resources/<core>`.
- Provide compile/simulation support scripts and verification harness files.
- Wire the core into `CONFIG.PROCESSOR` and CLI switches if needed.

### Editing test generation

- Focus on `src/main/java/contractgen/riscv/isa/tests`.
- Be careful with changes that alter testcase count, determinism, seed handling, or SP mode behavior.
- Prefer deterministic seeds when adding regression-style checks.

## Artifact Hygiene

- The repo root may contain large generated files from prior experiments. Leave unrelated artifacts alone.
- `.gitignore` excludes generated `*.json`, `*.csv`, `*.txt`, `*.vcd`, `target/`, and similar outputs.
- Put new generated results under the existing `results/...` convention unless the task explicitly requires something else.

### Large-Artifact Safety

- Check a generated artifact's size before reading or searching it.
- Do not recursively run `rg`, `grep`, or similar content searches through directories containing large generated testcase or result files. Restrict searches by path and file type, and exclude generated artifacts explicitly.
- Prefer streaming parsers and bounded-memory scripts for large JSON files. Do not load multi-gigabyte JSON into Python, `jq`, Java, or another process when a streaming calculation is sufficient.
- Put temporary filtered files, extracted samples, and one-off analysis outputs under `/tmp` unless the task explicitly requires a persistent repository artifact.
- Start with metadata, small samples, or targeted fields, and avoid printing large JSON objects or traces to the terminal.

## Practical Review Checklist

Before closing a task, check:

- Does the change fit the paper and README model of the pipeline?
- If a new observation/core path was added, are Java and resource-side changes both present?
- Did you run the lightest meaningful validation available?
- Did you avoid committing bulky generated outputs?
- Did you document any simulator/tool dependency limitations if validation was partial?
