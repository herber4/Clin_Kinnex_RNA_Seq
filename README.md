# Clin_Kinnex_RNA_Seq
Clinical Analysis of long read Kinnex RNAseq for the Cogan/Hamid UDN project at VUMC

# isoseq-kinnex-pipeline

Slurm-based pipeline for processing PacBio Kinnex full-length RNA-seq data: adapter
de-concatenation → primer removal/refinement → clustering → mapping → transcript
collapse → isoform classification (Pigeon) → transcriptome QC (SQANTI3).

Built for and tested on Vanderbilt's ACCRE cluster (Slurm scheduler, Conda
environments), but should port to any Slurm cluster with minor path edits.

This is **not** a Nextflow pipeline — it's a set of plain `sbatch` scripts chained
together with `--dependency`, designed to be readable and hackable without needing
to know Nextflow.

---

## Pipeline overview

| Step | Script | Runs as | What it does |
|---|---|---|---|
| 0 | `00_validate_and_stage.sh` | interactive | Validates `samples.tsv`, symlinks each sample's bam+pbi into a staging directory |
| 1 | `01_skera_split.slurm` | array (1 task/sample) | De-concatenates Kinnex MAS-seq reads (`skera split`) |
| 2 | `02_lima_refine.slurm` | array (1 task/sample) | Removes primers (`lima`) and generates FLNC reads (`isoseq refine`) |
| 3 | `03_cluster.slurm` | single job | Pools all samples' FLNC reads and clusters into transcripts (`isoseq cluster2`) |
| 4 | `04_map.slurm` | single job | Maps clustered transcripts to the reference genome (`pbmm2 align`) |
| 5 | `05_collapse.slurm` | single job | Collapses redundant transcript models (`isoseq collapse`) |
| 6 | `06_pigeon.slurm` | single job | Classifies isoforms against reference annotation (`pigeon classify/report/filter`) |
| 7 | `07_sqanti3.slurm` | single job | Structural QC and artifact filtering of the final isoform set (`sqanti3_qc.py`) |

Steps 1–2 are per-sample and run as Slurm job arrays. Steps 3–7 operate on the
pooled cohort (this mirrors how `isoseq cluster2` and `isoseq collapse` are
designed to be run — across samples, not per-sample) and run as single jobs.
`submit_pipeline.sh` chains steps 1–7 with `--dependency=afterok`, so the whole
thing runs unattended once submitted.

---

## Repository layout

```
.
├── README.md
├── pipeline_config.sh          # <-- edit this first, everything else sources it
├── samples.tsv.template        # copy to samples.tsv and fill in
├── 00_validate_and_stage.sh
├── 01_skera_split.slurm
├── 02_lima_refine.slurm
├── 03_cluster.slurm
├── 04_map.slurm
├── 05_collapse.slurm
├── 06_pigeon.slurm
├── 07_sqanti3.slurm
└── submit_pipeline.sh
```

---

## Prerequisites

