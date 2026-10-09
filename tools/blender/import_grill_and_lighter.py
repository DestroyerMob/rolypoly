"""Convert the supplied grill and lighter archives into reusable Godot models.

Run with Blender --background --factory-startup --disable-autoexec --python
tools/blender/import_grill_and_lighter.py after extracting the archives into
their respective assets/models directories. Original sources stay untouched.
"""

from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
GRILL = ROOT / "assets/models/obstacles/iron_grill"
LIGHTER = ROOT / "assets/models/props/lighter"


def texture(material, directory, filename, socket, data=False):
    nodes = material.node_tree.nodes
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(str(directory / "textures" / filename))
    if data:
        image.image.colorspace_settings.name = "Non-Color"
    surface = nodes.get("Principled BSDF")
    if socket == "Normal":
        normal = nodes.new("ShaderNodeNormalMap")
        material.node_tree.links.new(image.outputs["Color"], normal.inputs["Color"])
        material.node_tree.links.new(normal.outputs["Normal"], surface.inputs[socket])
    else:
        material.node_tree.links.new(image.outputs["Color"], surface.inputs[socket])


def export_model(model, destination):
    bpy.ops.object.select_all(action="DESELECT")
    model.select_set(True)
    bpy.context.view_layer.objects.active = model
    bpy.ops.export_scene.gltf(
        filepath=str(destination), export_format="GLB", use_selection=True,
        export_yup=True, export_cameras=False, export_lights=False,
    )
    bounds = [model.matrix_world @ Vector(corner) for corner in model.bound_box]
    print(destination.name, "Blender bounds:",
          tuple(min(v[a] for v in bounds) for a in range(3)),
          tuple(max(v[a] for v in bounds) for a in range(3)))


bpy.ops.wm.open_mainfile(filepath=str(GRILL / "source/iron grill.blend.blend"))
source = bpy.data.objects["grill"]
evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = bpy.data.meshes.new_from_object(evaluated)
model = bpy.data.objects.new("IronGrill-col", mesh)
bpy.context.collection.objects.link(model)
stretch = source.matrix_world.to_scale()
for vertex in mesh.vertices:
    vertex.co = Vector(tuple(vertex.co[a] * abs(stretch[a]) * 10 for a in range(3)))
low = Vector(tuple(min(v.co[a] for v in mesh.vertices) for a in range(3)))
high = Vector(tuple(max(v.co[a] for v in mesh.vertices) for a in range(3)))
origin = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, high.z))
for vertex in mesh.vertices:
    vertex.co -= origin
material = bpy.data.materials.new("WeatheredIron")
material.use_nodes = True
surface = material.node_tree.nodes.get("Principled BSDF")
surface.inputs["Metallic"].default_value = 0.85
surface.inputs["Roughness"].default_value = 0.55
texture(material, GRILL, "b15metals017.jpeg", "Base Color")
mesh.materials.clear()
mesh.materials.append(material)
for polygon in mesh.polygons:
    polygon.material_index = 0
export_model(model, GRILL / "iron_grill.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(
    filepath=str(LIGHTER / "source/lighter.obj"),
    forward_axis="NEGATIVE_Z", up_axis="Y",
)
model = next(o for o in bpy.context.scene.objects if o.type == "MESH")
model.data.transform(model.matrix_world)
model.matrix_world = Matrix.Identity(4)
vertices = model.data.vertices
low = Vector(tuple(min(v.co[a] for v in vertices) for a in range(3)))
high = Vector(tuple(max(v.co[a] for v in vertices) for a in range(3)))
origin = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
scale = 6 / (high.z - low.z)
for vertex in vertices:
    vertex.co = (vertex.co - origin) * scale
material = bpy.data.materials.new("Lighter")
material.use_nodes = True
for filename, socket, data in (
    ("lighter_diffuse.tga.png", "Base Color", False),
    ("lighter_metallic.tga.png", "Metallic", True),
    ("lighter_roughness.tga.png", "Roughness", True),
    ("lighter_normal.tga.png", "Normal", True),
):
    texture(material, LIGHTER, filename, socket, data)
model.data.materials.clear()
model.data.materials.append(material)
for polygon in model.data.polygons:
    polygon.material_index = 0
model.name = "Lighter"
export_model(model, LIGHTER / "lighter.glb")
