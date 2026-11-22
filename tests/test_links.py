"""Markdown link checker behavior and the repository's own documentation links."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_links", ROOT / "scripts/check_links.py")
links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(links)


class LinkCheckTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="highground-links-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def problems(self):
        return links.check(self.root, ["."])

    def test_github_heading_slugs(self):
        self.assertEqual(links.slug("Estimated specs (Cata)"), "estimated-specs-cata")
        self.assertEqual(links.slug("Spell ranks (WoW Forever)"), "spell-ranks-wow-forever")
        self.assertEqual(links.slug("`/hg` → **Addons**"), "hg--addons")
        self.assertEqual(links.slug("Run [tests](x.md) & checks"), "run-tests--checks")
        self.assertEqual(links.slug("_Quick_ __calls__ and `snake_case`"), "quick-calls-and-snake_case")
        self.assertEqual(links.slug("Bounties &amp; claims"), "bounties--claims")
        self.assertEqual(links.slug("Keep snake_case words"), "keep-snake_case-words")

    def test_valid_files_directories_and_anchors(self):
        self.write("docs/guide.md", "# Guide\n\n## Set up\n\n## Set up\n\n<a id=\"custom\"></a>\n")
        self.write("src/code.lua", "return true\n")
        self.write("README.md", "\n".join([
            "[guide](docs/guide.md) [dir](src/) [code](src/code.lua#L1)",
            "[first](docs/guide.md#set-up) [second](docs/guide.md#set-up-1)",
            "[html](docs/guide.md#custom) [self](#readme) [web](https://example.com/x.md)",
            "[mail](mailto:a@example.com) ![image](src/code.lua \"title\")",
            "[ref]: docs/guide.md#guide",
            "# Readme",
        ]))
        self.assertEqual(self.problems(), [])

    def test_missing_files_and_anchors_are_reported(self):
        self.write("docs/guide.md", "# Guide\n")
        self.write("README.md", "[a](docs/missing.md)\n[b](docs/guide.md#nope)\n[c](#absent)\n")
        self.assertEqual(self.problems(), [
            "README.md:1: missing docs/missing.md",
            "README.md:2: no heading for #nope in docs/guide.md#nope",
            "README.md:3: no heading for #absent in #absent",
        ])

    def test_code_is_ignored(self):
        self.write("README.md", "`[a](missing.md)`\n\n```md\n[b](missing.md)\n```\n\n~~~\n## Not a heading\n~~~\n[c](#not-a-heading)\n")
        self.assertEqual(self.problems(), ["README.md:10: no heading for #not-a-heading in #not-a-heading"])

    def test_setext_headings_and_mixed_case_html_ids(self):
        self.write("guide.md", "Setext title\n============\n\nSecond part\n---\n\n<a id=\"MixedCase\"></a>\n")
        self.write("README.md", "[a](guide.md#setext-title) [b](guide.md#second-part) [c](guide.md#MixedCase)\n")
        self.assertEqual(self.problems(), [])

    def test_html_links_are_checked(self):
        self.write("README.md", '<a href="missing.md">a</a> <img src="logo.png" alt=""> <a href="https://example.com">b</a>\n')
        self.assertEqual(self.problems(), ["README.md:1: missing missing.md", "README.md:1: missing logo.png"])

    def test_comments_and_indented_code_are_ignored(self):
        self.write("README.md", "\n".join([
            "<!-- [a](missing.md) -->",
            "<!--",
            "[b](missing.md)",
            "-->",
            "",
            "    [c](missing.md)",
            "",
            "- List item",
            "    [d](also-missing.md)",
            "",
        ]))
        self.assertEqual(self.problems(), ["README.md:9: missing also-missing.md"])

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks unavailable")
    def test_links_through_symlinks_are_reported(self):
        self.write("source/file.lua", "return true\n")
        (self.root / "addon").mkdir()
        os.symlink("../source", self.root / "addon/libs")
        self.write("addon/README.md", "[linked](libs/file.lua) [source](../source/file.lua)\n")
        self.assertEqual(self.problems(), [
            "addon/README.md:1: libs/file.lua passes through symlink addon/libs; link its source path",
        ])

    def test_repository_documentation_links(self):
        self.assertEqual(links.check(ROOT), [])


if __name__ == "__main__":
    unittest.main()
