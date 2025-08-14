# Enhanced MutateX Position List Generator

This enhanced version of `generate_mutatex_position_list.py` provides smart sequence matching, interactive selection, and validation features inspired by the ELELAB RosettaDDGPrediction utilities.

## New Features

### 1. **Interactive Mode** (`-i, --interactive`)
Launch an interactive session to explore your PDB structure and select residues:
- View all chains with residue counts and ranges
- Search for sequence motifs interactively
- Select entire chains or specific spans
- Combine multiple selection methods

### 2. **Sequence Search** (`-q, --query`)
Find residues by searching for sequence motifs:
- Exact sequence matching
- Fuzzy matching with allowed mismatches (`--fuzzy N`)
- Multiple queries can be combined
- Shows matched sequences with mismatch information

### 3. **Enhanced Validation** (`--validate`)
Validate your selections before generating the position list:
- Check if chains exist in the structure
- Verify residue ranges are within bounds
- Report warnings for potential issues

### 4. **Non-standard Residue Handling** (`--include-non-standard`)
- Option to include non-standard residues as 'X'
- Clear reporting of skipped residues
- Useful for modified amino acids or unusual residues

## Usage Examples

### Basic Usage

```bash
# Manual span specification (original functionality)
python generate_mutatex_position_list.py -p antibody.pdb -s H:30-35 L:50-56

# Interactive mode - explore and select
python generate_mutatex_position_list.py -p antibody.pdb -i

# Search for a specific sequence
python generate_mutatex_position_list.py -p antibody.pdb -q GFTFSSYA

# Fuzzy sequence search (allow 1 mismatch)
python generate_mutatex_position_list.py -p antibody.pdb -q GFTFSSYA --fuzzy 1

# Combine multiple search queries
python generate_mutatex_position_list.py -p antibody.pdb -q GFTF -q YYCAR -q RASQ

# Validate spans and show warnings
python generate_mutatex_position_list.py -p antibody.pdb -s H:1-500 --validate
```

### Advanced Examples

#### Finding Antibody CDRs
```bash
# Search for common CDR motifs with fuzzy matching
python generate_mutatex_position_list.py \
    -p antibody.pdb \
    -q "GFTF" --fuzzy 1 \
    -q "YYCSR" --fuzzy 1 \
    -q "RASQ" --fuzzy 1 \
    -o cdr_positions.txt
```

#### Combining Methods
```bash
# Use sequence search plus manual spans
python generate_mutatex_position_list.py \
    -p protein.pdb \
    -q "EVQLVQ" \
    -s A:100-110 \
    -o combined_positions.txt
```

#### Including Non-standard Residues
```bash
# Include modified amino acids as 'X'
python generate_mutatex_position_list.py \
    -p modified_protein.pdb \
    -s A:1-100 \
    --include-non-standard \
    -o positions_with_mods.txt
```

## Interactive Mode Features

When using `-i` or `--interactive`, you'll get a menu with these options:

1. **Search for a sequence motif**
   - Enter any sequence in 1-letter code
   - Optionally allow mismatches for fuzzy matching
   - Select which matches to include

2. **Manually enter residue spans**
   - Enter spans in format: `A:30-37,B:50-60`
   - Multiple spans can be comma-separated

3. **Select entire chains**
   - View all available chains with their ranges
   - Select multiple chains by number

4. **Exit interactive mode**
   - Proceed with selected spans or cancel

## Output Format

The generated position list follows the MutateX format:
```
GH31
FH32
TH33
FL50
SL51
```

Where each line contains:
- 1-letter amino acid code of the wild-type residue
- Chain identifier
- Residue number

## Enhanced Workflow Script

Use `run_mutatex_enhanced.sh` for a complete workflow:

```bash
# Interactive workflow
./run_mutatex_enhanced.sh antibody.pdb results interactive

# Automatic CDR detection
./run_mutatex_enhanced.sh antibody.pdb results auto

# Manual span entry
./run_mutatex_enhanced.sh antibody.pdb results manual
```

## Error Handling

The enhanced script provides better error messages:
- Invalid span formats are caught with helpful messages
- Missing chains are reported with warnings
- Empty results are clearly indicated
- Validation warnings help identify potential issues

## Comparison with Original Script

| Feature | Original | Enhanced |
|---------|----------|----------|
| Manual spans | ✓ | ✓ |
| Interactive mode | ✗ | ✓ |
| Sequence search | ✗ | ✓ |
| Fuzzy matching | ✗ | ✓ |
| Validation | Basic | Comprehensive |
| Error messages | Basic | Detailed |
| Non-standard residues | Skip only | Skip or include as 'X' |
| Multiple input methods | ✗ | ✓ |
| Summary statistics | Basic | Detailed |

## Tips

1. **Use validation** (`--validate`) when working with unfamiliar structures
2. **Try fuzzy matching** (`--fuzzy 1` or `--fuzzy 2`) when exact sequences don't match
3. **Interactive mode** is great for exploring new structures
4. **Combine methods** for comprehensive coverage (e.g., CDRs + framework regions)
5. **Check the summary** output to verify your selections

## Requirements

- Python 3.6+
- BioPython
- Same dependencies as the original script

## Integration with MutateX

The output is fully compatible with MutateX. After generating your position list:

```bash
# Run MutateX with the generated positions
mutatex structure.pdb \
    --positions position_list.txt \
    --output-prefix results \
    --mode saturation
``` 












Planning to update the script to: (1) support multiple motifs via repeated -q flags, (2) add an --append-output flag to avoid clobbering the output file, and (3) wire these into the main flow and the file write mode. Then I’ll run a quick example command to verify non-clobbering and multiple queries work.
Ran tool
Ran tool

Making the script accept multiple -q motifs and add an --append-output option to avoid clobbering, then wiring these into the main flow and write mode.
Ran tool

### Yes — you can pass multiple spans and motifs in one go now

- **Multiple spans in one run**: The script already supported this. Use `-s` with space-separated spans.
- **Multiple motifs in one run**: I added repeated `-q` support. Use `-q` multiple times.
- **Avoid clobbering output**: I added `--append-output` to append rather than overwrite.

Examples:

- Run with 6 spans (one invocation):
```bash
python3 mutateX/P1B7/generate_mutatex_position_list.py \
  -p mutateX/P1B7/P1B7_cleaned_noSoto.pdb \
  -s A:12-34 A:56-78 B:10-20 B:45-60 C:5-15 C:100-110 \
  -o mutateX/P1B7/position_list.txt --validate
```

- Search multiple motifs at once (optionally with mismatches), plus manual spans, and append to an existing file:
```bash
python3 mutateX/P1B7/generate_mutatex_position_list.py \
  -p mutateX/P1B7/P1B7_cleaned_noSoto.pdb \
  -q EVQLVQ -q DIQMTQ -q GGGGS --fuzzy 1 \
  -s A:30-37 B:50-60 \
  -o mutateX/P1B7/position_list.txt --append-output --validate
```

Notes:
- Within a single run, spans deduplicate before processing. If you append across multiple runs, duplicates can accumulate in the output; you can dedup after appending with:
```bash
sort -u -o mutateX/P1B7/position_list.txt mutateX/P1B7/position_list.txt
```
- To include non-standard residues as `X`, add `--include-non-standard`.

- **Changes made**:
  - `-q/--query` now accepts multiple motifs via repeated flags.
  - Added `--append-output` to append instead of overwriting.
  - File write honors append mode.