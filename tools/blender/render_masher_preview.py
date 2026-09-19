import bpy
import os
from mathutils import Vector


PROJECT_ROOT = "/Users/nanzhe/Desktop/rolypoly"
SOURCE_PATH = os.path.join(PROJECT_ROOT, "assets", "models", "source", "Masher.blend")
RENDER_PATH = os.path.join(PROJECT_ROOT, "renders", "masher_preview.png")

# Keep only the Masher and the existing studio preview setup.
funnel_collection = bpy.data.collections.get("Funnel")
if funnel_collection:
    for obj in list(funnel_collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(funnel_collection)

masher_root = bpy.data.objects.get("Masher_Root")
if masher_root:
    masher_root.location = (0.0, 0.0, 0.0)

floor = bpy.data.objects.get("Preview_Floor")
if floor:
    floor.location = (0.0, 0.0, -0.16)
    floor.dimensions = (7.0, 7.0, 0.24)

camera = bpy.data.objects.get("Preview_Camera")
if camera:
    camera.location = (5.6, -7.6, 4.7)
    target = Vector((0.0, 0.0, 1.55))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 62
    bpy.context.scene.camera = camera

scene = bpy.context.scene
scene.render.resolution_x = 1000
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = RENDER_PATH

bpy.ops.wm.save_as_mainfile(filepath=SOURCE_PATH)
bpy.ops.render.render(write_still=True)
print(f"Saved {SOURCE_PATH} and {RENDER_PATH}")
