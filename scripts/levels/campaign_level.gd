class_name CampaignLevel
extends Node2D
## Controlador unificado das 10 Fases da Campanha de DON'T FORGET ME.
## Implementa a narrativa como progressão jogável com estados, gatilhos causais,
## apresentação de chefes, participação ativa de Chopp, Luffy (na abertura) e habitantes do Esquecido.

@export var level_number: int = 1
@export var arena_rect: Rect2i = Rect2i(0, 0, 640, 420)

var pablita: Pablita
var hud: HUD
var chopp_actor: ChoppNPC = null
var exit_portal: WorldObject = null
var return_portal: WorldObject = null
var required_crystals: Array[WorldObject] = []
var active_enemies_count: int = 0
var required_story_flags: Array[String] = []

var _wall_rects: Array[Rect2] = []
var _floor_zones: Array[Dictionary] = []
var _thief_visual_pos: Vector2 = Vector2.ZERO
var _show_thief_visual: bool = false

func _ready() -> void:
	# Desativa quaisquer camadas de arte herdadas (caso a cena seja level_01_intro.tscn)
	for art_node_name: String in ["GroundLayer", "Decorations", "AmbientLight", "Walls"]:
		var n: Node = get_node_or_null(art_node_name)
		if n:
			if n is CanvasItem:
				(n as CanvasItem).visible = false
			if n is CollisionObject2D:
				(n as CollisionObject2D).collision_layer = 0
				(n as CollisionObject2D).collision_mask = 0
			for child in n.get_children():
				if child is CollisionShape2D:
					(child as CollisionShape2D).disabled = true

	var gm := GameManagerService.get_gm()
	if gm:
		gm.current_level_index = level_number
		if level_number >= 2 and not gm.is_pipop_acquired():
			gm.unlock_pipop()
		gm.set_game_state(GameManagerService.GameState.PLAYING)
		if not gm.story_flag_changed.is_connected(_on_story_flag_changed):
			gm.story_flag_changed.connect(_on_story_flag_changed)

	_ensure_player_and_hud()
	_configure_level_content(level_number)
	_build_boundary_and_internal_walls()
	pablita.set_camera_limits(arena_rect)
	_refresh_portal_lock()
	var am := AudioManagerService.get_am()
	if am:
		am.set_music_for_level(level_number)
	queue_redraw()

func _ensure_player_and_hud() -> void:
	pablita = get_node_or_null("Pablita") as Pablita
	if pablita == null:
		var p_scene: PackedScene = load("res://scenes/characters/pablita.tscn")
		pablita = p_scene.instantiate() as Pablita
		pablita.name = "Pablita"
		add_child(pablita)
	pablita.add_to_group("player")

	hud = get_node_or_null("HUD") as HUD
	if hud == null:
		var h_scene: PackedScene = load("res://scenes/ui/hud.tscn")
		hud = h_scene.instantiate() as HUD
		hud.name = "HUD"
		add_child(hud)
	else:
		hud._connect_player_and_managers()

	for old_name: String in ["ChoppNPC", "SockEnemy", "ForgottenCDItem"]:
		var old_node: Node = get_node_or_null(old_name)
		if old_node:
			old_node.queue_free()

func _build_boundary_and_internal_walls() -> void:
	var static_walls := StaticBody2D.new()
	static_walls.name = "PlaceholderWalls"
	static_walls.collision_layer = 2
	static_walls.collision_mask = 0
	add_child(static_walls)

	var r := Rect2(arena_rect)
	var thickness: float = 24.0
	var border_rects: Array[Rect2] = [
		Rect2(r.position.x, r.position.y, r.size.x, thickness),
		Rect2(r.position.x, r.end.y - thickness, r.size.x, thickness),
		Rect2(r.position.x, r.position.y, thickness, r.size.y),
		Rect2(r.end.x - thickness, r.position.y, thickness, r.size.y)
	]
	for br: Rect2 in border_rects:
		_wall_rects.append(br)

	for wr: Rect2 in _wall_rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wr.size
		cs.shape = shape
		cs.position = wr.position + wr.size * 0.5
		static_walls.add_child(cs)

func _add_wall_block(rect: Rect2) -> void:
	_wall_rects.append(rect)

func _spawn_npc(npc_name: String, pos: Vector2, lines: Array[String], color: Color = Color(0.95, 0.72, 0.25), on_talk_flag: String = "") -> ChoppNPC:
	var scene: PackedScene = load("res://scenes/characters/chopp_npc.tscn")
	var npc := scene.instantiate() as ChoppNPC
	npc.speaker_name = npc_name
	npc.dialogue_lines = lines
	npc.npc_color = color
	npc.global_position = pos
	npc.dialogue_requested.connect(func(speaker: String, dlg_lines: Array[String]):
		if hud:
			hud.show_dialogue_sequence(speaker, dlg_lines)
		if not on_talk_flag.is_empty():
			var gm := GameManagerService.get_gm()
			if gm:
				gm.set_story_flag(on_talk_flag, true)
	)
	add_child(npc)
	return npc

func _spawn_encarte_pickup(pos: Vector2, encarte_id: String, prompt: String, cap_bonus: int = 0, unique_flag: String = "") -> ForgottenCDItem:
	var scene: PackedScene = load("res://scenes/environments/forgotten_cd_item.tscn")
	var item := scene.instantiate() as ForgottenCDItem
	item.grant_encarte_id = encarte_id
	item.grant_capacity_bonus = cap_bonus
	item.unique_world_flag = unique_flag
	item.prompt_text = prompt
	item.global_position = pos
	add_child(item)
	return item

func _spawn_enemy(pos: Vector2, arch: EnemyBase.Archetype, drop_id: String = "") -> EnemyBase:
	var enemy := EnemyBase.new()
	enemy.archetype = arch
	enemy.drop_encarte_id = drop_id
	enemy.global_position = pos
	enemy.enemy_died.connect(_on_enemy_died)
	add_child(enemy)
	active_enemies_count += 1
	_refresh_portal_lock()
	return enemy

