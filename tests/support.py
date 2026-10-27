"""Shared setup for the repository tests: the scripts/ modules and temporary copies.

The scripts import each other as plain modules (python3 scripts/build.py puts
scripts/ on the path); this puts scripts/ on the path for the tests too.
"""
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import addons  # noqa: E402
import build  # noqa: E402
import curseforge  # noqa: E402
import publish  # noqa: E402
import release_check  # noqa: E402

__all__ = ["ROOT", "addons", "build", "curseforge", "publish", "release_check", "TempTestCase"]

COMMIT = "a" * 40  # a full commit SHA for publish tests


class TempTestCase(unittest.TestCase):
    """A test with a temporary folder (self.temp) and an output folder (self.output)."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.temp = Path(temp.name)
        self.output = self.temp / "dist"
        self.manifest = addons.load()

    def copy_addons(self):
        """Editable copies of addons/ and .pkgmeta (links kept, tests left out); returns the manifest."""
        root = self.temp / "source"
        shutil.copytree(ROOT / "addons", root / "addons", symlinks=True,
                        ignore=shutil.ignore_patterns("tests", "__pycache__"))
        shutil.copy(ROOT / ".pkgmeta", root / ".pkgmeta")
        return addons.load(root)
