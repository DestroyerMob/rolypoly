import bpy
import math
import os
from mathutils import Vector


ROOT = "/Users/nanzhe/Desktop/rolypoly"
MODEL_DIR = os.path.join(ROOT, "assets", "models", "obstacles")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source")
RENDER_DIR = os.path.join(ROOT, "renders")
for directory in (MODEL_DIR, SOURCE_DIR, RENDER_DIR):
    os.makedirs(directory, exist_ok=True)


def make_material(name, color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def move_to(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, name, mat, collection, root, bevel=0.0):
    obj.name = name
    move_to(obj, collection)
    obj.parent = root
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Soft_Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.select_set(False)
    return obj


def cylinder(name, x, radius, length, mat, collection, root, bevel=0.05):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=radius, depth=length, location=(x, 0, 0), rotation=(0, math.pi / 2, 0)
    )
    return finish(bpy.context.object, name, mat, collection, root, bevel)


def ring(name, x, radius, thickness, mat, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32, minor_segments=8, major_radius=radius, minor_radius=thickness,
        location=(x, 0, 0), rotation=(0, math.pi / 2, 0),
    )
    return finish(bpy.context.object, name, mat, collection, root)


def spiral(name, phase, mat, collection, root):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 2
    data.bevel_depth = 0.035
    data.bevel_resolution = 3
    spline = data.splines.new("POLY")
    point_count = 180
    spline.points.add(point_count - 1)
    for index in range(point_count):
        t = index / (point_count - 1)
        angle = phase + math.tau * 1.35 * t
        spline.points[index].co = (-2.55 + 5.10 * t, 1.018 * math.cos(angle), 1.018 * math.sin(angle), 1)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(mat)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"

wood = make_material("Spinner_HoneyWood", (0.76, 0.34, 0.10), roughness=0.38)
light_wood = make_material("Spinner_LightWood", (0.95, 0.61, 0.23), roughness=0.42)
dark_line = make_material("Spinner_DarkLine", (0.20, 0.045, 0.012), roughness=0.42)
light_line = make_material("Spinner_LightLine", (1.0, 0.82, 0.34), roughness=0.34)
metal = make_material("Spinner_Axle", (0.55, 0.62, 0.67), 0.72, 0.26)

collection = bpy.data.collections.new("RollingPinSpinner")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("RollingPinSpinner_Root", None)
collection.objects.link(root)

cylinder("RollingPinSpinner_Barrel", 0, 1.0, 5.6, wood, collection, root, 0.12)
ring("RollingPinSpinner_BandLeft", -2.48, 1.01, 0.05, light_wood, collection, root)
ring("RollingPinSpinner_BandRight", 2.48, 1.01, 0.05, light_wood, collection, root)
# Two asymmetric helical lines make rotation obvious even from far away.
spiral("RollingPinSpinner_DarkSpiral", 0, dark_line, collection, root)
spiral("RollingPinSpinner_LightSpiral", math.pi, light_line, collection, root)
cylinder("RollingPinSpinner_AxleLeft", -3.05, 0.17, 0.82, metal, collection, root, 0.04)
cylinder("RollingPinSpinner_AxleRight", 3.05, 0.17, 0.82, metal, collection, root, 0.04)
cylinder("RollingPinSpinner_HandleLeft", -3.72, 0.30, 1.0, light_wood, collection, root, 0.10)
cylinder("RollingPinSpinner_HandleRight", 3.72, 0.30, 1.0, light_wood, collection, root, 0.10)

for name, x in (("RollingPinSpinner_TipLeft", -4.22), ("RollingPinSpinner_TipRight", 4.22)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.30, location=(x, 0, 0))
    finish(bpy.context.object, name, light_wood, collection, root)

# Save and export with the long axis along Blender Y. This maps to Godot Z,
# matching the vertical/front-to-back placement used by the gameplay scene.
root.rotation_euler[2] = math.radians(90.0)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "RollingPinSpinner.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "RollingPinSpinner.glb"),
    export_format="GLB", use_selection=True, export_yup=True,
)

preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_mat = make_material("Preview_Floor", (0.075, 0.085, 0.11), roughness=0.8)
bpy.ops.mesh.primitive_cube_add(location=(0, 0, -1.18))
floor = bpy.context.object
floor.dimensions = (10, 6.5, 0.24)
move_to(floor, preview)
floor.data.materials.append(floor_mat)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
root.rotation_euler[0] = math.radians(32)

target = Vector((0, 0, 0.05))
bpy.ops.object.camera_add(location=(7.8, -10.5, 5.4))
camera = bpy.context.object
move_to(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58
bpy.context.scene.camera = camera

for name, location, energy, color, size in (
    ("Key", (-4, -4, 7), 1100, (1.0, 0.72, 0.48), 4.5),
    ("Fill", (5, -1, 4.5), 800, (0.48, 0.70, 1.0), 4),
    ("Rim", (0, 4, 5.5), 950, (1.0, 0.34, 0.16), 3.5),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    light = bpy.data.objects.new(name, data)
    preview.objects.link(light)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.018, 0.03, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1200, 760, 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "rolling_pin_spinner_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Created RollingPinSpinner.blend, RollingPinSpinner.glb, and preview")
