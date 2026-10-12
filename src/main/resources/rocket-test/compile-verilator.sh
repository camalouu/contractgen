#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
SOURCE_DIR=$(realpath "${1:?source directory required}")
mkdir -p "${2:?output directory required}"
OUT_DIR=$(realpath "$2")
if [[ ! -f "$SOURCE_DIR/generated/ContractRocket.sv" ]]; then
  echo 'Rocket generated RTL is missing; run regenerate.sh with Mill 0.11.12 and firtool 1.62.0.' >&2
  exit 1
fi
(cd "$SOURCE_DIR" && sha256sum --check generated.sha256)
RTL_FILES=()
while read -r digest file; do
  if [[ ! $digest =~ ^[[:xdigit:]]{64}$ || ! $file =~ ^generated/[[:alnum:]_]+\.(sv|v)$ ]]; then
    echo "Invalid Rocket RTL manifest entry: $file" >&2
    exit 1
  fi
  RTL_FILES+=("$SOURCE_DIR/$file")
done < "$SOURCE_DIR/generated.sha256"
# The raw RF probe includes Rocket's provisional mul/div write. Diagnostics
# consume the completion write selected by the core's late-write arbiter.
# Change only this observation assignment in a disposable copy, not core logic.
python3 - "$SOURCE_DIR/generated/Rocket.sv" "$OUT_DIR/Rocket-observation.sv" <<'PYTRACE'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old='assign writeback_valid_bore = rf_wen;'
assert s.count(old)==1, 'Pinned Rocket RF probe changed'
s=s.replace(old,'assign writeback_valid_bore = ll_wen | (wb_wen & ~(wb_ctrl_mul | wb_ctrl_div));')
Path(sys.argv[2]).write_text(s)
PYTRACE
for i in "${!RTL_FILES[@]}"; do
  if [[ ${RTL_FILES[$i]} == "$SOURCE_DIR/generated/Rocket.sv" ]]; then
    RTL_FILES[$i]="$OUT_DIR/Rocket-observation.sv"
  fi
done
verilator --cc --top-module ContractRocket -Wno-fatal -Wno-WIDTH \
  --threads-dpi none --x-initial 0 --x-assign 0 +define+PRINTF_COND=0 -O3 --Mdir "$OUT_DIR/obj_dir" \
  --exe "$SOURCE_DIR/verif/rocket_test_runtime.cpp" \
  -CFLAGS "-std=c++17 -O3 -fPIC -I$SOURCE_DIR/verif" -LDFLAGS '-shared -fPIC' \
  -o libcontract_rocket_test_attacker.so "${RTL_FILES[@]}"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR/obj_dir" -f VContractRocket.mk
cp "$OUT_DIR/obj_dir/libcontract_rocket_test_attacker.so" "$OUT_DIR/libcontract_rocket_test_attacker.so"
