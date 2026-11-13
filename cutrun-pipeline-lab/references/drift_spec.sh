PIPELINE=cutrun
CODE_VAR=LAB_CODE_CUT
DRIFT_FILES=(pipelines/chipseq_auto_nf/run_auto_chipseq.sh pipelines/chipseq_auto_nf/run_pipeline.sh pipelines/chipseq_auto_nf/run_downstream.sh pipelines/chipseq_auto_nf/main.nf tools/cutrun_cli/cutrun_preflight.py)
HELP_LABELS=(run_auto run_downstream)
HELP_CMDS=(
  "bash pipelines/chipseq_auto_nf/run_auto_chipseq.sh --help"
  "bash pipelines/chipseq_auto_nf/run_downstream.sh --help"
)
