"""Compare complete measured evidence; tied ILP solutions may choose different atoms."""
import hashlib
import json
import sys
from pathlib import Path


def normalize(value):
    if isinstance(value, dict):
        return {key: normalize(item) for key, item in sorted(value.items())}
    if isinstance(value, list):
        return sorted((normalize(item) for item in value), key=lambda item: json.dumps(item, sort_keys=True))
    return value


left, right = map(Path, sys.argv[1:])
for artifact in (left, right):
    metadata = json.loads(Path(str(artifact) + ".execution.json").read_text())
    assert metadata["executionModel"] == "rv32-v1"
    assert metadata["sha256"] == hashlib.sha256(artifact.read_bytes()).hexdigest()
assert normalize(json.loads(left.read_text())["testResults"]) == normalize(json.loads(right.read_text())["testResults"])
print("Direct synthesis and exact replay have identical per-case labels and evidence")
