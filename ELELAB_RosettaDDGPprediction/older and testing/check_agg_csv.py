#!/usr/bin/env python3
"""
Comprehensive diagnostic script for ddg_mutations_aggregate.csv files.
Checks for all issues that could cause rosetta_ddg_plot to fail with
"You need to have only single mutations..." error.

Usage: python3 check_agg_csv.py [ddg_mutations_aggregate.csv]
"""

import pandas as pd
import numpy as np
import sys
import os
from pathlib import Path

def check_file_exists(filepath):
    """Check if the CSV file exists and is readable."""
    if not os.path.exists(filepath):
        print(f"❌ ERROR: File '{filepath}' not found!")
        return False
    
    if not os.access(filepath, os.R_OK):
        print(f"❌ ERROR: File '{filepath}' is not readable!")
        return False
    
    print(f"✅ File '{filepath}' exists and is readable")
    return True

def check_csv_structure(filepath):
    """Check basic CSV structure and load the dataframe."""
    try:
        df = pd.read_csv(filepath)
        print(f"✅ CSV loaded successfully: {len(df)} rows, {len(df.columns)} columns")
        return df
    except pd.errors.EmptyDataError:
        print("❌ ERROR: CSV file is empty!")
        return None
    except pd.errors.ParserError as e:
        print(f"❌ ERROR: CSV parsing failed: {e}")
        return None
    except Exception as e:
        print(f"❌ ERROR: Failed to read CSV: {e}")
        return None

def check_required_columns(df):
    """Check if required columns are present."""
    required_cols = ['mutation', 'mutation_label', 'position_label', 'state', 
                    'energy_unit', 'score_function_name', 'total_score']
    
    missing_cols = [col for col in required_cols if col not in df.columns]
    
    if missing_cols:
        print(f"❌ ERROR: Missing required columns: {missing_cols}")
        print(f"   Available columns: {list(df.columns)}")
        return False
    
    print("✅ All required columns present")
    return True

def check_mutation_column_format(df):
    """Check mutation column for formatting issues."""
    print("\n🔍 Checking mutation column format...")
    
    mutation_col = 'mutation'
    if mutation_col not in df.columns:
        print(f"❌ ERROR: '{mutation_col}' column not found!")
        return False
    
    issues = []
    
    # Check for NaN/null values
    nan_mask = df[mutation_col].isna()
    nan_count = nan_mask.sum()
    if nan_count > 0:
        issues.append(f"❌ {nan_count} NaN/null values in mutation column")
        nan_rows = df.index[nan_mask].tolist()[:10]  # Show first 10
        issues.append(f"   First NaN rows: {nan_rows}")
    
    # Check for non-string values
    non_string_mask = df[mutation_col].apply(lambda x: not isinstance(x, str) if pd.notna(x) else False)
    non_string_count = non_string_mask.sum()
    if non_string_count > 0:
        issues.append(f"❌ {non_string_count} non-string values in mutation column")
        non_string_vals = df.loc[non_string_mask, mutation_col].tolist()[:5]
        issues.append(f"   Examples: {non_string_vals}")
    
    # Check mutation format (should be X.Y.Z.W)
    valid_mutations = df[mutation_col].dropna()
    malformed = []
    
    for idx, mutation in valid_mutations.items():
        if not isinstance(mutation, str):
            continue
            
        # Split by dots
        parts = mutation.split('.', 3)  # max 4 parts
        
        # Check if we have exactly 4 parts
        if len(parts) != 4:
            malformed.append((idx + 2, mutation, f"Expected 4 parts, got {len(parts)}"))
            continue
        
        # Check if any part is empty
        if any(part == '' for part in parts):
            empty_indices = [i for i, part in enumerate(parts) if part == '']
            malformed.append((idx + 2, mutation, f"Empty parts at positions: {empty_indices}"))
            continue
        
        # Check format: Chain.WT.Num.Mut
        chain, wt_res, res_num, mut_res = parts
        
        # Chain should be 1 character (usually A, B, etc.)
        if len(chain) != 1 or not chain.isalpha():
            malformed.append((idx + 2, mutation, f"Invalid chain '{chain}' (should be single letter)"))
            continue
        
        # WT and Mut residues should be 1 character amino acids
        valid_aa = 'ACDEFGHIKLMNPQRSTVWY'
        if len(wt_res) != 1 or wt_res.upper() not in valid_aa:
            malformed.append((idx + 2, mutation, f"Invalid WT residue '{wt_res}'"))
            continue
        
        if len(mut_res) != 1 or mut_res.upper() not in valid_aa:
            malformed.append((idx + 2, mutation, f"Invalid mutant residue '{mut_res}'"))
            continue
        
        # Residue number should be numeric
        if not res_num.isdigit():
            malformed.append((idx + 2, mutation, f"Invalid residue number '{res_num}' (should be numeric)"))
            continue
    
    if malformed:
        issues.append(f"❌ {len(malformed)} malformed mutation entries:")
        for row, mut, reason in malformed[:10]:  # Show first 10
            issues.append(f"   Row {row}: '{mut}' - {reason}")
        if len(malformed) > 10:
            issues.append(f"   ... and {len(malformed) - 10} more")
    
    # Check for multiple mutations in the string (comma, colon or semicolon)
    multi_mut_mask = df[mutation_col].str.contains('[,:;]', regex=True, na=False)
    multi_mut_count = multi_mut_mask.sum()
    if multi_mut_count > 0:
        issues.append(f"❌ {multi_mut_count} entries appear to contain multiple mutations (comma/colon/semicolon separated)")
        examples = df.loc[multi_mut_mask, mutation_col].head(5).tolist()
        issues.append(f"   Examples: {examples}")
    
    # ----------- NEW: compatibility with plotting.load_aggregated_data -----------
    # The plotting code will run `df[mutation_col].str.split('.', 3)` and then try
    # to build a DataFrame with exactly 4 columns.  If even **one** row returns a
    # list whose length is different from 4 that call will raise and the plot
    # will abort.  Catch that scenario here so the user sees the offending rows.
    split_lists = df[mutation_col].dropna().apply(lambda s: str(s).split('.', 3))
    bad_len_mask = split_lists.apply(len) != 4
    if bad_len_mask.any():
        bad_idx = bad_len_mask[bad_len_mask].index
        issues.append(f"❌ {len(bad_idx)} mutation strings would not split into 4 parts (exactly the error the plot catches)")
        examples = df.loc[bad_idx, mutation_col].head(5).tolist()
        issues.append(f"   Examples: {examples}")
    
    if issues:
        for issue in issues:
            print(issue)
        return False
    
    print("✅ Mutation column format is valid")
    return True

