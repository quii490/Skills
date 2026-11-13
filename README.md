# Skills for the med.thu cluster

可复用的科研 / 集群 skills。目前包含 **5 个给实验室成员使用的共享版 skill**：在 med.thu pod 上运行 RNA-seq、CUT&RUN/CUT&Tag/ChIP-seq、ATAC-seq、GPU Job，以及最基础的 pod 操作。

核心设计只有一句：

> **维护者的代码、conda 环境和参考基因组是只读的；每个使用者的结果、work、缓存写自己的 `/home/<账号>`。**

这样实验室成员不需要复制一份代码或环境，也不会把结果写到维护者目录里。

---

## 包含的 skills

| Skill | 功能 | 典型触发 |
|---|---|---|
| `med-pod-exec-lab` | 查 pod、以本人身份 `kubectl exec`、传脚本、后台跑长任务、按 PID 停止 | “进集群”“上 pod”“看下容器里的文件” |
| `rnaseq-pipeline-lab` | bulk RNA-seq：STAR/HISAT2、Salmon/featureCounts、TE 模块、DESeq2/GSEA 下游 | “跑 RNA-seq”“重跑下游” |
| `cutrun-pipeline-lab` | CUT&RUN/CUT&Tag/ChIP-seq：比对、MACS3 peak、bigWig、HOMER、注释/通路、下游 | “跑 CUT&RUN”“call peak” |
| `atacseq-pipeline-lab` | bulk ATAC-seq：比对、peak/consensus、fixed-bin、QC、DE、HOMER、footprinting/phasing | “跑 ATAC”“补 profile 图” |
| `med-gpu-job-lab` | 通过 med-helm/med 提交 GPU/CPU Job，使用自己的 Harbor 凭据和 namespace | “跑 GPU”“提交训练/推理” |

不包含：BioID 质谱分析、TFspacer、GraphTEBind、AF3 专用流程，以及维护者私人的 `med-data-transfer` 路径。以后有用的 skill 可以继续加到这个仓库。

---

## 环境要求

- macOS 或 Linux，`bash`、`python3`（3.9+）；
- 能访问 med.thu 的 `kubectl`，且 context 是你自己的；
- 你的集群账号在 `zhaoslab` 组，能读维护者的 `/home/machicheng`（只读）；
- 自己的 namespace / Running pod（默认 `zhaoslab-<账号>`）；
- 只有 GPU skill 额外需要：`helm`，以及你自己的 `base.med.thu` Harbor 账号。

默认 namespace 是 `zhaoslab-$LAB_CLUSTER_USER`；pod 名每次会变，skill 会自动查 Running pod。

---

## 安装

```bash
git clone https://github.com/quii490/Skills.git
cd Skills

# DSH 用户
bash install.sh --cluster-user <你的集群账号> --target ~/.dsh/skills

# 或 Codex CLI
bash install.sh --cluster-user <你的集群账号> --target ~/.codex/skills
```

安装器会：

1. 复制 5 个 `*-lab` skill；
2. 写 `~/.config/med-lab/config.env`（600）；
3. 写 `~/.config/med-lab/registry.env` 模板（600，GPU 用，密码留空）；
4. 已存在的配置默认不覆盖；需要重建时加 `--force`。

安装完成后：

```bash
export SKROOT="$HOME/.dsh/skills"          # Codex 用户改成 $HOME/.codex/skills
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
```

---

## 配置

`~/.config/med-lab/config.env`：

```bash
LAB_CLUSTER_USER=hujiatong          # 你的集群账号，不是 Mac 用户名
LAB_NAMESPACE=zhaoslab-hujiatong
LAB_MAINTAINER=machicheng
LAB_CODE_ROOT=/home/machicheng
LAB_CONDA_ROOT=/home/machicheng/.conda/envs
LAB_REFERENCE=/home/machicheng/reference
LAB_WORK_ROOT=/home/hujiatong/lab-work
LAB_RESULTS_ROOT=/home/hujiatong/lab-results
LAB_SCRATCH=/tmp/hujiatong
LAB_POD=                            # 留空自动查 Running pod
LAB_EXEC_SU=1                       # pod 默认 root 时 su 到本人；pod 已是本人则设 0
```

