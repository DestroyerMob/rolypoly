@tool
class_name StarIcon
extends Control

## A faceted five-point star. Lit stars are gold, unlit stars are a flat grey.

@export var lit := true:
	set(value):
		lit = value
		queue_redraw()


func _ready() -> void:
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var centre := size * 0.5 + Vector2(0, radius * 0.05)
	var face_a := Color(1.0, 0.86, 0.25) if lit else Color(0.8, 0.76, 0.69)
	var face_b := Color(1.0, 0.74, 0.12) if lit else Color(0.72, 0.68, 0.61)
	var edge := Color(0.78, 0.43, 0.1) if lit else Color(0.58, 0.53, 0.46)

	var outline := PackedVector2Array()
	for i in 10:
		var point_radius := radius * (0.92 if i % 2 == 0 else 0.46)
		var angle := -PI * 0.5 + i * TAU / 10.0
		outline.append(centre + Vector2(cos(angle), sin(angle)) * point_radius)
	for i in 10:
		draw_colored_polygon(PackedVector2Array([centre, outline[i], outline[(i + 1) % 10]]),
				face_a if i % 2 == 0 else face_b)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, edge, radius * 0.1, true)
