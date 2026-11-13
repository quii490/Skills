#!/usr/bin/env bash
# Install the shared lab skills into a DSH/Codex skills directory.
#
# Example:
#   bash install.sh --cluster-user hujiatong --target ~/.dsh/skills
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.dsh/skills"
CLUSTER_USER=""
NAMESPACE=""
MAINTAINER="machicheng"
WORK_ROOT=""
RESULTS_ROOT=""
SCRATCH=""
POD=""
FORCE=0
NO_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --cluster-user) CLUSTER_USER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --maintainer) MAINTAINER="$2"; shift 2 ;;
    --work-root) WORK_ROOT="$2"; shift 2 ;;
    --results-root) RESULTS_ROOT="$2"; shift 2 ;;
    --scratch) SCRATCH="$2"; shift 2 ;;
    --pod) POD="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-config) NO_CONFIG=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown option $1" >&2; exit 2 ;;
  esac
done

[[ -n "$CLUSTER_USER" || "$NO_CONFIG" == "1" ]] || {
  echo "ERROR: --cluster-user is required (your med.thu account, e.g. hujiatong)" >&2; exit 2; }
TARGET="${TARGET/#\~/$HOME}"
NAMESPACE="${NAMESPACE:-zhaoslab-$CLUSTER_USER}"
WORK_ROOT="${WORK_ROOT:-/home/$CLUSTER_USER/lab-work}"
RESULTS_ROOT="${RESULTS_ROOT:-/home/$CLUSTER_USER/lab-results}"
SCRATCH="${SCRATCH:-/tmp/$CLUSTER_USER}"
CONFIG="$HOME/.config/med-lab/config.env"

mkdir -p "$TARGET"
for s in med-pod-exec-lab rnaseq-pipeline-lab cutrun-pipeline-lab atacseq-pipeline-lab med-gpu-job-lab; do
  if [[ -e "$TARGET/$s" && "$FORCE" != "1" ]]; then
    echo "ERROR: $TARGET/$s exists; use --force to replace" >&2; exit 1
  fi
  rm -rf "$TARGET/$s"
  cp -R "$HERE/$s" "$TARGET/$s"
  mkdir -p "$TARGET/$s/scripts" "$TARGET/$s/references/generated"
  cp "$HERE/common/lab_config.sh" "$HERE/common/check_remote_env.sh" "$TARGET/$s/scripts/"
  if [[ "$s" == *-pipeline-lab ]]; then
    cp "$HERE/common/pipeline_adapt.py" "$TARGET/$s/scripts/"
    cp "$HERE/common/shared-pitfalls.md" "$TARGET/$s/references/"
  fi
  chmod 755 "$TARGET/$s/scripts/"*.sh "$TARGET/$s/scripts/"*.py 2>/dev/null || true
done

if [[ "$NO_CONFIG" != "1" ]]; then
  mkdir -p "$(dirname "$CONFIG")"; chmod 700 "$(dirname "$CONFIG")" 2>/dev/null || true
  if [[ -f "$CONFIG" && "$FORCE" != "1" ]]; then
    echo "KEEP existing config: $CONFIG"
  else
    cat > "$CONFIG" <<EOF
# Shared lab skills config (mode 600). Edit if paths change.
LAB_CLUSTER_USER=$CLUSTER_USER
LAB_NAMESPACE=$NAMESPACE
LAB_MAINTAINER=$MAINTAINER
LAB_CODE_ROOT=/home/$MAINTAINER
LAB_CONDA_ROOT=/home/$MAINTAINER/.conda/envs
LAB_REFERENCE=/home/$MAINTAINER/reference
LAB_WORK_ROOT=$WORK_ROOT
LAB_RESULTS_ROOT=$RESULTS_ROOT
LAB_SCRATCH=$SCRATCH
LAB_POD=$POD
LAB_EXEC_SU=1
EOF
    chmod 600 "$CONFIG"
    echo "WROTE $CONFIG"
  fi
  REG="$HOME/.config/med-lab/registry.env"
  if [[ ! -f "$REG" ]]; then
    cat > "$REG" <<EOF
# Your own base.med.thu Harbor account (mode 600); fill the password before GPU jobs.
LAB_REGISTRY_USER=$CLUSTER_USER
LAB_REGISTRY_PASSWORD=
EOF
    chmod 600 "$REG"
    echo "WROTE $REG (fill LAB_REGISTRY_PASSWORD)"
  else
    echo "KEEP existing $REG"
  fi
fi

echo "INSTALLED to $TARGET"
echo "Next:"
echo "  bash $TARGET/med-pod-exec-lab/scripts/check_remote_env.sh"
echo "  python3 $TARGET/rnaseq-pipeline-lab/scripts/pipeline_adapt.py check"
