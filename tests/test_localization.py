"""Catalog packaging and real language preferences in every embedding host."""
from pathlib import Path
import importlib.util
import re
import json
from collections import Counter
import subprocess
import unittest

from support import ROOT, addons, build

spec = importlib.util.spec_from_file_location("l10n_sync", ROOT / "scripts/l10n_sync.py")
l10n_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(l10n_sync)


class LocalizationTests(unittest.TestCase):
    def test_library_and_catalogs_load_in_every_host_and_package(self):
        folder = ROOT / "libs/HighgroundKit/locale"
        languages = [path.stem for path in folder.glob("*.lua")
                     if l10n_sync.CATALOG_NAME.fullmatch(path.stem) and path.stem != "enUS"]
        shared = {path.name for path in folder.glob("*.lua")} - {f"{code}.lua" for code in languages}
        self.assertEqual(shared, {"Library.lua", "Locales.lua", "Index.lua", "enUS.lua", "Highground.lua"})
        self.assertEqual(len(languages), 10)
        for name, addon in addons.load(include_deprecated=True).items():
            sources = build.package_sources(addon)
            for filename in shared:
                self.assertIn(f"{name}/libs/locale/{filename}", sources)
            for toc in addons.tocs(addon.path):
                entries = toc.read_text().splitlines()
                for filename in shared:
                    entry = f"libs/locale/{filename}"
                    self.assertEqual(entries.count(entry), 1)
                    self.assertLess(entries.index(entry), entries.index("libs/ui/Style.lua"))
                order = [f"libs/locale/{n}.lua" for n in ("Library", "Locales", "Index", "enUS", "Highground")]
                self.assertEqual(order, sorted(order, key=entries.index))
            # Each other language is its own load-on-demand addon, loading only its catalog.
            definitions = dict(re.findall(r'key = "(\w+)", addon = "(\w+)"', (folder / "Locales.lua").read_text()))
            self.assertEqual(sorted(definitions), sorted(languages))
            bundled = (addons.field(addon.path, "X-Bundled-Addons") or "").split()
            for code in languages:
                language = definitions[code]
                with self.subTest(host=name, language=code):
                    self.assertIn(language, bundled)
                    self.assertNotIn(f"{name}/libs/locale/{code}.lua", sources)
                    self.assertEqual(sources[f"{language}/{code}.lua"].resolve(), (folder / f"{code}.lua").resolve())
                    path = addon.path.parent / language
                    self.assertEqual(addons.field(path, "X-Highground-Locale"), code)
                    entries = [line for line in (path / f"{language}.toc").read_text().splitlines()
                               if line and not line.startswith("#")]
                    self.assertEqual(entries, [f"{code}.lua"])

    def test_generated_index_is_current(self):
        # Coverage and Locale:Variants texts of catalogs that load on demand.
        path = ROOT / "libs/HighgroundKit/locale/Index.lua"
        self.assertEqual(path.read_text(encoding="utf-8"), l10n_sync.render_index(ROOT),
                         "Index.lua is stale; run: python3 scripts/l10n_sync.py index")

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
        # One definition of preserved controls and syntax, shared with scripts/l10n_sync.py.
        controls, syntax = l10n_sync.CONTROLS, l10n_sync.SYNTAX
        for path in folder.glob("*.lua"):
            if not l10n_sync.CATALOG_NAME.fullmatch(path.stem) or path.stem == "enUS":
                continue
            translated = catalog(path)
            # English keys plus the plural forms this language adds (ruRU: few, many).
            expected = l10n_sync.expected_keys(list(english), path.stem)
            self.assertEqual(set(translated), set(expected), path.name)
            for key in expected:
                source = english[l10n_sync.source_key(english, key)]
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
                    r'''\b(?:L|Locale)\s*:\s*(?:Get|Format|Plural)\s*\(\s*(["'])([\w.]+)\1\s*[,)]''', source))
                used.update(re.findall(r'["\']([a-z][\w.]+\.[a-f0-9]{6})["\']', source))
                used.update(match.group(2) for match in re.finditer(
                    r'''\bLocalization\.Bind\s*\([^,]+,\s*(["'])([\w.]+)\1\s*[,)]''', source))
        self.assertTrue(used)
        # Locale:Plural bases name a family: <base>.one and <base>.other.
        unregistered = {k for k in used - keys if not {k + ".one", k + ".other"} <= keys}
        self.assertFalse(unregistered, f"Unregistered English keys: {unregistered}")


if __name__ == "__main__":
    unittest.main()
