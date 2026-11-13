#!/usr/bin/env bash
# Verify that the current user can read the maintainer's code/env/reference
# and write only to their own work/results/scratch directories.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab_config.sh
source "$HERE/lab_config.sh" || exit 1

pod="$(lab_pod)"
if [[ -z "$pod" ]]; then
  echo "ERROR: no Running pod in namespace $LAB_NAMESPACE" >&2
  echo "Check: kubectl config current-context; kubectl get pods -n $LAB_NAMESPACE" >&2
  exit 2
fi

echo "== local config"
echo "pod=$pod namespace=$LAB_NAMESPACE cluster_user=$LAB_CLUSTER_USER"
echo "code_root=$LAB_CODE_ROOT conda=$LAB_CONDA_ROOT reference=$LAB_REFERENCE"
echo "work=$LAB_WORK_ROOT results=$LAB_RESULTS_ROOT scratch=$LAB_SCRATCH"

script=$(cat <<RS
set -u
fail=0
check_r() {
  if [ -r "\$1" ]; then echo "[PASS] read  \$1"; else echo "[FAIL] read  \$1"; fail=1; fi
}
check_x() {
  if [ -x "\$1" ]; then echo "[PASS] exec  \$1"; else echo "[FAIL] exec  \$1"; fail=1; fi
}
check_w() {
  if mkdir -p "\$1" 2>/dev/null && [ -w "\$1" ]; then echo "[PASS] write \$1"; else echo "[FAIL] write \$1"; fail=1; fi
}
echo "== remote read-only"
check_r "$LAB_CODE_ROOT"
check_r "$LAB_CODE_RNA"
check_r "$LAB_CODE_CUT"
check_r "$LAB_CODE_ATAC"
check_r "$LAB_CONDA_ROOT"
check_x "$LAB_UPSTREAM_ENV/bin/STAR"
check_x "$LAB_DOWNSTREAM_ENV/bin/Rscript"
check_x "$LAB_CHIPSEQ_ENV/bin/bowtie2"
check_x "$LAB_NEXTFLOW"
if command -v conda >/dev/null 2>&1 || [ -x "$LAB_CONDA_BIN/conda" ]; then echo "[PASS] conda"; else echo "[FAIL] conda"; fail=1; fi
check_r "$LAB_REFERENCE"
check_r "$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json"
check_r "$LAB_REFERENCE/CUTnRUN/mm39_20261102_v1/reference_bundle.json"
echo "== remote writable (own only)"
check_w "$LAB_WORK_ROOT"
check_w "$LAB_RESULTS_ROOT"
check_w "$LAB_SCRATCH"
echo "== maintainer repo status (WARN only)"
for d in "$LAB_CODE_RNA" "$LAB_CODE_CUT"; do
  if git -C "\$d" rev-parse --git-dir >/dev/null 2>&1; then
    dirty=\$(git -C "\$d" status --short | wc -l)
    [ "\$dirty" -eq 0 ] && echo "[PASS] clean \$d" || echo "[WARN] dirty(\$dirty) \$d"
  fi
done
[ "\$fail" -eq 0 ] && echo "REMOTE_ENV_READY" || echo "REMOTE_ENV_FAIL"
exit "\$fail"
RS
)

out="$(lab_exec_stdin "$script" "$pod" 2>&1)"
rc=$?
printf '%s\n' "$out"
exit "$rc"
