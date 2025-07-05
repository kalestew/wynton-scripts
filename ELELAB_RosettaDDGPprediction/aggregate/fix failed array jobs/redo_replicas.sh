#!/bin/bash
##############################################################################
#  redo_replicas.sh  –  resubmit individual replica(s) that failed or were
#                      deleted from the original saturation run.
#
#  HOW TO USE
#  1.  Place this file in the SAME directory that contains:
#          mutation_chunks/            (created by the original submit script)
#          SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh  (the worker script)
#  2.  Edit the parameters below (PDB, PROJECT, RESLIST) if they differ.
#  3.  Either:
#          a) Run find_missing_replicas.py to generate missing_replicas.txt, then run:
#             bash redo_replicas.sh
#          b) Or manually fill the MUT_REP array and run with --manual flag:
#             bash redo_replicas.sh --manual
##############################################################################
set -euo pipefail

# ─── CHECK FOR METADATA FILE AND AUTO-POPULATE PARAMETERS ─────────────────
METADATA_FILE=".rosetta_ddg_metadata.json"
if [[ -f "$METADATA_FILE" ]]; then
    echo "📋  Found metadata file - reading parameters..."
    METADATA_INFO=$(python3 -c "
import json
try:
    with open('$METADATA_FILE', 'r') as f:
        data = json.load(f)
        # Extract just the filename for PDB
        pdb_path = data['submission_info']['pdb_file']['absolute_path']
        print(data['submission_info']['pdb_file']['filename'])
        print(data['project_name'])
        print(data['submission_info']['residues_file']['filename'])
        print(data['run_parameters']['cores_per_replica'])
        print(data['run_parameters']['mem_per_core'])
        print(data['run_parameters']['scratch'])
        print(data['run_parameters']['wall_time'])
except Exception as e:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$METADATA_INFO" ]]; then
        readarray -t META_PARAMS <<< "$METADATA_INFO"
        PDB="${META_PARAMS[0]}"
        PROJECT="${META_PARAMS[1]}"
        RESLIST="${META_PARAMS[2]}"
        CORES="${META_PARAMS[3]}"
        MEM_PER_CORE="${META_PARAMS[4]}"
        SCRATCH="${META_PARAMS[5]}"
        H_RT="${META_PARAMS[6]}"
        
        echo "    ✓ Loaded parameters from metadata"
        echo "    ✓ PDB: $PDB"
        echo "    ✓ Project: $PROJECT"
        PARAMS_FROM_METADATA=true
    else
        PARAMS_FROM_METADATA=false
    fi
else
    PARAMS_FROM_METADATA=false
fi

# ─── DEFAULT PARAMETERS (used if no metadata or as override) ───────────────
if [[ "$PARAMS_FROM_METADATA" == "false" ]]; then
    # ─── SAME PARAMETERS YOU USED LAST TIME ─────────────────────────────────────
    PDB="41D1_rosettaPreped.pdb"                     # absolute or relative path
    PROJECT="FINAL_FULL_41D1_Array_jun24thLate/WedTarCopyRegular1"
    RESLIST="residues.txt"       # leave as "residues.txt" if you ran without one
    CORES=5                      # must match SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh
    MEM_PER_CORE=4G
    SCRATCH=8G
    H_RT="40:00:00"
fi

# ─── INPUT OPTIONS ──────────────────────────────────────────────────────────
MISSING_REPLICAS_FILE="missing_replicas.txt"    # output from find_missing_replicas.py
USE_MANUAL_ARRAY=false
CHUNKS_DIR_OVERRIDE=""
SGE_SCRIPT_OVERRIDE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --manual)
            USE_MANUAL_ARRAY=true
            shift
            ;;
        --file)
            MISSING_REPLICAS_FILE="$2"
            shift 2
            ;;
        --chunks-dir)
            CHUNKS_DIR_OVERRIDE="$2"
            shift 2
            ;;
        --sge-script)
            SGE_SCRIPT_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--manual] [--file <path>] [--chunks-dir <path>] [--sge-script <path>]"
            echo "  --manual       Use hardcoded MUT_REP array instead of file"
            echo "  --file         Specify missing replicas file (default: missing_replicas.txt)"
            echo "  --chunks-dir   Specify mutation_chunks directory path (default: ./mutation_chunks)"
            echo "  --sge-script   Specify SGE worker script path (default: ./SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

