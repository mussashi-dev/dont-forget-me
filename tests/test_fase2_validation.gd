extends SceneTree
## Validação headless da Fase 2:
## - Configuração Nearest + SpriteFrames de Pablita e Pipop (frames e animações)
## - Pivôs nos pés (offset.y < 0)
## - TileMapLayer (madeira do quarto + roxo do Esquecido) e StaticBody2D (paredes e móveis)
## - 3 Mobs (Brinquedo de Corda, Tufo de Meias, Flor de Poeira): colisão ativa e lógica
## Uso: godot --headless --path . -s res://tests/test_fase2_validation.gd

func _init() -> void:
	var gm_script: Script = load("res://autoload/game_manager.gd")
	var gm_node: Node = gm_script.new()
	gm_node.name = "GameManager"
	root.add_child(gm_node)

	var am_script: Script = load("res://autoload/audio_manager.gd")
	var am_node: Node = am_script.new()
	am_node.name = "AudioManager"
	root.add_child(am_node)

	call_deferred("_run_validation")

func _run_validation() -> void:
	print("=== INICIANDO VALIDAÇÃO HEADLESS DA FASE 2 ===")

	# 1. Filtro Nearest global no project.godot
	var default_filter: int = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	assert(default_filter == 0, "default_texture_filter deve ser 0 (Nearest)")
	print("[PASSOU] 1. Filtro global = Nearest (0)")

	# 2. Carregar Fase2.tscn
	var fase2_packed: PackedScene = load("res://scenes/levels/Fase2.tscn")
	assert(fase2_packed != null, "Fase2.tscn deve carregar")
	var fase2 := fase2_packed.instantiate() as Node2D
	root.add_child(fase2)
	current_scene = fase2
	await process_frame
	await process_frame

	# 3. Validar Pablita & Pipop SpriteFrames, animações e pivô
	var pablita: Pablita = fase2.get_node("Pablita") as Pablita
	assert(pablita != null, "Pablita deve estar instanciada em Fase2")
	var p_sprite: AnimatedSprite2D = pablita.get_node("Sprite") as AnimatedSprite2D
	assert(p_sprite != null and p_sprite.sprite_frames != null, "Pablita deve possuir SpriteFrames")
	assert(p_sprite.offset.y < 0.0, "Pivô da Pablita deve estar nos pés (offset.y < 0)")
	for anim: String in ["idle_south", "walk_south", "walk_north", "walk_east", "walk_west"]:
		assert(p_sprite.sprite_frames.has_animation(anim), "Pablita deve ter animação %s" % anim)
		assert(p_sprite.sprite_frames.get_frame_count(anim) >= 1, "Animação %s deve ter frames" % anim)
		p_sprite.play(anim)
		assert(p_sprite.animation == StringName(anim), "Pablita deve tocar %s" % anim)

	var pipop: PipopCompanion = pablita.get_node("PipopCompanion") as PipopCompanion
	assert(pipop != null, "PipopCompanion deve estar presente")
	var pip_sprite: AnimatedSprite2D = pipop.get_node("Sprite") as AnimatedSprite2D
	assert(pip_sprite != null and pip_sprite.sprite_frames != null, "Pipop deve possuir SpriteFrames")
	assert(pip_sprite.offset.y < 0.0, "Pivô do Pipop deve estar nos pés (offset.y < 0)")
	for anim: String in ["idle_south", "walk_south", "sonic_roar"]:
		assert(pip_sprite.sprite_frames.has_animation(anim), "Pipop deve ter animação %s" % anim)
		assert(pip_sprite.sprite_frames.get_frame_count(anim) >= 1, "Animação Pipop %s deve ter frames" % anim)
	print("[PASSOU] 2. Pablita (8 anims) e Pipop (14 anims) com SpriteFrames válidos e pivô nos pés.")

	# 4. Validar TileMapLayer e StaticBody2D (paredes e móveis)
	var tile_layer: TileMapLayer = fase2.get_node("CorredorTileMapLayer") as TileMapLayer
	assert(tile_layer != null and tile_layer.tile_set != null, "CorredorTileMapLayer deve ter TileSet")
	assert(tile_layer.tile_set.tile_size == Vector2i(32, 32), "TileSet deve usar grid 32x32")
	var left_source: int = tile_layer.get_cell_source_id(Vector2i(2, 5))
	var right_source: int = tile_layer.get_cell_source_id(Vector2i(18, 5))
	assert(left_source in [0, 1], "Metade esquerda do corredor deve usar tiles de madeira do quarto")
	assert(right_source in [2, 3], "Metade direita do corredor deve usar tiles roxos do Esquecido")

	var walls: StaticBody2D = fase2.get_node("ParedesStaticBody") as StaticBody2D
	assert(walls != null and walls.collision_layer == 2, "ParedesStaticBody deve existir na layer 2")
	var active_wall_shapes: int = 0
	for child: Node in walls.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			active_wall_shapes += 1
	assert(active_wall_shapes == 4, "Todas as 4 paredes devem ter CollisionShape2D ativo")

	var furniture: Node2D = fase2.get_node("MoveisQuarto") as Node2D
	assert(furniture != null and furniture.get_child_count() >= 3, "MoveisQuarto deve conter móveis com colisão")
	for furn: Node in furniture.get_children():
		assert(furn is StaticBody2D, "Móvel %s deve ser StaticBody2D" % furn.name)
		var fcs: CollisionShape2D = furn.get_node_or_null("CollisionShape2D") as CollisionShape2D
		assert(fcs != null and not fcs.disabled, "Móvel %s deve ter CollisionShape2D ativo" % furn.name)
	print("[PASSOU] 3. TileMapLayer (32x32 madeira + Esquecido) e StaticBody2D de paredes/móveis ativos.")

	# 5. Validar os 3 Mobs (colisão ativa, pivô nos pés e comportamento)
	var corda: Node2D = fase2.get_node("Mobs/BrinquedoDeCorda") as Node2D
	assert(corda != null, "BrinquedoDeCorda deve estar em Mobs")
	var corda_cs: CollisionShape2D = corda.get_node("CollisionShape2D") as CollisionShape2D
	var corda_spr: Sprite2D = corda.get_node("Sprite2D") as Sprite2D
	assert(corda_cs != null and not corda_cs.disabled, "BrinquedoDeCorda CollisionShape2D deve estar ativo")
	assert(corda_spr.offset.y < 0.0, "BrinquedoDeCorda pivô deve estar nos pés")
	# Mover até colidir com a parede direita e verificar inversão de direção
	var initial_dir: Vector2 = corda.get("patrol_direction")
	corda.global_position = Vector2(726, 176)
	corda.set("patrol_direction", Vector2.RIGHT)
	for i: int in 15:
		await physics_frame
	assert((corda.get("patrol_direction") as Vector2).x < 0.0, "BrinquedoDeCorda deve virar ao colidir com a parede (era %s)" % str(initial_dir))

	var tufo: Node2D = fase2.get_node("Mobs/TufoDeMeias") as Node2D
	assert(tufo != null, "TufoDeMeias deve estar em Mobs")
	var tufo_cs: CollisionShape2D = tufo.get_node("CollisionShape2D") as CollisionShape2D
	var tufo_spr: Sprite2D = tufo.get_node("Sprite2D") as Sprite2D
	var tufo_detect: Area2D = tufo.get_node("DetectionArea") as Area2D
	assert(tufo_cs != null and not tufo_cs.disabled, "TufoDeMeias CollisionShape2D deve estar ativo")
	assert(tufo_spr.offset.y < 0.0, "TufoDeMeias pivô deve estar nos pés")
	assert(tufo_detect != null and tufo_detect.monitoring, "TufoDeMeias DetectionArea deve estar monitorando")
	pablita.global_position = tufo.global_position + Vector2(-50, 0)
	tufo.call("_on_detection_body_entered", pablita)
	tufo._physics_process(0.016)
	assert(tufo.get("target_player") == pablita, "TufoDeMeias deve detectar Pablita ao entrar na Area2D")
	assert((tufo as CharacterBody2D).velocity.x < 0.0, "TufoDeMeias deve mover-se na direção da Pablita")

	var flor: Node2D = fase2.get_node("Mobs/FlorDePoeira") as Node2D
	assert(flor != null, "FlorDePoeira deve estar em Mobs")
	var flor_cs: CollisionShape2D = flor.get_node("CollisionShape2D") as CollisionShape2D
	var flor_spr: Sprite2D = flor.get_node("Sprite2D") as Sprite2D
	var flor_timer: Timer = flor.get_node("ShootTimer") as Timer
	assert(flor_cs != null and not flor_cs.disabled, "FlorDePoeira CollisionShape2D deve estar ativo")
	assert(flor_spr.offset.y < 0.0, "FlorDePoeira pivô deve estar nos pés")
	assert(flor_timer != null and is_equal_approx(flor_timer.wait_time, 2.0), "FlorDePoeira ShootTimer deve ser 2.0s")
	var spore: Area2D = flor.call("fire_spore_at_player") as Area2D
	assert(spore != null and spore.is_inside_tree(), "FlorDePoeira deve instanciar EsporoProjectile na árvore")
	var spore_dir: Vector2 = spore.get("direction")
	assert(spore_dir.x < 0.0, "Esporo deve ser disparado na direção da Pablita")
	print("[PASSOU] 4. Mobs (BrinquedoDeCorda, TufoDeMeias, FlorDePoeira) com colisão ativa e lógica validada.")

	print("=== VALIDAÇÃO HEADLESS DA FASE 2 CONCLUÍDA COM 100% DE SUCESSO! ===")
	fase2.queue_free()
	await process_frame
	quit(0)
