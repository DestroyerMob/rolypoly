extends Area3D

## 0 heat, 1 replenish + checkpoint, 2 fan, 3 steam lift, 4 goal.
@export_enum("Heat", "Cold station", "Wind", "Steam", "Goal", "Water rescue") var kind := 0
@export var strength := 22.0
@export var direction := Vector3.RIGHT
@export var pulse_period := 0.0
@export var checkpoint_offset := Vector3(0, 1.0, 0)
var _time := 0.0

func _ready() -> void:
	body_entered.connect(_entered)
	body_exited.connect(_exited)

func _physics_process(delta: float) -> void:
	_time += delta

func gust_factor() -> float:
	if pulse_period <= 0.0:
		return 1.0
	return 1.0 if fposmod(_time, pulse_period) < pulse_period * 0.50 else 0.08

func _entered(body: Node3D) -> void:
	if not body.has_method("request_reset"):
		return
	if body._pending_reset:
		return
	if kind == 5:
		body.request_reset("SPLASH! BACK TO THE SINK EDGE")
		return
	if kind == 4:
		body.complete()
		return
	if not body.zones.has(self):
		body.zones.append(self)
	if kind == 1:
		body.checkpoint = global_position + checkpoint_offset

func _exited(body: Node3D) -> void:
	if body.has_method("request_reset"):
		body.zones.erase(self)
