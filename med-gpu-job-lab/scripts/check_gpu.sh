#!/usr/bin/env bash
# Check prerequisites for the shared GPU Job skill. Read-only; submits nothing.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab_config.sh
source "$HERE/lab_config.sh" || exit 1
ENV_FILE="${LAB_REGISTRY_ENV:-$HOME/.config/med-lab/registry.env}"
fail=0
file_mode() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }
ok()   { echo "[PASS] $*"; }
bad()  { echo "[FAIL] $*"; fail=1; }
warn() { echo "[WARN] $*"; }

echo "== local"
command -v "$LAB_KUBECTL" >/dev/null 2>&1 && ok "kubectl" || bad "kubectl"
command -v helm >/dev/null 2>&1 && ok "helm" || bad "helm"
[[ -f "$ENV_FILE" ]] && ok "registry env $ENV_FILE" || bad "registry env missing: $ENV_FILE"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  [[ -n "${LAB_REGISTRY_USER:-}" ]] && ok "registry user=$LAB_REGISTRY_USER" || bad "LAB_REGISTRY_USER empty"
  [[ -n "${LAB_REGISTRY_PASSWORD:-}" ]] && ok "registry password set (not printed)" || bad "LAB_REGISTRY_PASSWORD empty"
  [[ "$(file_mode "$ENV_FILE")" == "600" ]] && ok "registry env mode 600" || warn "registry env mode is not 600"
  if [[ -n "${LAB_REGISTRY_USER:-}" && "$LAB_REGISTRY_USER" != "$LAB_CLUSTER_USER" ]]; then
    warn "registry user ($LAB_REGISTRY_USER) != cluster user ($LAB_CLUSTER_USER); job will run as registry user"
  fi
fi

echo "== cluster"
ctx="$("$LAB_KUBECTL" config current-context 2>/dev/null || true)"
[[ -n "$ctx" ]] && ok "context=$ctx" || bad "no kubectl context"
if "$LAB_KUBECTL" get namespace "$LAB_NAMESPACE" >/dev/null 2>&1; then
  ok "namespace=$LAB_NAMESPACE"
else
  bad "namespace not accessible: $LAB_NAMESPACE"
fi
if "$LAB_KUBECTL" auth can-i create jobs.batch -n "$LAB_NAMESPACE" 2>/dev/null | grep -qx yes; then
  ok "can create jobs"
else
  bad "cannot create jobs in $LAB_NAMESPACE"
fi
if helm repo list 2>/dev/null | grep -q '^med-helm'; then
  ok "helm repo med-helm"
else
  bad "helm repo med-helm missing (helm repo add med-helm http://166.111.153.65:7001)"
fi
gpu_nodes="$("$LAB_KUBECTL" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.nvidia\.com/gpu}{"\n"}{end}' 2>/dev/null | awk '$2+0>0' | wc -l | tr -d ' ')"
[[ "$gpu_nodes" -gt 0 ]] && ok "GPU nodes with capacity: $gpu_nodes" || warn "cannot read node GPU capacity (RBAC or no GPU nodes); scheduling is authoritative"

echo "== skill"
[[ -f "$HERE/../assets/gpu_job.yaml" ]] && ok "values template" || bad "values template missing"
[[ -x "$HERE/render_values.sh" ]] && ok "render_values.sh" || bad "render_values.sh not executable"

[[ "$fail" == "0" ]] && echo "GPU_ENV_READY" || echo "GPU_ENV_FAIL"
exit "$fail"
