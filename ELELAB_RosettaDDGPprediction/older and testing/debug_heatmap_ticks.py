#!/usr/bin/env python3
"""
Debug the tick/label mismatch in saturation heatmap plotting
"""

import pandas as pd
import numpy as np
import sys

def debug_heatmap_data(filepath):
    """Debug the data transformation for saturation heatmap"""
    
    print(f"🔍 Debugging heatmap data transformation for: {filepath}")
    print("=" * 60)
    
    # Load the dataframe
    df = pd.read_csv(filepath)
    print(f"✅ Loaded CSV: {len(df)} rows")
    
    # Define columns (from defaults.py)
    mutation_col = "mutation"
    pos_label_col = "position_label"
    state_col = "state"
    tot_score_col = "total_score"
    MUTR = "_mutr_"
    
    # Filter for ddg rows only (as the plotting code does)
    ddg_df = df[df[state_col] == "ddg"].copy()
    print(f"\n✅ Filtered to ddg rows: {len(ddg_df)} rows")
    
    # Add the mutation components
    new_cols = pd.DataFrame(
        ddg_df[mutation_col].str.split(".", n=3).tolist(),
        columns=["_chain_", "_wtr_", "_numr_", MUTR]
    )
    ddg_df = pd.concat([ddg_df.reset_index(drop=True), new_cols], axis=1)
    
    # Get unique positions
    positions = ddg_df[pos_label_col].unique()
    print(f"\n📊 Unique positions: {len(positions)}")
    print(f"   First 5: {positions[:5]}")
    
    # Get unique mutant residues
    mutants = ddg_df[MUTR].unique()
    print(f"\n📊 Unique mutant residues: {len(mutants)}")
    print(f"   All: {sorted(mutants)}")
    
    # Create the pivot table (as plotting code does)
    print(f"\n🔍 Creating pivot table...")
    pivot_df = ddg_df[[pos_label_col, MUTR, tot_score_col]].pivot(
        index=pos_label_col,
        columns=MUTR,
        values=tot_score_col
    ).transpose()
    
    print(f"\n📊 Pivot table shape: {pivot_df.shape}")
    print(f"   Rows (mutant residues): {pivot_df.shape[0]}")
    print(f"   Columns (positions): {pivot_df.shape[1]}")
    
    # Check for NaN values
    nan_count = pivot_df.isna().sum().sum()
    total_cells = pivot_df.shape[0] * pivot_df.shape[1]
    print(f"\n📊 NaN values: {nan_count} out of {total_cells} cells ({nan_count/total_cells*100:.1f}%)")
    
    # The issue seems to be that the code expects different dimensions
    print(f"\n⚠️  Potential issue:")
    print(f"   The error mentions 24 tick locations but 70 labels")
    print(f"   Your data has {len(positions)} positions")
    print(f"   This suggests the plotting code might be using wrong axis")
    
    # Check if positions are ordered correctly
    print(f"\n🔍 Checking position ordering...")
    print(f"   First 10 positions in data: {list(positions[:10])}")
    
    # Save a sample of the pivot table for inspection
    sample_file = "pivot_table_sample.csv"
    pivot_df.head().to_csv(sample_file)
    print(f"\n💾 Saved pivot table sample to {sample_file}")
    
    return pivot_df

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = "ddg_mutations_aggregate.csv"
    
    debug_heatmap_data(filepath)

if __name__ == "__main__":
    main() 