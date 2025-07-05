#!/usr/bin/env python3
"""
Script to generate all plot types from ddg_mutations_aggregate.csv file
using rosetta_ddg_plot command with appropriate configuration files.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description='Generate all DDG plot types from aggregate CSV file')
    parser.add_argument('-i', '--input', 
                        default='ddg_mutations_aggregate.csv',
                        help='Input CSV file (default: ddg_mutations_aggregate.csv)')
    parser.add_argument('-o', '--output-dir',
                        default='plots',
                        help='Output directory for plots (default: plots)')
    parser.add_argument('--config-base-path',
                        default='/wynton/home/craik/kjander/ddg/RosettaDDGPrediction/RosettaDDGPrediction',
                        help='Base path for configuration files')
    parser.add_argument('--structures-file',
                        default='ddg_mutations_structures.csv',
                        help='Structures CSV file for dg_swarmplot (default: ddg_mutations_structures.csv)')
    
    args = parser.parse_args()
    
    # Check if input file exists
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found!")
        sys.exit(1)
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    print(f"Created output directory: {output_dir}")
    
    # Configuration paths
    config_plot_dir = f"{args.config_base_path}/config_plot"
    config_aggregate_file = f"{args.config_base_path}/config_aggregate/aggregate.yaml"
    
    # Plot types and their corresponding files
    plot_types = [
        {
            'name': 'total_heatmap',
            'config': f"{config_plot_dir}/total_heatmap.yaml",
            'output': output_dir / 'total_heatmap.png',
            'input_file': args.input,
            'description': 'One-row heatmap of all mutations'
        },
        {
            'name': 'total_heatmap_saturation',
            'config': f"{config_plot_dir}/total_heatmap_saturation.yaml",
            'output': output_dir / 'total_heatmap_saturation.png',
            'input_file': args.input,
            'description': '2D heatmap showing positions vs residue types'
        },
        {
            'name': 'contributions_barplot',
            'config': f"{config_plot_dir}/contributions_barplot.yaml",
            'output': output_dir / 'contributions_barplot.png',
            'input_file': args.input,
            'description': 'Stacked bar plot of energy contributions'
        },
        {
            'name': 'dg_swarmplot',
            'config': f"{config_plot_dir}/dg_swarmplot.yaml",
            'output': output_dir / 'dg_swarmplot.png',
            'input_file': args.structures_file,
            'description': 'Swarmplot of ΔG scores for each structure'
        }
    ]
    
    # Generate each plot type
    for plot in plot_types:
        print(f"\nGenerating {plot['name']}...")
        print(f"Description: {plot['description']}")
        
        # Check if input file exists for this plot type
        if not os.path.exists(plot['input_file']):
            print(f"Warning: Input file '{plot['input_file']}' not found for {plot['name']}. Skipping...")
            continue
        
        # Construct rosetta_ddg_plot command
        cmd = [
            'rosetta_ddg_plot',
            '-i', plot['input_file'],
            '-o', str(plot['output']),
            '-ca', config_aggregate_file,
            '-cp', plot['config']
        ]
        
        try:
            print(f"Running command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            print(f"✓ Successfully generated {plot['output']}")
            if result.stdout:
                print(f"Output: {result.stdout}")
        except subprocess.CalledProcessError as e:
            print(f"✗ Error generating {plot['name']}: {e}")
            if e.stdout:
                print(f"Stdout: {e.stdout}")
            if e.stderr:
                print(f"Stderr: {e.stderr}")
        except FileNotFoundError:
            print(f"✗ Error: rosetta_ddg_plot command not found. Make sure it's in your PATH.")
            print("You may need to source the appropriate environment (e.g., source /programs/sbgrid.shrc)")
            sys.exit(1)
    
    print(f"\nPlot generation complete! Check the '{args.output_dir}' directory for results.")

if __name__ == "__main__":
    main() 