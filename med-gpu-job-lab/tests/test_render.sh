#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
COMMON="$(cd "$ROOT/.." && pwd)/common"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
file_mode() { if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi; }
mkdir -p "$TMP/skill/scripts" "$TMP/skill/assets"
cp "$ROOT/scripts/render_values.sh" "$TMP/skill/scripts/"
cp "$COMMON/lab_config.sh" "$TMP/skill/scripts/"
cp "$ROOT/assets/gpu_job.yaml" "$TMP/skill/assets/"
cat > "$TMP/lab.env" <<EOF
LAB_CLUSTER_USER=tester
LAB_NAMESPACE=zhaoslab-tester
LAB_MAINTAINER=machicheng
LAB_WORK_ROOT=/home/tester/lab-work
LAB_RESULTS_ROOT=/home/tester/lab-results
LAB_SCRATCH=/tmp/tester
EOF
cat > "$TMP/registry.env" <<'EOF'
LAB_REGISTRY_USER=tester
LAB_REGISTRY_PASSWORD='p@ss"word'
EOF
chmod 600 "$TMP/registry.env"
out="$(LAB_CONFIG="$TMP/lab.env" bash "$TMP/skill/scripts/render_values.sh" \
  --env "$TMP/registry.env" --name test-job --user tester)"; rc=$?
[[ "$rc" == 0 && -f "$out" ]] && echo "ok   render" || { echo "FAIL render rc=$rc"; exit 1; }
[[ "$(file_mode "$out")" == "600" ]] && echo "ok   mode" || { echo "FAIL mode"; exit 1; }
! grep -q '__LAB_' "$out" && echo "ok   placeholders replaced" || { echo "FAIL placeholder"; exit 1; }
grep -q 'tester' "$out" && echo "ok   user" || { echo "FAIL user"; exit 1; }
grep -q 'test-job' "$out" && echo "ok   name" || { echo "FAIL name"; exit 1; }
bash "$TMP/skill/scripts/render_values.sh" --cleanup "$out"
[[ ! -e "$out" ]] && echo "ok   cleanup" || { echo "FAIL cleanup"; exit 1; }
echo "gpu render tests OK"
