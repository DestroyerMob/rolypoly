# Electronic scale

Imported from the supplied `electronic-scale.zip` / `source/electronic-scale-obj.zip`.
The OBJ, MTL, texture, and license are preserved unchanged from the source archive.

Model attribution: Emmanuel PUYBARET / eTeks <info@eteks.com> and
Scopia Visual Interfaces Systems, s.l. (http://www.scopia.es).
Licensed under Creative Commons Attribution 3.0 Unported; see `LICENSE.TXT`.

Instance `res://scenes/obstacles/scale.tscn` in a level. The scene scales the model
by 0.2 (approximately 3 units wide, 4.4 units deep, and 0.4 units high) and places
the feet at Y = 0. The origin sits beneath the center of the weighing platform;
the display extends toward +Z. `WeighingSurface` marks the top of that platform
for future puzzle logic. The display currently uses the supplied static texture.

`Body/CollisionShape3D` contains static triangle collision derived from the OBJ,
with scale and floor offset baked into the points. If the model transform changes,
update the collision and marker to match, or transform the entire scene instance.
No weighing or puzzle behavior is implemented yet.
