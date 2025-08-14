#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -j y
#$ -l mem_free=1G
#$ -l scratch=2G
#$ -l h_rt=00:50:00
#$ -r y

echo "===== Disk Usage Check Started ====="
date
hostname

# Limit to depth 3 and report disk *usage* (compressed, relevant for quota)
echo -e "\nTop 30 largest directories/files in $HOME (max depth: 3):"
du -x -d 3 -h "$HOME" 2>/dev/null | sort -hr | head -n 70

echo -e "\nDetailed (compressed) disk usage at byte resolution (top 30):"
du -x -d 3 --block-size=1 "$HOME" 2>/dev/null | sort -nr | head -n 70 | awk '{ printf "%10.2f MiB\t%s\n", $1/1048576, $2 }'

echo -e "\n===== Job Finished ====="
date

# Show job stats
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"
