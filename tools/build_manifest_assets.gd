extends SceneTree
## Builds SpriteFrames (.tres) and normalized 32x32 tiles directly from res://assets/asset_manifest.json.
## Usage:
##   godot --headless --path . --script tools/build_manifest_assets.gd

const MANIFEST_PATH := "res://assets/asset_manifest.json"
const OUTPUT_PABLITA_TRES := "res://resources/pablita_topdown_frames.tres"
const OUTPUT_BOSS_TRES := {
	"meia": "res://resources/boss_sock_frames.tres",
	"robot": "res://resources/boss_robot_frames.tres",
	"queen": "res://resources/boss_queen_frames.tres",
}
const TILES_OUT_DIR := "res://assets/tilesets/final_reference/grid_32x32"


func _init() -> void:
	var raw_text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	if raw_text.is_empty():
		printerr("build_manifest_assets: failed to read %s" % MANIFEST_PATH)
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		printerr("build_manifest_assets: invalid JSON in %s" % MANIFEST_PATH)
		quit(1)
		return
	var manifest: Dictionary = parsed

	if not _build_pablita_frames(manifest.get("pablita", {})):
		quit(1)
		return

	for key: String in OUTPUT_BOSS_TRES.keys():
		if not _build_boss_frames(key, manifest.get(key, {}), String(OUTPUT_BOSS_TRES[key])):
			quit(1)
			return

	if not _build_fase2_32x32_tiles():
		quit(1)
		return

	print("MANIFEST_ASSETS_BUILT_OK")
	quit(0)


func _build_pablita_frames(pablita_data: Variant) -> bool:
	if not (pablita_data is Dictionary):
		printerr("build_manifest_assets: missing 'pablita' dictionary in manifest")
		return false
	var pdata: Dictionary = pablita_data
	var sheet_rel: String = String(pdata.get("sheet", ""))
	if sheet_rel.is_empty():
		printerr("build_manifest_assets: missing pablita.sheet")
		return false
	var sheet_path: String = "res://" + sheet_rel
	var sheet_tex := ResourceLoader.load(sheet_path) as Texture2D
	if sheet_tex == null:
		printerr("build_manifest_assets: failed to load %s" % sheet_path)
		return false

	var frame_size_dict: Dictionary = pdata.get("frame_size", {"w": 32, "h": 32})
	var fw: int = int(frame_size_dict.get("w", 32))
	var fh: int = int(frame_size_dict.get("h", 32))
	var frames_meta: Dictionary = pdata.get("frames", {})

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var dirs: Array[String] = ["south", "west", "north", "east"]
	var atlas_cache: Dictionary = {}

	# Helper closure via inner helper calls using atlas_cache keyed by frame name.
	for anim_key: String in frames_meta.keys():
		var fmeta: Dictionary = frames_meta[anim_key]
		var col: int = int(fmeta.get("col", 0))
		var row: int = int(fmeta.get("row", 0))
		var at := AtlasTexture.new()
		at.atlas = sheet_tex
		at.region = Rect2(col * fw, row * fh, fw, fh)
		at.filter_clip = true
		atlas_cache[anim_key] = at

	for d: String in dirs:
		var idle_key: String = "idle_" + d
		var walk_key: String = "walk_" + d
		var run_key: String = "run_" + d

		var idle_tex: AtlasTexture = atlas_cache.get(idle_key) as AtlasTexture
		var walk_tex: AtlasTexture = atlas_cache.get(walk_key) as AtlasTexture
		var run_tex: AtlasTexture = atlas_cache.get(run_key) as AtlasTexture
		if idle_tex == null or walk_tex == null or run_tex == null:
			printerr("build_manifest_assets: missing pablita frames for dir '%s'" % d)
			return false

		sf.add_animation(idle_key)
		sf.set_animation_loop(idle_key, true)
		sf.set_animation_speed(idle_key, 4.0)
		sf.add_frame(idle_key, idle_tex)

		# Alternate walk step + neutral idle pose for legible 2-frame cycle.
		sf.add_animation(walk_key)
		sf.set_animation_loop(walk_key, true)
		sf.set_animation_speed(walk_key, 8.0)
		sf.add_frame(walk_key, walk_tex)
		sf.add_frame(walk_key, idle_tex)

		sf.add_animation(run_key)
		sf.set_animation_loop(run_key, true)
		sf.set_animation_speed(run_key, 10.0)
		sf.add_frame(run_key, run_tex)
		sf.add_frame(run_key, walk_tex)

		# Compatibility alias used by Pablita._update_sprite_visuals() during dash.
		var dash_key: String = "dash_" + d
		sf.add_animation(dash_key)
		sf.set_animation_loop(dash_key, false)
		sf.set_animation_speed(dash_key, 12.0)
		sf.add_frame(dash_key, run_tex)

	# Preserve physical attack frames so melee combat & vertical slice tests continue working cleanly.
	sf.add_animation("attack_phys")
	sf.set_animation_loop("attack_phys", false)
	sf.set_animation_speed("attack_phys", 14.0)
	for i in range(4):
		var p_path: String = "res://assets/sprites/pablita/attack_phys_%d.png" % i
		var p_tex := ResourceLoader.load(p_path) as Texture2D
		if p_tex != null:
			sf.add_frame("attack_phys", p_tex)
	if sf.get_frame_count("attack_phys") == 0 and atlas_cache.has("run_south"):
		sf.add_frame("attack_phys", atlas_cache["run_south"] as Texture2D)

	var err: int = ResourceSaver.save(sf, OUTPUT_PABLITA_TRES)
	if err != OK:
		printerr("build_manifest_assets: failed saving %s (%d)" % [OUTPUT_PABLITA_TRES, err])
		return false
	print("Saved ", OUTPUT_PABLITA_TRES, " animations=", sf.get_animation_names())
	return true


