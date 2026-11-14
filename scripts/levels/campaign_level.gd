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
		gm.set_game_state(GameManagerService.GameState.PLAYING)
		if not gm.story_flag_changed.is_connected(_on_story_flag_changed):
			gm.story_flag_changed.connect(_on_story_flag_changed)

	_ensure_player_and_hud()
	_configure_level_content(level_number)
	_build_boundary_and_internal_walls()
	pablita.set_camera_limits(arena_rect)
	_refresh_portal_lock()
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

func _spawn_encarte_pickup(pos: Vector2, encarte_id: String, prompt: String, cap_bonus: int = 0) -> ForgottenCDItem:
	var scene: PackedScene = load("res://scenes/environments/forgotten_cd_item.tscn")
	var item := scene.instantiate() as ForgottenCDItem
	item.grant_encarte_id = encarte_id
	item.grant_capacity_bonus = cap_bonus
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

func _spawn_return_portal(pos: Vector2, prev_lvl: int, custom_prompt: String = "Caminho Conhecido (Retornar)") -> WorldObject:
	return_portal = WorldObject.new()
	return_portal.object_type = WorldObject.ObjectType.LEVEL_PORTAL
	return_portal.target_level_index = prev_lvl
	return_portal.is_locked = false
	return_portal.prompt_text = custom_prompt
	return_portal.global_position = pos
	add_child(return_portal)
	if return_portal._interactable:
		return_portal._interactable.prompt_message = custom_prompt
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
			_spawn_npc("Luffy (Cachorro)", Vector2(110, 140), [
				"Au! Au! (Luffy está acordado ao pé da cama, olhando fixamente para o Guarda-Roupa.)",
				"(Um barulho abafado e um brilho estranho vêm detrás do Guarda-Roupa!)"
			], Color(0.88, 0.58, 0.28), "f1_luffy_petted")

			# Guarda-Roupa com brilho e gatilho do roubo do CD pela meia velha
			var wardrobe_gate := _spawn_crate(Vector2(254, 210))
			var wardrobe_trigger := _spawn_lore_object(Vector2(215, 210), "Investigar Brilho no Guarda-Roupa", [
				"Você afasta o Guarda-Roupa e vê uma passagem brilhante!",
				"De repente, uma criatura parecida com uma MEIA VELHA salta, agarra o CD do seu filme favorito e foge pela passagem!",
				"Luffy late preocupado. Quebre as tábuas da passagem [SOCO] ou atravesse para seguir a criatura!"
			], "f1_wardrobe_checked")
			wardrobe_trigger.activated.connect(func(_o):
				_show_thief_visual = true
				_thief_visual_pos = Vector2(310, 210)
				if is_instance_valid(wardrobe_gate):
					wardrobe_gate.queue_free()
				if hud:
					hud.set_objective_text("Siga a meia ladra pela passagem e fale com Chopp no Esquecido")
				queue_redraw()
			)

			# Chopp, o pequeno rato que conhece o Esquecido e passa a acompanhar Pablita
			chopp_actor = _spawn_npc("Chopp (Rato Guia)", Vector2(390, 210), [
				"Ei! Você veio do mundo lá de cima?! Eu vi uma Meia Esquecida correndo com um CD brilhante para a Trilha das Lembranças!",
				"Prazer, sou o Chopp! Este lugar é O Esquecido — tudo o que perdem ou deixam para trás acaba caindo aqui.",
				"Não se preocupe, você pode entrar e sair por caminhos conhecidos, mas para recuperar seu CD vou acompanhar você! Ative aquele Cristal Sônico [SOM] e vamos!"
			], Color(0.95, 0.78, 0.25), "f1_chopp_met")
			chopp_actor.dialogue_requested.connect(func(_s, _l):
				_show_thief_visual = false
				chopp_actor.start_following(pablita)
				if hud:
					hud.set_objective_text("Ative o Cristal Sônico [SOM], colete o Encarte e avance para a Fase 2")
				queue_redraw()
			)

			_spawn_encarte_pickup(Vector2(490, 120), "agulha_veloz", "Coletar Encarte: Agulha Veloz")
			_spawn_sonic_crystal(Vector2(560, 140), true)
			_spawn_exit_portal(Vector2(690, 210), 2, "Seguir Rastro da Meia Ladra (Fase 2)")

		2:
			# FASE 2: Aprendizado de movimentação, exploração e combate (perseguindo a Meia que roubou o CD)
			arena_rect = Rect2i(0, 0, 760, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 712, 372), "color": Color(0.12, 0.10, 0.18), "label": "FASE 2: TRILHA DAS LEMBRANÇAS"})
			_add_wall_block(Rect2(250, 110, 24, 200))
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 1, "Voltar ao Quarto / Entrada (Fase 1)")

			chopp_actor = _spawn_npc("Chopp", Vector2(125, 165), [
				"A Meia Esquecida fugiu por esta trilha levando o seu CD!",
				"Alguns habitantes daqui ficaram ariscos. Use o SOCO FÍSICO nos vermelhos e o ROSNADO SÔNICO do Pipop para quebrar o escudo azul!",
				"Quando limparmos o caminho, entraremos no covil dela na Fase 3."
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Derrote os guardas da Meia usando Soco [Físico] e Som [Sônico]")

			_spawn_enemy(Vector2(370, 150), EnemyBase.Archetype.MELEE_RUSHER)
			_spawn_enemy(Vector2(430, 280), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_encarte_pickup(Vector2(540, 105), "eco_distante", "Coletar Encarte: Eco Distante")
			_spawn_exit_portal(Vector2(695, 210), 3, "Entrar no Covil da Meia Esquecida (Fase 3)")

		3:
			# FASE 3: Primeiro Chefe — A Meia Esquecida (Apresentação narrativa antes do confronto!)
			arena_rect = Rect2i(0, 0, 680, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 632, 372), "color": Color(0.15, 0.09, 0.18), "label": "FASE 3: COVIL DE COSTURA — CHEFE: A MEIA ESQUECIDA"})
			pablita.global_position = Vector2(95, 210)
			_spawn_return_portal(Vector2(45, 210), 2, "Retornar à Trilha (Fase 2)")

			required_story_flags = ["f3_boss_defeated"]
			if hud:
				hud.set_objective_text("Confronte A Meia Esquecida que roubou seu CD (Fale com Chopp)")

			chopp_actor = _spawn_npc("Chopp", Vector2(145, 160), [
				"Ali está ela! A Meia Esquecida que roubou o seu CD lá no quarto!",
				"Olhe: ela prendeu o CD numa teia ligada a 3 Pontos de Ancoragem. Ataques físicos quase não causam dano enquanto as âncoras estiverem ativas!",
				"Dispare o ATAQUE SÔNICO [SOM] nas âncoras para romper o controle da arena e então golpeie com a MANOPLA FÍSICA!"
			], Color(0.95, 0.78, 0.25), "f3_intro_done")
			chopp_actor.start_following(pablita)

			var boss := BossSock.new()
			boss.global_position = Vector2(400, 210)
			boss.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
				if hud:
					hud.show_boss_health(bname, cur, mx)
			)
			active_enemies_count += 1
			boss.boss_defeated.connect(func():
				active_enemies_count = 0
				if hud:
					hud.hide_boss_health()
					hud.set_objective_text("Pegue a pista do CD e siga para a Vila dos Achados (Fase 4)")
					hud.show_dialogue_sequence("Chopp", [
						"Conseguimos! A Meia Esquecida se desfez... mas espere: a caixa do CD está vazia!",
						"Os mensageiros da Rainha Empoeirada levaram o disco para a Forja do Robô Esquecido. Vamos perguntar aos moradores da Vila dos Achados na Fase 4!"
					])
				if gm:
					gm.set_story_flag("f3_boss_defeated", true)
				_spawn_encarte_pickup(Vector2(360, 210), "punho_chumbo", "Coletar Encarte: Punho de Chumbo (+1 Capacidade)", 1)
				_refresh_portal_lock()
			)
			add_child(boss)
			if hud:
				hud.show_boss_health(boss.boss_title, boss.max_health, boss.max_health)
			_spawn_exit_portal(Vector2(615, 210), 4, "Ir para a Vila dos Achados (Fase 4)")

		4:
			# FASE 4: Expansão da exploração, nova região (comunidade pacífica de objetos) e NPCs
			arena_rect = Rect2i(0, 0, 780, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 732, 392), "color": Color(0.10, 0.14, 0.18), "label": "FASE 4: VILA DOS ACHADOS (COMUNIDADE DO ESQUECIDO)"})
			_add_wall_block(Rect2(360, 24, 24, 150))
			_add_wall_block(Rect2(360, 260, 24, 156))
			pablita.global_position = Vector2(90, 220)
			_spawn_return_portal(Vector2(45, 220), 3, "Retornar ao Covil (Fase 3)")
			required_story_flags = ["f4_talked_villager"]

			if hud:
				hud.set_objective_text("Converse com os habitantes da Vila dos Achados sobre o paradeiro do CD")

			chopp_actor = _spawn_npc("Chopp", Vector2(130, 165), [
				"Esta é a Vila dos Achados! Nem todos no Esquecido são hostis — muitos objetos vivem em comunidade aqui.",
				"Converse com o Sr. Despertador ou com a Boneca de Porcelana para descobrirmos como entrar na Forja do Robô Esquecido."
			])
			chopp_actor.start_following(pablita)

			_spawn_npc("Sr. Despertador (Habitante)", Vector2(260, 310), [
				"Tic-tac! Uma visitante do Quarto de Cima? Sim, eu vi os soldados levando um CD brilhante para a Forja Rítmica!",
				"O Robô Esquecido guarda a ponte na Fase 7. Quando o núcleo dele vibrar em AZUL, dispare SOM para expor as engrenagens dele!"
			], Color(0.4, 0.85, 0.95), "f4_talked_villager")

			_spawn_npc("Dona Xícara (Comerciante de Memórias)", Vector2(500, 130), [
				"A Rainha Empoeirada coleciona memórias queridas porque teme ser esquecida para sempre.",
				"Pegue o Encarte do Olhar Atento ali embaixo — vai ajudar você e o Chopp nas Ruínas Sonoras da Fase 5!"
			], Color(0.95, 0.55, 0.8), "f4_talked_villager")

			_spawn_crate(Vector2(372, 200))
			_spawn_crate(Vector2(372, 230))
			_spawn_encarte_pickup(Vector2(540, 320), "olhar_atento", "Coletar Encarte: Olhar Atento")
			_spawn_enemy(Vector2(630, 220), EnemyBase.Archetype.THREAD_TRAPPER)
			_spawn_exit_portal(Vector2(715, 220), 5, "Seguir para as Ruínas Sonoras (Fase 5)")

		5:
			# FASE 5: Desafios ambientais e combinação das habilidades (Físico + Sônico)
			arena_rect = Rect2i(0, 0, 780, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 732, 392), "color": Color(0.13, 0.12, 0.16), "label": "FASE 5: PASSAGENS TRANCADAS — COMBINANDO FÍSICO E SÔNICO"})
			_add_wall_block(Rect2(250, 130, 180, 20))
			_add_wall_block(Rect2(250, 290, 180, 20))
			pablita.global_position = Vector2(90, 220)
			_spawn_return_portal(Vector2(45, 220), 4, "Voltar à Vila dos Achados (Fase 4)")

			chopp_actor = _spawn_npc("Chopp", Vector2(130, 165), [
				"As comportas para a Forja estão trancadas por dois Cristais de Ressonância e caixotes pesados.",
				"Quebre os caixotes com a MANOPLA FÍSICA [SOCO] e ative os dois Cristais à distância com o ROSNADO SÔNICO [SOM]!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Quebre as barreiras [SOCO], ative os 2 Cristais [SOM] e derrote os guardas")

			_spawn_crate(Vector2(210, 220))
			_spawn_sonic_crystal(Vector2(340, 80), true)
			_spawn_sonic_crystal(Vector2(340, 360), true)
			_spawn_enemy(Vector2(430, 220), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_enemy(Vector2(560, 150), EnemyBase.Archetype.THREAD_TRAPPER)
			_spawn_enemy(Vector2(560, 290), EnemyBase.Archetype.MELEE_RUSHER)
			_spawn_encarte_pickup(Vector2(340, 220), "onda_larga", "Coletar Encarte: Onda Larga")
			_spawn_exit_portal(Vector2(715, 220), 6, "Avançar para a Antecâmara da Forja (Fase 6)")

		6:
			# FASE 6: Preparação para o segundo chefe
			arena_rect = Rect2i(0, 0, 740, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 692, 372), "color": Color(0.14, 0.11, 0.14), "label": "FASE 6: ANTECÂMARA DA ENGRENAGEM"})
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 5, "Retornar às Passagens (Fase 5)")

			chopp_actor = _spawn_npc("Chopp", Vector2(135, 155), [
				"Ouviu esse som metálico? O Robô Esquecido está logo adiante na Fase 7.",
				"Estes autômatos laranjas atacam em ritmo cadenciado. Treine o tempo de resposta e equipe o Encarte do Casulo de Retalhos se quiser mais proteção!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Supere os autômatos rítmicos e prepare seus Encartes para o Robô Esquecido")

			_spawn_enemy(Vector2(360, 160), EnemyBase.Archetype.RHYTHM_BRUTE)
			_spawn_enemy(Vector2(470, 260), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_encarte_pickup(Vector2(550, 110), "casulo_retalhos", "Coletar Encarte: Casulo de Retalhos")
			_spawn_exit_portal(Vector2(675, 210), 7, "Entrar na Forja Rítmica (Fase 7)")

		7:
			# FASE 7: Segundo Chefe — O Robô Esquecido (Ritmo e sincronização)
			arena_rect = Rect2i(0, 0, 680, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 632, 372), "color": Color(0.12, 0.14, 0.18), "label": "FASE 7: FORJA RÍTMICA — CHEFE: O ROBÔ ESQUECIDO"})
			pablita.global_position = Vector2(95, 210)
			_spawn_return_portal(Vector2(45, 210), 6, "Recuar para a Antecâmara (Fase 6)")
			required_story_flags = ["f7_boss_defeated"]

			chopp_actor = _spawn_npc("Chopp", Vector2(140, 155), [
				"É O Robô Esquecido! Ele protege o elevador que leva à Galeria Real da Rainha!",
				"Espere o núcleo central dele vibrar em AZUL CIANO e dispare o ATAQUE SÔNICO [SOM]! Isso interrompe a ressonância e abre a carcaça para o seu SOCO FÍSICO!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Use SOM na janela azul de ressonância do Robô e ataque com SOCO quando exposto")

			var robot := BossRobot.new()
			robot.global_position = Vector2(400, 210)
			robot.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
				if hud:
					hud.show_boss_health(bname, cur, mx)
			)
			active_enemies_count += 1
			robot.boss_defeated.connect(func():
				active_enemies_count = 0
				if hud:
					hud.hide_boss_health()
					hud.set_objective_text("Siga para as Profundezas Desbotadas rumo ao palácio da Rainha (Fase 8)")
					hud.show_dialogue_sequence("Robô Esquecido (Desativando)", [
						"BZZT... Sincronização encerrada... Eu só queria manter a fábrica funcionando...",
						"Chopp: 'Ele deixou a passagem aberta! O CD da Pablita está na sala do trono da Rainha Empoeirada. Vamos!'"
					])
				if gm:
					gm.set_story_flag("f7_boss_defeated", true)
				_spawn_encarte_pickup(Vector2(360, 210), "amplificador_ruido", "Coletar Encarte: Amplificador de Ruído (+1 Capacidade)", 1)
				_refresh_portal_lock()
			)
			add_child(robot)
			if hud:
				hud.show_boss_health(robot.boss_title, robot.max_health, robot.max_health)
			_spawn_exit_portal(Vector2(615, 210), 8, "Avançar para as Profundezas Desbotadas (Fase 8)")

		8:
			# FASE 8: Região mais perigosa e desenvolvimento narrativo
			arena_rect = Rect2i(0, 0, 800, 460)
			_floor_zones.append({"rect": Rect2(24, 24, 752, 412), "color": Color(0.16, 0.08, 0.14), "label": "FASE 8: PROFUNDEZAS DESBOTADAS"})
			_add_wall_block(Rect2(270, 140, 24, 180))
			_add_wall_block(Rect2(510, 90, 24, 120))
			_add_wall_block(Rect2(510, 260, 24, 120))
			pablita.global_position = Vector2(90, 230)
			_spawn_return_portal(Vector2(45, 230), 7, "Voltar à Forja (Fase 7)")

			chopp_actor = _spawn_npc("Chopp", Vector2(135, 175), [
				"Cuidado, Pablita... Aqui ficam as lembranças quase apagadas. A Rainha Empoeirada trancou este setor para ninguém chegar ao vitral dela.",
				"Ative os dois Cristais Sônicos e derrote as Tecelãs Híbridas para abrirmos os portões reais!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Ative os 2 Cristais Sônicos e vença os guardas de elite das Profundezas")

			_spawn_lore_object(Vector2(220, 350), "Ler Inscrição Antiga", [
				"'A Rainha já foi a boneca mais amada de uma vitrine. Quando foi esquecida no sótão, jurou reunir todas as lembranças do mundo para nunca desaparecer.'"
			])

			_spawn_sonic_crystal(Vector2(220, 80), true)
			_spawn_sonic_crystal(Vector2(460, 380), true)
			_spawn_enemy(Vector2(370, 150), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_enemy(Vector2(390, 310), EnemyBase.Archetype.RHYTHM_BRUTE)
			_spawn_enemy(Vector2(620, 230), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_encarte_pickup(Vector2(620, 100), "passo_vento", "Coletar Encarte: Passo de Vento")
			_spawn_exit_portal(Vector2(735, 230), 9, "Subir ao Salão Antes do Trono (Fase 9)")

		9:
			# FASE 9: Preparação para o confronto final
			arena_rect = Rect2i(0, 0, 740, 420)
			_floor_zones.append({"rect": Rect2(24, 24, 692, 372), "color": Color(0.15, 0.11, 0.18), "label": "FASE 9: SALÃO ANTES DO TRONO"})
			pablita.global_position = Vector2(90, 210)
			_spawn_return_portal(Vector2(45, 210), 8, "Voltar às Profundezas (Fase 8)")
			required_story_flags = ["f9_chopp_ready"]

			chopp_actor = _spawn_npc("Chopp", Vector2(150, 155), [
				"Pablita, chegamos à porta da Rainha Empoeirada! O seu CD favorito está lá dentro, e também o portal direto de volta para o seu quarto e para o Luffy.",
				"Lembre-se de tudo que aprendemos: quebre a vitrine dela com o ROSNADO SÔNICO [SOM] e ataque nas brechas com a MANOPLA FÍSICA [SOCO].",
				"Pegue o Núcleo de Memória ali no altar para expandir sua capacidade ao máximo. Estou com você até o fim!"
			], Color(0.95, 0.78, 0.25), "f9_chopp_ready")
			chopp_actor.start_following(pablita)

			if hud:
				hud.set_objective_text("Fale com Chopp, colete a Expansão Final e derrote a guarda real")

			_spawn_encarte_pickup(Vector2(330, 125), "", "Coletar Núcleo de Memória (+2 Capacidade e Cura)", 2)
			_spawn_enemy(Vector2(460, 160), EnemyBase.Archetype.HYBRID_WEAVER)
			_spawn_enemy(Vector2(460, 270), EnemyBase.Archetype.SONIC_SHIELDED)
			_spawn_exit_portal(Vector2(675, 210), 10, "Entrar no Trono da Rainha Empoeirada (Fase 10)")

		10:
			# FASE 10: Chefe Final — A Rainha Empoeirada (3 fases) e Encerramento da Campanha (recuperando o CD e voltando para Luffy)
			arena_rect = Rect2i(0, 0, 700, 440)
			_floor_zones.append({"rect": Rect2(24, 24, 652, 392), "color": Color(0.18, 0.10, 0.20), "label": "FASE 10: O VITRAL EMPOEIRADO — CHEFE FINAL: A RAINHA EMPOEIRADA"})
			pablita.global_position = Vector2(95, 220)
			_spawn_return_portal(Vector2(45, 220), 9, "Recuar ao Salão (Fase 9)")

			chopp_actor = _spawn_npc("Chopp", Vector2(140, 160), [
				"A Rainha Empoeirada tem 3 fases: 1) Vitrine, 2) Boneca Desfeita e 3) O Que Restou Dela!",
				"Use SOM para quebrar a barreira ciano dela e SOCO durante a janela verde de vulnerabilidade!"
			])
			chopp_actor.start_following(pablita)
			if hud:
				hud.set_objective_text("Derrote A Rainha Empoeirada (3 Fases) para recuperar o CD e voltar ao quarto!")

			var queen := BossQueen.new()
			queen.global_position = Vector2(420, 220)
			queen.boss_health_changed.connect(func(bname: String, cur: int, mx: int):
				if hud:
					hud.show_boss_health(bname, cur, mx)
			)
			active_enemies_count += 1
			queen.boss_defeated.connect(func():
				active_enemies_count = 0
				if hud:
					hud.hide_boss_health()
					hud.set_objective_text("CD Recuperado! Campanha Concluída!")
				var gm2 := GameManagerService.get_gm()
				if gm2:
					gm2.set_story_flag("f10_queen_defeated", true)
					gm2.complete_campaign()
			)
			add_child(queen)
			if hud:
				hud.show_boss_health(queen.get_phase_title(), queen.max_health, queen.max_health)

func _draw() -> void:
	draw_rect(Rect2(arena_rect), Color(0.08, 0.06, 0.11, 1.0), true)

	for z: Dictionary in _floor_zones:
		var zr: Rect2 = z["rect"]
		var zc: Color = z["color"]
		draw_rect(zr, zc, true)
		draw_rect(zr, zc.lightened(0.25), false, 1.5)

	for x in range(arena_rect.position.x, arena_rect.end.x, 32):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(arena_rect.position.y, arena_rect.end.y, 32):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), Color(1, 1, 1, 0.04), 1.0)

	for wr: Rect2 in _wall_rects:
		draw_rect(wr, Color(0.28, 0.24, 0.36, 1.0), true)
		draw_rect(wr, Color(0.65, 0.58, 0.80, 1.0), false, 1.8)

	if _show_thief_visual:
		# Representação geométrica da meia ladra fugindo pela passagem com o CD
		draw_circle(_thief_visual_pos, 10.0, Color(0.85, 0.35, 0.75, 0.9))
		draw_circle(_thief_visual_pos + Vector2(8, -6), 5.0, Color(0.3, 0.95, 1.0, 1.0))
