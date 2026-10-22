extends RefCounted

static func setup() -> void:
	# Level-specific bindings: do not remove arrows from the team's other players.
	var bindings := {"ice_left":KEY_A,"ice_right":KEY_D,"ice_forward":KEY_W,"ice_backward":KEY_S,"ice_look_left":KEY_LEFT,"ice_look_right":KEY_RIGHT,"ice_look_up":KEY_UP,"ice_look_down":KEY_DOWN,"ice_camera_down":KEY_Q,"ice_camera_up":KEY_E}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode=bindings[action]
		InputMap.action_add_event(action,key)
