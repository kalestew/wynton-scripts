# Missing Replica Fix Workflow

This directory contains a complete workflow for handling missing replicas in Rosetta DDG saturation runs on Wynton HPC. The workflow automatically detects missing replicas, resubmits them as SGE jobs, and merges the results back while preserving data integrity.

## Metadata File System (New Feature)

As of the latest update, the workflow now uses a `.rosetta_ddg_metadata.json` file to track all important parameters and file paths throughout the pipeline. This makes the workflow more robust and automatic.

### How it works:

1. **Initial Submission**: When you run `ELELAB_submit_SGE_RosettaDDGPrediction.sh`, it creates a metadata file in the project directory containing:
   - Absolute paths to all input files (PDB, positions, residues)
   - Run parameters (replicas, cores, memory, etc.)
   - Project name and submission directory
   - Timestamp and user information

2. **Aggregation**: When `submit_SGE_output_forELELAB_processing.sh` runs, it:
   - Reads the metadata file to find original files
   - Automatically copies PDB files, residues.txt, mutation_chunks, and SGE scripts
   - Updates the metadata with aggregation information

3. **Fix/Resubmit**: The fix workflow scripts:
   - Automatically read parameters from the metadata file
   - Know exactly where to find required files
   - Can copy missing files automatically
   - Provide specific commands when manual intervention is needed

### Benefits:

- **No more manual parameter editing** - Scripts auto-configure from metadata
- **Automatic file discovery** - No need to hunt for original PDB files
- **Clear error messages** - Scripts know exactly what's missing and where to find it
- **Audit trail** - Track when and where runs were submitted and aggregated

### Using the metadata system:

If you have a metadata file in your directory:
```bash
# The scripts will automatically use it
bash fix_and_resubmit_workflow.sh

# redo_replicas.sh will auto-load parameters
bash redo_replicas.sh
```

If you don't have a metadata file (older runs), the scripts will fall back to the traditional behavior and search for files manually.

### Creating metadata for existing runs:

For runs created before the metadata system was implemented, you can generate a metadata file:

```bash
# From your aggregated directory or project directory
bash generate_metadata_for_existing_run.sh

# Or specify parameters explicitly
bash generate_metadata_for_existing_run.sh --project MY_PROJECT --pdb my_protein.pdb
```

The script will:
- Analyze your directory structure
- Find PDB files and other resources
- Infer parameters from existing runs
- Create a `.rosetta_ddg_metadata.json` file

Once created, all the workflow scripts will use this metadata automatically.

## Required Files When Running from Aggregated Directory

⚠️ **IMPORTANT**: When running these scripts from an aggregated directory (e.g., `/wynton/scratch/kjander/PROJECT/aggregated_flexddg/`), you must ensure the following files are present:

1. **Original PDB file(s)** - The same PDB file used in the initial submission
2. **residues.txt** - If custom residues were used (can be omitted if using standard amino acids)
3. **mutation_chunks/** directory - Contains individual mutation files
4. **SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh** - The SGE worker script

### Why are these files needed?

The `redo_replicas.sh` script needs to resubmit jobs with the exact same parameters as the original run. The SGE job script expects to copy the PDB file from the submission directory, but when running from the aggregated directory, these files aren't present by default.

### Automatic file copying

The `submit_SGE_output_forELELAB_processing.sh` script (as of recent updates) will attempt to automatically copy:
- mutation_chunks directory
- SGE submission script
- PDB files found in run directories
- residues.txt if present

However, if these files are missing, you'll need to copy them manually:

```bash
# From your aggregated directory
cp /path/to/original/submission/*.pdb .
cp /path/to/original/submission/residues.txt .  # if applicable
cp -r /path/to/original/submission/mutation_chunks .
cp /path/to/original/submission/SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh .
```

## Overview

The workflow consists of five main scripts:

1. **`find_missing_replicas.py`** - Detects missing replicas and cleans mutinfo.txt
2. **`redo_replicas.sh`** - Resubmits missing replicas as SGE jobs
3. **`merge_redo_runs.sh`** - Merges completed runs and restores mutinfo.txt entries
4. **`fix_and_resubmit_workflow.sh`** - Orchestrates the entire process
5. **`generate_metadata_for_existing_run.sh`** - Creates metadata files for pre-existing runs

## Quick Start

The scripts can be run from **either** location:

### Option A: Aggregation Directory (Recommended)
```
aggregation_output_directory/   # ← Copy scripts here and run from here
├── flexddg/                   # Master aggregation directory
├── mutation_chunks/           # Automatically copied during aggregation
├── find_missing_replicas.py   # ← Copy here
├── redo_replicas.sh           # ← Copy here  
├── merge_redo_runs.sh         # ← Copy here
├── fix_and_resubmit_workflow.sh  # ← Copy here
└── run_*/                     # Will be created by redo_replicas.sh
```

### Option B: Original Submission Directory
```
original_submission_directory/  # Where you ran ELELAB_submit_SGE_RosettaDDGPrediction.sh
├── mutation_chunks/           # From original submission
├── SGEprocess_ddg_array_RosettaDDGPrediction_job_production.sh  # SGE worker script
├── find_missing_replicas.py   # ← Copy here
├── redo_replicas.sh           # ← Copy here  
├── merge_redo_runs.sh         # ← Copy here
└── fix_and_resubmit_workflow.sh  # ← Copy here
```

### Automated Workflow (Recommended)

**From aggregation directory:**
```bash
bash fix_and_resubmit_workflow.sh
```

**From original submission directory:**
```bash
bash fix_and_resubmit_workflow.sh --flex /path/to/aggregation/flexddg
```

**With custom chunks directory:**
```bash
bash fix_and_resubmit_workflow.sh --chunks-dir /path/to/mutation_chunks
```

### Manual Step-by-Step

**Standard usage:**
```bash
# Step 1: Find missing replicas
python3 find_missing_replicas.py --inplace -v