### Software
- Slurm scheduler with `sbatch`, `squeue`, `sacctmgr`
- Conda/Miniconda with two pre-built environments:
  - `isoseq` — containing `skera`, `lima`, `isoseq` (IsoSeq v4+), `pbmm2`, `pigeon`
  - `sqanti3` — containing SQANTI3 v5.5.4+ and its dependencies (see
    [ConesaLab/SQANTI3](https://github.com/ConesaLab/SQANTI3) for the conda env
    yml used to build this)
- A reference genome FASTA and GTF annotation, **already downloaded and indexed**:
  ```bash
  pbmm2 index -j 16 --preset ISOSEQ your_genome.fa your_genome.mmi
  ```
  This pipeline does not download or index references for you — see the "Reference
  genome" section below.

### Data
- Raw Kinnex subreads BAMs (one per sample), each with its accompanying `.pbi`
  index file
- A MAS-seq/Kinnex concatenation primer FASTA (e.g. `mas16_primers.fasta`)
- An Iso-Seq primer FASTA for `lima`/`isoseq refine` (e.g.
  `IsoSeq_v2_primers_12.fasta`)

### Cluster access
- A valid Slurm account and partition. Find yours with:
  ```bash
  sacctmgr show assoc user=$USER format=account,partition
  ```

---

## Setup

### 1. Clone this repo onto the cluster

```bash
git clone <this-repo-url> isoseq_pipeline
cd isoseq_pipeline
```

### 2. Create your project directory structure

The pipeline expects one top-level project directory (`PROJDIR` in the config)
containing your reference and primer files, with everything else created
automatically:

```bash
mkdir -p /scratch/$USER/my_project
mkdir -p /scratch/$USER/my_project/ref
# put/link your reference fasta, gtf, and pre-built .mmi index in ref/
# put your primer fastas directly in the project dir
```

### 3. Edit `pipeline_config.sh`

This is the only file you need to touch for basic setup — every script sources it.
At minimum, set:

```bash
export SLURM_ACCOUNT="your_slurm_account"
export SLURM_PARTITION="your_partition"
export CONDA_BASE="/path/to/your/anaconda3"
export PROJDIR="/scratch/you/my_project"
```

Also confirm/update the reference and primer filenames near the bottom of the
file to match what you actually named things in `ref/`.

### 4. Create your samplesheet

Copy the template and fill it in — **tab-separated**, header required, exactly
these three columns:

```
sample    bam    pbi
```

```bash
cp samples.tsv.template samples.tsv
```

Edit `samples.tsv` with your real sample names and absolute paths to each
sample's raw subreads BAM and its `.pbi` index. Example:

```
sample    bam    pbi
patient01    /data/raw/patient01.subreads.bam    /data/raw/patient01.subreads.bam.pbi
patient02    /data/raw/patient02.subreads.bam    /data/raw/patient02.subreads.bam.pbi
```

The bam and pbi don't need to live next to each other or match any particular
naming convention — step 0 symlinks them into a consistent layout regardless of
where the originals are.

### 5. Validate and stage your inputs

```bash
bash 00_validate_and_stage.sh
```

This checks that `samples.tsv` is well-formed and every listed file exists, then
symlinks each sample's bam+pbi into `$PROJDIR/staged_input/` so downstream tools
always find the index next to its bam. It will print the number of samples found
and exit with an error message pointing at the specific problem if anything's
missing or misnamed.

---

## Running the pipeline

Submit everything in one go:

```bash
bash submit_pipeline.sh
```

This submits all 7 stages with Slurm dependencies (`--dependency=afterok`), so
each stage only starts once the previous one has fully succeeded. You'll see
output like:

```
Submitting pipeline for 12 samples (array range 0-11)...
Step 1 (skera)        -> job 1234567
Step 2 (lima+refine)  -> job 1234568
Step 3 (cluster2)     -> job 1234569
Step 4 (pbmm2 align)  -> job 1234570
Step 5 (collapse)     -> job 1234571
Step 6 (pigeon)       -> job 1234572
Step 7 (SQANTI3)      -> job 1234573
```

Monitor with:
```bash
squeue -u $USER
```

Logs for every job land in `$PROJDIR/logs/`, named by stage and job ID.

### Running a single stage manually

If a stage fails, fix the underlying issue and resubmit just that stage (no need
to rerun everything upstream):

```bash
sbatch --account=$SLURM_ACCOUNT --partition=$SLURM_PARTITION \
    --array=0-11 01_skera_split.slurm     # array stages only (01, 02)

sbatch --account=$SLURM_ACCOUNT --partition=$SLURM_PARTITION \
    03_cluster.slurm                       # single-job stages (03-07)
```

Then manually chain any stages after it with `--dependency=afterok:<jobid>` if you
want them to auto-continue, or just submit them one at a time as each finishes.

---

## Outputs

| Directory | Contents |
|---|---|
| `staged_input/` | Symlinked bam+pbi pairs per sample |
| `skera_split/` | De-concatenated segmented BAMs per sample |
| `lima_out/` | Primer-demultiplexed BAMs per sample |
| `flnc/` | Full-length non-chimeric reads per sample, plus pooled `flnc.fofn` |
| `clustered/` | Pooled clustered transcript BAM |
| `mapped/` | Genome-mapped, sorted BAM; `collapsed.gff` |
| `pigeon_out/` | Sorted/classified GFF+GTF, `collapsed_classification.txt`, filtered isoform set, subsampled saturation report |
| `sqanti3_out/` | SQANTI3 QC report and classification files |
| `logs/` | stdout/stderr for every Slurm job, named `<stage>_<jobid>[_<arraytaskid>].out/.err` |

The files most people want for downstream analysis (differential isoform usage,
splicing analysis, variant interpretation, etc.) are:
- `pigeon_out/collapsed_classification.filtered_lite_classification.txt` — final
  filtered isoform classification table
- `pigeon_out/collapsed.sorted.filtered_lite.gff` — final filtered isoform models
- `sqanti3_out/` — QC report to sanity-check the above before trusting it

---

## Known limitations / things to check before trusting results

- **`lima` output naming**: step 2 globs for `*IsoSeqX_3p.bam` in the lima output.
  If your Iso-Seq primer FASTA uses different primer pair names, this pattern in
  `02_lima_refine.slurm` needs updating to match.
- **`pigeon prepare` output naming**: step 6 assumes the sorted GTF is named
  `<original_basename>.sorted.gtf`. Confirm this on your first run's logs before
  relying on it for a full cohort.
- **Resource requests** (cpu/mem/time in each `.slurm` file) are reasonable
  starting points for a moderate Kinnex cohort but are not tuned to your cluster's
  actual limits or your data's actual size. Check partition limits with `sinfo`
  and adjust if jobs get rejected or run out of memory.
- This pipeline does not include reference download/indexing, gene-fusion calling,
  or downstream differential expression/splicing analysis (e.g. IsoQuant,
  IsoformSwitchAnalyzeR) — it stops at classified, QC'd isoforms.

---

## Tools used

- [skera](https://isoseq.how) / [lima](https://lima.how) / [IsoSeq](https://isoseq.how) — PacBio
- [pbmm2](https://github.com/PacificBiosciences/pbmm2) — PacBio's minimap2 wrapper
- [pigeon](https://isoseq.how/classification/pigeon.html) — PacBio isoform classification
- [SQANTI3](https://github.com/ConesaLab/SQANTI3) — Pardo-Palacios et al., transcriptome QC

## Citation

If you use this pipeline, please cite the underlying tools above rather than this
repo directly (this is a thin orchestration layer around them).

## License

<!-- add your license of choice -->

