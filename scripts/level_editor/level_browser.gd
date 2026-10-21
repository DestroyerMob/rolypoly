extends Window
signal chosen(document: Dictionary, filename: String, editing: bool)
signal deleted(filename: String)
signal moved(from_filename: String, to_filename: String)
signal set_changed
const EditorTheme = preload("res://scripts/level_editor/editor_theme.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
var _list: ItemList
var _message: Label
var _entries: Array = []
var _delete_button: Button
var _add_button: Button
var _remove_button: Button
var _up_button: Button
var _down_button: Button

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
	var set_row := HBoxContainer.new()
	column.add_child(set_row)
	var editor_only := "" if Store.can_edit_set() else " Run the game from the Godot editor to change the level list."
	_add_button = _set_button(set_row, "Add level", _add,
		"Add this level to the game's level list (the levels/ folder), as the last numbered level in Play. Commit it to share it." + editor_only)
	_remove_button = _set_button(set_row, "Remove level", _remove,
		"Take this level out of the level list and back into your saved levels." + editor_only)
	_up_button = _set_button(set_row, "Move up", _move.bind(-1), "Play this level earlier in the level list." + editor_only)
	_down_button = _set_button(set_row, "Move down", _move.bind(1), "Play this level later in the level list." + editor_only)

func _set_button(row: HBoxContainer, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tip
	button.disabled = true
	button.pressed.connect(action)
	row.add_child(button)
	return button

func show_levels() -> void:
	_refresh_levels()
	popup_centered()

func _refresh_levels() -> void:
	_entries = Store.list_levels()
	_list.clear()
	for button in [_delete_button, _add_button, _remove_button, _up_button, _down_button]:
		button.disabled = true
	for entry in _entries:
		var label: String = ("Level %d · %s" % [entry.number, entry.name]) if entry.number > 0 else entry.name
		_list.add_item(label + (" — draft / unavailable" if not entry.error.is_empty() else ""))
	_message.text = "Choose a saved level to play or edit." if not _entries.is_empty() else "No saved levels yet. Create a new level to get started."

func _select(index: int) -> void:
	var entry: Dictionary = _entries[index]
	var bundled := Store.is_bundled(entry.filename)
	var editable := Store.can_edit_set()
	var count := Store.level_set().size()
	_delete_button.disabled = bundled
	_add_button.disabled = bundled or not editable or not entry.error.is_empty() or count >= Store.MAX_LEVELS
	_remove_button.disabled = not bundled or not editable
	_up_button.disabled = not editable or entry.number <= 1
	_down_button.disabled = not editable or entry.number == 0 or entry.number >= count
	if not entry.error.is_empty():
		_message.text = entry.error
	elif entry.number > 0:
		_message.text = "Level %d in the level list (levels/%s). Ready to play." % [entry.number, entry.filename]
	elif editable and count >= Store.MAX_LEVELS:
		_message.text = "Ready to play. The Play menu's %d slots are full; remove a level from the list before adding another." % Store.MAX_LEVELS
	else:
		_message.text = "Ready to play." + (" Add it to the level list to make it a numbered level in Play." if editable else "")

func _selected_index() -> int:
	return _list.get_selected_items()[0] if not _list.get_selected_items().is_empty() else -1

func _reselect(filename: String) -> void:
	for index in _entries.size():
		if _entries[index].filename == filename:
			_list.select(index)
			_select(index)

func _add() -> void:
	var index := _selected_index()
	if index < 0:
		return
	var entry: Dictionary = _entries[index]
	var result := Store.add_to_set(entry.filename)
	if result.has("error"):
		_message.text = result.error
		return
	_refresh_levels()
	_reselect(result.filename)
	_message.text = "Added “%s” as Level %d (levels/%s). Commit the levels folder to share it." % [entry.name, result.number, result.filename]
	moved.emit(entry.filename, result.filename)
	set_changed.emit()

func _remove() -> void:
	var index := _selected_index()
	if index < 0:
		return
	var entry: Dictionary = _entries[index]
	var result := Store.remove_from_set(entry.filename)
	if result.has("error"):
		_message.text = result.error
		return
	_refresh_levels()
	_reselect(result.filename)
	_message.text = "Removed “%s” from the level list. It's back in your saved levels." % entry.name
	moved.emit(entry.filename, result.filename)
	set_changed.emit()

func _move(offset: int) -> void:
	var index := _selected_index()
	if index < 0:
		return
	var entry: Dictionary = _entries[index]
	var result := Store.move_in_set(entry.filename, offset)
	if result.has("error"):
		_message.text = result.error
		return
	_refresh_levels()
	_reselect(entry.filename)
	_message.text = "“%s” is now Level %d." % [entry.name, result.number]
	set_changed.emit()

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

static func install(menu: Node, container: Node) -> Window:
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
		return browser
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
	return browser