# Step 2: Resubmit missing replicas
bash redo_replicas.sh

# Step 3: Wait for jobs to complete (monitor with: watch qstat)

# Step 4: Merge results and restore mutinfo.txt
bash merge_redo_runs.sh
```

**With custom chunks directory:**
```bash
# Step 2: Resubmit missing replicas with custom chunks path
bash redo_replicas.sh --chunks-dir /path/to/original/mutation_chunks
```

## Script Details

### find_missing_replicas.py

**Purpose**: Identifies mutations with missing replica folders or database files, removes them from `mutinfo.txt`, and outputs a list for resubmission.

**Usage**:
```bash
python3 find_missing_replicas.py [options]
```

**Options**:
- `--flex DIR` - Path to flexddg directory (default: flexddg)
- `--nstruct N` - Expected replicas per mutation (default: 35)
- `--mutinfo FILE` - mutinfo filename (default: mutinfo.txt)
- `--inplace` - Overwrite mutinfo.txt in-place (creates .bak backup)
- `--log FILE` - Output file for redo list (default: missing_replicas.txt)
- `-v, --verbose` - Enable verbose logging

**Outputs**:
- `missing_replicas.txt` - List of missing replicas in format `mut_id:replica`
- `mutinfo.cleaned.txt` - Cleaned mutinfo (or overwrites original if --inplace)
- `mutinfo.txt.bak` - Backup of original (if --inplace used)

### redo_replicas.sh

**Purpose**: Resubmits individual replicas as SGE jobs using the output from `find_missing_replicas.py`.

**Usage**:
```bash
bash redo_replicas.sh [options]
```

**Options**:
- `--file FILE` - Missing replicas file (default: missing_replicas.txt)
- `--manual` - Use hardcoded MUT_REP array instead of file
- `--chunks-dir PATH` - Specify mutation_chunks directory path (default: ./mutation_chunks)
- `--help` - Show usage information

**Configuration**: Edit the script to set your PDB file, PROJECT path, and resource requirements.

### merge_redo_runs.sh

**Purpose**: Merges completed resubmission runs back into the master flexddg directory and restores mutinfo.txt entries.

**Usage**:
```bash
bash merge_redo_runs.sh [options]
```

**Options**:
- `--missing-file FILE` - Missing replicas file for validation (default: missing_replicas.txt)
- `--no-restore` - Don't restore mutinfo.txt entries (restoration is default)
- `--help` - Show usage information

**Default Behavior**: Automatically restores mutinfo.txt entries for successfully completed mutations.

### fix_and_resubmit_workflow.sh

**Purpose**: Orchestrates the complete workflow from detection to completion.

**Usage**:
```bash
bash fix_and_resubmit_workflow.sh [options]
```

**Options**:
- `--nstruct N` - Expected replicas per mutation (default: 35)
- `--no-wait` - Don't wait for jobs to complete before merging
- `--flex DIR` - Path to flexddg directory (default: flexddg)
- `--chunks-dir DIR` - Path to mutation_chunks directory (optional)
- `--help` - Show usage information

## Workflow Details

### Step 1: Detection
- Scans all mutation directories for missing replica folders or database files
- Creates a backup of the original mutinfo.txt
- Removes entries for incomplete mutations from mutinfo.txt
- Generates a list of missing replicas for resubmission

### Step 2: Resubmission
- Reads the missing replicas list
- Submits individual SGE jobs for each missing replica
- Uses the same parameters as the original submission
- Jobs are named `redo_<mut_id>_<replica>` for easy identification

### Step 3: Monitoring (Optional)
- Monitors SGE queue for job completion
- Provides progress updates every 30 seconds
- Can be skipped with `--no-wait` flag

### Step 4: Merging
- Merges completed replica directories into the master flexddg structure
- Preserves existing data (won't overwrite completed replicas)
- Restores mutinfo.txt entries for successfully completed mutations
- Validates against the original missing replicas list

## File Structure

```
your_output_directory/
├── flexddg/                    # Master aggregation directory
│   ├── mutinfo.txt            # Main mutation info file
│   ├── mutinfo.txt.bak        # Backup (if --inplace used)
│   └── <mut_id>/              # Mutation directories
│       └── <replica>/         # Individual replica folders
│           ├── ddg.db3        # Database file
│           └── struct.db3     # Structure database
├── run_<mut_id>/              # Individual resubmission runs
│   └── flexddg/
│       └── <mut_id>/
│           └── <replica>/
└── missing_replicas.txt       # List of missing replicas
```

## Error Handling

### Common Issues

1. **Missing mutation_chunks directory**: 
   - Ensure you're running from the correct directory
   - Check that `mutation_chunks/` exists with `mutsite_*.txt` files

2. **SGE job failures**:
   - Check job logs for specific error messages
   - Verify resource requirements match node capabilities
   - Ensure proper file permissions

3. **Database corruption**:
   - Look for incomplete ddg.db3 files
   - Check for filesystem errors in job logs

### Recovery

If the workflow fails midway:
- Individual steps can be run manually
- `merge_redo_runs.sh` can be run multiple times safely
- Use `--no-restore` if you need to prevent mutinfo.txt changes

## Advanced Usage

### Custom Configuration

Edit `redo_replicas.sh` to modify:
- PDB file path
- PROJECT directory
- Resource requirements (cores, memory, time)
- SGE queue parameters

### Multiple Rounds

If some replicas still fail after the first round:
```bash
# Run the workflow again to catch remaining failures
bash fix_and_resubmit_workflow.sh
```

The workflow is designed to be run multiple times safely.

### Manual Intervention

For specific mutations that repeatedly fail:
```bash
# Check specific mutation
ls -la flexddg/<mut_id>/

