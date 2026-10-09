extends RefCounted

## The primary colour of each catalog item. Each item lists the parts that make up
## its primary colour; a part names a material, a MeshInstance3D, or a colour
## uniform of a ShaderMaterial. The first part found is the reference colour the
## editor shows. The other parts are shades that stay as much lighter or darker
## than the picked colour as they were than the reference, so two-tone pieces stay
## two-tone. Textured materials only recolour their most colourful hue, so the
## blender's red swatch changes while its greys and blacks stay put.

const GRID := ["checker_a", "checker_b", "minor_line_color", "major_line_color"]
const PICKUP := ["Brushed teal trim", "LightRing", "glow_color"]
const WOOD := ["Honey_Wood", "Light_Wood", "Dark_Wood"]

const SPECS := {
	"counter": ["Kitchen Countertops"],
	"box": GRID,
	"ramp": GRID,
	"half_pipe": GRID,
	"cylinder": GRID,
	"oven": ["Oven_Deep_Teal_Enamel", "Oven_Deep_Shadow"],
	"grill": ["WeatheredIron"],
	"lighter": ["Lighter"],
	"spoon": ["Model"],
	"cardboard": ["lambert1"],
	"bottle": ["Glass"],
	"roller": WOOD,
	"spinner": ["Spinner_HoneyWood", "Spinner_LightWood", "Spinner_LightLine", "Spinner_DarkLine"],
	"log": WOOD,
	"masher": ["Coral_Handle"],
	"knife": ["knife_handle"],
	"blender": ["blender"],
	"ladle": ["Coral_Grip"],
	"ladle_vertical": ["Skimmer_CoralGrip"],
	"funnel": ["Funnel_Teal"],
	"funnel_long": ["FunnelLong_Enamel", "FunnelLong_TubeBand"],
	"corkscrew": ["lambert3SG"],
	"scale": ["baseScale"],
	"dicer": ["TopRim", "BottomRim"],
	"umbrella": PICKUP,
	"cream": PICKUP,
	"ice": PICKUP,
	"gravity": PICKUP,
	"m4a1": PICKUP,
	"shotgun": PICKUP,
	"pistol": PICKUP,
	"produce": ["Material.001"],
	"pot": ["Material.001"],
}

## Where to look for an item's parts when its material names are reused elsewhere
## in the scene; the pot's floating egg also has a "Material.001".
const ROOTS := {"pot": "Model"}

## Each recoloured MeshInstance3D keeps its original materials here, by surface
## (-1 for material_override), so colours can be changed again or removed.
const SOURCES := &"primary_colour_sources"

## Textures are analysed at most this size; larger ones are scaled down first.
const MASK_SIZE := 512
const TINT_SIZE := 1024

static var _analysed := {}


static func supports(id: String) -> bool:
	return SPECS.has(id)


static func to_text(colour: Color) -> String:
	return "#" + colour.to_html(false)


static func parse(value: Variant) -> Variant:
	if value is String and value.length() == 7 and value.begins_with("#") and value.substr(1).is_valid_hex_number():
		return Color.html(value)
	return null


static func validate(id: String, value: Variant) -> String:
	if not supports(id):
		return "An object has a colour but cannot be recoloured."
	if parse(value) == null:
		return "An object has an invalid colour."
	return ""


## The item's own primary colour, ignoring any colour applied to it, or null when
## none of its parts are present.
static func own_colour(node: Node, id: String) -> Variant:
	return _reference(_surfaces(node, id), id)


## Recolours the item, or restores its own colours when colour is null. Pieces
## that build their meshes in _ready are recoloured once they are ready.
static func apply(node: Node, id: String, colour: Variant) -> void:
	if not node.is_node_ready():
		node.ready.connect(apply.bind(node, id, colour), CONNECT_ONE_SHOT)
		return
	var surfaces := _surfaces(node, id)
	var primary: Variant = _reference(surfaces, id)
	if colour != null and primary == null:
		return
	for entry in surfaces:
		var mesh: MeshInstance3D = entry.mesh
		var sources: Dictionary = mesh.get_meta(SOURCES, {})
		if colour == null:
			if sources.has(entry.surface):
				_restore(mesh, entry.surface, entry.source)
				sources.erase(entry.surface)
		else:
			var material: Material = _current(mesh, entry.surface) if sources.has(entry.surface) else entry.source.duplicate()
			_paint(material, entry.source, entry.names, colour, primary)
			if entry.surface < 0:
				mesh.material_override = material
			else:
				mesh.set_surface_override_material(entry.surface, material)
			sources[entry.surface] = entry.source
		if sources.is_empty():
			mesh.remove_meta(SOURCES)
		else:
			mesh.set_meta(SOURCES, sources)


