#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -j y
#$ -l mem_free=25G
#$ -l scratch=50G
#$ -l h_rt=30:00:00
#$ -r y
#$ -pe smp 24

# Usage: qsub run_mutatex.sh input_model.pdb

# Validate input argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 input_model.pdb"
    exit 1
fi

INPUT_PDB="$1"
POSLIST="position_list.txt"

# Check for required input files
if [ ! -f "$INPUT_PDB" ]; then
    echo "Error: Input PDB file '$INPUT_PDB' not found."
    exit 2
fi

if [ ! -f "$POSLIST" ]; then
    echo "Error: Position list file '$POSLIST' not found in current directory."
    exit 3
fi

# Activate environment
source /wynton/home/craik/kjander/mutateX/mutatex/mutatex-env/bin/activate

# Set FoldX binary
export FOLDX_BINARY=/wynton/home/craik/kjander/mutateX/foldx5Linux64/foldx_20251231

# Run MutateX
TEMPLATE_DIR="/wynton/home/craik/kjander/mutateX/mutatex/templates/foldxsuite5"

mutatex "$INPUT_PDB" \
    --np 20 \
    --verbose \
    --foldx-log \
    --foldx-version suite5 \
    --binding-energy \
    --poslist "$POSLIST" \
    --repair "$TEMPLATE_DIR/repair_runfile_template.txt" \
    --mutate "$TEMPLATE_DIR/mutate_runfile_template.txt" \
    --binding "$TEMPLATE_DIR/interface_runfile_template.txt"

# End-of-job diagnostics
echo "Job finished on $(hostname) at $(date)"
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"
