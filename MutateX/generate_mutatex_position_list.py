#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Enhanced MutateX position list generator with smart sequence matching and interactive features.
Inspired by ELELAB RosettaDDGPrediction utilities.
"""

import argparse
import sys
from Bio import PDB
from Bio.Data.IUPACData import protein_letters_3to1
from collections import namedtuple

# Reverse mapping for 3-letter to 1-letter AA codes
three_to_one = {k.upper(): v for k, v in protein_letters_3to1.items()}

# Named tuple for sequence matches
Match = namedtuple("Match", ["chain_id", "start_resnum", "end_resnum", "mismatches", "sequence"])

def extract_chain_sequence(chain):
    """Extract sequence and residue numbers from a PDB chain."""
    sequence = []
    res_nums = []
    
    for res in chain:
        if res.id[0] != ' ':  # Skip heteroatoms/waters
            continue
        resname = res.resname.upper()
        if resname in three_to_one:
            sequence.append(three_to_one[resname])
        else:
            sequence.append('X')  # Unknown residue
        res_nums.append(res.id[1])
    
    return sequence, res_nums

def hamming_distance(seq1, seq2):
    """Calculate the number of mismatched characters between two sequences."""
    return sum(a != b for a, b in zip(seq1, seq2))

def find_sequence_matches(structure, query, max_mismatches=0):
    """Find all occurrences of a query sequence in the PDB structure."""
    model = structure[0]
    query = query.upper()
    matches = []
    
    for chain in model:
        chain_id = chain.id
        sequence, res_nums = extract_chain_sequence(chain)
        
        if not sequence or len(sequence) < len(query):
            continue
        
        # Search for matches with sliding window
        for i in range(len(sequence) - len(query) + 1):
            window = sequence[i:i+len(query)]
            mismatches = hamming_distance(query, window)
            
            if mismatches <= max_mismatches:
                start_res = res_nums[i]
                end_res = res_nums[i + len(query) - 1]
                matched_seq = ''.join(window)
                matches.append(Match(chain_id, start_res, end_res, mismatches, matched_seq))
    
    return matches

def parse_residue_spans(span_list):
    """Parse residue span strings like ['A:30-37', 'B:50-55']."""
    residues = []
    for span in span_list:
        if ':' not in span:
            raise ValueError(f"Invalid span format: {span}. Expected format: CHAIN:START-END")
        chain, rng = span.split(":")
        if '-' not in rng:
            raise ValueError(f"Invalid range format: {rng}. Expected format: START-END")
        start, end = map(int, rng.split("-"))
        if start > end:
            raise ValueError(f"Invalid range: {start}-{end}. Start must be <= end.")
        residues.append((chain, start, end))
    return residues

def validate_spans_in_structure(structure, spans):
    """Validate that specified spans exist in the structure."""
    model = structure[0]
    warnings = []
    
    for chain_id, start, end in spans:
        if chain_id not in model:
            warnings.append(f"Chain {chain_id} not found in structure")
            continue
        
        chain = model[chain_id]
        res_nums = [res.id[1] for res in chain if res.id[0] == ' ']
        
        if not res_nums:
            warnings.append(f"Chain {chain_id} has no standard residues")
            continue
        
        min_res, max_res = min(res_nums), max(res_nums)
        
        if start < min_res or end > max_res:
            warnings.append(f"Span {chain_id}:{start}-{end} partially outside chain range {min_res}-{max_res}")
    
    return warnings

def generate_position_list(structure, spans, output_file, include_non_standard=False, append_output=False):
    """Generate a MutateX-compatible position list."""
    model = structure[0]
    pos_entries = []
    skipped_residues = []
    
    for chain_id, start, end in spans:
        if chain_id not in model:
            print(f"Warning: Chain {chain_id} not found in structure.")
            continue
        
        chain = model[chain_id]
        for res in chain.get_residues():
            if res.id[0] != ' ':
                continue  # Skip heteroatoms/waters
            
            resseq = res.id[1]
            if start <= resseq <= end:
                res_3letter = res.resname.upper()
                
                if res_3letter not in three_to_one:
                    if include_non_standard:
                        # Use 'X' for unknown residues
                        one_letter = 'X'
                        print(f"Including non-standard residue {res.resname} as X at {chain_id}{resseq}")
                    else:
                        skipped_residues.append(f"{res.resname} at {chain_id}{resseq}")
                        continue
                else:
                    one_letter = three_to_one[res_3letter]
                
                pos_entry = f"{one_letter}{chain_id}{resseq}"
                pos_entries.append(pos_entry)
    
    # Write output file
    mode = 'a' if append_output else 'w'
    with open(output_file, mode) as f:
        for entry in pos_entries:
            f.write(entry + "\n")
    
    # Print summary
    print(f"\n=== Position List Generation Summary ===")
    print(f"Output file: {output_file}")
    print(f"Total positions: {len(pos_entries)}")
    
    if skipped_residues:
        print(f"\nSkipped {len(skipped_residues)} non-standard residues:")
        for skip in skipped_residues[:5]:  # Show first 5
            print(f"  - {skip}")
        if len(skipped_residues) > 5:
            print(f"  ... and {len(skipped_residues) - 5} more")
    
    return pos_entries

def interactive_mode(structure):
    """Interactive mode for exploring and selecting spans."""
    model = structure[0]
    
    print("\n=== Interactive Mode ===")
    print("Available chains in structure:")
    
    chain_info = []
    for chain in model:
        chain_id = chain.id
        residues = [res for res in chain if res.id[0] == ' ']
        if residues:
            res_nums = [res.id[1] for res in residues]
            min_res, max_res = min(res_nums), max(res_nums)
            chain_info.append((chain_id, len(residues), min_res, max_res))
            print(f"  Chain {chain_id}: {len(residues)} residues (range: {min_res}-{max_res})")
    
    if not chain_info:
        print("No standard residues found in structure!")
        return []
    
    # Allow user to search for sequences
    while True:
        print("\nOptions:")
        print("  1. Search for a sequence motif")
        print("  2. Manually enter residue spans")
        print("  3. Select entire chains")
        print("  4. Exit interactive mode")
        
        choice = input("\nSelect option (1-4): ").strip()
        
        if choice == '1':
            query = input("Enter sequence to search (1-letter code): ").strip().upper()
            if not query:
                continue
            
            fuzzy = input("Allow mismatches? (0 for exact match, or number): ").strip()
            max_mismatches = int(fuzzy) if fuzzy.isdigit() else 0
            
            matches = find_sequence_matches(structure, query, max_mismatches)
            
            if not matches:
                print(f"No matches found for '{query}' with {max_mismatches} allowed mismatches")
            else:
                print(f"\nFound {len(matches)} match(es):")
                spans = []
                for i, match in enumerate(matches):
                    mismatch_info = f" ({match.mismatches} mismatch{'es' if match.mismatches != 1 else ''})" if match.mismatches else ""
                    print(f"  {i+1}. Chain {match.chain_id}: {match.start_resnum}-{match.end_resnum} [{match.sequence}]{mismatch_info}")
                    spans.append(f"{match.chain_id}:{match.start_resnum}-{match.end_resnum}")
                
                use_all = input("\nUse all matches? (y/n): ").strip().lower()
                if use_all == 'y':
                    return spans
                else:
                    selected = input("Enter match numbers to use (comma-separated, e.g., 1,3): ").strip()
                    if selected:
                        indices = [int(x.strip()) - 1 for x in selected.split(',') if x.strip().isdigit()]
                        return [spans[i] for i in indices if 0 <= i < len(spans)]
        
        elif choice == '2':
            spans_input = input("Enter residue spans (e.g., A:30-37,B:50-60): ").strip()
            if spans_input:
                return [s.strip() for s in spans_input.split(',')]
        
        elif choice == '3':
            print("\nAvailable chains:")
            for i, (chain_id, count, min_res, max_res) in enumerate(chain_info):
                print(f"  {i+1}. Chain {chain_id} ({min_res}-{max_res})")
            
            selected = input("\nSelect chains (comma-separated numbers): ").strip()
            if selected:
                indices = [int(x.strip()) - 1 for x in selected.split(',') if x.strip().isdigit()]
                spans = []
                for i in indices:
                    if 0 <= i < len(chain_info):
                        chain_id, _, min_res, max_res = chain_info[i]
                        spans.append(f"{chain_id}:{min_res}-{max_res}")
                return spans
        
        elif choice == '4':
            return []

def main():
    parser = argparse.ArgumentParser(
        description="Generate MutateX position list with smart sequence matching and interactive features",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  %(prog)s -p structure.pdb -i
  
  # Search for sequence motif
  %(prog)s -p structure.pdb -q EVQLVQ --fuzzy 1
  
  # Manual spans
  %(prog)s -p structure.pdb -s A:30-37 B:50-60
  
  # Combine sequence search with manual spans
  %(prog)s -p structure.pdb -q DIQMTQ -s A:100-110
        """
    )
    
    parser.add_argument("-p", "--pdb", required=True, help="Input PDB file")
    parser.add_argument("-s", "--spans", nargs='+', help="Residue spans to include (e.g., A:30-37 B:50-60)")
    parser.add_argument("-q", "--query", action='append', help="Sequence motif to search (1-letter AA). Repeat -q for multiple motifs")
    parser.add_argument("--fuzzy", type=int, default=0, help="Allow up to N mismatches in sequence search (default: 0)")
    parser.add_argument("-i", "--interactive", action='store_true', help="Interactive mode for span selection")
    parser.add_argument("-o", "--output", default="position_list.txt", help="Output file name (default: position_list.txt)")
    parser.add_argument("--include-non-standard", action='store_true', help="Include non-standard residues as 'X'")
    parser.add_argument("--append-output", action='store_true', help="Append to output file instead of overwriting")
    parser.add_argument("--validate", action='store_true', help="Validate spans and show warnings")
    
    args = parser.parse_args()
    
    # Parse PDB structure
    print(f"Loading PDB file: {args.pdb}")
    pdb_parser = PDB.PDBParser(QUIET=True)
    structure = pdb_parser.get_structure("input", args.pdb)
    
    # Collect spans from different sources
    all_spans = []
    
    # Interactive mode
    if args.interactive:
        interactive_spans = interactive_mode(structure)
        if interactive_spans:
            all_spans.extend(interactive_spans)
    
    # Query sequence search
    if args.query:
        for q in args.query:
            print(f"\nSearching for sequence: {q} (max {args.fuzzy} mismatches)")
            matches = find_sequence_matches(structure, q, args.fuzzy)
            
            if not matches:
                print(f"No matches found for '{q}'")
            else:
                print(f"Found {len(matches)} match(es):")
                for match in matches:
                    mismatch_info = f" ({match.mismatches} mismatch{'es' if match.mismatches != 1 else ''})" if match.mismatches else ""
                    span = f"{match.chain_id}:{match.start_resnum}-{match.end_resnum}"
                    print(f"  {span} [{match.sequence}]{mismatch_info}")
                    all_spans.append(span)
    
    # Manual spans
    if args.spans:
        all_spans.extend(args.spans)
    
    # No spans specified
    if not all_spans:
        print("\nNo spans specified. Use -s, -q, or -i to select residues.")
        sys.exit(1)
    
    # Remove duplicates while preserving order
    unique_spans = []
    seen = set()
    for span in all_spans:
        if span not in seen:
            seen.add(span)
            unique_spans.append(span)
    
    print(f"\nProcessing {len(unique_spans)} unique span(s): {', '.join(unique_spans)}")
    
    # Parse and validate spans
    try:
        parsed_spans = parse_residue_spans(unique_spans)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    
    # Validation
    if args.validate:
        warnings = validate_spans_in_structure(structure, parsed_spans)
        if warnings:
            print("\nValidation warnings:")
            for warning in warnings:
                print(f"  - {warning}")
    
    # Generate position list
    positions = generate_position_list(structure, parsed_spans, args.output, args.include_non_standard, args.append_output)
    
    if not positions:
        print("\nWarning: No valid positions found!")
        sys.exit(1)

if __name__ == "__main__":
    main()
