extends SceneTree
## Suíte de Testes Automatizados para Melhorias Narrativas e de Fluxo:
## 1. Sistema de Foco Cinematográfico da Pablita e bloqueio de ações
## 2. Apresentação do Roubo do CD na Fase 1 e sinal dialogue_closed
## 3. Bloqueio de retorno nas arenas de chefe (Fases 3, 7 e 10)
## 4. Manutenção de portais livres em fases comuns (Fases 2, 4, 5, etc.)
## 5. Preservação do prompt específico ao desbloquear portal
## 6. HUD de depuração oculta por padrão

func _init() -> void:
	var gm_script: Script = load("res://autoload/game_manager.gd")
	var gm_node: Node = gm_script.new()
	gm_node.name = "GameManager"
	root.add_child(gm_node)
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("=== INICIANDO VALIDAÇÃO DE MELHORIAS NARRATIVAS E DE FLUXO ===")
	var gm := GameManagerService.get_gm()
	assert(gm != null, "GameManagerService deve estar presente")
	gm.reset_campaign()

	# -------------------------------------------------------------------------
	# 1. TESTE DO SISTEMA DE FOCO CINEMATOGRÁFICO EM PABLITA
	# -------------------------------------------------------------------------
	var pablita_packed: PackedScene = load("res://scenes/characters/pablita.tscn")
	var pablita := pablita_packed.instantiate() as Pablita
	root.add_child(pablita)
	await process_frame
	await process_frame

	assert(pablita.current_state == Pablita.State.IDLE, "1.1: Pablita deve iniciar em IDLE")
	assert(pablita._orig_camera_pos == pablita.camera.position, "1.2: Câmera deve memorizar posição original")
	assert(pablita._orig_camera_zoom == pablita.camera.zoom, "1.3: Câmera deve memorizar zoom original")

	# Testar bloqueio cinematográfico
	pablita.set_cinematic_locked(true)
	assert(pablita.current_state == Pablita.State.CINEMATIC_LOCKED, "1.4: Estado deve ser CINEMATIC_LOCKED")
	assert(pablita.velocity == Vector2.ZERO, "1.5: Velocidade deve ser zero no lock")

	# Simular tentativa de movimentação durante lock
	Input.action_press("move_right")
	pablita._physics_process(0.016)
	Input.action_release("move_right")
	assert(pablita.velocity == Vector2.ZERO, "1.6: Pablita não deve mover-se durante lock cinematográfico")

	# Simular tentativa de ataque durante lock
	Input.action_press("attack_physical")
	pablita._physics_process(0.016)
	Input.action_release("attack_physical")
	assert(pablita.current_state == Pablita.State.CINEMATIC_LOCKED, "1.7: Ataque físico deve ser ignorado durante lock")

	# Simular foco de câmera
	var target_pos := Vector2(300, 200)
	var tween_focus: Tween = pablita.focus_camera_on(target_pos, 0.05, 2.5)
	assert(pablita.camera.top_level == true, "1.8: Câmera deve estar em top_level durante foco")
	await tween_focus.finished

	# Retornar câmera ao jogador
	var tween_return: Tween = pablita.return_camera_to_player(0.05)
	await tween_return.finished
	assert(pablita.camera.top_level == false, "1.9: Câmera deve reconectar à Pablita (top_level=false)")
	assert(pablita.camera.position == pablita._orig_camera_pos, "1.10: Posição relativa da câmera deve restaurar")
	assert(pablita.camera.zoom == pablita._orig_camera_zoom, "1.11: Zoom da câmera deve restaurar")

	pablita.set_cinematic_locked(false)
	assert(pablita.current_state == Pablita.State.IDLE, "1.12: Controle deve ser restaurado")
	print("[PASSOU] Critério 1: Sistema reutilizável de foco cinematográfico e bloqueio de ações validado.")

	pablita.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 2. TESTE DA FASE 1: ROUBO DO CD, DIÁLOGO EM PARTES E RETORNO DE CÂMERA
	# -------------------------------------------------------------------------
	var lvl1_packed: PackedScene = load("res://scenes/levels/level_01_intro.tscn")

	# A primeira visita precisa começar no escuro, com Pablita deitada e o
	# Esquecido integralmente oculto.
	var opening_preview := lvl1_packed.instantiate() as CampaignLevel
	root.add_child(opening_preview)
	current_scene = opening_preview
	await process_frame
	await process_frame
	assert(opening_preview._bedroom_wakeup_completed == false, "2.0: A abertura deve iniciar antes do despertar")
	assert(opening_preview.pablita.current_state == Pablita.State.CINEMATIC_LOCKED, "2.0a: Pablita deve começar deitada e sem controle")
	assert(opening_preview._esquecido_occlusion != null and opening_preview._esquecido_occlusion.visible, "2.0b: O Esquecido deve começar coberto")
	assert(is_equal_approx(opening_preview._esquecido_occlusion.color.a, 1.0), "2.0c: A máscara do Esquecido deve começar totalmente opaca")
	assert((opening_preview.get_node("BedroomArtDark") as Sprite2D).visible, "2.0d: A arte escura do quarto deve estar visível")
	assert(is_equal_approx((opening_preview.get_node("BedroomArtLit") as Sprite2D).modulate.a, 0.0), "2.0e: A arte iluminada deve começar invisível")
	opening_preview.queue_free()
	await process_frame

	# O teste da cinemática do armário parte de um save em que Pablita já despertou.
	gm.set_story_flag("f1_bedroom_wakeup_done", true)
	var lvl1 := lvl1_packed.instantiate() as CampaignLevel
	root.add_child(lvl1)
	current_scene = lvl1
	await process_frame
	await process_frame

	var hud: HUD = lvl1.hud
	assert(hud != null, "2.1: HUD deve existir na Fase 1")
	assert(hud.debug_combat_label.visible == false, "2.2: Bloco [DEBUG COMBATE] deve estar oculto por padrão")

	# Testar toggle do debug combat com F3
	hud.toggle_debug_combat_visibility()
	assert(hud.debug_combat_label.visible == true, "2.3: Debug combat deve ser exibido ao alternar visibilidade")
	hud.toggle_debug_combat_visibility()
	assert(hud.debug_combat_label.visible == false, "2.4: Debug combat deve ocultar novamente")

	# Localizar o gatilho do Guarda-Roupa
	var wardrobe_trigger: WorldObject = null
	for child in lvl1.get_children():
		if child is WorldObject and (child as WorldObject).prompt_text.contains("Guarda-Roupa"):
			wardrobe_trigger = child as WorldObject
			break
	assert(wardrobe_trigger != null, "2.5: Gatilho do Guarda-Roupa deve estar na sala")

	# Interagir com Guarda-Roupa dispara a cena
	wardrobe_trigger._on_interacted(lvl1.pablita)
	assert(lvl1.pablita.current_state == Pablita.State.CINEMATIC_LOCKED, "2.6: Pablita deve ser bloqueada ao disparar cena")
	assert(lvl1._show_thief_visual == true, "2.7: Meia ladra deve aparecer com o CD")
	assert(hud._is_dialogue_open == true, "2.8: Caixa de diálogo deve abrir")

	# Avançar diálogo linha por linha até o fim
	var state_tracker: Dictionary = {"closed": false}
	hud.dialogue_closed.connect(func(): state_tracker["closed"] = true)

	while hud._is_dialogue_open:
		hud.advance_dialogue()
		await process_frame

	assert(state_tracker["closed"] == true, "2.9: Sinal dialogue_closed deve ser emitido ao encerrar diálogo")

	# Aguardar o tween de retorno da câmera finalizar
	if lvl1.pablita._active_camera_tween and lvl1.pablita._active_camera_tween.is_valid():
		await lvl1.pablita._active_camera_tween.finished
	await process_frame
	await create_timer(0.35).timeout # Aguarda a transição de revelação do Esquecido terminar.

	assert(lvl1.pablita.current_state == Pablita.State.IDLE, "2.10: Controle de Pablita deve ser devolvido após retorno da câmera")
	assert(lvl1._show_thief_visual == false, "2.11: Visual provisório da meia deve ser ocultado")
	assert(not lvl1._esquecido_occlusion.visible, "2.12: A máscara deve desaparecer depois de empurrar o armário")
	print("[PASSOU] Critério 2: Apresentação do roubo do CD, avanço de diálogo e retorno suave da câmera validados.")

	lvl1.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 3. TESTE DE BLOQUEIO DE RETORNO NAS ARENAS DE CHEFE (FASES 3, 7 E 10)
	# -------------------------------------------------------------------------
	# FASE 3: A Meia Esquecida
	var lvl3 := load(gm.LEVEL_PATHS[3]).instantiate() as CampaignLevel
	root.add_child(lvl3)
	current_scene = lvl3
	await process_frame
	await process_frame

	assert(lvl3.return_portal != null, "3.1: Fase 3 deve possuir portal de retorno")
	assert(lvl3.return_portal.is_locked == true, "3.2: Portal de retorno da Fase 3 deve iniciar BLOQUEADO")
	assert(lvl3.return_portal._interactable.prompt_message.contains("Trancada"), "3.3: Mensagem do portal deve indicar trancado")

	# Derrotar o chefe da Fase 3
	var sock_boss := get_nodes_in_group("bosses")[0] as BossSock
	sock_boss.health_component.take_damage(sock_boss.max_health)
	await process_frame
	await process_frame

	assert(lvl3.return_portal.is_locked == false, "3.4: Portal de retorno da Fase 3 deve DESBLOQUEAR após derrotar chefe")
	assert(lvl3.return_portal._interactable.prompt_message == "Retornar à Trilha (Fase 2)", "3.5: Texto específico de retorno deve ser restaurado")
	print("[PASSOU] Critério 3.A: Fase 3 (Meia) bloqueia retorno durante batalha e libera com texto correto após vitória.")

	lvl3.queue_free()
	await process_frame

	# FASE 7: O Robô Esquecido
	var lvl7 := load(gm.LEVEL_PATHS[7]).instantiate() as CampaignLevel
	root.add_child(lvl7)
	current_scene = lvl7
	await process_frame
	await process_frame

	assert(lvl7.return_portal.is_locked == true, "3.6: Portal de retorno da Fase 7 deve iniciar BLOQUEADO")
	var robot_boss := get_nodes_in_group("bosses")[0] as BossRobot
	robot_boss.health_component.take_damage(robot_boss.max_health)
	await process_frame
	await process_frame

	assert(lvl7.return_portal.is_locked == false, "3.7: Portal de retorno da Fase 7 deve DESBLOQUEAR após derrotar robô")
	assert(lvl7.return_portal._interactable.prompt_message == "Recuar para a Antecâmara (Fase 6)", "3.8: Texto específico de retorno deve ser restaurado na Fase 7")
	print("[PASSOU] Critério 3.B: Fase 7 (Robô) bloqueia retorno durante batalha e libera com texto correto após vitória.")

	lvl7.queue_free()
	await process_frame

	# FASE 10: A Rainha Empoeirada
	var lvl10 := load(gm.LEVEL_PATHS[10]).instantiate() as CampaignLevel
	root.add_child(lvl10)
	current_scene = lvl10
	await process_frame
	await process_frame

	assert(lvl10.return_portal.is_locked == true, "3.9: Portal de retorno da Fase 10 deve iniciar BLOQUEADO")
	var queen_boss := get_nodes_in_group("bosses")[0] as BossQueen
	queen_boss.health_component.take_damage(queen_boss.max_health)
	await process_frame
	await process_frame

	assert(lvl10.return_portal.is_locked == false, "3.10: Portal de retorno da Fase 10 deve DESBLOQUEAR após derrotar Rainha")
	assert(lvl10.return_portal._interactable.prompt_message == "Recuar ao Salão (Fase 9)", "3.11: Texto específico de retorno deve ser restaurado na Fase 10")
	print("[PASSOU] Critério 3.C: Fase 10 (Rainha) bloqueia retorno durante batalha e libera com texto correto após vitória.")

	lvl10.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 4. TESTE DE FASES COMUNS (GARANTIR QUE NÃO FORAM BLOQUEADAS POR ENGANO)
	# -------------------------------------------------------------------------
	for common_idx in [2, 4, 5, 6, 8, 9]:
		var common_lvl := load(gm.LEVEL_PATHS[common_idx]).instantiate() as CampaignLevel
		root.add_child(common_lvl)
		current_scene = common_lvl
		await process_frame
		await process_frame
		assert(common_lvl.return_portal != null, "4.1: Fase comum %d deve ter portal de retorno" % common_idx)
		assert(common_lvl.return_portal.is_locked == false, "4.2: Portal de retorno da fase comum %d NUNCA deve ser bloqueado" % common_idx)
		common_lvl.queue_free()
		await process_frame

	print("[PASSOU] Critério 4: Fases comuns (2, 4, 5, 6, 8, 9) mantêm portais de retorno livres.")

	# =========================================================================
	# 5. CRITÉRIOS P0-P3: PIPOP BLOQUEADO NA ABERTURA, FASE 4 PACÍFICA,
	#    ANTI-EXPLOIT DE CAPACIDADE NA FASE 9, WEB SLOW ZONE OVERLAP E ÁUDIO
	# =========================================================================
	gm.reset_campaign()
	assert(not gm.is_pipop_acquired(), "5.1: No início da campanha (Fase 1), Pipop ainda não foi adquirido")

	# Fase 4 pacífica (Vila dos Achados sem inimigos hostis)
	var lvl4 := load(gm.LEVEL_PATHS[4]).instantiate() as CampaignLevel
	root.add_child(lvl4)
	current_scene = lvl4
	await process_frame
	await process_frame
	assert(lvl4.active_enemies_count == 0, "5.2: Fase 4 (Vila dos Achados) deve ser 100% pacífica (0 inimigos)")
	assert(lvl4.exit_portal != null and lvl4.exit_portal.is_locked, "5.3: Portal de saída da Vila dos Achados aguarda conversa com morador")
	gm.set_story_flag("f4_talked_villager", true)
	assert(not lvl4.exit_portal.is_locked, "5.3b: Após conversar com um morador da Vila, o portal de saída fica livre")

	# Teste de sobreposição de WebSlowZone (PROB-15)
	var z1 := WebSlowZone.new()
	z1.slow_factor = 0.42
	var z2 := WebSlowZone.new()
	z2.slow_factor = 0.50
	lvl4.add_child(z1)
	lvl4.add_child(z2)
	z1._on_body_entered(lvl4.pablita)
	z2._on_body_entered(lvl4.pablita)
	assert(is_equal_approx(lvl4.pablita.speed_modifier_zone, 0.42), "5.4: Com duas teias sobrepostas, aplica o fator mais lento (0.42)")
	z1._on_body_exited(lvl4.pablita)
	assert(is_equal_approx(lvl4.pablita.speed_modifier_zone, 0.50), "5.5: Ao sair de uma teia mas continuar na segunda, mantém lentidão da segunda (0.50)")
	z2._on_body_exited(lvl4.pablita)
	assert(is_equal_approx(lvl4.pablita.speed_modifier_zone, 1.0), "5.6: Ao sair de todas as teias, velocidade volta a 1.0")
	lvl4.queue_free()
	await process_frame

	# Fase 9: Anti-exploit de Capacidade (f9_altar_core_taken)
	var cap_before_f9: int = gm.max_capacity
	var lvl9 := load(gm.LEVEL_PATHS[9]).instantiate() as CampaignLevel
	root.add_child(lvl9)
	current_scene = lvl9
	await process_frame
	await process_frame
	var altar_pickup: ForgottenCDItem = null
	for child in lvl9.get_children():
		if child is ForgottenCDItem and (child as ForgottenCDItem).unique_world_flag == "f9_altar_core_taken":
			altar_pickup = child as ForgottenCDItem
			break
	assert(altar_pickup != null, "5.7: Fase 9 deve conter o Núcleo de Memória na primeira visita")
	altar_pickup._on_interacted(lvl9.pablita)
	assert(gm.max_capacity == cap_before_f9 + 2, "5.8: Coletar Núcleo na Fase 9 aumenta capacidade em +2")
	assert(gm.has_story_flag("f9_altar_core_taken"), "5.9: Flag f9_altar_core_taken deve ser gravada")
	lvl9.queue_free()
	await process_frame

	# Revisitando Fase 9: Núcleo não pode reaparecer nem conceder mais capacidade
	var lvl9_revisit := load(gm.LEVEL_PATHS[9]).instantiate() as CampaignLevel
	root.add_child(lvl9_revisit)
	current_scene = lvl9_revisit
	await process_frame
	await process_frame
	for child in lvl9_revisit.get_children():
		if child is ForgottenCDItem and (child as ForgottenCDItem).unique_world_flag == "f9_altar_core_taken":
			assert((child as ForgottenCDItem).is_collected, "5.10: Na revisita à Fase 9, o Núcleo já deve estar marcado como coletado")
	lvl9_revisit.queue_free()
	await process_frame

	# AudioManager presente e operacional
	var am := AudioManagerService.get_am()
	assert(am != null, "5.11: AudioManagerService deve estar registrado e ativo")
	print("[PASSOU] Critério 5: Bloqueio inicial de Pipop, Vila dos Achados pacífica, Anti-exploit Fase 9, WebSlowZone overlap e AudioManager validados!")

	print("=== TODOS OS TESTES DE MELHORIAS NARRATIVAS E DE FLUXO PASSARAM COM SUCESSO! ===")
	quit(0)