def check_state_column(df):
    """Check state column for required values."""
    print("\n🔍 Checking state column...")
    
    if 'state' not in df.columns:
        print("❌ ERROR: 'state' column not found!")
        return False
    
    # Check for required states
    required_states = {'ddg', 'wt', 'mut'}
    actual_states = set(df['state'].dropna().unique())
    
    missing_states = required_states - actual_states
    if missing_states:
        print(f"❌ ERROR: Missing required states: {missing_states}")
        print(f"   Found states: {actual_states}")
        return False
    
    # Check for NaN values in state
    nan_count = df['state'].isna().sum()
    if nan_count > 0:
        print(f"❌ ERROR: {nan_count} NaN values in state column")
        return False
    
    print("✅ State column is valid")
    return True

def check_numeric_columns(df):
    """Check numeric columns for issues."""
    print("\n🔍 Checking numeric columns...")
    
    numeric_cols = ['total_score']
    # Add energy contribution columns if they exist
    energy_cols = [col for col in df.columns if col.startswith('fa_') or 
                   col in ['hbond_sr_bb', 'hbond_lr_bb', 'hbond_bb_sc', 'hbond_sc', 
                          'omega', 'fa_dun', 'p_aa_pp', 'yhh_planarity', 'ref', 'rama_prepro']]
    numeric_cols.extend(energy_cols)
    
    issues = []
    
    for col in numeric_cols:
        if col not in df.columns:
            continue
        
        # Check for non-numeric values
        try:
            pd.to_numeric(df[col], errors='raise')
        except (ValueError, TypeError):
            non_numeric = df[col].apply(lambda x: not isinstance(x, (int, float, np.number)) and pd.notna(x))
            if non_numeric.any():
                bad_vals = df.loc[non_numeric, col].tolist()[:5]
                issues.append(f"❌ Non-numeric values in '{col}': {bad_vals}")
    
    if issues:
        for issue in issues:
            print(issue)
        return False
    
    print("✅ Numeric columns are valid")
    return True

