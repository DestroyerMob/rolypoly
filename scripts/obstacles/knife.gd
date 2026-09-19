extends Node3D

@export var swing_speed := 1.0
@onready var knife: Node3D = $model

#Need the chop angle degree, time it takes to chop down, time it takes to lift up, the pause after it chops, the pause after it reaches the back swing
@export_range(-360.0,360.0,1.0) var chop_angle_degrees := -90.0
@export_range(0.05,2.0,0.01) var chop_time := 1.5
@export_range(0.1,3.0,0.05) var lift_time := 1.5
@export_range(0.0,3.0,0.05) var pause_down := 0.2
@export_range(0.0,3.0,0.05) var pause_up := 0.5

var _knife_tween: Tween

func _ready():
	_chop()
func _chop() -> void:
	#destroy old tween before making new one
	if _knife_tween != null and _knife_tween.is_running():
		_knife_tween.kill()
	_knife_tween = create_tween()
	
	_knife_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	#todo loop
	_knife_tween.set_loops()
	
	#Knife Down
	_knife_tween.tween_property(knife, "rotation_degrees:z",chop_angle_degrees,chop_time)
	#Knife pause
	_knife_tween.tween_interval(pause_down)
	#Knife lift
	_knife_tween.tween_property(knife,"rotation_degrees:z",0.0,lift_time)
	#knife pause up
	_knife_tween.tween_interval(pause_up)
		
