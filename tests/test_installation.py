"""Install complete release packages without relying on another public addon."""
import re
import unittest

from support import TempTestCase, addons, build


class InstallationTests(TempTestCase):
    def test_every_required_dependency_is_in_the_same_download(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                folders = {path.split('/')[0] for path in sources}
                for relative, path in sources.items():
                    if not relative.endswith('.toc'):
                        continue
                    for value in addons.toc_field(path, 'Dependencies'):
                        for dependency in re.split(r'[,\s]+', value):
                            self.assertIn(dependency, folders, relative)
                if name != 'Highground':
                    self.assertEqual(folders & self.manifest.keys(), {name})

    def test_combined_downloads_have_identical_overlaps_and_unique_saved_owners(self):
        installed = {}
        owners = {}
        for addon in self.manifest.values():
            for relative, source in build.package_sources(addon).items():
                data = source.read_bytes()
                if relative in installed:
                    self.assertEqual(installed[relative], data, relative)
                installed[relative] = data
                if not relative.endswith('.toc'):
                    continue
                folder = relative.split('/')[0]
                for field in ('SavedVariables', 'SavedVariablesPerCharacter'):
                    for value in addons.toc_field(source, field):
                        for variable in re.split(r'[,\s]+', value):
                            self.assertEqual(owners.setdefault(variable, folder), folder, variable)
        self.assertEqual(owners['HighgroundBountyNetworkDB'], 'HighgroundBountyData')
        self.assertEqual(owners['HighgroundReputationNetworkDB'], 'HighgroundReputationData')


if __name__ == '__main__':
    unittest.main()
