#!/bin/bash
##############################################################################
#  process_ddg_aggregate_one_run.sh – SGE array task that copies ONE run's results
#
#  Environment variables supplied by submit script:
#      PROJECT   – project name
#      AGG_DIR   – aggregation directory name
#      RUN_LIST  – file whose N-th line gives the run_NNNN/flexddg path
##############################################################################
#$ -cwd
#$ -S /bin/bash
#$ -j y
#$ -pe smp 1
#$ -l mem_free=2G
#$ -l h_rt=12:00:00
#$ -l scratch=4G
#$ -r y
##############################################################################
set -euo pipefail

: "${PROJECT:?} ${AGG_DIR:?} ${RUN_LIST:?}"
: "${SGE_TASK_ID:?}"

export OMP_NUM_THREADS=${NSLOTS:-1}   # respect SGE core allocation guidance

RUN_FLEX=$(sed -n "${SGE_TASK_ID}p" "${RUN_LIST}")
[[ -d "${RUN_FLEX}" ]] || { echo "Task ${SGE_TASK_ID}: ${RUN_FLEX} not found!" >&2; exit 3; }

BASE="/wynton/scratch/kjander/${PROJECT}"
DEST_ROOT="${BASE}/${AGG_DIR}"
DEST="${DEST_ROOT}/flexddg"
PARTS_DIR="${DEST_ROOT}/mutinfo_parts"

mkdir -p "${DEST}" "${PARTS_DIR}"

echo "[$(date)]  Task ${SGE_TASK_ID}: copying ${RUN_FLEX##${BASE}/} …"

# -- copy mutation directories (skip existing) ------------------------------
for ENTRY in "${RUN_FLEX}"/*; do
    NAME=$(basename "${ENTRY}")
    if [[ "${NAME}" == "mutinfo.txt" ]]; then
        cp "${ENTRY}" "${PARTS_DIR}/${NAME}.${SGE_TASK_ID}"
        continue
    fi
    [[ -d "${ENTRY}" ]] || continue
    DEST_MUT="${DEST}/${NAME}"
    # Atomically create destination mutation dir; skip if it already exists
    if ! mkdir "${DEST_MUT}" 2>/dev/null; then
        echo "  [SKIP] ${NAME} already present – not overwriting" >&2
        continue
    fi
    # Copy with streaming tar – robust on BeeGFS and avoids temp-file issues
    echo "      → copying with tar …"
    if ! tar -C "${ENTRY}" -cf - . | tar -C "${DEST_MUT}" -xpf - ; then
        echo "[ERROR] tar copy failed for ${NAME}" >&2
    fi
done

# Ensure mutinfo.txt was collected; warn if missing
if [[ ! -f "${PARTS_DIR}/mutinfo.txt.${SGE_TASK_ID}" ]]; then
    if [[ -f "${RUN_FLEX}/mutinfo.txt" ]]; then
        cp "${RUN_FLEX}/mutinfo.txt" "${PARTS_DIR}/mutinfo.txt.${SGE_TASK_ID}"
    else
        echo "[WARN] Task ${SGE_TASK_ID}: mutinfo.txt not found in ${RUN_FLEX}" >&2
    fi
fi

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"  # SGE job summary (memory/CPU usage)

echo "[$(date)]  Task ${SGE_TASK_ID} finished." 