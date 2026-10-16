extends SceneTree

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const ItemTriggers = preload("res://scripts/level_editor/item_triggers.gd")
const World = preload("res://scripts/level_editor/level_world.gd")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func has_property(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if property.name == name:
			return true
	return false


func record(id: String, uid: int, position := Vector3.ZERO) -> Dictionary:
	var entry := Catalog.record(id, position)
	entry.uid = uid
	return entry


## spawn 1, closed finish 2, watcher 3 opening the finish after one death.
func gated_level() -> Dictionary:
	var level := Store.new_level()
	level.objects = [record("spawn", 1, Vector3(0, 80, 0)), record("goal", 2, Vector3(40, 80, 0)), record("watcher", 3, Vector3(20, 80, 0))]
	level.objects[1].properties = {"enabled": false}
	level.objects[2].targets = [{"uid": 2, "action": "enabled", "mode": "on"}]
	return level


func test_actions_match_scenes() -> void:
	for id in ItemTriggers.ACTIONS:
		check(Catalog.ITEMS.has(id), "%s has trigger actions but is not in the catalog." % id)
		var fresh := Catalog.instantiate(Catalog.record(id))
		for action in ItemTriggers.actions(id):
			if action.kind == "pulse":
				check(fresh.has_method(action.name), "%s: %s is not a method." % [id, action.name])
			else:
				check(has_property(fresh, action.name), "%s: %s is not a property." % [id, action.name])
				if not action.setter.is_empty():
					check(fresh.has_method(action.setter), "%s: %s is not a method." % [id, action.setter])
		fresh.free()


func test_store() -> void:
	var fresh := Store.new_level()
	check(fresh.objects.all(func(entry): return entry.has("uid")), "New levels must give every object an id.")
	var legacy := {"version": 1, "name": "Old", "objects": [Catalog.record("spawn"), Catalog.record("goal")]}
	check(Store.validate(legacy).is_empty(), "Levels saved before ids existed must still load.")
	var upgraded := Store.normalize(legacy)
	check(upgraded.objects[0].uid != upgraded.objects[1].uid, "Loading an old level must assign distinct ids.")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(gated_level()))
	check(Store.validate(parsed).is_empty(), "A saved watcher level must validate: %s" % Store.validate(parsed))
	check(Store.normalize(parsed).objects[2].targets[0].uid is int, "Ids read from JSON must become whole numbers.")
	var shared := gated_level()
	shared.objects[1].uid = 1
	check(not Store.validate(shared).is_empty(), "Duplicate ids must be rejected.")
	var wrong_owner := gated_level()
	wrong_owner.objects[0].targets = [{"uid": 2, "action": "enabled", "mode": "on"}]
	check(not Store.validate(wrong_owner).is_empty(), "Only watchers may have targets.")
	var bad_action := gated_level()
	bad_action.objects[2].targets[0].action = "explode"
	check(not Store.validate(bad_action).is_empty(), "Actions the target doesn't support must be rejected.")
	var bad_mode := gated_level()
	bad_mode.objects[2].targets[0].mode = "sideways"
	check(not Store.validate(bad_mode).is_empty(), "Unknown modes must be rejected.")
	var dangling := gated_level()
	dangling.objects[2].targets.append({"uid": 99, "action": "enabled", "mode": "on"})
	dangling.objects[2].source = 98
	check(Store.validate(dangling).is_empty(), "Links to deleted objects must not block loading.")
	var pruned := Store.normalize(dangling)
	check(pruned.objects[2].targets.size() == 1 and not pruned.objects[2].has("source"), "Links to deleted objects must be dropped.")
	check(Store.playable_error(gated_level()).is_empty(), "A closed finish opened by a watcher must be playable.")
	var stuck := gated_level()
	stuck.objects[2].erase("targets")
	check(not Store.playable_error(stuck).is_empty(), "A level whose only finish can never open must not be playable.")


