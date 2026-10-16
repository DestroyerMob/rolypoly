extends RefCounted

const DIRECTION := [["Forward", 1], ["Reversed", -1]]

static var SPECS := _build()


static func _num(name: String, label: String, low: float, high: float, step: float, on := "") -> Dictionary:
	return {"name": name, "label": label, "type": "float", "min": low, "max": high, "step": step, "on": on}


static func _whole(name: String, label: String, low: int, high: int, on := "") -> Dictionary:
	return {"name": name, "label": label, "type": "int", "min": low, "max": high, "step": 1, "on": on}


static func _flag(name: String, label: String, on := "") -> Dictionary:
	return {"name": name, "label": label, "type": "bool", "on": on}


static func _choice(name: String, label: String, options: Array, on := "") -> Dictionary:
	return {"name": name, "label": label, "type": "enum", "options": options, "on": on}


static func _gun() -> Array:
	return [
		_num("fire_interval", "Seconds between shots", 0.02, 3.0, 0.01, "gadget"),
		_flag("automatic", "Hold to keep firing", "gadget"),
		_whole("pellets", "Pellets per shot", 1, 30, "gadget"),
		_num("spread_degrees", "Spread · degrees", 0.0, 45.0, 0.1, "gadget"),
		_num("impulse", "Push per pellet", 0.0, 200.0, 0.5, "gadget"),
	]


static func _build() -> Dictionary:
	return {
		"oven": [
			_flag("start_burners_on", "Burners start on"),
			_flag("start_doors_open", "Doors start open"),
			_num("door_open_angle_degrees", "Door angle · degrees", 45.0, 105.0, 1.0),
		],
		"grill": [
			_flag("heated", "Heated"),
			_num("ice_melt_seconds", "Ice melt time · seconds", 0.5, 30.0, 0.5),
		],
		"lighter": [_flag("lit", "Lit")],
		"roller": [
			_flag("active", "Moving"),
			_num("travel_distance", "Travel distance", 0.0, 20.0, 0.1),
			_num("travel_speed", "Travel speed", 0.1, 12.0, 0.1),
			_num("pause_at_ends", "Pause at ends · seconds", 0.0, 3.0, 0.05),
			_choice("starting_direction", "Starting direction", DIRECTION),
		],
		"spinner": [
			_flag("active", "Spinning"),
			_num("rotation_speed_degrees", "Speed · degrees per second", 0.0, 720.0, 1.0),
			_choice("spin_direction", "Direction", DIRECTION),
		],
		"log": [
			_flag("active", "Spinning"),
			_choice("spin_axis", "Spins about", [["Length (X)", 0], ["Length (Z)", 1], ["Vertical", 2]]),
			_choice("spin_direction", "Direction", DIRECTION),
			_num("spin_speed_degrees", "Speed · degrees per second", 0.0, 720.0, 1.0),
			_num("reverse_interval", "Reverse every · seconds (0 = never)", 0.0, 20.0, 0.1),
			_num("reverse_ramp", "Reversal ramp · seconds", 0.0, 2.0, 0.05),
		],
		"masher": [
			_flag("active", "Active"),
			_flag("auto_cycle", "Cycles automatically"),
			_num("raised_height", "Raised height", 0.1, 10.0, 0.1),
			_num("lowered_height", "Lowered height", 0.0, 2.0, 0.05),
			_num("drop_speed", "Drop speed", 0.1, 20.0, 0.1),
			_num("rise_speed", "Rise speed", 0.1, 20.0, 0.1),
			_num("wait_time", "Wait while raised · seconds", 0.0, 10.0, 0.1),
			_num("hold_time", "Hold while lowered · seconds", 0.0, 5.0, 0.05),
		],
		"knife": [
			_num("swing_speed", "Swing speed", 0.1, 10.0, 0.1),
			_num("chop_angle_degrees", "Chop angle · degrees", -360.0, 360.0, 1.0),
			_num("chop_time", "Chop time · seconds", 0.05, 2.0, 0.01),
			_num("lift_time", "Lift time · seconds", 0.1, 3.0, 0.05),
			_num("pause_down", "Pause down · seconds", 0.0, 3.0, 0.05),
			_num("pause_up", "Pause up · seconds", 0.0, 3.0, 0.05),
		],
		"blender": [
			_num("force_strength", "Force strength (negative pulls)", -200.0, 200.0, 1.0),
			_num("force_range", "Force range", 0.5, 100.0, 0.1),
			_num("force_angle_degrees", "Force cone angle · degrees", 1.0, 80.0, 1.0),
			_num("rotation_duration", "Seconds per blade rotation", 0.05, 60.0, 0.05),
		],
		"ladle": [
			_flag("active", "Swinging"),
			_num("swing_angle_degrees", "Swing angle · degrees", 0.0, 360.0, 0.5),
			_num("swing_period", "Swing period · seconds", 0.2, 10.0, 0.1),
			_num("phase_degrees", "Phase · degrees", -180.0, 180.0, 1.0),
			_num("swing_offset_degrees", "Swing offset · degrees", -90.0, 90.0, 1.0),
			_choice("swing_direction", "Direction", DIRECTION),
		],
		"ladle_vertical": [
			_flag("active", "Swinging"),
			_num("swing_angle_degrees", "Swing angle · degrees", 0.0, 75.0, 0.5),
			_num("swing_period", "Swing period · seconds", 0.8, 10.0, 0.1),
			_num("phase_degrees", "Phase · degrees", -180.0, 180.0, 1.0),
		],
		"funnel": [
			_num("transition_delay", "Transition delay · seconds", 0.0, 1.0, 0.01),
			_num("cooldown", "Cooldown · seconds", 0.0, 2.0, 0.05),
		],
		"funnel_long": [
			_num("transition_delay", "Transition delay · seconds", 0.0, 1.0, 0.01),
			_num("cooldown", "Cooldown · seconds", 0.0, 2.0, 0.05),
		],
		"corkscrew": [
			_num("rotation_amount_degrees", "Turn per activation · degrees", -3600.0, 3600.0, 15.0),
			_num("height_change", "Height change", -20.0, 20.0, 0.1),
			_num("duration", "Duration · seconds", 0.01, 60.0, 0.05),
		],
		"dicer": [
			_flag("active", "Moving"),
			_num("travel_speed", "Travel speed", 0.0, 10.0, 0.1),
		],
		"umbrella": [_num("max_fall_speed", "Maximum fall speed", 0.1, 30.0, 0.1, "gadget")],
		"cream": [
			_num("burst_duration", "Burst length · seconds", 0.05, 2.0, 0.05, "gadget"),
			_num("thrust_acceleration", "Thrust", 1.0, 100.0, 1.0, "gadget"),
			_num("max_boost_rise_speed", "Maximum rise speed", 1.0, 30.0, 0.5, "gadget"),
		],
		"ice": [
			_num("size_multiplier", "Size multiplier", 1.0, 2.0, 0.05, "gadget"),
			_num("ambient_melt_seconds", "Melt time · seconds", 1.0, 300.0, 1.0, "gadget"),
		],
		"gravity": [
			_num("pull_speed", "Pull speed", 1.0, 60.0, 1.0, "gadget"),
			_num("grab_range", "Grab range", 5.0, 300.0, 1.0, "gadget"),
			_num("launch_impulse", "Launch force", 0.0, 200.0, 1.0, "gadget"),
		],
		"npc": [
			_choice("character", "Character", [["Onion", 0], ["Egg", 1], ["Tomato", 2], ["Ice cream", 3], ["Lollipop", 4]]),
			_choice("mode", "Behaviour", [["Wander", 1], ["Fight", 3], ["Race to finish", 2], ["Stand still", 0]]),
			_num("max_speed", "Top speed", 1.0, 40.0, 0.5),
			_num("wander_radius", "Wander radius", 1.0, 200.0, 0.5),
			_num("fight_range", "Fight · shooting range", 2.0, 300.0, 1.0),
			_num("aim_error", "Fight · aim error", 0.0, 20.0, 0.1),
		],
		"m4a1": _gun(),
		"shotgun": _gun(),
		"pistol": _gun(),
	}


