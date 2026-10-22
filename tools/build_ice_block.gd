extends SceneTree

const PATH := "res://scenes/levels/ice_block.tscn"
var level := Node3D.new()
var course := Node3D.new()
var mint := make_material(Color("69c6b7"))
var cream := make_material(Color("f2dfba"))
var brass := make_material(Color("b78a4d"), 0.65)
var timber := make_material(Color("986846"))
var dark := make_material(Color("213e3c"))

func _initialize() -> void:
	call_deferred("build")

func make_material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.48
	m.metallic = metallic
	return m

func attach(node: Node, parent: Node, title: String) -> Node:
	node.name = title
	parent.add_child(node)
	return node

func box(parent: Node, title: String, pos: Vector3, size: Vector3, material: Material, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	attach(body, parent, title)
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	attach(visual, body, "Mesh")
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		attach(collider, body, "Collision")
	return body

func board(title: String, a: Vector3, b: Vector3, width := 14.0, guarded := true) -> Node3D:
	var bridge := Node3D.new()
	attach(bridge, course, title)
	bridge.position = (a+b)*0.5 - Vector3(0,0.35,0)
	bridge.basis = Basis.looking_at(b-a, Vector3.UP)
	var length := a.distance_to(b)
	box(bridge, "WalkableBoard", Vector3.ZERO, Vector3(width, 0.7, length), timber)
	for x in [-1, 1]:
		if not guarded: continue
		box(bridge, "SafetyRim", Vector3(x*(width*.5-.2), .75, 0), Vector3(.4, 1.3, maxf(length-12,1)), brass)
	for x in range(-2, 3):
		box(bridge,"WoodGrain",Vector3(x*width/5.0,.36,0),Vector3(.04,.015,length-.2),dark,false)
	for z in range(3, int(length)-2, 7):
		var arrow := box(bridge,"RouteMarker",Vector3(0,.4,length/2.0-z),Vector3(1.1,.05,1.8),mint,false)
		arrow.rotation.y=PI/4
	return bridge

func label(parent: Node, title: String, pos: Vector3, value: String, color := Color("f2dfba"), size := 52) -> void:
	var l := Label3D.new()
	attach(l,parent,title)
	l.position=pos
	l.text=value
	l.font_size=size
	l.pixel_size=.014
	l.modulate=color
	l.outline_modulate=Color("18332f")
	l.outline_size=8
	l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test=false

func refill(parent: Node, title: String, pos: Vector3, caption: String) -> void:
	var station=load("res://scenes/props/ice_cube_upgrade.tscn").instantiate()
	station.set_script(load("res://scripts/ice_delivery/cooler.gd"))
	attach(station,parent,title)
	station.position=pos
	station.scale=Vector3.ONE*1.5
	station.get_node("UpgradeNode").position=Vector3(-4,1.5,0)
	label(station,"Sign",Vector3(0,6,0),caption+"\nICE REFILL • CHECKPOINT",Color("b6f4e3"),44)

func ui_label(parent: Node, title: String, value: String, font_size:=18) -> Label:
	var l:=Label.new()
	attach(l,parent,title)
	l.text=value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",Color("f2dfba"))
	return l

func dish(title: String, pos: Vector3) -> void:
	var body := AnimatableBody3D.new()
	body.set_script(load("res://scripts/obstacles/sinkable_dish.gd"))
	body.sink_depth = 2.0
	body.sink_speed = .75
	body.return_speed = 1.15
	body.bob_height = .015
	attach(body,course,title)
	body.position = pos
	var model = load("res://assets/models/obstacles/sink/SinkPlate.glb").instantiate()
	attach(model,body,"Model")
	model.scale = Vector3.ONE * 3.1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.4
	shape.height = .25
	collision.shape = shape
	collision.position.y = -.125
	attach(collision,body,"Collision")
	var sensor := Area3D.new()
	sensor.collision_layer = 0
	attach(sensor,body,"PlayerSensor")
	var sensor_shape := CollisionShape3D.new()
	var sensor_cylinder := CylinderShape3D.new()
	sensor_cylinder.radius = 3.2
	sensor_cylinder.height = .3
	sensor_shape.shape = sensor_cylinder
	sensor_shape.position.y = .35
	attach(sensor_shape,sensor,"Collision")

func progress(parent: Node, title: String, color: Color, width: float) -> void:
	var p:=ProgressBar.new()
	attach(p,parent,title)
	p.custom_minimum_size=Vector2(width,14)
	p.show_percentage=false
	p.value=100
	var fill:=StyleBoxFlat.new()
	fill.bg_color=color
	fill.set_corner_radius_all(4)
	p.add_theme_stylebox_override("fill",fill)
	var bg:=fill.duplicate()
	bg.bg_color=Color("384f49")
	p.add_theme_stylebox_override("background",bg)

func build() -> void:
	level.name="IceBlock"
	# Use Iroh's merged kitchen and its original dependencies. Convert only the
	# organizational nodes in this derived copy so the 1:4 scale propagates.
	var environment_text := FileAccess.get_file_as_string("res://scenes/level_editor/kitchen_interior.tscn")
	var header_end := environment_text.find("\n")
	environment_text = "[gd_scene format=4]" + environment_text.substr(header_end)
	environment_text = environment_text.replace('type="Node"', 'type="Node3D"')
	var environment_file := FileAccess.open("res://scenes/levels/ice_block_environment.tscn", FileAccess.WRITE)
	environment_file.store_string(environment_text)
	environment_file.close()
	var kitchen=load("res://scenes/levels/ice_block_environment.tscn").instantiate()
	attach(kitchen,level,"IrohKitchen")
	kitchen.scale=Vector3.ONE*.25
	attach(course,level,"Course")
	# One main route, supported by Iroh's existing table / island / counters.
	board("DiningToIslandRamp",Vector3(0,-4.6,-48),Vector3(0,.9,-114),10)
	board("IslandToSinkEntry",Vector3(20,-.4,-125),Vector3(35,-.4,-125),12,false)
	board("IslandToSinkExit",Vector3(63,.8,-125),Vector3(82,1.5,-125),12)
	# The detour trades extra ice/time for avoiding heat and crosswind.
	# Flat turning landings: a box-shaped ice shell cannot climb a small
	# vertical lip where two perpendicular sloping boards overlap.
	board("CoolDetourEntryRamp",Vector3(32,-.45,-125),Vector3(32,.15,-117),9,false)
	board("CoolDetourEntry",Vector3(32,.15,-117),Vector3(32,.15,-105),9,false)
	board("CoolDetourBridge",Vector3(32,.15,-105),Vector3(67,.15,-105),9)
	board("CoolDetourExit",Vector3(67,.15,-105),Vector3(67,.15,-111),9,false)
	board("CoolDetourExitRamp",Vector3(67,.15,-111),Vector3(67,1.1,-119),9,false)
	board("CoolDetourLanding",Vector3(67,1.1,-119),Vector3(67,1.1,-125),9,false)
	label(course,"RouteChoice",Vector3(30,7,-119),"CHOICE\nStraight: HOT + WIND\nSide loop: COOL, but longer",Color("b6f4e3"),38)
	# Two sinking plates replace the solid bridge over Iroh's real basin.
	board("SinkEntry",Vector3(82,1.15,-125),Vector3(82,1.15,-135.5),12)
	board("SinkExit",Vector3(82,1.15,-155),Vector3(82,1.15,-183),12)
	dish("SinkingPlateA",Vector3(79.5,1.15,-141.5))
	dish("SinkingPlateB",Vector3(84,1.15,-150))
	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(17,18)
	water_mesh.subdivide_width = 20
	water_mesh.subdivide_depth = 20
	water.mesh = water_mesh
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://assets/shaders/sink_water.gdshader")
	water.material_override = water_mat
	attach(water,course,"ChallengeWater")
	water.position = Vector3(82,-.9,-145)
	var rescue := Area3D.new()
	rescue.set_script(load("res://scripts/ice_delivery/water_rescue.gd"))
	attach(rescue,course,"WaterRescue")
	rescue.position = Vector3(82,-1.2,-145)
	var rescue_shape := CollisionShape3D.new()
	var rescue_box := BoxShape3D.new()
	rescue_box.size = Vector3(17,1.1,18)
	rescue_shape.shape = rescue_box
	attach(rescue_shape,rescue,"Collision")
	board("CounterServingRoute",Vector3(82,.6,-189),Vector3(63,.6,-189),15)
	# Raised counter loop: climb, balance on a live roller, turn back to the oven.
	board("RollerClimb",Vector3(65,.45,-184),Vector3(65,6.5,-175),11)
	board("RollerApproach",Vector3(65,6.5,-175),Vector3(65,6.5,-169),11,false)
	box(course,"RollerEntryLanding",Vector3(65,6.15,-169),Vector3(15,.7,11),timber)
	box(course,"RollerExitLanding",Vector3(35,6.15,-169),Vector3(15,.7,11),timber)
	var roller = load("res://scenes/obstacles/rolling_pin_spinner.tscn").instantiate()
	attach(roller,course,"CounterRoller")
	roller.position = Vector3(50,.35,-169)
	roller.rotation.y = PI/2
	roller.scale = Vector3.ONE*3
	roller.rotation_speed_degrees = 48.0
	# Supports sit below the rotating drum; no invisible flat bridge over it.
	for x in [40,60]:
		box(course,"RollerBearing",Vector3(x,1.85,-169),Vector3(1.5,2.8,5),dark)
	var roller_rescue := Area3D.new()
	roller_rescue.set_script(load("res://scripts/ice_delivery/water_rescue.gd"))
	attach(roller_rescue,course,"RollerCatch")
	roller_rescue.position=Vector3(50,1.4,-169)
	var catch_shape:=CollisionShape3D.new()
	var catch_box:=BoxShape3D.new()
	catch_box.size=Vector3(24,1,24)
	catch_shape.shape=catch_box
	attach(catch_shape,roller_rescue,"Collision")
	label(course,"RollerHint",Vector3(65,12,-177),"SPINNING PIN\nClimb • turn left • keep your balance",Color("b6f4e3"),30)
	board("CounterReturn",Vector3(35,6.5,-169),Vector3(35,6.5,-189),11,false)
	box(course,"ServingTurn",Vector3(35,6.15,-189),Vector3(11,.7,11),timber)
	board("SpoonRamp",Vector3(35,6.5,-189),Vector3(25,6.7631579,-189),11)
	var hot_board = board("TimedHotplate",Vector3(25,6.7631579,-189),Vector3(15,7.0263158,-189),11)
	var hot_floor = hot_board.get_node("WalkableBoard")
	hot_floor.set_script(load("res://scripts/ice_delivery/timed_hotplate.gd"))
	hot_floor.get_node("Mesh").material_override=make_material(Color("364b4a"),.4)
	for i in range(5):
		box(hot_floor,"HeatStripe%02d" % i,Vector3(0,.365,i*1.8-3.6),Vector3(10,.025,.25),make_material(Color("ad492e")),false)
	label(hot_floor,"HeatSign",Vector3(-7,4,0),"",Color("b6f4e3"),28)
	board("ServingFinish",Vector3(15,7.0263158,-189),Vector3(-3,7.5,-189),11)
	box(course,"IslandLanding",Vector3(0,-.05,-119),Vector3(20,.7,22),timber)
	box(course,"CornerLanding",Vector3(82,.25,-184),Vector3(17,.7,22),timber)
	# Reuse the team's working obstacles, separated by broad recovery landings.
	var masher=load("res://scenes/obstacles/masher.tscn").instantiate()
	masher.set_script(load("res://scripts/ice_delivery/combo_masher.gd"))
	attach(masher,course,"TimingMasher")
	masher.position=Vector3(0,-2.28,-76)
	masher.scale=Vector3.ONE*3.2
	masher.wait_time=2.6
	masher.hold_time=.65
	var second=load("res://scenes/obstacles/masher.tscn").instantiate()
	second.set_script(load("res://scripts/ice_delivery/combo_masher.gd"))
	second.position=Vector3(0,-.45,-98)
	second.scale=Vector3.ONE*3.2
	second.wait_time=2.6
	second.hold_time=.65
	second.phase_offset=2.4
	attach(second,course,"SecondMasher")
	label(course,"MasherHint",Vector3(0,6,-63),"DOUBLE PRESS\nCross one • brake on the mint rest • cross two",Color("ffb393"),35)
	box(course,"RestMarker",Vector3(0,-1.30,-87),Vector3(8,.04,5),mint,false)
	var ladle=load("res://scenes/obstacles/ladle.tscn").instantiate()
	attach(ladle,course,"SinkSweeper")
	ladle.position=Vector3(96,1.4,-147)
	ladle.rotation.y=PI
	ladle.scale=Vector3.ONE*3.0
	ladle.swing_angle_degrees=85.0
	ladle.swing_period=8.0
	box(course,"SweeperMount",Vector3(96,-.2,-147),Vector3(5,3,5),dark)
	label(course,"SweeperHint",Vector3(70,8,-143),"SINKING STEPS\nWatch spoon from the bank\nJump on • jump off before the plate sinks",Color("b6f4e3"),26)
	# A broad warm contact surface: visible red ceramic, not an invisible trigger.
	var heat=box(course,"WarmTray",Vector3(50,.65,-125),Vector3(17,.6,10),make_material(Color("934639")))
	board("WarmTrayEntry",Vector3(35,-.4,-125),Vector3(41,1.05,-125),10)
	board("WarmTrayExit",Vector3(57,.9,-125),Vector3(62.6,1.15,-125),10)
	heat.set_script(load("res://scripts/ice_delivery/heat.gd"))
	heat.ice_melt_seconds=4.0
	var fan=load("res://scenes/ice/crosswind_fan.tscn").instantiate()
	fan.scene_file_path=""
	fan.get_node("EffectZone").set_script(load("res://scripts/ice_delivery/gust.gd"))
	attach(fan,course,"HotTrayFan")
	fan.position=Vector3(50,-.4,-138)
	fan.scale=Vector3.ONE*2.5
	box(course,"FanShelf",Vector3(50,-.85,-135),Vector3(6,.9,10),dark)
	box(course,"FanShelfBrace",Vector3(50,-2,-131),Vector3(2,2,3),brass)
	label(fan,"WindSign",Vector3(0,6,0),"",Color("b6f4e3"),18)
	for i in range(6):
		box(heat,"HotGrillLine",Vector3(i*2.5-6.25,.32,0),Vector3(.15,.07,10),brass,false)
	label(heat,"Warning",Vector3(0,4,0),"HOT SHORTCUT\nDo not wait here",Color("ffb393"),34)
	var stations:=Node3D.new()
	attach(stations,level,"Refills")
	refill(stations,"01_DINING_TABLE",Vector3(0,-4.2,-18),"01 / START")
	refill(stations,"02_ISLAND",Vector3(10,.35,-120),"02 / ISLAND COOLER")
	refill(stations,"03_SINK_COOLER",Vector3(82,1.4,-133),"03 / SINK COOLER")
	refill(stations,"04_SERVING_COUNTER",Vector3(65,1,-189),"04 / ROLLER CLIMB")
	refill(stations,"05_ROLLER_EXIT",Vector3(35,6.65,-169),"05 / LAST REFILL")
	label(course,"RouteStart",Vector3(0,4,-43),"ICE BLOCK\nUp the board to the island",Color("e7d2a3"),56)
	# Actual plate collider and trigger, rather than a hidden coordinate launch.
	var launcher:=Node3D.new()
	launcher.set_script(load("res://scripts/ice_delivery/launcher.gd"))
	attach(load("res://models/ice_delivery/spring_server.glb").instantiate(),launcher,"Model")
	box(launcher,"Plate",Vector3(0,-.15,0),Vector3(8.8,.3,8.8),cream).get_node("Mesh").hide()
	var launch_area:=Area3D.new()
	attach(launch_area,launcher,"PickupArea")
	var launch_shape:=CollisionShape3D.new()
	var launch_box:=BoxShape3D.new()
	launch_box.size=Vector3(7,6,7)
	launch_shape.shape=launch_box
	launch_shape.position.y=3
	attach(launch_shape,launch_area,"Collision")
	label(launcher,"Sign",Vector3(0,9,0),"SPRING SERVER\nStep onto the plate • E",Color("b6f4e3"),44)
	launcher.name="SpringServer"
	set_branch_owners(launcher,launcher)
	var launcher_scene:=PackedScene.new()
	assert(launcher_scene.pack(launcher)==OK)
	assert(ResourceSaver.save(launcher_scene,"res://scenes/obstacles/ice_block_spring_server.tscn")==OK)
	launcher.free()
	var server=load("res://scenes/obstacles/ice_block_spring_server.tscn").instantiate()
	attach(server,course,"SpringServer")
	server.position=Vector3(-3,7.5,-189)
	board("ServerEntry",Vector3(12,6.0,-189),Vector3(.8,7.55,-189),10)
	# The target is independent and can be reused in the team's level.
	var mouth:=AnimatableBody3D.new()
	attach(mouth,course,"MovingMouth")
	mouth.position=Vector3(-23,14,-189)
	mouth.rotation.y=PI/2
	mouth.set_script(load("res://scripts/ice_delivery/mouth.gd"))
	attach(load("res://models/ice_delivery/moving_mouth.glb").instantiate(),mouth,"Model")
	# Rim collision follows the visual target. Interior remains open.
	for i in range(24):
		var a:=i*TAU/24.0
		var rim:=CollisionShape3D.new()
		var rim_shape:=BoxShape3D.new()
		rim_shape.size=Vector3(1.5,1.3,1.2)
		rim.shape=rim_shape
		rim.position=Vector3(cos(a)*6.15,sin(a)*5.15,0)
		rim.rotation.z=a+PI/2
		attach(rim,mouth,"Lip%02d" % i)
	# One moving body owns all lip shapes; nested synchronized bodies would
	# lag behind their moving parent and block an apparently empty opening.
	var mouth_transform:=mouth.transform
	course.remove_child(mouth)
	mouth.transform=Transform3D.IDENTITY
	set_branch_owners(mouth,mouth)
	var mouth_scene:=PackedScene.new()
	assert(mouth_scene.pack(mouth)==OK)
	assert(ResourceSaver.save(mouth_scene,"res://scenes/obstacles/moving_mouth_goal.tscn")==OK)
	mouth.free()
	var goal=load("res://scenes/obstacles/moving_mouth_goal.tscn").instantiate()
	attach(goal,course,"MovingMouth")
	goal.transform=mouth_transform
	box(course,"MouthSupportRail",Vector3(-25,5,-189),Vector3(3,1,29),brass)
	var rig=Node.new()
	rig.set_script(load("res://scenes/player_rig.gd"))
	attach(rig,level,"PlayerRig")
	var player=load("res://packed_scenes/player_ice_cream.tscn").instantiate()
	player.scene_file_path=""
	player.set_script(load("res://scripts/ice_delivery/scoop.gd"))
	attach(player,rig,"Player")
	player.position=Vector3(0,-.5,-18)
	player.speed_force=24.0
	player.bounciness=.05
	player.get_node("CollisionShape3D").scale=Vector3.ONE
	player.get_node("Trail").set_script(load("res://scripts/ice_delivery/trail.gd"))
	# The team's GLB import already applies 2x scale, matching its radius 2.2 collider.
	player.get_node("CollisionShape3D/MeshInstance3D").scale=Vector3.ONE
	var camera:=Camera3D.new()
	attach(camera,rig,"Camera3D")
	camera.set_script(load("res://scripts/ice_delivery/camera.gd"))
	camera.follow_distance=27.0
	camera.free_move_speed=30.0
	camera.far=650
	camera.fov=65
	var mount:=Node3D.new()
	attach(mount,level,"GadgetMount")
	mount.set_script(load("res://scripts/gadget_mount.gd"))
	mount.player_rig=rig
	mount.camera=camera
	var hud:=CanvasLayer.new()
	attach(hud,rig,"HUD")
	hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var margin:=MarginContainer.new()
	attach(margin,hud,"Margin")
	margin.position=Vector2(22,22)
	var panel:=PanelContainer.new()
	attach(panel,margin,"Panel")
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.035,.09,.085,.92)
	style.set_corner_radius_all(12)
	style.content_margin_left=20
	style.content_margin_right=20
	style.content_margin_top=16
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	var rows:=VBoxContainer.new()
	attach(rows,panel,"Rows")
	rows.add_theme_constant_override("separation",9)
	ui_label(rows,"Title","ICE BLOCK",24)
	ui_label(rows,"CoreLabel","SCOOP / 3 health",15)
	var health:=HBoxContainer.new()
	attach(health,rows,"Health")
	for i in range(3): progress(health,"Cell%d"%i,Color("f5d79b"),92)
	ui_label(rows,"IceLabel","ICE SHELL",15)
	progress(rows,"Shell",Color("69c6db"),284)
	ui_label(rows,"State","01 / DINING TABLE",16)
	ui_label(rows,"Objective","Reach the moving mouth",14)
	ui_label(rows,"Controls","WASD move · Space jump · R checkpoint\nArrows look · C recenter · V overview\nTab free camera · E spring server",13)
	var result:=PanelContainer.new()
	attach(result,hud,"Result")
	result.position=Vector2(480,220)
	result.custom_minimum_size=Vector2(410,250)
	result.add_theme_stylebox_override("panel",style)
	result.hide()
	var result_rows:=VBoxContainer.new()
	attach(result_rows,result,"Rows")
	ui_label(result_rows,"Title","DELIVERED!",32)
	ui_label(result_rows,"Stars","★★★",50)
	ui_label(result_rows,"Detail","",19)
	# Broad ambient fill keeps Iroh's material details readable beneath his ceiling.
	var env:=WorldEnvironment.new()
	attach(env,level,"DeliveryLighting")
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("96b4bb")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("fff0d5")
	env.environment.ambient_light_energy=.45
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	camera.environment=env.environment
	var sun:=DirectionalLight3D.new()
	attach(sun,level,"SoftKey")
	sun.rotation_degrees=Vector3(-55,-35,0)
	sun.light_energy=.75
	sun.shadow_enabled=false
	level.set_script(load("res://scripts/ice_delivery/level.gd"))
	set_owners(level)
	var packed:=PackedScene.new()
	assert(packed.pack(level)==OK)
	assert(ResourceSaver.save(packed,PATH)==OK)
	print("SAVED ",PATH)
	level.free()
	quit()

func set_owners(parent: Node) -> void:
	for child in parent.get_children():
		child.owner=level
		if child.scene_file_path.is_empty():
			set_owners(child)

func set_branch_owners(parent: Node, scene_root: Node) -> void:
	for child in parent.get_children():
		child.owner=scene_root
		if child.scene_file_path.is_empty():
			set_branch_owners(child,scene_root)
