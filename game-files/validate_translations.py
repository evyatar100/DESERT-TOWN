"""Backward-compatible entry point. The checks live in tests/test_translations.py."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import unittest

from tests import test_translations

if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(test_translations)
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
