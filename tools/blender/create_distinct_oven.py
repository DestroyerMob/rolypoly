import bpy
import math
import os
from mathutils import Vector


ROOT = "/Users/nanzhe/Desktop/rolypoly"
MODEL_DIR = os.path.join(ROOT, "assets", "models", "props")
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


def box(name, location, dimensions, material, collection, root, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.dimensions = dimensions
    return finish(obj, name, material, collection, root, bevel)


def cylinder(name, location, radius, depth, rotation, material, collection, root, bevel=0.03):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, material, collection, root, bevel, True)


def torus(name, location, major_radius, minor_radius, rotation, material, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=40,
        minor_segments=10,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, material, collection, root, 0.0, True)


def front_trim(prefix, center_x, center_z, width, height, material, collection, root):
    y = -1.733
    thickness = 0.10
    depth = 0.10
    box(prefix + "_Top", (center_x, y, center_z + height / 2), (width, depth, thickness), material, collection, root, 0.025)
    box(prefix + "_Bottom", (center_x, y, center_z - height / 2), (width, depth, thickness), material, collection, root, 0.025)
    box(prefix + "_Left", (center_x - width / 2, y, center_z), (thickness, depth, height), material, collection, root, 0.025)
    box(prefix + "_Right", (center_x + width / 2, y, center_z), (thickness, depth, height), material, collection, root, 0.025)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"

enamel = make_material("Oven_Deep_Teal_Enamel", (0.025, 0.16, 0.19), metallic=0.18, roughness=0.24)
enamel_dark = make_material("Oven_Deep_Shadow", (0.008, 0.035, 0.045), metallic=0.15, roughness=0.30)
brass = make_material("Oven_Warm_Brass", (0.78, 0.47, 0.11), metallic=0.88, roughness=0.20)
brass_dark = make_material("Oven_Aged_Brass", (0.37, 0.19, 0.035), metallic=0.80, roughness=0.31)
steel = make_material("Oven_Cooktop_Steel", (0.12, 0.14, 0.15), metallic=0.70, roughness=0.25)
glass = make_material("Oven_Smoked_Glass", (0.008, 0.018, 0.022), metallic=0.22, roughness=0.10)
cream = make_material("Oven_Cream_Detail", (0.82, 0.73, 0.56), metallic=0.15, roughness=0.38)
red = make_material("Oven_Heat_Red", (0.55, 0.035, 0.018), metallic=0.10, roughness=0.28)

collection = bpy.data.collections.new("DistinctOven")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("DistinctOven_Root", None)
collection.objects.link(root)

# Large, readable silhouette: body, heavy plinth, cooktop, and tall backguard.
box("DistinctOven_MainBody", (0, 0, 2.15), (8.0, 3.35, 3.85), enamel, collection, root, 0.16)
box("DistinctOven_BasePlinth", (0, 0, 0.22), (8.25, 3.52, 0.44), brass_dark, collection, root, 0.10)
box("DistinctOven_KickPlate", (0, -1.73, 0.62), (7.55, 0.12, 0.38), enamel_dark, collection, root, 0.04)
box("DistinctOven_Cooktop", (0, 0, 4.18), (8.35, 3.65, 0.30), steel, collection, root, 0.08)
box("DistinctOven_FrontLip", (0, -1.91, 4.14), (8.45, 0.20, 0.30), brass, collection, root, 0.04)
box("DistinctOven_Backguard", (0, 1.54, 5.02), (8.0, 0.32, 1.62), enamel, collection, root, 0.12)
box("DistinctOven_BackguardCrown", (0, 1.51, 5.88), (8.24, 0.38, 0.18), brass, collection, root, 0.05)
box("DistinctOven_BackguardStripe", (0, 1.34, 4.82), (7.55, 0.08, 0.12), brass, collection, root, 0.025)

# Feet make the prop feel like a deliberate piece of furniture.
for index, x in enumerate((-3.48, 3.48)):
    for side, y in enumerate((-1.30, 1.30)):
        cylinder(
            f"DistinctOven_Foot_{index}_{side}",
            (x, y, -0.12),
            0.24,
            0.42,
            (0, 0, 0),
            brass,
            collection,
            root,
            0.04,
        )

# Two bold oven doors with smoked windows and layered brass trim.
for side, center_x in (("Left", -2.02), ("Right", 2.02)):
    box(f"DistinctOven_{side}Door", (center_x, -1.715, 2.03), (3.48, 0.18, 2.24), enamel_dark, collection, root, 0.13)
    box(f"DistinctOven_{side}Window", (center_x, -1.825, 2.05), (2.80, 0.055, 1.50), glass, collection, root, 0.12)
    front_trim(f"DistinctOven_{side}OuterTrim", center_x, 2.03, 3.15, 1.92, brass, collection, root)
    front_trim(f"DistinctOven_{side}InnerTrim", center_x, 2.05, 2.56, 1.30, brass_dark, collection, root)
    cylinder(
        f"DistinctOven_{side}Handle",
        (center_x, -2.02, 3.12),
        0.105,
        2.55,
        (0, math.pi / 2, 0),
        brass,
        collection,
        root,
        0.025,
    )
    for post_x in (center_x - 1.08, center_x + 1.08):
        cylinder(
            f"DistinctOven_{side}HandlePost_{post_x:+.2f}",
            (post_x, -1.89, 3.12),
            0.14,
            0.30,
            (math.pi / 2, 0, 0),
            brass,
            collection,
            root,
            0.025,
        )

