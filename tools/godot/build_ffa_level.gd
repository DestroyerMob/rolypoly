extends SceneTree

## Saves "Island brawl", a free-for-all arena on the kitchen island, into My levels.
## Run: godot --headless --path . -s res://tools/godot/build_ffa_level.gd

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const FILENAME := "island_brawl.json"
## Top of the kitchen island, which spans x -149..137 and z -560..-437.
const TOP := -0.55

enum Character { ONION, EGG, TOMATO, ICE_CREAM, LOLLIPOP }
enum Weapon { NONE, PISTOL, M4A1, SHOTGUN }


func _initialize() -> void:
	var level := {"version": Store.VERSION, "name": "Island brawl", "player": "onion", "mode": "ffa", "objects": []}
	place(level, "spawn", -120, -498)
	place(level, "pistol", -120, -498)
	place(level, "m4a1", -6, -498)
	place(level, "shotgun", -6, -450)
	place(level, "shotgun", -6, -548)
	wall(level, -55, -498, 45, 5)
	wall(level, 45, -498, -45, 5)
	wall(level, -30, -470, -45, 4)
	wall(level, 20, -526, 45, 4)
	for spot in [Vector2(-85, -458), Vector2(-85, -540), Vector2(85, -460), Vector2(80, -538)]:
		place(level, "cardboard", spot.x, spot.y, 0.0, Vector3.ONE, 0.8)
	npc(level, 115, -498, Character.ONION, Weapon.SHOTGUN)
	npc(level, 60, -450, Character.TOMATO, Weapon.PISTOL)
	npc(level, 60, -546, Character.TOMATO, Weapon.PISTOL)
	level = Store.normalize(level)
	var problem := Store.playable_error(level)
	var result := Store.save_level(level, FILENAME)
	if result.has("error") or not problem.is_empty():
		push_error(result.get("error", problem))
		quit(1)
		return
	print("Saved %s to %s" % [level.name, ProjectSettings.globalize_path(Store.DIRECTORY.path_join(FILENAME))])
	quit(0)


func place(level: Dictionary, id: String, x: float, z: float, yaw := 0.0, size := Vector3.ONE, lift := 0.0) -> Dictionary:
	var entry := Catalog.record(id, Vector3(x, TOP + lift, z))
	entry.rotation = [0.0, yaw, 0.0]
	entry.scale = [size.x, size.y, size.z]
	level.objects.append(entry)
	return entry


## A platform stood on edge: 4 units per width step, 5 tall, 4 thick.
func wall(level: Dictionary, x: float, z: float, yaw: float, width: float) -> void:
	place(level, "box", x, z, yaw, Vector3(width, 10, 1))


func npc(level: Dictionary, x: float, z: float, character: Character, weapon: Weapon) -> void:
	var entry := place(level, "npc", x, z, -90.0)
	entry.properties = {"character": character, "mode": NPC.Mode.FIGHT, "weapon": weapon,
		"fight_range": 45.0, "aim_error": 2.5, "max_speed": 10.0}
