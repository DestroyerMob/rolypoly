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
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft_Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.select_set(False)
    return obj


def cylinder_z(name, x, z, radius, length, mat, collection, root, bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=length, location=(x, 0, z))
    return finish(bpy.context.object, name, mat, collection, root, bevel)


def cylinder_between(name, start, end, radius, mat, collection, root):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=direction.length, location=(start_v + end_v) * 0.5)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat, collection, root, 0.035)


def create_perforated_bowl(mat, hole_mat, collection, root):
    center_x = 1.15
    rim_z = -3.58
    outer_radius = 1.45
    inner_radius = 1.27
    outer_depth = 0.82
    inner_depth = 0.64
    segments = 48
    rings = 14
    profile = []

    # Open, shallow outer and inner surfaces joined only at the rim and bottom.
    for ring in range(rings + 1):
        theta = math.pi * 0.5 * ring / rings
        profile.append((outer_radius * math.sin(theta), rim_z - outer_depth * math.cos(theta)))
    for ring in range(rings, -1, -1):
        theta = math.pi * 0.5 * ring / rings
        profile.append((inner_radius * math.sin(theta), rim_z - inner_depth * math.cos(theta)))

    vertices = []
    for radial, z in profile:
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append((center_x + radial * math.cos(angle), radial * math.sin(angle), z))
    faces = []
    for index in range(len(profile) - 1):
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append((index * segments + segment, index * segments + nxt,
                          (index + 1) * segments + nxt, (index + 1) * segments + segment))
    mesh = bpy.data.meshes.new("LadleVertical_Bowl_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bowl = bpy.data.objects.new("LadleVertical_Bowl", mesh)
    collection.objects.link(bowl)
    bowl.parent = root
    bowl.data.materials.append(mat)
    for polygon in bowl.data.polygons:
        polygon.use_smooth = True

    bpy.ops.mesh.primitive_torus_add(
        major_segments=48, minor_segments=10, major_radius=1.36, minor_radius=0.075,
        location=(center_x, 0.0, rim_z),
    )
    finish(bpy.context.object, "LadleVertical_Rim", mat, collection, root)

    # Dark recessed discs read clearly as drain holes while preserving a stable
    # collision surface for the game ball.
    holes = [
        (0.0, 0.0), (-0.42, 0.0), (0.42, 0.0), (0.0, -0.42), (0.0, 0.42),
        (-0.32, -0.32), (-0.32, 0.32), (0.32, -0.32), (0.32, 0.32),
    ]
    for index, (dx, dy) in enumerate(holes, start=1):
        radial = math.sqrt(dx * dx + dy * dy)
        surface_z = rim_z - inner_depth * math.sqrt(max(0.0, 1.0 - (radial / inner_radius) ** 2))
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=20, radius=0.115, depth=0.025,
            location=(center_x + dx, dy, surface_z + 0.018),
        )
        finish(bpy.context.object, f"LadleVertical_Hole_{index:02d}", hole_mat, collection, root, 0.008)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"

steel = make_material("Skimmer_Steel", (0.55, 0.67, 0.74), 0.82, 0.24)
dark = make_material("Skimmer_DarkSteel", (0.12, 0.18, 0.23), 0.74, 0.30)
coral = make_material("Skimmer_CoralGrip", (0.92, 0.16, 0.10), 0.05, 0.34)
gold = make_material("Skimmer_Collar", (0.96, 0.53, 0.08), 0.48, 0.28)

collection = bpy.data.collections.new("LadleVertical")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("LadleVertical_Root", None)
collection.objects.link(root)

bpy.ops.mesh.primitive_torus_add(
    major_segments=28, minor_segments=10, major_radius=0.25, minor_radius=0.085,
    location=(0, 0, -0.10), rotation=(math.pi / 2, 0, 0),
)
finish(bpy.context.object, "LadleVertical_PivotEye", dark, collection, root)
cylinder_z("LadleVertical_HandleGrip", 0, -0.78, 0.20, 1.05, coral, collection, root, 0.06)
cylinder_z("LadleVertical_Handle", 0, -2.00, 0.115, 1.55, steel, collection, root, 0.035)
cylinder_z("LadleVertical_Collar", 0, -2.82, 0.19, 0.30, gold, collection, root, 0.045)
cylinder_between("LadleVertical_Neck", (0, 0, -2.98), (0.16, 0, -3.60), 0.13, dark, collection, root)
create_perforated_bowl(steel, dark, collection, root)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "LadleVertical.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "LadleVertical.glb"),
    export_format="GLB", use_selection=True, export_yup=True,
)

preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_mat = make_material("Preview_Floor", (0.055, 0.07, 0.09), roughness=0.82)
bpy.ops.mesh.primitive_cube_add(location=(0.6, 0, -5.22))
floor = bpy.context.object
floor.dimensions = (7.5, 6.5, 0.18)
move_to(floor, preview)
floor.data.materials.append(floor_mat)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
root.rotation_euler[1] = math.radians(-12)

target = Vector((0.5, 0, -2.55))
bpy.ops.object.camera_add(location=(7.6, -10.5, 4.4))
camera = bpy.context.object
move_to(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 60
bpy.context.scene.camera = camera

for name, location, energy, color, size in (
    ("Key", (-4, -4.5, 4), 1250, (1.0, 0.74, 0.52), 4.5),
    ("Fill", (5, -1, 2), 900, (0.42, 0.67, 1.0), 4.2),
    ("RimLight", (0, 4, 3), 1100, (1.0, 0.24, 0.12), 3.8),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    light = bpy.data.objects.new(name, data)
    preview.objects.link(light)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.014, 0.026, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.30
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 900, 1050, 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "ladle_vertical_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Updated LadleVertical as an upward-facing perforated skimmer")
