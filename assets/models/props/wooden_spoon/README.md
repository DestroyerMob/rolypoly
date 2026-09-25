# Wooden spoon

Source: `wooden-spoon.zip` supplied by the user on 2026-09-25.
The OBJ and MTL come from the nested source archive. Base color, OpenGL normal,
and roughness textures come from the outer archive. No license or author
metadata was included in the supplied archive.

`scenes/props/wooden_spoon.tscn` applies a uniform 0.45 scale to the original
mesh (8.85 game units long), with the bowl facing up and extending toward -X.
The spoon is a 2 kg RigidBody3D with 33 solid convex collision sections cut
from the same OBJ. These preserve the shallow bowl cavity without using
concave collision on a dynamic body. Rebuild the prop with:

```
godot --headless --path . --script res://tools/godot/build_wooden_spoon.gd
```

In `scenes/obstacles/wooden_spoon_demo.tscn`, a 100 kg weight drops onto the
raised handle after two seconds. An unpowered HingeJoint3D anchors the spoon
at the top of the rolling pin. The bench ends just beyond the rolling pin;
the handle overhangs the edge so it can swing well below the benchtop. Weight,
spoon, and player respond to rigid-body collisions and gravity. No launch velocity,
impulse, animation, or temporary player collision exceptions are scripted.
The resulting throw arcs upward and toward the handle, out over the edge; its
trajectory varies with player position and movement, masses, and drop height.

Press E to drop immediately, or R to reload the whole demo and repeat.
The demo controller exports the drop delay. The weight's mass and drop position
are editable on HeavyWeight. There is no on-screen text. For optional motion
logging, run the scene with `-- --log-spoon-physics` after the engine arguments.
