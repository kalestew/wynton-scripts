#!/bin/bash
##############################################################################
#  fix_and_resubmit_workflow.sh – Complete workflow for handling missing
#                                  replicas in Rosetta DDG saturation runs
#
#  This script orchestrates the entire process:
#  1. Identifies missing replicas and cleans mutinfo.txt
#  2. Resubmits missing replicas as SGE jobs
#  3. Waits for jobs to complete (with monitoring)
#  4. Merges results back and restores mutinfo.txt entries
#
#  USAGE:
#    bash fix_and_resubmit_workflow.sh [--nstruct N] [--no-wait] [--help]
#
#  Run this from the run_<id>/flexddg parent directory.
##############################################################################
set -euo pipefail

# ─── DEFAULT PARAMETERS ─────────────────────────────────────────────────────
NSTRUCT=35
WAIT_FOR_JOBS=true
FLEX_DIR="flexddg"
MUTINFO_FILE="mutinfo.txt"
MISSING_REPLICAS_FILE="missing_replicas.txt"
CHUNKS_DIR=""
SGE_SCRIPT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --nstruct)
            NSTRUCT="$2"
            shift 2
            ;;
        --no-wait)
            WAIT_FOR_JOBS=false
            shift
            ;;
        --flex)
            FLEX_DIR="$2"
            shift 2
            ;;
        --chunks-dir)
            CHUNKS_DIR="$2"
            shift 2
            ;;
        --sge-script)
            SGE_SCRIPT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--nstruct N] [--no-wait] [--flex DIR] [--chunks-dir DIR] [--sge-script PATH]"
            echo ""
            echo "  --nstruct N      Number of expected replicas per mutation (default: 35)"
            echo "  --no-wait        Don't wait for jobs to complete before merging"
            echo "  --flex DIR       Path to flexddg directory (default: flexddg)"
            echo "  --chunks-dir DIR Path to mutation_chunks directory (optional)"
            echo "  --sge-script PATH Path to SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
            echo ""
            echo "This script will:"
            echo "  1. Find missing replicas and clean mutinfo.txt"
            echo "  2. Resubmit missing replicas as SGE jobs"
            echo "  3. Wait for jobs to complete (unless --no-wait)"
            echo "  4. Merge results and restore mutinfo.txt entries"
            echo ""
            echo "Requirements:"
            echo "  • find_missing_replicas.py"
            echo "  • redo_replicas.sh"
            echo "  • merge_redo_runs.sh"
            echo "  • All configured with proper paths/parameters"
            echo ""
            echo "Note: If mutation_chunks directory or SGE script are not found automatically,"
            echo "      use --chunks-dir and --sge-script to specify their locations."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

##############################################################################

echo "🔍  Starting missing replica workflow..."
echo "    Expected replicas per mutation: $NSTRUCT"
echo "    Flex directory: $FLEX_DIR"
echo "    Wait for jobs: $WAIT_FOR_JOBS"
if [[ -n "$CHUNKS_DIR" ]]; then
    echo "    Chunks directory: $CHUNKS_DIR"
fi
if [[ -n "$SGE_SCRIPT" ]]; then
    echo "    SGE script: $SGE_SCRIPT"
fi
echo ""

