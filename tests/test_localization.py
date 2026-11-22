"""Catalog packaging and real language preferences in every embedding host."""
from pathlib import Path
import re
import subprocess
import unittest

from support import ROOT, addons, build


class LocalizationTests(unittest.TestCase):
    def test_library_and_catalogs_load_in_every_host_and_package(self):
        names = {path.name for path in (ROOT / "libs/HighgroundKit/locale").glob("*.lua")}
        for name, addon in addons.load(include_deprecated=True).items():
            sources = build.package_sources(addon)
            for filename in names:
                self.assertIn(f"{name}/libs/locale/{filename}", sources)
            for toc in addons.tocs(addon.path):
                entries = toc.read_text().splitlines()
                for filename in names:
                    entry = f"libs/locale/{filename}"
                    self.assertEqual(entries.count(entry), 1)
                    self.assertLess(entries.index(entry), entries.index("libs/ui/Style.lua"))
                self.assertLess(entries.index("libs/locale/enUS.lua"), entries.index("libs/locale/frFR.lua"))

    def test_preferences_in_all_hosts_and_client_families(self):
        for name, addon in addons.load(include_deprecated=True).items():
            for client, version in (("cata", 40402), ("retail", 120100), ("retail", 16001)):
                with self.subTest(addon=name, version=version):
                    result = subprocess.run(
                        ["luajit", "../../tests/localization.lua", name, client, str(version)],
                        cwd=addon.path, text=True, capture_output=True, timeout=90,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_localized_message_references_exist_in_english(self):
        english = (ROOT / "libs/HighgroundKit/locale/enUS.lua").read_text()
        keys = set(re.findall(r'\["([\w.]+)"\]\s*=', english))
        used = set()
        for folder in (ROOT / "libs/HighgroundKit", ROOT / "addons"):
            for path in folder.rglob("*.lua"):
                if "tests" in path.parts:
                    continue
                used.update(re.findall(r'(?:L|Locale):(?:Get|Format)\("([\w.]+)"', path.read_text()))
                used.update(re.findall(r'Localization.Bind\([^,]+, "([\w.]+)"', path.read_text()))
        self.assertTrue(used)
        self.assertFalse(used - keys, f"Unregistered English keys: {used - keys}")


if __name__ == "__main__":
    unittest.main()