def check_saturation_compatibility(df):
    """Check if data is compatible with saturation mutagenesis plotting."""
    print("\n🔍 Checking saturation mutagenesis compatibility...")
    
    # Get only ddg rows
    ddg_df = df[df['state'] == 'ddg'].copy()
    
    if len(ddg_df) == 0:
        print("❌ ERROR: No ddg rows found!")
        return False
    
    # Extract position information from mutations
    positions = {}  # position -> set of mutant residues
    
    for _, row in ddg_df.iterrows():
        mutation = row['mutation']
        parts = mutation.split('.', 3)
        
        if len(parts) != 4:
            continue
        
        chain, wt_res, res_num, mut_res = parts
        position = f"{chain}.{wt_res}.{res_num}"
        
        if position not in positions:
            positions[position] = set()
        positions[position].add(mut_res)
    
    # Check for duplicate mutations (same position, same mutant)
    duplicates = []
    mutation_counts = ddg_df['mutation'].value_counts()
    duplicates = mutation_counts[mutation_counts > 1]
    
    if len(duplicates) > 0:
        print(f"❌ WARNING: {len(duplicates)} duplicate mutations found:")
        for mut, count in duplicates.head(10).items():
            print(f"   '{mut}' appears {count} times")
    
    # Check for multiple mutations (contains comma or colon)
    multi_mut = ddg_df['mutation'].str.contains('[,:;]', regex=True, na=False)
    if multi_mut.any():
        multi_count = multi_mut.sum()
        examples = ddg_df.loc[multi_mut, 'mutation'].head(5).tolist()
        print(f"❌ ERROR: {multi_count} multiple mutations found (not compatible with saturation plot):")
        for example in examples:
            print(f"   '{example}'")
        return False
    
    print(f"✅ Found {len(positions)} positions with saturation data")
    
    # Show summary of positions
    for pos, muts in list(positions.items())[:5]:
        print(f"   {pos}: {len(muts)} mutations ({sorted(muts)})")
    if len(positions) > 5:
        print(f"   ... and {len(positions) - 5} more positions")
    
    return True

def check_data_consistency(df):
    """Check for data consistency issues."""
    print("\n🔍 Checking data consistency...")
    
    issues = []
    
    # Check if each mutation has all three states (wt, mut, ddg)
    mutation_groups = df.groupby('mutation')['state'].apply(set)
    
    incomplete_mutations = []
    for mutation, states in mutation_groups.items():
        expected_states = {'wt', 'mut', 'ddg'}
        if not expected_states.issubset(states):
            missing = expected_states - states
            incomplete_mutations.append((mutation, missing))
    
    if incomplete_mutations:
        issues.append(f"❌ {len(incomplete_mutations)} mutations missing states:")
        for mut, missing in incomplete_mutations[:5]:
            issues.append(f"   '{mut}' missing: {missing}")
        if len(incomplete_mutations) > 5:
            issues.append(f"   ... and {len(incomplete_mutations) - 5} more")
    
    # Check for consistent energy units
    energy_units = df['energy_unit'].unique()
    if len(energy_units) > 1:
        issues.append(f"❌ Multiple energy units found: {energy_units}")
    
    # Check for consistent score function
    score_functions = df['score_function_name'].unique()
    if len(score_functions) > 1:
        issues.append(f"❌ Multiple score functions found: {score_functions}")
    
    if issues:
        for issue in issues:
            print(issue)
        return False
    
    print("✅ Data consistency checks passed")
    return True

def main():
    """Main diagnostic function."""
    # Get filename from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = "ddg_mutations_aggregate.csv"
    
    print(f"🔍 Diagnosing CSV file: {filepath}")
    print("=" * 60)
    
    # Run all checks
    checks = [
        ("File existence", lambda: check_file_exists(filepath)),
        ("CSV structure", lambda: check_csv_structure(filepath)),
    ]
    
    # Load dataframe for subsequent checks
    df = None
    if check_file_exists(filepath):
        df = check_csv_structure(filepath)
    
    if df is None:
        print("\n❌ Cannot proceed with further checks - file loading failed")
        sys.exit(1)
    
    # Continue with dataframe-based checks
    additional_checks = [
        ("Required columns", lambda: check_required_columns(df)),
        ("Mutation format", lambda: check_mutation_column_format(df)),
        ("State column", lambda: check_state_column(df)),
        ("Numeric columns", lambda: check_numeric_columns(df)),
        ("Saturation compatibility", lambda: check_saturation_compatibility(df)),
        ("Data consistency", lambda: check_data_consistency(df)),
    ]
    
    all_passed = True
    
    for check_name, check_func in additional_checks:
        try:
            result = check_func()
            if not result:
                all_passed = False
        except Exception as e:
            print(f"❌ ERROR in {check_name}: {e}")
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 ALL CHECKS PASSED!")
        print("   Your CSV should work with rosetta_ddg_plot total_heatmap_saturation")
    else:
        print("❌ SOME CHECKS FAILED!")
        print("   Fix the issues above before running rosetta_ddg_plot")
        sys.exit(1)

if __name__ == "__main__":
    main() 