func _spawn_crate(pos: Vector2) -> WorldObject:
	var crate := WorldObject.new()
	crate.object_type = WorldObject.ObjectType.BREAKABLE_CRATE
	crate.global_position = pos
	add_child(crate)
	return crate

func _spawn_sonic_crystal(pos: Vector2, required_for_exit: bool = true) -> WorldObject:
	var crystal := WorldObject.new()
	crystal.object_type = WorldObject.ObjectType.SONIC_CRYSTAL
	crystal.global_position = pos
	if required_for_exit:
		required_crystals.append(crystal)
		crystal.activated.connect(func(_c): _refresh_portal_lock())
	add_child(crystal)
	_refresh_portal_lock()
	return crystal

func _spawn_lore_object(pos: Vector2, prompt: String, lines: Array[String], set_flag: String = "") -> WorldObject:
	var obj := WorldObject.new()
	obj.object_type = WorldObject.ObjectType.LORE_PLINTH
	obj.prompt_text = prompt
	obj.lore_lines = lines
	obj.global_position = pos
	if not set_flag.is_empty():
		obj.activated.connect(func(_o):
			var gm := GameManagerService.get_gm()
			if gm:
				gm.set_story_flag(set_flag, true)
		)
	add_child(obj)
	return obj

func _spawn_exit_portal(pos: Vector2, next_lvl: int = 0, custom_prompt: String = "Avançar de Fase") -> WorldObject:
	exit_portal = WorldObject.new()
	exit_portal.object_type = WorldObject.ObjectType.LEVEL_PORTAL
	exit_portal.target_level_index = next_lvl
	exit_portal.prompt_text = custom_prompt
	exit_portal.global_position = pos
	add_child(exit_portal)
	_refresh_portal_lock()
	return exit_portal

func _spawn_return_portal(pos: Vector2, prev_lvl: int, custom_prompt: String = "Caminho Conhecido (Retornar)", initially_locked: bool = false) -> WorldObject:
	return_portal = WorldObject.new()
	return_portal.object_type = WorldObject.ObjectType.LEVEL_PORTAL
	return_portal.target_level_index = prev_lvl
	return_portal.prompt_text = custom_prompt
	return_portal.global_position = pos
	add_child(return_portal)
	return_portal.set_locked(initially_locked)
	return return_portal

func _on_enemy_died(_enemy: EnemyBase) -> void:
	active_enemies_count = maxi(0, active_enemies_count - 1)
	_refresh_portal_lock()

func _on_story_flag_changed(_flag_name: String, _value: Variant) -> void:
	_refresh_portal_lock()

func _are_required_flags_met() -> bool:
	var gm := GameManagerService.get_gm()
	if gm == null:
		return true
	for f: String in required_story_flags:
		if not gm.has_story_flag(f):
			return false
	return true

func _refresh_portal_lock() -> void:
	if exit_portal == null:
		return
	var crystals_pending: bool = false
	for c: WorldObject in required_crystals:
		if is_instance_valid(c) and not c.is_activated:
			crystals_pending = true
			break
	var flags_pending: bool = not _are_required_flags_met()
	exit_portal.set_locked(active_enemies_count > 0 or crystals_pending or flags_pending)

# ---------- Foco Cinematográfico e Apresentações Narrativas ----------

func _play_phase_1_intro_cinematic(wardrobe_gate: WorldObject) -> void:
	if pablita:
		pablita.set_cinematic_locked(true)
	var am := AudioManagerService.get_am()
	if am:
		am.stop_music_for_dramatic_silence()
		am.play_sfx("wardrobe_slide")
	_show_thief_visual = true
	_thief_visual_pos = Vector2(310, 210)
	if is_instance_valid(wardrobe_gate):
		wardrobe_gate.queue_free()
	queue_redraw()

	if pablita:
		pablita.focus_camera_on(_thief_visual_pos, 1.2, 2.3)

	var intro_lines: Array[String] = [
		"Você encosta as mãos na madeira pesada e empurra o guarda-roupa para o lado... Há uma fenda estreita brilhando atrás do papel de parede!",
		"Antes que você possa entender o que é aquilo, uma criatura feita de meia velha e botões desparelhados salta da fresta!",
		"Em um bote rápido, ela agarra a caixa do seu CD favorito em cima da escrivaninha — aquele filme que você assistia sem parar!",
		"Luffy solta um latido rouco ao pé da cama e recua com as orelhas baixas diante da corrente de ar frio.",
		"A criatura de meia dá um risinho abafado de tecido e mergulha de volta para dentro da escuridão!",
		"Pablita: 'Ei! Devolve isso! Esse CD não é coisa perdida!'"
	]

	if hud:
		hud.set_objective_text("Siga a meia ladra pela passagem!")
		hud.dialogue_closed.connect(_on_phase_1_cinematic_dialogue_closed, CONNECT_ONE_SHOT)
		hud.show_dialogue_sequence("O Roubo do CD", intro_lines)
	else:
		_on_phase_1_cinematic_dialogue_closed()

func _on_phase_1_cinematic_dialogue_closed() -> void:
	if pablita:
		var cam_tween: Tween = pablita.return_camera_to_player(0.9)
		if cam_tween:
			cam_tween.finished.connect(func():
				_finish_phase_1_cinematic()
			, CONNECT_ONE_SHOT)
		else:
			_finish_phase_1_cinematic()
	else:
		_finish_phase_1_cinematic()

func _finish_phase_1_cinematic() -> void:
	_show_thief_visual = false
	queue_redraw()
	if pablita:
		pablita.set_cinematic_locked(false)
	var am := AudioManagerService.get_am()
	if am:
		am.set_music_state("ESQUECIDO_INITIAL")
	if hud:
		hud.set_objective_text("Atravesse a fenda atrás do guarda-roupa para o Esquecido")

