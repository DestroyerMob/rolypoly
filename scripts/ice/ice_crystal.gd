extends Area3D

@export var crystal_id := ""
var collected := false
var _time := 0.0

func _ready() -> void:
	body_entered.connect(_entered)

func _process(delta: float) -> void:
	_time += delta
	$Gem.rotation.y += delta * 0.8
	$Gem.position.y = sin(_time * 1.6) * 0.12

func _entered(body: Node3D) -> void:
	if collected or not body.has_method("request_reset"):
		return
	var level := get_tree().current_scene
	if not level or not level.has_method("collect_crystal"):
		return
	collected = true
	level.collect_crystal(crystal_id)
	hide()
	set_deferred("monitoring", false)
	set_process(false)
