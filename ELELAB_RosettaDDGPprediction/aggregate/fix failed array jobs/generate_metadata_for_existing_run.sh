#!/bin/bash
##############################################################################
#  generate_metadata_for_existing_run.sh - Create metadata file for runs that
#                                          were created before the metadata
#                                          system was implemented
#
#  Usage:
#    bash generate_metadata_for_existing_run.sh [--project PROJECT] [--pdb PDB_FILE]
#
#  This script will try to infer parameters from the existing run structure
#  and prompt for any missing information.
##############################################################################
set -euo pipefail

# Default values
PROJECT=""
PDB_FILE=""
RESLIST="residues.txt"
OUTPUT_FILE=".rosetta_ddg_metadata.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --pdb)
            PDB_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--project PROJECT] [--pdb PDB_FILE] [--output FILE]"
            echo ""
            echo "Generate metadata file for existing Rosetta DDG runs"
            echo ""
            echo "Options:"
            echo "  --project  Project name (will try to infer from path if not provided)"
            echo "  --pdb      PDB file path (will search for .pdb files if not provided)"
            echo "  --output   Output metadata file (default: .rosetta_ddg_metadata.json)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔍 Analyzing existing run structure..."

# Try to infer project from current path
if [[ -z "$PROJECT" ]]; then
    CURRENT_PATH=$(pwd)
    if [[ "$CURRENT_PATH" =~ /wynton/scratch/[^/]+/([^/]+) ]]; then
        PROJECT="${BASH_REMATCH[1]}"
        echo "   Inferred project: $PROJECT"
    else
        echo "❓ Please enter the project name:"
        read -r PROJECT
    fi
fi

