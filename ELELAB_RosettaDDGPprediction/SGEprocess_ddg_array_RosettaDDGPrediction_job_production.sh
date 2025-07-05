#!/bin/bash
##############################################################################
#  SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh      –  array-safe replica runner for Wynton SGE
#
#  Usage (from ELELAB_submit_SGE_RosettaDDGPrediction.sh):
#     qsub SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh <pdb> <mutfile> <run_id> <project> [reslist]
#
#  Fixes versus original:
#    • Each task gets its own OUTDIR → no clobbering
#    • Stage-out starts inside OUTDIR/flexddg → no double directory
#    • Renames Rosetta’s default “1” folder to the replica index
##############################################################################

##############################################################################
#  SGE OPTIONS
##############################################################################
#$ -cwd
#$ -S /bin/bash
#$ -j y
#$ -t 1-35                 # array size  (35 replicas by default)
#$ -tc 10                  # max concurrent tasks
#$ -pe smp 4               # 4 cores / replica
#$ -l mem_free=4G          # 3 GB / core  (12 GB / task)
#$ -l scratch=8G           # node-local SSD quota
#$ -r y
##############################################################################

##############################################################################
# 0.  Args:  <pdb> <mutation_list> <run_id> <project>  [residues.txt]
##############################################################################
if (( $# < 4 )); then
  echo "Usage: qsub SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh <pdb> <mutfile> <run_id> <project> [residues.txt]"
  exit 1
fi

PDB_ORIG="$1"
MUTFILE_ORIG="$2"
RUN_ID="$3"
PROJECT="$4"
RESLIST_ORIG="${5:-residues.txt}"
REPL_ID="${SGE_TASK_ID:-1}"

##############################################################################
# 1.  Environment
##############################################################################

set -o pipefail          # always on
set -o errexit           # strict… but
set +o errexit           #  ⇢ suspend for env-setup
source /programs/sbgrid.shrc
source /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/bin/activate
set -o errexit           #  ⇢ strict again
set -u                   # nounset after env is stable

##############################################################################
# 2.  Directories
##############################################################################
# 2a.  BeeGFS final storage --------------------------------------------------
BASE="/wynton/scratch/kjander/${PROJECT}/run_${RUN_ID}"
FINAL_FLEX="${BASE}/flexddg"      # final home for all replicas

# === atomic, race‑proof creation of $BASE ===============================
if ! mkdir "${BASE}" 2>/dev/null; then
    [[ -d "${BASE}" ]] || { echo "FATAL: ${BASE} is not a directory" >&2; exit 1; }
fi
mkdir -p "${FINAL_FLEX}"

# 2b.  Node-local SSD working dir  ($TMPDIR is pre-created by SGE)
: "${TMPDIR:=$(mktemp -d /scratch/${USER:-$LOGNAME}/ddg_${JOB_ID}_${REPL_ID}_XXXX)}"
WORKDIR="${TMPDIR}/work"
OUTDIR="${WORKDIR}/replica_${REPL_ID}"   # **replica-private root**
mkdir -p "${OUTDIR}"

##############################################################################
# 3.  Stage-IN  (small files only)
##############################################################################
cp "${PDB_ORIG}"     "${OUTDIR}/"
cp "${MUTFILE_ORIG}" "${OUTDIR}/"
cp "${RESLIST_ORIG}" "${OUTDIR}/"

PDB_FILE="${OUTDIR}/$(basename "${PDB_ORIG}")"
MUTFILE="${OUTDIR}/$(basename "${MUTFILE_ORIG}")"
RESLIST="${OUTDIR}/$(basename "${RESLIST_ORIG}")"

##############################################################################
# 4.  Logging header
##############################################################################
echo "===== Replica ${REPL_ID} on $(hostname) @ $(date) ====="
echo "TMPDIR : ${TMPDIR}"
echo "BASE   : ${BASE}"
echo "-------------------------------------------------------"

##############################################################################
# 5.  Rosetta  –  run entirely on the local SSD
##############################################################################
rosetta_ddg_run \
    -p  "${PDB_FILE}" \
    -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod.yaml \
    -cs /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml \
    -r  /programs/x86_64-linux/rosetta/3.12 \
    -d  "${OUTDIR}" \
    -l  "${MUTFILE}" \
    -n  "${NSLOTS}" \
    --saturation \
    --reslistfile "${RESLIST}" \
    | tee "${OUTDIR}/rosetta.log"

##############################################################################
# 5a.  Rename Rosetta’s default “1” folder → replica index
##############################################################################
if [[ "${REPL_ID}" -ne 1 ]]; then         # replica 1 already named “1”
    for mutdir in "${OUTDIR}"/flexddg/*; do
        src="${mutdir}/1"
        dest="${mutdir}/${REPL_ID}"
        [[ -d "${src}" ]] && mv "${src}" "${dest}"
    done
fi

##############################################################################
# 6.  Stage‑OUT (concurrency‑safe with flock)
##############################################################################
stage_out() {
    echo "[$(date)]  Staging replica ${REPL_ID} …"

    # grab exclusive lock for this mutation
    exec 9> "${BASE}/.stageout.lock"
    flock -x 9

    # 6a. once‑per‑run small files
    for f in "${PDB_FILE}" "${MUTFILE}" "${RESLIST}"; do
        cp -n "${f}" "${BASE}/" 2>/dev/null || true
    done
    [[ -f "${OUTDIR}/flexddg/mutinfo.txt" ]] && \
        cp -n "${OUTDIR}/flexddg/mutinfo.txt" "${FINAL_FLEX}/" 2>/dev/null || true

    # 6b. bulk results
    tar -C "${OUTDIR}/flexddg" -cf - . | tar -C "${FINAL_FLEX}" -xpf -

    mv "${OUTDIR}/rosetta.log"  "${BASE}/rosetta_rep${REPL_ID}.log"

    echo "[$(date)]  Replica ${REPL_ID} stage‑out finished."
    flock -u 9           # release lock
}
##############################################################################
# 7.  Traps – ensure results are copied even on timeout
##############################################################################
trap stage_out USR1      # soft-limit warning SIGUSR1
trap stage_out EXIT      # always execute on normal or error exit

##############################################################################
# 8.  Done
##############################################################################
wait                      # paranoia – ensure Rosetta exited
exit 0                    # EXIT trap performs the stage-out

date
hostname

## End-of-job summary, if running as a job
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"  # This is useful for debugging and usage purposes,
                                          # e.g. "did my job exceed its memory request?"
