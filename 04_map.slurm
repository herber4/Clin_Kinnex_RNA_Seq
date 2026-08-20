#!/bin/bash
#SBATCH --job-name=pbmm2_align
#SBATCH --output=logs/map_%j.out
#SBATCH --error=logs/map_%j.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=12:00:00

set -euo pipefail
source "$(dirname "$0")/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

# NOTE: assumes REF_MMI was already built via:
#   pbmm2 index -j 16 --preset ISOSEQ ${REF_FASTA} ${REF_MMI}
pbmm2 align -j "${SLURM_CPUS_PER_TASK}" --preset ISOSEQ --sort \
    "${REF_FASTA}" "${CLUSTERDIR}/clustered.bam" \
    "${MAPDIR}/mapped_reads_all_samples.bam"

