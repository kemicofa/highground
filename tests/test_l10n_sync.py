"""scripts/l10n_sync.py finds, inserts and checks catalog entries."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("l10n_sync", ROOT / "scripts/l10n_sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

ENGLISH = {
    "a.first": "First",
    "a.colored": "|cff00ff00Ready|r for {name}",
    "a.command": "Type /hg help",
    "a.last": 'Say "hi"\nthen leave',
}


def catalog(locale, entries):
    lines = "".join(f'  ["{key}"] = {sync.encode(value)},\n' for key, value in entries.items())
    return f'local _, ns = ...\nassert(ns.Locale:Register("{locale}", {{\n{lines}}}))\n'


class L10nSyncTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="highground-l10n-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.folder = self.root / sync.LOCALE_DIR
        self.folder.mkdir(parents=True)
        (self.folder / "enUS.lua").write_text(catalog("enUS", ENGLISH))
        (self.folder / "deDE.lua").write_text(catalog("deDE", {"a.first": "Erste", "a.old": "Alt"}))
        for name in ("Library", "Locales", "Highground"):
            (self.folder / f"{name}.lua").write_text("return {}\n")

    def run_cli(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            code = sync.main([*args])
        return code, output.getvalue()

    def entries(self, locale):
        return {key: text for key, (_, text) in sync.Catalog(self.folder / f"{locale}.lua").entries.items()}

    def apply(self, translations, *flags):
        path = self.root / "todo.json"
        path.write_text(json.dumps(translations, ensure_ascii=False))
        return self.run_cli("apply", str(self.root), str(path), *flags)

    def test_missing_reports_missing_and_stale_keys(self):
        code, output = self.run_cli("missing", str(self.root), "--json")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(output)["deDE"], {
            "missing": ["a.colored", "a.command", "a.last"], "stale": ["a.old"]})

    def test_template_lists_missing_entries_with_english(self):
        output = self.root / "todo.json"
        self.assertEqual(self.run_cli("template", str(self.root), "-o", str(output))[0], 0)
        template = json.loads(output.read_text())
        self.assertEqual(list(template), ["a.colored", "a.command", "a.last"])
        self.assertEqual(template["a.last"], {"_en": 'Say "hi"\nthen leave', "deDE": ""})

    def test_apply_inserts_in_english_order_and_round_trips_escapes(self):
        code, _ = self.apply({
            "a.last": {"_en": "ignored", "deDE": 'Sag "hallo"\ndann geh'},
            "a.colored": {"deDE": "|cff00ff00Bereit|r für {name}"},
            "a.command": {"deDE": "Gib /hg help ein"},
        }, "--prune-stale")
        self.assertEqual(code, 0)
        self.assertEqual(list(self.entries("deDE")), list(ENGLISH))
        self.assertEqual(self.entries("deDE")["a.last"], 'Sag "hallo"\ndann geh')
        text = (self.folder / "deDE.lua").read_text(encoding="utf-8")
        self.assertIn('["a.colored"] = "|cff00ff00Bereit|r für {name}",', text)
        self.assertEqual(self.run_cli("missing", str(self.root))[0], 0)

    def test_apply_refuses_changed_controls_placeholders_and_unknown_keys(self):
        before = (self.folder / "deDE.lua").read_text()
        code, output = self.apply({
            "a.colored": {"deDE": "Bereit für {player}"},
            "a.command": {"deDE": "Gib Hilfe ein"},
            "a.unknown": {"deDE": "?"},
            "a.last": {"xxXX": "?"},
        })
        self.assertEqual(code, 1)
        for reason in ("inline controls differ", "placeholders differ", "not an enUS key", "no such catalog"):
            self.assertIn(reason, output)
        self.assertEqual((self.folder / "deDE.lua").read_text(), before)

    def test_existing_entries_need_overwrite_and_dry_run_writes_nothing(self):
        before = (self.folder / "deDE.lua").read_text()
        self.apply({"a.first": {"deDE": "Erstens"}}, "--dry-run", "--overwrite")
        self.assertEqual((self.folder / "deDE.lua").read_text(), before)
        self.apply({"a.first": {"deDE": "Erstens"}})
        self.assertEqual(self.entries("deDE")["a.first"], "Erste")
        self.apply({"a.first": {"deDE": "Erstens"}}, "--overwrite")
        self.assertEqual(self.entries("deDE")["a.first"], "Erstens")

    def test_interrupted_write_leaves_the_catalog_intact(self):
        before = (self.folder / "deDE.lua").read_text()
        files = sorted(self.folder.iterdir())
        translations = self.root / "todo.json"
        translations.write_text(json.dumps({"a.command": {"deDE": "Gib /hg help ein"}}))
        write = Path.write_text

        def interrupted(path, text, *args, **kwargs):
            write(path, text[:20], *args, **kwargs)
            raise KeyboardInterrupt

        with patch.object(Path, "write_text", interrupted), self.assertRaises(KeyboardInterrupt):
            self.run_cli("apply", str(self.root), str(translations))
        self.assertEqual((self.folder / "deDE.lua").read_text(), before)
        self.assertEqual(sorted(self.folder.iterdir()), files, "no temporary file left behind")

    def test_catalog_without_a_register_line_is_a_clear_error(self):
        (self.folder / "deDE.lua").write_text("return {}\n")
        with self.assertRaisesRegex(SystemExit, r"deDE\.lua: no Register\( line to insert a\.first after"):
            self.apply({"a.first": {"deDE": "Erste"}})
        self.assertEqual((self.folder / "deDE.lua").read_text(), "return {}\n")

    def test_index_keeps_coverage_and_every_catalogs_variant_texts(self):
        feature = self.root / "addons/Example/Feature.lua"
        feature.parent.mkdir(parents=True)
        feature.write_text('local words = ns.Locale:Variants("a.first")\nlocal rows = Win.Variants(entry)\n')
        self.assertEqual(self.run_cli("index", str(self.root), "--check")[0], 1, "missing index is stale")
        self.assertEqual(self.run_cli("index", str(self.root))[0], 0)
        text = (self.folder / sync.INDEX).read_text(encoding="utf-8")
        self.assertIn("coverage = { enUS = 4, deDE = 1 },", text, "stale keys are not coverage")
        self.assertIn('["a.first"] = { "First", "Erste" },', text)
        self.assertEqual(self.run_cli("index", str(self.root), "--check")[0], 0)
        self.apply({"a.command": {"deDE": "Gib /hg help ein"}})
        self.assertIn("deDE = 2 }", (self.folder / sync.INDEX).read_text(encoding="utf-8"), "apply rewrites it")

    def test_index_needs_literal_variant_keys(self):
        feature = self.root / "libs/HighgroundKit/core/Feature.lua"
        feature.parent.mkdir(parents=True)
        feature.write_text("local words = ns.Locale:Variants(KEY)\n")
        with self.assertRaisesRegex(SystemExit, r"Feature\.lua: Locale:Variants needs a literal message key"):
            self.run_cli("index", str(self.root))

    def test_repository_catalogs_are_complete(self):
        code, output = self.run_cli("missing", str(ROOT))
        self.assertEqual(code, 0, output)


if __name__ == "__main__":
    unittest.main()
