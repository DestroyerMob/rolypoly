"""Export the supplied cream can and styled powerup base as reusable GLBs."""
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROPS = Path(__file__).resolve().parents[2] / "assets/models/props"


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                              use_selection=True, export_animations=False)


def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


clear_scene()
cream_dir = PROPS / "whipped_cream"
bpy.ops.import_scene.fbx(filepath=str(cream_dir / "source/creamcan_rigged.fbx"))
# The source also contains hidden, oversized modeling parts. Export only the
# finished can, baking its rest pose so the loose animation rig is not required.
armature = bpy.data.objects["Armature"]
armature.data.pose_position = "REST"
armature.animation_data_clear()
bpy.context.view_layer.update()
source = bpy.data.objects["Creamcanmesh"]
mesh = bpy.data.meshes.new_from_object(
    source.evaluated_get(bpy.context.evaluated_depsgraph_get()))
mesh.transform(source.matrix_world)
bottom = min(v.co.z for v in mesh.vertices)
top = max(v.co.z for v in mesh.vertices)
center_x = (min(v.co.x for v in mesh.vertices) + max(v.co.x for v in mesh.vertices)) / 2
center_y = (min(v.co.y for v in mesh.vertices) + max(v.co.y for v in mesh.vertices)) / 2
mesh.transform(Matrix.Scale(1 / (top - bottom), 4)
               @ Matrix.Translation(Vector((-center_x, -center_y, -bottom))))
can = bpy.data.objects.new("WhippedCreamCan", mesh)
bpy.context.collection.objects.link(can)
mat = material("Cream can label and metal", (1, 1, 1), 0, 0.4)
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get("Principled BSDF")
for suffix, socket, color_data in (
    ("Base_Color", "Base Color", True),
    ("Metallic", "Metallic", False),
    ("Roughness", "Roughness", False),
    ("Normal_OpenGL", "Normal", False),
):
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(cream_dir / f"source/textures/Cream_can_{suffix}.png"))
    if not color_data:
        texture.image.colorspace_settings.name = "Non-Color"
    output = texture.outputs["Color"]
    if socket == "Normal":
        normal = nodes.new("ShaderNodeNormalMap")
        links.new(output, normal.inputs["Color"])
        output = normal.outputs["Normal"]
    links.new(output, bsdf.inputs[socket])
mesh.materials.clear()
mesh.materials.append(mat)
export(can, cream_dir / "whipped_cream.glb")

clear_scene()
base_dir = PROPS / "powerup_base"
bpy.ops.import_scene.fbx(filepath=str(base_dir / "source/powerup_base.fbx"))
bpy.context.view_layer.update()
base = next(o for o in bpy.context.scene.objects if o.type == "MESH")
base.data.transform(base.matrix_world)
base.matrix_world = Matrix.Identity(4)
bottom = min(v.co.z for v in base.data.vertices)
height = max(v.co.z for v in base.data.vertices) - bottom
width = max(v.co.x for v in base.data.vertices) - min(v.co.x for v in base.data.vertices)
base.data.transform(Matrix.Diagonal((5.5 / width, 5.5 / width, 0.55 / height, 1))
                    @ Matrix.Translation(Vector((0, 0, -bottom))))
base.name = "PowerupBase"
base.data.materials.clear()
for mat in (
    material("Graphite housing", (0.035, 0.065, 0.085), 0.7, 0.3),
    material("Porcelain top", (0.72, 0.83, 0.82), 0.22, 0.26),
    material("Brushed teal trim", (0.06, 0.3, 0.32), 0.65, 0.28),
):
    base.data.materials.append(mat)
base.data.update()
for face in base.data.polygons:
    face.material_index = 1 if face.normal.z > 0.5 else (2 if face.center.z > 0.32 else 0)
bevel = base.modifiers.new("Soft machined edges", "BEVEL")
bevel.width = 0.035
bevel.segments = 3
bpy.context.view_layer.objects.active = base
bpy.ops.object.modifier_apply(modifier=bevel.name)
export(base, base_dir / "powerup_base.glb")
