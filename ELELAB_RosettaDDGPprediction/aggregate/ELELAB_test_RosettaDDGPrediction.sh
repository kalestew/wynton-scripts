#!/bin/bash
##############################################################################
#  ELELAB_test_RosettaDDGPrediction.sh  –  test the results of the 
#                      RosettaDDGPrediction saturation run.
#
#  HOW TO USE
#  
#  4.  Run    bash ELELAB_test_RosettaDDGPrediction.sh          – or –
#             qsub ELELAB_test_RosettaDDGPrediction.sh
##############################################################################

source /programs/sbgrid.shrc
source /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/bin/activate

# Automatically detect the mutinfo.txt file in the flexddg directory
MUTINFO_PATH="$(pwd)/flexddg/mutinfo.txt"
RUN_DIR="$(pwd)/flexddg"

# Check if the mutinfo.txt file exists
if [ ! -f "$MUTINFO_PATH" ]; then
    echo "Error: mutinfo.txt not found at $MUTINFO_PATH"
    echo "Please ensure you are running this script from the run directory (not the flexddg directory)"
    exit 1
fi

echo "Using mutinfo.txt at: $MUTINFO_PATH"

rosetta_ddg_check_run \
    -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_agg35.yaml \
    -d "$RUN_DIR" \
    -mf "$MUTINFO_PATH"