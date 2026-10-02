"""Remove the stick and export a centered lollipop player model.

Run with Blender --background --factory-startup --python tools/blender/import_lollypop.py.
"""

from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "models/candy/lollypop"
DIAMETER = 2.2

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ASSET / "source/lollypop.glb"))
model = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
mesh = bmesh.new()
mesh.from_mesh(model.data)
unseen = set(mesh.verts)
components = []
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
                component.add(other)
                pending.append(other)
    components.append(component)

# The round candy is the broad component; the narrow cylinder is the stick.
candy = max(components, key=lambda part: max(v.co.x for v in part) - min(v.co.x for v in part))
discarded = [vertex for component in components if component is not candy for vertex in component]
if not discarded:
    raise RuntimeError("No separate stick component found in the source model.")
bmesh.ops.delete(mesh, geom=discarded, context="VERTS")
minimum = Vector(tuple(min(v.co[axis] for v in mesh.verts) for axis in range(3)))
maximum = Vector(tuple(max(v.co[axis] for v in mesh.verts) for axis in range(3)))
center = (minimum + maximum) / 2.0
scale = DIAMETER / max(maximum - minimum)
for vertex in mesh.verts:
    vertex.co = (vertex.co - center) * scale
mesh.to_mesh(model.data)
mesh.free()
model.name = "Lollypop"
model.data.name = "LollypopCandyMesh"
bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.context.view_layer.objects.active = model
bpy.ops.export_scene.gltf(
    filepath=str(ASSET / "lollypop.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
)
print(f"Removed {len(discarded)} stick vertices; centered candy diameter: {DIAMETER}")
