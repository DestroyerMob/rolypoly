@tool
extends StaticBody3D

@export var lit := true:
	set(value):
		lit = value
		_update_flame()

var _time := 0.0


func _ready() -> void:
	_update_flame()


func _process(delta: float) -> void:
	if not lit:
		return
	_time += delta
	$Burner/FireLight.light_energy = 2.3 + sin(_time * 9.0) * 0.22 + sin(_time * 15.3) * 0.12


func _update_flame() -> void:
	if not is_inside_tree():
		return
	$Burner.visible = lit
