"""Install complete release packages without relying on another public addon."""
import itertools
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import zipfile

from support import ROOT, TempTestCase, addons, build


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


class PackagedRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='highground-installation-')
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        cls.manifest = addons.load()
        cls.folders = {}
        cls.combined = cls.root / 'combined'
        for name, addon in cls.manifest.items():
            _, archive = build.build(addon, cls.root / 'dist' / name)
            isolated = cls.root / name
            with zipfile.ZipFile(archive) as package:
                package.extractall(isolated)
                package.extractall(cls.combined)
                cls.folders[name] = sorted({path.split('/')[0] for path in package.namelist()})
            (isolated / '__empty.toc').touch()
        (cls.combined / '__empty.toc').touch()

    def run_install(self, root, client, folders, reverse=False, disabled=False):
        result = subprocess.run(
            ['luajit', str(ROOT / 'tests/installation_scenarios.lua'), str(root), str(client),
             'disabled' if disabled else 'reverse' if reverse else 'forward', *folders],
            cwd=root, text=True, capture_output=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_each_zip_runs_without_the_repository_or_other_downloads(self):
        for name in self.manifest:
            for client in (120100, 16001, 40402):
                with self.subTest(addon=name, client=client):
                    self.run_install(self.root / name, client, self.folders[name])
        for client in (11508, 20505):
            with self.subTest(addon='HighgroundMacros', client=client):
                self.run_install(self.root / 'HighgroundMacros', client, self.folders['HighgroundMacros'])

    def test_all_standalone_combinations_and_load_order_directions(self):
        names = sorted(set(self.manifest) - {'Highground'})
        groups = [group for size in range(2, len(names) + 1) for group in itertools.combinations(names, size)]
        groups += [('Highground', name) for name in names] + [tuple(self.manifest)]
        for group in groups:
            folders = sorted({folder for name in group for folder in self.folders[name]})
            for client, reverse in itertools.product((120100, 16001, 40402), (False, True)):
                with self.subTest(addons=group, client=client, reverse=reverse):
                    self.run_install(self.combined, client, folders, reverse)

    def test_shared_data_survives_switching_hosts_and_newer_schemas(self):
        folders = sorted({folder for group in self.folders.values() for folder in group})
        for client in (120100, 16001, 40402):
            with self.subTest(client=client):
                result = subprocess.run(
                    ['luajit', str(ROOT / 'tests/installation_data.lua'), str(self.combined), str(client), *folders],
                    cwd=self.combined, text=True, capture_output=True, timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_installed_but_disabled_optional_hosts_leave_standalones_active(self):
        folders = sorted({folder for group in self.folders.values() for folder in group})
        for client in (120100, 16001, 40402):
            with self.subTest(client=client):
                self.run_install(self.combined, client, folders, disabled=True)


if __name__ == '__main__':
    unittest.main()