func _play_boss_intro_cinematic(boss_node: CharacterBody2D, speaker: String, lines: Array, on_finished: Callable = Callable()) -> void:
	var typed_lines: Array[String] = []
	for item in lines:
		typed_lines.append(String(item))
	if pablita:
		pablita.set_cinematic_locked(true)
	if is_instance_valid(boss_node):
		boss_node.set_physics_process(false)
		boss_node.velocity = Vector2.ZERO

	var boss_target_pos: Vector2 = boss_node.global_position if is_instance_valid(boss_node) else (pablita.global_position + Vector2(250, 0))
	var am := AudioManagerService.get_am()
	if am:
		am.stop_music_for_dramatic_silence()
		am.play_sfx("boss_roar")
	if pablita:
		pablita.focus_camera_on(boss_target_pos, 1.1, 2.2)

	var cleanup := func():
		var am2 := AudioManagerService.get_am()
		if am2:
			am2.set_music_state("BOSS_BATTLE")
		if pablita:
			var ret_tween: Tween = pablita.return_camera_to_player(0.85)
			if ret_tween:
				ret_tween.finished.connect(func():
					if pablita:
						pablita.set_cinematic_locked(false)
					if is_instance_valid(boss_node):
						boss_node.set_physics_process(true)
					if on_finished.is_valid():
						on_finished.call()
				, CONNECT_ONE_SHOT)
			else:
				if pablita:
					pablita.set_cinematic_locked(false)
				if is_instance_valid(boss_node):
					boss_node.set_physics_process(true)
				if on_finished.is_valid():
					on_finished.call()
		else:
			if is_instance_valid(boss_node):
				boss_node.set_physics_process(true)
			if on_finished.is_valid():
				on_finished.call()

	if hud:
		hud.dialogue_closed.connect(cleanup, CONNECT_ONE_SHOT)
		hud.show_dialogue_sequence(speaker, typed_lines)
	else:
		cleanup.call()

# ---------- Acontecimentos Narrativos e Progressão das 10 Fases ----------

