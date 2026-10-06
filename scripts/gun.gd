class_name Gun
extends Node3D
## Hitscan gun gadget. Fires from the camera crosshair while equipped, so the
## muzzle only decides where the tracer is drawn from.

signal fired
## Emitted once per pellet that hits something.
signal hit(collider: Object, position: Vector3, normal: Vector3, direction: Vector3)

@export_group("Firing")
## Seconds between shots.
@export var fire_interval := 0.1
## Hold to keep firing; otherwise one shot per click.
@export var automatic := false
@export var pellets := 1
## Half-angle of the cone pellets are scattered in.
@export_range(0.0, 45.0, 0.1) var spread_degrees := 0.0
@export var max_range := 300.0
## Impulse each pellet applies to a rigid body it hits.
@export var impulse := 10.0

@export_group("Effects")
@export var tracer_color := Color(1.0, 0.85, 0.45)
@export var tracer_width := 0.3
@export var tracer_seconds := 0.1
@export var impact_radius := 0.8
@export var flash_energy := 6.0
## How far the model slides back when firing.
@export var kick_distance := 0.2
@export var kick_degrees := 4.0

@onready var _model: Node3D = $Model
@onready var _muzzle: Marker3D = $Muzzle

var _player: Player
var _mount: GadgetMount
var _cooldown := 0.0
var _buffered := 0.0
var _flash: OmniLight3D
var _tracer_material: StandardMaterial3D
var _kick_tween: Tween


func _ready() -> void:
	_flash = OmniLight3D.new()
	_flash.light_color = tracer_color
	_flash.light_energy = 0.0
	_flash.omni_range = 16.0
	_flash.shadow_enabled = false
	_muzzle.add_child(_flash)
	_tracer_material = StandardMaterial3D.new()
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = tracer_color
	_tracer_material.emission_enabled = true
	_tracer_material.emission = tracer_color
	_tracer_material.emission_energy_multiplier = 3.0


# Only the gadget mount calls this, so a pickup's display copy never fires.
func update_attachment(player: Player, mount: GadgetMount) -> void:
	_player = player
	_mount = mount


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_buffered = maxf(_buffered - delta, 0.0)
	if not is_instance_valid(_player) or _player.is_squished:
		return
	if Input.is_action_just_pressed("activate_equipment"):
		_buffered = 0.15
	var wants_fire := Input.is_action_pressed("activate_equipment") if automatic else _buffered > 0.0
	if wants_fire and _cooldown <= 0.0:
		_buffered = 0.0
		_shoot()


func _shoot() -> void:
	var camera := _mount.camera if is_instance_valid(_mount) else null
	if camera == null:
		return
	_cooldown = fire_interval
	var center := get_viewport().get_visible_rect().size * 0.5
	var aim := camera.project_ray_normal(center)
	# Start at the player's depth so scenery between the camera and player is ignored.
	var origin := camera.project_ray_origin(center)
	origin += aim * origin.distance_to(_player.global_position)
	var space := get_world_3d().direct_space_state
	for i in pellets:
		var direction := _scatter(aim)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range)
		query.exclude = [_player.get_rid()]
		var result := space.intersect_ray(query)
		var end: Vector3 = origin + direction * max_range
		if not result.is_empty():
			end = result.position
			_on_hit(result, direction)
		_spawn_tracer(_muzzle.global_position, end)
	_play_kick()
	fired.emit()


func _scatter(aim: Vector3) -> Vector3:
	if spread_degrees <= 0.0:
		return aim
	var reference := Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := aim.cross(reference).normalized()
	var up := right.cross(aim)
	var angle := randf() * TAU
	var radius := tan(deg_to_rad(spread_degrees)) * sqrt(randf())
	return (aim + right * cos(angle) * radius + up * sin(angle) * radius).normalized()


func _on_hit(result: Dictionary, direction: Vector3) -> void:
	var body := result.collider as RigidBody3D
	if body != null:
		body.apply_impulse(direction * impulse, result.position - body.global_position)
	_spawn_impact(result.position)
	hit.emit(result.collider, result.position, result.normal, direction)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var y := (to - from) / length
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
	var mesh := CylinderMesh.new()
	mesh.top_radius = tracer_width * 0.5
	mesh.bottom_radius = tracer_width * 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = _tracer_material
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child(tracer)
	tracer.global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (from + to) * 0.5)
	var tween := tracer.create_tween()
	tween.tween_property(tracer, "transparency", 1.0, tracer_seconds)
	tween.tween_callback(tracer.queue_free)


func _spawn_impact(position: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = impact_radius
	mesh.height = impact_radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _tracer_material
	var spark := MeshInstance3D.new()
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child(spark)
	spark.global_position = position
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ZERO, 0.12)
	tween.tween_callback(spark.queue_free)


func _play_kick() -> void:
	_flash.light_energy = flash_energy
	if _kick_tween != null:
		_kick_tween.kill()
	_model.position = Vector3(0, 0, kick_distance)
	_model.rotation_degrees = Vector3(kick_degrees, 0, 0)
	_kick_tween = create_tween().set_parallel()
	_kick_tween.tween_property(_flash, "light_energy", 0.0, 0.06)
	_kick_tween.tween_property(_model, "position", Vector3.ZERO, minf(fire_interval, 0.25))
	_kick_tween.tween_property(_model, "rotation_degrees", Vector3.ZERO, minf(fire_interval, 0.25))
