"""Catalog packaging and real language preferences in every embedding host."""
from pathlib import Path
import re
import json
from collections import Counter
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

    def test_full_catalog_behavior_preserves_gameplay_and_authored_data(self):
        for client, version in (("cata", 40402), ("retail", 120100), ("retail", 16001)):
            with self.subTest(version=version):
                result = subprocess.run(
                    ["luajit", "../../tests/localization_behavior.lua", client, str(version)],
                    cwd=ROOT / "addons/Highground", text=True, capture_output=True, timeout=90,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_translations_preserve_commands_and_inline_controls(self):
        def catalog(path):
            return {key: json.loads(value) for key, value in re.findall(
                r'\["([\w.]+)"\]\s*=\s*("(?:\\.|[^"\\])*")', path.read_text())}

        folder = ROOT / "libs/HighgroundKit/locale"
        english = catalog(folder / "enUS.lua")
        controls = re.compile(r"\|c[0-9a-fA-F]{8}|\|[rHhTt]|/(?:highground|hgbg|hgrep|hgb|hgn|hgm|hga|hg|reload|castsequence|run)\b|#showtooltip|#show\b", re.ASCII)
        syntax = (
            "{CMD} [board] | list | add [GOLD] NAME [; note] | submit NAME | approve NAME | reject NAME | shared | suggestions | claims | gold | remove NAME | claim NAME | share NAME | export NAME | import [CODE] | sync | test [FEATURE|stop] | guide [CHAPTER|stop] | on | off",
            "{CMD} share NAME", "{CMD} add [GOLD] NAME [; note]", "{CMD} {sub} NAME",
            "{B_CMD} shared add GOLD DURATION NAME [; note]", "500 2h target",
            "communities | manage | report [target/full name] | sync | status | on | off",
            "board | receive on/off | publish on/off | threshold GOLD | add GOLD 2h NAME | claim NAME | withdraw NAME | claims | sync",
        )
        for path in folder.glob("*.lua"):
            if path.stem in ("Library", "Locales", "Highground", "enUS"):
                continue
            translated = catalog(path)
            self.assertEqual(set(translated), set(english), path.name)
            for key, source in english.items():
                with self.subTest(locale=path.stem, key=key):
                    self.assertEqual(Counter(controls.findall(source)), Counter(controls.findall(translated[key])))
                    for literal in syntax:
                        if literal in source:
                            self.assertIn(literal, translated[key])
                    if 'NAME can be "target"' in source:
                        self.assertIn('"target"', translated[key])

    def test_localized_message_references_exist_in_english(self):
        english = (ROOT / "libs/HighgroundKit/locale/enUS.lua").read_text()
        keys = set(re.findall(r'\["([\w.]+)"\]\s*=', english))
        used = set()
        for folder in (ROOT / "libs/HighgroundKit", ROOT / "addons"):
            for path in folder.rglob("*.lua"):
                if "tests" in path.parts:
                    continue
                # Only complete literal arguments; dynamic families (such as
                # locale.name.*) have explicit behavioral coverage in Lua.
                source = path.read_text()
                used.update(match.group(2) for match in re.finditer(
                    r'''\b(?:L|Locale)\s*:\s*(?:Get|Format)\s*\(\s*(["'])([\w.]+)\1\s*[,)]''', source))
                used.update(re.findall(r'["\']([a-z][\w.]+\.[a-f0-9]{6})["\']', source))
                used.update(match.group(2) for match in re.finditer(
                    r'''\bLocalization\.Bind\s*\([^,]+,\s*(["'])([\w.]+)\1\s*[,)]''', source))
        self.assertTrue(used)
        self.assertFalse(used - keys, f"Unregistered English keys: {used - keys}")


if __name__ == "__main__":
    unittest.main()
