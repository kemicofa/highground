"""Runtime textures stay at their budgeted sizes and formats (tools/export_textures.py)."""
import importlib.util
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_textures", ROOT / "tools/export_textures.py")
textures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(textures)


def power_of_two(value):
    return value > 0 and value & (value - 1) == 0


class TextureTests(unittest.TestCase):
    def test_every_runtime_texture_has_a_budget(self):
        listed = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-s", "--", "addons", "libs"], text=True)
        runtime = {line.split("\t", 1)[1] for line in listed.splitlines()
                   if not line.startswith("120000") and line.lower().endswith((".tga", ".blp", ".png", ".jpg"))}
        self.assertEqual(runtime, set(textures.TEXTURES) | set(textures.GENERATED),
                         "List new game textures in tools/export_textures.py")

    def test_textures_match_their_budget(self):
        self.assertEqual(textures.problems(), [])
        for path in [*textures.TEXTURES, *textures.GENERATED]:
            _, width, height, _, _ = textures.header(ROOT / path)
            with self.subTest(path=path):
                self.assertTrue(power_of_two(width) and power_of_two(height), "WoW needs power-of-two textures")

    def test_sources_exist_and_cover_twice_the_default_draw_size(self):
        for path, (source, size, draw) in textures.TEXTURES.items():
            with self.subTest(path=path):
                self.assertTrue((ROOT / source).is_file(), source)
                self.assertGreaterEqual(size, 2 * int(draw.split()[0].rstrip(',')))
        for path, (generator, _, _) in textures.GENERATED.items():
            self.assertTrue((ROOT / generator).is_file(), generator)

    def test_export_reproduces_a_committed_texture(self):
        # Requires ImageMagick; the exporter must not change unchanged art.
        if subprocess.run(["sh", "-c", "command -v magick"], capture_output=True).returncode:
            self.skipTest("ImageMagick unavailable")
        destination = "addons/Highground/assets/sniper/SniperReticle.tga"
        original = (ROOT / destination).read_bytes()
        try:
            textures.export(destination)
            self.assertEqual((ROOT / destination).read_bytes(), original)
        finally:
            (ROOT / destination).write_bytes(original)


if __name__ == "__main__":
    unittest.main()
