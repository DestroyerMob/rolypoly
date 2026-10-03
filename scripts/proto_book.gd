@tool
class_name ProtoBook
extends Node3D

## A parametric book. One script covers all nine size combinations and all
## three gameplay uses: a closed book, a cover laid flat as a ramp, or both
## covers splayed into a tent. Geometry comes from BoxBuilder, so there is no
## mesh to export from Blender and no origin to fix.
##
## Local space, book lying flat and closed:
##   X = cover width, spine at -X
##   Y = thickness, front cover on top
##   Z = book height
## Both covers hinge about the Z axis at the spine edge, and each carries half
## the page block with it, the way a real book opens.

enum Title {
	NONE,
	MACARONS,
	UDON_RAMEN_SOBA,
	ONE_POT_DINNERS,
	CAKES_AND_DESSERT,
	BREAKFAST_IN_BORDIGHERA,
	CONVERT_YOUR_FRIENDS,
	CUCINA_ITALIANA,
	SPOOKY_RECIPES,
	WHERES_THE_LAMB_SAUCE,
}
const BOOK_DIR := "res://assets/textures/Books/"

const GENERATED := &"proto_book_generated"
## How far the artwork quad floats off its board. Overlapping surfaces are
## free, so the art is a separate quad rather than a UV on the box.
const ART_OFFSET := 0.05
## Title to filename stem. The three faces are the stem plus _Front, _Back
## and _Spine, which is why the rename script was worth writing.
const TITLE_STEM := {
	Title.MACARONS: "T_Book_01_Macarons",
	Title.UDON_RAMEN_SOBA: "T_Book_02_UdonRamenSoba",
	Title.ONE_POT_DINNERS: "T_Book_03_OnePotDinners",
	Title.CAKES_AND_DESSERT: "T_Book_04_CakesAndDessert",
	Title.BREAKFAST_IN_BORDIGHERA: "T_Book_05_BreakfastInBordighera",
	Title.CONVERT_YOUR_FRIENDS: "T_Book_06_ConvertYourFriends",
	Title.CUCINA_ITALIANA: "T_Book_07_CucinaItaliana",
	Title.SPOOKY_RECIPES: "T_Book_08_SpookyRecipes",
	Title.WHERES_THE_LAMB_SAUCE: "T_Book_09_WheresTheLambSauce",
}

## Built materials, keyed by texture path, so a rebuild does not allocate
## three new StandardMaterial3D every time a slider moves.
var _mat_cache := {}
# ----- shape --------------------------------------------------------------
@export_group("Shape")
@export var width := 16.0:
	set(value):
		width = maxf(value, 0.1)
		_rebuild()

@export var height := 24.0:
	set(value):
		height = maxf(value, 0.1)
		_rebuild()

@export var thickness := 3.0:
	set(value):
		thickness = maxf(value, 0.3)
		_rebuild()

@export var cover_thickness := 0.35:
	set(value):
		cover_thickness = maxf(value, 0.05)
		_rebuild()

## Chamfer on the cover boards only. The point is the highlight it catches,
## not the silhouette, so keep it under a tenth of the board thickness.
@export var cover_bevel := 0.5:
	set(value):
		cover_bevel = maxf(value, 0.0)
		_rebuild()
## Chamfer on the spine slab. A real binding is rounded at the hinge, so a
## slightly heavier bevel here than on the boards reads well.
@export var spine_bevel := 0.5:
	set(value):
		spine_bevel = maxf(value, 0.0)
		_rebuild()
		
# ----- pages --------------------------------------------------------------
@export_group("Pages")
## Gap between the spine's inner face and the start of the page block.
@export var page_gap := 0.1:
	set(value):
		page_gap = maxf(value, 0.0)
		_rebuild()

## How far the covers overhang the pages on the fore-edge, top and bottom.
## A board that is flush with the paper does not read as a book.
@export var page_inset := 0.25:
	set(value):
		page_inset = maxf(value, 0.0)
		_rebuild()

# ----- hinges -------------------------------------------------------------
@export_group("Hinges")
## 0 closed. 180 lays the cover flat on the far side, which is the ramp.
## 50 to 70 on both covers gives the tent, with the node rotated so the
## spine sits uppermost.
@export_range(0.0, 180.0, 0.5) var front_open_degrees := 0.0:
	set(value):
		front_open_degrees = value
		_rebuild()

@export_range(0.0, 180.0, 0.5) var back_open_degrees := 0.0:
	set(value):
		back_open_degrees = value
		_rebuild()
# ----- title --------------------------------------------------------------
@export_group("Title")
## Pick a book and its front, back and spine textures load automatically.
## The material overrides below still win where they are set.
@export var title: Title = Title.NONE:
	set(value):
		title = value
		_mat_cache.clear()
		_rebuild()
		
