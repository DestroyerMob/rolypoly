"""Convert the supplied razor blade FBX and textures into a Godot GLB.

Run with Blender --background --factory-startup --python tools/blender/import_razor_blade.py.
"""

from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "assets/models/props/razor_blade"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(ASSET / "source/Razor Blade.fbx"))
models = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]

material = bpy.data.materials.new("RazorBladeSteel")
material.use_nodes = True
surface = material.node_tree.nodes.get("Principled BSDF")
surface.inputs["Metallic"].default_value = 0.85
for filename, socket, color_space in (
    ("BaseTexture.png", "Base Color", "sRGB"),
    ("RazorBladeRoughness.png", "Roughness", "Non-Color"),
):
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(ASSET / "textures" / filename), check_existing=False)
    texture.image.colorspace_settings.name = color_space
    material.node_tree.links.new(texture.outputs["Color"], surface.inputs[socket])

# Bake the FBX transforms while preserving its authored dimensions and UVs.
for model in models:
    model.data.transform(model.matrix_world)
    model.parent = None
    model.matrix_world = Matrix.Identity(4)

vertices = [v.co for model in models for v in model.data.vertices]
minimum = Vector(tuple(min(v[axis] for v in vertices) for axis in range(3)))
maximum = Vector(tuple(max(v[axis] for v in vertices) for axis in range(3)))
origin = Vector(((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, minimum.z))
bpy.ops.object.select_all(action="DESELECT")
for index, model in enumerate(models):
    for vertex in model.data.vertices:
        vertex.co -= origin
    model.data.materials.clear()
    model.data.materials.append(material)
    for polygon in model.data.polygons:
        polygon.material_index = 0
    # Godot generates static collision matching the blade and its cutouts.
    model.name = "RazorBlade-col" if index == 0 else f"RazorBlade{index}-col"
    model.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=str(ASSET / "razor_blade.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)
print(f"Exported razor blade; dimensions {tuple(maximum - minimum)}")
