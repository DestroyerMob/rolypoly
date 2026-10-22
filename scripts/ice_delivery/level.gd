extends Node3D

const ICE := preload("res://scenes/obstacles/ice_block_shell.tscn")
@export var shell_lifetime := 17.0
@export var refill_seconds := 4.0
@onready var player = $PlayerRig/Player
@onready var mount: GadgetMount = $GadgetMount
@onready var mouth = $Course/MovingMouth
@onready var rows: VBoxContainer = $PlayerRig/HUD/Margin/Panel/Rows
var checkpoint := Vector3(0, -0.5, -18)
var active_station := "01 / DINING TABLE"
var result := false
var equip_pending := false
var is_refilling := false

func _ready() -> void:
	configure_environment($IrohKitchen)
	$PlayerRig.set_process_unhandled_input(false)
	player.reset_callback = reset_checkpoint
	player.melted.connect(finish.bind(false))
	mouth.player = player
	mouth.swallowed.connect(finish.bind(true))
	$Course/SpringServer.player = player
	$Course/SpringServer.mouth = mouth
	for station in $Refills.get_children():
		station.gadget_mount = mount
		station.get_node("UpgradeNode").position = Vector3(-4, 1.5, 0)
		station.get_node("PickupArea").body_entered.connect(reached_station.bind(station))
	refill()
	update_hud()

func configure_environment(node: Node) -> void:
	# Iroh's room is scaled to 1:4 for this route. Local light output must
	# follow squared distance, otherwise his 350–3000 energy lamps blow out.
	if node is OmniLight3D or node is SpotLight3D:
		node.light_energy *= .0625
		node.light_size *= .25
		node.shadow_normal_bias *= .25
		if node is OmniLight3D:
			node.omni_range *= .25
		else:
			node.spot_range *= .25
	if node is DistinctOven:
		# This oven is scenery for the serving platform. Its close-range door
		# prompt otherwise fills the camera and competes with E on the server.
		node.set_process_unhandled_input(false)
		node.interaction_area.monitoring = false
		node.interaction_prompt.hide()
		node.set_burners_enabled(false)
	if node is SinkableDish:
		# Replaced by two explicitly sized challenge plates in Course. Keep
		# Iroh's basin, but don't leave submerged decorative colliders to stand on.
		node.active = false
		node.collision_layer = 0
		node.player_sensor.monitoring = false
		node.hide()
	for child in node.get_children():
		configure_environment(child)

func refill() -> void:
	if result:
		return
	# Initial spawn only. Station charging uses add_ice() below, never refresh.
	mount.equip(ICE, {"ambient_melt_seconds": shell_lifetime})

func equip_empty() -> void:
	equip_pending = false
	if result or is_instance_valid(player.gadget):
		return
	mount.equip(ICE, {"ambient_melt_seconds": shell_lifetime})
	player.gadget.set_amount(.001)
	player.gadget.charging = is_refilling

func add_ice(delta: float) -> void:
	if not is_instance_valid(player.gadget):
		if not equip_pending:
			equip_pending = true
			equip_empty.call_deferred()
		return
	player.gadget.set_amount(player.gadget.amount() + delta / refill_seconds)

func reached_station(body: Node3D, station: Node3D) -> void:
	if body != player or result:
		return
	checkpoint = station.global_position + Vector3(0, 3.6, 0)
	if station.name.begins_with("05"):
		$PlayerRig/Camera3D.turn_towards(0)
	elif station.name.begins_with("04"):
		$PlayerRig/Camera3D.turn_towards(PI)
	elif station.name.begins_with("02"):
		$PlayerRig/Camera3D.turn_towards(-PI / 2)
	elif station.name.begins_with("03"):
		$PlayerRig/Camera3D.turn_towards(0)
		$PlayerRig/Camera3D.pitch = deg_to_rad(-38)
	active_station = station.name.replace("_", " ")

func _physics_process(delta: float) -> void:
	if result:
		return
	is_refilling = false
	for station in $Refills.get_children():
		if station.get_node("PickupArea").overlaps_body(player):
			is_refilling = true
	player.cooling = is_refilling
	if is_instance_valid(player.gadget):
		player.gadget.charging = is_refilling
	if is_refilling:
		add_ice(delta)
	if player.global_position.y < -12:
		reset_checkpoint()
	var camera = $PlayerRig/Camera3D
	if active_station.begins_with("04") and player.position.z > -175 and camera.route_yaw != PI/2:
		camera.turn_towards(PI/2)
	elif active_station.begins_with("05") and player.position.z < -184 and camera.route_yaw != PI/2:
		camera.turn_towards(PI/2)
	update_hud($Course/SpringServer.ready_to_launch)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if result and event.physical_keycode == KEY_ENTER:
			get_tree().reload_current_scene()

func reset_checkpoint() -> void:
	if result:
		return
	$Course/SpringServer.cancel()
	player.teleport_to(Transform3D(Basis.IDENTITY, checkpoint))
	player.flight_remaining = 0.0
	$PlayerRig/Camera3D.initialized = false

func finish(success: bool) -> void:
	if result:
		return
	result = true
	player.finished = true
	player.freeze = true
	# Freeze equipment too: the final result is a snapshot of the delivered scoop.
	if is_instance_valid(player.gadget):
		player.gadget.set_physics_process(false)
	var panel: PanelContainer = $PlayerRig/HUD/Result
	panel.show()
	var stars: int = player.star_count() if success else 0
	panel.get_node("Rows/Title").text = "DELIVERED!" if success else "SCOOP MELTED"
	panel.get_node("Rows/Stars").text = "★".repeat(stars) + "☆".repeat(3 - stars)
	panel.get_node("Rows/Detail").text = "Scoop remaining: %d%%\nIce refills never restore the scoop.\n\nEnter — try a fresh run" % roundi(player.core_health / 3.0 * 100)
	update_hud()

func update_hud(at_spoon := false) -> void:
	var shell := 0.0
	if is_instance_valid(player.gadget):
		shell = (1.0 - float(player.gadget.get("_melt_progress"))) * 100.0
	rows.get_node("Shell").value = shell
	rows.get_node("IceLabel").text = "ICE SHELL  %d%%  /  unlimited refills" % roundi(shell)
	for i in range(3):
		rows.get_node("Health/Cell%d" % i).value = clampf(player.core_health - i, 0, 1) * 100
	rows.get_node("CoreLabel").text = "SCOOP  %d%%  /  your final star rating" % roundi(player.core_health / 3.0 * 100)
	if not $PlayerRig/Camera3D.free_mode:
		rows.get_node("State").text = ("GREEN • E TO SERVE" if $Course/SpringServer.launch_window else "WAIT FOR GREEN • E can miss") if at_spoon else ("CHARGING ICE... stay on the cooler" if is_refilling and shell < 99.5 else active_station)
	if active_station.begins_with("05"):
		rows.get_node("Objective").text = "Watch hotplate → time your serve on GREEN"
	elif active_station.begins_with("04"):
		rows.get_node("Objective").text = "Climb → turn left → balance across the spinning pin"
	elif active_station.begins_with("03"):
		rows.get_node("Objective").text = "Watch spoon from bank → jump across sinking plates"
	elif active_station.begins_with("02"):
		rows.get_node("Objective").text = "Hot + windy shortcut OR longer cool side loop"
	else:
		rows.get_node("Objective").text = "Two presses • stop on mint rest between them"
