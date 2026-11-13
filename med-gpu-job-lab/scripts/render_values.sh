#!/usr/bin/env bash
# Render the shared GPU values template with the caller's registry credentials
# and per-user paths. Prints only the output path; never prints secrets.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
TEMPLATE="$SKILL_DIR/assets/gpu_job.yaml"
OUT=""
NAME=""
USER_NAME=""
ENV_FILE="${LAB_REGISTRY_ENV:-$HOME/.config/med-lab/registry.env}"
CLEANUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --env) ENV_FILE="$2"; shift 2 ;;
    --cleanup) CLEANUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown option $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$CLEANUP" ]]; then rm -f -- "$CLEANUP"; exit 0; fi
# shellcheck source=lab_config.sh
source "$HERE/lab_config.sh" || exit 1
USER_NAME="${USER_NAME:-$LAB_CLUSTER_USER}"
[[ -f "$TEMPLATE" ]] || { echo "ERROR: template not found: $TEMPLATE" >&2; exit 2; }
[[ -f "$ENV_FILE" ]] || { echo "ERROR: registry env not found: $ENV_FILE" >&2; exit 2; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${LAB_REGISTRY_PASSWORD:?LAB_REGISTRY_PASSWORD missing in $ENV_FILE}"
LAB_REGISTRY_USER="${LAB_REGISTRY_USER:-$USER_NAME}"
NAME="${NAME:-lab-$USER_NAME-$(date +%Y%m%d-%H%M%S)}"
[[ -z "$OUT" ]] && OUT="$(mktemp "${TMPDIR:-/tmp}/med-gpu-values.XXXXXX")"

LAB_USER="$USER_NAME" LAB_NAME="$NAME" LAB_RUSER="$LAB_REGISTRY_USER" \
LAB_RPASS="$LAB_REGISTRY_PASSWORD" python3 - "$TEMPLATE" "$OUT" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
repl = {
    "__LAB_CONTAINER_NAME__": os.environ["LAB_NAME"],
    "__LAB_REGISTRY_USER__": os.environ["LAB_RUSER"],
    "__LAB_REGISTRY_PASSWORD__": os.environ["LAB_RPASS"],
    "__LAB_USER__": os.environ["LAB_USER"],
}
for k, v in repl.items():
    s = s.replace(k, json.dumps(v)[1:-1])
open(dst, "w").write(s)
os.chmod(dst, 0o600)
PY
echo "$OUT"
