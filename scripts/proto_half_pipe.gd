@tool
class_name ProtoHalfPipe
extends ProtoPiece

## A curved ramp built from flat planks around an arc.
## The trough runs along Z, and its lowest point sits at y = 0.
##
## Height and Width determine Radius and Arc, and vice versa. Size Mode
## picks which pair you drive with. The other pair stays visible, live,
## and greyed out.
##
## PRESETS.
## [codeblock]
##   Setting        GENTLE BANK   HALF PIPE     TIGHT GUTTER
##   -------------  ------------  ------------  ------------
##   Height         1.0           3.0           0.6
##   Width          6.0           6.0           1.5
##   Length         6.0           4.0           8.0
##   Plank Length   0.8           0.6           0.3
##   Segments       0 (auto)      0 (auto)      0 (auto)
##   Thickness      0.3           0.3           0.2
## [/codeblock]
##
## Height greater than half the Width curls the pipe past 180 degrees.

const GENERATED_META := &"proto_generated"

enum SizeMode {
	BY_BOX,  ## Type Height and Width. Radius and Arc are derived.
	BY_ARC,  ## Type Radius and Arc. Height and Width are derived.
}

@export_category("Sizing")
@export var size_mode: SizeMode = SizeMode.BY_BOX:
	set(value):
		size_mode = value
		notify_property_list_changed()   # regreys the Inspector
		_sync_and_rebuild()

## How far the rim sits above the trough floor.
@export var height := 3.0:
	set(value):
		height = maxf(value, 0.05)
		_sync_and_rebuild()

## How far across the opening is, rim to rim.
@export var width := 6.0:
	set(value):
		width = maxf(value, 0.1)
		_sync_and_rebuild()

@export var radius := 3.0:
	set(value):
		radius = maxf(value, 0.05)
		_sync_and_rebuild()

@export_range(5.0, 355.0, 1.0) var arc_degrees := 180.0:
	set(value):
		arc_degrees = clampf(value, 5.0, 355.0)
		_sync_and_rebuild()

@export_category("Build")
## How far the marble travels along the pipe. Independent of the curve.
@export var length := 4.0:
	set(value):
		length = maxf(value, 0.1)
		_rebuild()

## Roughly how long each flat plank is. Only used when Segments is 0.
@export var plank_length := 0.6:
	set(value):
		plank_length = maxf(value, 0.05)
		_rebuild()

## 0 means work it out from Plank Length. Anything else is used literally.
@export_range(0, 96, 1) var segments := 0:
	set(value):
		segments = clampi(value, 0, 96)
		_rebuild()

## How thick each plank is. Thicker is harder for a fast marble to tunnel through.
@export var thickness := 0.3:
	set(value):
		thickness = maxf(value, 0.02)
		_rebuild()

var _syncing := false

## Leave empty to use the function colour from fn. Set to override by hand.
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()
		


## Greys out whichever pair is not currently driving.
func _validate_property(property: Dictionary) -> void:
	var by_box := size_mode == SizeMode.BY_BOX
	if property.name in ["height", "width"] and not by_box:
		property.usage |= PROPERTY_USAGE_READ_ONLY
	elif property.name in ["radius", "arc_degrees"] and by_box:
		property.usage |= PROPERTY_USAGE_READ_ONLY


# --- sizing ------------------------------------------------------------------

func _sync_and_rebuild() -> void:
	# The guard stops the setters below from re-entering this function.
	if _syncing:
		return
	_syncing = true

	match size_mode:
		SizeMode.BY_BOX:
			# The one circle through the trough bottom and both rim points.
			var h := maxf(height, 0.01)
			var s := maxf(width * 0.5, 0.01)
			var r := (s * s + h * h) / (2.0 * h)
			radius = r
			arc_degrees = rad_to_deg(atan2(s, r - h) * 2.0)
		SizeMode.BY_ARC:
			var r2 := maxf(radius, 0.05)
			var half := deg_to_rad(arc_degrees) * 0.5
			height = r2 * (1.0 - cos(half))
			width = 2.0 * r2 * sin(half)

	_syncing = false
	_rebuild()


func _segment_count() -> int:
	if segments > 0:
		return segments
	var arc_length := radius * deg_to_rad(arc_degrees)
	return clampi(int(round(arc_length / maxf(plank_length, 0.05))), 3, 96)


# --- build -------------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
		

	_clear_generated()

	var material: Material = surface_material if surface_material != null else MATERIALS.get(fn)
	var half_angle := deg_to_rad(arc_degrees) * 0.5
	var count := _segment_count()
	var step := (half_angle * 2.0) / float(count)

	# Chord of one segment, 2 percent oversized so neighbouring planks overlap.
	# A gap between planks is a seam the marble catches on.
	var chord := 2.0 * radius * sin(step * 0.5) * 1.02

	# The circle's centre sits directly above the trough's lowest point.
	var arc_centre := Vector3(0.0, radius, 0.0)

	var plank_size := Vector3(chord, thickness, length)
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = plank_size
	var plank_shape := BoxShape3D.new()
	plank_shape.size = plank_size

	for i in count:
		# Angle of this plank's midpoint, measured from the bottom of the arc.
		var a := -half_angle + step * (float(i) + 0.5)

		# Unit vector from the circle's centre out through the rolling surface.
		var outward := Vector3(sin(a), -cos(a), 0.0)

		# Push the plank half its thickness below the surface, so the face
		# the marble touches lies exactly on the arc.
		var surface := arc_centre + outward * radius
		var pose := Transform3D(
			Basis(Vector3(0.0, 0.0, 1.0), a),
			surface + outward * (thickness * 0.5)
		)

		var mesh_node := MeshInstance3D.new()
		mesh_node.mesh = plank_mesh
		mesh_node.material_override = material
		mesh_node.transform = pose
		mesh_node.set_meta(GENERATED_META, true)
		add_child(mesh_node)

		var collision := CollisionShape3D.new()
		collision.shape = plank_shape
		collision.transform = pose
		collision.set_meta(GENERATED_META, true)
		add_child(collision)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			remove_child(child)
			child.queue_free()
