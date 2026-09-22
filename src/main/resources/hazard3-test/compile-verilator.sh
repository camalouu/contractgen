#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
OUT_DIR="$2"
LEGACY_DIR="${CONTRACT_HAZARD3_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/hazard3}"
PROJECT_LEGACY_DIR="${CONTRACT_HAZARD3_PROJECT_RESOURCE_ROOT:-${CONTRACTGEN_RESOURCE_ROOT:-./src/main/resources}/hazard3}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

if [[ -d "$LEGACY_DIR/core" ]]; then
  CORE_ROOT="$LEGACY_DIR"
elif [[ -d "$PROJECT_LEGACY_DIR/core" ]]; then
  CORE_ROOT="$PROJECT_LEGACY_DIR"
else
  echo "Cannot find the legacy Hazard3 RTL resources." >&2
  exit 1
fi

CORE_SOURCES=(
  "$CORE_ROOT"/core/hdl/hazard3_core.v
  "$CORE_ROOT"/core/hdl/hazard3_csr.v
  "$CORE_ROOT"/core/hdl/hazard3_decode.v
  "$CORE_ROOT"/core/hdl/hazard3_frontend.v
  "$CORE_ROOT"/core/hdl/hazard3_instr_decompress.v
  "$CORE_ROOT"/core/hdl/hazard3_irq_ctrl.v
  "$CORE_ROOT"/core/hdl/hazard3_pmp.v
  "$CORE_ROOT"/core/hdl/hazard3_power_ctrl.v
  "$CORE_ROOT"/core/hdl/hazard3_regfile_1w2r.v
  "$CORE_ROOT"/core/hdl/hazard3_triggers.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_alu.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_branchcmp.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_mul_fast.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_muldiv_seq.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_onehot_encode.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_onehot_priority.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_onehot_priority_dynamic.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_priority_encode.v
  "$CORE_ROOT"/core/hdl/arith/hazard3_shift_barrel.v
)

# The historical harness was passed through sv2v, which removed permissive
# trailing commas. Feed equivalent normalized SystemVerilog directly to
# Verilator so this harness does not depend on sv2v.
mkdir -p "$OUT_DIR"/verif
for name in atk clk_sync top; do
  perl -0pe 's/,\s*\);/\n);/g' "$CORE_ROOT/verif/$name.sv" > "$OUT_DIR/verif/$name.sv"
done

VERIF_SOURCES=(
  "$OUT_DIR"/verif/atk.sv
  "$OUT_DIR"/verif/clk_sync.sv
  "$SOURCE_DIR"/verif/ctr.sv
  "$SOURCE_DIR"/verif/data_mem.sv
  "$SOURCE_DIR"/verif/control.sv
  "$SOURCE_DIR"/verif/instr_mem.sv
  "$OUT_DIR"/verif/top.sv
  "$SOURCE_DIR"/verif/hazard3_test_top.sv
)

VERILATOR_FLAGS=(
  --cc --top-module hazard3_test_top
  -DUSEVERILATOR -DRISCV_FORMAL -DHAZARD3_RVFI_STANDALONE
  -I"$CORE_ROOT"/core/hdl
  -Wno-fatal -Wno-UNOPTFLAT -Wno-INITIALDLY -Wno-LATCH -Wno-COMBDLY
  -Wno-STMTDLY -Wno-WIDTH -Wno-PINMISSING -Wno-LITENDIAN -Wno-CASEINCOMPLETE
  --threads-dpi none -O3
)

verilator "${VERILATOR_FLAGS[@]}" --Mdir "$OUT_DIR"/obj_dir_shared \
  --exe "$SOURCE_DIR"/verif/hazard3_test_runtime.cpp "$SOURCE_DIR"/verif/hazard3_test_shared.cpp \
  -CFLAGS "-std=c++17 -O3 -fPIC" -LDFLAGS "-shared -fPIC" \
  -o libcontract_hazard3_test_attacker.so "${CORE_SOURCES[@]}" "${VERIF_SOURCES[@]}"
make -j "${CONTRACT_BUILD_JOBS:-4}" -C "$OUT_DIR"/obj_dir_shared -f Vhazard3_test_top.mk libcontract_hazard3_test_attacker.so
cp "$OUT_DIR"/obj_dir_shared/libcontract_hazard3_test_attacker.so "$OUT_DIR"/libcontract_hazard3_test_attacker.so
test -f "$OUT_DIR"/libcontract_hazard3_test_attacker.so