static func _surfaces(node: Node, id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var parts: Array = SPECS.get(id, [])
	var root := node.get_node_or_null(NodePath(ROOTS.get(id, ".")))
	if parts.is_empty() or root == null:
		return found
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var sources: Dictionary = mesh.get_meta(SOURCES, {})
		var slots: Array = [-1] if mesh.material_override != null else range(mesh.mesh.get_surface_count())
		for surface in slots:
			var material: Material = sources.get(surface, _current(mesh, surface))
			var names := _matches(mesh, material, parts)
			if not names.is_empty():
				found.append({"mesh": mesh, "surface": surface, "source": material, "names": names})
	return found


static func _matches(mesh: MeshInstance3D, material: Material, parts: Array) -> Array:
	if material is BaseMaterial3D:
		for name in [material.resource_name, String(mesh.name)]:
			if parts.has(name):
				return [name]
	elif material is ShaderMaterial:
		return parts.filter(func(part: String): return _shader_colour(material, part) != null)
	return []


static func _current(mesh: MeshInstance3D, surface: int) -> Material:
	if surface < 0:
		return mesh.material_override
	var material := mesh.get_surface_override_material(surface)
	return material if material != null else mesh.mesh.surface_get_material(surface)


static func _restore(mesh: MeshInstance3D, surface: int, source: Material) -> void:
	if surface < 0:
		mesh.material_override = source
	else:
		mesh.set_surface_override_material(surface, null if source == mesh.mesh.surface_get_material(surface) else source)


static func _reference(surfaces: Array[Dictionary], id: String) -> Variant:
	for part in SPECS.get(id, []):
		for entry in surfaces:
			if entry.names.has(part):
				return _original_colour(entry.source, part)
	return null


static func _original_colour(material: Material, part: String) -> Variant:
	if material is ShaderMaterial:
		return _shader_colour(material, part)
	var base := material as BaseMaterial3D
	var info := _analyse(base.albedo_texture)
	return base.albedo_color * info.reference if not info.is_empty() else base.albedo_color


static func _shader_colour(material: ShaderMaterial, part: String) -> Variant:
	if material.shader == null:
		return null
	var value: Variant = material.get_shader_parameter(part)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), part)
	if value is Vector4:
		value = Color(value.x, value.y, value.z, value.w)
	return value if value is Color else null


static func _paint(material: Material, source: Material, names: Array, colour: Color, primary: Color) -> void:
	if source is ShaderMaterial:
		for part in names:
			material.set_shader_parameter(part, _shade(colour, primary, _shader_colour(source, part)))
		return
	var base := source as BaseMaterial3D
	var painted := material as BaseMaterial3D
	painted.albedo_color = Color(_shade(colour, primary, _original_colour(base, "")), base.albedo_color.a)
	if base.emission_enabled:
		painted.emission = _shade(colour, primary, base.emission)
	var info := _analyse(base.albedo_texture)
	if info.is_empty():
		return
	painted.albedo_texture = info.shade
	# Outside the recoloured hue, the detail layer puts the original texture back.
	if info.keep != null:
		painted.detail_enabled = true
		painted.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		painted.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		painted.detail_albedo = base.albedo_texture
		painted.detail_mask = info.keep


## The picked colour, lightened or darkened as far as original is from reference.
static func _shade(picked: Color, reference: Color, original: Color) -> Color:
	var from := _lightness(reference)
	var to := _lightness(original)
	var result := picked
	if to > from + 0.002:
		result = picked.lerp(Color.WHITE, (to - from) / maxf(1.0 - from, 0.001))
	elif to < from - 0.002:
		result = picked.lerp(Color.BLACK, 1.0 - to / maxf(from, 0.001))
	result.a = original.a
	return result


## Matches Image.adjust_bcs, which greys a pixel to the mean of its channels.
static func _lightness(colour: Color) -> float:
	return (colour.r + colour.g + colour.b) / 3.0


