#!/bin/bash
##############################################################################
#  merge_redo_runs.sh – copy results from the *new* run_<mut_id>/flexddg/*
#                       folders (created by redo_replicas.sh) into the master
#                       aggregation directory  flexddg/   that already exists
#                       in the current directory.
#
#  Run this *inside*  …/[output directory from submit_SGE_output_forELELAB_processing.sh]
#
#  It:
#    • merges every   run_*/flexddg/<mut_id>/<replica>/   sub-directory
#      that is not yet present in  flexddg/<mut_id>/<replica>/
#    • appends the new lines from   run_*/flexddg/mutinfo.txt   to the master
#      flexddg/mutinfo.txt   (while keeping only the first appearance of each
#      line → no duplicates)
#    • BY DEFAULT: restores mutinfo.txt entries for successfully resubmitted
#      mutations (use --no-restore to disable this behavior)
##############################################################################
set -euo pipefail
shopt -s nullglob          # empty globs expand to nothing, not themselves

# ─── OPTIONS ────────────────────────────────────────────────────────────────
RESTORE_MUTINFO=true
MISSING_REPLICAS_FILE="missing_replicas.txt"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-restore)
            RESTORE_MUTINFO=false
            shift
            ;;
        --missing-file)
            MISSING_REPLICAS_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--no-restore] [--missing-file <path>]"
            echo "  --no-restore      Don't restore mutinfo.txt entries for resubmitted mutations"
            echo "  --missing-file    Specify missing replicas file (default: missing_replicas.txt)"
            echo ""
            echo "By default, this script will restore mutinfo.txt entries for mutations that"
            echo "were successfully resubmitted and are now complete."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

##############################################################################

MASTER_FLEX="flexddg"
MASTER_INFO="${MASTER_FLEX}/mutinfo.txt"

[[ -d "${MASTER_FLEX}" ]] ||
  { echo "❌  ${MASTER_FLEX} not found – run this in output directory from submit_SGE_output_forELELAB_processing.sh"; exit 2; }

echo "🔄  Merging new run_* directories into ${MASTER_FLEX}/ …"
tmp_info=$(mktemp)
merged_mutations=()

