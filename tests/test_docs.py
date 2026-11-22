"""Documentation stays in step with the code it indexes."""
import importlib.util
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
HIGHGROUND = ROOT / "addons/Highground"
spec = importlib.util.spec_from_file_location("lint", ROOT / "tools/lint/lint.py")
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


def linked(index: Path) -> set[Path]:
    text = index.read_text(encoding="utf-8")
    return {(index.parent / target.split("#")[0]).resolve()
            for target in re.findall(r"\]\(([^)#\s]+\.md)(?:#[^)]*)?\)", text)}


class DocsTests(unittest.TestCase):
    def test_simulation_groups_are_documented(self):
        runner = (HIGHGROUND / "tests/simulation_test.lua").read_text(encoding="utf-8")
        groups = re.findall(r'"([a-z]+)"', re.search(r"local groups = \{(.*?)\}", runner, re.S).group(1))
        documented = re.findall(r"^\| `([a-z]+)` \|", (HIGHGROUND / "docs/simulations.md").read_text(encoding="utf-8"), re.M)
        self.assertEqual(sorted(set(groups)), sorted(documented),
                         "Update the group table in addons/Highground/docs/simulations.md")

    def test_every_guide_is_indexed(self):
        # Changelog archives are linked from the changelog itself.
        indexed = linked(ROOT / "docs/README.md") | linked(HIGHGROUND / "docs/README.md") | linked(HIGHGROUND / "CHANGELOG.md")
        guides = [*ROOT.joinpath("docs").glob("*.md"), *HIGHGROUND.joinpath("docs").glob("*.md")]
        missing = sorted(path.relative_to(ROOT).as_posix() for path in guides
                         if path.name != "README.md" and path.resolve() not in indexed)
        self.assertEqual(missing, [], "Link new guides from docs/README.md or addons/Highground/docs/README.md")

    def test_addon_markdown_fits_the_line_limit(self):
        # Addon validators apply the same limit; documentation-only PRs skip them in CI.
        names = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z", "--", "addons/*.md"])
        long = [name for name in names.decode().split("\0") if name and (ROOT / name).is_file()
                and len((ROOT / name).read_text(encoding="utf-8").splitlines()) > lint.MAX_LINES]
        self.assertEqual(long, [], f"Split or shorten files over {lint.MAX_LINES} lines")


if __name__ == "__main__":
    unittest.main()
