"""
Pytest configuration — shared fixtures and sys.path setup.
"""

import sys
from pathlib import Path

# Ensure src/ is on the import path for tests
_SRC = Path(__file__).resolve().parent.parent / "src"
if str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))
