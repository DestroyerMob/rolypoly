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
for future puzzle logic.

The LCD interior is covered by `Display/Screen`, leaving the original bezel and
printed button labels visible. `Display/WeightDisplay` is a blank `Label3D`,
aligned with the screen and accessible as `%WeightDisplay` from a future scene
script. Set its `text` property to supply the eventual readout, including units.
It starts empty; no values, units, calculations, or automatic updates are supplied.
The source texture is unchanged. The screen shader supplies the rounded blank
background, and the label's font, color, and pixel size can be edited in Godot.

Collision uses simple shapes: `Body/BaseCollision` is a box,
`Body/DisplayHousingCollision` is a convex wedge matching the sloped front, and
four cylinder colliders cover the feet. The metal weighing plate has its own
static body, `WeighingPlatform`, with a dedicated `MetalPlatformCollision` box.
The platform collider's top matches `WeighingSurface` at Y = 0.3956, and the base
collider stops at the underside of the metal plate. Future puzzle scripts can
reference `%WeighingPlatform` independently of the housing.

Collision dimensions and positions include the model's scale and floor offset.
If the model transform changes, update the collision and marker to match, or
transform the entire scene instance. No weighing or puzzle behavior is implemented yet.
