class_name Vignette
extends CanvasLayer

## How fast the vignette fades in and out. Higher is snappier.
@export var fade_speed := 4.0

@onready var _rect: ColorRect = $ColorRect

var _on_ring := false
var _hold_left := 0.0
var _strength := 0.0


func _ready() -> void:
	add_to_group(&"vignette")
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


## Held on for as long as the player stands on a launch ring.
func set_ring(active: bool) -> void:
	_on_ring = active


## Shows the vignette for at least this many seconds. A second pulse extends
## it rather than cutting the first one short.
func pulse(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)


func _process(delta: float) -> void:
	_hold_left = maxf(_hold_left - delta, 0.0)
	#Job 1: Either reason is enough to show it.
	var target := 1.0 if (_on_ring or _hold_left > 0.0) else 0.0
	_strength = move_toward(_strength, target, fade_speed * delta)
	_apply()


func _apply() -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter(&"strength", _strength)
	#Job 2: Hide it entirely when clear, so it costs nothing most of the time.
	_rect.visible = _strength > 0.001
