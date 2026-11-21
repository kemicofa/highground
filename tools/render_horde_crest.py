"""Retexture the existing Highground Blender rig and render its Horde variant.

blender -b /path/to/Highground_Coin.blend --python tools/render_horde_crest.py
Add -- --preview to render only front, edge and reverse inspection frames.
The source scene is never saved over. Requires the Horde artwork in the repo.
"""

from pathlib import Path
import sys

import bpy


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets/stream-banner/horde/source"
ARTWORK = DESTINATION / "Highground-Horde-Artwork.png"
OUTPUT = DESTINATION / "Highground-Horde-Coin.blend"
scene = bpy.context.scene

if not ARTWORK.is_file():
    raise FileNotFoundError(f"Generate the Horde crest texture first: {ARTWORK}")
if "HIGHGROUND | vertical Y-axis spin" not in bpy.data.objects:
    raise RuntimeError("Open the original Highground_Coin.blend rig first")

texture = bpy.data.images.load(str(ARTWORK), check_existing=True)
texture.name = "Highground | Horde crimson artwork (packed)"
texture.pack()
material = bpy.data.materials["Full-color enamel and raised gold artwork"]
texture_nodes = [node for node in material.node_tree.nodes if node.type == "TEX_IMAGE"]
if len(texture_nodes) != 1:
    raise RuntimeError("Expected one artwork texture on the enamel material")
texture_nodes[0].image = texture

enamel = bpy.data.materials.get("Deep blue enamel | edge inlay")
if enamel is not None:
    enamel.name = "Deep crimson enamel | edge inlay"
    enamel.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        .055, .0035, .005, 1
    )

# Keep the gold studio lighting; replace the cool Alliance rim and environment.
for light in bpy.data.lights:
    if "cool strip" in light.name:
        light.color = (1, .54, .43)
        light.name = "Rim | warm Horde reflection"
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (
    .48, .30, .25, 1
)

# Author credit is stationary, editable banner copy instead of tiny 3D text.
for obj in bpy.data.objects:
    if obj.name.startswith("Credit |"):
        obj.hide_render = True

prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type == "OPTIX"
    gpu = any(device.use for device in prefs.devices)
except (TypeError, RuntimeError):
    gpu = False
scene.cycles.device = "GPU" if gpu else "CPU"
scene.cycles.denoiser = "OPTIX" if gpu else "OPENIMAGEDENOISE"
scene.cycles.samples = 40
scene.render.resolution_x = 960
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.fps = 25
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.frame_start = 1
scene.frame_end = 150
scene["variant"] = "Horde: crimson artwork, Horde insignia, red enamel, warm rim"
scene["source_artwork"] = ARTWORK.name
scene["credit_behavior"] = "Credit is included in the Twitch banner layout"
scene.frame_set(1)
scene.render.filepath = "//renders/crest_"
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT), compress=True)

if "--preview" in sys.argv:
    for frame in [1, 55, 76]:
        scene.frame_set(frame)
        scene.render.filepath = str(DESTINATION.parent / "previews" / f"crest_{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
else:
    (DESTINATION / "renders").mkdir(exist_ok=True)
    scene.render.filepath = str(DESTINATION / "renders" / "crest_")
    bpy.ops.render.render(animation=True)
