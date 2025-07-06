#!/usr/bin/env python3
"""
Convert RosettaDDG mutinfo.txt format to MutateX position list format.

RosettaDDG format: H.S.214
MutateX format: SH214
"""

import argparse
import re
import sys
from collections import OrderedDict

def parse_rosetta_position(position_str):
    """
    Parse RosettaDDG position format.
    
    Input: "H.S.214" or "H S 214"
    Output: ("H", "S", 214)
    """
    # Handle both dot-separated and space-separated formats
    parts = position_str.replace('.', ' ').split()
    
    if len(parts) != 3:
        raise ValueError(f"Invalid position format: {position_str}")
    
    chain = parts[0]
    residue = parts[1].upper()
    
    # Handle single-letter or three-letter codes
    if len(residue) == 3:
        # Convert three-letter to one-letter
        from Bio.Data.IUPACData import protein_letters_3to1
        three_to_one = {k.upper(): v for k, v in protein_letters_3to1.items()}
        if residue in three_to_one:
            residue = three_to_one[residue]
        else:
            print(f"Warning: Unknown residue {residue}, using 'X'")
            residue = 'X'
    elif len(residue) != 1:
        raise ValueError(f"Invalid residue code: {residue}")
    
    try:
        resnum = int(parts[2])
    except ValueError:
        raise ValueError(f"Invalid residue number: {parts[2]}")
    
    return chain, residue, resnum

def convert_mutinfo_to_mutatex(mutinfo_file, output_file, unique_only=True):
    """
    Convert RosettaDDG mutinfo.txt to MutateX position list.
    
    Args:
        mutinfo_file: Path to mutinfo.txt file
        output_file: Path to output position list
        unique_only: If True, only output unique positions
    """
    positions = []
    seen_positions = set()
    
    with open(mutinfo_file, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            # Extract position from various formats
            # Format 1: position mutation_dir
            # Format 2: just position
            parts = line.split()
            if not parts:
                continue
            
            position_str = parts[0]
            
            try:
                chain, residue, resnum = parse_rosetta_position(position_str)
                mutatex_format = f"{residue}{chain}{resnum}"
                
                if unique_only:
                    if mutatex_format not in seen_positions:
                        seen_positions.add(mutatex_format)
                        positions.append(mutatex_format)
                else:
                    positions.append(mutatex_format)
                    
            except ValueError as e:
                print(f"Warning: Line {line_num}: {e} - skipping line: '{line}'")
                continue
    
    # Write output
    with open(output_file, 'w') as f:
        for pos in positions:
            f.write(pos + '\n')
    
    return positions

def convert_spans_file(spans_file, pdb_file, output_file):
    """
    Convert a file containing chain:start-end spans to MutateX format.
    Requires PDB file to get actual residue identities.
    """
    from Bio import PDB
    from Bio.Data.IUPACData import protein_letters_3to1
    
    three_to_one = {k.upper(): v for k, v in protein_letters_3to1.items()}
    
    # Parse PDB
    parser = PDB.PDBParser(QUIET=True)
    structure = parser.get_structure("input", pdb_file)
    model = structure[0]
    
    positions = []
    
    with open(spans_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Parse span format: A:30-37
            if ':' not in line:
                print(f"Warning: Invalid span format: {line}")
                continue
            
            chain_id, range_str = line.split(':', 1)
            
            if '-' in range_str:
                start, end = map(int, range_str.split('-'))
            else:
                # Single residue
                start = end = int(range_str)
            
            # Get residues from PDB
            if chain_id in model:
                chain = model[chain_id]
                for res in chain:
                    if res.id[0] != ' ':  # Skip heteroatoms
                        continue
                    
                    resnum = res.id[1]
                    if start <= resnum <= end:
                        res_3letter = res.resname.capitalize()
                        if res_3letter in three_to_one:
                            one_letter = three_to_one[res_3letter]
                        else:
                            one_letter = 'X'
                        
                        positions.append(f"{one_letter}{chain_id}{resnum}")
            else:
                print(f"Warning: Chain {chain_id} not found in PDB")
    
    # Write output
    with open(output_file, 'w') as f:
        for pos in positions:
            f.write(pos + '\n')
    
    return positions

def main():
    parser = argparse.ArgumentParser(
        description="Convert between RosettaDDG and MutateX position formats",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert mutinfo.txt to MutateX position list
  %(prog)s -i mutinfo.txt -o position_list.txt
  
  # Convert with duplicates preserved
  %(prog)s -i mutinfo.txt -o position_list.txt --keep-duplicates
  
  # Convert spans file (requires PDB)
  %(prog)s -i spans.txt -o position_list.txt --pdb structure.pdb --spans
  
  # Show statistics only
  %(prog)s -i mutinfo.txt --stats-only
        """
    )
    
    parser.add_argument("-i", "--input", required=True, help="Input file (mutinfo.txt or spans file)")
    parser.add_argument("-o", "--output", help="Output position list file")
    parser.add_argument("-p", "--pdb", help="PDB file (required for --spans mode)")
    parser.add_argument("--spans", action='store_true', help="Input is spans file (chain:start-end format)")
    parser.add_argument("--keep-duplicates", action='store_true', help="Keep duplicate positions")
    parser.add_argument("--stats-only", action='store_true', help="Only show statistics, don't write output")
    
    args = parser.parse_args()
    
    if args.spans and not args.pdb:
        print("Error: --pdb is required when using --spans mode")
        sys.exit(1)
    
    if not args.stats_only and not args.output:
        print("Error: --output is required unless using --stats-only")
        sys.exit(1)
    
    try:
        if args.spans:
            positions = convert_spans_file(args.input, args.pdb, args.output)
        else:
            positions = convert_mutinfo_to_mutatex(
                args.input, 
                args.output if not args.stats_only else "/dev/null",
                unique_only=not args.keep_duplicates
            )
        
        # Print statistics
        print(f"\n=== Conversion Summary ===")
        print(f"Input file: {args.input}")
        if not args.stats_only:
            print(f"Output file: {args.output}")
        print(f"Total positions: {len(positions)}")
        
        if positions:
            # Count by chain
            chain_counts = {}
            for pos in positions:
                chain = pos[1]  # Second character is chain
                chain_counts[chain] = chain_counts.get(chain, 0) + 1
            
            print("\nPositions by chain:")
            for chain in sorted(chain_counts.keys()):
                print(f"  Chain {chain}: {chain_counts[chain]} positions")
            
            if len(positions) <= 20:
                print("\nAll positions:")
                for pos in positions:
                    print(f"  {pos}")
            else:
                print("\nFirst 10 positions:")
                for pos in positions[:10]:
                    print(f"  {pos}")
                print(f"  ... and {len(positions) - 10} more")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 