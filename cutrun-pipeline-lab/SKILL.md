---
name: cutrun-pipeline-lab
description: "共享版 med.thu CUT&RUN/CUT&Tag/ChIP-seq 流程：使用维护者只读代码与 conda 环境，输出/work 写到你自己的 /home/你的账号；支持 FASTQ 全流程、只跑下游、峰层分析和验收。Run the med.thu CUT&RUN pipeline with shared read-only code/env and per-user outputs. 不适用于 RNA-seq 或 ATAC。"
---

# CUT&RUN pipeline (shared)

维护者的 `/home/machicheng/CUTnRUN` 与 conda 环境只读；你的结果只能写自己的目录。

> 路径约定：下面用 `$SKROOT` 表示 skill 安装根。DSH 是 `$HOME/.dsh/skills`，Codex 是 `$HOME/.codex/skills`；先 `export SKROOT=...`。

## 0. 使用前

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
python3 $SKROOT/cutrun-pipeline-lab/scripts/pipeline_adapt.py check
```

全 PASS 且 drift `OK` 再继续。`DRIFT` 时先 `refresh` 看 `references/generated/help.txt`。

## 0.1 自适应命令（推荐）

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
PROJ=my_cutrun
RES="$LAB_RESULTS_ROOT/$PROJ/results"; WORK="$LAB_WORK_ROOT/$PROJ"
# init
CMD=$(python3 $SKROOT/cutrun-pipeline-lab/scripts/pipeline_adapt.py plan init \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --outdir "$RES" --species hg38 --assay cutrun)
lab_exec -- "$CMD"
# run（核对 manifest 后）
CMD=$(python3 $SKROOT/cutrun-pipeline-lab/scripts/pipeline_adapt.py plan run \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --outdir "$RES" --species hg38 --assay cutrun \
  --reference-bundle "$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json" \
  --profile conda,par --resume --background)
lab_exec -- "$CMD"
```

`plan` 先比对代码 hash（变更则自动 refresh），再用角色别名适配当前 flag；下游用 `plan downstream --results "$RES" --species hg38 --threads 8 --peak-jobs 4 --tier standard`。

## 1. 目录与环境

```bash
PROJ=my_cutrun
RES="$LAB_RESULTS_ROOT/$PROJ/results"
WORK="$LAB_WORK_ROOT/$PROJ"
mkdir -p "$RES" "$WORK"
export TMPDIR="$LAB_SCRATCH/$PROJ"
export NXF_HOME="$LAB_WORK_ROOT/nextflow"
export PATH="$(dirname "$LAB_NEXTFLOW"):$LAB_CONDA_BIN:$LAB_CHIPSEQ_ENV/bin:$PATH"
```

## 2. FASTQ → 全流程

```bash
cd "$LAB_CODE_CUT/pipelines/chipseq_auto_nf"

# 1) manifest
bash run_auto_chipseq.sh --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --species hg38 --assay cutrun --outdir "$RES" --init-only
# 2) 人工核对 $RES/_automation/inputs/manifest.csv 的 igg/is_igg/group/replicate
# 3) preview
bash run_auto_chipseq.sh --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --species hg38 --assay cutrun --outdir "$RES" --preview
# 4) 正式
bash run_auto_chipseq.sh --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --species hg38 --assay cutrun --outdir "$RES" \
  --reference-bundle "$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json" \
  --background --resume --profile conda,par --max-cpus 24 --max-memory "120 GB"
```

不要日常用 `--skip-preflight`。preflight 报告在 `$RES/_automation/preflight_*.json`。

**固定参考包（2026-11-02 起）**：`--reference-bundle` 使用不可变 hg38/mm39 参考，推荐每次显式传，便于复现：

```bash
--reference-bundle "$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json"
# mm39: "$LAB_REFERENCE/CUTnRUN/mm39_20261102_v1/reference_bundle.json"
```

bundle JSON 内嵌绝对路径并被 sha256 锁定：不要编辑；搬家要整目录搬并保留旧路径软链。

## 3. 只重跑下游（自己的结果）

```bash
cd "$LAB_CODE_CUT/pipelines/chipseq_auto_nf"
bash run_downstream.sh --results-dir "$RES" --species hg38 \
  --threads 8 --peak-jobs 4 --resource-tier standard --resume
```

输出固定在 `$RES/09_downstream/`。`--no-resume` 强制重算。

## 4. 下游输入是维护者的结果（只读）

`run_downstream.sh` 会写 `<results>/09_downstream`，不能直接指向 `/home/machicheng`。做法：在自己的目录建镜像树（软链 `05_tracks`、`06_peaks` 等 stage 目录，只复制/重建需要的），再对镜像跑下游。不要修改维护者目录。

## 5. 验收

- `09_downstream/module_status_summary.json` 的 `counts` 与 `required_failures`；
- `run_report.html`、`qc_metrics.tsv`；
- exit 42 = SKIP；
- `status: PASS` 仍可能有 optional FAIL，必须看 counts；
- n=1 时只能说描述性结论。

## 权限与坑

- 只读 conda/代码：不要安装包、不要写 `__pycache__`。
- `TMPDIR`/`NXF_HOME` 必须指自己的目录；不要共用 `/tmp/cutrun-nextflow`。
- 多用户 pod 上不要 `pkill` 关键词，只用精确 PID。
- HOMER 需要 `PATH`+`PERL5LIB` 指向 `$LAB_CHIPSEQ_ENV/share/homer/bin`（`run_downstream` 会处理，手工直调时自己设）。
- 维护者代码更新后 `pipeline_adapt.py refresh`，用 `plan` 重新生成命令；新 flag 用 `--extra` 透传。

## 参考

- [references/pipeline-contract.md](references/pipeline-contract.md)
- [references/shared-pitfalls.md](references/shared-pitfalls.md)
- `references/generated/help.txt`（由 `pipeline_adapt.py refresh` 生成）
