@tool #So editing one in the Inspector rebuilds the wall live
class_name WallOpening
extends Resource

## One opening in an ArtWall. A Resource rather than a node, so the whole set
## lives in one array on the wall and a designer adds one with a single click.

enum Kind {
	THROUGH, ## Cuts all the way through. A window or a door.
	NICHE,   ## Cuts to Depth and adds an ArchNiche liner with its own collider.
	RECESS,  ## Cuts to Depth and stops. No liner. The CSG cut faces ARE the recess.
}

@export var kind: Kind = Kind.THROUGH:
	set(value):
		kind = value
		emit_changed()

## Clear opening, width by height.
@export var size := Vector2(60.0, 90.0):
	set(value):
		size = Vector2(maxf(value.x, 0.02), maxf(value.y, 0.02))
		emit_changed()

## Where it sits on the elevation.
## x is across, from the wall centre. y is the SILL HEIGHT above the wall base,
## which is how a draughtsman dimensions an elevation: from a datum, not from
## the middle of the thing.
@export var offset := Vector2(0.0, 90.0):
	set(value):
		offset = value
		emit_changed()

## How much of the height is arch. 0 gives a plain rectangle.
## Equal to half the width gives a semicircle.
@export var crown_rise := 0.0:
	set(value):
		crown_rise = maxf(value, 0.0)
		emit_changed()

@export_range(2, 100) var segments := 12:
	set(value):
		segments = value
		emit_changed()

## NICHE and RECESS only. How far back the cut goes. Keep it under the wall
## thickness, or you have made a THROUGH opening the slow way.
@export var depth := 20.0:
	set(value):
		depth = maxf(value, 0.01)
		emit_changed()

## NICHE only. Band around the mouth of the liner. RECESS has no liner, so
## this does nothing there.
@export var flange := 3.0:
	set(value):
		flange = maxf(value, 0.0)
		emit_changed()

## THROUGH and RECESS: this lands on the cut faces, because Godot puts the
## SUBTRACTING shape's material on the surfaces it reveals.
## NICHE: this goes on the liner instead.
@export var material: Material:
	set(value):
		material = value
		emit_changed()
