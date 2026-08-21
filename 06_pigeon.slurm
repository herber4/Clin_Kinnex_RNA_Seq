#!/bin/bash
#SBATCH --job-name=pigeon
#SBATCH --output=logs/pigeon_%j.out
#SBATCH --error=logs/pigeon_%j.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=8:00:00

set -euo pipefail
source "${SLURM_SUBMIT_DIR}/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

cd "${PIGEONDIR}"
cp "${MAPDIR}/collapsed.gff" .
cp "${MAPDIR}"/collapsed.flnc_count.txt . 2>/dev/null || true

pigeon prepare "${REF_GTF}" "${REF_FASTA}"
pigeon prepare collapsed.gff

pigeon classify -j "${SLURM_CPUS_PER_TASK}" \
    collapsed.sorted.gff \
    "$(basename "${REF_GTF}" .gtf).sorted.gtf" \
    "${REF_FASTA}" \
    --fl "${MAPDIR}/collapsed.flnc_count.txt"

pigeon report -j 8 --exclude-singletons collapsed_classification.txt subsampled_pigeon_report.txt
pigeon filter collapsed_classification.txt --isoforms collapsed.sorted.gff

