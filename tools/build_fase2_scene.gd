extends SceneTree
## Constrói res://resources/fase2_corridor_tileset.tres e res://scenes/levels/Fase2.tscn
## com TileMapLayer (metade madeira do quarto, metade roxo do Esquecido),
## StaticBody2D nas paredes e móveis, Pablita, HUD e os 3 novos mobs.
## Uso: godot --headless --path . -s res://tools/build_fase2_scene.gd

const TILESET_PATH: String = "res://resources/fase2_corridor_tileset.tres"
const SCENE_PATH: String = "res://scenes/levels/Fase2.tscn"

const CORRIDOR_COLS: int = 24
const CORRIDOR_ROWS: int = 10
const TILE_SIZE: int = 32

func _init() -> void:
	var tileset: TileSet = _create_corridor_tileset()
	var ts_err: int = ResourceSaver.save(tileset, TILESET_PATH)
	print("[FASE2_BUILDER] TileSet salvo em %s (erro=%d)" % [TILESET_PATH, ts_err])

	var root_node := Node2D.new()
	root_node.name = "Fase2"
	root_node.y_sort_enabled = true
	root_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root_node.set_script(load("res://scripts/levels/fase_2.gd"))

	# 1. TileMapLayer do corredor (metade madeira, metade roxo do Esquecido)
	var tile_layer := TileMapLayer.new()
	tile_layer.name = "CorredorTileMapLayer"
	tile_layer.z_index = -10
	tile_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile_layer.tile_set = load(TILESET_PATH)
	root_node.add_child(tile_layer)
	tile_layer.owner = root_node

	for y: int in CORRIDOR_ROWS:
		for x: int in CORRIDOR_COLS:
			if x < CORRIDOR_COLS / 2:
				var wood_source: int = 0 if (x + y) % 2 == 0 else 1
				tile_layer.set_cell(Vector2i(x, y), wood_source, Vector2i(0, 0))
			else:
				var void_source: int = 2 if (x + y) % 3 != 0 else 3
				tile_layer.set_cell(Vector2i(x, y), void_source, Vector2i(0, 0))

	# 2. StaticBody2D das paredes do corredor
	var walls := StaticBody2D.new()
	walls.name = "ParedesStaticBody"
	walls.collision_layer = 2
	walls.collision_mask = 0
	root_node.add_child(walls)
	walls.owner = root_node

	var w_px: float = float(CORRIDOR_COLS * TILE_SIZE)
	var h_px: float = float(CORRIDOR_ROWS * TILE_SIZE)
	var wall_t: float = 32.0
	_add_wall_rect(walls, root_node, "WallTop", Vector2(w_px * 0.5, wall_t * 0.5), Vector2(w_px, wall_t))
	_add_wall_rect(walls, root_node, "WallBottom", Vector2(w_px * 0.5, h_px - wall_t * 0.5), Vector2(w_px, wall_t))
	_add_wall_rect(walls, root_node, "WallLeft", Vector2(wall_t * 0.5, h_px * 0.5), Vector2(wall_t, h_px))
	_add_wall_rect(walls, root_node, "WallRight", Vector2(w_px - wall_t * 0.5, h_px * 0.5), Vector2(wall_t, h_px))

	# 3. Móveis do Quarto com StaticBody2D (colisão) na metade esquerda
	var furniture_group := Node2D.new()
	furniture_group.name = "MoveisQuarto"
	furniture_group.y_sort_enabled = true
	root_node.add_child(furniture_group)
	furniture_group.owner = root_node

	_add_furniture(furniture_group, root_node, "Cama", "res://assets/environments/bedroom/furn_bed.png", Vector2(88, 92), Vector2(40, 22))
	_add_furniture(furniture_group, root_node, "GuardaRoupa", "res://assets/environments/bedroom/furn_wardrobe.png", Vector2(200, 74), Vector2(36, 20))
	_add_furniture(furniture_group, root_node, "Estante", "res://assets/environments/bedroom/furn_bookshelf.png", Vector2(310, 74), Vector2(32, 18))

	# 4. Pablita + HUD
	var pablita_scene: PackedScene = load("res://scenes/characters/pablita.tscn")
	var pablita := pablita_scene.instantiate() as Node2D
	pablita.name = "Pablita"
	pablita.position = Vector2(96, 176)
	root_node.add_child(pablita)
	pablita.owner = root_node

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud := hud_scene.instantiate()
	hud.name = "HUD"
	root_node.add_child(hud)
	hud.owner = root_node

	# 5. Mobs da Fase 2
	var mobs_group := Node2D.new()
	mobs_group.name = "Mobs"
	mobs_group.y_sort_enabled = true
	root_node.add_child(mobs_group)
	mobs_group.owner = root_node

	var corda_scene: PackedScene = load("res://scenes/enemies/mob_brinquedo_corda.tscn")
	var corda := corda_scene.instantiate() as Node2D
	corda.name = "BrinquedoDeCorda"
	corda.position = Vector2(280, 176)
	mobs_group.add_child(corda)
	corda.owner = root_node

	var tufo_scene: PackedScene = load("res://scenes/enemies/mob_tufo_meias.tscn")
	var tufo := tufo_scene.instantiate() as Node2D
	tufo.name = "TufoDeMeias"
	tufo.position = Vector2(480, 168)
	mobs_group.add_child(tufo)
	tufo.owner = root_node

	var flor_scene: PackedScene = load("res://scenes/enemies/mob_flor_poeira.tscn")
	var flor := flor_scene.instantiate() as Node2D
	flor.name = "FlorDePoeira"
	flor.position = Vector2(640, 176)
	mobs_group.add_child(flor)
	flor.owner = root_node

	var packed := PackedScene.new()
	var pack_err: int = packed.pack(root_node)
	var save_err: int = ResourceSaver.save(packed, SCENE_PATH)
	print("[FASE2_BUILDER] Cena salva em %s (pack=%d, save=%d)" % [SCENE_PATH, pack_err, save_err])
	root_node.queue_free()
	quit(0)

func _create_corridor_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 2)
	ts.set_physics_layer_collision_mask(0, 0)

	var tile_paths: Array[String] = [
		"res://assets/environments/bedroom/tile_bedroom_wood_0.png",
		"res://assets/environments/bedroom/tile_bedroom_wood_1.png",
		"res://assets/environments/esquecido_fase3/tile_deep_void_stone.png",
		"res://assets/environments/esquecido_fase3/tile_stone_a.png",
	]
	for idx: int in tile_paths.size():
		var src := TileSetAtlasSource.new()
		src.texture = load(tile_paths[idx])
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, idx)
	return ts

func _add_wall_rect(parent: StaticBody2D, owner_node: Node, node_name: String, pos: Vector2, rect_size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = node_name
	cs.position = pos
	var shape := RectangleShape2D.new()
	shape.size = rect_size
	cs.shape = shape
	parent.add_child(cs)
	cs.owner = owner_node

func _add_furniture(parent: Node2D, owner_node: Node, node_name: String, tex_path: String, pos: Vector2, col_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.y_sort_enabled = true
	body.collision_layer = 2
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = owner_node

	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		spr.texture = tex
		spr.offset = Vector2(0, -tex.get_height() * 0.5)
	body.add_child(spr)
	spr.owner = owner_node

	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	cs.position = Vector2(0, -col_size.y * 0.5)
	var shape := RectangleShape2D.new()
	shape.size = col_size
	cs.shape = shape
	body.add_child(cs)
	cs.owner = owner_node
