# RNA-seq shared contract

## Coordinates

- Code (read-only): `$LAB_CODE_RNA` = `/home/machicheng/RNA-seq/Pipeline/rnaseq`
- Conda (read-only): `$LAB_UPSTREAM_ENV` (STAR/salmon/fastp), `$LAB_DOWNSTREAM_ENV` (DESeq2/GSEA)
- Reference (read-only): `$LAB_REFERENCE` (STAR/HISAT2 indexes, GTF, TE annotation)
- Writable: `$LAB_RESULTS_ROOT`, `$LAB_WORK_ROOT`, `$LAB_SCRATCH`

## Entry chain

`rnaseq/run_auto_rnaseq.sh` → `rnaseq/run_pipeline.sh` → `rnaseq/main.nf`;
downstream `rnaseq-downstream/run_downstream.R`.

## Inputs

- FASTQ: `<sample>_R1/_R2.fastq.gz` (pattern configurable)
- `results/condition.csv`: `sample,condition,replicate`
- `results/contrast.csv`: `case,control` (case = experimental group)

## Outputs (own dir)

- Upstream: `00_refcheck/ 01_fastp/ 02_gene_star/ 03_gene_featurecounts/ 05_gene_salmon/ 06_te_star/ 09_TEtranscripts/ 12_telescope/ multiqc/ RUN_MANIFEST.json`
- Downstream: `index.html`, `module_checklist.txt`, `_summary/{module_status.csv,run_summary.txt,deg_summary.csv}`, module/contrast dirs
- `plots/_summary` exists only when wrapper writes inside your results dir

## Rules

- Never write `_automation`, `plots`, `work` into `/home/machicheng`.
- Read-only source results: mirror with symlinks or call `run_downstream.R` with `--outdir` in your tree.
- Default thresholds: padj 0.05, |lfc| 0.58, baseMean 5 (C174 used 10); `deg_summary.csv` records actual values.
- `--resume` = upstream Nextflow; `--no-resume-modules` = downstream modules.
