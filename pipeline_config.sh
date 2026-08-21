#!/bin/bash
# ============================================================
# pipeline_config.sh
# EDIT THIS FILE FIRST. Every other script sources it.
# ============================================================

# --- Slurm ---
export SLURM_ACCOUNT="herberaa"      # from: sacctmgr show assoc user=$USER
export SLURM_PARTITION="batch"       # confirm real partition name with ACCRE

# --- Conda ---
export CONDA_BASE="/home/herberaa/anaconda3"
export ISOSEQ_ENV="isoseq"
export SQANTI3_ENV="sqanti3"

# --- Project layout ---
export PROJDIR="/data/l3_udn_2/herber/kinnex"    # EDIT to your real project dir

export STAGEDIR="${PROJDIR}/staged_input"           # bam+pbi symlinked here per sample
export SKERADIR="${PROJDIR}/skera_split"
export LIMADIR="${PROJDIR}/lima_out"
export FLNCDIR="${PROJDIR}/flnc"
export CLUSTERDIR="${PROJDIR}/clustered"
export REFDIR="${PROJDIR}/ref"
export MAPDIR="${PROJDIR}/mapped"
export PIGEONDIR="${PROJDIR}/pigeon_out"
export SQANTIDIR="${PROJDIR}/sqanti3_out"
export LOGDIR="${PROJDIR}/logs"

# --- Reference (assumed already downloaded + indexed per your notes) ---
export REF_FASTA="${REFDIR}/GRCh38.primary_assembly.genome.fa"
export REF_GTF="${REFDIR}/gencode.v38.annotation.gtf"
export REF_MMI="${REFDIR}/GRCh38.primary_assembly.genome.mmi"

# --- Primers ---
export MAS_PRIMERS="${PROJDIR}/mas16_primers.fasta"
export ISOSEQ_PRIMERS="${PROJDIR}/IsoSeq_v2_primers_12.fasta"

# --- Sample manifest ---
# Tab-separated, header required, columns: sample  bam  pbi
export SAMPLES_TSV="${PROJDIR}/samples.tsv"

# --- SQANTI3 location (per your unzip step) ---
export SQANTI3_QC="${PROJDIR}/bin/sqanti3/sqanti3_qc.py"

mkdir -p "$STAGEDIR" "$SKERADIR" "$LIMADIR" "$FLNCDIR" "$CLUSTERDIR" "$MAPDIR" "$PIGEONDIR" "$SQANTIDIR" "$LOGDIR"

# --- Helper: given a 0-based Slurm array task ID, echo "sample<TAB>bam<TAB>pbi" ---
# (data lines start at line 2 of samples.tsv, since line 1 is the header)
get_sample_row () {
    local task_id="$1"
    sed -n "$((task_id + 2))p" "${SAMPLES_TSV}"
}