func _configure_level_content(lvl: int) -> void:
	var gm := GameManagerService.get_gm()
	match lvl:
		1:
			# FASE 1: Abertura fiel ao GDD:
			# Quarto de Pablita -> Cachorro Luffy -> Barulho/Brilho atrás do Guarda-Roupa ->
			# Criatura meia velha rouba o CD favorito e foge pela passagem ->
			# Pablita atravessa a passagem até o Esquecido -> Encontra o rato Chopp, que passa a acompanhá-la!
			arena_rect = Rect2i(0, 0, 760, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 230, 372), "color": Color(0.18, 0.14, 0.22), "label": "QUARTO DE PABLITA"})
			_floor_zones.append({"rect": Rect2(254, 24, 482, 372), "color": Color(0.11, 0.09, 0.16), "label": "CHEGADA AO ESQUECIDO"})
			# Parede dividindo o Quarto e o Esquecido, com passagem atrás do Guarda-Roupa (em x=254, y=180..240)
			_add_wall_block(Rect2(246, 24, 16, 156))
			_add_wall_block(Rect2(246, 240, 16, 156))

			pablita.global_position = Vector2(90, 220)
			required_story_flags = ["f1_wardrobe_checked", "f1_chopp_met"]

			if hud:
				hud.set_objective_text("Fale com Luffy e investigue o barulho atrás do Guarda-Roupa")

			# Luffy, o cachorro de Pablita, no quarto
			_spawn_npc("Luffy", Vector2(110, 140), [
				"Au! Au! (Luffy apoia as patas na beirada do tapete, farejando o ar com o focinho trêmulo.)",
				"(Ele não tira os olhos do canto do guarda-roupa. Há um sopro morno e um rangido vindo detrás da madeira.)"
			], Color(0.88, 0.58, 0.28), "f1_luffy_petted")

			# Guarda-Roupa com brilho e gatilho do roubo do CD pela meia velha
			var wardrobe_already_done: bool = gm != null and gm.has_story_flag("f1_wardrobe_checked")
			var wardrobe_gate: WorldObject = null
			if not wardrobe_already_done:
				wardrobe_gate = _spawn_crate(Vector2(254, 210))
			var empty_lines: Array[String] = []
			var wardrobe_trigger := _spawn_lore_object(Vector2(215, 210), "Afastar Guarda-Roupa e Investigar Brilho", empty_lines, "f1_wardrobe_checked")
			if wardrobe_already_done and wardrobe_trigger._interactable:
				wardrobe_trigger._interactable.is_active = false
			wardrobe_trigger.activated.connect(func(_o):
				if wardrobe_trigger._interactable:
					wardrobe_trigger._interactable.is_active = false
					wardrobe_trigger._interactable.lose_focus()
				_play_phase_1_intro_cinematic(wardrobe_gate)
			)

			# Chopp, o pequeno rato que conhece o Esquecido e passa a acompanhar Pablita
			chopp_actor = _spawn_npc("Chopp", Vector2(390, 210), [
				"Ei, cuidado onde pisa! Você caiu mesmo lá de cima?! Nunca vi alguém atravessar o guarda-roupa acordada!",
				"Eu me chamo Chopp. Tudo o que esquecem embaixo do sofá, no fundo das gavetas ou nas mudanças acaba escorregando para cá: O Esquecido.",
				"Aquela meia remendada passou correndo por aqui segurando um disco prateado... mas este lugar é traiçoeiro para andar de mãos vazias.",
				"Veja quem estava escondido atrás deste caixote: é o Pipop! Ele é meio dentuço e estranho, mas tem um coração enorme — e um grito de sacudir poeira!",
				"Com o Pipop ao seu lado, podemos abrir o selo de cristal ali adiante e seguir o rastro da ladra!"
			], Color(0.95, 0.78, 0.25), "f1_chopp_met")
			if gm != null and gm.has_story_flag("f1_chopp_met"):
				chopp_actor.start_following(pablita)
			chopp_actor.dialogue_requested.connect(func(_s, _l):
				_show_thief_visual = false
				chopp_actor.start_following(pablita)
				var gm_ref := GameManagerService.get_gm()
				if gm_ref and not gm_ref.is_pipop_acquired():
					gm_ref.unlock_pipop()
				if hud:
					hud.set_objective_text("Desperte o Cristal de Ressonância com o grito do Pipop e siga pela trilha")
				queue_redraw()
			)

			_spawn_encarte_pickup(Vector2(490, 120), "agulha_veloz", "Recolher Encarte: Agulha Veloz")
			var c1 := _spawn_sonic_crystal(Vector2(560, 140), true)
			if gm != null and gm.has_story_flag("f1_crystal_1"):
				c1.is_activated = true
			c1.activated.connect(func(_c):
				if GameManagerService.get_gm():
					GameManagerService.get_gm().set_story_flag("f1_crystal_1", true)
			)
			_spawn_exit_portal(Vector2(690, 210), 2, "Seguir Rastro da Meia Ladra")

		2:
			# FASE 2: Aprendizado de movimentação, exploração e combate (perseguindo a Meia que roubou o CD)
			arena_rect = Rect2i(0, 0, 760, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 712, 372), "color": Color(0.12, 0.10, 0.18), "label": "TRILHA DAS LEMBRANÇAS"})
			_add_wall_block(Rect2(250, 110, 24, 200))
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 1, "Voltar ao Quarto / Entrada (Fase 1)")

			chopp_actor = _spawn_npc("Chopp", Vector2(125, 165), [
				"Olhe os fiapos no chão... A meia ladra correu direto para a velha oficina de costura!",
				"Alguns objetos abandonados aqui perderam a paciência com visitantes. O Pipop pode envolver seu braço como uma manopla ou projetar a voz dele contra carapaças de vidro!",
				"Assim que abrirmos passagem, entramos no covil onde ela se escondeu."
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Abra caminho pela Trilha das Lembranças junto com Pipop e Chopp")

			_spawn_enemy(Vector2(370, 150), EnemyBase.Archetype.MELEE_RUSHER)
			_spawn_enemy(Vector2(430, 280), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_encarte_pickup(Vector2(540, 105), "eco_distante", "Recolher Encarte: Eco Distante")
			_spawn_exit_portal(Vector2(695, 210), 3, "Entrar no Covil de Costura")

		3:
			# FASE 3: Primeiro Chefe — A Meia Esquecida
			arena_rect = Rect2i(0, 0, 680, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 632, 372), "color": Color(0.15, 0.09, 0.18), "label": "COVIL DE COSTURA"})
			pablita.global_position = Vector2(95, 210)
			var f3_already_cleared: bool = (gm != null and gm.has_story_flag("f3_boss_defeated") and not gm.has_story_flag("boss_rush_revisit"))
			_spawn_return_portal(Vector2(45, 210), 2, "Retornar à Trilha (Fase 2)", not f3_already_cleared)

			required_story_flags = ["f3_boss_defeated"]
			chopp_actor = _spawn_npc("Chopp", Vector2(145, 160), [], Color(0.95, 0.78, 0.25), "f3_intro_done")
			chopp_actor.start_following(pablita)

			if f3_already_cleared:
				if hud:
					hud.set_objective_text("O Covil está silencioso. Siga para a Vila dos Achados.")
				_spawn_encarte_pickup(Vector2(360, 210), "punho_chumbo", "Recolher Encarte: Punho de Chumbo", 1, "f3_reward_taken")
				_spawn_exit_portal(Vector2(615, 210), 4, "Seguir para a Vila dos Achados")
			else:
				if gm != null and gm.has_story_flag("boss_rush_revisit"):
					gm.set_story_flag("boss_rush_revisit", false)
				if hud:
					hud.set_objective_text("Rompa as âncoras de linha e recupere o CD das garras da Meia Esquecida")

				var boss := BossSock.new()
				boss.global_position = Vector2(400, 210)
				boss.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
					if hud:
						hud.show_boss_health(bname, cur, mx)
				)
				active_enemies_count += 1
				boss.boss_defeated.connect(func():
					active_enemies_count = 0
					if return_portal and is_instance_valid(return_portal):
						return_portal.set_locked(false)
					if hud:
						hud.hide_boss_health()
						hud.set_objective_text("Examine o que restou e siga para a Vila dos Achados")
						hud.show_dialogue_sequence("Chopp", [
							"Os fios cederam! Mas... espere um segundo, Pablita. Esta é só a capa acrílica do seu CD!",
							"O disco de verdade não está aqui! Olhe as marcas de engrenagem no chão: os coletores da Rainha Empoeirada já levaram o disco para a Forja.",
							"Vamos até a Vila dos Achados logo adiante. Os moradores de lá conhecem todos os atalhos deste mundo!"
						])
					if gm:
						gm.set_story_flag("f3_boss_defeated", true)
					_spawn_encarte_pickup(Vector2(360, 210), "punho_chumbo", "Recolher Encarte: Punho de Chumbo", 1, "f3_reward_taken")
					_refresh_portal_lock()
				)
				add_child(boss)
				if hud:
					hud.show_boss_health(boss.boss_title, boss.max_health, boss.max_health)
				_spawn_exit_portal(Vector2(615, 210), 4, "Seguir para a Vila dos Achados")

				call_deferred("_play_boss_intro_cinematic", boss, "Chopp", [
					"Ali está ela! A Meia Esquecida que pulou no seu quarto!",
					"Veja só: ela amarrou toda a sala em três carretéis de linha ressonante para amortecer qualquer golpe direto.",
					"Se o Pipop gritar contra aqueles cristais de ancoragem, a trama inteira desaba e ela fica sem defesa!"
				])

		4:
			# FASE 4: Comunidade pacífica de objetos no Esquecido (Vila dos Achados)
			arena_rect = Rect2i(0, 0, 780, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 732, 392), "color": Color(0.10, 0.14, 0.18), "label": "VILA DOS ACHADOS"})
			_add_wall_block(Rect2(360, 24, 24, 150))
			_add_wall_block(Rect2(360, 260, 24, 156))
			pablita.global_position = Vector2(90, 220)
			_spawn_return_portal(Vector2(45, 220), 3, "Retornar ao Covil (Fase 3)")
			required_story_flags = ["f4_talked_villager"]

			if hud:
				hud.set_objective_text("Converse com os moradores da Vila dos Achados sobre o rumo do seu CD")

			chopp_actor = _spawn_npc("Chopp", Vector2(130, 165), [
				"Respire fundo, Pablita. Aqui é a Vila dos Achados — um refúgio tranquilo onde botões soltos, xícaras e brinquedos antigos cuidam uns dos outros.",
				"Converse com o Sr. Despertador ou com a Dona Xícara. Eles sempre ouvem quando o cortejo da Rainha passa."
			])
			chopp_actor.start_following(pablita)

			_spawn_npc("Sr. Despertador", Vector2(260, 310), [
				"Tic-tac, atrasado, sempre atrasado... Oh! Uma menina de verdade, com cheiro de sol e papel novo!",
				"Eu vi, sim! Os autômatos carregaram um disco reluzente como espelho rumo à Forja Rítmica.",
				"O velho Robô Esquecido vigia a ponte. Ele tem o coração no compasso de um metrônomo: quando o peito dele cantar em azul, faça o seu amigo dentuço responder no mesmo tom!"
			], Color(0.4, 0.85, 0.95), "f4_talked_villager")

			_spawn_npc("Dona Xícara", Vector2(500, 130), [
				"Cuidado para não lascar a borda lá fora, querida. A Rainha Empoeirada não rouba por maldade... ela tem pavor do silêncio de quando ninguém mais lembra do nosso nome.",
				"Fique com aquele Encarte perto da bancada. Vai manter seus ouvidos atentos nas Ruínas Sonoras."
			], Color(0.95, 0.55, 0.8), "f4_talked_villager")

			_spawn_npc(" Soldadinho de Chumbo Sem Tinta", Vector2(610, 250), [
				"Eu costumava morar numa caixa de sapatos debaixo da cama de alguém. Aqui na vila ninguém exige que a gente esteja inteiro para fazer parte da roda."
			], Color(0.55, 0.78, 0.62), "f4_talked_villager")

			_spawn_crate(Vector2(372, 200))
			_spawn_crate(Vector2(372, 230))
			_spawn_encarte_pickup(Vector2(540, 320), "olhar_atento", "Recolher Encarte: Olhar Atento")
			_spawn_exit_portal(Vector2(715, 220), 5, "Seguir para as Ruínas Sonoras")

		5:
			# FASE 5: Desafios ambientais e combinação das habilidades (Físico + Sônico)
			arena_rect = Rect2i(0, 0, 780, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 732, 392), "color": Color(0.13, 0.12, 0.16), "label": "PASSAGENS TRANCADAS"})
			_add_wall_block(Rect2(250, 130, 180, 20))
			_add_wall_block(Rect2(250, 290, 180, 20))
			pablita.global_position = Vector2(90, 220)
			_spawn_return_portal(Vector2(45, 220), 4, "Voltar à Vila dos Achados (Fase 4)")

			chopp_actor = _spawn_npc("Chopp", Vector2(130, 165), [
				"As comportas antigas da galeria só cedem quando os dois diapasões de cristal vibram juntos.",
				"Derrube as barricadas de madeira e faça a voz do Pipop ecoar pelos dois corredores laterais!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Desobstrua o corredor, sintonize os 2 Cristais e supere os sentinelas")

			_spawn_crate(Vector2(210, 220))
			var c5_a := _spawn_sonic_crystal(Vector2(340, 80), true)
			var c5_b := _spawn_sonic_crystal(Vector2(340, 360), true)
			if gm != null and gm.has_story_flag("f5_crystals_done"):
				c5_a.is_activated = true
				c5_b.is_activated = true
			_spawn_enemy(Vector2(430, 220), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_enemy(Vector2(560, 150), EnemyBase.Archetype.THREAD_TRAPPER)
			_spawn_enemy(Vector2(560, 290), EnemyBase.Archetype.MELEE_RUSHER)
			_spawn_encarte_pickup(Vector2(340, 220), "onda_larga", "Recolher Encarte: Onda Larga")
			_spawn_exit_portal(Vector2(715, 220), 6, "Avançar para a Antecâmara da Engrenagem")

		6:
			# FASE 6: Preparação para o segundo chefe
			arena_rect = Rect2i(0, 0, 740, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 692, 372), "color": Color(0.14, 0.11, 0.14), "label": "ANTECÂMARA DA ENGRENAGEM"})
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 5, "Retornar às Passagens (Fase 5)")

			chopp_actor = _spawn_npc("Chopp", Vector2(135, 155), [
				"Sente o chão tremer em compasso? A Forja Rítmica fica logo atrás daquela porta blindada.",
				"Os guardas de lata daqui marcham num tempo certinho. Se quiser reforçar nossa defesa antes da ponte, o Casulo de Retalhos está logo ali!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Atravesse a Antecâmara da Engrenagem e prepare seus Encartes")

			_spawn_enemy(Vector2(360, 160), EnemyBase.Archetype.RHYTHM_BRUTE)
			_spawn_enemy(Vector2(470, 260), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_encarte_pickup(Vector2(550, 110), "casulo_retalhos", "Recolher Encarte: Casulo de Retalhos")
			_spawn_exit_portal(Vector2(675, 210), 7, "Entrar na Forja Rítmica")

		7:
			# FASE 7: Segundo Chefe — O Robô Esquecido (Ritmo e sincronização)
			arena_rect = Rect2i(0, 0, 680, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 632, 372), "color": Color(0.12, 0.14, 0.18), "label": "FORJA RÍTMICA"})
			pablita.global_position = Vector2(95, 210)
			var f7_already_cleared: bool = (gm != null and gm.has_story_flag("f7_boss_defeated") and not gm.has_story_flag("boss_rush_revisit"))
			_spawn_return_portal(Vector2(45, 210), 6, "Recuar para a Antecâmara (Fase 6)", not f7_already_cleared)
			required_story_flags = ["f7_boss_defeated"]

			chopp_actor = _spawn_npc("Chopp", Vector2(140, 155), [])
			chopp_actor.start_following(pablita)

			if f7_already_cleared:
				if hud:
					hud.set_objective_text("A ponte da Forja está livre. Siga para as Profundezas Desbotadas.")
				_spawn_encarte_pickup(Vector2(360, 210), "amplificador_ruido", "Recolher Encarte: Amplificador de Ruído", 1, "f7_reward_taken")
				_spawn_exit_portal(Vector2(615, 210), 8, "Avançar para as Profundezas Desbotadas")
			else:
				if gm != null and gm.has_story_flag("boss_rush_revisit"):
					gm.set_story_flag("boss_rush_revisit", false)
				if hud:
					hud.set_objective_text("Responda ao pulso azul do Robô Esquecido com o grito do Pipop")

				var robot := BossRobot.new()
				robot.global_position = Vector2(400, 210)
				robot.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
					if hud:
						hud.show_boss_health(bname, cur, mx)
				)
				active_enemies_count += 1
				robot.boss_defeated.connect(func():
					active_enemies_count = 0
					if return_portal and is_instance_valid(return_portal):
						return_portal.set_locked(false)
					if hud:
						hud.hide_boss_health()
						hud.set_objective_text("Atravesse a ponte liberada rumo às Profundezas Desbotadas")
						hud.show_dialogue_sequence("O Robô Esquecido", [
							"CLANC... Tique... O turno... finalmente terminou? Fazia tanto tempo que ninguém batia palma no ritmo da minha música...",
							"Podem passar, pequenos viajantes. A Rainha guarda o disco brilhante no alto do Vitral Empoeirado."
						])
					if gm:
						gm.set_story_flag("f7_boss_defeated", true)
					_spawn_encarte_pickup(Vector2(360, 210), "amplificador_ruido", "Recolher Encarte: Amplificador de Ruído", 1, "f7_reward_taken")
					_refresh_portal_lock()
				)
				add_child(robot)
				if hud:
					hud.show_boss_health(robot.boss_title, robot.max_health, robot.max_health)
				_spawn_exit_portal(Vector2(615, 210), 8, "Avançar para as Profundezas Desbotadas")

				call_deferred("_play_boss_intro_cinematic", robot, "Chopp", [
					"Escute o compasso da fornalha, Pablita! O Robô Esquecido ainda acha que precisa guardar a fábrica sozinho.",
					"A blindagem dele é dura demais para bater de frente, mas antes de cada golpe o núcleo dele respira num brilho azul.",
					"Quando o peito dele brilhar em azul, faça o Pipop soltar a voz para desencaixar as placas dele!"
				])

		8:
			# FASE 8: Região mais perigosa e desenvolvimento narrativo
			arena_rect = Rect2i(0, 0, 800, 460)
			_floor_zones.append({"rect": Rect2(24, 24, 752, 412), "color": Color(0.16, 0.08, 0.14), "label": "PROFUNDEZAS DESBOTADAS"})
			_add_wall_block(Rect2(270, 140, 24, 180))
			_add_wall_block(Rect2(510, 90, 24, 120))
			_add_wall_block(Rect2(510, 260, 24, 120))
			pablita.global_position = Vector2(90, 230)
			_spawn_return_portal(Vector2(45, 230), 7, "Voltar à Forja (Fase 7)")

			chopp_actor = _spawn_npc("Chopp", Vector2(135, 175), [
				"Fique perto de mim, Pablita... Aqui até as cores começam a falhar. São as lembranças que quase ninguém no mundo de cima consegue recordar.",
				"Se despertarmos os dois cristais antigos e passarmos pelas tecelãs da Rainha, chegaremos direto à escadaria do trono."
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Desperte os 2 Cristais das Profundezas e abra caminho até a escadaria")

			_spawn_lore_object(Vector2(220, 350), "Ler Placa Desbotada", [
				"'Ela já foi a boneca mais querida da estante. Quando a infância da dona passou e a trancaram num baú escuro, jurou que nenhuma memória voltaria a ficar sozinha.'"
			])

			_spawn_sonic_crystal(Vector2(220, 80), true)
			_spawn_sonic_crystal(Vector2(460, 380), true)
			_spawn_enemy(Vector2(370, 150), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_enemy(Vector2(390, 310), EnemyBase.Archetype.RHYTHM_BRUTE)
			_spawn_enemy(Vector2(620, 230), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_encarte_pickup(Vector2(620, 100), "passo_vento", "Recolher Encarte: Passo de Vento")
			_spawn_exit_portal(Vector2(735, 230), 9, "Subir ao Salão Antes do Trono")

		9:
			# FASE 9: Preparação para o confronto final
			arena_rect = Rect2i(0, 0, 740, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 692, 372), "color": Color(0.15, 0.11, 0.18), "label": "SALÃO ANTES DO TRONO"})
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 8, "Voltar às Profundezas (Fase 8)")
			required_story_flags = ["f9_chopp_ready"]

			chopp_actor = _spawn_npc("Chopp", Vector2(150, 155), [
				"É logo atrás daquelas cortinas, Pablita. Eu consigo ver o reflexo do seu CD preso no centro do vitral!",
				"E olhe só: a corrente de ar quente que vem lá de trás é a fresta direto para o seu quarto e para o Luffy.",
				"A Rainha se esconde atrás de uma redoma de vidro antes de usar as linhas de marionete. Use a voz do Pipop para rachar a redoma e não solte a mão dele por nada!"
			], Color(0.95, 0.78, 0.25), "f9_chopp_ready")
			chopp_actor.start_following(pablita)
			if gm == null or not gm.has_story_flag("f9_chopp_ready"):
				if chopp_actor.interactable:
					chopp_actor.interactable.is_active = true
				chopp_actor.dialogue_requested.connect(func(_s, _l):
					if chopp_actor.interactable:
						chopp_actor.interactable.is_active = false
						chopp_actor.interactable.lose_focus()
				)

			if hud:
				hud.set_objective_text("Converse com Chopp, examine o Altar de Memória e vença a guarda real")

			_spawn_encarte_pickup(Vector2(330, 125), "", "Absorver Núcleo de Memória (+2 Capacidade e Restauração)", 2, "f9_altar_core_taken")
			_spawn_enemy(Vector2(460, 160), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_enemy(Vector2(460, 270), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_exit_portal(Vector2(675, 210), 10, "Entrar no Vitral Empoeirado")

		10:
			# FASE 10: Chefe Final — A Rainha Empoeirada (3 fases) e Epílogo Emocional
			arena_rect = Rect2i(0, 0, 700, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 652, 392), "color": Color(0.18, 0.10, 0.20), "label": "O VITRAL EMPOEIRADO"})
			pablita.global_position = Vector2(95, 220)
			_spawn_return_portal(Vector2(45, 220), 9, "Recuar ao Salão (Fase 9)", true)

			chopp_actor = _spawn_npc("Chopp", Vector2(140, 160), [])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Liberte seu CD favorito e ajude a Rainha Empoeirada a descansar")

			var queen := BossQueen.new()
			queen.global_position = Vector2(420, 220)
			queen.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
				if hud:
					hud.show_boss_health(bname, cur, mx)
			)
			active_enemies_count += 1
			queen.boss_defeated.connect(func():
				active_enemies_count = 0
				if return_portal and is_instance_valid(return_portal):
					return_portal.set_locked(false)
				var gm2 := GameManagerService.get_gm()
				if gm2:
					gm2.set_story_flag("f10_queen_defeated", true)
				if hud:
					hud.hide_boss_health()
					hud.set_objective_text("CD Recuperado! Despeça-se de Chopp e volte para o quarto!")
					var epilogue_lines: Array[String] = [
						"A redoma se desfaz em poeira dourada. No centro do salão, a Rainha Empoeirada senta-se devagar, segurando o CD com cuidado antes de estendê-lo para você.",
						"A Rainha Empoeirada: 'Você atravessou toda a poeira só por causa deste disco... Então ele realmente ainda é lembrado.'",
						"Pablita: 'Eu nunca esqueci dele. E agora que conheci vocês... também não vou esquecer deste lugar.'",
						"Chopp ajeita os bigodes com um sorriso orgulhoso, enquanto Pipop dá um pulinho no seu ombro.",
						"Chopp: 'Ouviu isso, Luffy? Estamos mandando ela de volta! Quando sentir saudade, Pablita, basta espiar atrás do guarda-roupa!'"
					]
					hud.dialogue_closed.connect(func():
						if GameManagerService.get_gm():
							GameManagerService.get_gm().complete_campaign()
					, CONNECT_ONE_SHOT)
					hud.show_dialogue_sequence("Epílogo — O Que Permanece Lembrado", epilogue_lines)
					if gm2:
						gm2.complete_campaign()
				else:
					if gm2:
						gm2.complete_campaign()
			)
			add_child(queen)
			if hud:
				hud.show_boss_health(queen.get_phase_title(), queen.max_health, queen.max_health)

			call_deferred("_play_boss_intro_cinematic", queen, "A Rainha Empoeirada", [
				"Mais uma criança do andar de cima que só percebe o valor de um tesouro depois que ele escorrega para a sombra...",
				"Este disco brilha tão bonito no meu vitral! Aqui embaixo, nada envelhece e ninguém é deixado numa gaveta trancada.",
				"Chopp: 'Pablita, a redoma de cristal dela reflete golpes comuns! Use o grito do Pipop para abrir brecha na vitrine e mostre a ela que sua lembrança ainda está viva!'"
			])

