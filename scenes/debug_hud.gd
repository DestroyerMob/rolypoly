@tool #Runs in the editor so VRAM and triangle count are visible while building
extends RichTextLabel

## Full strength. The row is telling the truth in this context.
const LIVE := "#ffffff"
## Dimmed. The row is still updating but the number does not mean what it
## says, so it should not compete for your attention.
const DIM := "#ffffff66"

## Master switch for this readout. Leave it off in anything you hand in.
@export var dev_mode := false:
	set(value):
		dev_mode = value
		_apply_enabled()


func _ready() -> void:
	#Job 1: Configure the node in code, as a debug tool that depends on three
	#       Inspector tickboxes being right is a debug tool that silently
	#       breaks when someone duplicates the scene.
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	_apply_enabled()


## Called from _ready and from the dev_mode setter, as the setter fires during
## scene load before the node is in the tree, where set_process does nothing.
func _apply_enabled() -> void:
	if not is_inside_tree():
		return
	#Job 1: Hide it AND stop the script, as an invisible node still runs
	#       _process and still reads eight monitors every frame.
	visible = dev_mode
	set_process(dev_mode)
	#Job 2: Never take input in the editor, as the toggle key would fight the
	#       editor's own shortcuts while you are trying to work.
	set_process_unhandled_input(dev_mode and not Engine.is_editor_hint())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_stats"):
		visible = not visible


func _process(_delta: float) -> void:
	#Job 1: Work out the context once, as it decides how every row is drawn.
	#       In the editor these monitors measure Godot itself, not your game:
	#       FPS is the editor's, physics never steps, and Process includes the
	#       @tool rebuilds in ArtBox and RugPlane.
	var in_editor := Engine.is_editor_hint()

	#Job 2: Third column is "still true in the editor". Only the two that
	#       survive get full strength there. At runtime everything is true, so
	#       the flag is ignored.
	var rows := [
		["FPS",             "%d"      % Performance.get_monitor(Performance.TIME_FPS), false],
		["Process",         "%.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0), false],
		["Physics",         "%.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0), false],
		["Objects drawn",   "%d"      % Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), false],
		["Primitives",      "%d"      % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), true],
		["Video memory",    "%.1f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), true],
		["Bodies active",   "%d"      % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), false],
		["Collision pairs", "%d"      % Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), false],
	]

	#Job 3: Pad each label to a fixed width so values line up in a column.
	#       The minus sign means left-align. Needs a monospace font to work.
	var out := "[b]PERF%s[/b]\n" % ("  (editor)" if in_editor else "")
	for row in rows:
		var meaningful: bool = (not in_editor) or bool(row[2])
		out += "[color=%s]%-16s %s[/color]\n" % [
			LIVE if meaningful else DIM,
			row[0],
			row[1],
		]
	text = out
