#!/bin/bash
##############################################################################
#  ddg_saturation_aggregate_job.sh  –  collate flexddg outputs from many runs
#
#  Usage:
#     qsub ddg_saturation_aggregate_job.sh <project> [agg_dir]
#
#      <project>   Name used in  /wynton/scratch/kjander/<project>
#      [agg_dir]   Name of new directory to create beneath <project>
#                  (default: aggregated_flexddg)
#
#  Resulting layout:
#     /wynton/scratch/kjander/<project>/<agg_dir>/flexddg/ <mutation dirs…>
#                                                      └─ mutinfo.txt
##############################################################################

##############################################################################
#  SGE OPTIONS  –  one light-weight task, minimal resources
##############################################################################
#$ -cwd
#$ -S /bin/bash
#$ -j y
#$ -pe smp 1
#$ -l mem_free=2G
#$ -l scratch=4G
#$ -r y
##############################################################################

##############################################################################
# 0.  Args
##############################################################################
if (( $# < 1 )); then
  echo "Usage: qsub ddg_saturation_aggregate_job.sh <project> [agg_dir]" >&2
  exit 1
fi

PROJECT="$1"
AGG_DIR="${2:-aggregated_flexddg}"

BASE="/wynton/scratch/kjander/${PROJECT}"
SRC_GLOB="${BASE}/run_*/flexddg"
DEST_ROOT="${BASE}/${AGG_DIR}"
DEST="${DEST_ROOT}/flexddg"
MUTINFO_OUT="${DEST}/mutinfo.txt"

##############################################################################
# 1.  Sanity checks
##############################################################################
set -o errexit -o pipefail -o nounset

[[ -d "${BASE}" ]] || { echo "FATAL: ${BASE} does not exist" >&2; exit 2; }

if [[ -e "${DEST}" ]]; then
    echo "NOTE: ${DEST} already exists – new mutations will be merged, duplicates skipped."
else
    mkdir -p "${DEST}"
fi

##############################################################################
# 2.  Merge flexddg mutation directories & mutinfo files
##############################################################################
echo "===== Aggregation started on $(hostname) @ $(date) ====="
: > "${MUTINFO_OUT}"               # truncate / create

for RUN_FLEX in ${SRC_GLOB}; do
    [[ -d "${RUN_FLEX}" ]] || continue
    echo "[INFO] Processing ${RUN_FLEX##${BASE}/}"

    # --- copy each mutation directory --------------------------------------
    for ENTRY in "${RUN_FLEX}"/*; do
        NAME="$(basename "${ENTRY}")"

        if [[ "${NAME}" == "mutinfo.txt" ]]; then
            # accumulate mutinfo lines
            cat "${ENTRY}" >> "${MUTINFO_OUT}"
            continue
        fi

        # mutation directory
        if [[ -d "${ENTRY}" ]]; then
            DEST_MUT="${DEST}/${NAME}"
            if [[ -e "${DEST_MUT}" ]]; then
                echo "  [SKIP] ${NAME} already present – not overwriting" >&2
            else
                cp -r "${ENTRY}" "${DEST}/"
            fi
        fi
    done
done

# ---- de-duplicate mutinfo.txt (preserve order of first appearance) ---------
awk '!seen[$0]++' "${MUTINFO_OUT}" > "${MUTINFO_OUT}.tmp" && mv "${MUTINFO_OUT}.tmp" "${MUTINFO_OUT}"

echo "===== Aggregation finished @ $(date) ====="
echo "Master directory : ${DEST}"
echo "Mutinfo file     : ${MUTINFO_OUT}"