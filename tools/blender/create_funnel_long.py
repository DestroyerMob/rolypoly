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


def lathed_shell(profile, mat, collection, root):
    segments = 48
    vertices = []
    for radius, z in profile:
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append((radius * math.cos(angle), radius * math.sin(angle), z))
    faces = []
    for profile_index in range(len(profile)):
        next_profile = (profile_index + 1) % len(profile)
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append((profile_index * segments + segment, profile_index * segments + nxt,
                          next_profile * segments + nxt, next_profile * segments + segment))
    mesh = bpy.data.meshes.new("FunnelLong_Body_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    body = bpy.data.objects.new("FunnelLong_Body", mesh)
    collection.objects.link(body)
    body.parent = root
    body.data.materials.append(mat)
    for polygon in body.data.polygons:
        polygon.use_smooth = True


def ring(name, z, radius, thickness, mat, collection, root):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=40, minor_segments=10, major_radius=radius, minor_radius=thickness,
        location=(0, 0, z),
    )
    obj = bpy.context.object
    obj.name = name
    move_to(obj, collection)
    obj.parent = root
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = "METRIC"

body_mat = make_material("FunnelLong_Enamel", (0.16, 0.62, 0.68), 0.28, 0.26)
rim_mat = make_material("FunnelLong_Rim", (0.92, 0.76, 0.28), 0.58, 0.22)
dark_mat = make_material("FunnelLong_TubeBand", (0.035, 0.13, 0.16), 0.48, 0.30)

collection = bpy.data.collections.new("FunnelLong")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("FunnelLong_Root", None)
collection.objects.link(root)

# Outer wall goes from wide mouth through the cone into a long tube, then the
# profile returns up the inside. The top and bottom openings remain real holes.
profile = [
    (2.35, 2.00), (2.35, 1.82), (0.95, 0.05), (0.95, -2.25),
    (0.72, -2.25), (0.72, 0.05), (2.10, 1.82), (2.10, 2.00),
]
lathed_shell(profile, body_mat, collection, root)
ring("FunnelLong_MouthRim", 1.98, 2.225, 0.13, rim_mat, collection, root)
ring("FunnelLong_TubeEnd", -2.20, 0.835, 0.08, dark_mat, collection, root)
ring("FunnelLong_TubeGuide", -1.42, 0.955, 0.035, rim_mat, collection, root)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "FunnelLong.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=os.path.join(MODEL_DIR, "FunnelLong.glb"),
    export_format="GLB", use_selection=True, export_yup=True,
)

preview = bpy.data.collections.new("Preview_Only")
bpy.context.scene.collection.children.link(preview)
floor_mat = make_material("Preview_Floor", (0.055, 0.07, 0.09), roughness=0.82)
bpy.ops.mesh.primitive_cube_add(location=(0, 0, -2.38))
floor = bpy.context.object
floor.dimensions = (7.5, 7.5, 0.16)
move_to(floor, preview)
floor.data.materials.append(floor_mat)
bpy.context.view_layer.objects.active = floor
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

target = Vector((0, 0, 0))
bpy.ops.object.camera_add(location=(7.2, -9.8, 5.2))
camera = bpy.context.object
move_to(camera, preview)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58
bpy.context.scene.camera = camera

for name, location, energy, color, size in (
    ("Key", (-4, -4, 7), 1250, (1.0, 0.76, 0.52), 4.5),
    ("Fill", (5, -1, 3), 850, (0.42, 0.72, 1.0), 4),
    ("Rim", (0, 4, 4.5), 1000, (1.0, 0.30, 0.12), 3.8),
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
scene.render.filepath = os.path.join(RENDER_DIR, "funnel_long_preview.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Created FunnelLong.blend, FunnelLong.glb, and preview")
