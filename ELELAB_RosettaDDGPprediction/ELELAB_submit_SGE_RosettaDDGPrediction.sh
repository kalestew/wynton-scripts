#!/bin/bash
##############################################################################
# ELELAB_submit_SGE_RosettaDDGPrediction.sh  (array-aware version)
#
# Usage (same as before):
#   bash ELELAB_submit_SGE_RosettaDDGPrediction.sh  <input.pdb>  <positions.txt>  [residues.txt]  <project_name>
#
# The script submits ONE array job per mutation site.  Each array job
# runs N_REPLICAS replicas (default 35) with at most TC_MAX running at once.
##############################################################################
set -euo pipefail

##############################################################################
# ---- USER-TUNABLE GLOBALS --------------------------------------------------
##############################################################################
N_REPLICAS=35        # total replicas (= Rosetta nstruct) per mutation site
TC_MAX=5             # throttle: max running tasks per array
CORES=5             # cores per replica  (matches -pe smp $CORES)
MEM_PER_CORE=4G      # mem_free request per core   (total = CORES×MEM_PER_CORE)
SCRATCH=8G           # scratch request per task
H_RT="40:00:00"      # wall-clock limit per replica
##############################################################################

# ---- positional arguments check -------------------------------------------
if (( $# < 3 )); then
    echo "Usage: bash ELELAB_submit_SGE_RosettaDDGPrediction.sh <input.pdb> <positions.txt> [residues.txt] <project_name>"
    exit 1
fi

PDB=$(realpath "$1")
POSFILE=$(realpath "$2")

if (( $# == 3 )); then
    PROJECT_NAME="$3"
    RESLIST=$(realpath "${3:-residues.txt}")
else
    RESLIST="$3"
    PROJECT_NAME="$4"
fi

CHUNKS_DIR="mutation_chunks"
mkdir -p "$CHUNKS_DIR"

GLOBAL_SCRATCH_BASE="/wynton/scratch/kjander"
PROJECT_DIR="${GLOBAL_SCRATCH_BASE}/${PROJECT_NAME}"
mkdir -p "$PROJECT_DIR"

# ---- Create metadata file for tracking run parameters ---------------------
METADATA_FILE="${PROJECT_DIR}/.rosetta_ddg_metadata.json"
SUBMISSION_DIR=$(pwd)
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Create or update metadata file
cat > "$METADATA_FILE" <<EOF
{
  "project_name": "${PROJECT_NAME}",
  "submission_info": {
    "timestamp": "${TIMESTAMP}",
    "submission_directory": "${SUBMISSION_DIR}",
    "pdb_file": {
      "absolute_path": "${PDB}",
      "filename": "$(basename "${PDB}")"
    },
    "position_file": {
      "absolute_path": "${POSFILE}",
      "filename": "$(basename "${POSFILE}")"
    },
    "residues_file": {
      "absolute_path": "${RESLIST}",
      "filename": "$(basename "${RESLIST}")",
      "is_default": $([ "$RESLIST" == "residues.txt" ] && [ $# -eq 3 ] && echo "true" || echo "false")
    },
    "user": "${USER}",
    "hostname": "$(hostname)"
  },
  "run_parameters": {
    "n_replicas": ${N_REPLICAS},
    "tc_max": ${TC_MAX},
    "cores_per_replica": ${CORES},
    "mem_per_core": "${MEM_PER_CORE}",
    "scratch": "${SCRATCH}",
    "wall_time": "${H_RT}"
  },
  "paths": {
    "project_directory": "${PROJECT_DIR}",
    "chunks_directory": "${SUBMISSION_DIR}/${CHUNKS_DIR}",
    "sge_script": "${SUBMISSION_DIR}/SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
  },
  "aggregations": []
}
EOF

echo "📝 Created metadata file: ${METADATA_FILE}"

# -------------------- submission loop --------------------------------------
while read -r line; do
    mut_id=$(echo "$line" | cut -d' ' -f1 | tr '.' '-')
    chunk_file="${CHUNKS_DIR}/mutsite_${mut_id}.txt"
    echo "$line" > "$chunk_file"

    final_run_dir="${PROJECT_DIR}/run_${mut_id}"
    if [ -f "${final_run_dir}/finished" ]; then
        echo "✔ run_${mut_id} already completed – skipping"
        continue
    fi

    echo "Submitting mutation ${mut_id}"

    QSUB_OPTS="-t 1-${N_REPLICAS} -tc ${TC_MAX} \
               -pe smp ${CORES} \
               -l mem_free=${MEM_PER_CORE},scratch=${SCRATCH},h_rt=${H_RT}"

    if [[ "$RESLIST" == "residues.txt" && $# -eq 3 ]]; then
        qsub $QSUB_OPTS -N "ddg_${mut_id}" SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh \
             "$PDB" "$chunk_file" "$mut_id" "$PROJECT_NAME"
    else
        qsub $QSUB_OPTS -N "ddg_${mut_id}" SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh \
             "$PDB" "$chunk_file" "$mut_id" "$PROJECT_NAME" "$RESLIST"
    fi

    sleep 1          # gentle on the scheduler
done < "$POSFILE"

echo
echo "All array jobs submitted.  Monitor with:  watch qstat"
echo "Results will aggregate under:  ${PROJECT_DIR}/run_<mut_id>"