# -------- 1. copy missing mutation/replica folders --------------------------
for rundir in run_* ; do
    [[ -d "${rundir}/flexddg" ]] || continue   # skip if structure unexpected
    echo "   • scanning ${rundir}"
    for mutdir in "${rundir}/flexddg"/* ; do
        [[ -d "${mutdir}" ]] || continue      # skip mutinfo.txt etc.
        mut=$(basename "${mutdir}")
        dest_mut="${MASTER_FLEX}/${mut}"
        mkdir -p "${dest_mut}"

        mutation_merged=false
        for repldir in "${mutdir}"/* ; do
            [[ -d "${repldir}" ]] || continue
            repl=$(basename "${repldir}")

            dest_rep="${dest_mut}/${repl}"

            # Skip if this replica has already been merged
            if [[ -e "${dest_rep}" ]]; then
                continue
            fi

            echo "      → ${mut}/${repl}"

            # Create the replica directory first, then extract into it so
            # that the original directory hierarchy is preserved.
            mkdir -p "${dest_rep}"
            tar -C "${repldir}" -cf - . | tar -C "${dest_rep}" -xpf -
            mutation_merged=true
        done
        
        # Track mutations that had replicas merged
        if [[ "$mutation_merged" == "true" ]]; then
            merged_mutations+=("$mut")
        fi
    done

    # collect mutinfo lines (if any)
    if [[ -f "${rundir}/flexddg/mutinfo.txt" ]]; then
        cat "${rundir}/flexddg/mutinfo.txt" >> "${tmp_info}"
    fi
done

# -------- 2. merge mutinfo.txt (de-duplicate while preserving order) --------
if [[ -s "${tmp_info}" ]]; then
    echo "📝  Updating mutinfo.txt"
    # ensure master file exists
    : > "${MASTER_INFO}"
    # concatenate old + new, keep first appearance only
    awk '!seen[$0]++' "${MASTER_INFO}" "${tmp_info}" > "${MASTER_INFO}.new"
    mv "${MASTER_INFO}.new" "${MASTER_INFO}"
else
    echo "ℹ️   No new mutinfo lines found"
fi
rm -f "${tmp_info}"

# -------- 3. restore mutinfo.txt entries for completed mutations ------------
if [[ "$RESTORE_MUTINFO" == "true" ]] && [[ ${#merged_mutations[@]} -gt 0 ]]; then
    echo "🔄  Restoring mutinfo.txt entries for ${#merged_mutations[@]} resubmitted mutations..."
    
    # Find the backup or original mutinfo file
    backup_mutinfo=""
    if [[ -f "${MASTER_INFO}.bak" ]]; then
        backup_mutinfo="${MASTER_INFO}.bak"
        echo "   • found backup: ${backup_mutinfo}"
    elif [[ -f "${MASTER_INFO}.cleaned.txt" ]]; then
        # If we have a cleaned version, the original should be the uncleaned one
        original_mutinfo="${MASTER_INFO%%.cleaned.txt}.txt"
        if [[ -f "$original_mutinfo" ]]; then
            backup_mutinfo="$original_mutinfo"
            echo "   • found original: ${backup_mutinfo}"
        fi
    fi
    
    # Also check for the missing replicas file to validate mutations
    completed_mutations=()
    if [[ -f "$MISSING_REPLICAS_FILE" ]]; then
        echo "   • validating against $MISSING_REPLICAS_FILE"
        # Extract unique mutation IDs from the missing replicas file
        readarray -t missing_entries < "$MISSING_REPLICAS_FILE"
        declare -A expected_mutations
        for entry in "${missing_entries[@]}"; do
            [[ -n "$entry" ]] || continue
            mut="${entry%%:*}"
            expected_mutations["$mut"]=1
        done
        
        # Only restore mutations that were actually in the missing list
        for mut in "${merged_mutations[@]}"; do
            if [[ -n "${expected_mutations[$mut]:-}" ]]; then
                completed_mutations+=("$mut")
            fi
        done
    else
        echo "   • $MISSING_REPLICAS_FILE not found, restoring all merged mutations"
        completed_mutations=("${merged_mutations[@]}")
    fi
    
    if [[ ${#completed_mutations[@]} -gt 0 ]]; then
        if [[ -n "$backup_mutinfo" ]]; then
            echo "   • restoring entries for: ${completed_mutations[*]}"
            tmp_restore=$(mktemp)
            
            # Extract entries for completed mutations from backup
            for mut in "${completed_mutations[@]}"; do
                grep ",$mut," "$backup_mutinfo" >> "$tmp_restore" 2>/dev/null || true
            done
            
            if [[ -s "$tmp_restore" ]]; then
                # Append to current mutinfo and deduplicate
                cat "$MASTER_INFO" "$tmp_restore" | awk '!seen[$0]++' > "${MASTER_INFO}.new"
                mv "${MASTER_INFO}.new" "$MASTER_INFO"
                echo "   ✅  restored $(wc -l < "$tmp_restore") mutinfo entries"
            else
                echo "   ⚠️   no matching entries found in backup"
            fi
            rm -f "$tmp_restore"
        else
            echo "   ⚠️   no backup mutinfo file found – entries cannot be restored"
            echo "        (looked for: ${MASTER_INFO}.bak and original mutinfo.txt)"
        fi
    else
        echo "   ℹ️   no mutations to restore (not found in missing replicas list)"
    fi
else
    echo "ℹ️   mutinfo.txt restoration skipped (--no-restore or no merged mutations)"
fi

echo "✅  Merge complete."
echo "   You may now rerun rosetta_ddg_aggregate or any downstream analysis."