## Splits a texture into the pixels of its most common saturated hue and the rest.
## Returns {} for unreadable textures, otherwise:
##   reference: the typical colour of those pixels, at their median lightness
##   shade:     a grey texture, 1.0 at the reference, to multiply the new colour by;
##              lighter pixels clamp, darker ones such as wood grain keep their contrast
##   keep:      a mask that is white where the original texture should stay, or
##              null when the whole texture takes the new colour
static func _analyse(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	if _analysed.has(texture):
		return _analysed[texture]
	var result := {}
	var full := _readable(texture)
	if full != null:
		var image := _fitted(full, MASK_SIZE)
		var data := image.get_data()
		var pixels := data.size() / 4
		var hues := PackedInt32Array()
		hues.resize(36)
		var colourful := 0
		for i in pixels:
			var hue := _hue(data[i * 4], data[i * 4 + 1], data[i * 4 + 2])
			if hue >= 0:
				hues[hue / 10] += 1
				colourful += 1
		var dominant := 0
		var best := -1
		for bin in 36:
			var votes := hues[(bin + 35) % 36] + hues[bin] * 2 + hues[(bin + 1) % 36]
			if votes > best:
				best = votes
				dominant = bin * 10 + 5
		var whole := colourful < pixels * 0.03
		var primary := PackedByteArray()
		primary.resize(pixels)
		var count := 0
		for i in pixels:
			var hue := _hue(data[i * 4], data[i * 4 + 1], data[i * 4 + 2])
			if whole or (hue >= 0 and absi((hue - dominant + 540) % 360 - 180) <= 30):
				primary[i] = 1
				count += 1
		if count >= pixels * 0.85:
			whole = true
			primary.fill(1)
			count = pixels
		var reference := _percentile_colour(data, primary, count, 0.5)
		var level := maxf(_lightness(reference), 0.02)
		var keep: ImageTexture = null
		var shade: Image
		if whole:
			shade = _fitted(full, TINT_SIZE)
			shade.adjust_bcs(1.0 / level, 1.0, 0.0)
		else:
			shade = image.duplicate()
			var shade_data := shade.get_data()
			var mask := PackedByteArray()
			mask.resize(pixels)
			for i in pixels:
				var value := 255
				if primary[i] == 1:
					var lightness := (data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2]) / (765.0 * level)
					value = clampi(roundi(lightness * 255.0), 0, 255)
				else:
					mask[i] = 255
				shade_data[i * 4] = value
				shade_data[i * 4 + 1] = value
				shade_data[i * 4 + 2] = value
			shade.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, shade_data)
			var keep_image := Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_L8, mask)
			keep_image.generate_mipmaps()
			keep = ImageTexture.create_from_image(keep_image)
		shade.generate_mipmaps()
		result = {"reference": reference, "shade": ImageTexture.create_from_image(shade), "keep": keep}
	_analysed[texture] = result
	return result


static func _readable(texture: Texture2D) -> Image:
	var source := texture.get_image()
	if source == null or source.is_empty():
		return null
	# get_image can hand back the texture's own copy, so never change it in place.
	var image := source.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK:
		return null
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _fitted(image: Image, limit: int) -> Image:
	var fitted := image.duplicate() as Image
	var longest := maxi(fitted.get_width(), fitted.get_height())
	if longest > limit:
		var factor := float(limit) / longest
		fitted.resize(maxi(1, roundi(fitted.get_width() * factor)), maxi(1, roundi(fitted.get_height() * factor)), Image.INTERPOLATE_BILINEAR)
	return fitted


## Hue in degrees, or -1 for greys, near-blacks and washed-out pixels.
static func _hue(r: int, g: int, b: int) -> int:
	var high := maxi(r, maxi(g, b))
	var span := high - mini(r, mini(g, b))
	if high < 30 or span * 4 < high:
		return -1
	var hue: float
	if high == r:
		hue = fposmod(float(g - b) / span, 6.0)
	elif high == g:
		hue = float(b - r) / span + 2.0
	else:
		hue = float(r - g) / span + 4.0
	return int(hue * 60.0) % 360


static func _percentile_colour(data: PackedByteArray, primary: PackedByteArray, count: int, percentile: float) -> Color:
	var totals := PackedInt64Array()
	totals.resize(256 * 4)
	for i in primary.size():
		if primary[i] == 1:
			var bin := (data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2]) / 3
			totals[bin * 4] += 1
			totals[bin * 4 + 1] += data[i * 4]
			totals[bin * 4 + 2] += data[i * 4 + 1]
			totals[bin * 4 + 3] += data[i * 4 + 2]
	var target := count * percentile
	var seen := 0
	var level := 255
	for bin in 256:
		seen += totals[bin * 4]
		if seen >= target:
			level = bin
			break
	var sums := Vector4.ZERO
	for bin in range(maxi(level - 4, 0), mini(level + 5, 256)):
		sums += Vector4(totals[bin * 4], totals[bin * 4 + 1], totals[bin * 4 + 2], totals[bin * 4 + 3])
	if sums.x == 0:
		return Color.WHITE
	return Color(sums.y / sums.x / 255.0, sums.z / sums.x / 255.0, sums.w / sums.x / 255.0)
