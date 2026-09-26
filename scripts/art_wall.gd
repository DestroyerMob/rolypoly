@tool #Designer sizes the wall and its openings, everything else is automatic
class_name ArtWall
extends CSGCombiner3D #Root of its own CSG tree, so Use Collision works here

## A wall with holes in it. Builds the union box, one exact arch-shaped
## subtraction per opening, and an ArchNiche liner for any opening marked NICHE.
## Origin is at the BASE CENTRE of the wall, so Position Y is floor level and
## every opening's sill height is measured from it.
## The room-facing side is +Z unless you tick Flip Cuts.

const GENERATED := &"art_wall_generated" #Stamp node

@export var size := Vector3(600.0, 250.0, 35.0):
	set(value):
		size = Vector3(maxf(value.x, 0.02), maxf(value.y, 0.02), maxf(value.z, 0.02))
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Click + and choose New WallOpening for each hole.
@export var openings: Array[WallOpening] = []:
	set(value):
		#Job 1: Drop the old connections first, as the resources in the old
		#       array may still exist elsewhere and would keep firing.
		_unwatch()
		openings = value
		_watch()
		_rebuild()

## Godot extrudes a CSGPolygon3D one way along Z, and which way is not worth
## memorising. If your cuts miss the wall, or the niches appear on the far
## side, tick this once and forget it.
@export var flip_cuts := false:
	set(value):
		flip_cuts = value
		_rebuild()


func _ready() -> void:
	_watch()
	_rebuild()


## The array setter only fires when the ARRAY is replaced. Editing a field
## inside one opening does not touch the array, so the wall would not notice.
## Connecting each resource's changed signal is what closes that gap.
func _watch() -> void:
	for op in openings:
		if op != null and not op.changed.is_connected(_rebuild):
			op.changed.connect(_rebuild)


func _unwatch() -> void:
	for op in openings:
		if op != null and op.changed.is_connected(_rebuild):
			op.changed.disconnect(_rebuild)


func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return
	#Job 2: Throw the previous build away, as three kinds of child is more
	#       bookkeeping than re-adopting them is worth.
	_clear_generated()

	var t := size.z

	#Job 3: The wall itself, sitting on the node rather than centred on it.
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.set_meta(GENERATED, true)
	wall.operation = CSGShape3D.OPERATION_UNION
	wall.size = size
	wall.position = Vector3(0.0, size.y * 0.5, 0.0)
	wall.material = material
	add_child(wall)

	for i in openings.size():
		var op: WallOpening = openings[i]
		if op == null:
			continue

		#Job 4: The cut. A polygon, not a box plus a cylinder, so the hole is
		#       the exact arch the liner was built from.
		var poly := CSGPolygon3D.new()
		poly.name = "Cut_%d" % i
		poly.set_meta(GENERATED, true)
		poly.operation = CSGShape3D.OPERATION_SUBTRACTION
		poly.mode = CSGPolygon3D.MODE_DEPTH
		poly.polygon = ArchNiche.profile(op.size.x, op.size.y, op.crown_rise, op.segments)
		poly.material = op.material

		#Job 5: Work out where the extrusion has to start so it covers the
		#       right slab of wall. THROUGH overshoots both faces by 2.
		#       NICHE and RECESS start at the room face and stop at Depth.
		var cut_depth: float
		var z0: float
		if op.kind == WallOpening.Kind.THROUGH:
			cut_depth = t + 4.0
			z0 = (t * 0.5 + 2.0) if flip_cuts else (-t * 0.5 - 2.0)
		else:
			cut_depth = op.depth + 0.5
			z0 = (t * 0.5 + 0.5) if flip_cuts else (t * 0.5 - op.depth)
			
		#Job 5b: Apply the numbers and put the cut in the tree. Nothing above
		#        this line has any effect until the node joins the scene.
		poly.depth = cut_depth
		poly.position = Vector3(op.offset.x, op.offset.y, z0)
		add_child(poly)
		
		#Job 6: Nothing more to do for a THROUGH opening, as the CSG cut faces
		#       already carry the material.
		if op.kind != WallOpening.Kind.NICHE:
			continue

		#Job 7: The liner. Its own collision, so the shelves you add inside it
		#       have something to sit on.
		var niche := ArchNiche.new()
		niche.name = "Niche_%d" % i
		niche.set_meta(GENERATED, true)
		niche.size = op.size
		niche.crown_rise = op.crown_rise
		niche.depth = op.depth
		niche.segments = op.segments
		niche.flange = op.flange
		niche.material = op.material
		niche.collision_enabled = true
		#Job 8: Sit it in the room face with its back running into the wall.
		#       Flipped, it faces the other way, which is a 180 on Y.
		if flip_cuts:
			niche.position = Vector3(op.offset.x, op.offset.y, -t * 0.5)
			niche.rotation = Vector3(0.0, PI, 0.0)
		else:
			niche.position = Vector3(op.offset.x, op.offset.y, t * 0.5)
		add_child(niche)


func _clear_generated() -> void:
	#Job 1: Detach first, as queue_free defers to the end of the frame and the
	#       old children would still be found by the next loop until then.
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()
