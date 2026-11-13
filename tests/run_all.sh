#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for t in "$HERE"/test_*.sh; do echo "== $(basename "$t")"; bash "$t"; done
echo "== gpu render"
bash "$HERE/../med-gpu-job-lab/tests/test_render.sh"
