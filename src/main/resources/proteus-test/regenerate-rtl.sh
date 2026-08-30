#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/proteus-checkout" >&2
  exit 2
fi

SOURCE_DIR=$(realpath "$1")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPECTED_COMMIT=0f489fc5cfddabca93ae01880374385fcb649660
ACTUAL_COMMIT=$(git -C "$SOURCE_DIR" rev-parse HEAD)
if [[ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]]; then
  echo "Proteus checkout is $ACTUAL_COMMIT; expected $EXPECTED_COMMIT" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cp -R "$SOURCE_DIR"/. "$WORK_DIR"/
mkdir -p "$WORK_DIR/src/main/scala/contractgen/proteus"
cp "$SCRIPT_DIR/generator/ProteusContractCore.scala" \
  "$WORK_DIR/src/main/scala/contractgen/proteus/ProteusContractCore.scala"
mkdir -p "$WORK_DIR/generated"
(
  cd "$WORK_DIR"
  sbt "runMain contractgen.proteus.ProteusContractCoreGenerator generated"
)
cp "$WORK_DIR/generated/ProteusContractCore.v" "$SCRIPT_DIR/generated/ProteusContractCore.v"
(
  cd "$SCRIPT_DIR/generated"
  sha256sum ProteusContractCore.v > ProteusContractCore.v.sha256
)