func _build_boss_frames(boss_key: String, boss_data: Variant, out_tres: String) -> bool:
	if not (boss_data is Dictionary):
		printerr("build_manifest_assets: missing '%s' dictionary in manifest" % boss_key)
		return false
	var bdata: Dictionary = boss_data
	var frames_arr: Variant = bdata.get("frames", [])
	if not (frames_arr is Array) or (frames_arr as Array).is_empty():
		printerr("build_manifest_assets: missing frames array for '%s'" % boss_key)
		return false

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var grouped: Dictionary = {}
	for entry_var: Variant in (frames_arr as Array):
		if not (entry_var is Dictionary):
			continue
		var entry: Dictionary = entry_var
		var group_name: String = String(entry.get("visual_group", "locomotion"))
		if not grouped.has(group_name):
			grouped[group_name] = {
				"fps": float(entry.get("fps_suggested", 8.0)),
				"loop": bool(entry.get("loop", true)),
				"files": []
			}
		(grouped[group_name]["files"] as Array).append(String(entry.get("file", "")))

	for anim_name: String in grouped.keys():
		var adef: Dictionary = grouped[anim_name]
		var fps: float = float(adef.get("fps", 8.0))
		var loop_flag: bool = bool(adef.get("loop", true))
		var frame_paths: Array = adef.get("files", [])

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop_flag)

		for rel_p: Variant in frame_paths:
			var res_path: String = "res://" + String(rel_p)
			var tex := ResourceLoader.load(res_path) as Texture2D
			if tex == null:
				printerr("build_manifest_assets: missing boss texture %s" % res_path)
				return false
			sf.add_frame(anim_name, tex)

		if sf.get_frame_count(anim_name) == 0:
			printerr("build_manifest_assets: animation %s.%s has 0 frames" % [boss_key, anim_name])
			return false

	var err: int = ResourceSaver.save(sf, out_tres)
	if err != OK:
		printerr("build_manifest_assets: failed saving %s (%d)" % [out_tres, err])
		return false
	print("Saved ", out_tres, " animations=", sf.get_animation_names())
	return true


