#!/usr/bin/env bash
# Elaborate in a new isolated checkout. Routine builds use the checked-in output.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REV=55bcad0f59436de98ea510334121de8546b9e9d7
MILL=${MILL:-mill}
FIRTOOL=${FIRTOOL:-firtool}
command -v "$MILL" >/dev/null
command -v "$FIRTOOL" >/dev/null
"$MILL" --version | grep -q "0.11.12"
"$FIRTOOL" --version | grep -q '1.62.0'
WORK=$(mktemp -d /tmp/contract-rocket-regenerate.XXXXXX)
echo "Generator workspace: $WORK"
git clone --no-checkout https://github.com/chipsalliance/rocket-chip.git "$WORK/rocket"
git -C "$WORK/rocket" checkout --detach "$REV"
git -C "$WORK/rocket" submodule update --init --recursive --depth 1
cp "$HERE/generator/ContractRocket.scala" "$WORK/rocket/src/main/scala/ContractRocket.scala"
mkdir "$WORK/elaborated" "$WORK/generated"
(cd "$WORK/rocket" && "$MILL" -i 'rocketchip[6.7.0].run' \
  --dir "$WORK/elaborated" --top contractrocket.ContractRocket \
  --config contractrocket.ContractRocketConfig) | tee "$WORK/elaboration.log"
"$FIRTOOL" "$WORK/elaborated/ContractRocket.fir" \
  --annotation-file="$WORK/elaborated/ContractRocket.anno.json" \
  --disable-annotation-unknown --split-verilog --preserve-values=named \
  --lowering-options=disallowLocalVariables -o "$WORK/generated"
# Only publish after both stages succeed. This does not build a simulator library.
mkdir -p "$HERE/generated"
cp "$WORK/rocket/src/main/resources/vsrc/plusarg_reader.v" "$WORK/generated/"
cp "$WORK/generated/"*.sv "$WORK/generated/"*.v "$HERE/generated/"
# Derive the manifest from this elaboration only; old unlisted modules in the
# destination must never become simulator inputs after regeneration.
(cd "$WORK" && sha256sum generated/*.sv generated/*.v > "$HERE/generated.sha256")
git -C "$WORK/rocket" submodule status --recursive > "$HERE/generator/submodules.lock"
sed -n '/^CONTRACT_ROCKET_/p' "$WORK/elaboration.log" > "$HERE/generator/parameters.lock"
