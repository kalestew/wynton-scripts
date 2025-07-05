#!/usr/bin/env python3
"""
Comprehensive debug script to find why rosetta_ddg_plot fails with
"You need to have only single mutations..." error.
"""

import pandas as pd
import sys
import traceback

def debug_plotting_comprehensive(filepath):
    """Check all possible causes of the plotting error"""
    
    print(f"🔍 Comprehensive debug for: {filepath}")
    print("=" * 60)
    
    # Load the dataframe
    try:
        df = pd.read_csv(filepath)
        print(f"✅ Loaded CSV: {len(df)} rows, {len(df.columns)} columns")
    except Exception as e:
        print(f"❌ Failed to load CSV: {e}")
        return
    
    # Define column names (from defaults.py)
    CHAIN = "_chain_"
    WTR = "_wtr_"
    NUMR = "_numr_"
    MUTR = "_mutr_"
    COMP_SEP = "."
    
    mutation_col = "mutation"
    
    print(f"\n🔍 Checking all rows for split compatibility...")
    
    # Check if any row has NaN in mutation column
    nan_count = df[mutation_col].isna().sum()
    if nan_count > 0:
        print(f"⚠️  Found {nan_count} NaN values in mutation column")
        nan_indices = df[df[mutation_col].isna()].index.tolist()[:5]
        print(f"   First few NaN indices: {nan_indices}")
    
    # Try the exact code from plotting.load_aggregated_data
    print(f"\n🔍 Reproducing exact plotting.load_aggregated_data logic...")
    
    try:
        # This is the EXACT try block from plotting.py
        new_cols = \
            pd.DataFrame(\
                df[mutation_col].str.split(COMP_SEP, 3).tolist(),
                columns = [CHAIN, WTR, NUMR, MUTR])
        
        print(f"✅ DataFrame construction succeeded!")
        print(f"   Shape: {new_cols.shape}")
        
        # Check if concat would work
        result = pd.concat([df, new_cols], axis=1)
        print(f"✅ Concat succeeded! Final shape: {result.shape}")
        
    except Exception as e:
        print(f"❌ FOUND THE ERROR: {e}")
        print(f"   Error type: {type(e).__name__}")
        print("\nFull traceback:")
        traceback.print_exc()
        
        # Try to identify which rows are problematic
        print("\n🔍 Identifying problematic rows...")
        
        # Get the split results
        split_results = df[mutation_col].str.split(COMP_SEP, 3).tolist()
        
        # Find rows with wrong number of parts
        for i, parts in enumerate(split_results):
            if len(parts) != 4:
                print(f"   Row {i+2}: '{df.iloc[i][mutation_col]}' splits into {len(parts)} parts: {parts}")
                print(f"      State: {df.iloc[i].get('state', 'N/A')}")
        
        return
    
    # Additional checks
    print(f"\n🔍 Additional checks...")
    
    # Check for multiple mutation separators
    multi_mut_chars = [',', ':', ';']
    for char in multi_mut_chars:
        mask = df[mutation_col].str.contains(char, na=False)
        count = mask.sum()
        if count > 0:
            print(f"⚠️  Found {count} rows containing '{char}'")
            examples = df.loc[mask, [mutation_col, 'state']].head(3)
            for idx, row in examples.iterrows():
                print(f"      Row {idx+2}: '{row[mutation_col]}' (state: {row['state']})")
    
    # Check state distribution
    print(f"\n🔍 State distribution:")
    state_counts = df['state'].value_counts()
    for state, count in state_counts.items():
        print(f"   {state}: {count} rows")
    
    # Check if filtering by state='ddg' would help
    ddg_df = df[df['state'] == 'ddg'].copy()
    print(f"\n🔍 Testing with only ddg rows ({len(ddg_df)} rows)...")
    
    try:
        new_cols_ddg = \
            pd.DataFrame(\
                ddg_df[mutation_col].str.split(COMP_SEP, 3).tolist(),
                columns = [CHAIN, WTR, NUMR, MUTR])
        print(f"✅ DataFrame construction with ddg-only rows succeeded!")
    except Exception as e:
        print(f"❌ Even ddg-only rows fail: {e}")
    
    print("\n" + "=" * 60)
    print("Debug complete!")

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = "ddg_mutations_aggregate.csv"
    
    debug_plotting_comprehensive(filepath)

if __name__ == "__main__":
    main() 