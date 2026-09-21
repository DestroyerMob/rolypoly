import bpy
import math
import os
from mathutils import Vector


PROJECT_ROOT = "/Users/nanzhe/Desktop/rolypoly"
MODEL_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "obstacles")
SOURCE_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "source")
RENDER_DIR = os.path.join(PROJECT_ROOT, "renders")

for directory in (MODEL_DIR, SOURCE_DIR, RENDER_DIR):
    os.makedirs(directory, exist_ok=True)


def material(name, color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def move_to_collection(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, name, mat, collection, root, bevel=0.0, smooth=True):
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = root
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft_Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.select_set(False)
    return obj


def add_cylinder(name, x, z, radius, length, mat, collection, root, vertices=24, bevel=0.05):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=length,
        location=(x, 0.0, z),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    return finish(bpy.context.object, name, mat, collection, root, bevel)


def add_sphere(name, x, z, radius, mat, collection, root):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=12,
        radius=radius,
        location=(x, 0.0, z),
    )
    return finish(bpy.context.object, name, mat, collection, root)


def add_ring(name, x, z, major_radius, minor_radius, mat, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=28,
        minor_segments=8,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=(x, 0.0, z),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    return finish(bpy.context.object, name, mat, collection, root, smooth=True)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0

wood = material("Honey_Wood", (0.76, 0.34, 0.10), metallic=0.0, roughness=0.38)
wood_light = material("Light_Wood", (0.95, 0.61, 0.23), metallic=0.0, roughness=0.42)
wood_dark = material("Dark_Wood", (0.35, 0.11, 0.035), metallic=0.0, roughness=0.48)
metal = material("Axle_Metal", (0.55, 0.62, 0.67), metallic=0.72, roughness=0.26)

collection = bpy.data.collections.new("RollingPin")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("RollingPin_Root", None)
collection.objects.link(root)
root.empty_display_type = "PLAIN_AXES"

center_z = 0.58
add_cylinder("RollingPin_Barrel", 0.0, center_z, 0.56, 3.6, wood, collection, root, vertices=28, bevel=0.10)
add_ring("RollingPin_Band_Left", -1.47, center_z, 0.565, 0.035, wood_light, collection, root)
add_ring("RollingPin_Band_Right", 1.47, center_z, 0.565, 0.035, wood_light, collection, root)
add_ring("RollingPin_Grain_Left", -0.62, center_z, 0.562, 0.014, wood_dark, collection, root)
add_ring("RollingPin_Grain_Right", 0.62, center_z, 0.562, 0.014, wood_dark, collection, root)

add_cylinder("RollingPin_Axle_Left", -2.03, center_z, 0.15, 0.82, metal, collection, root, vertices=18, bevel=0.035)
add_cylinder("RollingPin_Axle_Right", 2.03, center_z, 0.15, 0.82, metal, collection, root, vertices=18, bevel=0.035)
add_cylinder("RollingPin_Handle_Left", -2.72, center_z, 0.24, 1.05, wood_light, collection, root, vertices=22, bevel=0.09)
add_cylinder("RollingPin_Handle_Right", 2.72, center_z, 0.24, 1.05, wood_light, collection, root, vertices=22, bevel=0.09)
add_sphere("RollingPin_HandleTip_Left", -3.245, center_z, 0.24, wood_light, collection, root)
add_sphere("RollingPin_HandleTip_Right", 3.245, center_z, 0.24, wood_light, collection, root)

# Save a clean, independently editable Blender source.
source_path = os.path.join(SOURCE_DIR, "RollingPin.blend")
bpy.ops.wm.save_as_mainfile(filepath=source_path)

# Export only the model collection for Godot.
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "RollingPin.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)

# Temporary studio setup for a preview render; it is not saved into the source file.
preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_mat = material("Preview_Floor", (0.075, 0.085, 0.11), roughness=0.8)
bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, -0.16))
floor = bpy.context.object
floor.name = "Preview_Floor"
floor.dimensions = (9.0, 6.5, 0.24)
move_to_collection(floor, preview)
floor.data.materials.append(floor_mat)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

target = Vector((0.0, 0.0, 0.62))
bpy.ops.object.camera_add(location=(7.4, -10.2, 5.3))
camera = bpy.context.object
move_to_collection(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58
bpy.context.scene.camera = camera

def add_light(name, location, energy, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    preview.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()

add_light("Key_Light", (-4.0, -4.0, 7.0), 1100, (1.0, 0.72, 0.48), 4.5)
add_light("Fill_Light", (5.0, -1.0, 4.5), 800, (0.48, 0.70, 1.0), 4.0)
add_light("Rim_Light", (0.0, 4.0, 5.5), 950, (1.0, 0.34, 0.16), 3.5)

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.018, 0.03, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1200
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "rolling_pin_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)

print("Created RollingPin.blend, RollingPin.glb, and rolling_pin_preview.png")
