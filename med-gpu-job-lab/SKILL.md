---
name: med-gpu-job-lab
description: "共享版 med.thu GPU/CPU Job 提交：用你自己的 Harbor 凭据和 namespace，通过 med-helm/med chart 跑 GPU 批处理，日志/输出写自己的 /home/你的账号。Submit and monitor GPU batch Jobs on med.thu with per-user credentials and a read-only shared setup. 不负责 AF3 专用流程（med-af3）。"
---

# Med GPU Job (shared)

> 路径约定：下面用 `$SKROOT` 表示 skill 安装根（DSH `$HOME/.dsh/skills`，Codex `$HOME/.codex/skills`）。

共享版只共享**流程和 values 模板**，不共享维护者的 Harbor 密码。你需要自己的 `base.med.thu` 账号。

## 0. 前置检查

```bash
source $SKROOT/med-pod-exec-lab/scripts/lab_config.sh
bash $SKROOT/med-gpu-job-lab/scripts/check_gpu.sh
```

必须 `GPU_ENV_READY`。它检查 kubectl/helm、namespace、`create jobs` 权限、`med-helm` repo、GPU 节点容量和 registry 凭据（只报“已设置”，不打印）。

 registry 凭据放在 `~/.config/med-lab/registry.env`（600）：

```bash
LAB_REGISTRY_USER=<你的 Harbor 用户名>
LAB_REGISTRY_PASSWORD=<你的 Harbor 密码>
```

`LAB_REGISTRY_USER` 必须等于你的集群账号（chart 以它运行 Job，并决定挂载哪个 home）。没有 Harbor 账号就找管理员开通，**不要**使用别人的密码。

## 1. 渲染 values

```bash
VALUES=$(bash $SKROOT/med-gpu-job-lab/scripts/render_values.sh \
  --name "$LAB_CLUSTER_USER-$(date +%m%d-%H%M)" \
  --user "$LAB_CLUSTER_USER")
```

也可以 `--template` 指定自己的 values。渲染结果 600、只打印路径。

编辑 **渲染后的临时文件**，至少改：

```yaml
image:
  repository: base.med.thu/public/jupyter-gpu
  tag: "v1"
containerName: "<唯一名>"       # render 已生成
gputype: "low"                  # 或 high；纯 CPU 注释掉
resources:
  cpu: "24"
  memory: "128"
  gpu: "1"
job:
  script: "cd /home/<你> && python train.py ..."
  jobLogPath: "/home/<你>/joblog"
```

不要把 `personal` 改成别人的 home；不要挂载 `/home/machicheng` 作为可写目录。

## 2. 预览（不下发）

```bash
helm template "$LAB_CLUSTER_USER-test" med-helm/med --version 1.1.0 \
  --namespace "$LAB_NAMESPACE" -f "$VALUES" >/dev/null
```

只检查退出码；**不要把 template 输出贴到聊天**（含 Secret/凭据）。

## 3. 提交

```bash
helm upgrade --install "$LAB_CLUSTER_USER-$(date +%m%d-%H%M)" med-helm/med \
  --version 1.1.0 --namespace "$LAB_NAMESPACE" -f "$VALUES"
```

提交会改共享集群状态，只在用户明确要求跑任务时执行。不要加 `--wait-for-jobs`。

## 4. 监控

```bash
kubectl get jobs -n "$LAB_NAMESPACE" -l release=<release>
kubectl get pods -n "$LAB_NAMESPACE" -l job-name=<job> -o wide
kubectl logs -n "$LAB_NAMESPACE" -f job/<job>
```

Job 日志还会写到 `job.jobLogPath`（默认 `/home/<你>/joblog`）。pending 时看 `kubectl describe job/pod` 的 events，不要只看 GPU 是否调度成功。

## 5. 清理

```bash
helm uninstall <release> -n "$LAB_NAMESPACE"
bash $SKROOT/med-gpu-job-lab/scripts/render_values.sh --cleanup "$VALUES"
```

确认 Job/Pod/Service/Ingress 都消失；不要卸载别人的 release。

## 坑

- `containerName` 必须每个 release 唯一，否则 Secret/Service/Ingress 冲突。
- `resources.cpu` 是 limit，request 上限 8；memory limit，request 上限 50Gi。
- `nfs` 不要改；默认 Taurus 由管理员指定。
- `imageCredentials.username` 同时决定 Job 运行用户和挂载 home；填错会看不到自己的数据。
- 渲染文件含密码，只能放 `/private/tmp` 或自己的目录，600，用完删除。
- 共享集群 GPU 配额/排队与维护者无关；不要抢占别人的 GPU。

## 参考

- [references/cluster-contract.md](references/cluster-contract.md)
- `assets/gpu_job.yaml`（模板，`password` 为空）
