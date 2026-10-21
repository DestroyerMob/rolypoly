class_name HealthBar
extends Node3D

## A small bar floating over a Player that always faces the camera. It sits
## outside the rolling body's rotation, so it stays upright.

const WIDTH := 3.0
const HEIGHT := 0.35
## How far above the character's centre the bar floats.
const LIFT := 2.8

var player: Player
var _fill_mesh := QuadMesh.new()
var _fill_material := StandardMaterial3D.new()
var _shown := -1


func _init(target: Player) -> void:
	player = target
	name = "HealthBar"
	top_level = true


func _ready() -> void:
	add_child(_quad(Vector2(WIDTH + 0.16, HEIGHT + 0.16), Color(0.08, 0.06, 0.06, 0.85), 0.0, QuadMesh.new()))
	add_child(_quad(Vector2(WIDTH, HEIGHT), Color.WHITE, 0.02, _fill_mesh, _fill_material))
	_update_fill()


func _process(_delta: float) -> void:
	global_position = player.global_position + Vector3.UP * LIFT
	if player.health != _shown:
		_update_fill()


func _update_fill() -> void:
	_shown = player.health
	var ratio := clampf(float(player.health) / maxf(player.get_max_health(), 1.0), 0.0, 1.0)
	_fill_mesh.size = Vector2(maxf(WIDTH * ratio, 0.001), HEIGHT)
	_fill_mesh.center_offset = Vector3(-WIDTH * (1.0 - ratio) * 0.5, 0.0, 0.02)
	_fill_material.albedo_color = Color(0.9, 0.2, 0.15).lerp(Color(1, 0.8, 0.2), clampf(ratio * 2.0, 0, 1)).lerp(Color(0.35, 0.9, 0.4), clampf(ratio * 2.0 - 1.0, 0, 1))


func _quad(size: Vector2, colour: Color, depth: float, mesh: QuadMesh, material := StandardMaterial3D.new()) -> MeshInstance3D:
	mesh.size = size
	mesh.center_offset = Vector3(0, 0, depth)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
