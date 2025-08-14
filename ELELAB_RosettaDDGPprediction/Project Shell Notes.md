# This works perfectly for aggregating. You must be in the *aggregated* run directory (not the flexddg directory) 
## well wait actually you should be in the aggregated flexddg folder like this one for checking a run */wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg*

*Note it is critical to use a config_run file that uses the right number of nstructs, which is likely more than 1 (which is used in the prod configs for array job submissions)*

rosetta_ddg_aggregate \
    -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_agg35.yaml \
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



(ddg) [kjander@dev2 flexddg]$ rosetta_ddg_check_run -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_10struct.yaml -mf /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/mutinfo.txt
INFO:root:Now checking the configuration file /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_1backrub_10struct.yaml.
WARNING:root:The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654P/5.
The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654P/5.
WARNING:root:The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654T/5.
The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654T/5.
WARNING:root:The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654W/5.
The run in the following directory reported a crash: /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/E-N654W/5.


# Database errors when aggregating from the wron directory
__this is an error that is created because we were running from the aggregated flexddg folder and not the aggregated folder *that contains the flexddg folder with all aggregated mutations*__
(ddg) [kjander@dev2 flexddg]$ rosetta_ddg_aggregate -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_agg10.yaml -ca /wynton/home/craik/kjander/ddg/RosettaDDGPredi
ction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cs /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml -mf /wynton/scratch/kjander/P1B7_mini_repeat3/aggre
gated_flexddg/flexddg/mutinfo.txt 
2025-08-11 12:44:08,439 - distributed.worker - ERROR - Compute Failed
Key:       parse_output_flexddg-089724a01cdab269be6ad0fe69c4a899
State:     executing
Task:  <Task 'parse_output_flexddg-089724a01cdab269be6ad0fe69c4a899' parse_output_flexddg(, ...)>
Exception: "OperationalError('unable to open database file')"
Traceback: '  File "/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/lib/python3.11/site-packages/RosettaDDGPrediction-0.0.1-py3.11.egg/RosettaDDGPrediction/aggregation.py", line 177, in parse_output_flexddg\n    connection = sqlite3.connect(db3_out)\n                 ^^^^^^^^^^^^^^^^^^^^^^^^\n'

Traceback (most recent call last):
  File "/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/bin/rosetta_ddg_aggregate", line 33, in <module>
    sys.exit(load_entry_point('RosettaDDGPrediction==0.0.1', 'console_scripts', 'rosetta_ddg_aggregate')())
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/lib/python3.11/site-packages/RosettaDDGPrediction-0.0.1-py3.11.egg/RosettaDDGPrediction/rosetta_ddg_aggregate.py", line 493, in main
  File "/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/lib/python3.11/site-packages/distributed-2025.3.0-py3.11.egg/distributed/client.py", line 401, in result
    return self.client.sync(self._result, callback_timeout=timeout)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/lib/python3.11/site-packages/RosettaDDGPrediction-0.0.1-py3.11.egg/RosettaDDGPrediction/aggregation.py", line 177, in parse_output_flexddg
sqlite3.OperationalError: unable to open database file


# making plots

(ddg) [kjander@dev2 aggregated_flexddg]$ python3 /wynton/home/craik/kjander/ddg/wynton-scripts/ELELAB_RosettaDDGPprediction/aggregate/generate_ddg_plots.py -i /wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv -o /wynton/home/craik/kjander/ddg/Prod_P1B
7/plots --config-base-path /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction --structures-file /wynton/home/crai
k/kjander/ddg/Prod_P1B7/ddg_mutations_structures.csv
Created output directory: /wynton/home/craik/kjander/ddg/Prod_P1B7/plots

Generating total_heatmap...
Description: One-row heatmap of all mutations
Running command: rosetta_ddg_plot -i /wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv -o /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/total_heatmap.png -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cp /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/total_heatmap.yaml
✗ Error generating total_heatmap: Command '['rosetta_ddg_plot', '-i', '/wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv', '-o', '/wynton/home/craik/kjander/ddg/Prod_P1B7/plots/total_heatmap.png', '-ca', '/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml', '-cp', '/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/total_heatmap.yaml']' returned non-zero exit status 1.
Stderr: ERROR:root:Could not plot the heatmap : The number of FixedLocator locations (33), usually from a call to set_ticks, does not match the number of labels (420).
Could not plot the heatmap : The number of FixedLocator locations (33), usually from a call to set_ticks, does not match the number of labels (420).


Generating total_heatmap_saturation...
Description: 2D heatmap showing positions vs residue types
Running command: rosetta_ddg_plot -i /wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv -o /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/total_heatmap_saturation.png -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cp /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/total_heatmap_saturation.yaml
✗ Error generating total_heatmap_saturation: Command '['rosetta_ddg_plot', '-i', '/wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv', '-o', '/wynton/home/craik/kjander/ddg/Prod_P1B7/plots/total_heatmap_saturation.png', '-ca', '/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml', '-cp', '/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/total_heatmap_saturation.yaml']' returned non-zero exit status 1.
Stderr: /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/ddg/lib/python3.11/site-packages/RosettaDDGPrediction-0.0.1-py3.11.egg/RosettaDDGPrediction/plotting.py:86: FutureWarning: In a future version of pandas all arguments of StringMethods.split except for the argument 'pat' will be keyword-only.
ERROR:root:Could not plot the heatmap : FigureCanvasAgg.print_png() got an unexpected keyword argument 'figsize'
Could not plot the heatmap : FigureCanvasAgg.print_png() got an unexpected keyword argument 'figsize'


Generating contributions_barplot...
Description: Stacked bar plot of energy contributions
Running command: rosetta_ddg_plot -i /wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_aggregate.csv -o /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/contributions_barplot.png -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cp /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/contributions_barplot.yaml
✓ Successfully generated /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/contributions_barplot.png

Generating dg_swarmplot...
Description: Swarmplot of ΔG scores for each structure
Running command: rosetta_ddg_plot -i /wynton/home/craik/kjander/ddg/Prod_P1B7/ddg_mutations_structures.csv -o /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/dg_swarmplot.png -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cp /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_plot/dg_swarmplot.yaml
✓ Successfully generated /wynton/home/craik/kjander/ddg/Prod_P1B7/plots/dg_swarmplot.png

Plot generation complete! Check the '/wynton/home/craik/kjander/ddg/Prod_P1B7/plots' directory for results.



rosetta_ddg_aggregate -cr /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_run/ddg_kja_prod_agg10.yaml -ca /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_aggregate/aggregate.yaml -cs /wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction/config_settings/nompi.yaml -mf /wynton/scratch/kjander/P1B7_mini_repeat3/aggregated_flexddg/flexddg/mutinfo.txt --mutatex-convert --mutatex-reslistfile /wynton/home/craik/kjander/ddg/Prod_P1B7/residues.txt