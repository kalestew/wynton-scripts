#!/bin/bash
##############################################################################
#  ddg_saturation_job_single.sh   – one mutation, full nstruct, no array
##############################################################################
#$ -cwd
#$ -S /bin/bash
#$ -j y
#  PE / memory / scratch options are supplied by qsub
#$ -r y
##############################################################################

############################ 0. Strict shell & traps #########################
# strict by default
set -o pipefail
set -o errexit
set -o nounset

########################## 1. Positional arguments ###########################
if (( $# < 4 )); then
  echo "Usage: qsub ddg_saturation_job_single.sh <pdb> <mutfile> <run_id> <project> [residues.txt]"
  exit 1
fi
PDB_ORIG=$1
MUTFILE_ORIG=$2
RUN_ID=$3
PROJECT=$4
RESLIST_ORIG=${5:-residues.txt}

########################### 2. Environment setup #############################
# Relax `errexit` while sourcing SBGrid and Conda so that harmless non-zero
# returns (e.g. from `module` calls) do not kill the job.
set +o errexit
set +o nounset
source /programs/sbgrid.shrc
source /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/bin/activate
set -o errexit
set -o nounset

# Prefer ROSETTA3 defined by SBGrid; fall back to original hard-code
ROSETTA_DIR="${ROSETTA3:-/programs/x86_64-linux/rosetta/3.12}"

CONFIG_RUN="/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_35.yaml"
CONFIG_SETTINGS="/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml"

############################ 3. Directories ##################################
BASE="/wynton/scratch/$USER/${PROJECT}/run_${RUN_ID}"   # final BeeGFS home
FINAL_FLEX="${BASE}/flexddg"
mkdir -p "${FINAL_FLEX}"

TMPROOT="${TMPDIR:-/scratch/$USER/ddg_${JOB_ID}_$$}"
WORKDIR="${TMPROOT}/work"
mkdir -p "${WORKDIR}"

############################ 4. Stage-in #####################################
cp "${PDB_ORIG}"     "${WORKDIR}/"
cp "${MUTFILE_ORIG}" "${WORKDIR}/"
cp "${RESLIST_ORIG}" "${WORKDIR}/" 2>/dev/null || true

PDB=$(basename "${PDB_ORIG}")
MUTFILE=$(basename "${MUTFILE_ORIG}")
RESLIST=$(basename "${RESLIST_ORIG}")

############################ 5. Rosetta run ##################################
echo "===== $(date)  Mutation ${RUN_ID} on $(hostname);  cores=${NSLOTS}  ====="

# --- LIVE LOG FORWARDER -----------------------------------------------------
LIVELOG="${WORKDIR}/rosetta.log"          # master log preserved on scratch
touch "${LIVELOG}"
# Background tail sends every new line to SGE stdout
tail -n +1 -F "${LIVELOG}" &
TAILPID=$!
# ---------------------------------------------------------------------------

#  ↓ combine stdout + stderr, append to LIVELOG (which tail is following)
stdbuf -oL -eL \
rosetta_ddg_run \
    -p  "${WORKDIR}/${PDB}" \
    -cr "${CONFIG_RUN}" \
    -cs "${CONFIG_SETTINGS}" \
    -r  "${ROSETTA_DIR}" \
    -d  "${WORKDIR}" \
    -l  "${WORKDIR}/${MUTFILE}" \
    -n  "${NSLOTS}" \
    --saturation \
    --reslistfile "${WORKDIR}/${RESLIST}" \
    2>&1 | tee -a "${LIVELOG}"

# --- stop the tailer cleanly -----------------------------------------------
kill "${TAILPID}" 2>/dev/null || true
wait "${TAILPID}" 2>/dev/null || true
# ---------------------------------------------------------------------------

############################ 6. Stage-out ####################################
echo "[$(date)]  Copying results back to BeeGFS …"
mkdir -p "${FINAL_FLEX}"
tar -C "${WORKDIR}/flexddg" -cf - . | tar -C "${FINAL_FLEX}" -xpf -
cp -n "${WORKDIR}"/{${PDB},${MUTFILE},${RESLIST}} "${BASE}/" 2>/dev/null || true
cp "${WORKDIR}/rosetta.log" "${BASE}/"
touch "${BASE}/finished"
echo "[$(date)]  Done."

############################ 7. Cleanup ######################################
rm -rf "${TMPROOT}" || true

date
hostname

## End-of-job summary, if running as a job
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"  # This is useful for debugging and usage purposes,
                                          # e.g. "did my job exceed its memory request?"