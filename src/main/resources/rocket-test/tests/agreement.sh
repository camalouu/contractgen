#!/usr/bin/env bash
set -euo pipefail
# Built with the same patched source as the reference library.
REFERENCE=${1:?Nix Spike package directory required}
LIB=$(realpath "${2:?attacker library required}")
exec "$REFERENCE/libexec/contract-spike-rtl-agreement" "$LIB"
