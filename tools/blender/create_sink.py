import bpy
import math
import os
from mathutils import Vector


ROOT = "/Users/nanzhe/Desktop/rolypoly"
MODEL_DIR = os.path.join(ROOT, "assets", "models", "obstacles", "sink")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source")
RENDER_DIR = os.path.join(ROOT, "renders")
for directory in (MODEL_DIR, SOURCE_DIR, RENDER_DIR):
    os.makedirs(directory, exist_ok=True)


def make_material(name, color, metallic=0.0, roughness=0.5):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def move_to(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, name, material, collection, root, bevel=0.0, smooth=False):
    obj.name = name
    move_to(obj, collection)
    obj.parent = root
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Rounded_Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.select_set(False)
    return obj


def box(name, location, dimensions, material, collection, root, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.dimensions = dimensions
    return finish(obj, name, material, collection, root, bevel)


def cylinder(name, location, radius, depth, material, collection, root, bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth, location=location)
    return finish(bpy.context.object, name, material, collection, root, bevel, True)


def torus(name, location, major_radius, minor_radius, material, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=48,
        minor_segments=12,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
    )
    return finish(bpy.context.object, name, material, collection, root, 0.0, True)


def lathed_shell(name, profile, material, collection, root):
    segments = 64
    vertices = []
    for radius, height in profile:
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append((radius * math.cos(angle), radius * math.sin(angle), height))
    faces = []
    for profile_index in range(len(profile)):
        next_profile = (profile_index + 1) % len(profile)
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append(
                (
                    profile_index * segments + segment,
                    profile_index * segments + nxt,
                    next_profile * segments + nxt,
                    next_profile * segments + segment,
                )
            )
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def curve_pipe(name, points, bevel_depth, material, collection, root):
    curve_data = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = bevel_depth
    curve_data.bevel_resolution = 5
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve_data)
    collection.objects.link(obj)
    obj.parent = root
    obj.data.materials.append(material)
    return obj


def export_collection(collection, root, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(MODEL_DIR, filename),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
    )


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"

ceramic = make_material("Sink_Warm_Ceramic", (0.80, 0.86, 0.86), metallic=0.03, roughness=0.30)
ceramic_edge = make_material("Sink_Ceramic_Edge", (0.22, 0.47, 0.50), metallic=0.10, roughness=0.25)
steel = make_material("Sink_Brushed_Steel", (0.38, 0.45, 0.49), metallic=0.82, roughness=0.23)
steel_dark = make_material("Sink_Dark_Steel", (0.08, 0.11, 0.13), metallic=0.72, roughness=0.32)
cabinet = make_material("Sink_Deep_Teal_Cabinet", (0.025, 0.18, 0.20), metallic=0.12, roughness=0.36)
brass = make_material("Sink_Warm_Brass", (0.72, 0.43, 0.10), metallic=0.82, roughness=0.22)
plate_material = make_material("Dish_Coral", (0.92, 0.34, 0.25), metallic=0.02, roughness=0.33)
bowl_material = make_material("Dish_Golden_Yellow", (0.95, 0.66, 0.16), metallic=0.03, roughness=0.32)

# Reusable sink model.
sink_collection = bpy.data.collections.new("SinkBasin")
bpy.context.scene.collection.children.link(sink_collection)
sink_root = bpy.data.objects.new("SinkBasin_Root", None)
sink_collection.objects.link(sink_root)

box("Sink_CabinetBase", (0, 0, -0.06), (11.8, 8.2, 0.32), cabinet, sink_collection, sink_root, 0.10)
for side in (-1, 1):
    box("Sink_CabinetSide_%s" % side, (side * 5.55, 0, 1.48), (0.7, 8.2, 2.9), cabinet, sink_collection, sink_root, 0.12)
    box("Sink_CabinetEnd_%s" % side, (0, side * 3.93, 1.48), (10.5, 0.34, 2.9), cabinet, sink_collection, sink_root, 0.10)
box("Sink_BasinFloor", (0, 0, 0.32), (9.45, 6.45, 0.36), steel_dark, sink_collection, sink_root, 0.15)
box("Sink_LeftWall", (-4.95, 0, 1.66), (0.62, 7.05, 3.05), steel, sink_collection, sink_root, 0.18)
box("Sink_RightWall", (4.95, 0, 1.66), (0.62, 7.05, 3.05), steel, sink_collection, sink_root, 0.18)
box("Sink_FrontWall", (0, -3.52, 1.66), (10.5, 0.62, 3.05), steel, sink_collection, sink_root, 0.18)
box("Sink_BackWall", (0, 3.52, 1.66), (10.5, 0.62, 3.05), steel, sink_collection, sink_root, 0.18)

# Broad rim so this can connect directly to level platforms.
box("Sink_LeftCounter", (-5.68, 0, 3.18), (1.45, 8.45, 0.46), ceramic, sink_collection, sink_root, 0.14)
box("Sink_RightCounter", (5.68, 0, 3.18), (1.45, 8.45, 0.46), ceramic, sink_collection, sink_root, 0.14)
box("Sink_FrontCounter", (0, -3.94, 3.18), (10.25, 1.05, 0.46), ceramic, sink_collection, sink_root, 0.14)
box("Sink_BackCounter", (0, 3.94, 3.18), (10.25, 1.05, 0.46), ceramic, sink_collection, sink_root, 0.14)

for x in (-4.85, 4.85):
    box("Sink_RimAccent_%+.1f" % x, (x, -4.38, 3.16), (0.20, 0.10, 0.38), brass, sink_collection, sink_root, 0.025)

