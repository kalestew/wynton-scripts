#!/bin/bash
# Fix numpy/pandas compatibility issue on Wynton
# Following Wynton best practices: https://wynton.ucsf.edu/hpc/howto/python.html

echo "Fixing numpy/pandas compatibility in virtual environment..."

# First, uninstall both to avoid conflicts
# Using python3 -m pip as required on Wynton
python3 -m pip uninstall -y pandas numpy

# Install compatible versions
# For pandas 1.5.3, we need numpy < 1.24
# No --user flag needed since we're in a virtual environment
python3 -m pip install numpy==1.23.5
python3 -m pip install pandas==1.5.3

# Verify installation
python3 -c "import numpy; print(f'NumPy version: {numpy.__version__}')"
python3 -c "import pandas; print(f'Pandas version: {pandas.__version__}')"

# Test that imports work correctly
echo "Testing imports..."
python3 -c "import pandas as pd; import numpy as np; print('✅ Imports successful!')"

echo "Done! Now try running rosetta_ddg_plot again." 