static func specs(id: String) -> Array:
	return SPECS.get(id, [])


static func spec_named(id: String, name: String) -> Dictionary:
	for spec in specs(id):
		if spec.name == name:
			return spec
	return {}


static func coerce(spec: Dictionary, value: Variant) -> Variant:
	match spec.type:
		"bool":
			return bool(value)
		"int":
			return clampi(int(roundf(float(value))), spec.min, spec.max)
		"enum":
			return int(value)
		_:
			return clampf(float(value), spec.min, spec.max)


static func gadget_scene_of(node: Node) -> Node:
	var scene := node.get("gadget_scene") as PackedScene
	return scene.instantiate() if scene != null else null


static func read_defaults(id: String, fresh: Node) -> Dictionary:
	var defaults := {}
	var gadget: Node = null
	for spec in specs(id):
		var source := fresh
		if spec.on == "gadget":
			if gadget == null:
				gadget = gadget_scene_of(fresh)
			source = gadget
		if source != null:
			defaults[spec.name] = source.get(spec.name)
	if gadget != null:
		gadget.free()
	return defaults


static func apply(node: Node, id: String, values: Dictionary) -> void:
	var gadget_values := {}
	for spec in specs(id):
		if not values.has(spec.name):
			continue
		var value: Variant = coerce(spec, values[spec.name])
		if spec.on == "gadget":
			gadget_values[spec.name] = value
		else:
			node.set(spec.name, value)
	if not gadget_values.is_empty():
		node.set("gadget_overrides", gadget_values)


static func validate(id: String, values: Variant) -> String:
	if not values is Dictionary:
		return "An object has invalid properties."
	for key in values:
		var spec := spec_named(id, str(key))
		if spec.is_empty():
			return "An object has an unknown property."
		var value: Variant = values[key]
		match spec.type:
			"bool":
				if not value is bool:
					return "An object has an invalid property value."
			"enum":
				if not (value is float or value is int) or not spec.options.any(func(option): return option[1] == int(value)):
					return "An object has an invalid property value."
			_:
				if not (value is float or value is int) or not is_finite(float(value)):
					return "An object has an invalid property value."
				if float(value) < spec.min - 0.0001 or float(value) > spec.max + 0.0001:
					return "An object property is outside its supported range."
	return ""
