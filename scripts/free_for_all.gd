class_name FreeForAll
extends Node

## Last one standing. Drop into a level: every Player and NPC in the scene
## joins the match, and dying (death zone, fall, no health) knocks them out.

## `by` is whoever hurt them last, if that was recent enough to count.
signal knocked_out(player: Player, by: Player)
signal damaged(player: Player, amount: int, by: Player)
signal match_won(winner: Player)

## Anyone below this height is out, for arenas without death zones.
@export var kill_height := -30.0
## A fall still counts as a knock-out for whoever hit them within this long.
@export var credit_seconds := 6.0
## NPCs get a health bar overhead.
@export var show_health_bars := true

## Everyone who joined, including those since knocked out.
var entrants := 0
## Knock-outs credited to each player.
var knockouts := {}
## Finishing place of everyone knocked out, and of the winner: 1 is first.
var places := {}
var _alive: Array[Player] = []


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		player.in_match = true
		player.eliminated.connect(_on_eliminated.bind(player))
		player.damaged.connect(func(amount: int, source: Player): damaged.emit(player, amount, source))
		if show_health_bars and player is NPC:
			player.add_child(HealthBar.new(player))
		knockouts[player] = 0
		_alive.append(player)
	entrants = _alive.size()


func remaining() -> int:
	return _alive.size()


func _physics_process(_delta: float) -> void:
	for player in _alive.duplicate():
		if player.global_position.y < kill_height:
			player.die()


func _on_eliminated(player: Player) -> void:
	_alive.erase(player)
	places[player] = _alive.size() + 1
	var by := player.last_attacker
	if not is_instance_valid(by) or Time.get_ticks_msec() - player.last_hit_msec > credit_seconds * 1000.0:
		by = null
	if by != null:
		knockouts[by] = knockouts.get(by, 0) + 1
	knocked_out.emit(player, by)
	if _alive.size() != 1:
		return
	var winner := _alive[0]
	places[winner] = 1
	print("%s wins!" % winner.name)
	winner.enter_condition(Player.Condition.WIN)
	set_physics_process(false)
	match_won.emit(winner)
