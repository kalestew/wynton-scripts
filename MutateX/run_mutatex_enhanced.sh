#!/bin/bash
# Enhanced MutateX workflow with smart position list generation
# This script demonstrates the new features of the position list generator

set -euo pipefail

# Configuration
PDB_FILE=${1:-"structure.pdb"}
OUTPUT_DIR=${2:-"mutatex_results"}
MODE=${3:-"interactive"}  # Options: interactive, sequence, manual, auto

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [PDB_FILE] [OUTPUT_DIR] [MODE]

Enhanced MutateX workflow with intelligent position selection.

Arguments:
  PDB_FILE    - Input PDB structure (default: structure.pdb)
  OUTPUT_DIR  - Output directory for results (default: mutatex_results)
  MODE        - Selection mode (default: interactive)
                Options:
                  interactive - Interactive span selection
                  sequence    - Search for sequence motifs
                  manual      - Manual span entry
                  auto        - Automatic CDR detection (for antibodies)

Examples:
  # Interactive mode
  $0 antibody.pdb results interactive

  # Search for CDR sequences
  $0 antibody.pdb results sequence

  # Manual span specification
  $0 protein.pdb results manual
EOF
    exit 1
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Validate PDB file exists
if [[ ! -f "$PDB_FILE" ]]; then
    echo "Error: PDB file '$PDB_FILE' not found!"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "=== Enhanced MutateX Workflow ==="
echo "PDB File: $PDB_FILE"
echo "Output Directory: $OUTPUT_DIR"
echo "Mode: $MODE"
echo

# Copy PDB to working directory
cp "../$PDB_FILE" ./input.pdb

# Generate position list based on mode
case "$MODE" in
    interactive)
        echo "Starting interactive position selection..."
        python3 ../generate_mutatex_position_list.py \
            -p input.pdb \
            -i \
            -o position_list.txt \
            --validate
        ;;
    
    sequence)
        echo "Searching for common antibody CDR sequences..."
        # Example: Search for common CDR motifs
        python3 ../generate_mutatex_position_list.py \
            -p input.pdb \
            -q "GFTF" --fuzzy 1 \
            -q "YYCSR" --fuzzy 1 \
            -q "RASQ" --fuzzy 1 \
            -o position_list.txt \
            --validate
        ;;
    
    manual)
        echo "Enter residue spans (e.g., H:30-37,L:50-56):"
        read -r SPANS
        python3 ../generate_mutatex_position_list.py \
            -p input.pdb \
            -s $SPANS \
            -o position_list.txt \
            --validate
        ;;
    
    auto)
        echo "Automatic CDR detection for antibody structures..."
        # First, try to find heavy chain CDRs
        echo "Searching for heavy chain CDRs..."
        python3 ../generate_mutatex_position_list.py \
            -p input.pdb \
            -q "GFTF" --fuzzy 2 \
            -o heavy_cdrs.txt
        
        # Then, try to find light chain CDRs
        echo "Searching for light chain CDRs..."
        python3 ../generate_mutatex_position_list.py \
            -p input.pdb \
            -q "RASQ" --fuzzy 2 \
            -o light_cdrs.txt
        
        # Combine results
        cat heavy_cdrs.txt light_cdrs.txt > position_list.txt
        echo "Combined CDR positions into position_list.txt"
        ;;
    
    *)
        echo "Error: Unknown mode '$MODE'"
        usage
        ;;
esac

# Check if position list was generated
if [[ ! -f position_list.txt ]] || [[ ! -s position_list.txt ]]; then
    echo "Error: No positions selected or position_list.txt is empty!"
    exit 1
fi

echo
echo "=== Position List Summary ==="
echo "Total positions: $(wc -l < position_list.txt)"
echo "First 10 positions:"
head -10 position_list.txt
echo

# Generate mutation list using mutatex
echo "=== Running MutateX ==="
if command -v mutatex &> /dev/null; then
    # Run mutatex with the generated position list
    mutatex input.pdb \
        --positions position_list.txt \
        --output-prefix mutatex \
        --mode saturation
    
    echo "MutateX completed successfully!"
    echo "Results saved in: $OUTPUT_DIR"
else
    echo "Warning: mutatex command not found!"
    echo "Please install mutatex or adjust the command for your system"
    echo
    echo "Example mutatex command that would be run:"
    echo "mutatex input.pdb --positions position_list.txt --output-prefix mutatex --mode saturation"
fi

# Generate summary report
echo
echo "=== Generating Summary Report ==="
cat > summary_report.txt << EOF
MutateX Enhanced Workflow Summary
================================
Date: $(date)
PDB File: $PDB_FILE
Mode: $MODE

Position List Statistics:
- Total positions: $(wc -l < position_list.txt)
- Chains included: $(cut -c2 position_list.txt | sort -u | tr '\n' ' ')

Selected Positions:
$(cat position_list.txt)

EOF

echo "Summary report saved to: summary_report.txt"
echo
echo "=== Workflow Complete ===" 