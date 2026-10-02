extends RefCounted

const INK := Color("e8edf4")
const MUTED := Color("9faec1")
const ACCENT := Color("91e5c1")

static func box(color: Color, padding := 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color("647186"))
	var panel := box(Color("171e29"), 18)
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	theme.set_stylebox("panel", "PanelContainer", panel)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, box(Color("293446")))
		theme.set_stylebox("hover", type, box(Color("35445b")))
		theme.set_stylebox("pressed", type, box(Color("254c45")))
		var focus := box(Color(0, 0, 0, 0))
		focus.border_color = ACCENT
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, focus)
		theme.set_font_size("font_size", type, 18)
	for type in ["LineEdit", "ItemList"]:
		theme.set_stylebox("normal" if type == "LineEdit" else "panel", type, box(Color("101620")))
		theme.set_color("font_color", type, INK)
		theme.set_color("font_placeholder_color", type, MUTED)
		theme.set_color("font_selected_color", type, Color.WHITE)
	theme.set_stylebox("selected", "ItemList", box(Color("285047"), 8))
	theme.set_stylebox("selected_focus", "ItemList", box(Color("285047"), 8))
	theme.set_constant("v_separation", "ItemList", 10)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 10)
	return theme

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(ACCENT, 18))
	button.add_theme_stylebox_override("hover", box(Color("b2f1d6"), 18))
	button.add_theme_stylebox_override("pressed", box(Color("6acaa3"), 18))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("102c25"))
