# 共享环境的通用坑（所有 pipeline-lab 适用）

## P1. 维护者的目录只读

`/home/machicheng`（代码、conda、reference、results）属于维护者。你的账号只在 `zhaoslab` 组，能读/执行，**不能写**。任何 `conda install`、`pip install`、`R CMD INSTALL`、`__pycache__`、`.Rhistory`、`_automation` 都不能落到那里。

核查：

```bash
test -w /home/machicheng && echo "UNEXPECTED writable" || echo "read-only OK"
```

## P2. 输出目录必须是自己的

pipeline 默认会写 `results/_automation`、`plots/`、`09_downstream/` 等。统一用：

```bash
RES=$LAB_RESULTS_ROOT/<project>
WORK=$LAB_WORK_ROOT/<project>
```

不要直接对 `/home/machicheng/.../results` 跑会写目录的 wrapper；只读源要么做软链镜像，要么直调下游 R 指定 `--outdir`。

## P3. conda 环境只读，缓存要外移

直接调用 `$LAB_UPSTREAM_ENV/bin/STAR`、`$LAB_DOWNSTREAM_ENV/bin/Rscript`、`$LAB_CHIPSEQ_ENV/bin/bowtie2`，不要 `conda activate` 后安装包。设置：

```bash
export TMPDIR="$LAB_SCRATCH/<project>"
export NXF_HOME="$LAB_WORK_ROOT/nextflow"
export R_USER_CACHE_DIR="$LAB_WORK_ROOT/.cache/R"
export MPLCONFIGDIR="$LAB_WORK_ROOT/.cache/matplotlib"
mkdir -p "$TMPDIR" "$NXF_HOME" "$R_USER_CACHE_DIR" "$MPLCONFIGDIR"
```

## P4. Nextflow 的 launch/cache 不能共用

`-resume` 依赖**启动目录**里的 `.nextflow/history`，不是 work dir。每个项目固定自己的 `NXF_HOME`/launch 目录；不要用别人的 `/tmp/.../launch`。

## P5. `/tmp` 是共享且临时的

用 `/tmp/$LAB_CLUSTER_USER/<project>`，不要用 `/tmp/cutrun-nextflow` 这类全局名。pod 重建后 `/tmp` 丢失，resume 历史也会丢。

## P6. 不要杀别人的进程

共享 pod 上 `pkill -f` 会匹配到自己的 exec 命令，也可能杀掉别人的任务。只用精确 PID，并且只停自己启动的。

## P7. 参考基因组的路径是维护者的

STAR/HISAT2/bowtie2 索引、GTF、TE 注释都在 `$LAB_REFERENCE`。可以读，不要复制到自己的 home（占空间）；需要自定义索引时放到 `$LAB_WORK_ROOT/reference`。

## P8. 代码会变

维护者更新 pipeline 后，参数/默认值可能变化。每次开工先：

```bash
python3 scripts/pipeline_adapt.py check
```

`DRIFT` 时运行 `refresh`，用 `pipeline_adapt.py plan` 重新生成命令，并读 `references/generated/help.txt`；不要凭旧记忆执行。
