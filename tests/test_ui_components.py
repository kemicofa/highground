"""Shared controls are usable through every shipped addon's manifests."""
import subprocess
import unittest

from support import addons


class UIComponentTests(unittest.TestCase):
    def test_components_across_addons_and_clients(self):
        for name, addon in addons.load().items():
            for client, build in (("cata", 40402), ("retail", 120100), ("retail", 16001)):
                with self.subTest(addon=name, client=client, build=build):
                    result = subprocess.run(
                        ["luajit", "../../tests/ui_components.lua", name, client, str(build)],
                        cwd=addon.path, text=True, capture_output=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
