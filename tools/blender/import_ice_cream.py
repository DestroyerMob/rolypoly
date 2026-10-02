"""Center the supplied scoop and export a vanilla player model.

Run with Blender --background --factory-startup --python tools/blender/import_ice_cream.py.
Append -- --preview /absolute/path.png to render the exported model.
"""

import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "models/desserts/ice_cream"
RADIUS = 1.1
VANILLA = (0.94, 0.88, 0.75, 1.0)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ASSET / "source/chocolate_ice_cream.glb"))
model = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
points = [model.matrix_world @ vertex.co for vertex in model.data.vertices]
minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
center = (minimum + maximum) / 2.0
# Fit the entire uneven scoop inside the player's rolling sphere.
scale = RADIUS / max((point - center).length for point in points)
for vertex, point in zip(model.data.vertices, points):
    vertex.co = (point - center) * scale
model.matrix_world = Matrix.Identity(4)
model.name = "VanillaIceCream"
model.data.name = "VanillaIceCreamMesh"

for material in model.data.materials:
    material.name = "VanillaIceCream"
    material.diffuse_color = VANILLA
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            # Keep the original roughness map and sculpted scoop detail.
            for link in list(node.inputs["Base Color"].links):
                material.node_tree.links.remove(link)
            node.inputs["Base Color"].default_value = VANILLA

bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.context.view_layer.objects.active = model
output = ASSET / "vanilla_ice_cream.glb"
bpy.ops.export_scene.gltf(
    filepath=str(output),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)
print(f"Exported vanilla scoop with radius {RADIUS}: {output}")

parser = argparse.ArgumentParser()
parser.add_argument("--preview", type=Path)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
if args.preview:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(output))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.world.color = (0.22, 0.22, 0.22)
    bpy.ops.object.camera_add(location=(3.5, -4.7, 2.5))
    camera = bpy.context.object
    camera.rotation_euler = (-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 52
    scene.camera = camera
    for position, power, size in [((2, -4, 5), 550, 4), ((-3, -1, 2), 220, 3)]:
        bpy.ops.object.light_add(type="AREA", location=position)
        light = bpy.context.object
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (-light.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(args.preview.resolve())
    bpy.ops.render.render(write_still=True)
