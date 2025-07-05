#!/bin/bash
##############################################################################
#  submit_all_saturation_single.sh
#
#  Usage:
#    bash submit_all_saturation_single.sh  <input.pdb>  <positions.txt>  \
#         [residues.txt]  <project_name>
#
#  One **SGE job per mutation site**.  Each job produces the full nstruct set
#  (default 35) in a single Rosetta run and stages the results back to BeeGFS.
##############################################################################
set -euo pipefail

############################ USER‑TUNABLE GLOBALS ############################
NSTRUCT=35               # nstruct inside ddg_kja_prod_35.yaml must match
CORES=20                 # CPU cores per job   (matches -pe smp $CORES)
MEM_PER_CORE=3G          # mem_free request per core
SCRATCH=20G              # node‑local SSD quota (Rosetta is I/O‑heavy)
H_RT="72:00:00"          # wall‑clock limit per mutation
##############################################################################

if (( $# < 3 )); then
    echo "Usage: bash $0 <input.pdb> <positions.txt> [residues.txt] <project_name>"
    exit 1
fi

PDB=$(realpath "$1")
POSFILE=$(realpath "$2")

if (( $# == 3 )); then
    PROJECT="$3"
    RESLIST=""                          # use Rosetta default residues.txt
else
    RESLIST=$(realpath "$3")
    PROJECT="$4"
fi

CHUNKS_DIR="mutation_chunks"
mkdir -p "${CHUNKS_DIR}"

SCRATCH_BASE="/wynton/scratch/$USER"
PROJECT_DIR="${SCRATCH_BASE}/${PROJECT}"
mkdir -p "${PROJECT_DIR}"

while read -r line; do
    mut_id=$(echo "$line" | cut -d' ' -f1 | tr '.' '-')
    chunk="${CHUNKS_DIR}/mutsite_${mut_id}.txt"
    echo "$line" > "$chunk"

    run_dir="${PROJECT_DIR}/run_${mut_id}"
    [[ -f "${run_dir}/finished" ]] && \
        { echo "✔ run_${mut_id} already finished – skipping"; continue; }

    echo "Submitting mutation ${mut_id}"

    qsub -N "ddg_${mut_id}" \
         -pe smp ${CORES} \
         -l mem_free=${MEM_PER_CORE},scratch=${SCRATCH},h_rt=${H_RT} \
         ddg_saturation_job_single.sh \
         "$PDB" "$chunk" "$mut_id" "$PROJECT" "${RESLIST:-}"

    sleep 1     # be gentle on qmaster
done < "$POSFILE"

echo
echo "Jobs submitted – monitor with:  watch qstat"
echo "Outputs: ${PROJECT_DIR}/run_<mut_id>/flexddg/<mut_id>/{1..${NSTRUCT}}/"