func _build_fase2_32x32_tiles() -> bool:
	var abs_out: String = ProjectSettings.globalize_path(TILES_OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out)

	var jobs: Array[Dictionary] = [
		{
			"src": "res://assets/tilesets/final_reference/floor_wood_clean_a.png",
			"dst": TILES_OUT_DIR + "/floor_wood_a.png",
			"mode": "sample_square",
			"sample_size": 64
		},
		{
			"src": "res://assets/tilesets/final_reference/floor_wood_clean_b.png",
			"dst": TILES_OUT_DIR + "/floor_wood_b.png",
			"mode": "sample_square",
			"sample_size": 64
		},
		{
			"src": "res://assets/tilesets/final_reference/floor_wood_overgrown_a.png",
			"dst": TILES_OUT_DIR + "/floor_forgotten_a.png",
			"mode": "sample_square",
			"sample_size": 64
		},
		{
			"src": "res://assets/tilesets/final_reference/forgotten_path.png",
			"dst": TILES_OUT_DIR + "/floor_forgotten_b.png",
			"mode": "sample_opaque_region",
			"sample_size": 64
		},
		{
			"src": "res://assets/tilesets/final_reference/wall_wood_vines.png",
			"dst": TILES_OUT_DIR + "/wall_corridor.png",
			"mode": "wall_slice"
		}
	]

	for job: Dictionary in jobs:
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(job["src"])))
		if img == null or img.is_empty():
			printerr("build_manifest_assets: failed loading tile source %s" % String(job["src"]))
			return false
		img.convert(Image.FORMAT_RGBA8)

		var out_img: Image = null
		var mode: String = String(job["mode"])
		if mode == "sample_square":
			var ss: int = mini(int(job["sample_size"]), mini(img.get_width(), img.get_height()))
			var rx: int = (img.get_width() - ss) / 2
			var ry: int = (img.get_height() - ss) / 2
			out_img = img.get_region(Rect2i(rx, ry, ss, ss))
			out_img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		elif mode == "sample_opaque_region":
			var ss: int = int(job["sample_size"])
			var best_rect: Rect2i = _find_most_opaque_rect(img, ss, ss)
			out_img = img.get_region(best_rect)
			out_img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		elif mode == "wall_slice":
			# Capture the vertical wood wainscoting + vine strip on the right half at 136px -> 32px.
			var h: int = img.get_height()
			var start_x: int = clampi(int(img.get_width() * 0.62), 0, maxi(0, img.get_width() - h))
			var slice_w: int = mini(h, img.get_width() - start_x)
			out_img = img.get_region(Rect2i(start_x, 0, slice_w, h))
			out_img.resize(32, 32, Image.INTERPOLATE_NEAREST)

		var save_err: int = out_img.save_png(ProjectSettings.globalize_path(String(job["dst"])))
		if save_err != OK:
			printerr("build_manifest_assets: failed saving %s (%d)" % [String(job["dst"]), save_err])
			return false
		print("Saved ", String(job["dst"]), " (", out_img.get_width(), "x", out_img.get_height(), ")")

	return true


func _find_most_opaque_rect(img: Image, w: int, h: int) -> Rect2i:
	var best_x: int = 0
	var best_y: int = 0
	var best_score: int = -1
	var step: int = 8
	for y in range(0, maxi(1, img.get_height() - h + 1), step):
		for x in range(0, maxi(1, img.get_width() - w + 1), step):
			var opaque_count: int = 0
			for sy in range(0, h, 4):
				for sx in range(0, w, 4):
					if img.get_pixel(x + sx, y + sy).a > 0.95:
						opaque_count += 1
			if opaque_count > best_score:
				best_score = opaque_count
				best_x = x
				best_y = y
	return Rect2i(best_x, best_y, mini(w, img.get_width()), mini(h, img.get_height()))
