#!/bin/bash
##############################################################################
#  process_ddg_aggregate_finalize.sh – merge mutinfo.txt pieces after array copy
##############################################################################
#$ -cwd
#$ -S /bin/bash
#$ -j y
#$ -pe smp 1
#$ -l h_rt=02:00:00
#$ -l mem_free=1G
#$ -r y
##############################################################################
set -euo pipefail

: "${PROJECT:?} ${AGG_DIR:?}"

BASE="/wynton/scratch/kjander/${PROJECT}"
DEST_ROOT="${BASE}/${AGG_DIR}"
DEST="${DEST_ROOT}/flexddg"
PARTS_DIR="${DEST_ROOT}/mutinfo_parts"
MUTINFO_FINAL="${DEST}/mutinfo.txt"

echo "[$(date)]  Finalising mutinfo.txt …"

: > "${MUTINFO_FINAL}"   # truncate / create

if compgen -G "${PARTS_DIR}/mutinfo.txt.*" > /dev/null; then
    cat "${PARTS_DIR}"/mutinfo.txt.* | awk '!seen[$0]++' >> "${MUTINFO_FINAL}"
    rm -rf "${PARTS_DIR}"
else
    echo "WARNING: no mutinfo parts found" >&2
fi

echo "[$(date)]  Aggregation complete."
echo "Flexddg master dir : ${DEST}"
echo "Mutinfo file       : ${MUTINFO_FINAL}"

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"  # SGE job summary 