# Manually resubmit single replica
bash redo_replicas.sh --manual
# (edit MUT_REP array in script first)
```

## Integration with ELELAB Pipeline

This workflow is designed to work with the existing ELELAB processing pipeline:

1. Run initial saturation job (`ELELAB_submit_SGE_RosettaDDGPrediction.sh`)
2. Run aggregation (`submit_SGE_output_forELELAB_processing.sh`) - **now automatically copies `mutation_chunks/`**
3. Use this workflow to fix missing replicas
4. Proceed with normal aggregation and analysis

The restored mutinfo.txt will be identical to the original, ensuring downstream processing works correctly.

### Recent Improvements

- **Automatic `mutation_chunks/` copying**: The aggregation script now automatically finds and copies the `mutation_chunks/` directory to the aggregation output
- **Flexible chunk directory**: Both `redo_replicas.sh` and the workflow script now accept `--chunks-dir` to specify custom locations
- **Smart directory detection**: The aggregation script searches multiple locations to find the original `mutation_chunks/` directory

## Best Practices

1. **Always backup**: The scripts create backups, but additional backups are recommended
2. **Monitor resources**: Check SGE queue and node usage during resubmission
3. **Validate results**: Use `find_missing_replicas.py` again after completion to verify
4. **Incremental approach**: Run workflow multiple times for stubborn failures
5. **Log everything**: Keep job logs for troubleshooting

## Troubleshooting

### Debug Mode
```bash
# Enable verbose logging
python3 find_missing_replicas.py -v

# Check what would be restored
bash merge_redo_runs.sh --help
```

### Manual Validation
```bash
# Count expected vs actual replicas
find flexddg -name "ddg.db3" | wc -l

# Check specific mutation
ls -la flexddg/<mut_id>/
```

### Recovery from Partial Failures
```bash
# Restore from backup if needed
cp flexddg/mutinfo.txt.bak flexddg/mutinfo.txt

# Start over with clean slate
bash fix_and_resubmit_workflow.sh
```

### Configuring redo_replicas.sh

Before running the workflow, you may need to edit `redo_replicas.sh` to match your specific run parameters:

```bash
# Edit these parameters at the top of redo_replicas.sh:
PDB="your_protein.pdb"              # Your input PDB filename
PROJECT="your_project_name"         # Your project name/path
RESLIST="residues.txt"             # Or your custom residue list filename
```

The script will check for these files and warn you if they're missing. 