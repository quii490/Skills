---
name: rnaseq-pipeline-lab
description: "共享版 med.thu bulk RNA-seq 流程：使用维护者只读的代码与 conda 环境，把结果/work 写到你自己的 /home/你的账号；支持从 FASTQ 起跑、只跑下游、续跑和验收。Run the med.thu RNA-seq pipeline with a shared read-only code/env install and per-user outputs. 不适用于 CUT&RUN（cutrun-pipeline-lab）或 ATAC（atacseq-pipeline-lab）。"
---

# RNA-seq pipeline (shared)

代码/环境是维护者的，**只读**；你的输出只能写自己的目录。

> 路径约定：下面用 `$SKROOT` 表示 skill 安装根。DSH 是 `$HOME/.dsh/skills`，Codex 是 `$HOME/.codex/skills`；先 `export SKROOT=...`。

## 0. 使用前

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py check
```

`check_remote_env.sh` 必须全 PASS。`pipeline_adapt.py check` 返回 `OK` 才按本文件的参数执行；返回 `DRIFT` 时先 `refresh`，看 `references/generated/help.txt`，不要照旧参数硬跑。

## 0.1 自适应命令（推荐）

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
PROJ=my_project
RES="$LAB_RESULTS_ROOT/$PROJ/results"; WORK="$LAB_WORK_ROOT/$PROJ"
```

不要凭记忆拼 flag。让 adapter 读当前 `--help` 并生成命令：

```bash
CMD=$(python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py plan run \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/fastq \
  --results "$RES" --work "$WORK" --species hg38 --strand reverse --resume --background)
echo "$CMD"
lab_exec -- "$CMD"
```

`plan` 会先比对代码 hash；pipeline 更新后自动 `refresh`，再按当前 `--help` 和 `references/adapt_spec.json` 的角色别名生成命令。`--fastq-dir` 改成 `--input-dir` 之类只要别名覆盖就会自动跟着变。下游同理：

```bash
CMD=$(python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py plan downstream \
  --results "$RES" --species hg38 --plots "$LAB_RESULTS_ROOT/$PROJ/plots" \
  --padj 0.05 --lfc 0.58 --basemean 10)
lab_exec -- "$CMD"
```

## 1. 选目录

```bash
PROJ=my_project
RES="$LAB_RESULTS_ROOT/$PROJ/results"
WORK="$LAB_WORK_ROOT/$PROJ"
mkdir -p "$RES" "$WORK"
export TMPDIR="$LAB_SCRATCH/$PROJ"
export NXF_HOME="$LAB_WORK_ROOT/nextflow"
mkdir -p "$TMPDIR" "$NXF_HOME"
```

`$LAB_RESULTS_ROOT` 和 `$LAB_WORK_ROOT` 默认在 `/home/<你的账号>` 下，可写；`/home/machicheng` 下的一切都只读。

## 2. 从 FASTQ 跑上游

```bash
cd "$LAB_CODE_RNA"
bash rnaseq/run_auto_rnaseq.sh \
  --fastq-dir /home/$LAB_CLUSTER_USER/lab-data/fastq \
  --results-dir "$RES" --work-root "$WORK" \
  --species hg38 --strand reverse --layout auto \
  --background --resume --max-cpus 24 --max-memory "120 GB"
```

先加 `--dry-run` 检查输入/参考/环境。首次运行会在 `$RES` 写 `condition.csv` / `contrast.csv`；**停下来确认分组和 case/control 方向**再跑下游。

## 3. 只重跑下游（自己的结果）

```bash
cd "$LAB_CODE_RNA"
bash rnaseq/run_auto_rnaseq.sh --downstream \
  --results-dir "$RES" --plots-dir "$LAB_RESULTS_ROOT/$PROJ/plots" \
  --species hg38 --strand reverse \
  --padj-cutoff 0.05 --lfc-cutoff 0.58 --baseMean-min 10 --gray-nonsig false
```

要强制重算加 `--no-resume-modules`；它只影响下游模块，和上游 `--resume` 无关。

## 4. 下游输入是维护者的结果（只读）

不能对 `/home/machicheng/...` 原地跑 wrapper（它要写 `_automation`）。两种做法：

1. 在自己的目录做软链镜像（模块目录软链 + 目标模块重建），用 `--results-dir` 指向镜像；
2. 或直调 R，输出到自己的 `--outdir`：

```bash
cd "$LAB_CODE_RNA"
"$LAB_DOWNSTREAM_ENV/bin/Rscript" rnaseq-downstream/run_downstream.R \
  --results-dir /home/machicheng/.../results \
  --outdir "$LAB_RESULTS_ROOT/$PROJ/downstream_from_shared" \
  --species hg38 \
  --te-annotation-tsv "$LAB_REFERENCE/TE_GTF/hg38_te_annotation.tsv" \
  --tx2gene-path "$LAB_REFERENCE/human_hg38/gencode.v49.primary_assembly.annotation.gtf" \
  --sample-table <condition.csv> --contrast-file <contrast.csv> \
  --padj-cutoff 0.05 --lfc-cutoff 0.58 --baseMean-min 10 --gray-nonsig false
```

## 5. 验收

- 上游：`00_refcheck/refcheck.ok`、`multiqc/`、`RUN_MANIFEST.json`；
- 下游：`index.html`、`module_checklist.txt`、`_summary/run_summary.txt`；
- `inherited>0` 时产物可能来自上次，不能宣称“本次重跑”；
- 代码/参数指纹以 `RUN_MANIFEST.json` 和 `_summary/deg_summary.csv` 为准。

## 权限与坑

- 只读代码/conda：不要 `conda install`、不要写 `__pycache__`/`.Rhistory` 到 `/home/machicheng`。
- 缓存指到自己目录：`TMPDIR`、`NXF_HOME`、`R_USER_CACHE_DIR`。
- 多用户 `/tmp`：Nextflow launch/cache 用 `$NXF_HOME` 或自己的 outdir 下路径。
- 不要对别人的 `results` 跑 `--stop` 或 `--no-resume-modules`。
- 维护者代码更新后先 `pipeline_adapt.py refresh`，看 `references/generated/help.txt` 与 `params_added/removed.txt`，再用 `plan` 重新生成命令。
- 完全新加的 flag 用 `plan ... --extra "--new-flag value"` 透传；若它是常用角色，再把别名补进 `references/adapt_spec.json`。

## 参考

- [references/pipeline-contract.md](references/pipeline-contract.md)
- [references/shared-pitfalls.md](references/shared-pitfalls.md)
- `references/generated/help.txt`（由 `pipeline_adapt.py refresh` 生成）
