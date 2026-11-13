# med.thu GPU Job contract (shared)

## Coordinates

- Kubernetes context: your own (`kubectl config current-context`), not necessarily `machicheng@med.thu`.
- Namespace: `LAB_NAMESPACE` (default `zhaoslab-<你的账号>`).
- Helm repo: `med-helm` at `http://166.111.153.65:7001`.
- Chart: `med-helm/med`, tested `1.1.0`.
- Registry: `base.med.thu`; your own username/password.

## What chart 1.1.0 renders

- one `batch/v1` Job;
- a ConfigMap with the platform entrypoint;
- an image-pull Secret;
- a ClusterIP Service and an Ingress (even for a batch Job).
- The Job runs privileged, starts SSSD/SSH, resolves `imageCredentials.username`, then executes `job.script` as that user.

## Resource translation

- `resources.cpu` → limit; request capped at 8 CPUs.
- `resources.memory` → Gi limit; request capped at 50 Gi.
- `resources.gpu` → equal `nvidia.com/gpu` requests/limits.
- GPU requests require `gputype: low|high` (node selector).

## Storage

- `loadDataPath.public: ["input"]` → `/mnt/data1/lanPublic/input` (read-only).
- `personal` → `/home/<entry>`; use only your own entry.
- `transfer: true` additionally mounts `/home/transfer`; not needed for normal jobs.
- `nfs` is administrator-provided; don't change it.

## Names

- Helm release names the Job/ConfigMap.
- `containerName` names Secret/Service/Ingress/container; must be unique per release.

## Logs and cleanup

- Job stdout/stderr → Kubernetes logs and `job.jobLogPath`.
- `ttlSecondsAfterFinished` default 600s; don't rely on it for data retention.
- `helm uninstall <release> -n <namespace>` after collecting results.

## Security

- The values file contains the image-pull password after rendering. Keep it 600, never commit/print, delete after submit.
- Do not use another person's registry credentials or home mount.