`registry.env`（只给 GPU skill）：

```bash
LAB_REGISTRY_USER=<你的 Harbor 用户名>
LAB_REGISTRY_PASSWORD=<你的 Harbor 密码>
```

**不要把密码提交到仓库或发到聊天里。**

---

## 安装后自检

```bash
# 读权限 + 自己的写权限
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
# 期望最后一行：REMOTE_ENV_READY

# 当前 pipeline 代码是否与 skill 快照一致
python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py check
python3 $SKROOT/cutrun-pipeline-lab/scripts/pipeline_adapt.py check
python3 $SKROOT/atacseq-pipeline-lab/scripts/pipeline_adapt.py check

# GPU 前置
bash $SKROOT/med-gpu-job-lab/scripts/check_gpu.sh
# 期望最后一行：GPU_ENV_READY
```

`check_remote_env.sh` 会检查：维护者代码/conda/reference/CUT 参考包可读，自己的 work/results/scratch 可写；维护者仓库 dirty 只 WARN。

---

## 快速使用

所有 pipeline skill 都建议用 `pipeline_adapt.py plan` 生成命令，而不是照抄旧 flag。`plan` 会读取**当前 pipeline 的 `--help`**。

### 1. pod 操作

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
POD="$(lab_pod)"
lab_exec "$POD" -- 'id; pwd; ls'
```

长任务：

```bash
lab_exec "$POD" -- "cd $LAB_WORK_ROOT && nohup setsid bash job.sh > run.log 2>&1 < /dev/null & echo launched"
```

### 2. RNA-seq

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
export TMPDIR="$LAB_SCRATCH/myproj" NXF_HOME="$LAB_WORK_ROOT/nextflow"

CMD=$(python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py plan run \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/fastq \
  --results "$LAB_RESULTS_ROOT/myproj/results" \
  --work "$LAB_WORK_ROOT/myproj" \
  --species hg38 --strand reverse --resume --background)
echo "$CMD"
lab_exec -- "$CMD"
```

先加 `--dry-run` 验证输入/环境；首次运行后人工确认 `condition.csv`/`contrast.csv` 再跑下游：

```bash
CMD=$(python3 .../pipeline_adapt.py plan downstream \
  --results "$LAB_RESULTS_ROOT/myproj/results" --species hg38 \
  --padj 0.05 --lfc 0.58 --basemean 10)
```

### 3. CUT&RUN / CUT&Tag / ChIP-seq

```bash
# 1) 生成 manifest
CMD=$(python3 $SKROOT/cutrun-pipeline-lab/scripts/pipeline_adapt.py plan init \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/cutrun \
  --outdir "$LAB_RESULTS_ROOT/mycut/results" --species hg38 --assay cutrun)
lab_exec -- "$CMD"

# 2) 人工核对 manifest 的 igg/is_igg/group/replicate
# 3) preview
CMD=$(python3 .../pipeline_adapt.py plan preview ... )
# 4) 正式
CMD=$(python3 .../pipeline_adapt.py plan run ... \
  --reference-bundle "$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json" \
  --profile conda,par --resume --background)
```

2026-11-02 起建议显式传不可变参考包：

- hg38：`$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json`
- mm39：`$LAB_REFERENCE/CUTnRUN/mm39_20261102_v1/reference_bundle.json`

bundle JSON 内嵌绝对路径并被 sha256 锁定，**不要编辑**；搬家要整目录搬并保留旧路径软链。

### 4. ATAC-seq

