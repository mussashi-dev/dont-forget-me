extends SceneTree
## QA Validation Suite for GDD 0.3 / Heartbound Mechanics (Tarefas 1-5)

var _failures: Array[String] = []
var _player_defeated_emitted: bool = false
var _crystal_solved_count: int = 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("[FAIL] " + msg)
	else:
		print("[PASS] " + msg)

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	print("=== INICIANDO VALIDACAO HEADLESS HEARTBOUND / GDD 0.3 ===")
	await process_frame

	await _test_tarefa1_sprites_ysort_and_hud()
	await _test_tarefa2_minigame_combat()
	await _test_tarefa3_resonance_crystal_fase2()
	await _test_tarefa4_reactive_narrative_and_boss_non_death()

	if not _failures.is_empty():
		printerr("=== FALHAS DETECTADAS (%d): ===" % _failures.size())
		for f: String in _failures:
			printerr(" - " + f)
		quit(1)
		return

	print("=== TODAS AS VALIDACOES HEARTBOUND / GDD 0.3 PASSARAM (100%) ===")
	quit(0)

func _test_tarefa1_sprites_ysort_and_hud() -> void:
	print("--- Tarefa 1: Nearest, Y-Sort, Offset, HUD PC vs Mobile ---")
	var default_filter: int = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1))
	_check(default_filter == 0, "ProjectSettings default_texture_filter = Nearest (0)")

	var fase2_scene: PackedScene = load("res://scenes/levels/Fase2.tscn")
	var fase2: Node2D = fase2_scene.instantiate() as Node2D
	root.add_child(fase2)
	await process_frame

	_check(fase2.y_sort_enabled, "Fase2 raiz tem y_sort_enabled = true")
	var corda: MobBrinquedoCorda = fase2.get_node("Mobs/BrinquedoDeCorda") as MobBrinquedoCorda
	var corda_spr: Sprite2D = corda.get_node("Sprite2D") as Sprite2D
	_check(corda.y_sort_enabled and corda_spr.offset.y == -16.0, "BrinquedoDeCorda y_sort_enabled = true e offset.y = -16")
	_check(corda_spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BrinquedoDeCorda Sprite2D usa Nearest filter")

	var sock_scene: PackedScene = load("res://scenes/enemies/sock_enemy.tscn")
	var sock_inst: Node2D = sock_scene.instantiate() as Node2D
	root.add_child(sock_inst)
	await process_frame
	var sock_spr: Sprite2D = sock_inst.get_node("Sprite2D") as Sprite2D
	_check(sock_inst.y_sort_enabled and sock_spr.offset.y == -16.0 and sock_spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "SockEnemy tem y_sort_enabled, offset.y = -16 e Nearest filter")
	sock_inst.queue_free()

	# HUD PC vs Mobile check
	var hud: HUD = fase2.get_node("HUD") as HUD
	var gm := GameManagerService.get_gm()
	if gm != null:
		gm.is_mobile_device = false
		hud._refresh_pipop_and_device_ui()
		_check(hud.touch_controls_node.visible == false, "PC oculta botoes touch")
		_check(hud.virtual_joystick_node.visible == false, "PC oculta joystick virtual")

		gm.is_mobile_device = true
		hud._refresh_pipop_and_device_ui()
		_check(hud.touch_controls_node.visible == true, "Mobile exibe botoes touch")
		for btn_name: String in ["PhysicalAttackBtn", "SonicAttackBtn", "DashBtn", "InteractButton"]:
			var btn: Control = hud.touch_controls_node.get_node(btn_name) as Control
			_check(btn.custom_minimum_size == Vector2(80, 80), "Mobile %s tem custom_minimum_size 80x80" % btn_name)
			_check(is_equal_approx(btn.anchor_left, 1.0) and is_equal_approx(btn.anchor_top, 1.0), "Mobile %s ancorado no canto inferior direito" % btn_name)
		gm.is_mobile_device = false

	fase2.queue_free()
	await process_frame

func _test_tarefa2_minigame_combat() -> void:
	print("--- Tarefa 2: MinigameCombat (Brinquedo de Corda & Flor de Poeira) ---")
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	var p_scene: PackedScene = load("res://scenes/characters/pablita.tscn")
	var pablita: Pablita = p_scene.instantiate() as Pablita
	pablita.position = Vector2(100, 150)
	container.add_child(pablita)

	# 2A. Brinquedo de Corda (Timing Bar: Crit vs Normal)
	var corda_scene: PackedScene = load("res://scenes/enemies/mob_brinquedo_corda.tscn")
	var corda: MobBrinquedoCorda = corda_scene.instantiate() as MobBrinquedoCorda
	corda.position = Vector2(220, 150)
	container.add_child(corda)
	await process_frame

	var initial_hp: int = corda.health_component.current_health
	corda.hurtbox.receive_hit(10, Hitbox.DamageType.PHYSICAL, Vector2.RIGHT, 0.2)
	await process_frame
	_check(corda.active_minigame != null and corda.active_minigame.is_inside_tree(), "BrinquedoDeCorda instancia MinigameCombat ao receber golpe")

	# Miss -> dano normal (10)
	var mg_miss: MinigameCombat = corda.active_minigame
	mg_miss.set_marker_position(0.05)
	mg_miss.trigger_player_input()
	await process_frame
	_check(corda.health_component.current_health == initial_hp - 10, "BrinquedoDeCorda erro na barra aplica dano normal (-10)")

	# Wait hurtbox i-frames then trigger Crit -> dano critico (20)
	corda.hurtbox.is_invulnerable = false
	var hp_before_crit: int = corda.health_component.current_health
	corda.hurtbox.receive_hit(10, Hitbox.DamageType.PHYSICAL, Vector2.RIGHT, 0.2)
	await process_frame
	var mg_crit: MinigameCombat = corda.active_minigame
	_check(mg_crit != null, "BrinquedoDeCorda instancia novo QTE para segundo golpe")
	mg_crit.set_marker_position(0.5) # dentro da zona verde (0.36..0.64)
	mg_crit.trigger_player_input()
	await process_frame
	_check(corda.health_component.current_health == hp_before_crit - 20, "BrinquedoDeCorda acerto na zona verde aplica dano critico (2x = -20)")

	# 2B. Flor de Poeira + EsporoProjectile (QTE de reflexo sonico)
	var flor_scene: PackedScene = load("res://scenes/enemies/mob_flor_poeira.tscn")
	var flor: MobFlorPoeira = flor_scene.instantiate() as MobFlorPoeira
	flor.position = Vector2(360, 150)
	container.add_child(flor)
	await process_frame

	var flor_hp_before: int = flor.health_component.current_health
	var spore: EsporoProjectile = flor.fire_spore_at_player() as EsporoProjectile
	_check(spore != null and spore.source_enemy == flor, "FlorDePoeira referencia a si mesma no EsporoProjectile")

	# Aproximar esporo da Pablita para disparar o QTE de reflexo
	spore.global_position = pablita.global_position + Vector2(60, 0)
	spore._physics_process(0.016)
	await process_frame
	_check(spore.active_minigame != null and spore.active_minigame.minigame_type == MinigameCombat.MinigameType.SONIC_REFLEX, "Esporo instancia QTE SONIC_REFLEX ao se aproximar de Pablita")

	# Executar som do Pipop no momento do reflexo
	spore.active_minigame.set_marker_position(0.5)
	spore.active_minigame.trigger_player_input()
	await process_frame
	_check(spore.is_reflected == true, "Esporo marcado como is_reflected apos uso do Som no QTE")
	_check(spore.direction.x > 0.0, "Esporo rebatido aponta de volta para a Flor de Poeira (direction.x > 0)")

	# Simular impacto de volta na Flor de Poeira
	spore._on_area_entered(flor.get_node("Hurtbox") as Hurtbox)
	await process_frame
	_check(not is_instance_valid(flor) or flor.health_component.current_health < flor_hp_before, "Esporo rebatido causa dano na Flor de Poeira")

	container.queue_free()
	await process_frame

func _test_tarefa3_resonance_crystal_fase2() -> void:
	print("--- Tarefa 3: ResonanceCrystal e Puzzle da Fase 2 ---")
	_crystal_solved_count = 0
	var fase2_scene: PackedScene = load("res://scenes/levels/Fase2.tscn")
	var fase2: Fase2Level = fase2_scene.instantiate() as Fase2Level
	root.add_child(fase2)
	current_scene = fase2
	await process_frame
	await process_frame

	var crystal: ResonanceCrystal = fase2.resonance_crystal
	var door: StaticBody2D = fase2.blocked_door
	var door_cs: CollisionShape2D = door.get_node("CollisionShape2D") as CollisionShape2D
	var relic: CanvasItem = fase2.secret_relic

	_check(crystal != null and not crystal.is_solved, "ResonanceCrystal existe na Fase 2 e inicia nao resolvido")
	_check(not door_cs.disabled and door.visible, "Porta bloqueada (StaticBody2D) inicia fechada")
	_check(not relic.visible, "Objeto secreto inicia invisivel")

	crystal.puzzle_solved.connect(func(_c: ResonanceCrystal): _crystal_solved_count += 1)

	# Posicionar Pablita dentro da area do cristal e usar SonicAttack do Pipop
	fase2.pablita.global_position = crystal.global_position
	for f: int in 4:
		await physics_frame
	fase2.pablita.pipop.can_sonic = true
	var fired: bool = fase2.pablita.pipop.perform_sonic_attack(Vector2.RIGHT, fase2.pablita.global_position)
	_check(fired, "Pipop dispara SonicAttack dentro da area do ResonanceCrystal")
	await process_frame

	_check(_crystal_solved_count == 1 and crystal.is_solved, "ResonanceCrystal emite sinal puzzle_solved ao receber SonicAttack")
	_check(door_cs.disabled and not door.visible, "Porta bloqueada (StaticBody2D) abre apos puzzle_solved")
	_check(relic.visible, "Objeto secreto se torna visivel apos puzzle_solved")

	fase2.queue_free()
	await process_frame

func _test_tarefa4_reactive_narrative_and_boss_non_death() -> void:
	print("--- Tarefa 4: Narrativa Reativa & Morte Nao-Punitiva em Chefe ---")
	var gm := GameManagerService.get_gm()
	if gm != null:
		gm.world_flags.clear()
		gm.set_story_flag("pipop_acquired", true)
	CampaignLevel.GameState.flags.clear()

	# Sem interagir com o urso -> dialogo padrao da Fase 2
	var lvl2_scene: PackedScene = load("res://scenes/levels/level_02.tscn")
	var lvl2_default: CampaignLevel = lvl2_scene.instantiate() as CampaignLevel
	root.add_child(lvl2_default)
	current_scene = lvl2_default
	await process_frame
	var lines_without_bear: Array[String] = lvl2_default.chopp_actor.dialogue_lines.duplicate()
	lvl2_default.queue_free()
	await process_frame

	# Interagir com o ursinho na Fase 1
	var lvl1_scene: PackedScene = load("res://scenes/levels/level_01_intro.tscn")
	var lvl1: CampaignLevel = lvl1_scene.instantiate() as CampaignLevel
	root.add_child(lvl1)
	current_scene = lvl1
	await process_frame
	var teddy_inter: Interactable = lvl1.get_node_or_null("UrsinhoEsquecido/Interactable") as Interactable
	_check(teddy_inter != null, "UrsinhoEsquecido interativo existe na Fase 1")
	teddy_inter.interact(lvl1.pablita)
	if lvl1.hud._is_dialogue_open:
		lvl1.hud.hide_dialogue()
	_check(bool(CampaignLevel.GameState.flags.get("interagiu_com_ursinho", false)), "Flag GameState.flags['interagiu_com_ursinho'] ativada ao interagir com ursinho")
	lvl1.queue_free()
	await process_frame

	# Carregar Fase 2 novamente e verificar fala reativa de Chopp
	var lvl2_reactive: CampaignLevel = lvl2_scene.instantiate() as CampaignLevel
	root.add_child(lvl2_reactive)
	current_scene = lvl2_reactive
	await process_frame
	var lines_with_bear: Array[String] = lvl2_reactive.chopp_actor.dialogue_lines.duplicate()
	_check(lines_with_bear != lines_without_bear and lines_with_bear[0].to_lower().contains("ursinho"), "Chopp muda dialogo na Fase 2 quando interagiu_com_ursinho = true")
	lvl2_reactive.queue_free()
	await process_frame

	# Testar Morte Nao-Punitiva na Arena de Chefe (Fase 3: BossSock)
	_player_defeated_emitted = false
	var lvl3_scene: PackedScene = load("res://scenes/levels/level_03_boss_sock.tscn")
	var lvl3: CampaignLevel = lvl3_scene.instantiate() as CampaignLevel
	root.add_child(lvl3)
	current_scene = lvl3
	await process_frame
	await process_frame

	if lvl3.hud._is_dialogue_open:
		lvl3.hud.hide_dialogue()
	lvl3.player_defeated.connect(func(): _player_defeated_emitted = true)

	var boss: BossSock = lvl3.active_boss as BossSock
	_check(boss != null, "Arena de Chefe Fase 3 registra active_boss")
	_check(lvl3.hud.suppress_game_over == true, "Arena de Chefe remove tela de Game Over (suppress_game_over = true)")

	# Danificar chefe e mover antes da derrota da Pablita
	boss.health_component.take_damage(80)
	boss.global_position = Vector2(200, 300)
	var boss_hp_damaged: int = boss.health_component.current_health
	_check(boss_hp_damaged < boss.max_health, "Chefe sofreu dano antes da derrota da Pablita")

	# Zerar vida da Pablita
	lvl3.pablita.health_component.take_damage(9999)
	_check(_player_defeated_emitted, "Sinal player_defeated emitido quando vida da Pablita chega a 0")
	_check(lvl3.hud.state_overlay_panel.visible == false, "Nenhum Game Over overlay aparece na arena de chefe")

	# Aguardar fade out -> recuperacao -> reset -> fade in -> fala do Chopp
	await lvl3.boss_arena_reset_completed

	var expected_half_hp: int = maxi(1, int(ceil(float(lvl3.pablita.health_component.max_health) * 0.5)))
	_check(lvl3.pablita.health_component.current_health == expected_half_hp, "Pablita recupera metade da vida apos derrota (%d/%d)" % [lvl3.pablita.health_component.current_health, lvl3.pablita.health_component.max_health])
	_check(lvl3.pablita.current_state != Pablita.State.DEAD, "Pablita sai do estado DEAD e continua jogavel")
	_check(boss.health_component.current_health == boss.max_health and boss.current_state == BossSock.State.IDLE, "Chefe reseta para estado inicial (vida maxima e State.IDLE)")
	_check(lvl3.hud.dialogue_box.visible and lvl3.hud.speaker_label.text == "Chopp", "Chopp exibe fala curta encorajando Pablita apos reset")

	lvl3.queue_free()
	await process_frame
