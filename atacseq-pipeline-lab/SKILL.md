---
name: atacseq-pipeline-lab
description: "共享版 med.thu bulk ATAC-seq 流程：使用维护者只读代码与 conda 环境，输出/work 写到你自己的 /home/你的账号；支持 FASTQ 全流程、只跑下游、preset 模块、QC 和验收。Run the med.thu ATAC-seq pipeline with shared read-only code/env and per-user outputs. 不适用于 CUT&RUN 或 RNA-seq。"
---

# ATAC-seq pipeline (shared)

维护者的 `/home/machicheng/ATAC-seq/pipeline_final` 与 conda 环境只读；结果写自己的目录。

> 路径约定：下面用 `$SKROOT` 表示 skill 安装根。DSH 是 `$HOME/.dsh/skills`，Codex 是 `$HOME/.codex/skills`；先 `export SKROOT=...`。

## 0. 使用前

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
python3 $SKROOT/atacseq-pipeline-lab/scripts/pipeline_adapt.py check
```

全 PASS + drift `OK` 再继续；`DRIFT` 时先 `refresh` 看 `references/generated/help.txt`。

## 0.1 自适应命令（推荐）

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
PROJ=my_atac
RES="$LAB_RESULTS_ROOT/$PROJ/results"; WORK="$LAB_WORK_ROOT/$PROJ"
CMD=$(python3 $SKROOT/atacseq-pipeline-lab/scripts/pipeline_adapt.py plan init \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/atac \
  --outdir "$RES" --species hg38)
lab_exec -- "$CMD"
# 编辑 samplesheet/contrasts 后：
CMD=$(python3 $SKROOT/atacseq-pipeline-lab/scripts/pipeline_adapt.py plan run \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/atac \
  --outdir "$RES" --species hg38 --preset quick --resume --background)
lab_exec -- "$CMD"
```

`plan` 先比对代码 hash（变更则自动 refresh），再按当前 help 解析 `--outdir`、`--preset` 等角色；下游用 `plan downstream --outdir "$RES" --species hg38 --levels both`。

## 1. 目录与环境

```bash
PROJ=my_atac
RES="$LAB_RESULTS_ROOT/$PROJ/results"
WORK="$LAB_WORK_ROOT/$PROJ"
mkdir -p "$RES" "$WORK"
export TMPDIR="$LAB_SCRATCH/$PROJ"
export NXF_HOME="$LAB_WORK_ROOT/nextflow"
export PATH="$(dirname "$LAB_NEXTFLOW"):$LAB_CONDA_BIN:$LAB_CHIPSEQ_ENV/bin:$PATH"
```

## 2. FASTQ → 全流程

```bash
cd "$LAB_CODE_ATAC"

# 1) 设计文件
bash run_auto_atacseq.sh --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/atac \
  --species hg38 --outdir "$RES" --init-only
# 编辑 $RES/_automation/inputs/{samplesheet.csv,contrasts.csv}
# 2) 正式（quick 先试；standard 含 HOMER；full 最慢）
bash run_auto_atacseq.sh --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/atac \
  --species hg38 --outdir "$RES" --preset quick \
  --background --resume --max-cpus 24 --max-memory "120 GB"
```

`--preset` 决定模块；`--run-motif true|false` 等显式开关优先于 preset。先跑 quick 确认链路，再按需要 standard/full。

## 3. 只重跑下游（自己的结果）

```bash
bash run_auto_atacseq.sh --mode downstream --outdir "$RES" --species hg38 --levels both

# 或参数更全的 wrapper
bash scripts/run_atac_downstream_only.sh --result-dir "$RES" --species hg38 --levels both \
  --output-layout standard --label-top-n 40
```

`--mode downstream` 会写 `$RES/08_downstream`；不要指向维护者目录。

## 4. 下游输入是维护者的结果（只读）

下游会写 `<results>/08_downstream`。要用维护者的结果，先把需要的 stage 目录复制/软链到自己的 `RES`，再跑下游；不要原地写。

## 5. 验收

- `00_refcheck/refcheck.ok`；
- `03_qc/qc_pass_fail.tsv`：样本级 PASS/WARN/FAIL；
- `08_downstream/{peak_level,bin_level}/downstream.ok`；
- `QC_REPORT.md`、`pipeline_report.html`；
- `--init-only`/design 未完成时 exit 0/3 的语义不同，必须读日志。

## 权限与坑

- 只读代码/conda/参考；不要 `conda install`，不要写 `__pycache__`。
- `TMPDIR`/`NXF_HOME` 指自己目录；launch 目录不要共用。
- ATAC resume：launch 目录按 outdir 固定，`-name` 每次唯一；不要用别人的 outdir。
- QC FAIL 是样本级，不是流程失败。
- 维护者代码更新后 `pipeline_adapt.py refresh`，用 `plan` 重新生成命令；新 flag 用 `--extra` 透传。

## 参考

- [references/pipeline-contract.md](references/pipeline-contract.md)
- [references/shared-pitfalls.md](references/shared-pitfalls.md)
- `references/generated/help.txt`（由 `pipeline_adapt.py refresh` 生成）
