#!/usr/bin/env python3
"""Check versions of all relevant packages"""

import sys

packages = ['pandas', 'numpy', 'matplotlib', 'seaborn']

for pkg in packages:
    try:
        module = __import__(pkg)
        version = getattr(module, '__version__', 'unknown')
        print(f"{pkg}: {version}")
    except ImportError:
        print(f"{pkg}: NOT INSTALLED")

print(f"\nPython version: {sys.version}") 