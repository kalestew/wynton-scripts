#!/bin/bash
# monitor_qstat.sh
# This script monitors your qstat output every 5 seconds.
# It displays your job status (for the current user) or a message if no jobs are running or queued.

while true; do
    clear
    echo "Job Monitoring - $(date)"
    echo "-------------------------------------"
    
    # Get full qstat output for current user
    qstat_output=$(qstat -u "$(whoami)")
    
    # Remove header lines (first two lines) to check for job rows
    job_rows=$(echo "$qstat_output" | sed '1,2d')
    
    if [ -z "$job_rows" ]; then
        echo "No jobs running or queued."
    else
        # Print the entire qstat output (including header) for context
        echo "$qstat_output"
    fi

    sleep 35
done