# Look for PDB files if not specified
if [[ -z "$PDB_FILE" ]]; then
    echo "   Searching for PDB files..."
    PDB_CANDIDATES=()
    
    # Search in current directory and run directories
    while IFS= read -r pdb; do
        basename_pdb=$(basename "$pdb")
        # Skip Rosetta output files
        if [[ ! "$basename_pdb" =~ _[0-9]{4}\.pdb$ ]] && \
           [[ ! "$basename_pdb" =~ _relaxed ]] && \
           [[ ! "$basename_pdb" =~ _min ]] && \
           [[ ! "$basename_pdb" =~ _0001 ]]; then
            PDB_CANDIDATES+=("$pdb")
        fi
    done < <(find . -maxdepth 3 -name "*.pdb" -type f 2>/dev/null | head -20)
    
    if [[ ${#PDB_CANDIDATES[@]} -eq 1 ]]; then
        PDB_FILE="${PDB_CANDIDATES[0]}"
        echo "   Found PDB: $PDB_FILE"
    elif [[ ${#PDB_CANDIDATES[@]} -gt 1 ]]; then
        echo "   Found multiple PDB candidates:"
        for i in "${!PDB_CANDIDATES[@]}"; do
            echo "     $((i+1)). ${PDB_CANDIDATES[$i]}"
        done
        echo "❓ Select PDB file (enter number):"
        read -r selection
        PDB_FILE="${PDB_CANDIDATES[$((selection-1))]}"
    else
        echo "❓ No PDB files found. Please enter the PDB filename:"
        read -r PDB_FILE
    fi
fi

# Look for positions file
echo "   Searching for positions file..."
POSFILE=""
if [[ -f "positions.txt" ]]; then
    POSFILE="positions.txt"
elif [[ -f "../positions.txt" ]]; then
    POSFILE="../positions.txt"
else
    # Search for files with position patterns
    POSFILE_CANDIDATE=$(find . -maxdepth 2 -name "*position*.txt" -o -name "*pos*.txt" 2>/dev/null | head -1)
    if [[ -n "$POSFILE_CANDIDATE" ]]; then
        POSFILE="$POSFILE_CANDIDATE"
    else
        echo "❓ Positions file not found. Please enter the filename (or press Enter to skip):"
        read -r POSFILE
    fi
fi

# Check for residues.txt
if [[ -f "residues.txt" ]]; then
    echo "   Found residues.txt"
    RESLIST_DEFAULT="false"
elif [[ -f "../residues.txt" ]]; then
    RESLIST="../residues.txt"
    RESLIST_DEFAULT="false"
else
    echo "   No residues.txt found (using standard amino acids)"
    RESLIST_DEFAULT="true"
fi

# Look for mutation_chunks
CHUNKS_DIR=""
if [[ -d "mutation_chunks" ]]; then
    CHUNKS_DIR="$(pwd)/mutation_chunks"
elif [[ -d "../mutation_chunks" ]]; then
    CHUNKS_DIR="$(realpath ../mutation_chunks)"
else
    echo "   No mutation_chunks directory found"
fi

# Look for SGE script
SGE_SCRIPT=""
SGE_NAME="SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh"
if [[ -f "$SGE_NAME" ]]; then
    SGE_SCRIPT="$(pwd)/$SGE_NAME"
elif [[ -f "../$SGE_NAME" ]]; then
    SGE_SCRIPT="$(realpath ../$SGE_NAME)"
fi

# Try to infer parameters from existing runs or logs
N_REPLICAS=35  # default
if [[ -d "flexddg" ]]; then
    # Count replicas in a mutation directory
    SAMPLE_MUT=$(find flexddg -maxdepth 1 -type d ! -path flexddg | head -1)
    if [[ -n "$SAMPLE_MUT" ]]; then
        REPLICA_COUNT=$(find "$SAMPLE_MUT" -maxdepth 1 -type d -regex '.*/[0-9]+$' | wc -l)
        if [[ $REPLICA_COUNT -gt 0 ]]; then
            N_REPLICAS=$REPLICA_COUNT
            echo "   Detected $N_REPLICAS replicas per mutation"
        fi
    fi
fi

# Generate metadata file
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
PDB_ABSOLUTE=$(realpath "$PDB_FILE" 2>/dev/null || echo "$PDB_FILE")
PDB_BASENAME=$(basename "$PDB_FILE")

cat > "$OUTPUT_FILE" <<EOF
{
  "project_name": "${PROJECT}",
  "submission_info": {
    "timestamp": "${TIMESTAMP}",
    "submission_directory": "$(pwd)",
    "pdb_file": {
      "absolute_path": "${PDB_ABSOLUTE}",
      "filename": "${PDB_BASENAME}"
    },
    "position_file": {
      "absolute_path": "${POSFILE}",
      "filename": "$(basename "${POSFILE:-positions.txt}")"
    },
    "residues_file": {
      "absolute_path": "${RESLIST}",
      "filename": "$(basename "$RESLIST")",
      "is_default": ${RESLIST_DEFAULT}
    },
    "user": "${USER}",
    "hostname": "$(hostname)",
    "note": "Generated retroactively for existing run"
  },
  "run_parameters": {
    "n_replicas": ${N_REPLICAS},
    "tc_max": 5,
    "cores_per_replica": 5,
    "mem_per_core": "4G",
    "scratch": "8G",
    "wall_time": "40:00:00"
  },
  "paths": {
    "project_directory": "/wynton/scratch/kjander/${PROJECT}",
    "chunks_directory": "${CHUNKS_DIR}",
    "sge_script": "${SGE_SCRIPT}"
  },
  "aggregations": []
}
EOF

echo ""
echo "✅ Generated metadata file: $OUTPUT_FILE"
echo ""
echo "📋 Summary:"
echo "   Project: $PROJECT"
echo "   PDB: $PDB_BASENAME"
echo "   Replicas: $N_REPLICAS"
echo ""
echo "⚠️  Note: Some parameters were set to defaults. Please edit $OUTPUT_FILE"
echo "   if you need to adjust cores, memory, or other settings." 