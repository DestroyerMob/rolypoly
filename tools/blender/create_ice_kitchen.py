"""Original Ice Block kit. Blender coordinates map (x, y, z) -> Godot (x, z, -y)."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/ice_kitchen'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

def mat(name, color, metal=0, rough=.4):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    b = next(node for node in m.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    return m

cream = mat('Porcelain / oat', (.84, .80, .67), 0, .27)
teal = mat('Enamel / petrol', (.025, .18, .19), .25, .3)
brass = mat('Satin brass', (.67, .39, .12), .8, .27)
steel = mat('Brushed aluminium', (.37, .46, .48), .85, .32)
dark = mat('Graphite', (.025, .035, .038), .3, .32)
ice = mat('Frost blue', (.24, .72, .84), .15, .18)
red = mat('Terracotta', (.66, .19, .085), .05, .5)
wood = mat('Honey oak', (.42, .21, .085), 0, .48)

def kit(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

def finish(o, name, m, c, bevel=0):
    o.name = name
    for old in list(o.users_collection):
        old.objects.unlink(o)
    c.objects.link(o)
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width, mod.segments = bevel, 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def box(name, p, s, m, c, bevel=.07):
    bpy.ops.mesh.primitive_cube_add(location=p)
    o = bpy.context.object
    o.dimensions = s
    return finish(o, name, m, c, bevel)

def cylinder(name, p, radius, depth, m, c, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth, location=p, rotation=rotation)
    o = finish(bpy.context.object, name, m, c, .025)
    for f in o.data.polygons:
        f.use_smooth = True
    return o

def ring(name, p, radius, tube, m, c, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=8, major_radius=radius, minor_radius=tube, location=p, rotation=rotation)
    o = finish(bpy.context.object, name, m, c)
    for f in o.data.polygons:
        f.use_smooth = True
    return o

fan = kit('FanHousing')
box('FanFoot', (0,0,.12), (2.5,1.7,.24), teal, fan, .12)
box('FanStem', (0,.18,1.0), (.32,.32,1.65), brass, fan)
cylinder('Motor', (0,.28,2.15), .55, .65, teal, fan, (math.pi/2,0,0))
for depth in (-.28,.28):
    ring('CageOuter', (0,depth,2.15), 1.34,.065,steel,fan,(math.pi/2,0,0))
    for r in (.43,.72,1.02):
        ring('CageWire', (0,depth,2.15),r,.016,steel,fan,(math.pi/2,0,0))
for i in range(12):
    a = i*math.tau/12
    o=box('GuardSpoke', (math.sin(a)*.67,-.3,2.15+math.cos(a)*.67),(.025,.025,1.34),steel,fan,.008)
    o.rotation_euler[1]=a
cylinder('Badge', (0,-.37,2.15),.23,.08,brass,fan,(math.pi/2,0,0))
blades=kit('FanBlades')
for i in range(4):
    a=i*math.pi/2
    o=box('Blade', (math.sin(a)*.66,0,math.cos(a)*.66),(.48,.09,1.02),teal,blades,.2)
    o.rotation_euler[1]=a+.22

hot=kit('Hotplate')
box('HotplateBody',(0,0,-.15),(5.8,4.6,.3),dark,hot,.18)
box('BrassEdge',(0,0,-.26),(5.94,4.74,.12),brass,hot,.1)
for x in (-1.45,1.45):
    for y in (-1.1,1.1):
        cylinder('Burner',(x,y,.015),.85,.045,steel,hot)
        for r in (.30,.51,.73):
            ring('Coil',(x,y,.065),r,.035,red,hot)
for x in (-1.4,0,1.4):
    cylinder('Dial',(x,-2.06,.10),.17,.13,brass,hot)

cool=kit('ColdStation')
box('Tray',(0,0,-.14),(3.8,3.2,.28),teal,cool,.14)
for x in (-1.85,1.85):
    box('TrayRim',(x,0,.10),(.10,3.2,.26),brass,cool,.04)
for y in (-1.55,1.55):
    box('TrayRim',(0,y,.10),(3.8,.10,.26),brass,cool,.04)
box('ColdCeramic',(0,0,.015),(3.5,2.9,.05),ice,cool,.08)
for i in range(9):
    x=-1.4+(i%3)*.30
    y=.60+(i//3)*.24
    o=box('IceChip',(x,y,.17),(.27,.24,.26),ice,cool,.05)
    o.rotation_euler[2]=i*.37

bowl=kit('DessertBowl')
verts=[]; faces=[]; n=64
profile=[(.03,0),(1.0,0),(1.8,.65),(2.15,1.55),(2.0,1.62),(1.65,.70),(.8,.18),(.03,.18)]
for r,z in profile:
    for i in range(n):
        a=i*math.tau/n
        verts.append((r*math.cos(a),r*math.sin(a),z))
for j in range(len(profile)):
    for i in range(n):
        faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
mesh=bpy.data.meshes.new('BowlShell'); mesh.from_pydata(verts,[],faces); mesh.update()
o=bpy.data.objects.new('Bowl',mesh); bowl.objects.link(o); o.data.materials.append(cream)
for f in mesh.polygons: f.use_smooth=True
ring('GiltRim',(0,0,1.58),2.07,.065,brass,bowl)
cylinder('FrozenSorbet',(0,0,1.0),1.65,.22,ice,bowl)

freezer=kit('FreezerCabinet')
box('Back',(0,1.9,4),(8.4,.35,8),teal,freezer,.16)
for x in (-4,4):
    box('OuterSide',(x,0,4),(.4,4.2,8),teal,freezer,.16)
    box('InnerLiner',(x*.965,-.05,4),(.1,3.7,7.6),cream,freezer,.06)
for z in (.2,7.8):
    box('OuterEdge',(0,0,z),(8.2,4.2,.4),teal,freezer,.16)
for z in (1.4,3.4,5.4):
    box('Shelf',(0,0,z),(7.7,3.8,.2),ice,freezer,.08)
    box('ShelfLip',(0,-1.9,z),(7.6,.1,.20),steel,freezer,.035)
for z in (2.0,6.0):
    for x in (-2.7,-1.5,0,1.5,2.7):
        box('FrozenDessertCarton',(x,.65,z),(.75,1.15,.95),cream,freezer,.08)
        box('BlueLid',(x,.65,z+.49),(.8,1.2,.12),ice,freezer,.04)
box('OpenDoor',(6,-1.7,4),(3.7,.32,7.7),teal,freezer,.17)
box('FrostedDoorPanel',(6,-1.9,4),(3.25,.05,6.9),ice,freezer,.13)
box('DoorHandle',(7.2,-2.13,4),(.13,.18,2.8),brass,freezer,.06)

basin=kit('IceSink')
box('BasinBottom',(0,0,-2.25),(15,13,.35),steel,basin,.18)
for x in (-7.75,7.75):
    box('BasinWall',(x,0,-1.1),(.5,14,2.4),steel,basin,.17)
    box('EnamelRim',(x,0,.02),(.9,14.7,.22),cream,basin,.10)
for y in (-6.75,6.75):
    box('BasinWall',(0,y,-1.1),(15.4,.5,2.4),steel,basin,.17)
    box('EnamelRim',(0,y,.02),(15.4,.9,.22),cream,basin,.10)
cylinder('Drain',(0,0,-2.04),.7,.07,dark,basin)
ring('DrainRim',(0,0,-1.99),.73,.05,brass,basin)
curve=bpy.data.curves.new('Gooseneck faucet','CURVE')
curve.dimensions='3D'; curve.bevel_depth=.16; curve.bevel_resolution=4
spline=curve.splines.new('POLY'); spline.points.add(34)
path=[(5,6.6,0),(5,6.6,2)]
path += [(5,5.6+math.cos(i*math.pi/32),2+math.sin(i*math.pi/32)) for i in range(33)]
for point,co in zip(spline.points,path): point.co=(*co,1)
faucet=bpy.data.objects.new('Faucet',curve); basin.objects.link(faucet)
faucet.data.materials.append(steel)
for o in list(basin.objects):
    if o.type=='CURVE':
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.convert(target='MESH')

# Model files share a clean origin for direct Godot instancing.
for collection in (fan,blades,hot,cool,bowl,freezer,basin):
    bpy.ops.object.select_all(action='DESELECT')
    for o in collection.objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(collection.name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
# Arrange the source library for easy inspection after exporting the clean origins.
for idx,c in enumerate((fan,blades,hot,cool,bowl,freezer,basin)):
    for o in c.objects: o.location.x += (idx-3)*18
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/models/source/IceKitchen.blend'))
print('ICE KITCHEN KIT EXPORTED')
