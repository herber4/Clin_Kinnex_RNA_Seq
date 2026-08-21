#!/bin/bash
#SBATCH --job-name=skera
#SBATCH --output=logs/skera_%A_%a.out
#SBATCH --error=logs/skera_%A_%a.err
#SBATCH --cpus-per-task=24
#SBATCH --mem=32G
#SBATCH --time=4:00:00
# --account, --partition, --array are set at submit time by submit_pipeline.sh
# (so the array size can match your actual sample count automatically)

set -euo pipefail
source "${SLURM_SUBMIT_DIR}/pipeline_config.sh"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate "${ISOSEQ_ENV}"

ROW=$(get_sample_row "${SLURM_ARRAY_TASK_ID}")
SAMPLE=$(echo "${ROW}" | cut -f1)

# use the staged copy (bam+pbi guaranteed co-located) rather than the raw path in samples.tsv
IN_BAM="${STAGEDIR}/${SAMPLE}.subreads.bam"
OUT_BAM="${SKERADIR}/${SAMPLE}.segmented.bam"

echo "[skera] sample=${SAMPLE}"
skera split -j "${SLURM_CPUS_PER_TASK}" "${IN_BAM}" "${MAS_PRIMERS}" "${OUT_BAM}"

