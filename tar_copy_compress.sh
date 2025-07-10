#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -j y
#$ -l mem_free=8G
#$ -l h_rt=100:00:00
#$ -r y

SOURCE_DIR="/wynton/scratch/kjander/FINAL_FULL_41D1_Array_jun24thLate/WedTarCopyRegular1"
OUTPUT_DIR="/wynton/scratch/kjander"  # Specify where you want the output
TAR_NAME="WedTarCopyRegular1.tar.gz"

echo "Starting compressed tar creation..."
echo "Source: $SOURCE_DIR"
echo "Output: $OUTPUT_DIR/$TAR_NAME"
date

# Compressed tar with specific output location
tar -czf "$OUTPUT_DIR/$TAR_NAME" "$SOURCE_DIR"

echo "Compressed tar creation completed"
echo "Final file size:"
ls -lh "$OUTPUT_DIR/$TAR_NAME"
date

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"