# ----- materials ----------------------------------------------------------
@export_group("Materials")
## Leave empty to use the picked Title. Set to override one face by hand
@export var mat_front: Material:
	set(value):
		mat_front = value
		_rebuild()

@export var mat_back: Material:
	set(value):
		mat_back = value
		_rebuild()

@export var mat_spine: Material:
	set(value):
		mat_spine = value
		_rebuild()

## Boards and spine slab. The un-arted edges of the binding.
@export var mat_cover: Material:
	set(value):
		mat_cover = value
		_rebuild()

## The page block. Share one cream material across every book in the game.
@export var mat_pages: Material:
	set(value):
		mat_pages = value
		_rebuild()

# ----- physics ------------------------------------------------------------
@export_group("Physics")
## Turn off for books that are pure background dressing, so the marble is
## not testing against boards it can never reach.
@export var collision_enabled := true:
	set(value):
		collision_enabled = value
		_rebuild()


## Catches up on the build that every setter skipped during load, for the same
## reason ArtBox does: setters fire before the node is in the tree.
func _ready() -> void:
	_rebuild()


## Turns the exports into geometry. Safe to run constantly, as it replaces
## rather than accumulates.
func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return

	#Job 2: Clear the previous build. Generated children are stamped and never
	#       given an owner, so they do not serialise into the .tscn and this
	#       cannot delete anything a designer placed by hand.
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()

	#Job 3: Spine first, as both hinges are positioned from its outer face.
	var spine_x := -width * 0.5
	_build_spine(spine_x)

	#Job 4: One hinge per cover, each carrying its board and its half of the
	#       page block, so opening a cover takes its pages with it.
	_build_side(true, spine_x)
	_build_side(false, spine_x)


# --------------------------------------------------------------------------
# Pieces
# --------------------------------------------------------------------------

## The binding slab at -X. Does not move, so it stays a StaticBody3D and the
## two hinges rotate around it.
func _build_spine(spine_x: float) -> void:
	var size := Vector3(cover_thickness, thickness, height)
	var pos := Vector3(spine_x + cover_thickness * 0.5, thickness * 0.5, 0.0)
	var slab := _box("Spine", size, pos, mat_cover, false, spine_bevel, null)

	#Job 1: Resolve the spine texture. The hand-set override wins, otherwise
	#       the picked Title supplies it, otherwise the slab stays plain.
	var spine_art := _art_material("Spine", mat_spine)
	if spine_art == null:
		return

	#Job 2: Shrink the art to the chamfered face, as the outward face of a
	#       bevelled box is inset by the bevel on all four sides and art
	#       sized to the full slab would hang off the chamfer.
	var inset := _spine_bevel_used() * 2.0

	#Job 3: Artwork on the outward face, which is -X. The basis names the
	#       quad's axes directly: image U runs along world Y (thickness),
	#       image V along world -Z (height), and the normal points -X.
	_art(slab, "SpineArt",
		Vector2(maxf(thickness - inset, 0.05), maxf(height - inset, 0.05)),
		Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)),
		Vector3(-size.x * 0.5 - ART_OFFSET, 0.0, 0.0),
		spine_art)

## BoxBuilder clamps the bevel to just under half the smallest dimension, and
## for a spine that smallest dimension is cover_thickness. Mirror the clamp
## here so the artwork is sized against the bevel actually used, not asked for.
func _spine_bevel_used() -> float:
	var limit := minf(minf(cover_thickness, thickness), height) * 0.49
	return clampf(spine_bevel, 0.0, limit)
	
