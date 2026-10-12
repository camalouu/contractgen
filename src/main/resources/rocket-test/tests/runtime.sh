#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
LIB=$(realpath "${1:?compiled library required}")
OUT=${2:-/tmp/contract-rocket-runtime-test}
g++ -std=c++17 -O2 -pthread -I"$HERE/../verif" "$HERE/runtime_test.cpp" "$LIB" -Wl,-rpath,"$(dirname "$LIB")" -o "$OUT"
"$OUT"
