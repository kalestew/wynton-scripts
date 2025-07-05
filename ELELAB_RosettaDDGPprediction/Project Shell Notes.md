# This works perfectly for aggregating. You must be in the run directory (not the flexddg directory)

*Note it is critical to use a config_run file that uses the right number of nstructs, which is likely more than 1 (which is used in the prod configs for array job submissions)*

rosetta_ddg_aggregate \
    -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_35struct.yaml \
    -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml \
    -cs /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml \
    -mf /wynton/scratch/kjander/41D1_ArrayTestSMOKETEST_FIX/run_B-S-133/flexddg/mutinfo.txt


    rosetta_ddg_check_run \
    -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_35struct.yaml \
    -cs /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml \
    -mf /wynton/scratch/kjander/FINAL_FULL_41D1_Array_jun24thLate/WedTarCopyRegular1/flexddg/mutinfo.txt

    rosetta_ddg_check_run \
     -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_35struct.yaml \
     -mf /wynton/scratch/kjander/FINAL_FULL_41D1_Array_jun24thLate/WedTarCopyRegular1/flexddg/mutinfo.txt
INFO:root:Now checking the configuration file /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_35struct.yaml.
INFO:root:No crashed run has been found.
No crashed run has been found