##############################################################################

# ---------- Manual list of mutations : replica-ID  to regenerate ------------
# Format:  "<mut_id>:<replica_nr>"   (one per line, space-separated is fine)
# Only used when --manual flag is specified
MUT_REP=(
  "B-S-133:35"
  "B-T-166:33"
  "A-S-26:29"
  "A-S-30:27"
  "A-L-54:29"
  "A-S-92:27"
)

##############################################################################
#  Nothing below this line normally needs editing
##############################################################################
GLOBAL_SCRATCH_BASE="/wynton/scratch/kjander"
PROJECT_DIR="${GLOBAL_SCRATCH_BASE}/${PROJECT}"
CHUNK_DIR="${CHUNKS_DIR_OVERRIDE:-mutation_chunks}"
SGE_SCRIPT="${SGE_SCRIPT_OVERRIDE:-SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh}"

# Populate MUT_REP array from file or use manual array
if [[ "$USE_MANUAL_ARRAY" == "true" ]]; then
    echo "ℹ️   Using manual MUT_REP array (${#MUT_REP[@]} entries)"
else
    if [[ ! -f "$MISSING_REPLICAS_FILE" ]]; then
        echo "❌  Missing replicas file not found: $MISSING_REPLICAS_FILE"
        echo "    Run find_missing_replicas.py first, or use --manual flag"
        exit 2
    fi
    
    # Read file into array
    readarray -t MUT_REP < "$MISSING_REPLICAS_FILE"
    
    # Remove empty lines
    MUT_REP=("${MUT_REP[@]// /}")
    
    echo "📁  Loaded ${#MUT_REP[@]} entries from $MISSING_REPLICAS_FILE"
fi

if [[ ${#MUT_REP[@]} -eq 0 ]]; then
    echo "✅  No replicas to resubmit!"
    exit 0
fi

# Check if SGE script exists
if [[ ! -f "$SGE_SCRIPT" ]]; then
    echo "❌  SGE script not found: $SGE_SCRIPT"
    echo "    Use --sge-script to specify the path to SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
    exit 2
fi

echo "⏳  Resubmitting ${#MUT_REP[@]} replica(s)…"
for entry in "${MUT_REP[@]}"; do
    [[ -n "$entry" ]] || continue  # skip empty lines
    
    mut="${entry%%:*}"         # left of :
    repl="${entry##*:}"        # right of :

    # Convert mutation ID format to match chunk file naming scheme
    # Example: A-A25A -> A-A-25 (Chain-OriginalAA-Position)
    # Extract chain, original AA, and position from mutation ID
    if [[ $mut =~ ^([A-Z])-([A-Z])([0-9]+)([A-Z])$ ]]; then
        chain="${BASH_REMATCH[1]}"
        orig_aa="${BASH_REMATCH[2]}"
        position="${BASH_REMATCH[3]}"
        # Convert to chunk file format: Chain-OriginalAA-Position
        chunk_mut="${chain}-${orig_aa}-${position}"
    else
        # Fallback: use original mutation ID if format doesn't match
        chunk_mut="$mut"
    fi

    chunk_file="${CHUNK_DIR}/mutsite_${chunk_mut}.txt"
    [[ -f "$chunk_file" ]] || { echo "❌  $chunk_file not found (tried ${chunk_mut} from ${mut})"; exit 2; }

    # single-task array: -t <rep>-<rep>  (so SGE_TASK_ID == replica number)
    qsub -N "redo_${mut}_${repl}" \
         -t "${repl}-${repl}" \
         -pe smp ${CORES} \
         -l mem_free=${MEM_PER_CORE},scratch=${SCRATCH},h_rt=${H_RT} \
         "$SGE_SCRIPT" \
         "$PDB" "$chunk_file" "$mut" "$PROJECT" "$RESLIST"
done

echo "✅  All requested replicas resubmitted – monitor with:  watch qstat"