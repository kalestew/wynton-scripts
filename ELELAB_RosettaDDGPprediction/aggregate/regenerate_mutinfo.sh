#!/bin/bash
##############################################################################
#  regenerate_mutinfo.sh – rebuild the master flexddg/mutinfo.txt file
#                          after it was accidentally truncated or deleted.
#
#  HOW TO USE
#  ----------
#  The script auto-detects your location and finds run directories:
#
#  Option A: Run from the project directory containing run_* folders:
#          /wynton/scratch/<user>/<project>/
#              run_0001/   run_0002/   …   aggregated_flexddg/
#          bash regenerate_mutinfo.sh
#
#  Option B: Run from within an aggregation directory:
#          /wynton/scratch/<user>/<project>/WedTarCopyRegular1/
#              flexddg/    (contains mutinfo.txt to rebuild)
#          bash regenerate_mutinfo.sh
#          (automatically looks for ../run_* and writes to ./flexddg/)
#
#  You can also supply optional arguments:                               
#          bash regenerate_mutinfo.sh [AGG_DIR] [RUN_GLOB]
#      where
#          AGG_DIR   – directory that holds flexddg/ (auto-detected if not specified)
#          RUN_GLOB  – pattern that matches the run directories (default: run_*)
#
#  RESULT                                                                    
#  ------                                                                    
#  The script collects every   ${RUN_DIR}/flexddg/mutinfo.txt   file,        
#  concatenates all lines, removes duplicates while preserving the order of  
#  first appearance, and writes the rebuilt list to the target flexddg/mutinfo.txt
#
#  The previous mutinfo.txt (if any) is backed up with a timestamp suffix.   
##############################################################################
set -euo pipefail
shopt -s nullglob          # empty globs expand to nothing, not themselves

# Auto-detect directory structure
if [[ -d "flexddg" ]]; then
    # We're in an aggregation directory (like WedTarCopyRegular1/)
    AGG_DIR="${1:-.}"
    RUN_GLOB="${2:-../run_*}"
    echo "🔍  Auto-detected: running from aggregation directory"
    echo "    Will look for runs in: ${RUN_GLOB}"
    echo "    Will update: ${AGG_DIR}/flexddg/mutinfo.txt"
else
    # We're in the parent project directory
    AGG_DIR="${1:-aggregated_flexddg}"
    RUN_GLOB="${2:-run_*}"
    echo "🔍  Auto-detected: running from project directory"
    echo "    Will look for runs in: ${RUN_GLOB}"
    echo "    Will update: ${AGG_DIR}/flexddg/mutinfo.txt"
fi

# Normalize paths to prevent double slashes
AGG_DIR="${AGG_DIR%/}"  # Remove trailing slash if present
MASTER_FLEX="${AGG_DIR}/flexddg"
MASTER_INFO="${MASTER_FLEX}/mutinfo.txt"

[[ -d "${MASTER_FLEX}" ]] || {
    echo "❌  ${MASTER_FLEX} not found." >&2
    echo "    Run this in the project directory that contains ${AGG_DIR}/flexddg/" >&2
    exit 2
}

echo ""
echo "🔄  Rebuilding mutinfo.txt from ${RUN_GLOB}/flexddg/mutinfo.txt …"

tmp_info=$(mktemp)

# -------- Collect mutinfo lines from every run -----------------------------
for runflex in ${RUN_GLOB}/flexddg ; do
    [[ -f "${runflex}/mutinfo.txt" ]] || continue
    echo "   • adding ${runflex}/mutinfo.txt"
    cat "${runflex}/mutinfo.txt" >> "${tmp_info}"
done

if [[ ! -s "${tmp_info}" ]]; then
    echo "❌  No mutinfo.txt files found via pattern:  ${RUN_GLOB}/flexddg/mutinfo.txt" >&2
    rm -f "${tmp_info}"
    exit 3
fi

# -------- De-duplicate while preserving original order ---------------------
if [[ -f "${MASTER_INFO}" ]]; then
    stamp="$(date +%Y%m%d_%H%M%S)"
    backup_file="${MASTER_INFO}.bak_${stamp}"
    mv "${MASTER_INFO}" "${backup_file}"
    echo "🗄️   Backed up existing mutinfo.txt → ${backup_file}"
fi

mkdir -p "${MASTER_FLEX}"  # ensure directory exists
awk '!seen[$0]++' "${tmp_info}" > "${MASTER_INFO}"
rm -f "${tmp_info}"

line_count=$(wc -l < "${MASTER_INFO}")
echo "✅  Rebuilt ${MASTER_INFO} (${line_count} lines)" 