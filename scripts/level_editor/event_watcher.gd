extends Node3D

## Counts something happening in a custom level and, when the count meets the
## condition, runs actions on the objects it targets. Invisible during play.

const ItemTriggers = preload("res://scripts/level_editor/item_triggers.gd")

enum Event { PLAYER_DEATHS, NPCS_FINISHED, SCALE_WEIGHT, SECONDS }
enum Comparison { AT_LEAST, AT_MOST, EXACTLY }

@export var event := Event.PLAYER_DEATHS
@export var comparison := Comparison.AT_LEAST
@export var threshold := 1.0
## Fire again every time the condition becomes true, not just the first time.
@export var repeat := false

## Set by the level: [{node, id, action, mode}] and the scale to read, if any.
var targets: Array[Dictionary] = []
var source_uid := 0
var fired := 0
var _value := 0.0
var _met := false
var _scale_weights: Dictionary = {}


func _ready() -> void:
	set_physics_process(event == Event.SECONDS)
	_check.call_deferred()


func _physics_process(delta: float) -> void:
	_value += delta
	_check()


func player_died() -> void:
	if event == Event.PLAYER_DEATHS:
		_value += 1
		_check()


func npc_finished() -> void:
	if event == Event.NPCS_FINISHED:
		_value += 1
		_check()


## Reads one scale, or every scale added together when no source is linked.
func scale_weighed(weight: float, uid: int) -> void:
	if event != Event.SCALE_WEIGHT or (source_uid != 0 and uid != source_uid):
		return
	_scale_weights[uid] = weight
	_value = 0.0
	for each in _scale_weights.values():
		_value += each
	_check()


func condition_met(value: float) -> bool:
	match comparison:
		Comparison.AT_MOST:
			return value <= threshold + 0.0001
		Comparison.EXACTLY:
			return absf(value - threshold) <= 0.0001
		_:
			return value >= threshold - 0.0001


func _check() -> void:
	var met := condition_met(_value)
	if met and not _met and (repeat or fired == 0):
		fired += 1
		for target in targets:
			ItemTriggers.run(target.node, target.id, target)
	_met = met
