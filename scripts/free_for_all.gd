class_name FreeForAll
extends Node


signal knocked_out(player: Player, by: Player)
signal damaged(player: Player, amount: int, by: Player)
signal match_won(winner: Player)

@export var kill_height := -30.0
@export var credit_seconds := 6.0
@export var show_health_bars := true

var entrants := 0
var knockouts := {}
var places := {}
var _alive: Array[Player] = []
var _finish_pending := false
var _finished := false


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
	if not player in _alive:
		return
	_alive.erase(player)
	places[player] = _alive.size() + 1
	var by := player.last_attacker
	if not is_instance_valid(by) or Time.get_ticks_msec() - player.last_hit_msec > credit_seconds * 1000.0:
		by = null
	if by != null:
		knockouts[by] = knockouts.get(by, 0) + 1
	knocked_out.emit(player, by)
	if not _finish_pending:
		_finish_pending = true
		_finish_match.call_deferred()


func _finish_match() -> void:
	_finish_pending = false
	if _finished or _alive.size() > 1:
		return
	_finished = true
	set_physics_process(false)
	if _alive.is_empty():
		return
	var winner := _alive[0]
	places[winner] = 1
	print("%s wins!" % winner.name)
	winner.enter_condition(Player.Condition.WIN)
	match_won.emit(winner)
