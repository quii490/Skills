#!/usr/bin/env bash
# Shared configuration loader for lab skills (source this file).
# Config: ~/.config/med-lab/config.env (override with LAB_CONFIG).
# Never edits the maintainer's code or environments.

LAB_CONFIG="${LAB_CONFIG:-$HOME/.config/med-lab/config.env}"
if [[ ! -f "$LAB_CONFIG" ]]; then
  echo "ERROR: lab config not found: $LAB_CONFIG" >&2
  echo "Run the installer or create it from skills-shared/README.md." >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck disable=SC1090
source "$LAB_CONFIG"

: "${LAB_CLUSTER_USER:?LAB_CLUSTER_USER is required in $LAB_CONFIG}"
LAB_NAMESPACE="${LAB_NAMESPACE:-zhaoslab-$LAB_CLUSTER_USER}"
LAB_MAINTAINER="${LAB_MAINTAINER:-machicheng}"
LAB_CODE_ROOT="${LAB_CODE_ROOT:-/home/$LAB_MAINTAINER}"
LAB_CONDA_ROOT="${LAB_CONDA_ROOT:-/home/$LAB_MAINTAINER/.conda/envs}"
LAB_REFERENCE="${LAB_REFERENCE:-/home/$LAB_MAINTAINER/reference}"
LAB_HOME="${LAB_HOME:-/home/$LAB_CLUSTER_USER}"
LAB_WORK_ROOT="${LAB_WORK_ROOT:-$LAB_HOME/lab-work}"
LAB_RESULTS_ROOT="${LAB_RESULTS_ROOT:-$LAB_HOME/lab-results}"
LAB_SCRATCH="${LAB_SCRATCH:-/tmp/$LAB_CLUSTER_USER}"
LAB_POD="${LAB_POD:-}"
LAB_KUBECTL="${LAB_KUBECTL:-kubectl}"
LAB_EXEC_SU="${LAB_EXEC_SU:-1}"

LAB_CODE_RNA="${LAB_CODE_RNA:-$LAB_CODE_ROOT/RNA-seq/Pipeline/rnaseq}"
LAB_CODE_CUT="${LAB_CODE_CUT:-$LAB_CODE_ROOT/CUTnRUN}"
LAB_CODE_ATAC="${LAB_CODE_ATAC:-$LAB_CODE_ROOT/ATAC-seq/pipeline_final}"

LAB_UPSTREAM_ENV="${LAB_UPSTREAM_ENV:-$LAB_CONDA_ROOT/rnaseq}"
LAB_DOWNSTREAM_ENV="${LAB_DOWNSTREAM_ENV:-$LAB_CONDA_ROOT/downstream}"
LAB_CHIPSEQ_ENV="${LAB_CHIPSEQ_ENV:-$LAB_CONDA_ROOT/chipseq}"
LAB_CUT_REFERENCE_BUNDLE="${LAB_CUT_REFERENCE_BUNDLE:-}"
LAB_NEXTFLOW="${LAB_NEXTFLOW:-$LAB_CODE_ROOT/softwares/nextflow}"
LAB_CONDA_BIN="${LAB_CONDA_BIN:-/miniconda3/bin}"

export LAB_CONFIG LAB_CLUSTER_USER LAB_NAMESPACE LAB_MAINTAINER LAB_CODE_ROOT
export LAB_CONDA_ROOT LAB_REFERENCE LAB_HOME LAB_WORK_ROOT LAB_RESULTS_ROOT
export LAB_SCRATCH LAB_POD LAB_KUBECTL LAB_EXEC_SU LAB_CODE_RNA LAB_CODE_CUT LAB_CODE_ATAC
export LAB_UPSTREAM_ENV LAB_DOWNSTREAM_ENV LAB_CHIPSEQ_ENV LAB_NEXTFLOW LAB_CONDA_BIN LAB_CUT_REFERENCE_BUNDLE

lab_pod() {
  if [[ -n "$LAB_POD" ]]; then echo "$LAB_POD"; return 0; fi
  local out=""
  for _ in 1 2 3; do
    out="$("$LAB_KUBECTL" get pods -n "$LAB_NAMESPACE" --request-timeout=15s \
      -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)"
    [[ -n "$out" ]] && { echo "$out"; return 0; }
    sleep 2
  done
  return 1
}

lab_exec() { # lab_exec [pod] -- command
  local pod
  if [[ "${1:-}" == "--" ]]; then
    pod="$(lab_pod)"; shift
  else
    pod="${1:-$(lab_pod)}"; shift || true
    [[ "${1:-}" == "--" ]] && shift
  fi
  [[ -n "$pod" ]] || { echo "ERROR: no Running pod in namespace $LAB_NAMESPACE" >&2; return 1; }
  if [[ "$LAB_EXEC_SU" == "1" ]]; then
    "$LAB_KUBECTL" exec "$pod" -n "$LAB_NAMESPACE" --request-timeout=60s -- \
      su - "$LAB_CLUSTER_USER" -c "$*"
  else
    "$LAB_KUBECTL" exec "$pod" -n "$LAB_NAMESPACE" --request-timeout=60s -- bash -lc "$*"
  fi
}

lab_exec_stdin() { # lab_exec_stdin <script> [pod]
  local script="$1" pod="${2:-$(lab_pod)}"
  [[ -n "$pod" ]] || { echo "ERROR: no Running pod in namespace $LAB_NAMESPACE" >&2; return 1; }
  if [[ "$LAB_EXEC_SU" == "1" ]]; then
    printf '%s' "$script" | "$LAB_KUBECTL" exec -i "$pod" -n "$LAB_NAMESPACE" --request-timeout=60s -- \
      su - "$LAB_CLUSTER_USER" -c 'bash -s'
  else
    printf '%s' "$script" | "$LAB_KUBECTL" exec -i "$pod" -n "$LAB_NAMESPACE" --request-timeout=60s -- bash -s
  fi
}
