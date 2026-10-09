extends Node3D

@export_enum("Spin", "Gate", "Bob") var mode := 0
@export var speed := 1.0
@export var axis := Vector3.UP
@export var travel := 3.0
var elapsed := 0.0
var rest := Vector3.ZERO

func _ready() -> void:
	rest = position

func _physics_process(delta: float) -> void:
	elapsed += delta
	if mode == 0:
		rotate_object_local(axis.normalized(), speed * delta)
	elif mode == 1:
		var opening := smoothstep(-0.35, 0.35, sin(elapsed * speed))
		position = rest + axis * travel * opening
	else:
		position = rest + axis * sin(elapsed * speed) * travel
