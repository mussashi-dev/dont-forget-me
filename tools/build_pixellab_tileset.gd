extends SceneTree
## Converte o tileset do PixelLab (JSON de metadados + PNG 128x128)
## em um recurso nativo Godot 4 TileSet (.tres) com Terrain Set (Corner Matching)
## Uso: godot --headless --path . -s res://tools/build_pixellab_tileset.gd

func _init() -> void:
	var metadata_path: String = "res://assets/_generated/inbox/tileset_quarto_esquecido_metadata.json"
	var source_png_path: String = "res://assets/_generated/inbox/tileset_quarto_esquecido_image.png"
	var target_dir: String = "res://assets/tilesets/generated"
	var target_png_path: String = "%s/tileset_quarto_esquecido.png" % target_dir
	var output_tres_path: String = "res://resources/tileset_quarto_esquecido.tres"

	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/tilesets/generated"):
		dir.make_dir_recursive("assets/tilesets/generated")

	# Copia PNG para assets/tilesets/generated/
	var copy_err := dir.copy(source_png_path, target_png_path)
	print("[BUILD] Copiando textura para %s (erro=%d)" % [target_png_path, copy_err])

	# Lê metadados JSON
	var json_file := FileAccess.open(metadata_path, FileAccess.READ)
	if json_file == null:
		push_error("Não foi possível abrir: %s" % metadata_path)
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(json_file.get_as_text())
	json_file.close()
	if not (parsed is Dictionary):
		push_error("JSON inválido")
		quit(1)
		return

	var meta: Dictionary = parsed
	var tileset_data: Dictionary = meta.get("tileset_data", {})
	var tiles: Array = tileset_data.get("tiles", [])

	# Cria o TileSet
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)

	# Terrains Set 0 (Corner matching)
	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)

	# Terrain 0 = Quarto (Madeira)
	tileset.add_terrain(0, 0)
	tileset.set_terrain_name(0, 0, "Quarto (Madeira)")
	tileset.set_terrain_color(0, 0, Color(0.85, 0.65, 0.45, 1.0)) # Madeira quente

	# Terrain 1 = Esquecido (Solo Roxo)
	tileset.add_terrain(0, 1)
	tileset.set_terrain_name(0, 1, "Esquecido (Solo Roxo)")
	tileset.set_terrain_color(0, 1, Color(0.40, 0.25, 0.55, 1.0)) # Roxo escuro do Esquecido

	# Carrega textura do atlas
	var texture: Texture2D = load(target_png_path)
	if texture == null:
		# Se ainda não foi importado pelo editor, carrega via ImageTexture
		var img := Image.load_from_file(ProjectSettings.globalize_path(target_png_path))
		texture = ImageTexture.create_from_image(img)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(32, 32)

	for tile_entry: Variant in tiles:
		if not (tile_entry is Dictionary):
			continue
		var td: Dictionary = tile_entry
		var bbox: Dictionary = td.get("bounding_box", {})
		var bx: int = int(bbox.get("x", 0)) / 32
		var by: int = int(bbox.get("y", 0)) / 32
		var tile_coord := Vector2i(bx, by)

		if not atlas_source.has_tile(tile_coord):
			atlas_source.create_tile(tile_coord)

		var tile_data: TileData = atlas_source.get_tile_data(tile_coord, 0)
		tile_data.terrain_set = 0

		var corners: Dictionary = td.get("corners", {})
		var nw_terrain: int = 1 if corners.get("NW", "") == "upper" else 0
		var ne_terrain: int = 1 if corners.get("NE", "") == "upper" else 0
		var sw_terrain: int = 1 if corners.get("SW", "") == "upper" else 0
		var se_terrain: int = 1 if corners.get("SE", "") == "upper" else 0

		tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, nw_terrain)
		tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, ne_terrain)
		tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, sw_terrain)
		tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, se_terrain)

		# Se os 4 cantos forem iguais, é o base tile do terreno
		if nw_terrain == ne_terrain and ne_terrain == sw_terrain and sw_terrain == se_terrain:
			tile_data.terrain = nw_terrain

	tileset.add_source(atlas_source, 0)

	var save_err := ResourceSaver.save(tileset, output_tres_path)
	print("[BUILD] TileSet salvo com sucesso em %s (erro=%d)" % [output_tres_path, save_err])

	quit(0)
