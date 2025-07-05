#!/usr/bin/env python3
"""
Debug script that reproduces the exact pandas operations that rosetta_ddg_plot
performs when loading saturation data. This will catch the exact error.
"""

import pandas as pd
import sys

def debug_plotting_load(filepath):
    """Reproduce the exact logic from plotting.load_aggregated_data with saturation=True"""
    
    print(f"🔍 Debugging plotting load for: {filepath}")
    print("=" * 60)
    
    # Load the dataframe (same as plotting code)
    try:
        df = pd.read_csv(filepath)
        print(f"✅ Loaded CSV: {len(df)} rows, {len(df.columns)} columns")
    except Exception as e:
        print(f"❌ Failed to load CSV: {e}")
        return
    
    # Check if mutation column exists
    mutation_col = "mutation"
    if mutation_col not in df.columns:
        print(f"❌ Column '{mutation_col}' not found!")
        return
    
    print(f"✅ Found mutation column with {len(df)} rows")
    
    # This is the EXACT code from plotting.load_aggregated_data when saturation=True
    print("\n🔍 Attempting the exact pandas operation that rosetta_ddg_plot does...")
    
    try:
        # This is the line that fails in rosetta_ddg_plot
        split_result = df[mutation_col].str.split(pat=".", n=3).tolist()
        print(f"✅ Split operation succeeded, got {len(split_result)} rows")
        
        # Check if all splits have exactly 4 parts
        bad_splits = []
        for i, parts in enumerate(split_result):
            if len(parts) != 4:
                bad_splits.append((i, parts, df.iloc[i][mutation_col]))
        
        if bad_splits:
            print(f"❌ Found {len(bad_splits)} rows that don't split into 4 parts:")
            for i, parts, original in bad_splits[:10]:  # Show first 10
                print(f"   Row {i+2}: '{original}' → {parts} ({len(parts)} parts)")
            if len(bad_splits) > 10:
                print(f"   ... and {len(bad_splits) - 10} more")
        else:
            print("✅ All rows split into exactly 4 parts")
        
        # Now try the DataFrame construction that actually fails
        print("\n🔍 Attempting DataFrame construction...")
        try:
            new_cols = pd.DataFrame(split_result, columns=["_chain_", "_wtr_", "_numr_", "_mutr_"])
            print(f"✅ DataFrame construction succeeded: {new_cols.shape}")
        except Exception as e:
            print(f"❌ DataFrame construction failed: {e}")
            print("This is the exact error that rosetta_ddg_plot hits!")
            
            # Show details about the split results
            lengths = [len(parts) for parts in split_result]
            unique_lengths = set(lengths)
            print(f"\nSplit result lengths: {unique_lengths}")
            for length in sorted(unique_lengths):
                count = lengths.count(length)
                print(f"   {count} rows have {length} parts")
                if length != 4:
                    # Show examples
                    examples = [(i, split_result[i], df.iloc[i][mutation_col]) 
                               for i in range(len(split_result)) 
                               if len(split_result[i]) == length][:3]
                    for i, parts, original in examples:
                        print(f"      Row {i+2}: '{original}' → {parts}")
            
            return
    
    except Exception as e:
        print(f"❌ Split operation failed: {e}")
        return
    
    print("\n✅ All operations succeeded - this shouldn't happen if rosetta_ddg_plot is failing!")

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = "ddg_mutations_aggregate.csv"
    
    debug_plotting_load(filepath)

if __name__ == "__main__":
    main() 