extends Node2D
## Protótipo visual v0.2 do Esquecido: valida escala-base (tile 16 px), perspectiva por composição
## (props com frente + topo, colisor só na base, Y-sort) e paleta roxa.
## TAB alterna entre a Floresta de Esquecidos e a Sala de Comparação de escala.
## Argumento de captura: godot -- --shot=forest|lineup  (salva PNG e sai)

const T: String = "res://assets/environments/esquecido/"
const TILE: int = 16
const FOREST_RECT: Rect2i = Rect2i(0, 0, 512, 384)
const LINEUP_ORIGIN: Vector2 = Vector2(1000, 0)

# Escala-base (px): tile = 16. Pablita ~28 (1,75 tile), Chopp ~16, Pipop ~18, Meia ~23, guarda-roupa ~48.
var _world: Node2D
var _player: Pablita
var _camera: Camera2D
var _in_lineup: bool = false
var _flames: Array[PointLight2D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Caminho principal legível (retângulos em tiles: x, y, w, h)
const PATH_RECTS: Array[Rect2i] = [
	Rect2i(14, 20, 4, 4), Rect2i(14, 14, 4, 6), Rect2i(10, 14, 8, 3), Rect2i(10, 8, 3, 6), Rect2i(10, 5, 10, 3), Rect2i(18, 5, 4, 5),
]

func _ready() -> void:
	_rng.seed = 20260511
	RenderingServer.set_default_clear_color(Color("#120b1c"))
	var tint := CanvasModulate.new()
	tint.color = Color(0.86, 0.8, 1.0)
	add_child(tint)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_build_ground()
	_build_forest_props()
	_build_bounds()
	_build_lineup()
	_player = (load("res://scenes/characters/pablita.tscn") as PackedScene).instantiate() as Pablita
	_player.position = Vector2(256, 360)
	_world.add_child(_player)
	_player.add_to_group("player")
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.position_smoothing_enabled = false
	_apply_camera_limits()
	var shot: String = _arg("shot")
	if shot != "":
		_take_shot(shot)

func _arg(key: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_area()

func _toggle_area() -> void:
	_in_lineup = not _in_lineup
	_player.global_position = LINEUP_ORIGIN + Vector2(40, 170) if _in_lineup else Vector2(256, 360)
	_apply_camera_limits()
	_zoom_for_area()
	_zoom_for_area()

func _apply_camera_limits() -> void:
	var r: Rect2 = Rect2(LINEUP_ORIGIN, Vector2(440, 200)) if _in_lineup else Rect2(FOREST_RECT)
	_camera.limit_left = int(r.position.x)
	_camera.limit_top = int(r.position.y)
	_camera.limit_right = int(r.end.x)
	_camera.limit_bottom = int(r.end.y)


func _zoom_for_area() -> void:
	_camera.zoom = Vector2(1, 1) if _in_lineup else Vector2(2, 2)

func _process(_delta: float) -> void:
	for f: PointLight2D in _flames:
		f.energy = 0.75 + 0.15 * sin(Time.get_ticks_msec() * 0.011 + f.position.x)

# ---------- construção ----------
func _tex(name: String) -> Texture2D:
	return load(T + name + ".png") as Texture2D

func _build_ground() -> void:
	var ground := Node2D.new()
	ground.z_index = -10
	add_child(ground)
	var g: Array[Texture2D] = [_tex("ground_a"), _tex("ground_b"), _tex("ground_c")]
	var p: Array[Texture2D] = [_tex("path_a"), _tex("path_b")]
	var path_tiles: Dictionary = {}
	for r: Rect2i in PATH_RECTS:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				path_tiles[Vector2i(x, y)] = true
	for ty: int in range(FOREST_RECT.size.y / TILE):
		for tx: int in range(FOREST_RECT.size.x / TILE):
			var s := Sprite2D.new()
			s.centered = false
			s.position = Vector2(tx * TILE, ty * TILE)
			s.texture = p[_rng.randi() % p.size()] if path_tiles.has(Vector2i(tx, ty)) else g[_rng.randi() % g.size()]
			ground.add_child(s)
			if not path_tiles.has(Vector2i(tx, ty)) and _rng.randf() < 0.06:
				var d := Sprite2D.new()
				d.texture = _tex(["detail_button", "detail_yarn", "detail_block", "detail_glint"][_rng.randi() % 4])
				d.position = s.position + Vector2(8, 8)
				ground.add_child(d)

## Cria um prop: origem = centro da base (onde toca o chão). Colisor só na base.
func _prop(name: String, pos: Vector2, base_size: Vector2 = Vector2.ZERO, parent: Node = null) -> Node2D:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 2   # camada 2 = sólidos do mundo (Pablita colide com a máscara 14)
	var spr := Sprite2D.new()
	var tx: Texture2D = _tex(name)
	spr.texture = tx
	spr.centered = false
	spr.offset = Vector2(-tx.get_width() / 2.0, -tx.get_height() + 2.0)
	body.add_child(spr)
	if base_size != Vector2.ZERO:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = base_size
		cs.shape = shape
		cs.position = Vector2(0, -base_size.y / 2.0)
		body.add_child(cs)
	(parent if parent != null else _world).add_child(body)
	return body

func _candle(pos: Vector2) -> void:
	var c: Node2D = _prop("teacup_candle", pos, Vector2(8, 5))
	var light := PointLight2D.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.45, 1.0))
	grad.set_color(1, Color(1.0, 0.8, 0.45, 0.0))
	gt.gradient = grad
	light.texture = gt
	light.texture_scale = 0.9
	light.color = Color(1.0, 0.78, 0.45)
	light.position = Vector2(0, -14)
	c.add_child(light)
	_flames.append(light)

