#!/usr/bin/env bash
# Some launchers explicitly invoke sh or zsh instead of honoring the shebang.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Edit these shared settings, then uncomment EVERY command line in ONE block below.
# Run with: ./run-synth-strategies.sh
# All experiment commands are commented out initially.
platform="IBEX_SMALL_TEST"
# platform="CVA6_TEST"
count=100000
threads=8
seed=11
isa="BASE,M"
# isa="BASE"
contract="BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE"

platform_lower="${platform,,}"
output_root="results/${platform_lower}-strategies-${count}-seed${seed}"
common=(-p "$platform" -i "$isa" -c "$contract" -t "$threads" --disable-adaptive-skipping)
generated=(-n "$count" -s "$seed")

# 1. Current generator: existing generation behavior and defaults.
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy current \
#   --output-dir "$output_root/current"

# 3. Different programs: leakage-modifier sweeps with full-width register values.
#    Setup contributes evidence (--no-skip-init is the default here).
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy different_programs --register-values full --no-skip-init \
#   --output-dir "$output_root/different-programs"

# 4. Different programs with the legacy register-value distribution.
#    The full-width setup layout stays the same; only the value distribution changes.
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy different_programs --register-values legacy --no-skip-init \
#   --output-dir "$output_root/different-programs-legacy"

# 5. Same generated body, different initial registers. Setup evidence is skipped.
./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
  --strategy same_programs --register-values full --skip-init \
  --output-dir "$output_root/same-programs"

# 6. Coverage-guided generation: Spike feedback steers leakage targets.
#    Use a batch smaller than count to exercise feedback on a small run.
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy coverage_guided --register-values full --no-skip-init \
#   --generation-batch-size 16 \
#   --output-dir "$output_root/coverage-guided"

# 7. Random generation with the rewrite's default distributions:
#    length 20/8/1/50, register differences 1/1/0/31, mutations 1/1/0/50
#    (mean / standard deviation / minimum / maximum).
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy random --register-values full --skip-init \
#   --generation-batch-size 256 \
#   --output-dir "$output_root/random"

# 8. Random generation with fixed counts.
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy random --register-values full --skip-init \
#   --program-length 10 --register-differences 2 --instruction-modifications 1 \
#   --output-dir "$output_root/random-fixed"

# 9. Random generation with custom distributions.
# ./run-nix.sh synth_new "${common[@]}" "${generated[@]}" \
#   --strategy random --register-values full --skip-init \
#   --program-length 'mean=12,sd=3,min=4,max=24' \
#   --register-differences 'mean=2,sd=1,min=0,max=8' \
#   --instruction-modifications 'mean=2,sd=1,min=1,max=6' \
#   --output-dir "$output_root/random-distributions"

# Replay input: change this to any saved canonical JSON or rewrite JSON-lines file.
# The default below is produced by block 7.
replay_input="$output_root/random/testcases.json"

# 10. Replay the complete saved corpus with its recorded evidence policy.
#     Replay needs neither count nor seed; do not pass the generated array.
# ./run-nix.sh synth_new "${common[@]}" \
#   --strategy replay --testcases "$replay_input" --generation-batch-size 64 \
#   --output-dir "$output_root/replay"

# 11. Replay while including setup evidence. Requires a recorded setup boundary.
#     Substitute --skip-init to exclude setup instead. The new policy is saved.
# ./run-nix.sh synth_new "${common[@]}" \
#   --strategy replay --testcases "$replay_input" --no-skip-init \
#   --output-dir "$output_root/replay-include-setup"
