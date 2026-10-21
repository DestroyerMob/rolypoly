extends Area3D

## Fan gusts punish waiting on the hot shortcut. Warning is readable before force.
@export var period := 6.0
@export var calm_seconds := 3.0
@export var warning_seconds := .8
@export var strength := 24.0
var elapsed := 0.0
var blowing := false

func _physics_process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, period)
	blowing = elapsed >= calm_seconds + warning_seconds
	var warning := elapsed >= calm_seconds and not blowing
	var blades := get_parent().get_node_or_null("SpinningBlades")
	if blades:
		blades.speed = move_toward(blades.speed, 12.0 if blowing else (4.0 if warning else 0.0), delta * 24.0)
	for child in get_parent().get_children():
		if child.name.begins_with("AirRibbon"):
			child.visible = blowing or warning
	var sign := get_parent().get_node_or_null("WindSign") as Label3D
	if sign:
		sign.text = "GUST! KEEP OFF THE HOT TRAY" if blowing else ("FAN STARTING..." if warning else "FAN RESTING • CROSS NOW")
		sign.modulate = Color("ffb393") if blowing or warning else Color("b6f4e3")
	if blowing:
		for body in get_overlapping_bodies():
			if body is Player and not body.freeze:
				# The ice shell catches more wind than a bare scoop.
				body.apply_central_force(global_basis.z.normalized() * strength * (1.0 if is_instance_valid(body.gadget) else .55))

func safe_seconds() -> float:
	return maxf(0, calm_seconds + warning_seconds - elapsed) if not blowing else 0.0
