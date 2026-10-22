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


def add_cylinder(name, x, z, radius, length, mat, collection, root, vertices=24, bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=length,
        location=(x, 0.0, z),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    return finish(bpy.context.object, name, mat, collection, root, bevel)


def add_torus(name, x, z, major_radius, minor_radius, mat, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=28,
        minor_segments=10,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=(x, 0.0, z),
    )
    return finish(bpy.context.object, name, mat, collection, root)


def add_bowl(name, center_x, rim_z, outer_radius, thickness, mat, collection, root):
    segments = 40
    rings = 12
    inner_radius = outer_radius - thickness
    profile = []

    # Revolve a closed outer/inner hemispherical profile. The open top stays open,
    # while the rim and bottom thickness make the mesh useful as real collision.
    for ring in range(rings + 1):
        theta = (math.pi * 0.5) * ring / rings
        profile.append(
            (
                outer_radius * math.sin(theta),
                rim_z - outer_radius * math.cos(theta),
            )
        )
    for ring in range(rings, -1, -1):
        theta = (math.pi * 0.5) * ring / rings
        profile.append(
            (
                inner_radius * math.sin(theta),
                rim_z - inner_radius * math.cos(theta),
            )
        )

    vertices = []
    for radial, z in profile:
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append((center_x + radial * math.cos(angle), radial * math.sin(angle), z))

    faces = []
    profile_count = len(profile)
    for profile_index in range(profile_count - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            a = profile_index * segments + segment
            b = profile_index * segments + next_segment
            c = (profile_index + 1) * segments + next_segment
            d = (profile_index + 1) * segments + segment
            faces.append((a, b, c, d))

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bowl = bpy.data.objects.new(name, mesh)
    collection.objects.link(bowl)
    bowl.parent = root
    bowl.data.materials.append(mat)
    for polygon in bowl.data.polygons:
        polygon.use_smooth = True

    bevel = bowl.modifiers.new("Rounded_Rim", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 2
    bpy.context.view_layer.objects.active = bowl
    bowl.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bowl.select_set(False)
    return bowl


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0

steel = material("Brushed_Steel", (0.55, 0.67, 0.74), metallic=0.82, roughness=0.24)
steel_dark = material("Dark_Steel", (0.12, 0.18, 0.23), metallic=0.74, roughness=0.30)
coral = material("Coral_Grip", (0.92, 0.16, 0.10), metallic=0.05, roughness=0.34)
gold = material("Warm_Collar", (0.96, 0.53, 0.08), metallic=0.48, roughness=0.28)

collection = bpy.data.collections.new("Ladle")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Ladle_Root", None)
collection.objects.link(root)
root.empty_display_type = "PLAIN_AXES"

# The pivot is at the tail of the handle. The ladle lies flat and extends
# along +X, so Godot can sweep it left/right around a vertical axis.
add_torus("Ladle_PivotEye", 0.0, 0.24, 0.26, 0.085, steel_dark, collection, root)
add_cylinder("Ladle_HandleGrip", 0.78, 0.24, 0.20, 1.08, coral, collection, root, vertices=24, bevel=0.065)
add_cylinder("Ladle_Handle", 1.95, 0.20, 0.115, 1.55, steel, collection, root, vertices=20, bevel=0.035)
add_cylinder("Ladle_Collar", 2.74, 0.20, 0.19, 0.28, gold, collection, root, vertices=24, bevel=0.045)
add_cylinder("Ladle_Neck", 2.93, 0.15, 0.13, 0.36, steel_dark, collection, root, vertices=20, bevel=0.035)
add_bowl("Ladle_Bowl", 4.38, 0.0, 1.46, 0.18, steel, collection, root)

source_path = os.path.join(SOURCE_DIR, "Ladle.blend")
bpy.ops.wm.save_as_mainfile(filepath=source_path)

bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "Ladle.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)

# Add a temporary studio only for the preview; it is deliberately not saved.
preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_mat = material("Preview_Floor", (0.055, 0.07, 0.09), roughness=0.82)
bpy.ops.mesh.primitive_cube_add(location=(2.7, 0.0, -1.58))
floor = bpy.context.object
floor.name = "Preview_Floor"
floor.dimensions = (9.0, 7.0, 0.18)
move_to_collection(floor, preview)
floor.data.materials.append(floor_mat)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

root.rotation_euler[2] = math.radians(-9.0)
target = Vector((2.7, 0.0, -0.30))
bpy.ops.object.camera_add(location=(9.3, -10.8, 7.0))
camera = bpy.context.object
move_to_collection(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 62
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


add_light("Key_Light", (-4.0, -4.5, 4.5), 1250, (1.0, 0.74, 0.52), 4.5)
add_light("Fill_Light", (5.0, -1.0, 1.5), 900, (0.42, 0.67, 1.0), 4.2)
add_light("Rim_Light", (0.0, 4.0, 2.8), 1100, (1.0, 0.24, 0.12), 3.8)

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.014, 0.026, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.30

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1050
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "ladle_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)

print("Created Ladle.blend, Ladle.glb, and ladle_preview.png")
