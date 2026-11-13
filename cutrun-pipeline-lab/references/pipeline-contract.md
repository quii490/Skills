# CUT&RUN shared contract

## Coordinates

- Code (read-only): `$LAB_CODE_CUT` = `/home/machicheng/CUTnRUN`
- Conda (read-only): `$LAB_CHIPSEQ_ENV` (bowtie2/samtools/MACS/deepTools/HOMER), `$LAB_DOWNSTREAM_ENV` (ChIPseeker)
- Reference (read-only): `$LAB_REFERENCE/bowtie2_index`, `$LAB_CODE_CUT/resources/CUTRUN_analysis/anno`
- Writable: `$LAB_RESULTS_ROOT`, `$LAB_WORK_ROOT`, `$LAB_SCRATCH`

## Entry chain

`pipelines/chipseq_auto_nf/run_auto_chipseq.sh` → `run_pipeline.sh` → `main.nf`;
downstream `run_downstream.sh` writes `<results>/09_downstream/`.

## Inputs

- FASTQ: `<sample>_R1/_R2.fastq.gz`
- `_automation/inputs/manifest.csv`: `sample,species,assay,group,replicate,igg,is_igg,layout,fastq_1,fastq_2`
- Control (IgG/Input) must be explicit; no-control runs need `--allow-no-control` and are exploratory.

## Outputs (own dir)

`01_prepared_reads/ 02_align/ 02_align_te/ 03_sorted_bam/ 03_sorted_bam_te/ 04_clean_bam/ 04_te_bam/ 04_te_locus_best_bam/ 05_tracks/ 05_tracks_te/ 06_peaks/ 07_featurecounts/ 08_analysis/ 09_downstream/`

## Reference bundles (2026-11-02)

- hg38: `$LAB_REFERENCE/CUTnRUN/hg38_20261102_v1/reference_bundle.json` (GRCh38, 194 contigs)
- mm39: `$LAB_REFERENCE/CUTnRUN/mm39_20261102_v1/reference_bundle.json` (GRCm39, 61 contigs)
- Pass with `--reference-bundle`; it overrides legacy references and is sha256-locked.
- Do not edit the JSON; it embeds absolute paths. Move the whole directory and keep old symlinks.

## Rules

- `run_downstream.sh` writes inside `--results-dir`; your results dir must be yours.
- Maintainer results are read-only: copy/symlink the stage dirs into your own tree before downstream.
- Default `--resource-tier standard`; `full` is much slower/larger.
- exit 42 = SKIP; `module_status_summary.json` status PASS can coexist with FAILs — read `counts` and `required_failures`.
- 2026-11-13 snapshot: annotate drops peaks on contigs absent from the TxDb (8e394ea); summarize_peaks keeps trailing empty fields (b966271).
