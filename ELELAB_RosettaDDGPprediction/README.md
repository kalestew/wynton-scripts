# Rosetta DDG – SGE Submission Pipeline

This document is a **one-stop guide** for running a full saturation-mutagenesis
Flex ddG workflow on UCSF Wynton, starting from a raw PDB and ending with plots
and CSV summaries ready for publication.

The scripts live under `RosettaDDGPrediction/SGE submission scripts/` and are
broken into logical sub-directories:

```
SGE submission scripts/
├── Relax/                # Optional Rosetta Relax job
├── Setup/                # Input-file generators & helpers
├── aggregate/            # Large-scale aggregation + fix-up utilities
│   └── fix failed array jobs/   # Missing-replica workflow
└── * main scripts *
    ├── ELELAB_submit_SGE_RosettaDDGPrediction.sh
    ├── SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh
    └── submit_SGE_output_forELELAB_processing.sh
```

---
## Quick reference
| Phase | Script | What it does |
|-------|--------|--------------|
| 0. Relax | `Relax/relax_run.sh` | Optional single-structure relax on Wynton |
| 1. Setup | `Setup/generate_mutation_inputs.py` | Converts chain :span → `positions.txt` + `residues.txt` |
| | (alt.) `Setup/gen_pdb_span.py` | Locates a sequence motif and prints span string |
| 2. Submit | `ELELAB_submit_SGE_RosettaDDGPrediction.sh` | Launches one **array job** per mutation site |
| | `SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh` | Worker called by SGE for each replica |
| 3. Aggregate (copy) | `aggregate/submit_SGE_output_forELELAB_processing.sh` | Copies **all** finished runs into a central `aggregated_flexddg/` directory |
| 4. QA / Fix | `aggregate/fix failed array jobs/fix_and_resubmit_workflow.sh` | Detect → resubmit → merge any missing replicas |
| 5. Final stats | `aggregate/debug_plotting_comprehensive.py` (example) | Generates master CSV & MutateX-style outputs |
| 6. Plot | `aggregate/plot_*` configs (+ notebooks) | Publication-quality figures |

> **Pro-Tip**  Every major script has `--help`.

---
## 0  (Optional) Relax the input structure
```bash
# submit from your laptop or Wynton login node
qsub Relax/relax_run.sh -F "my_complex_prepared.pdb"
```
The job writes a relaxed PDB next to the original.  Skip if you already have a
Rosetta-friendly structure.

---
## 1  Generate mutation inputs
1. Decide which residues you want to mutate.  Example: chain A positions 30–37
   and chain B 50–60, with chain B allowed to back off in the Flex ddG
   interface calculation.
2. Run the helper:

```bash
python3 Setup/generate_mutation_inputs.py \ 
        -p relaxed.pdb \ 
        -s A:30-37 B:50-60 \ 
        -m B \                       # chain to move
        -o positions.txt             # (default)
```
`positions.txt` and a 20-AA `residues.txt` are produced.

Need a span string?  Search by sequence motif:
```bash
python3 Setup/gen_pdb_span.py -p relaxed.pdb -s EVQLQQ -–fuzzy 1
# → A:24-29   (1 mismatch allowed)
```

---
## 2  Submit saturation run
```bash
bash ELELAB_submit_SGE_RosettaDDGPrediction.sh \ 
     relaxed.pdb positions.txt project_name
```
The script:
1. Splits `positions.txt` into `mutation_chunks/mutsite_*.txt`.
2. Writes **`.rosetta_ddg_metadata.json`** to the project's scratch directory
   – all later steps read from this file.
3. Submits one **SGE array job** per mutation site
   (`ddg_<mutid>[1-35]`).  Each task runs 35 replicas by default.

Monitor with `watch qstat` or `qstat -u $USER`.

---
## 3  Copy & coarse aggregate
When the array jobs finish:
```bash
bash aggregate/submit_SGE_output_forELELAB_processing.sh project_name
```
This creates `${SCRATCH}/project_name/aggregated_flexddg/` with:
* `flexddg/…`    – all mutation directories
* `mutation_chunks/`
* **metadata file** (updated!)

---
## 4  Quality-check and fix missing replicas
The most common failure is a handful of replicas timing-out or a node crash.
From *inside* the aggregation directory:
```bash
cd /wynton/scratch/$USER/project_name/aggregated_flexddg
bash fix failed array jobs/fix_and_resubmit_workflow.sh
```
The workflow will:
1. Detect gaps via `find_missing_replicas.py`.
2. Resubmit only the missing replica tasks.
3. Wait (or `--no-wait`).
4. Merge results back, restoring `mutinfo.txt`.

You can run it repeatedly until **0 missing replicas**.

---
## 5  Master aggregation & MutateX outputs
The ELELAB aggregation helpers turn the many SQLite db3 files into a single
CSV plus per-mutation summaries.

```bash
python3 aggregate/debug_plotting_comprehensive.py \
        --flex flexddg \
        --out master_results.csv
```
*Look in `aggregate/` for more lightweight examples.*

The resulting files are compatible with MutateX-style plotting utilities.

---
## 6  Plotting
Example (matplotlib-based) heat-map:
```bash
python3 aggregate/plot_total_heatmap_saturation.py master_results.csv
```
YAML configs for barplots, swarmplots, etc. live in
`RosettaDDGPrediction/config_plot/`.

---
## Troubleshooting cheatsheet
| Symptom | Script / Fix |
|---------|--------------|
| `cp: cannot stat '*.pdb'` when resubmitting | Ensure `submit_SGE_output_forELELAB_processing.sh` copied PDB; otherwise copy manually or regenerate metadata |
| Stale `mutinfo.txt` after merge | `bash merge_redo_runs.sh --missing-file missing_replicas.txt` |
| Job killed (exit 137) | Increase `mem_free` in `SGEprocess_ddg_array_*` or lower `N_REPLICAS` |
| GPU jobs deleted instantly | Forgot `-l h_rt=HH:MM:SS` on `gpu.q` |

---
## Known-good defaults
* 35 replicas (nstruct) per mutation
* `-pe smp 5`   → 5 cores, `mem_free=4G`, `scratch=8G`
* Wall-time `40:00:00`
* BeeGFS project root `/wynton/scratch/<user>/<project>`

---
## Version history
* **2025-07-05**  Metadata file system introduced – automatic parameter
  hand-off between all stages.
* **2024-11-02**  Stage-out rewritten for atomic `tar` copies.
* **2024-05-17**  Initial SGE submission helper published.

---
Happy mutating 🧬 