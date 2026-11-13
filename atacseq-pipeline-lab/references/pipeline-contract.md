# ATAC-seq shared contract

## Coordinates

- Code (read-only): `$LAB_CODE_ATAC` = `/home/machicheng/ATAC-seq/pipeline_final`
- Conda (read-only): `$LAB_CHIPSEQ_ENV` (bowtie2/samtools/MACS/deepTools/HOMER/Rscript)
- Reference (read-only): `$LAB_REFERENCE` (genome, bowtie2, GTF, TSS/gene body, TE, blacklist, MEME)
- Writable: `$LAB_RESULTS_ROOT`, `$LAB_WORK_ROOT`, `$LAB_SCRATCH`

## Entry chain

`run_auto_atacseq.sh` → `run_pipeline.sh` → `main.nf`;
downstream `atacseq-downstream/run_downstream_atac.R` via `scripts/run_atac_downstream_only.sh`.

## Inputs

- FASTQ: `<sample>_1/_2.fq.gz`
- `_automation/inputs/samplesheet.csv`: `sample,layout,condition,replicate,r1,r2`
- `_automation/inputs/contrasts.csv`: `case,control`

## Outputs (own dir)

`00_refcheck/ 01_fastp/ 02_align/ 03_qc/ 04_bw/ 05_peaks/ 06_consensus_peaks/ 07_counts/ 08_downstream/ 11_nuc_phasing/ QC_REPORT.md pipeline_report.html`

## Rules

- `--preset quick|standard|full`; standard keeps HOMER on.
- Downstream writes inside `<outdir>/08_downstream`; outdir must be yours.
- Maintainer results read-only: copy to your tree before re-running downstream.
- `--mode upstream` only upstream; `--mode downstream` needs existing results and writes there.
- QC FAIL/WARN is sample-level, not pipeline failure.
