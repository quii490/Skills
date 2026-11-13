---
name: med-pod-exec-lab
description: "共享版 med.thu pod 操作：按 ~/.config/med-lab/config.env 里的用户名/命名空间查 pod、以本人身份 kubectl exec、传脚本、后台跑长任务并清理。Use when asked to enter/connect to a med.thu pod, run commands inside it, inspect files, or debug a job. 适用对象是使用维护者只读代码/conda 环境的实验室成员；不适用于提交新的 Helm GPU/CPU 任务（用 med-gpu-job）或搬运大量数据（用 med-data-transfer）。"
---

# Med Pod Exec (shared)

这是给实验室成员用的共享版：维护者的代码、conda 环境和参考基因组在 `/home/machicheng` 下**只读**；所有输出写到自己的 `/home/<你的集群用户名>`。

> 路径约定：下面用 `$SKROOT` 表示 skill 安装根。DSH 是 `$HOME/.dsh/skills`，Codex 是 `$HOME/.codex/skills`；先 `export SKROOT=...`。

## 0. 先读配置并检查

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
bash $SKROOT/med-pod-exec-lab/scripts/check_remote_env.sh
```

配置在 `~/.config/med-lab/config.env`（`LAB_CLUSTER_USER`、`LAB_NAMESPACE`、`LAB_WORK_ROOT`、`LAB_RESULTS_ROOT` 等）。没有配置就先运行 `skills-shared/install.sh --cluster-user <你的账号>`。

`check_remote_env.sh` 会确认：能读维护者代码/conda/参考，且能写自己的 work/results/scratch。任何 `[FAIL]` 先解决再继续。

## 1. 查 pod

```bash
source .../lab_config.sh
kubectl config current-context          # 应是你自己的 med.thu context
kubectl get pods -n "$LAB_NAMESPACE"
POD="$(lab_pod)"                        # 第一个 Running pod
echo "$POD"
```

pod 名每次会变；不要复用旧名字。自己的 pod 优先用；没有 pod 时找管理员/维护者，不要擅自起别人的 release。

## 2. 以本人身份执行

`kubectl exec` 通常落在 root，必须降到自己的集群账号：

```bash
kubectl exec "$POD" -n "$LAB_NAMESPACE" -- su - "$LAB_CLUSTER_USER" -c 'id; pwd'
# 或
lab_exec "$POD" -- 'id; pwd'
```

**不要** `su - machicheng`，除非你本人就是 machicheng。所有输出路径必须在 `/home/$LAB_CLUSTER_USER` 下。

## 3. 传脚本（base64 + 字节校验）

heredoc 经 `kubectl exec` 会偶发吞内容。用：

```bash
B64=$(base64 -i local.sh | tr -d '\n')
lab_exec "$POD" -- "printf '%s' '$B64' | base64 -d > $LAB_WORK_ROOT/job.sh; wc -c $LAB_WORK_ROOT/job.sh"
```

核对字节数与本地一致，再 `bash -n`。

## 4. 后台启动

```bash
lab_exec "$POD" -- "cd $LAB_WORK_ROOT && nohup setsid bash job.sh > run.log 2>&1 < /dev/null & echo launched"
lab_exec "$POD" -- "ps -eo pid,etime,args | grep 'job.s[h]' | grep -v grep"
```

`A && B && nohup X &` 会把整条链后台化，必须拆成“前台准备”和“单独启动”两条。启动后确认恰好一个实例。

## 5. 监控与停止

- 轮询 `tail -n 50 run.log`、产物 mtime、pipeline 自己的 status 文件；不要 `tail -f`。
- pod 时钟是 UTC；向人汇报时 +8。
- 停止用精确 PID（`ps` 查），不要 `pkill -f` 关键词（会匹配到自己的 exec 命令）。
- 共享 pod 上不要杀别人的进程。

## 6. 清理

- 删自己的一次性脚本/日志/临时目录；
- 输出确认在 `$LAB_RESULTS_ROOT` / `$LAB_WORK_ROOT`；
- 不要改维护者 `/home/machicheng` 下的任何文件（只读）；
- 如果用了自己的 Helm release，按 med-gpu-job 的规则卸载，不要动别人的。

## 权限模型

| 路径 | 权限 |
|---|---|
| `/home/machicheng/...`（代码、conda、参考） | 只读；不要 `conda install`、不要写 `__pycache__`/缓存进去 |
| `/home/<你>` | 可写；work/results/scratch 都在这里 |
| `/tmp/<你>` | 可写但临时；pod 重建会丢 |
| `/mnt/data1/lanPublic/input` | 只读公共输入 |

需要写缓存时显式指向自己的目录：`TMPDIR=$LAB_SCRATCH`、`NXF_HOME=$LAB_WORK_ROOT/nextflow`、`R_USER_CACHE_DIR=$LAB_WORK_ROOT/.cache/R`。
