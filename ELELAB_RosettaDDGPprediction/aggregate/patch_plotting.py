#!/usr/bin/env python3
"""
Patched version of rosetta_ddg_plot for saturation heatmaps with many positions.
This fixes the tick/label mismatch error and supports custom figure sizes.
"""

import sys
import os
import matplotlib.pyplot as plt

# Import the original module
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from RosettaDDGPrediction import plotting
from RosettaDDGPrediction import rosetta_ddg_plot

# Save original functions
_original_set_axis = plotting.set_axis
_original_plot_total_heatmap = plotting.plot_total_heatmap

def patched_set_axis(ax, axis, config, ticks=None, ticklabels=None):
    """Patched version that ensures tick count matches label count"""
    
    # If we have ticklabels but no ticks, create appropriate ticks
    if ticklabels is not None and ticks is None:
        if axis == "x":
            # Create ticks for each label position
            ticks = list(range(len(ticklabels)))
        elif axis == "y" and ticklabels:  # Only if we have labels
            # Create ticks for each label position
            ticks = list(range(len(ticklabels)))
    
    # Call original function with fixed ticks
    return _original_set_axis(ax, axis, config, ticks, ticklabels)

def patched_plot_total_heatmap(df, config, out_file, out_config, saturation=False, saturation_on=None):
    """Patched version that provides explicit tick positions for saturation heatmaps"""
    
    # Check if figsize is specified in output config
    if 'figsize' in out_config:
        figsize = out_config.pop('figsize')
        # Set figure size before plotting
        plt.figure(figsize=figsize)
    
    # Temporarily replace set_axis with patched version
    plotting.set_axis = patched_set_axis
    
    try:
        # Call original function
        result = _original_plot_total_heatmap(df, config, out_file, out_config, saturation, saturation_on)
    finally:
        # Restore original function
        plotting.set_axis = _original_set_axis
    
    return result

# Apply patches
plotting.set_axis = patched_set_axis
plotting.plot_total_heatmap = patched_plot_total_heatmap

# Run the main program
if __name__ == "__main__":
    rosetta_ddg_plot.main() 