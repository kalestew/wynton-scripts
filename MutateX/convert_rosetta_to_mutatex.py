#!/usr/bin/env python3
"""
Convert RosettaDDG mutinfo.txt format to MutateX position list format.

Accepted Rosetta position formats in input lines (commas and/or spaces allowed):
- H.S.214                -> chain.residue.position
- H.S.214.A              -> chain.residue.position.mut_residue (mut part ignored)
- H-S214A                -> chain-wtResNumMut (mut part ignored)
- H S 214                -> space-separated chain residue position

Any line may contain multiple comma-separated representations of the same
mutation/position (e.g., "E.S.657.A,E-S657A,S657A,S657"). This tool will
extract the chain, wild-type residue and position from any supported token in
the line. Tokens without chain information (e.g., "S657A", "S657") are ignored.

MutateX format: SH214
"""

import argparse
import re
import sys
from collections import OrderedDict

def _to_one_letter(residue_code: str) -> str:
    """Convert a residue code to one-letter if possible.

    Accepts one-letter or three-letter codes. Unknowns return 'X'.
    """
    residue_code = residue_code.upper()
    if len(residue_code) == 1:
        return residue_code
    if len(residue_code) == 3:
        from Bio.Data.IUPACData import protein_letters_3to1
        three_to_one = {k.upper(): v for k, v in protein_letters_3to1.items()}
        return three_to_one.get(residue_code, 'X')
    return 'X'

def parse_rosetta_position(position_str: str):
    """
    Parse a single token describing a Rosetta DDG mutation position.

    Supports:
      - "H.S.214" or "H S 214"
      - "H.S.214.A" (mutant residue ignored)
      - "H-S214A" (mutant residue ignored)

    Returns (chain, wt_res_one_letter, resnum) or raises ValueError.
    """
    s = position_str.strip()

    # 1) Dot/space-separated: chain residue resnum [mut]
    parts = s.replace('.', ' ').split()
    if len(parts) in (3, 4):
        chain = parts[0]
        residue = _to_one_letter(parts[1])
        try:
            resnum = int(parts[2])
        except ValueError:
            raise ValueError(f"Invalid residue number: {parts[2]}")
        if not chain or len(chain) < 1:
            raise ValueError(f"Invalid chain: {chain}")
        return chain[0], residue, resnum

    # 2) Hyphenated: chain-wtResNum[mut]
    # Examples: E-S657A, E-Ser657A
    m = re.match(r"^([A-Za-z])\-([A-Za-z]{1,3})(\d+)([A-Za-z]{1,3})?$", s)
    if m:
        chain, wt_res, resnum_str, _mut = m.groups()
        residue = _to_one_letter(wt_res)
        return chain, residue, int(resnum_str)

    raise ValueError(f"Invalid position format: {position_str}")

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

            # Tokenize by commas and whitespace; try each token until one parses
            tokens = [t for t in re.split(r'[\s,]+', line) if t]
            parsed = False
            error_messages = []

            for token in tokens:
                try:
                    chain, residue, resnum = parse_rosetta_position(token)
                    mutatex_format = f"{residue}{chain}{resnum}"
                    if unique_only:
                        if mutatex_format not in seen_positions:
                            seen_positions.add(mutatex_format)
                            positions.append(mutatex_format)
                    else:
                        positions.append(mutatex_format)
                    parsed = True
                    break
                except ValueError as e:
                    error_messages.append(str(e))

            if not parsed:
                print(
                    f"Warning: Line {line_num}: Could not parse any token - skipping line: '{line}'"
                )
    
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