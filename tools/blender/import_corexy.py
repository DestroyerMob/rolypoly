"""Convert the supplied CoreXY STL to a grounded, ten-unit-wide Godot asset.

Run with Blender --background --factory-startup --python tools/blender/import_corexy.py.
"""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "assets/models/props/corexy"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.stl_import(filepath=str(ASSET / "source/CoreXY.stl"))
model = bpy.context.object

minimum = Vector(tuple(min(v.co[axis] for v in model.data.vertices) for axis in range(3)))
maximum = Vector(tuple(max(v.co[axis] for v in model.data.vertices) for axis in range(3)))
origin = Vector(((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, minimum.z))
scale = 10.0 / max(maximum.x - minimum.x, maximum.y - minimum.y)
for vertex in model.data.vertices:
    vertex.co = (vertex.co - origin) * scale

mesh = bmesh.new()
mesh.from_mesh(model.data)
bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
mesh.to_mesh(model.data)
mesh.free()

model.name = "CoreXY-col"
model.data.name = "CoreXYMesh"
material = bpy.data.materials.new("CoreXYSilver")
material.diffuse_color = (0.48, 0.55, 0.61, 1.0)
material.use_nodes = True
surface = material.node_tree.nodes.get("Principled BSDF")
surface.inputs["Base Color"].default_value = material.diffuse_color
surface.inputs["Metallic"].default_value = 0.45
surface.inputs["Roughness"].default_value = 0.38
model.data.materials.clear()
model.data.materials.append(material)
bpy.ops.export_scene.gltf(
    filepath=str(ASSET / "corexy.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)
print(f"Exported CoreXY: {len(model.data.polygons)} triangles; dimensions {tuple(model.dimensions)}")

mesh = bmesh.new()
mesh.from_mesh(model.data)
unseen = set(mesh.verts)
groups = {"frame": [], "gantry": [], "carriage": []}
while unseen:
    seed = unseen.pop()
    pending = [seed]
    component = {seed}
    while pending:
        vertex = pending.pop()
        for edge in vertex.link_edges:
            other = edge.other_vert(vertex)
            if other in unseen:
                unseen.remove(other)
                pending.append(other)
                component.add(other)
    raw = [vertex.co / scale + origin for vertex in component]
    low = tuple(min(v[axis] for v in raw) for axis in range(3))
    high = tuple(max(v[axis] for v in raw) for axis in range(3))
    if low[0] > -60 and high[0] < 20 and low[1] > 20 and high[1] < 140:
        group = "carriage"
    elif low[1] > 70 and high[1] < 140:
        if high[0] - low[0] > 350 and high[1] - low[1] < 12:
            continue
        group = "gantry"
    else:
        group = "frame"
    groups[group].append(component)

gantry_y = (104.22 - origin.y) * scale
carriage_x = (-22.51 - origin.x) * scale
for name, components in groups.items():
    part_origin = Vector((carriage_x if name == "carriage" else 0, gantry_y if name != "frame" else 0, 0))
    vertices = []
    faces = []
    for component in components:
        indices = {}
        for vertex in sorted(component, key=lambda v: v.index):
            indices[vertex] = len(vertices)
            vertices.append(tuple(vertex.co - part_origin))
        component_faces = {face for vertex in component for face in vertex.link_faces}
        for face in sorted(component_faces, key=lambda f: f.index):
            faces.append(tuple(indices[vertex] for vertex in face.verts))
    part_mesh = bpy.data.meshes.new(f"CoreXY{name.title()}Mesh")
    part_mesh.from_pydata(vertices, [], faces)
    part_mesh.materials.append(material)
    part = bpy.data.objects.new(f"CoreXY{name.title()}" + ("-col" if name == "frame" else ""), part_mesh)
    bpy.context.collection.objects.link(part)
    bpy.ops.object.select_all(action="DESELECT")
    part.select_set(True)
    bpy.context.view_layer.objects.active = part
    bpy.ops.export_scene.gltf(filepath=str(ASSET / f"corexy_{name}.glb"), export_format="GLB", use_selection=True, export_yup=True)
    print(f"{name}: {len(components)} parts, {len(faces)} triangles")
mesh.free()
print(f"Rest position in Godot: carriage X={carriage_x:.6f}; gantry/carriage Z={-gantry_y:.6f}")
