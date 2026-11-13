#!/usr/bin/env bash
# Local regression test for the shared skill bundle (no cluster needed).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
file_mode() { if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi; }
check() { if ! printf '%s\n' "$3" | grep -q "$2"; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }

out="$(HOME="$TMP/home" bash "$ROOT/install.sh" --cluster-user tester --target "$TMP/skills" --force 2>&1)"; rc=$?
check "install rc" "INSTALLED" "$out"
check "config written" "LAB_CLUSTER_USER=tester" "$(cat "$TMP/home/.config/med-lab/config.env")"
[[ "$(file_mode "$TMP/home/.config/med-lab/config.env")" == "600" ]] && echo "ok   config mode" || { echo "FAIL config mode"; fail=1; }

for s in med-pod-exec-lab rnaseq-pipeline-lab cutrun-pipeline-lab atacseq-pipeline-lab med-gpu-job-lab; do
  [[ -f "$TMP/skills/$s/SKILL.md" ]] || { echo "FAIL missing $s"; fail=1; }
  bash -n "$TMP/skills/$s/scripts/lab_config.sh" || fail=1
done
[[ -f "$TMP/skills/rnaseq-pipeline-lab/scripts/pipeline_adapt.py" ]] || { echo "FAIL no adapter"; fail=1; }
[[ -f "$TMP/skills/med-gpu-job-lab/scripts/render_values.sh" ]] || { echo "FAIL no gpu renderer"; fail=1; }
[[ -f "$TMP/skills/rnaseq-pipeline-lab/references/shared-pitfalls.md" ]] || { echo "FAIL no pitfalls"; fail=1; }

# Optional semantic validation if skill-creator is installed.
if [[ -f "$HOME/.dsh/skills/skill-creator/scripts/quick_validate.py" ]]; then
  for s in med-pod-exec-lab rnaseq-pipeline-lab cutrun-pipeline-lab atacseq-pipeline-lab med-gpu-job-lab; do
    python3 "$HOME/.dsh/skills/skill-creator/scripts/quick_validate.py" "$TMP/skills/$s" >/dev/null || { echo "FAIL validate $s"; fail=1; }
  done
  echo "ok   quick_validate"
fi

exit "$fail"
