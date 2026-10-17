extends Area3D

func _ready() -> void:
	body_entered.connect(_entered)

func _entered(body: Node3D) -> void:
	if body is Player and body.get("reset_callback") is Callable:
		var callback: Callable = body.reset_callback
		if callback.is_valid():
			callback.call_deferred()
