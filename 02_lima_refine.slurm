#!/bin/bash
#SBATCH --job-name=lima_refine
#SBATCH --output=logs/lima_refine_%A_%a.out
#SBATCH --error=logs/lima_refine_%A_%a.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=6:00:00

set -euo pipefail
source "$(dirname "$0")/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

ROW=$(get_sample_row "${SLURM_ARRAY_TASK_ID}")
SAMPLE=$(echo "${ROW}" | cut -f1)
SEG_BAM="${SKERADIR}/${SAMPLE}.segmented.bam"
LIMA_PREFIX="${LIMADIR}/${SAMPLE}.lima.bam"

echo "[lima] sample=${SAMPLE}"
lima "${SEG_BAM}" "${ISOSEQ_PRIMERS}" "${LIMA_PREFIX}" --isoseq -j "${SLURM_CPUS_PER_TASK}" --peek-guess

# lima names its output based on the primer pair it detected, e.g. <sample>.lima.IsoSeqX_5p--IsoSeqX_3p.bam
# find the 3p-tagged file it produced for this sample:
LIMA_OUT=$(ls "${LIMADIR}/${SAMPLE}"*IsoSeqX_3p.bam 2>/dev/null | head -n1)
if [[ -z "${LIMA_OUT}" ]]; then
    echo "ERROR: no lima output found for ${SAMPLE}" >&2
    exit 1
fi

echo "[refine] sample=${SAMPLE} input=${LIMA_OUT}"
isoseq refine -j "${SLURM_CPUS_PER_TASK}" --require-polya \
    "${LIMA_OUT}" "${ISOSEQ_PRIMERS}" "${FLNCDIR}/${SAMPLE}.flnc.bam"

