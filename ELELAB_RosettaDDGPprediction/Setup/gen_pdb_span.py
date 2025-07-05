#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
from Bio import PDB
from Bio.Data.IUPACData import protein_letters_3to1
from collections import namedtuple

# Reverse mapping
three_to_one = {k.upper(): v for k, v in protein_letters_3to1.items()}
Match = namedtuple("Match", ["chain_id", "start_resnum", "end_resnum", "mismatches"])

def extract_chain_sequence(chain):
    sequence = []
    res_nums = []

    for res in chain:
        if res.id[0] != ' ':  # exclude heteroatoms/waters
            continue
        resname = res.resname.upper()
        if resname in three_to_one:
            sequence.append(three_to_one[resname])
        else:
            sequence.append('X')  # unknown residue
        res_nums.append(res.id[1])
    return sequence, res_nums

def hamming_distance(seq1, seq2):
    """Returns the number of mismatched characters between two strings."""
    return sum(a != b for a, b in zip(seq1, seq2))

def find_matches(sequence, res_nums, query, max_mismatches):
    matches = []
    qlen = len(query)

    for i in range(len(sequence) - qlen + 1):
        window = sequence[i:i+qlen]
        mismatches = hamming_distance(query, window)
        if mismatches <= max_mismatches:
            matches.append((res_nums[i], res_nums[i + qlen - 1], mismatches))
    return matches

def find_spans_in_pdb(pdb_file, query, max_mismatches):
    parser = PDB.PDBParser(QUIET=True)
    structure = parser.get_structure("query", pdb_file)
    model = structure[0]

    query = query.upper()
    results = []

    for chain in model:
        chain_id = chain.id
        sequence, res_nums = extract_chain_sequence(chain)

        if not sequence or len(res_nums) < len(query):
            continue

        matches = find_matches(sequence, res_nums, query, max_mismatches)
        for start, end, mismatches in matches:
            results.append(Match(chain_id, start, end, mismatches))

    return results

def main():
    parser = argparse.ArgumentParser(description="Find spans in a PDB chain matching a 1-letter AA query string.")
    parser.add_argument("-p", "--pdb", required=True, help="Input PDB file")
    parser.add_argument("-s", "--sequence", required=True, help="Query sequence in 1-letter AA codes (e.g., EVOLVQ)")
    parser.add_argument("--fuzzy", type=int, default=0, help="Allow up to N mismatches (default: 0 = exact match)")
    args = parser.parse_args()

    query = args.sequence.upper()
    if any(aa not in "ACDEFGHIKLMNPQRSTVWY" for aa in query):
        print("Error: Invalid character in query sequence. Only standard 20 amino acids allowed.")
        exit(1)

    spans = find_spans_in_pdb(args.pdb, query, args.fuzzy)
    if not spans:
        print(f"No match found for sequence '{query}' in {args.pdb} (max mismatches: {args.fuzzy})")
        exit(2)

    print(f"Found {len(spans)} match(es):")
    for match in spans:
        fuzz_note = f" ({match.mismatches} mismatch{'es' if match.mismatches != 1 else ''})" if match.mismatches else ""
        print(f"{match.chain_id}:{match.start_resnum}-{match.end_resnum}{fuzz_note}")

if __name__ == "__main__":
    main()
