PIPELINE=atac
CODE_VAR=LAB_CODE_ATAC
DRIFT_FILES=(run_auto_atacseq.sh run_pipeline.sh main.nf nextflow.config atacseq-downstream/run_downstream_atac.R scripts/run_atac_downstream_only.sh)
HELP_LABELS=(run_auto run_pipeline run_downstream_only)
HELP_CMDS=(
  "bash run_auto_atacseq.sh --help"
  "bash run_pipeline.sh --help"
  "bash scripts/run_atac_downstream_only.sh --help"
)
