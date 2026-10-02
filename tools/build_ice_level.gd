extends SceneTree

const DIR := "res://scenes/ice/"
const KIT := "res://assets/models/ice_kitchen/"
var root_scene: Node3D
var cream: Material
var teal: Material
var brass: Material
var oak: Material
var marble: Material
var dark: Material
var cold: Material
var hot: Material
var tile: Material

func _initialize() -> void:
	call_deferred("build")

func material(color: Color, metal := 0.0, rough := 0.45, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func surface(color: Color, style: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ice_kitchen_surface.gdshader")
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("style", style)
	return m

func mesh(parent: Node, name_: String, primitive: Mesh, p: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	n.mesh = primitive
	n.material_override = mat
	n.position = p
	parent.add_child(n,true)
	return n

func box(parent: Node, name_: String, p: Vector3, size_: Vector3, mat: Material, solid := false) -> Node3D:
	var m := BoxMesh.new()
	m.size = size_
	if not solid:
		return mesh(parent, name_, m, p, mat)
	var b := StaticBody3D.new()
	b.name = name_
	b.position = p
	parent.add_child(b,true)
	mesh(b, "Surface", m, Vector3.ZERO, mat)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_
	c.shape = shape
	b.add_child(c)
	return b

func cylinder(parent: Node, name_: String, p: Vector3, radius: float, height: float, mat: Material, solid := false) -> Node3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 48
	if not solid:
		return mesh(parent, name_, m, p, mat)
	var b := StaticBody3D.new()
	b.name = name_
	b.position = p
	parent.add_child(b,true)
	mesh(b,"Surface",m,Vector3.ZERO,mat)
	var c := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	c.shape = shape
	b.add_child(c)
	return b

func sphere(parent: Node, name_: String, p: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return mesh(parent, name_, m, p, mat)

func ring(parent: Node, p: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radius - 0.035
	m.outer_radius = radius + 0.035
	m.rings = 48
	return mesh(parent,"Ring",m,p,mat)

func model(parent: Node, file: String, p := Vector3.ZERO) -> Node3D:
	var n := (load(KIT + file + ".glb") as PackedScene).instantiate() as Node3D
	n.position = p
	parent.add_child(n,true)
	return n

func sign_(parent: Node, words: String, p: Vector3, size_ := 40, color := Color("ecd9ac")) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.position = p
	label.font_size = size_
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 19.0
	label.visibility_range_end_margin = 4.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(label,true)
	return label

func zone(parent: Node, kind: int, p: Vector3, size_: Vector3) -> Area3D:
	var n := Area3D.new()
	n.set_script(load("res://scripts/ice/ice_zone.gd"))
	n.name = "EffectZone"
	n.set("kind", kind)
	n.collision_layer = 0
	n.position = p
	parent.add_child(n,true)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size_
	c.shape = s
	n.add_child(c)
	return n

func own(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		# Preserve packed model/component instances instead of duplicating their internals.
		if child.scene_file_path.is_empty():
			own(child,owner_)

func save_scene(node: Node3D, path: String) -> void:
	own(node,node)
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed,path)
	assert(err == OK, "Failed saving " + path)

func reusable(name_: String) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	return n

func components() -> void:
	var n := reusable("Hotplate")
	model(n,"Hotplate")
	box(n,"ContactSurface",Vector3(0,-.14,0),Vector3(5.8,.28,4.6),dark,true)
	zone(n,0,Vector3(0,.4,0),Vector3(5.6,.9,4.4))
	for x in [-1.45,1.45]:
		for z in [-1.1,1.1]:
			for r in [.30,.51,.73]:
				ring(n,Vector3(x,.09,z),r,hot)
	save_scene(n,DIR+"hotplate.tscn")
	n.free()
	n = reusable("ColdStation")
	model(n,"ColdStation")
	box(n,"TraySurface",Vector3(0,-.13,0),Vector3(3.8,.26,3.2),teal,true)
	zone(n,1,Vector3(0,.45,0),Vector3(3.6,1.1,3.0))
	ring(n,Vector3(0,.08,0),.8,cold)
	sign_(n,"ICE / REFILL",Vector3(0,1.65,-1.5),30,Color("89e3ed"))
	save_scene(n,DIR+"cold_station.tscn")
	n.free()
	n = reusable("CrosswindFan")
	model(n,"FanHousing")
	var spin := Node3D.new()
	spin.name = "SpinningBlades"
	spin.set_script(load("res://scripts/ice/ice_motion.gd"))
	spin.set("axis",Vector3.BACK)
	spin.set("speed",12.0)
	spin.position = Vector3(0,2.15,0)
	n.add_child(spin)
	model(spin,"FanBlades")
	var wind := zone(n,2,Vector3(0,1.6,4.7),Vector3(3.5,3.2,8.0))
	wind.set("direction",Vector3.BACK)
	wind.set("strength",11.0)
	wind.set("pulse_period",5.0)
	for i in range(6):
		var stripe := box(n,"AirRibbon",Vector3(-1.2+(i%3)*1.2,.8+(i/3)*.8,3.7),Vector3(.035,.035,4.0),cold)
		stripe.set_script(load("res://scripts/ice/ice_motion.gd"))
		stripe.set("mode",2)
		stripe.set("axis",Vector3.BACK)
		stripe.set("travel",.7)
		stripe.set("speed",2.0+i*.1)
	save_scene(n,DIR+"crosswind_fan.tscn")
	n.free()
	n = reusable("RotatingIcePlatter")
	var body := AnimatableBody3D.new()
	body.name = "RotatingPlatform"
	body.set_script(load("res://scripts/ice/ice_motion.gd"))
	body.set("speed",.30)
	n.add_child(body)
	var m := CylinderMesh.new()
	m.top_radius = 3.4
	m.bottom_radius = 3.4
	m.height = .3
	mesh(body,"Porcelain",m,Vector3.ZERO,cream)
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius=3.4
	s.height=.3
	c.shape=s
	body.add_child(c)
	for i in range(8):
		var a := i * TAU / 8
		box(body,"BlueInlay",Vector3(sin(a)*2.4,.17,cos(a)*2.4),Vector3(.55,.025,.55),cold)
	ring(body,Vector3(0,.17,0),3.15,brass)
	save_scene(n,DIR+"rotating_ice_platter.tscn")
	n.free()
	n = reusable("SteamKettle")
	sphere(n,"CopperBody",Vector3(0,.65,0),.95,brass)
	cylinder(n,"Lid",Vector3(0,1.38,0),.60,.12,teal)
	sphere(n,"LidKnob",Vector3(0,1.53,0),.16,dark)
	var spout := cylinder(n,"Spout",Vector3(0,.8,1.0),.22,1.1,brass)
	spout.rotation.x = .7
	var handle := ring(n,Vector3(0,1.25,-.25),.9,dark)
	handle.rotation.x=PI/2
	var steam := zone(n,3,Vector3(0,1.8,2.7),Vector3(3.2,4,3.2))
	steam.set("strength",32.0)
	steam.set("direction",Vector3(.35,1,.28))
	steam.set("pulse_period",5.0)
	for i in range(5):
		var cloud := ring(n,Vector3(0,.6+i*.65,2.7),.35+i*.12,cold)
		cloud.set_script(load("res://scripts/ice/ice_motion.gd"))
		cloud.set("mode",2)
		cloud.set("travel",.18)
		cloud.set("speed",2.0)
	save_scene(n,DIR+"steam_kettle.tscn")
	n.free()
	n = reusable("FreezerDoor")
	var door := AnimatableBody3D.new()
	door.name = "SlidingDoor"
	door.set_script(load("res://scripts/ice/ice_motion.gd"))
	door.set("mode",1)
	door.set("speed",.7)
	door.set("axis",Vector3.UP)
	door.set("travel",3.2)
	n.add_child(door)
	var dm := BoxMesh.new()
	dm.size=Vector3(3.6,2.5,.26)
	mesh(door,"Enamel",dm,Vector3(0,1.25,0),teal)
	var dc := CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size=dm.size
	dc.shape=ds
	dc.position.y=1.25
	door.add_child(dc)
	box(door,"Handle",Vector3(1.3,1.2,.24),Vector3(.12,1.0,.12),brass)
	for x in [-2.0,2.0]:
		box(n,"Frame",Vector3(x,2.75,0),Vector3(.28,5.5,.5),cream)
	box(n,"FrameTop",Vector3(0,5.5,0),Vector3(4.3,.3,.5),cream)
	save_scene(n,DIR+"freezer_door.tscn")
	n.free()

func instance(file: String, p: Vector3, yaw := 0.0) -> Node3D:
	var n := (load(DIR+file+".tscn") as PackedScene).instantiate() as Node3D
	n.position=p
	n.rotation.y=yaw
	root_scene.add_child(n,true)
	return n

func counter(name_: String, p: Vector3, size_: Vector3) -> void:
	box(root_scene,name_+"Cabinet",p-Vector3(0,1.5,0),Vector3(size_.x,2.6,size_.z),teal)
	box(root_scene,name_+"Plinth",p-Vector3(0,2.83,0),Vector3(size_.x+.08,.16,size_.z+.08),dark)
	box(root_scene,name_+"Top",p-Vector3(0,.15,0),Vector3(size_.x+.18,.3,size_.z+.18),marble,true)
	# Recessed front panels and brass handles on the long sides.
	var count := maxi(1,int(size_.z / 3.0))
	for i in range(count):
		var z := p.z-size_.z/2+1.5+i*3
		for side in [-1,1]:
			box(root_scene,"CabinetPanel",Vector3(p.x+side*(size_.x/2+.015),p.y-1.5,z),Vector3(.08,2.0,2.65),material(Color("17484b")))
			box(root_scene,"BrassPull",Vector3(p.x+side*(size_.x/2+.12),p.y-.8,z),Vector3(.08,.10,.75),brass)

func trail(a: Vector3, b: Vector3) -> void:
	var steps := int(a.distance_to(b)/1.8)
	for i in range(steps):
		cylinder(root_scene,"FrostTrail",a.lerp(b,float(i)/maxi(steps,1)),.075,.018,cold)

func crystal(id: String, p: Vector3) -> void:
	var pickup := Area3D.new()
	pickup.name = "Crystal_" + id
	pickup.set_script(load("res://scripts/ice/ice_crystal.gd"))
	pickup.set("crystal_id", id)
	pickup.position = p
	pickup.collision_layer = 0
	root_scene.add_child(pickup)
	var shape := CollisionShape3D.new()
	var radius := SphereShape3D.new()
	radius.radius = 0.85
	shape.shape = radius
	pickup.add_child(shape)
	var gem := BoxMesh.new()
	gem.size = Vector3(.55,.8,.55)
	var visual := mesh(pickup,"Gem",gem,Vector3.ZERO,cold)
	visual.rotation.z = PI / 4
	ring(pickup,Vector3(0,-.45,0),.62,brass)
	sign_(pickup,"ICE CRYSTAL",Vector3(0,1,0),20,Color("89e3ed"))

func build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	cream=material(Color("dfd7be"),0,.32)
	teal=material(Color("17494b"),.15,.3)
	brass=material(Color("bb8748"),.75,.28)
	dark=material(Color("182c32"),.3,.3)
	cold=material(Color("79deed"),.2,.18,.8)
	hot=material(Color("ed642b"),.1,.4,2.0)
	oak=surface(Color("956039"),1)
	marble=surface(Color("e4ddc9"),0)
	tile=material(Color("8bb4b3"),.1,.25)
	components()
	root_scene=Node3D.new()
	root_scene.name="IceBlockKitchen"
	root_scene.set_script(load("res://scripts/ice/ice_level.gd"))
	# Spacious three-act kitchen; counter tops are at Y=3 and Y=5.
	counter("Breakfast",Vector3(0,3,-6),Vector3(12,0,30))
	counter("WindowBridge",Vector3(9,3,-23),Vector3(30,0,8))
	counter("Cookery",Vector3(18,3,-35),Vector3(12,0,32))
	counter("Dessert",Vector3(3,5,-53),Vector3(24,0,10))
	# Two generous timber ramps take the route up to the dessert counter.
	var ramp := box(root_scene,"OakRamp",Vector3(18,3.87,-47.5),Vector3(6,.28,9.6),oak,true)
	ramp.rotation.x=deg_to_rad(15.945)
	box(root_scene,"RampLanding",Vector3(18,4.82,-53),Vector3(6,.36,4),marble,true)
	box(root_scene,"DessertLink",Vector3(13.8,4.82,-53),Vector3(3.0,.36,6),oak,true)
	# Entire floor is visual: falling returns to a station instead of trapping the player.
	box(root_scene,"RoomFloor",Vector3(18,-.4,-25),Vector3(72,.4,92),material(Color("b6a289"),0,.85))
	box(root_scene,"BackWall",Vector3(18,8,-62),Vector3(72,18,.5),cream)
	box(root_scene,"SideWall",Vector3(-14,8,-25),Vector3(.5,18,74),cream)
	var grout := material(Color("9b8d79"),0,.9)
	for z in range(-70,22,4):
		box(root_scene,"FloorJoint",Vector3(18,-.185,z),Vector3(72,.015,.035),grout)
	for x in range(-16,55,4):
		box(root_scene,"FloorJoint",Vector3(x,-.185,-25),Vector3(.035,.015,92),grout)
	# Blue tile backsplash and framed windows.
	for row in range(4):
		for col in range(22):
			box(root_scene,"GlazedTile",Vector3(-12.8,1+row*1.25,-59+col*3.1),Vector3(.16,1.17,3.00),tile if (row+col)%3 else cream)
	for z in [-9,-29,-49]:
		box(root_scene,"WindowReveal",Vector3(-13.5,9,z),Vector3(.65,8.5,12.2),teal)
		box(root_scene,"WindowSky",Vector3(-13.1,9,z),Vector3(.1,7.5,11.2),material(Color("b7d8db"),0,.8,.35))
		for dz in [-5.5,0,5.5]:
			box(root_scene,"WindowMullion",Vector3(-12.95,9,z+dz),Vector3(.3,7.8,.15),cream)
		box(root_scene,"WindowCrossbar",Vector3(-12.95,9,z),Vector3(.3,.15,11.3),cream)
		box(root_scene,"WindowSill",Vector3(-12.6,5.2,z),Vector3(1.7,.25,13),marble)
	# Start / cool / hot / wind / open exploration / combined section / dessert.
	instance("cold_station",Vector3(0,3.08,5))
	instance("hotplate",Vector3(0,3.08,-3))
	instance("cold_station",Vector3(0,3.08,-10))
	instance("crosswind_fan",Vector3(-5,3,-16),PI/2)
	instance("cold_station",Vector3(1,3.08,-22))
	instance("rotating_ice_platter",Vector3(9,2.96,-23))
	instance("cold_station",Vector3(18,3.08,-24))
	instance("freezer_door",Vector3(18,3,-31))
	instance("crosswind_fan",Vector3(23,3,-37),-PI/2)
	instance("hotplate",Vector3(18,3.08,-40))
	instance("cold_station",Vector3(18,3.08,-45))
	instance("cold_station",Vector3(9,5.08,-53))
	# Optional kettle ride to a recipe-book balcony. A ramp provides a relaxed return.
	instance("steam_kettle",Vector3(.8,3,-16))
	box(root_scene,"RecipeBalcony",Vector3(5,5.7,-9),Vector3(5,.4,5),oak,true)
	var balcony_ramp := box(root_scene,"BalconyReturn",Vector3(4.6,4.50,-3.0),Vector3(2.8,.25,8.5),oak,true)
	balcony_ramp.rotation.x=deg_to_rad(21)
	instance("cold_station",Vector3(5,5.94,-9))
	sign_(root_scene,"STEAM EXPRESS\nOptional rooftop picnic",Vector3(5,7.9,-12),28)
	crystal("freezer",Vector3(-7,4.25,-42))
	crystal("lagoon",Vector3(36,3.85,-32))
	crystal("recipe",Vector3(3,5.9,-56))
	# Safe lanes visibly skirt heat and fan areas. Plenty of room to experiment.
	for z in [-3,-16,-40]:
		var x := 0.0 if z > -25 else 18.0
		box(root_scene,"CoolLane",Vector3(x+4,3.02,z),Vector3(1.5,.025,5.0),tile)
	# Low counter-edge guards catch slight steering mistakes but leave views open.
	for x in [-5.7,5.7,12.3,23.7]:
		var center_z := -6.0 if x < 10 else -35.0
		box(root_scene,"CounterLip",Vector3(x,3.13,center_z),Vector3(.13,.26,27),brass,true)
	# Destination: small ramp enters the ice-cold bowl.
	model(root_scene,"DessertBowl",Vector3(-3,5,-53))
	var goal_ramp := box(root_scene,"DessertSpoon",Vector3(.0,5.50,-53),Vector3(5.2,.2,1.6),oak,true)
	goal_ramp.rotation.z=deg_to_rad(-12)
	zone(root_scene,4,Vector3(-3,6.15,-53),Vector3(2.6,1.2,2.6))
	cylinder(root_scene,"DessertLanding",Vector3(-3,5.99,-53),1.55,.25,cold,true)
	sign_(root_scene,"THE COLD TABLE\nBring your ice to dessert",Vector3(-3,9,-55),42)
	for pair in [[Vector3(0,3.025,7),Vector3(0,3.025,-23)],[Vector3(0,3.025,-23),Vector3(18,3.025,-23)],[Vector3(18,3.025,-24),Vector3(18,3.025,-46)],[Vector3(10,5.025,-53),Vector3(-1,5.025,-53)]]:
		trail(pair[0],pair[1])
	sign_(root_scene,"THE FROZEN KITCHEN\nThree crystals. Your own route.",Vector3(0,6,7),32)
	sign_(root_scene,"Warm rings melt your coat\nWalk around, or roll across",Vector3(0,5.8,-3),28)
	sign_(root_scene,"02 / THE BREEZE BAR\nA full ice coat catches more wind",Vector3(8,6,-23),32)
	sign_(root_scene,"03 / AFTERNOON SERVICE\nDoorway or side lane — your choice",Vector3(18,7,-30),32)
	exploration_wings()
	dressing()
	player_and_lighting()
	hud()
	save_scene(root_scene,"res://scenes/levels/ice_block_kitchen.tscn")
	root_scene.free()
	print("ICE BLOCK KITCHEN BUILT")
	quit()

func bridge(name_: String, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var plank := box(root_scene,name_,(a+b)*.5-Vector3(0,.12,0),Vector3(width,.24,a.distance_to(b)+.6),mat,true)
	plank.basis = Basis.looking_at((b-a).normalized(),Vector3.UP)
	for side in [-1,1]:
		box(plank,"EdgeInlay",Vector3(side*(width*.5-.10),.13,0),Vector3(.08,.015,a.distance_to(b)),brass)

func floe(p: Vector3, index: int) -> void:
	var body := AnimatableBody3D.new()
	body.name="FloatingIce"+str(index)
	body.position=p
	body.set_script(load("res://scripts/obstacles/sinkable_dish.gd"))
	body.set("sink_depth",.32)
	body.set("sink_speed",.10)
	body.set("return_speed",.26)
	body.set("phase_degrees",index*37.0)
	root_scene.add_child(body)
	var polygon := CylinderMesh.new()
	polygon.top_radius=1.85
	polygon.bottom_radius=1.62
	polygon.height=.38
	polygon.radial_segments=7
	mesh(body,"Ice",polygon,Vector3.ZERO,material(Color("87dbe2"),.12,.22))
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius=1.78
	shape.height=.38
	collider.shape=shape
	body.add_child(collider)
	var sensor := Area3D.new()
	sensor.name="PlayerSensor"
	sensor.collision_layer=0
	sensor.position.y=.60
	body.add_child(sensor)
	var sensor_collider := CollisionShape3D.new()
	var sensor_shape := CylinderShape3D.new()
	sensor_shape.radius=1.7
	sensor_shape.height=1.0
	sensor_collider.shape=sensor_shape
	sensor.add_child(sensor_collider)
	for i in range(3):
		var crack := box(body,"IceVein",Vector3(0,.196,0),Vector3(.035,.015,2.4),cream)
		crack.rotation.y=i*PI/3

func exploration_wings() -> void:
	# A central hub joins north, east and south. These links form actual loops,
	# not a single winding corridor. Every optional region has a broad approach.
	counter("ColdDrinksHub",Vector3(1,3,-35),Vector3(12,0,10))
	bridge("HubNorth",Vector3(1,3,-26),Vector3(1,3,-31),4.5,oak)
	bridge("HubEast",Vector3(6.5,3,-35),Vector3(13,3,-35),4.0,oak)
	bridge("HubDessert",Vector3(0,3,-39),Vector3(0,5,-49),4.2,oak)
	bridge("FreezerWalk",Vector3(-3,3,-38),Vector3(-7,3.5,-40.5),4.0,tile)
	instance("rotating_ice_platter",Vector3(1,2.96,-35))
	instance("cold_station",Vector3(3,3.08,-38))
	sign_(root_scene,"COLD DRINKS CLUB\nFREEZER ←   → ICE LAGOON\nDESSERT ↑",Vector3(1,6.6,-36),30)
	model(root_scene,"FreezerCabinet",Vector3(-7,0,-42))
	box(root_scene,"FreezerShelf",Vector3(-7,3.4,-42),Vector3(7.65,.2,3.8),tile,true)
	box(root_scene,"FreezerBack",Vector3(-7,4,-43.9),Vector3(8,8,.25),tile,true)
	for x in [-11,-3]:
		box(root_scene,"FreezerSide",Vector3(x,4,-42),Vector3(.3,8,4),teal,true)
	zone(root_scene,1,Vector3(-7,4.05,-42),Vector3(7.4,1.3,3.6))
	sign_(root_scene,"THE FROST VAULT\nCold storage / Crystal 01",Vector3(-7,8.8,-42),34,Color("89e3ed"))
	var freezer_light := OmniLight3D.new()
	freezer_light.position=Vector3(-7,5.2,-40.5)
	freezer_light.light_color=Color("86dcff")
	freezer_light.light_energy=2.0
	freezer_light.omni_range=7
	root_scene.add_child(freezer_light)
	# Sink island has two connections to cookery, a perimeter path and a floating
	# interior route. The floes dip gently under the player, then rise again.
	model(root_scene,"IceSink",Vector3(34,3,-32))
	box(root_scene,"SinkCabinet",Vector3(34,.3,-32),Vector3(16,.4,14),teal)
	for x in [25.5,42.5]:
		box(root_scene,"SinkWalkway",Vector3(x,2.85,-32),Vector3(3,.3,18),marble,true)
	for z in [-23.5,-40.5]:
		box(root_scene,"SinkWalkway",Vector3(34,2.85,z),Vector3(20,.3,3),marble,true)
	bridge("LagoonNorthLink",Vector3(23,3,-24),Vector3(27,3,-24),3.5,oak)
	bridge("LagoonSouthLink",Vector3(23,3,-40),Vector3(27,3,-40),3.5,oak)
	instance("cold_station",Vector3(25.4,3.08,-26))
	var water := PlaneMesh.new()
	water.size=Vector2(15,13)
	water.subdivide_width=40
	water.subdivide_depth=40
	var water_mat := ShaderMaterial.new()
	water_mat.shader=load("res://assets/shaders/sink_water.gdshader")
	water_mat.set_shader_parameter("shallow_color",Color(.08,.56,.65,.78))
	mesh(root_scene,"GlacialWater",water,Vector3(34,2.35,-32),water_mat)
	zone(root_scene,5,Vector3(34,1.1,-32),Vector3(15,1.0,13))
	var positions := [Vector3(27.5,2.97,-27.5),Vector3(30.3,2.97,-29),Vector3(33.1,2.97,-30.5),Vector3(36,2.97,-32),Vector3(38.8,2.97,-33.5),Vector3(40.4,2.97,-36.3)]
	for i in range(positions.size()):
		floe(positions[i],i)
	bridge("FloeBoarding",Vector3(25.5,3,-27.5),Vector3(27.5,3,-27.5),2.7,oak)
	bridge("FloeExit",Vector3(40.4,3,-36.3),Vector3(42.5,3,-36.3),2.7,oak)
	sign_(root_scene,"THE ICE LAGOON\nFloes dip, then rise again\nPerimeter path or island hopping",Vector3(34,7,-34),30,Color("89e3ed"))
	# A second high-level connection closes a larger kitchen loop.
	bridge("UpperReturn",Vector3(26,3,-40.5),Vector3(26,5,-51.5),3.5,oak)
	bridge("DessertEast",Vector3(26,5,-52),Vector3(18,5,-53),3.5,oak)
	# Frosted backdrop and dessert-service dressing, kept out of traversal lines.
	for x in [0,8,16,24,32,40]:
		box(root_scene,"ColdStorageFrame",Vector3(x,8,-61.5),Vector3(7.2,8,.35),teal)
		box(root_scene,"FrostedGlass",Vector3(x,8,-61.25),Vector3(6.5,7.3,.12),material(Color("86bfc7"),.12,.3))
		box(root_scene,"GlassHandle",Vector3(x+2.4,7.8,-61),Vector3(.13,2,.16),brass)
		for i in range(3):
			var flake := box(root_scene,"FrostEtching",Vector3(x,9,-61.15),Vector3(.09,1.8,.03),cold)
			flake.rotation.z=i*PI/3
	sign_(root_scene,"FROST & FEAST / THE ICE ATELIER",Vector3(12,13,-60),58)
	# Tall drink glasses, straws and citrus tie the scenery to a cold-dessert theme.
	for p in [Vector3(-3,3,-32),Vector3(5,3,-32),Vector3(40,3,-24),Vector3(5,5,-56)]:
		cylinder(root_scene,"DrinkGlass",p+Vector3(0,.65,0),.55,1.3,tile)
		ring(root_scene,p+Vector3(0,1.31,0),.52,brass)
		var straw := cylinder(root_scene,"PaperStraw",p+Vector3(.20,1.5,0),.05,1.1,cream)
		straw.rotation.z=.2
		var citrus := cylinder(root_scene,"LemonSlice",p+Vector3(-.4,1.2,0),.33,.10,material(Color("efc958")))
		citrus.rotation.x=PI/2
	for z in [-26,-38]:
		box(root_scene,"LagoonTowel",Vector3(42.5,3.02,z),Vector3(2,.025,2.7),teal)
		for i in range(3):
			box(root_scene,"FoldedTowelStripe",Vector3(42+i*.35,3.04,z),Vector3(.10,.015,2.7),cream)

func dressing() -> void:
	# Reuse the team's oven as a scenic anchor, positioned outside the route.
	var oven := (load("res://scenes/props/distinct_oven.tscn") as PackedScene).instantiate() as Node3D
	oven.position=Vector3(41,0,-55)
	root_scene.add_child(oven)
	# Breakfast table and stools establish scale below the counter adventure.
	box(root_scene,"DiningTable",Vector3(0,1.6,18),Vector3(13,.4,6),oak)
	for x in [-5,5]:
		for z in [16,20]:
			box(root_scene,"TableLeg",Vector3(x,.7,z),Vector3(.3,1.6,.3),teal)
	for x in [-4,0,4]:
		for z in [14,22]:
			cylinder(root_scene,"Stool",Vector3(x,.85,z),.75,.25,oak)
			for dx in [-.4,.4]:
				box(root_scene,"StoolLeg",Vector3(x+dx,.3,z),Vector3(.14,.9,.14),brass)
	# Shelves, labelled recipe books, spice jars, ceramics, cloth, and plants.
	for center in [Vector3(-9,4,-5),Vector3(27,4,-28),Vector3(1,7,-60)]:
		box(root_scene,"FloatingShelf",center,Vector3(8,.22,2),oak)
		for i in range(6):
			var p: Vector3 = center+Vector3(-3+i*1.05,.6,0)
			cylinder(root_scene,"SpiceJar",p,.30,1.0,cream if i%2 else teal)
			cylinder(root_scene,"JarLid",p+Vector3(0,.55,0),.33,.14,brass)
			sign_(root_scene,["SALT","SUGAR","MINT","TEA","COCOA","FLOUR"][i],p+Vector3(0,0,.34),12)
	for p in [Vector3(-3.8,3,-7),Vector3(21.8,3,-26),Vector3(2,5,-56)]:
		for i in range(3):
			var book := box(root_scene,"RecipeBook",p+Vector3(0,.15+i*.28,0),Vector3(2.2,.24,1.55),[teal,cream,material(Color("ac6341"))][i])
			book.rotation.y=i*.12
			box(book,"PageBlock",Vector3(0,0,.03),Vector3(2.05,.17,1.47),cream)
	for p in [Vector3(-9,5.4,-14),Vector3(-9,5.4,-36),Vector3(25,3,-48)]:
		cylinder(root_scene,"HerbPot",p,.62,.8,material(Color("b66c47")))
		for i in range(9):
			var a := i*TAU/9
			var leaf := sphere(root_scene,"BasilLeaf",p+Vector3(sin(a)*.42,.7+i*.055,cos(a)*.42),.3,material(Color("477b51")))
			leaf.scale=Vector3(.7,1.7,.4)
	# Cloth stripes, bowls and breakfast fruit create small composed still lifes.
	for p in [Vector3(-3.9,3.02,1),Vector3(21.8,3.02,-34)]:
		box(root_scene,"TeaTowel",p,Vector3(2.2,.035,3.8),cream)
		for i in range(7):
			box(root_scene,"TowelStripe",p+Vector3(-.9+i*.3,.025,0),Vector3(.06,.02,3.8),teal)
		for i in range(3):
			var model_ := (load("res://assets/models/obstacles/sink/SinkBowl.glb") as PackedScene).instantiate() as Node3D
			model_.position=p+Vector3(0,.22+i*.18,.1)
			model_.scale=Vector3.ONE*.5
			root_scene.add_child(model_)
	# Warm pendant lights are positioned away from camera paths.
	for p in [Vector3(-5,12,-8),Vector3(25,12,-37),Vector3(4,13,-55)]:
		cylinder(root_scene,"PendantCord",p+Vector3(0,2,0),.035,4,dark)
		var shade := CylinderMesh.new()
		shade.top_radius=.30
		shade.bottom_radius=1.4
		shade.height=1.1
		mesh(root_scene,"PendantShade",shade,p,teal)
		cylinder(root_scene,"PendantGlow",p-Vector3(0,.55,0),1.15,.04,material(Color("ffd397"),0,.5,1.5))

func player_and_lighting() -> void:
	var player := RigidBody3D.new()
	player.name="Player"
	player.set_script(load("res://scripts/ice/ice_player.gd"))
	player.position=Vector3(0,3.75,6)
	player.gravity_scale=1.5
	player.linear_damp=1.5
	player.set("speed_force",15.0)
	player.set("jump_impulse",7.0)
	var c := CollisionShape3D.new()
	c.name="CollisionShape3D"
	player.add_child(c)
	var s := SphereShape3D.new()
	s.radius=.60
	c.shape=s
	var v := MeshInstance3D.new()
	v.name="MeshInstance3D"
	c.add_child(v)
	var sm := SphereMesh.new()
	sm.radius=.60
	sm.height=1.2
	sm.radial_segments=48
	sm.rings=24
	v.mesh=sm
	var im := ShaderMaterial.new()
	im.shader=load("res://assets/shaders/ice_shell.gdshader")
	v.material_override=im
	root_scene.add_child(player)
	var camera := Camera3D.new()
	camera.name="Camera3D"
	camera.set_script(load("res://scripts/ice/ice_camera.gd"))
	camera.position=Vector3(0,12.75,16)
	camera.fov=65
	camera.far=180
	root_scene.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-42,0)
	sun.light_color=Color("ffdec0")
	sun.light_energy=.9
	sun.shadow_enabled=true
	root_scene.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("94b6c1")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b8ced9")
	env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	root_scene.add_child(environment)
	for p in [Vector3(-7,10,-9),Vector3(25,10,-36),Vector3(2,11,-54)]:
		var light := OmniLight3D.new()
		light.position=p
		light.light_color=Color("ffd5a2")
		light.light_energy=2.0
		light.omni_range=20
		root_scene.add_child(light)

func hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name="HUD"
	canvas.process_mode=Node.PROCESS_MODE_ALWAYS
	root_scene.add_child(canvas)
	var map := Control.new()
	map.name="KitchenMap"
	map.set_script(load("res://scripts/ice/ice_map.gd"))
	map.position=Vector2(1635,28)
	canvas.add_child(map)
	var margin := MarginContainer.new()
	margin.name="Margin"
	margin.position=Vector2(28,28)
	margin.custom_minimum_size=Vector2(405,0)
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	var panel := PanelContainer.new()
	panel.name="Panel"
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.09,.11,.94)
	style.set_corner_radius_all(16)
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=18
	style.content_margin_bottom=18
	panel.add_theme_stylebox_override("panel",style)
	margin.add_child(panel)
	var rows := VBoxContainer.new()
	rows.name="Rows"
	rows.add_theme_constant_override("separation",9)
	panel.add_child(rows)
	var title := Label.new()
	title.text="FROST & FEAST"
	title.add_theme_font_size_override("font_size",28)
	title.modulate=Color("ecd8ae")
	rows.add_child(title)
	var sub := Label.new()
	sub.text="A little ice. A whole kitchen."
	sub.add_theme_font_size_override("font_size",16)
	rows.add_child(sub)
	var meter := ProgressBar.new()
	meter.name="IceMeter"
	meter.value=100
	meter.custom_minimum_size.y=24
	var fill := StyleBoxFlat.new()
	fill.bg_color=Color("63ccde")
	fill.set_corner_radius_all(8)
	meter.add_theme_stylebox_override("fill",fill)
	rows.add_child(meter)
	var state := Label.new()
	state.name="State"
	state.add_theme_font_size_override("font_size",14)
	rows.add_child(state)
	var objectives := Label.new()
	objectives.name="Objectives"
	objectives.add_theme_font_size_override("font_size",14)
	objectives.modulate=Color("ecd8ae")
	rows.add_child(objectives)
	var controls := Label.new()
	controls.name="Controls"
	controls.text="WASD move · Space jump · R checkpoint\nArrows look · Tab free camera"
	controls.add_theme_font_size_override("font_size",14)
	controls.modulate=Color("adbfbe")
	rows.add_child(controls)
	var toast := Label.new()
	toast.name="Toast"
	toast.text="Explore at your own pace. Blue trays refill your ice."
	toast.position=Vector2(470,32)
	toast.add_theme_font_size_override("font_size",22)
	toast.add_theme_color_override("font_outline_color",Color("132e36"))
	toast.add_theme_constant_override("outline_size",8)
	canvas.add_child(toast)
	var results := PanelContainer.new()
	results.name="Results"
	results.visible=false
	results.position=Vector2(450,220)
	results.custom_minimum_size=Vector2(490,330)
	results.add_theme_stylebox_override("panel",style.duplicate())
	canvas.add_child(results)
	var result_rows := VBoxContainer.new()
	result_rows.name="Rows"
	result_rows.add_theme_constant_override("separation",14)
	results.add_child(result_rows)
	var result_title := Label.new()
	result_title.text="DESSERT SAVED!"
	result_title.add_theme_font_size_override("font_size",28)
	result_rows.add_child(result_title)
	var stars := Label.new()
	stars.name="Stars"
	stars.text="☆☆☆"
	stars.add_theme_font_size_override("font_size",54)
	stars.modulate=Color("f5ca72")
	result_rows.add_child(stars)
	var details := Label.new()
	details.name="Details"
	details.add_theme_font_size_override("font_size",17)
	result_rows.add_child(details)
	var replay := Button.new()
	replay.name="Replay"
	replay.text="Explore again  ·  R"
	result_rows.add_child(replay)
