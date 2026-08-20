#!/bin/bash
# Run this once, interactively, before submitting the pipeline.
# - Validates samples.tsv (header + 3 columns, files exist)
# - Symlinks each sample's bam+pbi into STAGEDIR as <sample>.subreads.bam(.pbi)
#   so every downstream tool finds the index right next to the bam,
#   regardless of where the originals actually live.

set -euo pipefail
source "$(dirname "$0")/pipeline_config.sh"

if [[ ! -s "${SAMPLES_TSV}" ]]; then
    echo "ERROR: ${SAMPLES_TSV} not found. Copy samples.tsv.template, fill it in, and point" >&2
    echo "       SAMPLES_TSV at it in pipeline_config.sh." >&2
    exit 1
fi

HEADER=$(head -n1 "${SAMPLES_TSV}")
EXPECTED=$'sample\tbam\tpbi'
if [[ "${HEADER}" != "${EXPECTED}" ]]; then
    echo "ERROR: samples.tsv header must be exactly: sample<TAB>bam<TAB>pbi" >&2
    echo "       Got: ${HEADER}" >&2
    exit 1
fi

N=0
while IFS=$'\t' read -r SAMPLE BAM PBI; do
    N=$((N + 1))
    [[ -f "${BAM}" ]] || { echo "ERROR: missing bam for ${SAMPLE}: ${BAM}" >&2; exit 1; }
    [[ -f "${PBI}" ]] || { echo "ERROR: missing pbi for ${SAMPLE}: ${PBI}" >&2; exit 1; }

    ln -sf "$(readlink -f "${BAM}")" "${STAGEDIR}/${SAMPLE}.subreads.bam"
    ln -sf "$(readlink -f "${PBI}")" "${STAGEDIR}/${SAMPLE}.subreads.bam.pbi"
done < <(tail -n +2 "${SAMPLES_TSV}")

echo "Validated and staged ${N} samples into ${STAGEDIR}/"
echo "Use --array=0-$((N-1)) for the per-sample array jobs (submit_pipeline.sh does this for you)."
