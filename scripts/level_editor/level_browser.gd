extends Window
signal chosen(document: Dictionary, filename: String, editing: bool)
signal deleted(filename: String)
const EditorTheme = preload("res://scripts/level_editor/editor_theme.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
var _list: ItemList
var _message: Label
var _entries: Array = []
var _delete_button: Button

func _ready() -> void:
	theme = EditorTheme.create()
	title = "My levels"
	size = Vector2i(820, 580)
	min_size = Vector2i(550, 420)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 56
	column.add_child(_message)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_list)
	_list.item_selected.connect(_select)
	_list.item_activated.connect(func(_index: int): _open(false))
	var row := HBoxContainer.new()
	column.add_child(row)
	for action in ["Play", "Edit", "Delete", "New level", "Close"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size.y = 46
		if action == "Play":
			EditorTheme.primary(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		match action:
			"Play": button.pressed.connect(_open.bind(false))
			"Edit": button.pressed.connect(_open.bind(true))
			"Delete":
				_delete_button = button
				button.disabled = true
				button.tooltip_text = "Delete the selected saved level."
				button.pressed.connect(_delete)
			"New level": button.pressed.connect(func(): chosen.emit.call_deferred(Store.new_level(), "", true))
			"Close": button.pressed.connect(hide)

func show_levels() -> void:
	_refresh_levels()
	popup_centered()

func _refresh_levels() -> void:
	_entries = Store.list_levels()
	_list.clear()
	_delete_button.disabled = true
	for entry in _entries:
		_list.add_item(entry.name + (" — draft / unavailable" if not entry.error.is_empty() else ""))
	_message.text = "Choose a saved level to play or edit." if not _entries.is_empty() else "No saved levels yet. Create a new level to get started."

func _select(index: int) -> void:
	_delete_button.disabled = false
	_message.text = _entries[index].error if not _entries[index].error.is_empty() else "Ready to play."

func _delete() -> void:
	if _list.get_selected_items().is_empty():
		return
	var index: int = _list.get_selected_items()[0]
	var entry: Dictionary = _entries[index]
	var result := Store.delete_level(entry.filename)
	if result.has("error"):
		_message.text = result.error
		return
	_refresh_levels()
	if not _entries.is_empty():
		index = mini(index, _entries.size() - 1)
		_list.select(index)
		_select(index)
	_message.text = "Deleted “%s”." % entry.name
	deleted.emit(entry.filename)

func _open(editing: bool) -> void:
	if _list.get_selected_items().is_empty():
		_message.text = "Select a saved level first."
		return
	var entry: Dictionary = _entries[_list.get_selected_items()[0]]
	var result := Store.read_level(entry.filename)
	if result.has("error"):
		_message.text = result.error
		return
	var problem := "" if editing else Store.playable_error(result.document)
	if not problem.is_empty():
		_message.text = problem + " Open Edit to finish this draft."
		return
	chosen.emit.call_deferred(result.document, entry.filename, editing)

static func install(menu: Node, container: Node) -> void:
	var browser: Window = load("res://scripts/level_editor/level_browser.gd").new()
	menu.add_child(browser)
	browser.hide()
	browser.chosen.connect(func(document: Dictionary, filename: String, editing: bool):
		var result := Store.launch(menu.get_tree(), document, filename, editing)
		if result != OK:
			browser._message.text = "Could not open the level: %s" % error_string(result)
	)
	var button := container.get_node_or_null("LevelEditorButton") as Button
	if button != null:
		button.pressed.connect(browser.show_levels)
		return
	button = Button.new()
	button.name = "LevelEditorButton"
	button.text = "Level editor / My levels"
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 26)
	var reference := container.get_node_or_null("SettingsButton") as Button
	if reference != null:
		for style in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(style, reference.get_theme_stylebox(style))
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color, reference.get_theme_color(color))
	container.add_child(button)
	container.move_child(button, 1)
	button.pressed.connect(browser.show_levels)
