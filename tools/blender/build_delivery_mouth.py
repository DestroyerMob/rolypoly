"""Original mouth goal asset; Blender source and glTF share identical geometry."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "models/ice_delivery"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .32
    p.inputs['Metallic'].default_value = metallic
    return m

coral = material('Glazed strawberry lips', (.63, .11, .14))
cream = material('Vanilla porcelain', (.96, .87, .67))
dark = material('Mouth interior', (.065, .014, .025))
mint = material('Mint enamel', (.075, .38, .34), .2)

def ellipsoid(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=location)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in o.data.polygons: face.use_smooth = True
    return o

# Elliptical tube: open center is real geometry, not a painted circle.
vertices, faces = [], []
for i in range(64):
    a = i * math.tau / 64
    for j in range(12):
        b = j * math.tau / 12
        vertices.append(((6.15 + .75 * math.cos(b)) * math.cos(a), .8 * math.sin(b), (5.15 + .75 * math.cos(b)) * math.sin(a)))
for i in range(64):
    for j in range(12):
        faces.append((i*12+j, ((i+1)%64)*12+j, ((i+1)%64)*12+(j+1)%12, i*12+(j+1)%12))
mesh = bpy.data.meshes.new('Open elliptical lip mesh')
mesh.from_pydata(vertices, [], faces)
lip = bpy.data.objects.new('OpenLips', mesh)
bpy.context.collection.objects.link(lip)
lip.data.materials.append(coral)
for f in mesh.polygons: f.use_smooth = True
ellipsoid('InteriorBehindOpening', (0, 2, 0), (6, .4, 5), dark)
for x in [-3, 3]:
    ellipsoid('EyeWhite', (x, .1, 6.9), (1.55, .9, 1.65), cream)
    ellipsoid('Pupil', (x, -.8, 6.8), (.56, .24, .7), mint)
for x in [-1.5, 0, 1.5]:
    ellipsoid('UpperTooth', (x, .2, 4.1), (.6, .5, .65), cream)
ellipsoid('Tongue', (0, 1.2, -3.5), (2.6, .4, .7), coral)
for x in [-7.2, 7.2]:
    ellipsoid('MintCheek', (x, 1, .3), (1.15, 1.1, 2.2), mint)

bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'moving_mouth.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'moving_mouth.glb'), export_format='GLB', export_yup=True)
