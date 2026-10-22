extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func point(p: Vector3) -> Vector2:
	return Vector2(p.x + 15, p.z + 62) * 3.15 + Vector2(12, 34)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO,Vector2(255,290)))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(16,23),"EXPLORE THE KITCHEN",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ecd8ae"))
	var links := [[Vector3(0,0,6),Vector3(0,0,-23)],[Vector3(0,0,-23),Vector3(18,0,-23)],[Vector3(18,0,-23),Vector3(18,0,-53)],[Vector3(18,0,-53),Vector3(-3,0,-53)],[Vector3(1,0,-23),Vector3(1,0,-35)],[Vector3(1,0,-35),Vector3(18,0,-35)],[Vector3(1,0,-35),Vector3(0,0,-53)],[Vector3(1,0,-35),Vector3(-7,0,-42)],[Vector3(18,0,-24),Vector3(42,0,-24)],[Vector3(42,0,-24),Vector3(42,0,-40)],[Vector3(42,0,-40),Vector3(18,0,-40)],[Vector3(26,0,-40),Vector3(26,0,-52)],[Vector3(26,0,-52),Vector3(18,0,-53)],[Vector3(26,0,-28),Vector3(40,0,-36)]]
	for link in links:
		draw_line(point(link[0]),point(link[1]),Color("427278"),7,true)
	for entry in [["FREEZER",Vector3(-11,0,-47)],["HUB",Vector3(-2,0,-33)],["LAGOON",Vector3(29,0,-31)],["DESSERT",Vector3(-6,0,-56)]]:
		draw_string(font,point(entry[1]),entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("adcfd1"))
	var level := get_tree().current_scene
	if not level:
		return
	for child in level.get_children():
		if child.name.begins_with("Crystal_") and child.visible:
			draw_circle(point(child.position),4,Color("80edff"))
	var player := level.get_node_or_null("Player") as Node3D
	if player:
		draw_circle(point(player.position),5,Color("ffd68a"))
		draw_circle(point(player.position),7,Color.WHITE,false,1.5)
	draw_string(font,Vector2(14,276),"● YOU    • ICE CRYSTALS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ecd8ae"))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.09,.11,.9)
	style.set_corner_radius_all(14)
	return style
