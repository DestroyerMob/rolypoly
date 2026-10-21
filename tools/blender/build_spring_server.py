"""Mint-enamel spring server, with matching editable Blender and glTF assets."""
from pathlib import Path
import math
import bpy

OUT = Path(__file__).resolve().parents[2] / 'models/ice_delivery'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = .3
    return m

mint = material('Mint enamel', (.11, .43, .37), .3)
gold = material('Brushed brass', (.68, .44, .18), .7)
cream = material('Porcelain plate', (.92, .85, .68))

def cylinder(name, radius, depth, z, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=radius, depth=depth, location=(0, 0, z))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    bevel = o.modifiers.new('Soft rounded edges', 'BEVEL')
    bevel.width = .12
    bevel.segments = 3
    o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o

cylinder('Enamel base', 4.8, .6, -2.7, mint)
cylinder('Inner guide post', .5, 2.3, -1.35, mint)
cylinder('Porcelain serving plate', 4.7, .3, -.15, cream)
# The top of the plate is z=0 (Godot y=0); model is mounted below track height.
bpy.ops.mesh.primitive_torus_add(major_radius=4.55, minor_radius=.12, location=(0, 0, .05))
bpy.context.object.name = 'Brass plate rim'
bpy.context.object.data.materials.append(gold)
curve = bpy.data.curves.new('Coiled spring', 'CURVE')
curve.dimensions = '3D'
curve.bevel_depth = .16
curve.bevel_resolution = 4
spline = curve.splines.new('POLY')
spline.points.add(240)
for i, p in enumerate(spline.points):
    t = i / 240
    a = t * math.tau * 4.5
    p.co = (2.4 * math.cos(a), 2.4 * math.sin(a), -2.4 + 2.1 * t, 1)
coil = bpy.data.objects.new('Visible brass spring', curve)
bpy.context.collection.objects.link(coil)
coil.data.materials.append(gold)
for x in [-3.4, 3.4]:
    for y in [-3.4, 3.4]:
        bolt = cylinder('Base bolt', .19, .15, -2.33, gold)
        bolt.location.x, bolt.location.y = x, y
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'spring_server.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'spring_server.glb'), export_format='GLB', export_yup=True)