```bash
CMD=$(python3 $SKROOT/atacseq-pipeline-lab/scripts/pipeline_adapt.py plan init \
  --fastq /home/$LAB_CLUSTER_USER/lab-data/atac \
  --outdir "$LAB_RESULTS_ROOT/myatac/results" --species hg38)
lab_exec -- "$CMD"

# 编辑 samplesheet.csv / contrasts.csv 后
CMD=$(python3 .../pipeline_adapt.py plan run ... --preset quick --resume --background)
```

下游：`plan downstream --outdir ... --species hg38 --levels both`。

### 5. GPU Job

```bash
bash $SKROOT/med-gpu-job-lab/scripts/check_gpu.sh

VALUES=$(bash $SKROOT/med-gpu-job-lab/scripts/render_values.sh \
  --name "$LAB_CLUSTER_USER-$(date +%m%d-%H%M)" --user "$LAB_CLUSTER_USER")

# 编辑渲染后的 VALUES：image/job.script/resources/gputype
helm template test med-helm/med --version 1.1.0 \
  --namespace "$LAB_NAMESPACE" -f "$VALUES" >/dev/null

helm upgrade --install "<release>" med-helm/med \
  --version 1.1.0 --namespace "$LAB_NAMESPACE" -f "$VALUES"
```

监控与清理：

```bash
kubectl get jobs -n "$LAB_NAMESPACE" -l release=<release>
kubectl logs -n "$LAB_NAMESPACE" -f job/<job>
helm uninstall <release> -n "$LAB_NAMESPACE"
bash $SKROOT/med-gpu-job-lab/scripts/render_values.sh --cleanup "$VALUES"
```

---

## 自适应：pipeline 更新后不用改 skill 命令

每个 pipeline skill 带一个 `pipeline_adapt.py`：

```bash
python3 $SKROOT/<skill>/scripts/pipeline_adapt.py check
python3 $SKROOT/<skill>/scripts/pipeline_adapt.py refresh
python3 $SKROOT/<skill>/scripts/pipeline_adapt.py plan run --fastq ... --results ... --species hg38
```

工作方式：

1. `plan` 先比较当前代码的 git HEAD / 关键文件 SHA256 与 `references/code_snapshot.json`；
2. 代码变了会自动 `refresh`：重跑 `--help`，保存 `references/generated/help.txt`，提取所有 flag，记录新增/删除；
3. 按 `references/adapt_spec.json` 里的**逻辑角色**（`fastq`、`results`、`outdir`、`species`、`preset`、`resume`…）和别名表，从当前 flag 里选择；
4. 生成最终命令。

因此：

- pipeline 把 `--fastq-dir` 改名成 `--input-dir`，只要别名表覆盖，`plan` 自动用新名；
- 新 flag 用 `--extra "--new-flag value"` 透传；
- `check`/`refresh` 会把新增/删除 flag 写到 `params_added.txt` / `params_removed.txt`。

**边界**：自动适配的是 flag 名称/可用性。若同名参数的**语义**变了（例如 `--strand` 方向定义改变），仍需要看 `generated/help.txt` 人工确认；新增必填参数也可能需要你补 `--extra` 或更新 `adapt_spec.json`。

---

## 权限与安全

| 路径 | 权限 |
|---|---|
| `/home/machicheng/...`（代码、conda、reference、results） | 只读；不要 `conda install`、不要写缓存/结果 |
| `/home/<你>/...` | 可写；`LAB_WORK_ROOT` / `LAB_RESULTS_ROOT` / `LAB_SCRATCH` |
| `/mnt/data1/lanPublic/input` | 只读公共输入 |
| `/tmp/<你>` | 临时；pod 重建会丢 |

- 不要 `su - machicheng`；共享版一律以 `LAB_CLUSTER_USER` 运行（`LAB_EXEC_SU=0` 用于 pod 本身已是本人）。
- 不要原地对维护者的 `results` 跑会写下游的 wrapper；只读源先复制/软链到自己的目录。
- 不要杀别人的进程；只用精确 PID。
- 渲染后的 GPU values 含密码，600、用完删除；不要提交/打印。
- 共享 pod 上不要 `pkill -f` 关键词，容易匹配到自己的 exec 命令。