func test_watcher_logic() -> void:
	var watcher: Node = Catalog.instantiate(record("watcher", 1))
	var goal: Area3D = Catalog.instantiate(record("goal", 2))
	goal.enabled = false
	root.add_child(watcher)
	root.add_child(goal)
	watcher.threshold = 2.0
	watcher.targets.append({"node": goal, "id": "goal", "action": "enabled", "mode": "toggle"})
	await process_frame
	watcher.player_died()
	check(not goal.enabled, "The watcher must not fire before the count is met.")
	watcher.npc_finished()
	check(not goal.enabled, "A watcher must ignore events it isn't watching.")
	watcher.player_died()
	check(goal.enabled and watcher.fired == 1, "Meeting the count must run the target action.")
	watcher.player_died()
	check(goal.enabled and watcher.fired == 1, "A one-shot watcher must fire only once.")
	watcher.free()
	goal.free()

	var scale_watcher: Node = Catalog.instantiate(record("watcher", 1))
	scale_watcher.event = 2
	scale_watcher.comparison = 0
	scale_watcher.threshold = 3.0
	scale_watcher.repeat = true
	var masher: Node = Catalog.instantiate(record("masher", 2))
	root.add_child(scale_watcher)
	root.add_child(masher)
	scale_watcher.targets.append({"node": masher, "id": "masher", "action": "active", "mode": "toggle"})
	await process_frame
	var start: bool = masher.active
	scale_watcher.scale_weighed(2.0, 5)
	scale_watcher.scale_weighed(1.5, 6)
	check(masher.active != start, "Without a linked scale, every scale's weight must be added together.")
	scale_watcher.scale_weighed(0.0, 5)
	scale_watcher.scale_weighed(2.0, 5)
	check(masher.active == start and scale_watcher.fired == 2, "A repeating watcher must fire each time the condition becomes true again.")
	scale_watcher.source_uid = 6
	scale_watcher.scale_weighed(9.0, 5)
	check(scale_watcher.fired == 2, "A watcher linked to one scale must ignore the others.")
	scale_watcher.free()
	masher.free()


func test_play() -> void:
	var world: Node3D = World.new()
	root.add_child(world)
	world.build(gated_level(), false)
	await physics_frame
	var goal: Area3D = world.objects[1]
	check(not goal.enabled, "A finish set closed must start closed.")
	check(world.watchers.size() == 1 and world.watchers[0].targets.size() == 1, "Playing must hand each watcher its targets.")
	world.rig.current_player.die()
	check(goal.enabled, "Dying must count as a player death and open the finish.")
	world.free()


## spawn 1 and one armed, fighting NPC 2; no finish needed.
func brawl_level() -> Dictionary:
	var level := Store.new_level()
	level.mode = "ffa"
	level.objects = [record("spawn", 1, Vector3(0, 80, 0)), record("npc", 2, Vector3(30, 80, 0))]
	level.objects[1].properties = {"mode": NPC.Mode.FIGHT, "weapon": 1}
	return level


func test_free_for_all() -> void:
	check(Store.playable_error(brawl_level()).is_empty(), "A free for all must not need a finish: %s" % Store.playable_error(brawl_level()))
	var empty := brawl_level()
	empty.objects.pop_back()
	check(not Store.playable_error(empty).is_empty(), "A free for all without NPCs must not be playable.")
	var unknown := brawl_level()
	unknown.mode = "golf"
	check(not Store.validate(unknown).is_empty(), "Unknown game modes must be rejected.")
	var world: Node3D = World.new()
	root.add_child(world)
	var outcome := []
	world.lost.connect(func(): outcome.append("lost"))
	world.completed.connect(func(): outcome.append("won"))
	world.build(brawl_level(), false)
	await physics_frame
	await physics_frame
	var npc: NPC = world.get_tree().get_nodes_in_group(&"players").filter(func(p): return p is NPC)[0]
	check(world.rig.current_player.in_match and npc.in_match, "Everyone must join the match.")
	check(npc.gadget is Gun, "An NPC spawner's weapon must be equipped.")
	npc.die()
	await process_frame
	check(outcome == ["won"], "Knocking out every NPC must win the level.")
	world.free()
	world = World.new()
	root.add_child(world)
	world.lost.connect(func(): outcome.append("lost"))
	world.build(brawl_level(), false)
	await physics_frame
	await physics_frame
	world.rig.current_player.die()
	await process_frame
	check(outcome == ["won", "lost"], "Being knocked out must lose the level.")
	world.free()


