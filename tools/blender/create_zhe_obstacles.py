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


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass


def material(name, color, metallic=0.0, roughness=0.55):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
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


def finish_object(obj, name, mat, collection, parent=None, bevel=0.0, smooth=False):
    obj.name = name
    move_to_collection(obj, collection)
    if parent:
        obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Soft_Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.select_set(False)
    return obj


def add_cube(name, location, dimensions, mat, collection, parent=None, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.dimensions = dimensions
    return finish_object(obj, name, mat, collection, parent, bevel)


def add_cylinder(name, location, radius, depth, mat, collection, parent=None, rotation=(0, 0, 0), vertices=20, bevel=0.04, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    return finish_object(obj, name, mat, collection, parent, bevel, smooth)


def add_uv_sphere(name, location, radius, mat, collection, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=radius, location=location)
    return finish_object(bpy.context.object, name, mat, collection, parent, 0.0, True)


def add_torus(name, location, major_radius, minor_radius, mat, collection, parent=None):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32,
        minor_segments=8,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
    )
    return finish_object(bpy.context.object, name, mat, collection, parent, 0.0, True)


def create_funnel_shell(name, collection, parent, mat):
    segments = 32
    outer_bottom = 0.98
    inner_bottom = 0.74
    outer_top = 2.40
    inner_top = 2.16
    z_bottom = 0.48
    z_top = 2.78
    verts = []
    for radius, z in (
        (outer_bottom, z_bottom),
        (outer_top, z_top),
        (inner_top, z_top),
        (inner_bottom, z_bottom),
    ):
        for i in range(segments):
            angle = 2.0 * math.pi * i / segments
            verts.append((radius * math.cos(angle), radius * math.sin(angle), z))

    faces = []
    for i in range(segments):
        n = (i + 1) % segments
        ob, obn = i, n
        ot, otn = segments + i, segments + n
        it, itn = 2 * segments + i, 2 * segments + n
        ib, ibn = 3 * segments + i, 3 * segments + n
        faces.extend(
            [
                (ob, obn, otn, ot),
                (ot, otn, itn, it),
                (it, itn, ibn, ib),
                (ib, ibn, obn, ob),
            ]
        )

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    bevel = obj.modifiers.new("Rounded_Rims", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)
    return obj


def select_collection(collection):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    roots = [obj for obj in collection.objects if obj.parent is None]
    if roots:
        bpy.context.view_layer.objects.active = roots[0]


clear_scene()
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0

metal = material("Warm_Brushed_Metal", (0.60, 0.66, 0.70), metallic=0.72, roughness=0.28)
metal_dark = material("Dark_Metal", (0.12, 0.16, 0.19), metallic=0.62, roughness=0.34)
coral = material("Coral_Handle", (0.93, 0.25, 0.20), metallic=0.0, roughness=0.48)
teal = material("Funnel_Teal", (0.18, 0.64, 0.63), metallic=0.08, roughness=0.42)
cream = material("Funnel_Rim", (1.00, 0.67, 0.22), metallic=0.0, roughness=0.4)

# Masher: broad enough to cover the current one-unit player ball.
masher_collection = bpy.data.collections.new("Masher")
bpy.context.scene.collection.children.link(masher_collection)
masher_root = bpy.data.objects.new("Masher_Root", None)
masher_collection.objects.link(masher_root)
masher_root.empty_display_type = "PLAIN_AXES"

add_cylinder("Masher_Plate", (0, 0, 0.18), 1.38, 0.26, metal, masher_collection, masher_root, vertices=28, bevel=0.08)
add_cylinder("Masher_Plate_Underside", (0, 0, 0.035), 1.18, 0.08, metal_dark, masher_collection, masher_root, vertices=28, bevel=0.035)
add_cylinder("Masher_Shaft", (0, 0, 1.62), 0.13, 2.72, metal_dark, masher_collection, masher_root, vertices=16, bevel=0.04)
add_cylinder("Masher_Collar", (0, 0, 2.82), 0.30, 0.42, metal, masher_collection, masher_root, vertices=20, bevel=0.06)
add_cylinder("Masher_Handle", (0, 0, 3.18), 0.30, 2.12, coral, masher_collection, masher_root, rotation=(0, math.pi / 2, 0), vertices=20, bevel=0.07)
add_uv_sphere("Masher_Handle_Left", (-1.06, 0, 3.18), 0.30, coral, masher_collection, masher_root)
add_uv_sphere("Masher_Handle_Right", (1.06, 0, 3.18), 0.30, coral, masher_collection, masher_root)

hole_positions = [(0, 0), (0.48, 0), (-0.48, 0), (0, 0.48), (0, -0.48), (0.44, 0.44), (-0.44, 0.44), (0.44, -0.44), (-0.44, -0.44)]
for index, (x, y) in enumerate(hole_positions, start=1):
    add_cylinder(f"Masher_Hole_{index:02d}", (x, y, 0.322), 0.105, 0.018, metal_dark, masher_collection, masher_root, vertices=16, bevel=0.01)

# Funnel: 1.48 m inner exit diameter, leaving clearance for the 1 m ball.
funnel_collection = bpy.data.collections.new("Funnel")
bpy.context.scene.collection.children.link(funnel_collection)
funnel_root = bpy.data.objects.new("Funnel_Root", None)
funnel_collection.objects.link(funnel_root)
funnel_root.empty_display_type = "PLAIN_AXES"

create_funnel_shell("Funnel_Body", funnel_collection, funnel_root, teal)
add_torus("Funnel_Top_Rim", (0, 0, 2.78), 2.28, 0.15, cream, funnel_collection, funnel_root)
add_torus("Funnel_Throat_Rim", (0, 0, 0.48), 0.86, 0.12, cream, funnel_collection, funnel_root)
add_torus("Funnel_Mid_Band", (0, 0, 1.47), 1.47, 0.055, cream, funnel_collection, funnel_root)

# Export each game-ready visual with its root at the origin.
select_collection(masher_collection)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "Masher.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)

select_collection(funnel_collection)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "Funnel.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)

# Arrange the editable source scene for inspection.
masher_root.location.x = -3.2
funnel_root.location.x = 3.2

preview_collection = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview_collection)
floor_mat = material("Preview_Floor", (0.08, 0.09, 0.11), metallic=0.0, roughness=0.78)
add_cube("Preview_Floor", (0, 0, -0.16), (11.5, 7.5, 0.24), floor_mat, preview_collection, bevel=0.12)

bpy.ops.object.camera_add(location=(9.6, -13.5, 7.7))
camera = bpy.context.object
camera.name = "Preview_Camera"
move_to_collection(camera, preview_collection)
target = Vector((0, 0, 1.55))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 55
bpy.context.scene.camera = camera

def add_area_light(name, location, energy, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    preview_collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()

add_area_light("Key_Light", (-4.5, -4.0, 8.0), 1250, (1.0, 0.79, 0.62), 5.0)
add_area_light("Fill_Light", (6.0, -1.0, 5.0), 900, (0.56, 0.76, 1.0), 4.0)
add_area_light("Rim_Light", (0.0, 5.0, 6.5), 1000, (1.0, 0.42, 0.25), 3.5)

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.023, 0.035, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.33

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1200
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "zhe_obstacles_preview.png")
scene.render.film_transparent = False
scene.view_settings.look = "AgX - Medium High Contrast"

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "Zhe_Kitchen_Obstacles.blend"))
bpy.ops.render.render(write_still=True)

select_collection(masher_collection)
print("Created Masher.glb, Funnel.glb, Zhe_Kitchen_Obstacles.blend, and preview render.")
