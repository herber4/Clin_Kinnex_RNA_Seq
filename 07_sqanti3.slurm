#!/bin/bash
#SBATCH --job-name=sqanti3
#SBATCH --output=logs/sqanti3_%j.out
#SBATCH --error=logs/sqanti3_%j.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=12:00:00

set -euo pipefail
source "$(dirname "$0")/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${SQANTI3_ENV}"

export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

cd "${PIGEONDIR}"

python "${SQANTI3_QC}" \
    --isoforms collapsed.sorted.filtered_lite.gff \
    --refGTF "${REF_GTF}" \
    --refFasta "${REF_FASTA}" \
    -fl collapsed.flnc_count.txt \
    -t "${SLURM_CPUS_PER_TASK}" \
    -o sqanti_run \
    -d "${SQANTIDIR}"

