extends Area3D
signal level_completed(player: Player)
var _finished := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _finished:
		_finished = true
		level_completed.emit(body)