func test_hit_burst() -> void:
	var world: Node3D = World.new()
	root.add_child(world)
	world.build(brawl_level(), false)
	await physics_frame
	await physics_frame
	var npc: NPC = world.get_tree().get_nodes_in_group(&"players").filter(func(p): return p is NPC)[0]
	var player: Player = world.rig.current_player
	var before := root.find_children("*", "GPUParticles3D", true, false).size()
	var hits := []
	npc.gadget.hit.connect(func(collider, point, normal, _direction): hits.append([collider, point, normal]))
	npc.gadget.spread_degrees = 0.0
	npc.gadget.fire_at(player.global_position)
	var bursts := root.find_children("*", "GPUParticles3D", true, false)
	check(hits.size() == 1 and hits[0][0] == player, "The test shot must hit the player.")
	check(bursts.size() == before + 1, "A shot that hits a player must spray pieces.")
	if hits.size() == 1 and bursts.size() == before + 1:
		var burst: GPUParticles3D = bursts[-1]
		check(burst.global_position.is_equal_approx(hits[0][1]), "Pieces must come from where the player was hit.")
		check((burst.global_basis * Vector3.UP).normalized().dot(hits[0][2]) > 0.99, "Pieces must spray out of the hit surface.")
		check(burst.process_material.color == player.hit_color, "Pieces must be the hit character's colour.")
	world.free()


func test_editor() -> void:
	var editor := preload("res://scenes/level_builder.tscn").instantiate() as LevelBuilder
	root.add_child(editor)
	await process_frame
	editor.document = Store.normalize(gated_level())
	editor.document.objects[2].erase("targets")
	editor.document.objects.append(record("masher", 4, Vector3(60, 80, 0)))
	editor.document.objects.append(record("scale", 5, Vector3(80, 80, 0)))
	editor._rebuild_world()
	editor._select_existing(3)
	check(editor.property_section.find_child("LinkTarget", true, false) != null, "A selected watcher must offer Link target.")
	editor._start_linking("target")
	check(editor.linking == "target", "Link target must wait for a click.")
	editor._link_pick(0)
	check(editor.linking == "target" and not editor.document.objects[2].has("targets"), "Objects without actions must not be linked.")
	editor._link_pick(3)
	check(editor.linking.is_empty() and editor.document.objects[2].targets == [{"uid": 4, "action": "active", "mode": "on"}], "Clicking a masher must link it.")
	editor._start_linking("target")
	editor._link_pick(3)
	check(editor.document.objects[2].targets.size() == 1, "The same object can't be linked twice.")
	editor.linking = ""
	editor._target_action_changed(1, 0)
	check(editor.document.objects[2].targets[0].action == "trigger", "Choosing an action must update the target.")
	editor._target_mode_changed(2, 0)
	check(editor.document.objects[2].targets[0].mode == "toggle", "Choosing a mode must update the target.")
	editor._start_linking("source")
	editor._link_pick(3)
	check(not editor.document.objects[2].has("source"), "Only scales can be a watcher's source.")
	editor._link_pick(4)
	check(editor.document.objects[2].source == 5, "Clicking a scale must make it the source.")
	var before: int = editor.document.objects[3].uid
	editor._select_existing(4)
	editor._delete_selected()
	check(not editor.document.objects[2].has("targets"), "Deleting a target must unlink it.")
	editor._undo()
	check(editor.document.objects[2].targets[0].uid == before, "Undo must restore the link.")
	editor._select_existing(4)
	editor._duplicate_selected()
	var uids: Array = editor.document.objects.map(func(entry): return entry.uid)
	check(uids.all(func(uid): return uids.count(uid) == 1) and Store.validate(editor.document).is_empty(), "Duplicates must get their own id.")
	check(editor.world.links != null and editor.world.links.mesh.get_surface_count() == 1, "Links must be drawn while editing.")
	editor.free()


func _run() -> void:
	test_actions_match_scenes()
	test_store()
	await test_watcher_logic()
	await test_play()
	await test_free_for_all()
	await test_hit_burst()
	await test_editor()
	print("Event watcher tests: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
