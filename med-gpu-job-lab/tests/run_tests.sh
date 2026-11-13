#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for t in "$HERE"/test_*.sh; do [[ -e "$t" ]] || continue; echo "== $(basename "$t")"; bash "$t" || exit 1; done