# Oversized faucet reads clearly at game scale.
cylinder("Sink_FaucetBase", (0, 3.86, 3.70), 0.68, 0.46, steel, sink_collection, sink_root, 0.07)
curve_pipe(
    "Sink_FaucetPipe",
    [
        Vector((0, 3.86, 3.82)),
        Vector((0, 3.86, 5.45)),
        Vector((0, 2.10, 6.20)),
        Vector((0, 0.55, 5.12)),
    ],
    0.23,
    steel,
    sink_collection,
    sink_root,
)
cylinder("Sink_FaucetNozzle", (0, 0.55, 4.86), 0.32, 0.54, steel_dark, sink_collection, sink_root, 0.05)
for x, color_material in ((-1.25, plate_material), (1.25, bowl_material)):
    cylinder("Sink_TapBase_%+.1f" % x, (x, 3.86, 3.56), 0.38, 0.26, steel, sink_collection, sink_root, 0.05)
    box("Sink_TapHandle_%+.1f" % x, (x, 3.86, 3.96), (1.08, 0.24, 0.20), color_material, sink_collection, sink_root, 0.05)

torus("Sink_DrainRing", (0, 0, 0.53), 0.48, 0.08, brass, sink_collection, sink_root)
cylinder("Sink_Drain", (0, 0, 0.49), 0.42, 0.08, steel_dark, sink_collection, sink_root, 0.02)

# Plate model: low enough to read as a plate, thick enough to be a platform.
plate_collection = bpy.data.collections.new("SinkPlate")
bpy.context.scene.collection.children.link(plate_collection)
plate_root = bpy.data.objects.new("SinkPlate_Root", None)
plate_collection.objects.link(plate_root)
plate_profile = [
    (0.0, -0.07), (0.88, -0.07), (1.08, 0.01), (1.16, 0.12),
    (1.10, 0.21), (0.94, 0.12), (0.0, 0.06),
]
lathed_shell("SinkPlate_Body", plate_profile, plate_material, plate_collection, plate_root)
torus("SinkPlate_Rim", (0, 0, 0.13), 1.08, 0.055, ceramic_edge, plate_collection, plate_root)

# Bowl model: hollow profile with a wide, forgiving top surface.
bowl_collection = bpy.data.collections.new("SinkBowl")
bpy.context.scene.collection.children.link(bowl_collection)
bowl_root = bpy.data.objects.new("SinkBowl_Root", None)
bowl_collection.objects.link(bowl_root)
bowl_profile = [
    (0.26, -0.16), (0.62, -0.12), (0.95, 0.13), (1.09, 0.43),
    (1.03, 0.53), (0.88, 0.39), (0.57, 0.07), (0.24, -0.04),
]
lathed_shell("SinkBowl_Body", bowl_profile, bowl_material, bowl_collection, bowl_root)
torus("SinkBowl_Rim", (0, 0, 0.48), 1.05, 0.062, ceramic_edge, bowl_collection, bowl_root)

# Save one editable Blender source containing all three reusable collections.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "Sink.blend"))
export_collection(sink_collection, sink_root, "SinkBasin.glb")
export_collection(plate_collection, plate_root, "SinkPlate.glb")
export_collection(bowl_collection, bowl_root, "SinkBowl.glb")

# Preview-only scene. It is deliberately not part of the saved source or GLBs.
preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
water_material = make_material("Preview_Water", (0.05, 0.48, 0.66), metallic=0.05, roughness=0.12)
water_material.diffuse_color = (0.05, 0.48, 0.66, 0.72)
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 2.12))
water = bpy.context.object
water.name = "Preview_Water"
water.dimensions = (9.35, 6.35, 0.07)
move_to(water, preview)
water.data.materials.append(water_material)

preview_positions = [
    (plate_collection, plate_root, (-3.10, -1.60, 2.22), 0.05),
    (plate_collection, plate_root, (0.0, 0.0, 2.23), -0.08),
    (plate_collection, plate_root, (3.10, 1.55, 2.22), 0.10),
    (bowl_collection, bowl_root, (3.05, -1.55, 2.16), -0.05),
    (bowl_collection, bowl_root, (-3.0, 1.55, 2.16), 0.07),
]
for index, (source_collection, source_root, location, tilt) in enumerate(preview_positions):
    duplicate_root = source_root.copy()
    preview.objects.link(duplicate_root)
    duplicate_root.location = location
    duplicate_root.rotation_euler = (tilt, tilt * 0.5, index * 0.55)
    for source_child in source_collection.objects:
        if source_child == source_root:
            continue
        duplicate = source_child.copy()
        duplicate.data = source_child.data.copy() if getattr(source_child, "data", None) else None
        preview.objects.link(duplicate)
        duplicate.parent = duplicate_root
        duplicate.matrix_parent_inverse = source_child.matrix_parent_inverse.copy()
        duplicate.matrix_basis = source_child.matrix_basis.copy()

target = Vector((0, 0, 2.35))
bpy.ops.object.camera_add(location=(14.2, -17.0, 11.2))
camera = bpy.context.object
move_to(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58
bpy.context.scene.camera = camera

for name, location, energy, color, size in (
    ("Key", (-7, -7, 11), 1500, (1.0, 0.75, 0.52), 5.0),
    ("Fill", (7, -3, 7), 1100, (0.40, 0.68, 1.0), 4.5),
    ("Rim", (0, 7, 9), 1350, (1.0, 0.38, 0.13), 4.0),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    preview.objects.link(light)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.016, 0.027, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.34
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 820
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "sink_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Created Sink.blend, SinkBasin.glb, SinkPlate.glb, SinkBowl.glb, and preview")
