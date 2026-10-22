extends Node3D

## Three independent stars: finish, preserve ice, explore. No speed requirement.
@export_range(0, 100) var ice_star_threshold := 50.0
@export var crystal_star_target := 3
@export var persist_best_score := true
@onready var player = $Player
@onready var meter: ProgressBar = $HUD/Margin/Panel/Rows/IceMeter
@onready var info: Label = $HUD/Margin/Panel/Rows/State
@onready var toast: Label = $HUD/Toast
@onready var objectives: Label = $HUD/Margin/Panel/Rows/Objectives
@onready var results: PanelContainer = $HUD/Results
var collected_ids: Array[String] = []
var stars := 0
var best_stars := 0
var toast_time := 6.0
var elapsed := 0.0

func _ready() -> void:
	player.ice_changed.connect(func(amount: float): meter.value = amount)
	player.restarted.connect(_reset_notice)
	player.finished.connect(_won)
	$HUD/Results/Rows/Replay.pressed.connect(func(): get_tree().reload_current_scene())
	var save := ConfigFile.new()
	if persist_best_score and save.load("user://ice_kitchen_stars.cfg") == OK:
		best_stars = clampi(int(save.get_value("ice_kitchen", "best_stars", 0)), 0, 3)
	_update_objectives()

func collect_crystal(id: String) -> void:
	if collected_ids.has(id) or player.won:
		return
	collected_ids.append(id)
	toast.text = "ICE CRYSTAL FOUND  %d / %d" % [collected_ids.size(), crystal_star_target]
	toast_time = 3.0
	_update_objectives()

func _update_objectives() -> void:
	objectives.text = "3 STARS: Finish / %.0f%% ice / Explore\nCrystals %d / %d   |   Best %d / 3" % [ice_star_threshold, collected_ids.size(), crystal_star_target, best_stars]

func calculate_stars(completed: bool, ice: float, crystals: int) -> int:
	if not completed:
		return 0
	return 1 + int(ice >= ice_star_threshold) + int(crystals >= crystal_star_target)

func _process(delta: float) -> void:
	if not player.won:
		elapsed += delta
	info.text = player.status
	toast_time -= delta
	toast.visible = toast_time > 0.0 or player.won

func _reset_notice(reason: String) -> void:
	toast.text = reason
	toast_time = 3.0

func _won() -> void:
	meter.value = player.ice_amount
	stars = calculate_stars(true, player.ice_amount, collected_ids.size())
	best_stars = maxi(best_stars, stars)
	var save := ConfigFile.new()
	save.set_value("ice_kitchen", "best_stars", best_stars)
	if persist_best_score:
		save.save("user://ice_kitchen_stars.cfg")
	_update_objectives()
	toast.text = ""
	results.show()
	$HUD/Results/Rows/Stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	$HUD/Results/Rows/Details.text = "★  Dessert reached\n%s  At least %.0f%% ice remaining (%.0f%%)\n%s  All ice crystals found (%d / %d)\n\nTime: %.0fs — no time limit for stars\nBest score: %d / 3" % ["★" if player.ice_amount >= ice_star_threshold else "☆", ice_star_threshold, player.ice_amount, "★" if collected_ids.size() >= crystal_star_target else "☆", collected_ids.size(), crystal_star_target, elapsed, best_stars]
