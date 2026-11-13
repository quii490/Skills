PIPELINE=rnaseq
CODE_VAR=LAB_CODE_RNA
DRIFT_FILES=(rnaseq/run_auto_rnaseq.sh rnaseq/main.nf rnaseq/nextflow.config rnaseq-downstream/run_downstream.R rnaseq-downstream/rnaseq-function.R)
HELP_LABELS=(run_auto run_downstream)
HELP_CMDS=(
  "bash rnaseq/run_auto_rnaseq.sh --help"
  "$LAB_DOWNSTREAM_ENV/bin/Rscript rnaseq-downstream/run_downstream.R --help"
)