# ─── CHECK FOR METADATA FILE ────────────────────────────────────────────────
METADATA_FILE=".rosetta_ddg_metadata.json"
METADATA_PATHS=()
if [[ -f "$METADATA_FILE" ]]; then
    echo "📋  Found metadata file - reading original paths..."
    # Extract paths from metadata
    METADATA_INFO=$(python3 -c "
import json
try:
    with open('$METADATA_FILE', 'r') as f:
        data = json.load(f)
        print(data['submission_info']['pdb_file']['absolute_path'])
        print(data['submission_info']['residues_file']['absolute_path'])
        print(data['paths']['chunks_directory'])
        print(data['paths']['sge_script'])
        print(data['project_name'])
        print(data['submission_info']['residues_file']['is_default'])
except Exception as e:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$METADATA_INFO" ]]; then
        readarray -t METADATA_PATHS <<< "$METADATA_INFO"
        META_PDB="${METADATA_PATHS[0]}"
        META_RESLIST="${METADATA_PATHS[1]}"
        META_CHUNKS="${METADATA_PATHS[2]}"
        META_SGE="${METADATA_PATHS[3]}"
        META_PROJECT="${METADATA_PATHS[4]}"
        META_RESLIST_DEFAULT="${METADATA_PATHS[5]}"
        
        echo "    ✓ Project: $META_PROJECT"
        echo "    ✓ PDB: $(basename "$META_PDB")"
        echo "    ✓ Original paths recorded"
        echo ""
    fi
fi

# ─── CHECK FOR REQUIRED FILES ───────────────────────────────────────────────
echo "🔍  Checking for required files..."
MISSING_FILES=()
WARNINGS=()

# Check for redo_replicas.sh script
if [[ ! -f "redo_replicas.sh" ]]; then
    # Look in common locations
    REDO_SCRIPT_LOCATIONS=(
        "./fix failed array jobs/redo_replicas.sh"
        "../redo_replicas.sh"
        "../../SGE submission scripts/aggregate/fix failed array jobs/redo_replicas.sh"
    )
    REDO_FOUND=false
    for loc in "${REDO_SCRIPT_LOCATIONS[@]}"; do
        if [[ -f "$loc" ]]; then
            echo "    ✓ Found redo_replicas.sh at: $loc"
            # Copy it to current directory
            cp "$loc" ./redo_replicas.sh
            REDO_FOUND=true
            break
        fi
    done
    if [[ "$REDO_FOUND" == "false" ]]; then
        MISSING_FILES+=("redo_replicas.sh")
    fi
else
    echo "    ✓ redo_replicas.sh found"
fi

# Check redo_replicas.sh for hardcoded PDB file
if [[ -f "redo_replicas.sh" ]]; then
    PDB_LINE=$(grep -E '^PDB=' redo_replicas.sh | head -1 || true)
    if [[ -n "$PDB_LINE" ]]; then
        # Extract PDB filename from the line
        PDB_FILE=$(echo "$PDB_LINE" | sed 's/PDB=//; s/"//g; s/'"'"'//g' | awk '{print $1}')
        if [[ -n "$PDB_FILE" && ! -f "$PDB_FILE" ]]; then
            # Try to copy from metadata path
            if [[ -n "${META_PDB:-}" && -f "${META_PDB}" ]]; then
                meta_pdb_basename=$(basename "${META_PDB}")
                if [[ "$PDB_FILE" == "$meta_pdb_basename" || "$PDB_FILE" == "$(basename "$PDB_FILE")" ]]; then
                    echo "    ℹ️  Copying PDB file from metadata: $meta_pdb_basename"
                    cp "${META_PDB}" "./"
                    if [[ -f "$meta_pdb_basename" ]]; then
                        echo "    ✓ PDB file copied successfully"
                    fi
                else
                    WARNINGS+=("PDB file in redo_replicas.sh ('$PDB_FILE') doesn't match metadata ('$meta_pdb_basename')")
                    MISSING_FILES+=("$PDB_FILE")
                fi
            else
                WARNINGS+=("PDB file '$PDB_FILE' referenced in redo_replicas.sh not found in current directory")
                MISSING_FILES+=("$PDB_FILE")
            fi
        elif [[ -n "$PDB_FILE" ]]; then
            echo "    ✓ PDB file found: $PDB_FILE"
        fi
    fi
fi

# Check for residues.txt if referenced
if [[ -f "redo_replicas.sh" ]]; then
    RESLIST_LINE=$(grep -E '^RESLIST=' redo_replicas.sh | head -1 || true)
    if [[ -n "$RESLIST_LINE" ]]; then
        RESLIST_FILE=$(echo "$RESLIST_LINE" | sed 's/RESLIST=//; s/"//g; s/'"'"'//g' | awk '{print $1}')
        if [[ -n "$RESLIST_FILE" && "$RESLIST_FILE" != "residues.txt" && ! -f "$RESLIST_FILE" ]]; then
            # Try to copy from metadata path
            if [[ -n "${META_RESLIST:-}" && -f "${META_RESLIST}" && "${META_RESLIST}" != "residues.txt" ]]; then
                echo "    ℹ️  Copying residues file from metadata"
                cp "${META_RESLIST}" "./${RESLIST_FILE}"
            else
                WARNINGS+=("Residue list file '$RESLIST_FILE' referenced in redo_replicas.sh not found")
                MISSING_FILES+=("$RESLIST_FILE")
            fi
        elif [[ "$RESLIST_FILE" == "residues.txt" ]]; then
            if [[ "${META_RESLIST_DEFAULT,,}" == "true" ]]; then
                echo "    ℹ️  residues.txt not needed (using default residues)"
            elif [[ ! -f "residues.txt" ]]; then
                if [[ -n "${META_RESLIST:-}" && -f "${META_RESLIST}" ]]; then
                    echo "    ℹ️  Copying residues.txt from metadata"
                    cp "${META_RESLIST}" "./residues.txt"
                else
                    echo "    ℹ️  residues.txt not found (may not be needed if running without custom residue list)"
                fi
            fi
        elif [[ -n "$RESLIST_FILE" && -f "$RESLIST_FILE" ]]; then
            echo "    ✓ Residue list found: $RESLIST_FILE"
        fi
    fi
fi

# Check for mutation_chunks directory
if [[ -z "$CHUNKS_DIR" ]]; then
    # Try metadata path first
    if [[ -n "${META_CHUNKS:-}" && -d "${META_CHUNKS}" ]]; then
        CHUNKS_DIR="${META_CHUNKS}"
        echo "    ✓ mutation_chunks directory found (from metadata)"
    elif [[ -d "mutation_chunks" ]]; then
        CHUNKS_DIR="mutation_chunks"
        echo "    ✓ mutation_chunks directory found"
    else
        WARNINGS+=("mutation_chunks directory not found (required for resubmission)")
    fi
else
    if [[ ! -d "$CHUNKS_DIR" ]]; then
        MISSING_FILES+=("$CHUNKS_DIR (directory)")
    else
        echo "    ✓ Chunks directory found: $CHUNKS_DIR"
    fi
fi

# Check for SGE script
if [[ -z "$SGE_SCRIPT" ]]; then
    SGE_SCRIPT="SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
    # Try metadata path first
    if [[ -n "${META_SGE:-}" && -f "${META_SGE}" ]]; then
        # Copy from metadata location
        echo "    ✓ Found SGE script from metadata, copying..."
        cp "${META_SGE}" "./${SGE_SCRIPT}"
    elif [[ ! -f "$SGE_SCRIPT" ]]; then
        WARNINGS+=("SGE script '$SGE_SCRIPT' not found (required for job submission)")
    else
        echo "    ✓ SGE script found: $SGE_SCRIPT"
    fi
else
    if [[ ! -f "$SGE_SCRIPT" ]]; then
        MISSING_FILES+=("$SGE_SCRIPT")
    else
        echo "    ✓ SGE script found: $SGE_SCRIPT"
    fi
fi

# Check for other required scripts
REQUIRED_SCRIPTS=(
    "find_missing_replicas.py"
    "merge_redo_runs.sh"
)
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        # Try to find and copy from common locations
        SCRIPT_LOCATIONS=(
            "./fix failed array jobs/$script"
            "../$script"
            "../../SGE submission scripts/aggregate/fix failed array jobs/$script"
        )
        SCRIPT_FOUND=false
        for loc in "${SCRIPT_LOCATIONS[@]}"; do
            if [[ -f "$loc" ]]; then
                echo "    ✓ Found $script at: $loc"
                cp "$loc" ./"$script"
                SCRIPT_FOUND=true
                break
            fi
        done
        if [[ "$SCRIPT_FOUND" == "false" ]]; then
            MISSING_FILES+=("$script")
        fi
    else
        echo "    ✓ $script found"
    fi
done

# Report missing files and warnings
if [[ ${#MISSING_FILES[@]} -gt 0 || ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️   IMPORTANT: Required files or directories are missing!"
    echo ""
    
    if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
        echo "❌  Missing required files:"
        for file in "${MISSING_FILES[@]}"; do
            echo "    • $file"
        done
        echo ""
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "⚠️   Warnings:"
        for warning in "${WARNINGS[@]}"; do
            echo "    • $warning"
        done
        echo ""
    fi
    
    echo "📋  To fix this issue, you need to have the following files in the current directory:"
    echo "    1. The original PDB file used in the initial submission"
    echo "    2. The residues.txt file (if used in original submission)"
    echo "    3. The mutation_chunks directory from the original submission"
    echo "    4. The SGE submission script (SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh)"
    echo ""
    echo "🔧  Suggested fix:"
    
    # Provide specific commands if metadata is available
    if [[ ${#METADATA_PATHS[@]} -gt 0 ]]; then
        echo "    Based on the metadata file, you can copy the required files with these commands:"
        echo ""
        
        # PDB file
        if [[ -n "${META_PDB:-}" && -f "${META_PDB}" ]]; then
            echo "    # Copy PDB file"
            echo "    cp \"${META_PDB}\" ."
        fi
        
        # Residues file (if not default)
        if [[ -n "${META_RESLIST:-}" && -f "${META_RESLIST}" && "${META_RESLIST_DEFAULT,,}" != "true" ]]; then
            echo "    # Copy residues file"
            echo "    cp \"${META_RESLIST}\" ."
        fi
        
        # Chunks directory
        if [[ -n "${META_CHUNKS:-}" && -d "${META_CHUNKS}" ]]; then
            echo "    # Copy mutation chunks"
            echo "    cp -r \"${META_CHUNKS}\" ."
        fi
        
        # SGE script
        if [[ -n "${META_SGE:-}" && -f "${META_SGE}" ]]; then
            echo "    # Copy SGE script"
            echo "    cp \"${META_SGE}\" ."
        fi
        echo ""
    else
        echo "    If you're in the aggregated directory (e.g., /wynton/scratch/kjander/PROJECT/aggregated_flexddg),"
        echo "    copy these files from your original submission directory:"
        echo ""
        echo "    cp /path/to/original/submission/*.pdb ."
        echo "    cp /path/to/original/submission/residues.txt . # if applicable"
        echo "    cp -r /path/to/original/submission/mutation_chunks ."
        echo "    cp /path/to/original/submission/SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh ."
        echo ""
    fi
    
    echo "    Note: The submit_SGE_output_forELELAB_processing.sh script should have copied"
    echo "    mutation_chunks and the SGE script automatically. If they're missing, check"
    echo "    the original submission directory."
    echo ""
    
    # Ask user if they want to continue
    if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
        echo "❓  Critical files are missing. Do you want to continue anyway? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Exiting. Please ensure all required files are present and try again."
            exit 1
        fi
    fi
fi
echo ""

# ─── STEP 1: Find missing replicas ──────────────────────────────────────────
echo "🔍  STEP 1: Finding missing replicas..."
if ! python3 find_missing_replicas.py --flex "$FLEX_DIR" --nstruct "$NSTRUCT" --inplace -v; then
    echo "❌  Failed to find missing replicas"
    exit 1
fi

# Check if there are any missing replicas
if [[ ! -f "$MISSING_REPLICAS_FILE" ]] || [[ ! -s "$MISSING_REPLICAS_FILE" ]]; then
    echo "✅  No missing replicas found. Workflow complete!"
    exit 0
fi

missing_count=$(wc -l < "$MISSING_REPLICAS_FILE")
echo "📋  Found $missing_count missing replicas"
echo ""

# ─── STEP 2: Resubmit missing replicas ──────────────────────────────────────
echo "🚀  STEP 2: Resubmitting missing replicas..."
REDO_ARGS="--file $MISSING_REPLICAS_FILE"
if [[ -n "$CHUNKS_DIR" ]]; then
    REDO_ARGS="$REDO_ARGS --chunks-dir $CHUNKS_DIR"
fi
if [[ -n "$SGE_SCRIPT" ]]; then
    REDO_ARGS="$REDO_ARGS --sge-script $SGE_SCRIPT"
fi
if ! bash redo_replicas.sh $REDO_ARGS; then
    echo "❌  Failed to resubmit replicas"
    exit 1
fi
echo ""

# ─── STEP 3: Wait for jobs (optional) ───────────────────────────────────────
if [[ "$WAIT_FOR_JOBS" == "true" ]]; then
    echo "⏳  STEP 3: Waiting for jobs to complete..."
    echo "    Use Ctrl+C to skip waiting and run merge manually later"
    echo ""
    
    # Extract unique mutation IDs for job monitoring
    readarray -t missing_entries < "$MISSING_REPLICAS_FILE"
    declare -A job_mutations
    for entry in "${missing_entries[@]}"; do
        [[ -n "$entry" ]] || continue
        mut="${entry%%:*}"
        job_mutations["$mut"]=1
    done
    
    # Monitor jobs
    while true; do
        # Count running jobs that match our mutation pattern
        running_jobs=0
        for mut in "${!job_mutations[@]}"; do
            job_count=$(qstat -u "$USER" 2>/dev/null | grep -c "redo_${mut}_" || true)
            ((running_jobs += job_count))
        done
        
        if [[ $running_jobs -eq 0 ]]; then
            echo "✅  All jobs completed!"
            break
        fi
        
        echo "    $running_jobs jobs still running... ($(date '+%H:%M:%S'))"
        sleep 30
    done
    echo ""
else
    echo "⏭️   STEP 3: Skipping job wait (--no-wait specified)"
    echo "    Run the following command manually after jobs complete:"
    echo "    bash merge_redo_runs.sh --missing-file $MISSING_REPLICAS_FILE"
    echo ""
    exit 0
fi

# ─── STEP 4: Merge results ──────────────────────────────────────────────────
echo "🔄  STEP 4: Merging results and restoring mutinfo.txt..."
if ! bash merge_redo_runs.sh --missing-file "$MISSING_REPLICAS_FILE"; then
    echo "❌  Failed to merge results"
    exit 1
fi
echo ""

# ─── STEP 5: Cleanup and summary ────────────────────────────────────────────
echo "🧹  STEP 5: Cleanup and summary..."
final_missing_count=0
if python3 find_missing_replicas.py --flex "$FLEX_DIR" --nstruct "$NSTRUCT" -v > /dev/null 2>&1; then
    if [[ -f "$MISSING_REPLICAS_FILE" ]] && [[ -s "$MISSING_REPLICAS_FILE" ]]; then
        final_missing_count=$(wc -l < "$MISSING_REPLICAS_FILE")
    fi
fi

echo ""
echo "✅  WORKFLOW COMPLETE!"
echo "    • Started with: $missing_count missing replicas"
echo "    • Remaining: $final_missing_count missing replicas"
echo "    • Fixed: $((missing_count - final_missing_count)) replicas"
echo ""

if [[ $final_missing_count -gt 0 ]]; then
    echo "⚠️   Some replicas are still missing. You may need to:"
    echo "    • Check SGE job logs for errors"
    echo "    • Rerun this workflow to retry failed jobs"
    echo "    • Manually investigate specific mutations"
else
    echo "🎉  All replicas are now complete!"
    echo "    You can proceed with rosetta_ddg_aggregate or downstream analysis."
fi 