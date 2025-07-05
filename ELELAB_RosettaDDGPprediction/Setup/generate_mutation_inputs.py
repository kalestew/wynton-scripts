#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
from Bio import PDB
from Bio.Data.IUPACData import protein_letters_3to1

def parse_residue_spans(span_list):
    """Parses residue span strings like ['A:30-37', 'B:50-55']."""
    residues = []
    for span in span_list:
        chain, rng = span.split(":")
        start, end = map(int, rng.split("-"))
        residues.append((chain, start, end))
    return residues

def generate_position_list(structure, spans, move_chain, output_file):
    model = structure[0]
    pos_entries = []

    for chain_id, start, end in spans:
        chain = model[chain_id]
        for res in chain.get_residues():
            if res.id[0] != ' ':
                continue  # skip heteroatoms, waters, etc.
            resseq = res.id[1]
            if start <= resseq <= end:
                res_3letter = res.resname.capitalize()
                if res_3letter not in protein_letters_3to1:
                    print(f"Skipping unknown residue {res.resname} at {chain_id}{resseq}")
                    continue
                resname = protein_letters_3to1[res_3letter]
                pos_entry = f"{chain_id}.{resname}.{resseq} {move_chain}"
                pos_entries.append(pos_entry)

    with open(output_file, 'w') as f:
        for entry in pos_entries:
            f.write(entry + "\n")
    print(f"Generated position list: {output_file} with {len(pos_entries)} entries.")

def generate_residue_type_list(output_file):
    aa_types = "ACDEFGHIKLMNPQRSTVWY"
    with open(output_file, 'w') as f:
        for aa in aa_types:
            f.write(f"{aa}\n")
    print(f"Generated standard 20 AA reslist file: {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Generate RosettaDDG-compatible input files for saturation mutagenesis.")
    parser.add_argument("-p", "--pdb", required=True, help="Input PDB file")
    parser.add_argument("-s", "--spans", nargs='+', required=True,
                        help="Residue spans to include, e.g., A:30-37 B:50-60")
    parser.add_argument("-m", "--movechain", required=True,
                        help="Chain to be moved away from interface (for Flex ddG)")
    parser.add_argument("-o", "--output", default="positions.txt",
                        help="Output file name for position list")
    parser.add_argument("-r", "--residues", default="residues.txt",
                        help="Output file name for residue types list")
    parser.add_argument("--no_residues", action='store_true',
                        help="Don't write residue types list file")
    args = parser.parse_args()

    pdb_parser = PDB.PDBParser(QUIET=True)
    structure = pdb_parser.get_structure("input", args.pdb)
    spans = parse_residue_spans(args.spans)

    generate_position_list(structure, spans, args.movechain, args.output)

    if not args.no_residues:
        generate_residue_type_list(args.residues)

if __name__ == "__main__":
    main()
