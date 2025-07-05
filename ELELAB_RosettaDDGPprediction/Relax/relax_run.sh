#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -j y
#$ -l mem_free=8G
#$ -l scratch=20G
#$ -l h_rt=2:00:00
#$ -r y

# === Handle input structure ===
INPUT_STRUCTURE="$1"

if [[ -z "$INPUT_STRUCTURE" ]]; then
  echo "Error: No input structure provided. Use qsub -F \"your_structure.pdb\""
  exit 1
fi

# === Activate your Rosetta environment ===
source /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/bin/activate

# === Run Rosetta Relax with the provided structure ===
/programs/x86_64-linux/rosetta/3.12/main/source/bin/relax.linuxgccrelease \
  -relax:constrain_relax_to_start_coords \
  -relax:coord_constrain_sidechains \
  -relax:ramp_constraints false \
  -s "$INPUT_STRUCTURE" \
  @relax_flags

# === Final status output ===
date
hostname

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"
