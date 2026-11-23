"""Shared controls are usable through every shipped addon's manifests."""
import subprocess
import unittest
from pathlib import Path
import runpy

from support import addons, build


class UIComponentTests(unittest.TestCase):
    def test_progress_circle_is_reproducible_and_packaged(self):
        root = Path(__file__).resolve().parents[1]
        generate = runpy.run_path(str(root / "tools/progress_circle.py"))["build"]
        data = generate()
        self.assertEqual((root / "libs/HighgroundKit/media/ProgressCircle.tga").read_bytes(), data)
        for name, addon in addons.load(include_deprecated=True).items():
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                self.assertEqual(sources[f"{name}/libs/media/ProgressCircle.tga"].read_bytes(), data)

    def test_map_ring_is_reproducible_and_packaged(self):
        root = Path(__file__).resolve().parents[1]
        data = runpy.run_path(str(root / "tools/map_ring.py"))["build"]()
        self.assertEqual((root / "libs/HighgroundKit/media/MapRing.tga").read_bytes(), data)
        for name, addon in addons.load(include_deprecated=True).items():
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                self.assertEqual(sources[f"{name}/libs/media/MapRing.tga"].read_bytes(), data)

    def test_shared_corner_art_is_reproducible_and_packaged(self):
        root = Path(__file__).resolve().parents[1]
        generate = runpy.run_path(str(root / "tools/control_corners.py"))["build"]
        relative = "libs/media/ControlCorners.tga"
        data = generate()
        self.assertEqual((root / "libs/HighgroundKit/media/ControlCorners.tga").read_bytes(), data)
        for name, addon in addons.load(include_deprecated=True).items():
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                self.assertEqual(sources[f"{name}/{relative}"].read_bytes(), data)

    def test_components_across_addons_and_clients(self):
        for name, addon in addons.load(include_deprecated=True).items():
            for client, build in (("cata", 40402), ("retail", 120100), ("retail", 16001)):
                with self.subTest(addon=name, client=client, build=build):
                    result = subprocess.run(
                        ["luajit", "../../tests/ui_components.lua", name, client, str(build)],
                        cwd=addon.path, text=True, capture_output=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
