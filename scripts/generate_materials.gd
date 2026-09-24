@tool
extends EditorScript

## Bulk-creates StandardMaterial3D resources from a folder of textures.
## Run with File > Run in the script editor, or Ctrl+Shift+X.
##
## Expects the naming convention T_<Name>_<Res>_<Suffix>.<ext>, for example
## T_Veneer_Oak_1K_BC.jpg, and produces MI_Veneer_Oak.tres.

const TEXTURE_DIR := "res://assets/textures/"
const OUTPUT_DIR := "res://materials/generated/"

## Off so a re-run never destroys materials you have already tuned.
## Flip to true only when you deliberately want to regenerate everything.
const OVERWRITE_EXISTING := false

## Your world is 100 units per fictional metre, so 1.0 / 100.0 tiles once per metre.
const TRIPLANAR_SCALE := 0.01

## Matches the toon shading on MM_WorldAligned so the kitchen stays consistent.
const USE_TOON := true


func _run() -> void:
	#Job 1: Make sure the output folder exists, as ResourceSaver will not create it.
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var dir := DirAccess.open(TEXTURE_DIR)
	if dir == null:
		push_error("Cannot open %s" % TEXTURE_DIR)
		return

	#Job 2: Collect every base colour file, as each one defines one material.
	#       The N and R files are looked up from its name rather than scanned.
	var bases: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".import"):
			continue
		var stem := file.get_basename()
		if stem.ends_with("_BC"):
			bases.append(stem)

	if bases.is_empty():
		push_warning("No _BC textures found in %s" % TEXTURE_DIR)
		return

	var made := 0
	var skipped := 0

	for bc_stem in bases:
		#Job 3: Work out the material name, as the file name carries a prefix,
		#       a resolution token and a suffix that none of us want to keep.
		var parts := bc_stem.split("_")
		var name_parts: Array[String] = []
		for i in range(parts.size()):
			var part := parts[i]
			if i == 0 and part == "T":
				continue                              # drop the T_ prefix
			if part == "BC":
				continue                              # drop the suffix
			if part.length() >= 2 and part.ends_with("K") and part.left(part.length() - 1).is_valid_int():
				continue                              # drop 1K, 2K, 4K
			name_parts.append(part)

		var mat_name := "MI_" + "_".join(name_parts)
		var out_path := OUTPUT_DIR + mat_name + ".tres"

		#Job 4: Skip anything that already exists, as regenerating would wipe
		#       whatever a designer has tuned since.
		if not OVERWRITE_EXISTING and ResourceLoader.exists(out_path):
			skipped += 1
			continue

		var mat := StandardMaterial3D.new()

		#Job 5: Assign albedo, as this is the one map every material must have.
		var bc_tex := _find_texture(dir, bc_stem)
		if bc_tex == null:
			push_warning("Could not load base colour for %s" % bc_stem)
			continue
		mat.albedo_texture = bc_tex

		#Job 6: Assign roughness if the file exists, and set the value to 1.0
		#       so the map is used at full strength rather than scaled down.
		var prefix := bc_stem.substr(0, bc_stem.length() - 2)   # strip "BC"
		var r_tex := _find_texture(dir, prefix + "R")
		if r_tex != null:
			mat.roughness_texture = r_tex
			mat.roughness = 1.0
		else:
			mat.roughness = 0.6

		#Job 7: Assign the normal map if present, as it must be explicitly
		#       enabled before the texture slot does anything.
		var n_tex := _find_texture(dir, prefix + "N")
		if n_tex != null:
			mat.normal_enabled = true
			mat.normal_texture = n_tex
			mat.normal_scale = 1.0

		#Job 8: Project in world space, as our geometry is generated boxes with
		#       UVs that stretch when a designer resizes them.
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(TRIPLANAR_SCALE, TRIPLANAR_SCALE, TRIPLANAR_SCALE)

		if USE_TOON:
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_TOON

		var err := ResourceSaver.save(mat, out_path)
		if err != OK:
			push_error("Failed to save %s (error %d)" % [out_path, err])
		else:
			print("Created ", out_path)
			made += 1

	print("--- Done. %d created, %d skipped as they already exist. ---" % [made, skipped])


## Textures may be .jpg or .png, so try both rather than assuming.
func _find_texture(dir: DirAccess, stem: String) -> Texture2D:
	var extensions: Array[String] = [".jpg", ".png", ".jpeg", ".exr"]
	for ext in extensions:
		var path := TEXTURE_DIR + stem + ext
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
