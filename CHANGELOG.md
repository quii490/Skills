# Changelog

## 2026-11-13

- Audit against current med.thu pipelines:
  - CUT&RUN code at `8e394ea` (annotate drops peaks on contigs absent from TxDb; summarize_peaks keeps trailing empty fields).
  - Added CUT&RUN immutable reference bundles (`hg38_20261102_v1`, `mm39_20261102_v1`) to the shared skill and `check_remote_env.sh`.
  - RNA-seq `9158a8b` and ATAC help/flags remain consistent with snapshots.
- Added `med-gpu-job-lab` (own Harbor credentials, per-user namespace/values).
- Added `pipeline_adapt.py`: `check`, `refresh`, `plan`, `run` with automatic refresh on pipeline code changes and role/alias-based flag resolution.
- Removed `code_drift.sh` (superseded by `pipeline_adapt.py`).
- Made tests portable (macOS/Linux) and added GitHub Actions.

## 2026-10-31

- Initial shared bundle: `med-pod-exec-lab`, `rnaseq-pipeline-lab`, `cutrun-pipeline-lab`, `atacseq-pipeline-lab`.
