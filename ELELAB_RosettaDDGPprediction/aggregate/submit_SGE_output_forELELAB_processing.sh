#!/bin/bash
##############################################################################
#  submit_SGE_output_forELELAB_processing.sh – launch parallel aggregation of many run_* dirs
#
#  Usage:
#      ./submit_SGE_output_forELELAB_processing.sh <project> [agg_dir] [chunks_dir]
#
#  If chunks_dir is not provided, the script will look for mutation_chunks in:
#    1. Current directory
#    2. Base project directory
#    3. Parent directory of first run_* directory found
##############################################################################
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: $0 <project> [agg_dir] [chunks_dir]" >&2; exit 1; }

PROJECT="$1"
AGG_DIR="${2:-aggregated_flexddg}"
CHUNKS_DIR_OVERRIDE="${3:-}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-}"   # export MAX_CONCURRENCY=50 to cap, otherwise unlimited

BASE="/wynton/scratch/kjander/${PROJECT}"
RUN_LIST="$(mktemp "${BASE}/runlist.XXXX")"

# ---------------------------------------------------------------------------
# 1a. Check for metadata file and read parameters
# ---------------------------------------------------------------------------
METADATA_FILE="${BASE}/.rosetta_ddg_metadata.json"
if [[ -f "$METADATA_FILE" ]]; then
    echo "[INFO]  Found metadata file: $METADATA_FILE"
    # Extract useful paths from metadata using python (more reliable than bash for JSON)
    METADATA_INFO=$(python3 -c "
import json
with open('$METADATA_FILE', 'r') as f:
    data = json.load(f)
    print(data['submission_info']['pdb_file']['absolute_path'])
    print(data['submission_info']['residues_file']['absolute_path'])
    print(data['paths']['chunks_directory'])
    print(data['paths']['sge_script'])
    print(data['submission_info']['submission_directory'])
" 2>/dev/null || echo "")
    
    if [[ -n "$METADATA_INFO" ]]; then
        readarray -t METADATA_PATHS <<< "$METADATA_INFO"
        ORIGINAL_PDB="${METADATA_PATHS[0]}"
        ORIGINAL_RESLIST="${METADATA_PATHS[1]}"
        ORIGINAL_CHUNKS="${METADATA_PATHS[2]}"
        ORIGINAL_SGE="${METADATA_PATHS[3]}"
        ORIGINAL_SUBMISSION_DIR="${METADATA_PATHS[4]}"
        echo "[INFO]  Read paths from metadata:"
        echo "        PDB: $ORIGINAL_PDB"
        echo "        Chunks: $ORIGINAL_CHUNKS"
        echo "        SGE Script: $ORIGINAL_SGE"
    fi
else
    echo "[WARNING]  No metadata file found. Will search for files manually."
fi

# ---------------------------------------------------------------------------
# 1. Enumerate all run_*/flexddg directories
# ---------------------------------------------------------------------------
find "${BASE}" -maxdepth 2 -type d -name "flexddg" -path "${BASE}/run_*" \
     -print > "${RUN_LIST}"

NUM_RUNS=$(wc -l < "${RUN_LIST}")
[[ ${NUM_RUNS} -gt 0 ]] || { echo "No run_*/flexddg directories found." >&2; exit 2; }

echo "[INFO]  Found ${NUM_RUNS} runs."

# ---------------------------------------------------------------------------
# 1.5. Find and copy mutation_chunks directory to aggregation directory
# ---------------------------------------------------------------------------
DEST_DIR="${BASE}/${AGG_DIR}"
mkdir -p "${DEST_DIR}"

# Find mutation_chunks directory
CHUNKS_DIR=""
if [[ -n "${CHUNKS_DIR_OVERRIDE}" ]]; then
    if [[ -d "${CHUNKS_DIR_OVERRIDE}" ]]; then
        CHUNKS_DIR="${CHUNKS_DIR_OVERRIDE}"
        echo "[INFO]  Using specified chunks directory: ${CHUNKS_DIR}"
    else
        echo "[WARNING]  Specified chunks directory not found: ${CHUNKS_DIR_OVERRIDE}"
    fi
fi

# Try metadata path first
if [[ -z "${CHUNKS_DIR}" && -n "${ORIGINAL_CHUNKS:-}" && -d "${ORIGINAL_CHUNKS}" ]]; then
    CHUNKS_DIR="${ORIGINAL_CHUNKS}"
    echo "[INFO]  Using chunks directory from metadata: ${CHUNKS_DIR}"
fi

if [[ -z "${CHUNKS_DIR}" ]]; then
    # Search in common locations
    SEARCH_LOCATIONS=(
        "./mutation_chunks"
        "${BASE}/mutation_chunks"
    )
    
    # Add parent directory of first run
    if [[ ${NUM_RUNS} -gt 0 ]]; then
        FIRST_RUN=$(head -n1 "${RUN_LIST}")
        FIRST_RUN_PARENT=$(dirname $(dirname "${FIRST_RUN}"))
        SEARCH_LOCATIONS+=("${FIRST_RUN_PARENT}/mutation_chunks")
    fi
    
    for loc in "${SEARCH_LOCATIONS[@]}"; do
        if [[ -d "$loc" ]]; then
            CHUNKS_DIR="$loc"
            echo "[INFO]  Found mutation_chunks at: ${CHUNKS_DIR}"
            break
        fi
    done
fi

# Copy mutation_chunks if found
if [[ -n "${CHUNKS_DIR}" ]]; then
    if [[ ! -d "${DEST_DIR}/mutation_chunks" ]]; then
        echo "[INFO]  Copying mutation_chunks to aggregation directory..."
        cp -r "${CHUNKS_DIR}" "${DEST_DIR}/mutation_chunks"
    else
        echo "[INFO]  mutation_chunks already exists in aggregation directory"
    fi
else
    echo "[WARNING]  mutation_chunks directory not found. redo_replicas.sh will need --chunks-dir flag."
fi

# Copy SGE script if found
SGE_SCRIPT_NAME="SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
SGE_SCRIPT_FOUND=""

# Try metadata path first
if [[ -n "${ORIGINAL_SGE:-}" && -f "${ORIGINAL_SGE}" ]]; then
    SGE_SCRIPT_FOUND="${ORIGINAL_SGE}"
    echo "[INFO]  Using SGE script from metadata: ${SGE_SCRIPT_FOUND}"
else
    SGE_SEARCH_LOCATIONS=(
        "./${SGE_SCRIPT_NAME}"
        "${BASE}/${SGE_SCRIPT_NAME}"
    )

    # Add parent directory of first run and chunks directory if found
    if [[ ${NUM_RUNS} -gt 0 ]]; then
        FIRST_RUN=$(head -n1 "${RUN_LIST}")
        FIRST_RUN_PARENT=$(dirname $(dirname "${FIRST_RUN}"))
        SGE_SEARCH_LOCATIONS+=("${FIRST_RUN_PARENT}/${SGE_SCRIPT_NAME}")
    fi
    if [[ -n "${CHUNKS_DIR}" ]]; then
        CHUNKS_PARENT=$(dirname "${CHUNKS_DIR}")
        SGE_SEARCH_LOCATIONS+=("${CHUNKS_PARENT}/${SGE_SCRIPT_NAME}")
    fi

    for loc in "${SGE_SEARCH_LOCATIONS[@]}"; do
        if [[ -f "$loc" ]]; then
            SGE_SCRIPT_FOUND="$loc"
            echo "[INFO]  Found SGE script at: ${SGE_SCRIPT_FOUND}"
            break
        fi
    done
fi

if [[ -n "${SGE_SCRIPT_FOUND}" ]]; then
    if [[ ! -f "${DEST_DIR}/${SGE_SCRIPT_NAME}" ]]; then
        echo "[INFO]  Copying SGE script to aggregation directory..."
        cp "${SGE_SCRIPT_FOUND}" "${DEST_DIR}/${SGE_SCRIPT_NAME}"
    else
        echo "[INFO]  SGE script already exists in aggregation directory"
    fi
else
    echo "[WARNING]  SGE script not found. redo_replicas.sh will need --sge-script flag."
fi

# ---------------------------------------------------------------------------
# 1.6. Find and copy PDB files and residues.txt to aggregation directory
# ---------------------------------------------------------------------------
echo "[INFO]  Looking for input PDB files and residues.txt..."

# Try metadata paths first
if [[ -n "${ORIGINAL_PDB:-}" && -f "${ORIGINAL_PDB}" ]]; then
    pdb_basename=$(basename "${ORIGINAL_PDB}")
    if [[ ! -f "${DEST_DIR}/${pdb_basename}" ]]; then
        echo "[INFO]  Copying PDB file from metadata: ${pdb_basename}"
        cp "${ORIGINAL_PDB}" "${DEST_DIR}/"
    else
        echo "[INFO]  PDB file already exists: ${pdb_basename}"
    fi
    PDB_COPIED=true
else
    PDB_COPIED=false
fi

if [[ -n "${ORIGINAL_RESLIST:-}" && -f "${ORIGINAL_RESLIST}" && "${ORIGINAL_RESLIST}" != "residues.txt" ]]; then
    if [[ ! -f "${DEST_DIR}/residues.txt" ]]; then
        echo "[INFO]  Copying residues.txt from metadata"
        cp "${ORIGINAL_RESLIST}" "${DEST_DIR}/residues.txt"
    else
        echo "[INFO]  residues.txt already exists in aggregation directory"
    fi
    RESLIST_COPIED=true
else
    RESLIST_COPIED=false
fi

# If metadata didn't work, fall back to searching run directories
if [[ "$PDB_COPIED" == "false" || "$RESLIST_COPIED" == "false" ]]; then
    # Find PDB files in run directories
    PDB_FILES_FOUND=()
    RESIDUES_FILES_FOUND=()

    # Sample a few run directories to find common files
    SAMPLE_COUNT=0
    MAX_SAMPLES=5
    while IFS= read -r flexddg_dir && [[ $SAMPLE_COUNT -lt $MAX_SAMPLES ]]; do
        run_dir=$(dirname "$flexddg_dir")
        
        # Look for PDB files
        if [[ "$PDB_COPIED" == "false" ]]; then
            for pdb in "$run_dir"/*.pdb; do
                if [[ -f "$pdb" ]]; then
                    pdb_basename=$(basename "$pdb")
                    # Skip Rosetta output PDBs (usually contain _0001, _relaxed, etc.)
                    if [[ ! "$pdb_basename" =~ _[0-9]{4}\.pdb$ ]] && \
                       [[ ! "$pdb_basename" =~ _relaxed ]] && \
                       [[ ! "$pdb_basename" =~ _min ]]; then
                        PDB_FILES_FOUND+=("$pdb")
                    fi
                fi
            done
        fi
        
        # Look for residues.txt
        if [[ "$RESLIST_COPIED" == "false" && -f "$run_dir/residues.txt" ]]; then
            RESIDUES_FILES_FOUND+=("$run_dir/residues.txt")
        fi
        
        ((SAMPLE_COUNT++))
    done < "$RUN_LIST"

    # Copy unique PDB files
    if [[ "$PDB_COPIED" == "false" ]]; then
        declare -A seen_pdbs
        for pdb_path in "${PDB_FILES_FOUND[@]}"; do
            pdb_basename=$(basename "$pdb_path")
            if [[ -z "${seen_pdbs[$pdb_basename]:-}" ]]; then
                seen_pdbs["$pdb_basename"]=1
                if [[ ! -f "${DEST_DIR}/${pdb_basename}" ]]; then
                    echo "[INFO]  Copying PDB file: ${pdb_basename}"
                    cp "$pdb_path" "${DEST_DIR}/"
                else
                    echo "[INFO]  PDB file already exists: ${pdb_basename}"
                fi
            fi
        done

        if [[ ${#seen_pdbs[@]} -eq 0 ]]; then
            echo "[WARNING]  No input PDB files found. You'll need to copy them manually for redo_replicas.sh"
            echo "           Look for .pdb files in your original submission directory"
        fi
    fi

    # Copy residues.txt if found
    if [[ "$RESLIST_COPIED" == "false" && ${#RESIDUES_FILES_FOUND[@]} -gt 0 ]]; then
        if [[ ! -f "${DEST_DIR}/residues.txt" ]]; then
            echo "[INFO]  Copying residues.txt"
            cp "${RESIDUES_FILES_FOUND[0]}" "${DEST_DIR}/"
        else
            echo "[INFO]  residues.txt already exists in aggregation directory"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 1.7. Copy and update metadata file
# ---------------------------------------------------------------------------
if [[ -f "$METADATA_FILE" ]]; then
    echo "[INFO]  Copying metadata file to aggregation directory..."
    cp "$METADATA_FILE" "${DEST_DIR}/"
    
    # Update metadata with aggregation info
    TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    python3 -c "
import json
metadata_file = '${DEST_DIR}/.rosetta_ddg_metadata.json'
with open(metadata_file, 'r') as f:
    data = json.load(f)

# Add aggregation info
agg_info = {
    'timestamp': '${TIMESTAMP}',
    'aggregation_directory': '${DEST_DIR}',
    'source_project_directory': '${BASE}',
    'num_runs_aggregated': ${NUM_RUNS}
}
data['aggregations'].append(agg_info)

# Write updated metadata
with open(metadata_file, 'w') as f:
    json.dump(data, f, indent=2)
print('Updated metadata with aggregation info')
" || echo "[WARNING]  Failed to update metadata file"
fi

# ---------------------------------------------------------------------------
# 2. Submit array job – one task per run directory
# ---------------------------------------------------------------------------
ARRAY_JOB_RAW=$( \
  qsub -terse \
       -N "aggCopy_${PROJECT}" \
       -t 1-"${NUM_RUNS}" \
       ${MAX_CONCURRENCY:+-tc ${MAX_CONCURRENCY}} \
       -v PROJECT="${PROJECT}",AGG_DIR="${AGG_DIR}",RUN_LIST="${RUN_LIST}" \
       process_ddg_aggregate_one_run.sh )

# qsub -terse returns something like "123456.1-73:1" for array jobs;
# we only need the numeric job ID portion before the first dot.
ARRAY_JOB_ID=${ARRAY_JOB_RAW%%.*}

# ---------------------------------------------------------------------------
# 3. Submit finaliser job that depends on array completion
# ---------------------------------------------------------------------------
qsub -N "aggFinalize_${PROJECT}" \
     -hold_jid "${ARRAY_JOB_ID}" \
     -v PROJECT="${PROJECT}",AGG_DIR="${AGG_DIR}" \
     process_ddg_aggregate_finalize.sh

echo "[INFO]  Submitted array job (${ARRAY_JOB_ID}) and finaliser job."
echo "[INFO]  You can remove ${RUN_LIST} after the pipeline finishes." 