# Strong vertical corner rails unify the facade and read clearly from far away.
for x in (-3.72, 0, 3.72):
    box(f"DistinctOven_FrontRail_{x:+.2f}", (x, -1.80, 2.12), (0.13, 0.13, 2.95), brass, collection, root, 0.035)

# A row of oversized controls, each with a contrasting center and pointer.
knob_x_positions = (-3.15, -2.10, -1.05, 0, 1.05, 2.10, 3.15)
for index, x in enumerate(knob_x_positions):
    cylinder(
        f"DistinctOven_Knob_{index + 1}",
        (x, -1.90, 3.72),
        0.25,
        0.24,
        (math.pi / 2, 0, 0),
        brass,
        collection,
        root,
        0.025,
    )
    cylinder(
        f"DistinctOven_KnobInset_{index + 1}",
        (x, -2.04, 3.72),
        0.125,
        0.045,
        (math.pi / 2, 0, 0),
        enamel_dark,
        collection,
        root,
        0.012,
    )
    angle = math.radians(-35 + index * 11)
    box(
        f"DistinctOven_KnobPointer_{index + 1}",
        (x + math.sin(angle) * 0.10, -2.075, 3.72 + math.cos(angle) * 0.10),
        (0.035, 0.025, 0.14),
        cream,
        collection,
        root,
        0.008,
    ).rotation_euler[1] = -angle

# Six burner assemblies and a central griddle give the top a useful play surface.
burner_positions = ((-2.75, -0.85), (-2.75, 0.62), (0, -0.85), (0, 0.62), (2.75, -0.85), (2.75, 0.62))
for index, (x, y) in enumerate(burner_positions):
    torus(
        f"DistinctOven_BurnerRing_{index + 1}",
        (x, y, 4.39),
        0.51,
        0.095,
        (0, 0, 0),
        brass_dark,
        collection,
        root,
    )
    cylinder(
        f"DistinctOven_BurnerCap_{index + 1}",
        (x, y, 4.36),
        0.34,
        0.12,
        (0, 0, 0),
        enamel_dark,
        collection,
        root,
        0.025,
    )
    for spoke_index in range(4):
        angle = spoke_index * math.pi / 2
        spoke = box(
            f"DistinctOven_BurnerSpoke_{index + 1}_{spoke_index + 1}",
            (x + math.cos(angle) * 0.42, y + math.sin(angle) * 0.42, 4.43),
            (0.48, 0.075, 0.075),
            steel,
            collection,
            root,
            0.018,
        )
        spoke.rotation_euler[2] = angle

# Original Roly Poly badge prevents the prop from being a branded replica.
bpy.ops.object.text_add(location=(0, -1.955, 4.03), rotation=(math.pi / 2, 0, 0))
badge = bpy.context.object
badge.data.body = "ROLY POLY"
badge.data.align_x = "CENTER"
badge.data.align_y = "CENTER"
badge.data.size = 0.34
badge.data.extrude = 0.018
badge.data.bevel_depth = 0.008
badge.data.materials.append(brass)
badge.name = "DistinctOven_RolyPolyBadge"
move_to(badge, collection)
badge.parent = root
badge.select_set(True)
bpy.context.view_layer.objects.active = badge
bpy.ops.object.convert(target="MESH")
badge.select_set(False)

# Central heat medallion makes the front recognisable even in silhouette.
torus("DistinctOven_CenterMedallion", (0, -1.91, 2.02), 0.34, 0.075, (math.pi / 2, 0, 0), brass, collection, root)
cylinder("DistinctOven_CenterGlow", (0, -2.00, 2.02), 0.22, 0.05, (math.pi / 2, 0, 0), red, collection, root, 0.02)

# Save the clean source and export only the reusable model collection.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "DistinctOven.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "DistinctOven.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)

# Presentation-only floor, camera, and lighting are added after saving/exporting.
preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_material = make_material("Preview_Floor", (0.055, 0.045, 0.038), roughness=0.82)
bpy.ops.mesh.primitive_cube_add(location=(0, 0, -0.43))
floor = bpy.context.object
floor.dimensions = (13.0, 9.0, 0.30)
move_to(floor, preview)
floor.data.materials.append(floor_material)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

target = Vector((0, 0, 2.55))
bpy.ops.object.camera_add(location=(11.0, -13.5, 9.0))
camera = bpy.context.object
move_to(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 60
bpy.context.scene.camera = camera

for name, location, energy, color, size in (
    ("Key", (-7.0, -7.0, 11.0), 1600, (1.0, 0.74, 0.50), 5.5),
    ("Fill", (7.0, -3.0, 7.0), 1150, (0.42, 0.67, 1.0), 5.0),
    ("Rim", (0, 6.0, 9.0), 1450, (1.0, 0.40, 0.14), 4.0),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    light = bpy.data.objects.new(name, data)
    preview.objects.link(light)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.012, 0.018, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.30
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1400, 900, 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(RENDER_DIR, "distinct_oven_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Created DistinctOven.blend, DistinctOven.glb, and preview")
