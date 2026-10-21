extends RefCounted


const MODES := [["Turn on", "on"], ["Turn off", "off"], ["Toggle", "toggle"]]
const MAX_TARGETS := 32

static var ACTIONS := _build()


static func _switch(name: String, label: String, setter := "") -> Dictionary:
	return {"name": name, "label": label, "kind": "switch", "setter": setter}


static func _pulse(method: String, label: String) -> Dictionary:
	return {"name": method, "label": label, "kind": "pulse"}


static func _build() -> Dictionary:
	return {
		"goal": [_switch("enabled", "Finish open")],
		"oven": [
			_switch("burners_on", "Burners", "set_burners_enabled"),
			_switch("doors_open", "Doors open", "set_doors_open"),
		],
		"grill": [_switch("heated", "Heated")],
		"lighter": [_switch("lit", "Lit")],
		"roller": [_switch("active", "Moving")],
		"spinner": [_switch("active", "Spinning")],
		"log": [_switch("active", "Spinning")],
		"masher": [_switch("active", "Active"), _pulse("trigger", "Drop once")],
		"ladle": [_switch("active", "Swinging")],
		"ladle_vertical": [_switch("active", "Swinging")],
		"dicer": [_switch("active", "Moving")],
	}


static func actions(id: String) -> Array:
	return ACTIONS.get(id, [])


static func action_named(id: String, name: String) -> Dictionary:
	for action in actions(id):
		if action.name == name:
			return action
	return {}


static func mode_valid(mode: Variant) -> bool:
	return MODES.any(func(option): return option[1] == mode)


static func run(node: Node, id: String, target: Dictionary) -> void:
	var action := action_named(id, target.action)
	if action.is_empty() or not is_instance_valid(node):
		return
	if action.kind == "pulse":
		node.call(action.name)
		return
	var value: bool = not bool(node.get(action.name)) if target.mode == "toggle" else target.mode == "on"
	if action.setter.is_empty():
		node.set(action.name, value)
	else:
		node.call(action.setter, value)