func _build_forest_props() -> void:
	# Borda densa de árvores-pilha-de-brinquedos (limite natural), com folgas para o caminho.
	var tree_base := Vector2(14, 8)
	var top: Array[int] = [20, 62, 104, 146, 188, 232, 276, 320, 364, 408, 450, 492]
	for x: int in top:
		_prop("tree_toypile", Vector2(x + _rng.randi_range(-4, 4), 44 + _rng.randi_range(-2, 4)), tree_base)
	for y: int in [92, 140, 190, 240, 290, 340]:
		_prop("tree_toypile", Vector2(14 + _rng.randi_range(-3, 3), y), tree_base)
		_prop("tree_toypile", Vector2(498 + _rng.randi_range(-3, 3), y + 14), tree_base)
	for x: int in [30, 78, 120, 170, 330, 380, 430, 478]:
		_prop("tree_toypile", Vector2(x, 380 + _rng.randi_range(-2, 2)), tree_base)
	# Arbustos de pelúcia, flores-bloco e objetos ao redor do caminho
	for pos: Vector2 in [Vector2(210, 340), Vector2(300, 330), Vector2(150, 250), Vector2(340, 230), Vector2(96, 150), Vector2(230, 150)]:
		_prop("bush_plushpile", pos, Vector2(22, 8))
	for pos: Vector2 in [Vector2(188, 300), Vector2(320, 284), Vector2(120, 210), Vector2(260, 190), Vector2(400, 150), Vector2(70, 110)]:
		_prop("mushroom_block", pos, Vector2(8, 4))
	_prop("teddy_buried", Vector2(190, 200), Vector2(20, 6))
	_prop("teddy_buried", Vector2(380, 300), Vector2(20, 6))
	_prop("doll_forgotten", Vector2(280, 270), Vector2(8, 4))
	_prop("doll_forgotten", Vector2(150, 70), Vector2(8, 4))
	_prop("dresser_mossy", Vector2(360, 120), Vector2(30, 14))
	_prop("dresser_mossy", Vector2(60, 300), Vector2(30, 14))
	_prop("wardrobe_mossy", Vector2(430, 220), Vector2(36, 18))
	# Cipós de roupa pendurados nas copas
	for pos: Vector2 in [Vector2(62, 54), Vector2(232, 54), Vector2(364, 56), Vector2(450, 54)]:
		_prop("vine_clothes", pos + Vector2(10, 6))
	# Pontos de luz quente ao longo do caminho
	for pos: Vector2 in [Vector2(238, 352), Vector2(238, 252), Vector2(176, 236), Vector2(176, 160), Vector2(236, 92), Vector2(330, 88)]:
		_candle(pos)

func _build_bounds() -> void:
	# Limites físicos de segurança, atrás da borda de árvores (a borda é o limite visual).
	var walls := StaticBody2D.new()
	walls.collision_layer = 2
	add_child(walls)
	var rects: Array[Rect2] = [
		Rect2(-32, -32, 576, 56), Rect2(-32, 392, 576, 40), Rect2(-32, -32, 32 + 4, 448), Rect2(508, -32, 36, 448),
	]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size / 2.0
		walls.add_child(cs)

func _build_lineup() -> void:
	var room := Node2D.new()
	room.position = LINEUP_ORIGIN
	room.z_index = -10
	room.set_script(load("res://scripts/prototype/scale_grid.gd"))
	add_child(room)
	var base_y: float = 150.0
	# [textura, rótulo, x, deslocamento vertical (Pipop flutua)]
	var items: Array[Array] = [
		["res://assets/characters/pablita/topdown/walk_south_1.png", "Pablita 28", 24, 0],
		["res://assets/characters/chopp/chopp_idle_0.png", "Chopp 16", 64, 0],
		["res://assets/characters/pipop/topdown/walk_south_1.png", "Pipop 20", 96, 0],
		["res://assets/characters/enemies/sock_enemy_0.png", "Meia 23", 128, 0],
		["res://assets/environments/esquecido/mushroom_block.png", "Cogumelo 18", 162, 0],
		["res://assets/environments/esquecido/doll_forgotten.png", "Boneca 28", 196, 0],
		["res://assets/environments/esquecido/teddy_buried.png", "Urso 24", 236, 0],
		["res://assets/environments/esquecido/bush_plushpile.png", "Arbusto 22", 282, 0],
		["res://assets/environments/esquecido/dresser_mossy.png", "Comoda 30", 336, 0],
		["res://assets/environments/esquecido/wardrobe_mossy.png", "G.-roupa 50", 396, 0],
	]
	for i: int in items.size():
		var tx: Texture2D = load(items[i][0])
		var s := Sprite2D.new()
		s.texture = tx
		s.centered = false
		if String(items[i][0]).contains("pablita"):
			s.offset = Vector2(-16, -30)
		elif String(items[i][0]).contains("pipop"):
			s.offset = Vector2(-12, -23)
		else:
			s.offset = Vector2(-tx.get_width() / 2.0, -tx.get_height() + 2.0)
		s.position = LINEUP_ORIGIN + Vector2(float(items[i][2]), base_y + float(items[i][3]))
		_world.add_child(s)
		_label(items[i][1], LINEUP_ORIGIN + Vector2(float(items[i][2]), base_y + 6 + (i % 2) * 9))
func _label(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.position = pos - Vector2(l.text.length() * 2.2, 0)
	l.z_index = 5
	add_child(l)

func _take_shot(which: String) -> void:
	if which == "lineup":
		_toggle_area()
		_player.global_position = LINEUP_ORIGIN + Vector2(440, 190)
	else:
		_player.global_position = Vector2(236, 300) if which == "forest" else Vector2(236, 130)
	for i: int in 12:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tests/shot_%s.png" % which))
	get_tree().quit()
