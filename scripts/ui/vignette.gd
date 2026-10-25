class_name Vignette
extends CanvasLayer

@export var fade_speed := 4.0
@export var prompt_text := "Press F to launch"
@export var prompt_font_size := 48

@onready var _rect: ColorRect = $ColorRect

var _prompt := Label.new()
var _on_ring := false
var _hold_left := 0.0
var _strength := 0.0


func _ready() -> void:
	add_to_group(&"vignette")
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	#Job 1: The prompt, along the bottom of the screen, hidden until needed.
	_prompt.text = prompt_text
	_prompt.add_theme_font_size_override(&"font_size", prompt_font_size)
	_prompt.add_theme_constant_override(&"outline_size", 12)
	_prompt.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -140
	_prompt.offset_bottom = -80
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	add_child(_prompt)

	_apply()


## On the ring: vignette and prompt on. Off the ring: both off.
func set_ring(active: bool) -> void:
	_on_ring = active
	_prompt.visible = active


## Called on launch. Keeps the vignette for a while, hides the prompt.
func pulse(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)
	_prompt.visible = false


func _process(delta: float) -> void:
	_hold_left = maxf(_hold_left - delta, 0.0)
	var target := 1.0 if (_on_ring or _hold_left > 0.0) else 0.0
	_strength = move_toward(_strength, target, fade_speed * delta)
	_apply()


func _apply() -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter(&"strength", _strength)
	_rect.visible = _strength > 0.001
