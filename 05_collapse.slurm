#!/bin/bash
#SBATCH --job-name=collapse
#SBATCH --output=logs/collapse_%j.out
#SBATCH --error=logs/collapse_%j.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=12:00:00

set -euo pipefail
source "$(dirname "$0")/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

ls "${FLNCDIR}"/*.flnc.bam > "${MAPDIR}/flnc.fofn"

isoseq collapse -j "${SLURM_CPUS_PER_TASK}" --do-not-collapse-extra-5exons \
    "${MAPDIR}/mapped_reads_all_samples.bam" "${MAPDIR}/flnc.fofn" \
    "${MAPDIR}/collapsed.gff"

