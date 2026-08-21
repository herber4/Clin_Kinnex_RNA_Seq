#!/bin/bash
#SBATCH --job-name=cluster2
#SBATCH --output=logs/cluster2_%j.out
#SBATCH --error=logs/cluster2_%j.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=24:00:00

set -euo pipefail
source "${SLURM_SUBMIT_DIR}/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

FOFN="${FLNCDIR}/flnc.fofn"
ls "${FLNCDIR}"/*.flnc.bam > "${FOFN}"
echo "Pooling $(wc -l < "${FOFN}") FLNC files for clustering:"
cat "${FOFN}"

isoseq cluster2 -j "${SLURM_CPUS_PER_TASK}" "${FOFN}" "${CLUSTERDIR}/clustered.bam"

