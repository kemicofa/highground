"""Release batch selection and the outputs that gate all publishing jobs."""
import json
import unittest
from unittest.mock import patch

from support import TempTestCase, release_check
import release_plan


class ReleasePlanTests(TempTestCase):
    def verdicts(self, statuses):
        return patch.object(release_check, "check", side_effect=lambda name, found:
                            release_check.Verdict(statuses.get(name, release_check.PUBLISHED), name))

    def announcement(self, *names):
        return {"releases": {name: self.manifest[name].version for name in names}}

    def test_completed_release_has_no_publishers_but_keeps_announcement_retry_possible(self):
        with self.verdicts({}):
            matrix = release_plan.plan(self.manifest, self.announcement("Highground"))
        self.assertEqual(matrix, {"include": []})

    def test_only_unpublished_addons_use_their_exact_tested_artifact(self):
        # An unfinished external upload is also PUBLISH, even if GitHub already
        # has that version. It must keep a publisher so the upload can retry.
        names = ("Highground", "HighgroundMacros")
        with self.verdicts(dict.fromkeys(names, release_check.PUBLISH)):
            matrix = release_plan.plan(self.manifest, self.announcement(*names))
        self.assertEqual(matrix, {"include": [
            {"addon": name, "artifact": f"{name}-{self.manifest[name].version}"} for name in names
        ]})

    def test_unready_shared_dependency_blocks_the_entire_batch(self):
        statuses = {"Highground": release_check.PUBLISH, "HighgroundMacros": release_check.WAITING}
        with self.verdicts(statuses), self.assertRaisesRegex(ValueError, "HighgroundMacros"):
            release_plan.plan(self.manifest, self.announcement("Highground"))

    def test_missing_or_wrong_announcement_version_blocks_publication(self):
        for releases in ({}, {"Highground": "0.0.1"}):
            with self.subTest(releases=releases), self.verdicts({"Highground": release_check.PUBLISH}), \
                    self.assertRaisesRegex(ValueError, "discord-release.json before publishing"):
                release_plan.plan(self.manifest, {"releases": releases})

    def run_cli(self, statuses, announcement, output):
        with self.verdicts(statuses), \
                patch.object(release_plan.discord_release, "load_plan", return_value=announcement), \
                patch("sys.argv", ["release_plan.py", "--github-output", str(output)]):
            release_plan.main()

    def test_cli_emits_a_skippable_empty_matrix_or_a_valid_publisher_matrix(self):
        for pending in (False, True):
            with self.subTest(pending=pending):
                output = self.temp / f"outputs-{pending}"
                self.run_cli({"Highground": release_check.PUBLISH} if pending else {},
                             self.announcement("Highground"), output)
                values = dict(line.split("=", 1) for line in output.read_text().splitlines())
                self.assertEqual(values["publish"], str(pending).lower())
                self.assertEqual(json.loads(values["matrix"])["include"], [
                    {"addon": "Highground", "artifact": self.manifest["Highground"].artifact()}
                ] if pending else [])

    def test_failed_plan_never_emits_publish_outputs(self):
        output = self.temp / "outputs"
        with self.assertRaises(ValueError):
            self.run_cli({"Highground": release_check.PUBLISH}, self.announcement(), output)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
