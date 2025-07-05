#!/bin/bash

set -euo pipefail

MERGED="combined_flexddg"
MUTINFO="${MERGED}/mutinfo.txt"
mkdir -p "$MERGED"

# Clear or initialize the combined mutinfo
: > "$MUTINFO"

# Loop over each run directory
for flexddg_dir in run_*/flexddg; do
    [ -d "$flexddg_dir" ] || continue

    echo "🔍 Processing $flexddg_dir"

    # Copy all mutation result subdirs (B-R213A, B-R213C, ...)
    for mutsub in "$flexddg_dir"/*; do
        [ -d "$mutsub" ] || continue
        mutname=$(basename "$mutsub")

        if [ -e "$MERGED/$mutname" ]; then
            echo "⚠️  Skipping duplicate: $mutname"
            continue
        fi

        echo "📁 Copying $mutname → $MERGED/"
        cp -r "$mutsub" "$MERGED/$mutname"
    done

    # Append mutinfo.txt contents
    if [ -f "$flexddg_dir/mutinfo.txt" ]; then
        cat "$flexddg_dir/mutinfo.txt" >> "$MUTINFO"
    else
        echo "⚠️  Warning: No mutinfo.txt found in $flexddg_dir"
    fi
done

echo "✅ Combined flexddg data written to: $MERGED"
echo "📝 Combined mutinfo written to: $MUTINFO"
