#!/usr/bin/env bash
# Unit test for the adaptive CLI planner (no cluster).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/skill/scripts" "$TMP/skill/references/generated"
cp "$ROOT/common/pipeline_adapt.py" "$TMP/skill/scripts/"
cp "$ROOT/rnaseq-pipeline-lab/references/adapt_spec.json" "$TMP/skill/references/"
printf 'LAB_CLUSTER_USER=tester\nLAB_CODE_RNA=/code\n' > "$TMP/cfg.env"
cat > "$TMP/skill/references/code_snapshot.json" <<'EOF'
{"pipeline":"rnaseq","code_root":"/code","git_head":"x","files":{},"capabilities":{"run":["--input-dir","--outdir","--genome","--resume"],"downstream":["--outdir","--genome"]}}
EOF
fail=0
out="$(LAB_CONFIG="$TMP/cfg.env" python3 "$TMP/skill/scripts/pipeline_adapt.py" plan run --fastq /a --results /b --species hg38 --resume)"; rc=$?
[[ "$rc" == 0 ]] && echo "ok   plan rc" || { echo "FAIL plan rc=$rc"; fail=1; }
printf '%s\n' "$out" | grep -q -- '--input-dir /a' && echo "ok   alias fastq" || { echo "FAIL alias fastq"; fail=1; }
printf '%s\n' "$out" | grep -q -- '--outdir /b' && echo "ok   alias results" || { echo "FAIL alias results"; fail=1; }
printf '%s\n' "$out" | grep -q -- '--genome hg38' && echo "ok   alias species" || { echo "FAIL alias species"; fail=1; }
printf '%s\n' "$out" | grep -q -- '--resume' && echo "ok   boolean" || { echo "FAIL boolean"; fail=1; }
LAB_CONFIG="$TMP/cfg.env" python3 "$TMP/skill/scripts/pipeline_adapt.py" plan run --fastq /a --results /b --species hg38 --padj 0.05 >/dev/null 2>&1; rc=$?
[[ "$rc" == 2 ]] && echo "ok   invalid action role rc=2" || { echo "FAIL invalid role rc=$rc"; fail=1; }
LAB_CONFIG="$TMP/cfg.env" python3 "$TMP/skill/scripts/pipeline_adapt.py" plan run --fastq /a --results /b >/dev/null 2>&1; rc=$?
[[ "$rc" == 2 ]] && echo "ok   missing required rc=2" || { echo "FAIL missing required rc=$rc"; fail=1; }
exit "$fail"
