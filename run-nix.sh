#!/usr/bin/env bash
set -euo pipefail
repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec nix run "$repository" -- "$@"
