#!/bin/bash
# Run this from the isoseq_pipeline/ directory:  bash submit_pipeline.sh
# It submits all 7 steps with Slurm dependencies so they run unattended,
# each stage waiting for the previous one to finish successfully.

set -euo pipefail
source ./pipeline_config.sh

if [[ ! -s "${SAMPLES_TSV}" ]]; then
    echo "ERROR: ${SAMPLES_TSV} not found. Run 00_validate_and_stage.sh first." >&2
    exit 1
fi

N=$(($(wc -l < "${SAMPLES_TSV}") - 1))   # subtract header line
ARRAY_RANGE="0-$((N - 1))"
echo "Submitting pipeline for ${N} samples (array range ${ARRAY_RANGE})..."

COMMON_SBATCH=(--account="${SLURM_ACCOUNT}" --partition="${SLURM_PARTITION}")

# --- Step 1: skera (array) ---
JID1=$(sbatch --parsable "${COMMON_SBATCH[@]}" --array="${ARRAY_RANGE}" 01_skera_split.slurm)
echo "Step 1 (skera)        -> job ${JID1}"

# --- Step 2: lima + refine (array), waits for ALL of step 1's array tasks ---
JID2=$(sbatch --parsable "${COMMON_SBATCH[@]}" --array="${ARRAY_RANGE}" \
    --dependency=afterok:${JID1} 02_lima_refine.slurm)
echo "Step 2 (lima+refine)  -> job ${JID2}"

# --- Step 3: pooled clustering, waits for all of step 2 ---
JID3=$(sbatch --parsable "${COMMON_SBATCH[@]}" \
    --dependency=afterok:${JID2} 03_cluster.slurm)
echo "Step 3 (cluster2)     -> job ${JID3}"

# --- Step 4: mapping ---
JID4=$(sbatch --parsable "${COMMON_SBATCH[@]}" \
    --dependency=afterok:${JID3} 04_map.slurm)
echo "Step 4 (pbmm2 align)  -> job ${JID4}"

# --- Step 5: collapse ---
JID5=$(sbatch --parsable "${COMMON_SBATCH[@]}" \
    --dependency=afterok:${JID4} 05_collapse.slurm)
echo "Step 5 (collapse)     -> job ${JID5}"

# --- Step 6: pigeon ---
JID6=$(sbatch --parsable "${COMMON_SBATCH[@]}" \
    --dependency=afterok:${JID5} 06_pigeon.slurm)
echo "Step 6 (pigeon)       -> job ${JID6}"

# --- Step 7: SQANTI3 ---
JID7=$(sbatch --parsable "${COMMON_SBATCH[@]}" \
    --dependency=afterok:${JID6} 07_sqanti3.slurm)
echo "Step 7 (SQANTI3)      -> job ${JID7}"

echo ""
echo "All stages submitted. Monitor with: squeue -u \$USER"
echo "If any stage fails, fix the issue and resubmit just that stage manually with:"
echo "  sbatch --account=${SLURM_ACCOUNT} --partition=${SLURM_PARTITION} [--array=${ARRAY_RANGE}] <script>"

