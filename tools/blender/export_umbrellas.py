"""Split the supplied FBX into upright, unit-height umbrella models for Godot."""
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


MODEL_DIR = Path(__file__).resolve().parents[2] / "assets/models/props/umbrella"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(MODEL_DIR / "source/classic_umbrella.fbx"))
bpy.context.view_layer.update()

for source_name, output_name in (
    ("classic_umbrela_closed", "umbrella_closed"),
    ("classic_umbrela_opened", "umbrella_open"),
):
    obj = bpy.data.objects[source_name]
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    bottom = min(point.z for point in bounds)
    height = max(point.z for point in bounds) - bottom
    # Keep the shaft centered, including the closed umbrella's asymmetric hook.
    origin = Vector((obj.location.x, obj.location.y, bottom))
    obj.data.transform(Matrix.Scale(1.0 / height, 4)
                       @ Matrix.Translation(-origin) @ obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    obj.name = output_name
    for material in obj.data.materials:
        material.use_backface_culling = False
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / f"{output_name}.glb"),
        export_format="GLB", use_selection=True, export_yup=True,
    )
