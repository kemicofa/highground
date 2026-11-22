"""Keep unused media out of builds and out of the CurseForge API request."""
import hashlib
import warnings
import zipfile
from unittest.mock import patch

from support import COMMIT, TempTestCase, addons, build, curseforge, publish


class AssetUsageTests(TempTestCase):
    def setUp(self):
        super().setUp()
        self.copies = self.copy_addons()
        self.addon = self.copies['HighgroundMacros']

    def include(self, addon, filename):
        for toc in addons.tocs(addon.path):
            toc.write_text(toc.read_text().replace('## X-Package-Files:', '## X-Package-Files: ' + filename))

    def test_wildcards_cannot_pick_up_unused_media(self):
        media = self.addon.path / 'libs/media/StreamBanner.tga'
        media.write_bytes(b'promotional texture')
        with self.assertRaisesRegex(ValueError, 'unapproved package asset.*StreamBanner'):
            build.build(self.addon, self.output)
        self.assertFalse(self.output.exists())

    def test_explicit_manifest_entry_cannot_approve_promotional_exports(self):
        root = self.addon.path.parent.parent
        banners = root / 'assets/stream-banner'
        banners.mkdir(parents=True)
        (banners / 'banner.webm').write_bytes(b'promotional video')
        (self.addon.path / 'promotion').symlink_to(banners, target_is_directory=True)
        self.include(self.addon, 'promotion/banner.webm')
        with self.assertRaisesRegex(ValueError, 'unapproved package asset.*banner.webm'):
            build.build(self.addon, self.output)

    def test_asset_used_only_by_another_addon_is_rejected(self):
        (self.addon.path / 'logos').symlink_to(self.copies['Highground'].path / 'assets/logos',
                                              target_is_directory=True)
        self.include(self.addon, 'logos/Highground.tga')
        with self.assertRaisesRegex(ValueError, 'unused package asset.*reader is not loaded'):
            build.build(self.addon, self.output)

    def test_commented_out_uses_do_not_approve_an_obsolete_asset(self):
        path = self.addon.path / 'libs/ui/Style.lua'
        original = path.read_text()
        use = 'Core.PROGRESS_CIRCLE = MEDIA .. "ProgressCircle.tga"'
        self.assertIn(use, original)
        for comment in ('', '-- ' + use, '--[=[\n' + use + '\n]=]'):
            with self.subTest(comment=comment):
                path.write_text(original.replace(use, comment))
                with self.assertRaisesRegex(ValueError, 'unused package asset.*no runtime reference'):
                    build.build(self.addon, self.output)

    def test_unused_code_in_package_extras_cannot_serve_as_a_reader(self):
        for toc in addons.tocs(self.addon.path):
            toc.write_text(toc.read_text().replace('\nlibs/ui/Style.lua\n', '\n'))
        self.include(self.addon, 'libs/ui/Style.lua')
        with self.assertRaisesRegex(ValueError, 'unapproved package asset|reader is not loaded'):
            build.build(self.addon, self.output)

    def test_guide_label_does_not_keep_an_unused_logo_approved(self):
        addon = self.copies['Highground']
        path = addon.path / 'hub/TourSteps.lua'
        text = path.read_text().replace('logo = "Highground",', '')
        self.assertIn('label = "Highground"', text)
        path.write_text(text)
        with self.assertRaisesRegex(ValueError, 'unused package asset.*Highground.tga'):
            build.build(addon, self.output)

    def test_bundled_data_addons_cannot_smuggle_extra_assets(self):
        addon = self.copies['Highground']
        data = addon.path.parent / 'HighgroundBountyData'
        (data / 'poster.tga').write_bytes(b'promotional texture')
        self.include(addons.Addon(data.name, data), 'poster.tga')
        with self.assertRaisesRegex(ValueError, 'HighgroundBountyData: unapproved package asset'):
            build.build(addon, self.output)

    def test_poster_media_and_license_ship_only_with_bounty_consumers(self):
        consumers = {'Highground', 'HighgroundBounties', 'HighgroundNearby'}
        expected = {'WantedDisplay.ttf', 'WantedName.ttf', 'WantedCaption.ttf',
                    'WantedPaper.tga', 'WantedScroll.tga', 'OFL-wanted.txt'}
        for name, addon in self.copies.items():
            with self.subTest(addon=name):
                media = {p.name for p in build.package_files(addon)
                         if p.as_posix().startswith('libs/bounty/media/')}
                self.assertEqual(media, expected if name in consumers else set())


