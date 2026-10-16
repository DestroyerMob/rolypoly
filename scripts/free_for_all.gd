class_name FreeForAll
extends Node

## Last one standing. Drop into a level: every Player and NPC in the scene
## joins the match, and dying (death zone, fall, no health) knocks them out.

signal match_won(winner: Player)

## Anyone below this height is out, for arenas without death zones.
@export var kill_height := -30.0

var _alive: Array[Player] = []


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		player.in_match = true
		player.eliminated.connect(_on_eliminated.bind(player))
		_alive.append(player)


func _physics_process(_delta: float) -> void:
	for player in _alive.duplicate():
		if player.global_position.y < kill_height:
			player.die()


func _on_eliminated(player: Player) -> void:
	_alive.erase(player)
	if _alive.size() != 1:
		return
	var winner := _alive[0]
	print("%s wins!" % winner.name)
	winner.enter_condition(Player.Condition.WIN)
	set_physics_process(false)
	match_won.emit(winner)
