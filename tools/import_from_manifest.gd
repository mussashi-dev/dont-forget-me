extends SceneTree
## Prepara importação pixel-art em res://assets/ (Filter Nearest + Mipmaps desativados)
## e gera SpriteFrames (.tres) a partir de res://manifest_assets.json (grid 32x32).
## Uso: godot --headless --path . -s res://tools/import_from_manifest.gd

const MANIFEST_PATH: String = "res://manifest_assets.json"
const DEFAULT_CELL_SIZE: int = 32

func _init() -> void:
	var fixed_count: int = _enforce_no_mipmaps_recursive("res://assets")
	print("[IMPORT] Verificados .import em res://assets/ (mipmaps/generate=false corrigidos: %d)" % fixed_count)

	if not FileAccess.file_exists(MANIFEST_PATH):
		print("[MANIFEST] res://manifest_assets.json ainda não encontrado. Aguardando assets do ChatGPT.")
		_verify_existing_spriteframes("res://resources/pablita_topdown_frames.tres", "Pablita")
		_verify_existing_spriteframes("res://resources/pipop_topdown_frames.tres", "Pipop")
		quit(0)
		return

	var json_text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("[MANIFEST] JSON inválido em %s" % MANIFEST_PATH)
		quit(1)
		return

	var manifest: Dictionary = parsed
	var cell_size: int = int(manifest.get("cell_size", DEFAULT_CELL_SIZE))
	var characters: Dictionary = manifest.get("characters", {})
	for char_key: String in characters.keys():
		var char_cfg: Dictionary = characters[char_key]
		var out_path: String = str(char_cfg.get("output_tres", "res://resources/%s_manifest_frames.tres" % char_key))
		_build_character_frames(char_key, char_cfg, cell_size, out_path)

	quit(0)

func _enforce_no_mipmaps_recursive(dir_path: String) -> int:
	var fixed: int = 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path: String = "%s/%s" % [dir_path, entry]
			if dir.current_is_dir():
				fixed += _enforce_no_mipmaps_recursive(full_path)
			elif entry.ends_with(".png.import"):
				var content: String = FileAccess.get_file_as_string(full_path)
				if content.contains("mipmaps/generate=true"):
					var updated: String = content.replace("mipmaps/generate=true", "mipmaps/generate=false")
					var f := FileAccess.open(full_path, FileAccess.WRITE)
					if f:
						f.store_string(updated)
						f.close()
						fixed += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return fixed

func _build_character_frames(char_key: String, cfg: Dictionary, default_cell: int, out_path: String) -> void:
	var sheet_path: String = str(cfg.get("spritesheet", ""))
	if sheet_path.is_empty() or not ResourceLoader.exists(sheet_path):
		push_error("[MANIFEST] Spritesheet ausente para %s: %s" % [char_key, sheet_path])
		return

	var sheet_tex: Texture2D = load(sheet_path)
	var cell_w: int = int(cfg.get("cell_width", default_cell))
	var cell_h: int = int(cfg.get("cell_height", default_cell))
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var anims: Dictionary = cfg.get("animations", {})
	for anim_name: String in anims.keys():
		var anim_data: Dictionary = anims[anim_name]
		var fps: float = float(anim_data.get("fps", 8.0))
		var loop: bool = bool(anim_data.get("loop", true))
		var coords: Array = anim_data.get("frames", [])
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)

		for frame_entry: Variant in coords:
			if frame_entry is Dictionary:
				var fd: Dictionary = frame_entry
				var rx: int = int(fd["x"]) if fd.has("x") else int(fd.get("col", 0)) * cell_w
				var ry: int = int(fd["y"]) if fd.has("y") else int(fd.get("row", 0)) * cell_h
				var rw: int = int(fd.get("w", cell_w))
				var rh: int = int(fd.get("h", cell_h))
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet_tex
				atlas.region = Rect2(rx, ry, rw, rh)
				frames.add_frame(anim_name, atlas)

	var err: int = ResourceSaver.save(frames, out_path)
	print("[MANIFEST] %s -> %s (erro=%d, animações=%d)" % [char_key, out_path, err, frames.get_animation_names().size()])

func _verify_existing_spriteframes(res_path: String, label: String) -> void:
	if not ResourceLoader.exists(res_path):
		push_warning("[MANIFEST] SpriteFrames não encontrado: %s" % res_path)
		return
	var sf := load(res_path) as SpriteFrames
	if sf == null:
		push_warning("[MANIFEST] Falha ao carregar SpriteFrames: %s" % res_path)
		return
	print("[MANIFEST] %s ativo (%s): %d animações -> %s" % [label, res_path, sf.get_animation_names().size(), str(sf.get_animation_names())])