---

## 常见问题

**`ERROR: no Running pod in namespace ...`**
检查 `kubectl config current-context`、`kubectl get pods -n $LAB_NAMESPACE`；pod 名会变，`LAB_POD` 留空即可自动查。

**`REMOTE_ENV_FAIL`**
看哪一行 `[FAIL]`：通常是 namespace/账号不对，或维护者路径权限变了。不要用 root 跑。

**`plan` 报 `role ... not found`**
当前 `--help` 没有该 flag。运行 `refresh` 后看 `generated/help.txt`；用 `--extra` 传新 flag，或把别名补进 `adapt_spec.json`。

**`DRIFT`**
代码/flag 变了：先 `refresh`，再看 diff；不要按旧参数硬跑。

**GPU `cannot read node GPU capacity`**
RBAC 不允许列 nodes 或当前无 GPU 节点；这只是 WARN，以实际调度为准。真正提交前确认 namespace 配额。

**GPU 无 Harbor 凭据**
找管理员开通自己的 `base.med.thu` 账号；不要使用别人的密码。

---

## 仓库结构

```text
Skills/
├── README.md
├── install.sh
├── common/
│   ├── lab_config.sh
│   ├── check_remote_env.sh
│   ├── pipeline_adapt.py
│   └── shared-pitfalls.md
├── med-pod-exec-lab/
├── rnaseq-pipeline-lab/
├── cutrun-pipeline-lab/
├── atacseq-pipeline-lab/
├── med-gpu-job-lab/
└── tests/
    ├── run_all.sh
    ├── test_adapter.sh
    └── test_bundle.sh
```

每个 skill 的 `references/generated/` 是 `pipeline_adapt.py refresh` 自动生成的，包含当前 `--help`、flag 列表和差异；不要手改。

---

## 测试

```bash
bash tests/run_all.sh
```

覆盖：adapter 的别名/布尔/必填校验；安装器 + 配置权限 + 5 个 skill `quick_validate`；GPU values 渲染与清理。CI 在 Ubuntu 上跑同一套测试（不连集群）。

集群侧验证（需要 pod）：

```bash
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
python3 $SKROOT/rnaseq-pipeline-lab/scripts/pipeline_adapt.py check --deep
```

---

## 本次审计记录（2026-11-13）

- CUT&RUN 集群代码已到 `8e394ea`（annotate 丢弃 TxDb 缺失 contig 的 peak；summarize_peaks 保留尾部空字段）；shared skill 的 `--reference-bundle` 已补上 2026-11-02 的 hg38/mm39 不可变参考包。
- RNA-seq `9158a8b`、ATAC（无 git）当前 help 与快照一致；三个 pipeline 的 `check --deep` 均 OK。
- 用 `hujiatong` 账号复测：维护者代码/环境只读、自己的目录可写；RNA dry-run、CUT/ATAC `--init-only` 均成功。
- GPU chart 仍为 `med-helm/med 1.1.0`；values 渲染 + `helm template` 通过，未真实提交 GPU Job（需要使用者自己的凭据/配额）。

---

## 新增 skill

1. 在仓库根新增 `<name>/SKILL.md`（frontmatter 至少 `name`、`description`）；
2. 需要脚本放 `<name>/scripts/`，测试放 `<name>/tests/`；
3. 在 `install.sh` 的 skill 列表里加名字；
4. README 的表里加一行；
5. 跑 `bash tests/run_all.sh`，再提交。

维护者更新 pipeline 后，不需要改 skill 命令；使用者下次 `plan` 会自动 refresh。只有角色语义/必填参数变化时，才需要更新 `adapt_spec.json` 或说明文字。