func _draw() -> void:
	draw_rect(Rect2(arena_rect), Color(0.08, 0.06, 0.11, 1.0), true)

	for z: Dictionary in _floor_zones:
		var zr: Rect2 = z["rect"]
		var zc: Color = z["color"]
		draw_rect(zr, zc, true)
		draw_rect(zr, zc.lightened(0.25), false, 1.5)

	# Evolução estética de chão e cenografia inspirada no pacote conceitual (Fases 1 -> 10)
	_draw_environment_art_details()

	for x in range(arena_rect.position.x, arena_rect.end.x, 32):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), Color(1, 1, 1, 0.035), 1.0)
	for y in range(arena_rect.position.y, arena_rect.end.y, 32):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), Color(1, 1, 1, 0.035), 1.0)

	for wr: Rect2 in _wall_rects:
		var wall_fill: Color = Color(0.28, 0.24, 0.36, 1.0)
		var wall_border: Color = Color(0.65, 0.58, 0.80, 1.0)
		if level_number <= 3:
			wall_fill = Color(0.32, 0.24, 0.22, 1.0)
			wall_border = Color(0.72, 0.56, 0.44, 1.0)
		elif level_number >= 7:
			wall_fill = Color(0.22, 0.16, 0.32, 1.0)
			wall_border = Color(0.58, 0.42, 0.85, 1.0)
		draw_rect(wr, wall_fill, true)
		draw_rect(wr, wall_border, false, 1.8)

	if _show_thief_visual:
		draw_circle(_thief_visual_pos + Vector2(0, 4), 10.0, Color(0.04, 0.02, 0.06, 0.5))
		draw_circle(_thief_visual_pos, 11.0, Color(0.85, 0.32, 0.72, 1.0))
		draw_arc(_thief_visual_pos, 11.0, 0.0, TAU, 16, Color(0.35, 0.10, 0.30, 1.0), 1.6)
		draw_line(_thief_visual_pos + Vector2(-6, -2), _thief_visual_pos + Vector2(6, 4), Color(1.0, 0.85, 0.4, 0.9), 1.5)
		var cd_pos := _thief_visual_pos + Vector2(10, -7)
		draw_circle(cd_pos, 7.5, Color(0.35, 0.95, 1.0, 1.0))
		draw_circle(cd_pos, 2.8, Color(0.10, 0.08, 0.14, 1.0))
		draw_arc(cd_pos, 7.5, 0.0, TAU, 16, Color(1, 1, 1, 0.9), 1.2)