class UploadBoundaryTests(TempTestCase):
    def setUp(self):
        super().setUp()
        self.addon = self.manifest['HighgroundMacros']
        _, self.archive = build.build(self.addon, self.output)

    def upload(self, archive=None, project=None):
        return curseforge.upload(project or self.addon.project, 'test-token', archive or self.archive,
                                 'Release notes', 'Highground Macros', [1])

    def checksum(self):
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.output / 'SHA256SUMS').write_text(f'{digest}  {self.archive.name}\n')

    def test_valid_addon_upload_ignores_sibling_release_assets(self):
        (self.output / 'stream-banner.webm').write_bytes(b'PROMOTIONAL_FILE_DO_NOT_UPLOAD')
        with patch.object(curseforge, 'request', return_value={'id': 123}) as request:
            self.assertEqual(self.upload(), 123)
        request.assert_called_once()
        method, path, token, body, headers = request.call_args.args
        self.assertEqual((method, path, token), ('POST', f'/api/projects/{self.addon.project}/upload-file', 'test-token'))
        self.assertTrue(headers['Content-Type'].startswith('multipart/form-data;'))
        self.assertIn(self.archive.name.encode(), body)
        self.assertNotIn(b'PROMOTIONAL_FILE_DO_NOT_UPLOAD', body)

    def test_banner_archive_cannot_be_uploaded_directly(self):
        banner = self.output / 'Highground-Twitch-Banner-Pack.zip'
        with zipfile.ZipFile(banner, 'w') as package:
            package.writestr('banner.webm', b'video')
        with patch.object(curseforge, 'request') as request, \
                self.assertRaisesRegex(ValueError, 'Expected addon archive'):
            self.upload(banner)
        request.assert_not_called()

    def test_renamed_banner_archive_cannot_impersonate_an_addon(self):
        with zipfile.ZipFile(self.archive, 'w') as package:
            package.writestr('banner.webm', b'video')
        with patch.object(curseforge, 'request') as request, \
                self.assertRaisesRegex(ValueError, 'unexpected, duplicate or missing'):
            self.upload()
        request.assert_not_called()

    def test_extra_asset_with_recomputed_checksum_cannot_reach_any_publisher(self):
        with zipfile.ZipFile(self.archive, 'a') as package:
            package.writestr('HighgroundMacros/libs/media/StreamBanner.tga', b'promotional texture')
        self.checksum()
        with patch.object(publish, 'lookup') as lookup, patch.object(curseforge, 'request') as request, \
                self.assertRaisesRegex(ValueError, 'unexpected, duplicate or missing'):
            publish.publish(self.addon, 'owner/repo', COMMIT, self.output, 'test-token')
        lookup.assert_not_called()
        request.assert_not_called()

    def test_direct_api_upload_rejects_a_hidden_extra_asset(self):
        with zipfile.ZipFile(self.archive, 'a') as package:
            package.writestr('HighgroundMacros/libs/media/StreamBanner.tga', b'promotional texture')
        with patch.object(curseforge, 'request') as request, \
                self.assertRaisesRegex(ValueError, 'unexpected, duplicate or missing'):
            self.upload()
        request.assert_not_called()

    def test_duplicate_member_cannot_override_a_runtime_asset(self):
        name = 'HighgroundMacros/libs/media/HighgroundIcon.tga'
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(self.archive, 'a') as package:
                package.writestr(name, b'promotional texture')
        with patch.object(curseforge, 'request') as request, self.assertRaisesRegex(ValueError, 'duplicate'):
            self.upload()
        request.assert_not_called()

    def test_replaced_runtime_asset_must_match_the_tested_source(self):
        with zipfile.ZipFile(self.archive) as package:
            entries = [(entry, package.read(entry)) for entry in package.infolist()]
        with zipfile.ZipFile(self.archive, 'w') as package:
            for entry, data in entries:
                if entry.filename.endswith('/HighgroundIcon.tga'):
                    data = bytes([data[0] ^ 1]) + data[1:]
                package.writestr(entry, data)
        self.checksum()
        with patch.object(curseforge, 'request') as request, \
                self.assertRaisesRegex(ValueError, 'does not match its source'):
            self.upload()
        request.assert_not_called()

    def test_unknown_or_wrong_project_cannot_receive_the_archive(self):
        for project, error in [('unknown', 'known addon project'),
                               (self.manifest['HighgroundBounties'].project, 'Expected addon archive')]:
            with self.subTest(project=project), patch.object(curseforge, 'request') as request, \
                    self.assertRaisesRegex(ValueError, error):
                self.upload(project=project)
            request.assert_not_called()

    def test_every_current_package_passes_complete_archive_validation(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                _, archive = build.build(addon, self.output / name)
                build.validate_archive(addon, archive)
