extends SceneTree
## Suíte de testes funcionais e de regressão cobrindo:
## - Teste A: Ataque físico exclusivo (sem disparar onda sônica)
## - Teste B: Ataque sônico exclusivo (sem ativar hitbox física; avanço de Pipop, onda, impacto e retorno)
## - Teste C: Alternância repetida Físico -> Sônico -> Físico -> Sônico
## - Teste D: Controles mobile (botões touch SOCO e SOM com verificação de não-interferência com mouse/toque)
## - Teste E: Narrativa completa (Quarto, Luffy, Guarda-Roupa, roubo do CD pela meia, chegada ao Esquecido,
##   encontro e acompanhamento de Chopp, ordem causal de progressão, 3 chefes nas fases 3, 7 e 10 e encerramento).

func _init() -> void:
	var gm_script: Script = load("res://autoload/game_manager.gd")
	var gm_node: Node = gm_script.new()
	gm_node.name = "GameManager"
	root.add_child(gm_node)
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("=== INICIANDO AUDITORIA E TESTES OBRIGATÓRIOS (A, B, C, D, E) ===")
	var gm: GameManagerService = GameManagerService.get_gm()
	assert(gm != null, "GameManagerService deve estar ativo")
	gm.reset_campaign()

	# Carregar Fase 1 para os Testes A, B, C, D e início do E
	var lvl1_packed: PackedScene = load("res://scenes/levels/level_01_intro.tscn")
	var lvl1 := lvl1_packed.instantiate() as CampaignLevel
	root.add_child(lvl1)
	current_scene = lvl1
	await process_frame
	await process_frame

	var pablita: Pablita = lvl1.pablita
	var pipop_comp: PipopComponent = pablita.pipop
	var pipop_body: PipopCompanion = pablita.pipop_companion
	var hud: HUD = lvl1.hud
	assert(pablita != null and pipop_comp != null and pipop_body != null and hud != null, "Entidades centrais devem existir")

	# Verificar que InputMap não possui mais MouseButton global em attack_physical
	for ev: InputEvent in InputMap.action_get_events("attack_physical"):
		assert(not (ev is InputEventMouseButton), "attack_physical NAO deve conter InputEventMouseButton global!")

	# Posicionar um inimigo de teste próximo a Pablita para validar acerto físico e sônico
	var dummy_enemy := lvl1._spawn_enemy(pablita.global_position + Vector2(20, 0), EnemyBase.Archetype.MELEE_RUSHER)
	dummy_enemy.set_physics_process(false) # Mantém parado para medição exata de hitbox
	pablita.facing_direction = Vector2.RIGHT
	await process_frame

	# =========================================================================
	# TESTE A — ATAQUE FÍSICO EXCLUSIVO
	# =========================================================================
	var hp_before_phys: int = dummy_enemy.health_component.current_health
	Input.action_press("attack_physical")
	pablita._physics_process(0.016)
	Input.action_release("attack_physical")

	assert(pablita.current_state == Pablita.State.ATTACK_PHYSICAL, "Teste A: Pablita deve estar em ATTACK_PHYSICAL")
	assert(pipop_body.current_state == PipopCompanion.State.PHYSICAL, "Teste A: Pipop deve assumir estado PHYSICAL (manopla)")
	assert(pipop_comp.is_hitbox_active == true, "Teste A: Hitbox física deve estar ativa")
	assert(pipop_comp.active_sonic_waves_count == 0, "Teste A: Nenhuma onda sônica pode ser disparada no ataque físico")
	assert(pipop_comp.last_command_received == "attack_physical", "Teste A: Debug deve registrar comando attack_physical")

	await physics_frame
	await physics_frame
	await process_frame
	assert(dummy_enemy.health_component.current_health < hp_before_phys, "Teste A: Inimigo próximo deve receber dano físico")

	# Avançar até o fim da janela e recarga física
	for i in range(15):
		pablita._physics_process(0.03)
		pipop_comp._physics_process(0.03)
		pipop_body._physics_process(0.03)
	assert(pipop_comp.is_hitbox_active == false, "Teste A: Hitbox física deve desativar após a janela")
	assert(pipop_body.current_state == PipopCompanion.State.FOLLOW, "Teste A: Pipop deve retornar ao estado FOLLOW")
	print("[PASSOU] TESTE A — Ataque Físico exclusivo, hitbox física, dano curto e ausência de ataque sônico.")

	# =========================================================================
	# TESTE B — ATAQUE SÔNICO EXCLUSIVO
	# =========================================================================
	# Posicionar inimigo com escudo sônico a média distância (fora do alcance do soco de 16px, dentro do sônico)
	var sonic_dummy := lvl1._spawn_enemy(pablita.global_position + Vector2(65, -8), EnemyBase.Archetype.SONIC_SHIELDED)
	sonic_dummy.set_physics_process(false)
	assert(sonic_dummy.has_sonic_shield == true, "Teste B: Inimigo de teste deve iniciar com escudo sônico")
	pablita.facing_direction = Vector2.RIGHT

	Input.action_press("attack_sonic")
	pablita._physics_process(0.016)
	Input.action_release("attack_sonic")

	assert(pablita.current_state == Pablita.State.ATTACK_SONIC, "Teste B: Pablita deve entrar exclusivamente em ATTACK_SONIC")
	assert(pipop_body.current_state == PipopCompanion.State.SONIC_APPROACH, "Teste B: Pipop deve iniciar em SONIC_APPROACH")
	assert(pipop_comp.is_hitbox_active == false, "Teste B: Hitbox física NUNCA deve ativar durante ataque sônico")
	assert(pipop_comp.physical_hitbox.monitoring == false, "Teste B: PhysicalHitbox.monitoring deve permanecer false")
	assert(pipop_comp.last_command_received == "attack_sonic", "Teste B: Debug deve registrar comando attack_sonic")
	assert(pipop_comp.last_ability_executed == "ROSNADO SÔNICO", "Teste B: Debug deve registrar habilidade ROSNADO SÔNICO")

	# Avançar Pipop até a frente de Pablita (SONIC_APPROACH -> SONIC_ATTACK)
	pipop_body._physics_process(0.07)
	assert(pipop_body.current_state == PipopCompanion.State.SONIC_ATTACK, "Teste B: Pipop deve posicionar-se à frente em SONIC_ATTACK")
	assert(pipop_comp.active_sonic_waves_count == 1, "Teste B: Onda sônica deve ser instanciada e ativa")
	assert(pipop_comp.is_hitbox_active == false, "Teste B: Hitbox física continua inativa durante SONIC_ATTACK")

	# Avançar física para a onda sônica viajar e atingir o alvo distante
	for i in range(10):
		await physics_frame
		pablita._physics_process(0.03)
		pipop_comp._physics_process(0.03)
		pipop_body._physics_process(0.03)
	await process_frame

	assert(sonic_dummy.has_sonic_shield == false, "Teste B: Onda sônica deve atingir alvo distante e quebrar seu escudo sônico")
	assert(pipop_body.current_state == PipopCompanion.State.FOLLOW, "Teste B: Pipop deve retornar a FOLLOW após SONIC_RETURN")
	print("[PASSOU] TESTE B — Ataque Sônico exclusivo, avanço de Pipop, onda sônica, impacto distante e hitbox física inativa.")

	# =========================================================================
	# TESTE C — ALTERNÂNCIA REPETIDA (FÍSICO -> SÔNICO -> FÍSICO -> SÔNICO)
	# =========================================================================
	var sequence: Array[String] = ["attack_physical", "attack_sonic", "attack_physical", "attack_sonic"]
	for step_idx in range(sequence.size()):
		var act: String = sequence[step_idx]
		# Garantir cooldowns prontos para teste de alternância imediata
		pipop_comp.can_physical = true
		pipop_comp.can_sonic = true
		pablita.current_state = Pablita.State.IDLE

		Input.action_press(act)
		pablita._physics_process(0.016)
		Input.action_release(act)

		if act == "attack_physical":
			assert(pablita.current_state == Pablita.State.ATTACK_PHYSICAL, "Teste C (passo %d): Deve executar ATTACK_PHYSICAL" % step_idx)
			assert(pipop_body.current_state == PipopCompanion.State.PHYSICAL, "Teste C (passo %d): Pipop deve estar em PHYSICAL" % step_idx)
			assert(pipop_comp.is_hitbox_active == true, "Teste C (passo %d): Hitbox física ativa" % step_idx)
		else:
			assert(pablita.current_state == Pablita.State.ATTACK_SONIC, "Teste C (passo %d): Deve executar ATTACK_SONIC" % step_idx)
			assert(pipop_body.current_state == PipopCompanion.State.SONIC_APPROACH, "Teste C (passo %d): Pipop deve estar em SONIC_APPROACH" % step_idx)
			assert(pipop_comp.is_hitbox_active == false, "Teste C (passo %d): Hitbox física inativa no ataque sônico" % step_idx)

		# Completar ciclo até retorno a FOLLOW
		await process_frame
		for f in range(16):
			pablita._physics_process(0.03)
			pipop_comp._physics_process(0.03)
			pipop_body._physics_process(0.03)
		assert(pipop_body.current_state == PipopCompanion.State.FOLLOW, "Teste C (passo %d): Pipop deve retornar a FOLLOW sem travar" % step_idx)

	print("[PASSOU] TESTE C — Alternância Físico -> Sônico -> Físico -> Sônico executada sem interferência de estados.")

	# =========================================================================
	# TESTE D — CONTROLES MOBILE (BOTÕES TOUCH FÍSICO E SÔNICO)
	# =========================================================================
	var phys_btn: TouchActionButton = hud.get_node("RootControl/TouchControls/PhysicalAttackBtn") as TouchActionButton
	var sonic_btn: TouchActionButton = hud.get_node("RootControl/TouchControls/SonicAttackBtn") as TouchActionButton
	assert(phys_btn.action_name == "attack_physical", "Teste D: Botão físico deve mapear para attack_physical")
	assert(sonic_btn.action_name == "attack_sonic", "Teste D: Botão sônico deve mapear para attack_sonic")

	# Simular toque mobile no botão SOM (SonicAttackBtn)
	pipop_comp.can_physical = true
	pipop_comp.can_sonic = true
	pablita.current_state = Pablita.State.IDLE

	var touch_sonic := InputEventScreenTouch.new()
	touch_sonic.index = 2
	touch_sonic.pressed = true
	sonic_btn._gui_input(touch_sonic)
	assert(Input.is_action_pressed("attack_sonic") == true, "Teste D: Toque em SonicAttackBtn deve pressionar attack_sonic")
	assert(Input.is_action_pressed("attack_physical") == false, "Teste D: Toque em SonicAttackBtn JAMAIS deve pressionar attack_physical")

	pablita._physics_process(0.016)
	assert(pablita.current_state == Pablita.State.ATTACK_SONIC, "Teste D: Toque no botão SOM deve acionar exclusivamente ATTACK_SONIC")
	assert(pipop_comp.is_hitbox_active == false, "Teste D: Hitbox física inativa ao tocar no botão SOM")

	touch_sonic.pressed = false
	sonic_btn._gui_input(touch_sonic)
	await process_frame
	for f in range(16):
		pablita._physics_process(0.03)
		pipop_comp._physics_process(0.03)
		pipop_body._physics_process(0.03)

	# Simular toque mobile no botão SOCO (PhysicalAttackBtn)
	pipop_comp.can_physical = true
	pablita.current_state = Pablita.State.IDLE
	var touch_phys := InputEventScreenTouch.new()
	touch_phys.index = 3
	touch_phys.pressed = true
	phys_btn._gui_input(touch_phys)
	assert(Input.is_action_pressed("attack_physical") == true, "Teste D: Toque em PhysicalAttackBtn deve pressionar attack_physical")
	assert(Input.is_action_pressed("attack_sonic") == false, "Teste D: Toque em PhysicalAttackBtn não deve pressionar attack_sonic")

	pablita._physics_process(0.016)
	assert(pablita.current_state == Pablita.State.ATTACK_PHYSICAL, "Teste D: Toque no botão SOCO deve acionar ATTACK_PHYSICAL")
	touch_phys.pressed = false
	phys_btn._gui_input(touch_phys)
	await process_frame
	for f in range(16):
		pablita._physics_process(0.03)
		pipop_comp._physics_process(0.03)
		pipop_body._physics_process(0.03)

	# Limpar inimigos de teste da Fase 1
	if is_instance_valid(dummy_enemy):
		dummy_enemy.queue_free()
	if is_instance_valid(sonic_dummy):
		sonic_dummy.queue_free()
	lvl1.active_enemies_count = 0
	await process_frame
	print("[PASSOU] TESTE D — Controles Mobile (Touch em SOM e SOCO) validados com separação total.")

	# =========================================================================
	# TESTE E — NARRATIVA E PROGRESSÃO CAUSAL PELAS 10 FASES
	# =========================================================================
	# Na Fase 1, o portal deve estar TRANCADO até que Pablita investigue o Guarda-Roupa (roubo do CD),
	# fale com Chopp e ative o Cristal Sônico!
	lvl1._refresh_portal_lock()
	assert(lvl1.exit_portal.is_locked == true, "Teste E (Fase 1): Portal deve iniciar trancado antes dos eventos narrativos")

	# 1. Verificar presença de Luffy no quarto
	var found_luffy: bool = false
	var wardrobe_obj: WorldObject = null
	for child in lvl1.get_children():
		if child is ChoppNPC and (child as ChoppNPC).speaker_name.contains("Luffy"):
			found_luffy = true
		elif child is WorldObject and (child as WorldObject).object_type == WorldObject.ObjectType.LORE_PLINTH:
			wardrobe_obj = child as WorldObject
	assert(found_luffy, "Teste E (Fase 1): Cachorro Luffy deve estar presente no quarto de Pablita")
	assert(wardrobe_obj != null, "Teste E (Fase 1): Guarda-Roupa interativo deve existir no quarto")

	# 2. Investigar o Guarda-Roupa -> dispara evento da meia roubando o CD e abre passagem
	wardrobe_obj._on_interacted(pablita)
	assert(gm.has_story_flag("f1_wardrobe_checked"), "Teste E (Fase 1): Flag f1_wardrobe_checked deve ser ativada após evento do roubo do CD")
	assert(lvl1._show_thief_visual == true, "Teste E (Fase 1): A meia ladra com o CD deve aparecer fugindo pela passagem")

	# 3. Atravessar passagem e encontrar Chopp -> Chopp passa a acompanhar Pablita
	assert(lvl1.chopp_actor != null, "Teste E (Fase 1): Chopp deve estar no Esquecido")
	assert(lvl1.chopp_actor.follow_target == null, "Teste E (Fase 1): Chopp aguarda o encontro antes de seguir Pablita")
	lvl1.chopp_actor._on_interacted(pablita)
	assert(gm.has_story_flag("f1_chopp_met"), "Teste E (Fase 1): Flag f1_chopp_met deve ser registrada ao conhecer Chopp")
	assert(lvl1.chopp_actor.follow_target == pablita, "Teste E (Fase 1): Chopp deve passar a acompanhar Pablita após o encontro")

	# 4. Ativar o Cristal Sônico da Fase 1 -> destranca o portal para a Fase 2
	for c: WorldObject in lvl1.required_crystals:
		c._on_hurtbox_hit(30, Hitbox.DamageType.SONIC, Vector2.ZERO, 0.2)
	assert(lvl1.exit_portal.is_locked == false, "Teste E (Fase 1): Portal para Fase 2 deve destrancar após cumprir todos os eventos obrigatórios")
	print("[PASSOU] TESTE E.1 — Abertura no Quarto (Luffy, Guarda-Roupa, roubo do CD pela meia, chegada ao Esquecido e Chopp acompanhante).")

	lvl1.queue_free()
	await process_frame

	# Verificar continuidade, caminhos de entrada/saída e chefes nas Fases 2 a 10
	for lvl_idx in range(2, 11):
		var path: String = gm.LEVEL_PATHS[lvl_idx]
		var scene_res: PackedScene = load(path)
		assert(scene_res != null, "Cena da Fase %d deve existir" % lvl_idx)
		var lvl_node := scene_res.instantiate() as CampaignLevel
		root.add_child(lvl_node)
		current_scene = lvl_node
		await process_frame
		await process_frame

		assert(lvl_node.chopp_actor != null and lvl_node.chopp_actor.follow_target == lvl_node.pablita, "Fase %d: Chopp deve acompanhar Pablita ativamente" % lvl_idx)
		assert(lvl_node.return_portal != null, "Fase %d: Deve existir caminho conhecido de retorno (entrada/saída do Esquecido)" % lvl_idx)

		if lvl_idx == 3:
			var bosses := get_nodes_in_group("bosses")
			assert(not bosses.is_empty() and bosses[0] is BossSock, "Fase 3: Chefe obrigatório 'A Meia Esquecida' deve estar presente")
			var sock_boss := bosses[0] as BossSock
			for anc: WorldObject in sock_boss.active_anchors:
				anc._on_hurtbox_hit(30, Hitbox.DamageType.SONIC, Vector2.ZERO, 0.2)
			assert(sock_boss.current_state == BossSock.State.VULNERABLE_RECOVERY, "Fase 3: Âncoras rompidas com ataque sônico deixam A Meia Esquecida vulnerável")
			sock_boss.health_component.take_damage(sock_boss.max_health)
			await process_frame
			assert(gm.has_story_flag("f3_boss_defeated") and not lvl_node.exit_portal.is_locked, "Fase 3: Derrotar A Meia Esquecida avança a história e destranca Fase 4")

		elif lvl_idx == 4:
			assert(lvl_node.exit_portal.is_locked == true, "Fase 4: Portal trancado até conversar com os habitantes da Vila dos Achados")
			for child in lvl_node.get_children():
				if child is ChoppNPC and (child as ChoppNPC).speaker_name.contains("Despertador"):
					(child as ChoppNPC)._on_interacted(lvl_node.pablita)
			for child in lvl_node.get_children():
				if child is EnemyBase:
					(child as EnemyBase).health_component.take_damage(999)
			await process_frame
			assert(gm.has_story_flag("f4_talked_villager") and not lvl_node.exit_portal.is_locked, "Fase 4: Conversar com habitante e limpar trilha destranca Fase 5")

		elif lvl_idx == 7:
			var bosses := get_nodes_in_group("bosses")
			assert(not bosses.is_empty() and bosses[0] is BossRobot, "Fase 7: Chefe obrigatório 'O Robô Esquecido' deve estar presente")
			var robot_boss := bosses[0] as BossRobot
			robot_boss.current_state = BossRobot.State.RESONANCE_WINDOW
			robot_boss._on_hit_received(30, Hitbox.DamageType.SONIC, Vector2.ZERO, 0.2)
			assert(robot_boss.current_state == BossRobot.State.EXPOSED_VULNERABLE, "Fase 7: Ataque sônico na janela de ressonância expõe O Robô Esquecido")
			robot_boss.health_component.take_damage(robot_boss.max_health)
			await process_frame
			assert(gm.has_story_flag("f7_boss_defeated") and not lvl_node.exit_portal.is_locked, "Fase 7: Derrotar O Robô Esquecido destranca Fase 8")

		elif lvl_idx == 10:
			var bosses := get_nodes_in_group("bosses")
			assert(not bosses.is_empty() and bosses[0] is BossQueen, "Fase 10: Chefe final 'A Rainha Empoeirada' deve estar presente")
			var queen := bosses[0] as BossQueen
			queen._on_hit_received(30, Hitbox.DamageType.SONIC, Vector2.ZERO, 0.2)
			queen._on_hit_received(220, Hitbox.DamageType.PHYSICAL, Vector2.ZERO, 0.2)
			assert(queen.current_phase == 2, "Fase 10: Rainha avança para Fase 2 (Boneca Desfeita)")
			queen._on_hit_received(30, Hitbox.DamageType.SONIC, Vector2.ZERO, 0.2)
			queen._on_hit_received(220, Hitbox.DamageType.PHYSICAL, Vector2.ZERO, 0.2)
			assert(queen.current_phase == 3, "Fase 10: Rainha avança para Fase 3 (O Que Restou Dela)")
			queen.health_component.take_damage(queen.max_health)
			await process_frame
			assert(gm.has_story_flag("f10_queen_defeated") and gm.current_state == GameManagerService.GameState.CAMPAIGN_COMPLETE, "Fase 10: Derrotar A Rainha Empoeirada recupera o CD e conclui a campanha")

		lvl_node.queue_free()
		await process_frame

	print("[PASSOU] TESTE E.2 — Progressão narrativa pelas 10 fases, comunidades, Chopp guia e 3 chefes obrigatórios.")
	print("=== TODOS OS TESTES OBRIGATÓRIOS (A, B, C, D, E) PASSARAM COM 100% DE EVIDÊNCIA! ===")
	quit(0)