## Builds one side of the book: a hinge, its cover board, its artwork, and its
## half of the page block. Called twice with is_front flipped.
func _build_side(is_front: bool, spine_x: float) -> void:
	var prefix: String = "Front" if is_front else "Back"
	var angle: float = front_open_degrees if is_front else back_open_degrees

	#Job 1: Put the pivot where the real hinge is, on the board's mid-plane at
	#       the spine edge. Pivot correctly and rotation needs no compensation
	#       anywhere downstream.
	var hinge_y: float = (thickness - cover_thickness * 0.5) if is_front \
		else (cover_thickness * 0.5)

	var hinge := Node3D.new()
	hinge.name = prefix + "Hinge"
	hinge.position = Vector3(spine_x, hinge_y, 0.0)
	#       Front swings up and over, back swings down and under, so the two
	#       angles both read as "how far open" rather than one being negative.
	hinge.rotation_degrees.z = angle if is_front else -angle
	_adopt(hinge)

	#Job 2: The cover board, offset so its spine edge sits on the pivot.
	var board_size := Vector3(width, cover_thickness, height)
	var board := _box(prefix + "Cover", board_size,
		Vector3(width * 0.5, 0.0, 0.0), mat_cover, true, cover_bevel, hinge)

	#Job 3: Artwork on the outward face. The hand-set override wins, otherwise
	#       the picked Title supplies it. Front faces +Y, back faces -Y, and
	#       the V axis flips between them so neither comes out upside down.
	var override: Material = mat_front if is_front else mat_back
	var art_mat := _art_material(prefix, override)
	if art_mat != null:
		var art_basis := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		var art_pos := Vector3(0.0, board_size.y * 0.5 + ART_OFFSET, 0.0)
		if not is_front:
			art_basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
			art_pos = Vector3(0.0, -board_size.y * 0.5 - ART_OFFSET, 0.0)
		_art(board, prefix + "Art", Vector2(width, height),
			art_basis, art_pos, art_mat)

	#Job 4: Half the page block, parented to this hinge so it travels with the
	#       cover. Two halves meeting in the middle is what makes an opened
	#       book look opened rather than hollow.
	var half_t := maxf((thickness - cover_thickness * 2.0) * 0.5, 0.02)

	#       X is measured in hinge space, where 0 is the spine's outer face.
	#       The block starts past the spine's inner face plus the gap, and
	#       stops short of the fore-edge so the board overhangs.
	var x_start := cover_thickness + page_gap
	var page_w := maxf(width - page_inset - x_start, 0.05)
	var page_size := Vector3(
		page_w,
		half_t,
		maxf(height - page_inset * 2.0, 0.05))

	var page_y: float = (-cover_thickness * 0.5 - half_t * 0.5) if is_front \
		else (cover_thickness * 0.5 + half_t * 0.5)

	_box(prefix + "Pages", page_size,
		Vector3(x_start + page_w * 0.5, page_y, 0.0),
		mat_pages, true, 0.0, hinge)

# --------------------------------------------------------------------------
# Builders
# --------------------------------------------------------------------------

## One box with its collider. Geometry comes from BoxBuilder, shared with
## ArtBox and TaperBox, so a fix to the chamfer fixes every piece at once.
func _box(p_name: String, size: Vector3, pos: Vector3, mat: Material,
		movable: bool, bevel: float, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = BoxBuilder.box_mesh(size, bevel)
	mi.position = pos
	if mat != null:
		mi.material_override = mat

	#Job 1: Attach to the hinge when there is one, so rotation carries the
	#       whole assembly. Spine and anything else hangs off the root.
	if parent == null:
		_adopt(mi)
	else:
		parent.add_child(mi)

	if not collision_enabled:
		return mi

	#Job 2: AnimatableBody3D for anything on a hinge, StaticBody3D otherwise.
	#       A StaticBody3D rotated by script does not push a resting body and
	#       lets the marble sink through the cover as it swings.
	var body: PhysicsBody3D
	if movable:
		body = AnimatableBody3D.new()
	else:
		body = StaticBody3D.new()
	body.name = p_name + "Body"

	#Job 3: A sharp box collider even where the mesh is chamfered. The bevel
	#       is a fraction of a unit at book scale and a sharp box behaves
	#       better under a rolling ball than a 44-triangle hull would.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	mi.add_child(body)

	return mi


## A flat quad carrying one of the three cover textures, floated off its board
## rather than UV-mapped onto it. BoxBuilder writes no UVs, and a separate
## quad costs nothing, so the art is geometry instead of a mapping problem.
func _art(parent: Node3D, p_name: String, size: Vector2, basis: Basis,
		offset: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.transform = Transform3D(basis, offset)
	mi.material_override = mat
	#Job 1: No collider. The artwork is decoration sitting on a board that
	#       already has one, and two colliders in the same place is the bug
	#       collision_enabled exists to avoid.
	parent.add_child(mi)

## Picks the material for one cover face: the hand-set override if there is
## one, otherwise the texture the chosen title implies, otherwise nothing.
func _art_material(face: String, override: Material) -> Material:
	if override != null:
		return override
	if title == Title.NONE:
		return null
	var stem: String = TITLE_STEM.get(title, "")
	if stem.is_empty():
		return null
	return _material_for(BOOK_DIR + stem + "_" + face + ".png")


## Builds and caches one unlit-ish paper material around a cover texture.
func _material_for(path: String) -> Material:
	#Job 1: Serve the cache, as _rebuild runs on every export change and a
	#       fresh material per rebuild leaks resources at editor speed.
	if _mat_cache.has(path):
		return _mat_cache[path]

	#Job 2: Check before loading, as load() on a missing path throws an error
	#       into the Output panel on every single rebuild.
	if not ResourceLoader.exists(path):
		push_warning("ProtoBook: texture not found, " + path)
		return null

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path) as Texture2D
	#Job 3: Paper and board, so matte and non-metallic. A shiny cover reads
	#       as a laminated poster rather than a cookbook.
	mat.roughness = 0.65
	mat.metallic = 0.0
	_mat_cache[path] = mat
	return mat
## Stamps a child so _rebuild can find and clear it, and adds it without an
## owner so it never serialises into the .tscn. Same trick as ArtBox.
func _adopt(node: Node) -> void:
	node.set_meta(GENERATED, true)
	add_child(node)
