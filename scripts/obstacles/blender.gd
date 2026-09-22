extends Node3D

const ProduceBody := preload("res://scripts/produce_body.gd")

## Seconds per full blade rotation. Smaller values spin faster; zero stops it.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var rotation_duration := 1.0
## Length of the force cone along the blade's local positive Y axis.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m") var force_range := 5.0
## Angle from the cone's center axis to its edge.
@export_range(1.0, 80.0, 1.0, "suffix:°") var force_angle_degrees := 20.0
## Positive pushes along the blade's local Y axis; negative pulls.
@export var force_strength := 10.0
## One-shot motor sound when produce or a player reaches the blades.
@export var blend_sound: AudioStream = preload("res://assets/audio/blender_chop.wav")
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var blend_volume_db := 0.0

@onready var blade_pivot: Node3D = $Model/BladePivot
@onready var blending_sound: AudioStreamPlayer3D = $BlendingSound
var _force_area := Area3D.new()
var _force_shape := ConvexPolygonShape3D.new()
var _force_dimensions := Vector2(-1, -1)


func _ready() -> void:
	blending_sound.stream = blend_sound
	blending_sound.volume_db = blend_volume_db
	$Model/BladePivot/BladeDeathZone.body_entered.connect(_on_produce_entered)
	_update_force_shape()
	var collision := CollisionShape3D.new()
	collision.shape = _force_shape
	_force_area.collision_layer = 0
	_force_area.collision_mask = 0xFFFFFFFF
	_force_area.monitorable = false
	_force_area.add_child(collision)
	# Keep the cone centered on the blade without spinning its polygonal collider.
	blade_pivot.get_parent().add_child(_force_area)
	_force_area.transform = blade_pivot.transform


func _on_produce_entered(body: Node3D) -> void:
	if body is ProduceBody or body is Player:
		# Several bodies can hit together; let the current motor cycle finish.
		if not blending_sound.playing:
			blending_sound.pitch_scale = randf_range(0.97, 1.03)
			blending_sound.play()
	if body is ProduceBody:
		body.call_deferred("burst", $ParticleOutlet.global_transform)


func _update_force_shape() -> void:
	_force_dimensions = Vector2(force_range, force_angle_degrees)
	var length := maxf(force_range, 0.001)
	var radius := length * tan(deg_to_rad(clampf(force_angle_degrees, 1.0, 80.0)))
	var points := PackedVector3Array([Vector3.ZERO])
	for i in range(32):
		var angle := TAU * i / 32.0
		points.append(Vector3(cos(angle) * radius, length, sin(angle) * radius))
	_force_shape.points = points


func _physics_process(_delta: float) -> void:
	if force_range <= 0.0 or force_strength == 0.0:
		return
	if _force_dimensions != Vector2(force_range, force_angle_degrees):
		_update_force_shape()
	var force := blade_pivot.global_basis.y.normalized() * force_strength
	for body in _force_area.get_overlapping_bodies():
		if body is RigidBody3D:
			body.apply_central_force(force)


func _process(delta: float) -> void:
	if rotation_duration <= 0.0:
		return
	blade_pivot.rotation.y = fposmod(blade_pivot.rotation.y + TAU * delta / rotation_duration, TAU)
