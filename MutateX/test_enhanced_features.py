#!/usr/bin/env python3
"""
Test script to demonstrate enhanced MutateX position list generator features.
This script creates a minimal test PDB and shows various usage patterns.
"""

import subprocess
import tempfile
import os

# Create a minimal test PDB content
TEST_PDB = """ATOM      1  N   GLY H  31      10.000  10.000  10.000  1.00 20.00           N  
ATOM      2  CA  GLY H  31      11.000  10.000  10.000  1.00 20.00           C  
ATOM      3  C   GLY H  31      12.000  10.000  10.000  1.00 20.00           C  
ATOM      4  O   GLY H  31      13.000  10.000  10.000  1.00 20.00           O  
ATOM      5  N   PHE H  32      10.000  11.000  10.000  1.00 20.00           N  
ATOM      6  CA  PHE H  32      11.000  11.000  10.000  1.00 20.00           C  
ATOM      7  C   PHE H  32      12.000  11.000  10.000  1.00 20.00           C  
ATOM      8  O   PHE H  32      13.000  11.000  10.000  1.00 20.00           O  
ATOM      9  N   THR H  33      10.000  12.000  10.000  1.00 20.00           N  
ATOM     10  CA  THR H  33      11.000  12.000  10.000  1.00 20.00           C  
ATOM     11  C   THR H  33      12.000  12.000  10.000  1.00 20.00           C  
ATOM     12  O   THR H  33      13.000  12.000  10.000  1.00 20.00           O  
ATOM     13  N   PHE H  34      10.000  13.000  10.000  1.00 20.00           N  
ATOM     14  CA  PHE H  34      11.000  13.000  10.000  1.00 20.00           C  
ATOM     15  C   PHE H  34      12.000  13.000  10.000  1.00 20.00           C  
ATOM     16  O   PHE H  34      13.000  13.000  10.000  1.00 20.00           O  
ATOM     17  N   SER H  35      10.000  14.000  10.000  1.00 20.00           N  
ATOM     18  CA  SER H  35      11.000  14.000  10.000  1.00 20.00           C  
ATOM     19  C   SER H  35      12.000  14.000  10.000  1.00 20.00           C  
ATOM     20  O   SER H  35      13.000  14.000  10.000  1.00 20.00           O  
ATOM     21  N   ARG L  50      20.000  10.000  10.000  1.00 20.00           N  
ATOM     22  CA  ARG L  50      21.000  10.000  10.000  1.00 20.00           C  
ATOM     23  C   ARG L  50      22.000  10.000  10.000  1.00 20.00           C  
ATOM     24  O   ARG L  50      23.000  10.000  10.000  1.00 20.00           O  
ATOM     25  N   ALA L  51      20.000  11.000  10.000  1.00 20.00           N  
ATOM     26  CA  ALA L  51      21.000  11.000  10.000  1.00 20.00           C  
ATOM     27  C   ALA L  51      22.000  11.000  10.000  1.00 20.00           C  
ATOM     28  O   ALA L  51      23.000  11.000  10.000  1.00 20.00           O  
ATOM     29  N   SER L  52      20.000  12.000  10.000  1.00 20.00           N  
ATOM     30  CA  SER L  52      21.000  12.000  10.000  1.00 20.00           C  
ATOM     31  C   SER L  52      22.000  12.000  10.000  1.00 20.00           C  
ATOM     32  O   SER L  52      23.000  12.000  10.000  1.00 20.00           O  
END
"""

def run_test(test_name, command, expected_output=None):
    """Run a test command and print results."""
    print(f"\n{'='*60}")
    print(f"TEST: {test_name}")
    print(f"{'='*60}")
    print(f"Command: {command}")
    print("-" * 60)
    
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    
    print("STDOUT:")
    print(result.stdout)
    
    if result.stderr:
        print("\nSTDERR:")
        print(result.stderr)
    
    print(f"\nExit code: {result.returncode}")
    
    if expected_output and os.path.exists(expected_output):
        print(f"\nOutput file ({expected_output}):")
        with open(expected_output, 'r') as f:
            content = f.read()
            print(content)
            print(f"Lines in output: {len(content.strip().split())}")
    
    return result.returncode == 0

def main():
    # Create temporary directory for tests
    with tempfile.TemporaryDirectory() as tmpdir:
        # Write test PDB
        test_pdb = os.path.join(tmpdir, "test.pdb")
        with open(test_pdb, 'w') as f:
            f.write(TEST_PDB)
        
        print("Enhanced MutateX Position List Generator - Feature Tests")
        print("========================================================")
        
        # Test 1: Basic manual span selection
        output1 = os.path.join(tmpdir, "test1_manual.txt")
        run_test(
            "Manual span selection",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -s H:31-33 L:50-52 -o {output1}",
            output1
        )
        
        # Test 2: Sequence search (exact match)
        output2 = os.path.join(tmpdir, "test2_exact.txt")
        run_test(
            "Exact sequence search",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -q GFTF -o {output2}",
            output2
        )
        
        # Test 3: Fuzzy sequence search
        output3 = os.path.join(tmpdir, "test3_fuzzy.txt")
        run_test(
            "Fuzzy sequence search (1 mismatch allowed)",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -q GFTX --fuzzy 1 -o {output3}",
            output3
        )
        
        # Test 4: Multiple queries
        output4 = os.path.join(tmpdir, "test4_multi.txt")
        run_test(
            "Multiple sequence queries",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -q GFT -q RAS -o {output4}",
            output4
        )
        
        # Test 5: Validation
        output5 = os.path.join(tmpdir, "test5_validate.txt")
        run_test(
            "Validation with warnings",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -s H:1-100 --validate -o {output5}",
            output5
        )
        
        # Test 6: Combining methods
        output6 = os.path.join(tmpdir, "test6_combined.txt")
        run_test(
            "Combined sequence search and manual spans",
            f"python3 generate_mutatex_position_list.py -p {test_pdb} -q RAS -s H:34-35 -o {output6}",
            output6
        )
        
        print("\n" + "="*60)
        print("Test Summary")
        print("="*60)
        print("All tests demonstrate different features of the enhanced script:")
        print("- Manual span selection (original functionality)")
        print("- Exact sequence matching")
        print("- Fuzzy sequence matching")
        print("- Multiple queries")
        print("- Validation with warnings")
        print("- Combining different selection methods")
        print("\nFor interactive mode, run:")
        print(f"python3 generate_mutatex_position_list.py -p {test_pdb} -i")

if __name__ == "__main__":
    main() 