func _draw_environment_art_details() -> void:
	match level_number:
		1:
			# Quarto de Pablita (esquerda: madeira aconchegante, cama, tapete estrelado, escrivaninha, caminha do Luffy)
			var bedroom_rect := Rect2(28, 28, 216, 364)
			draw_rect(bedroom_rect, Color(0.34, 0.23, 0.16, 0.88), true)
			for wy in range(36, 384, 18):
				draw_line(Vector2(28, wy), Vector2(244, wy), Color(0.24, 0.15, 0.10, 0.55), 1.0)
			# Tapete oval aconchegante no centro do quarto
			draw_circle(Vector2(130, 220), 46.0, Color(0.28, 0.32, 0.52, 0.85))
			draw_arc(Vector2(130, 220), 46.0, 0.0, TAU, 24, Color(0.92, 0.78, 0.48, 0.85), 2.0)
			# Cama de Pablita (canto superior esquerdo)
			draw_rect(Rect2(36, 42, 64, 92), Color(0.42, 0.25, 0.18, 1.0), true)
			draw_rect(Rect2(40, 48, 56, 24), Color(0.95, 0.92, 0.86, 1.0), true)
			draw_rect(Rect2(40, 72, 56, 56), Color(0.75, 0.32, 0.42, 1.0), true)
			# Caminha do Luffy
			draw_circle(Vector2(110, 142), 18.0, Color(0.62, 0.35, 0.24, 0.9))
			draw_circle(Vector2(110, 142), 13.0, Color(0.85, 0.68, 0.48, 0.9))
			# Escrivaninha (onde ficava o CD) e abajur âmbar
			draw_rect(Rect2(158, 42, 68, 30), Color(0.46, 0.30, 0.20, 1.0), true)
			draw_circle(Vector2(172, 56), 28.0, Color(1.0, 0.82, 0.42, 0.18))
			# Guarda-Roupa na divisória (x=230..246)
			draw_rect(Rect2(226, 155, 20, 110), Color(0.38, 0.22, 0.15, 1.0), true)
			draw_rect(Rect2(226, 155, 20, 110), Color(0.85, 0.68, 0.42, 0.9), false, 1.5)
			# Lado direito (Chegada ao Esquecido integrado a tábuas soltas do quarto)
			for i in range(6):
				var px: float = 290.0 + float(i) * 68.0
				var py: float = 80.0 + float((i * 97) % 240)
				draw_rect(Rect2(px, py, 36, 12), Color(0.34, 0.24, 0.18, 0.55), true)
				draw_circle(Vector2(px + 18.0, py + 24.0), 4.0, Color(0.68, 0.42, 0.95, 0.45))
		2, 3:
			# Fases 2 e 3: Esquecido integrado ao Quarto (tábuas flutuantes, carretéis de linha e luz âmbar/violeta)
			for i in range(8):
				var px: float = 80.0 + float(i) * 70.0
				var py: float = 65.0 + float((i * 113) % 270)
				draw_rect(Rect2(px, py, 42, 14), Color(0.32, 0.22, 0.18, 0.48), true)
			if level_number == 3:
				# Fios de costura no Covil da Meia Esquecida
				draw_line(Vector2(60, 60), Vector2(580, 360), Color(0.85, 0.55, 0.85, 0.18), 1.5)
				draw_line(Vector2(60, 360), Vector2(580, 60), Color(0.85, 0.55, 0.85, 0.18), 1.5)
				draw_arc(Vector2(410, 210), 85.0, 0.0, TAU, 32, Color(0.92, 0.45, 0.78, 0.22), 2.0)
		4:
			# Fase 4: Vila dos Achados (praça acolhedora de paralelepípedos, tapetes de retalhos e lanternas quentes)
			draw_circle(Vector2(360, 210), 95.0, Color(0.32, 0.25, 0.36, 0.55))
			draw_arc(Vector2(360, 210), 95.0, 0.0, TAU, 36, Color(0.95, 0.78, 0.45, 0.45), 2.0)
			for lamp_pos: Vector2 in [Vector2(230, 120), Vector2(360, 260), Vector2(450, 140)]:
				draw_circle(lamp_pos, 38.0, Color(1.0, 0.82, 0.42, 0.14))
				draw_circle(lamp_pos, 4.0, Color(1.0, 0.90, 0.55, 0.85))
		5, 6, 7:
			# Fases 5 a 7: Transição e Forja Rítmica (lajes de ardósia, trilhos e engrenagens de bronze)
			for i in range(5):
				var gx: float = 140.0 + float(i) * 115.0
				var gy: float = 210.0 + (55.0 if i % 2 == 0 else -55.0)
				draw_arc(Vector2(gx, gy), 22.0, 0.0, TAU, 16, Color(0.72, 0.55, 0.32, 0.28), 2.2)
				draw_circle(Vector2(gx, gy), 6.0, Color(0.45, 0.78, 0.95, 0.25))
		8, 9, 10:
			# Fases 8 a 10: Esquecido Profundo e O Vitral Empoeirado (pedra violeta escura, cristais bioluminescentes e vitral)
			for i in range(7):
				var cx: float = 95.0 + float(i) * 85.0
				var cy: float = 70.0 + float((i * 137) % 290)
				draw_circle(Vector2(cx, cy), 16.0, Color(0.65, 0.32, 0.95, 0.14))
				draw_circle(Vector2(cx, cy), 3.5, Color(0.82, 0.58, 1.0, 0.65))
			if level_number == 10:
				# Rosácea do Vitral Empoeirado no chão do trono
				var center := Vector2(420, 220)
				draw_circle(center, 110.0, Color(0.42, 0.22, 0.58, 0.22))
				draw_arc(center, 110.0, 0.0, TAU, 36, Color(0.95, 0.78, 0.42, 0.45), 2.2)
				draw_arc(center, 68.0, 0.0, TAU, 28, Color(0.55, 0.88, 1.0, 0.35), 1.8)

