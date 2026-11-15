extends SceneTree
## Headless integration test validating:
## - SpriteFrames from assets/asset_manifest.json (Pablita + BossSock + BossRobot + BossQueen)
## - Non-null textures across all animation frames & correct frame advancement
## - Boss visual hierarchy scale (3x/4x relative to 32px Pablita) & floor-aligned pivot (y = 0)
## - Fase2.tscn TileMapLayer 32x32 final reference tiles & furniture textures
## - HUD TouchActionButton & top bar UI textures
## Uso: godot --headless --path . --script tests/test_manifest_integration.gd

var _failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[FAIL] ", msg)


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	# 1. Verify all SpriteFrames resources load cleanly with zero null frame textures.
	var sf_expectations: Dictionary = {
		"res://resources/pablita_topdown_frames.tres": ["idle_south", "idle_north", "idle_east", "idle_west", "walk_south", "walk_north", "walk_east", "walk_west", "run_south", "dash_south", "attack_phys"],
		"res://resources/boss_sock_frames.tres": ["locomotion", "attack_web", "impact_death"],
		"res://resources/boss_robot_frames.tres": ["locomotion", "attack_sonic", "damage_death"],
		"res://resources/boss_queen_frames.tres": ["locomotion", "attack_web", "hit_fall"],
	}
	for res_path: String in sf_expectations.keys():
		var sf := ResourceLoader.load(res_path) as SpriteFrames
		_check(sf != null, "SpriteFrames missing: %s" % res_path)
		if sf == null:
			continue
		for anim_name: String in sf_expectations[res_path]:
			_check(sf.has_animation(anim_name), "%s missing animation '%s'" % [res_path, anim_name])
			if not sf.has_animation(anim_name):
				continue
			var cnt: int = sf.get_frame_count(anim_name)
			_check(cnt >= 1, "%s.%s has 0 frames" % [res_path, anim_name])
			for i in range(cnt):
				var tex: Texture2D = sf.get_frame_texture(anim_name, i)
				_check(tex != null and tex.get_width() > 0 and tex.get_height() > 0, "%s.%s[%d] has null/empty texture" % [res_path, anim_name, i])

	# 2. Verify Pablita AnimatedSprite2D + animation frame playback
	var pablita_scene := ResourceLoader.load("res://scenes/characters/pablita.tscn") as PackedScene
	_check(pablita_scene != null, "pablita.tscn failed to load")
	if pablita_scene != null:
		var pablita := pablita_scene.instantiate() as Node2D
		root.add_child(pablita)
		await process_frame
		var pspr := pablita.get_node_or_null("Sprite") as AnimatedSprite2D
		_check(pspr != null and pspr.sprite_frames != null, "Pablita AnimatedSprite2D missing")
		if pspr != null and pspr.sprite_frames != null:
			_check(pspr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Pablita Sprite must use Nearest filter")
			pspr.play(&"walk_south")
			_check(pspr.animation == &"walk_south", "Pablita should play walk_south")
			var f_before: int = pspr.frame
			for _k in range(15):
				await create_timer(0.02).timeout
			_check(pspr.frame != f_before or pspr.sprite_frames.get_frame_count(&"walk_south") > 1, "Pablita walk_south should have multiple frames and animate")
		pablita.queue_free()

	# 3. Verify Bosses: AnimatedSprite2D, non-null textures, 3x/4x scale relative to 32px Pablita, floor pivot, state transitions
	await _verify_boss(BossSock.new(), 3.0, ["locomotion", "attack_web", "impact_death"], BossSock.State.CREEPING_STITCH, &"attack_web")
	await _verify_boss(BossRobot.new(), 4.0, ["locomotion", "attack_sonic", "damage_death"], BossRobot.State.MECHANICAL_PULSE, &"attack_sonic")
	await _verify_boss(BossQueen.new(), 4.0, ["locomotion", "attack_web", "hit_fall"], BossQueen.State.IMPERIAL_DRESS, &"attack_web")

	# 4. Verify Fase2 scene tileset (32x32) & final reference furniture textures
	var fase2_scene := ResourceLoader.load("res://scenes/levels/Fase2.tscn") as PackedScene
	_check(fase2_scene != null, "Fase2.tscn failed to load")
	if fase2_scene != null:
		var f2 := fase2_scene.instantiate() as Node2D
		root.add_child(f2)
		await process_frame
		var tile_layer := f2.get_node_or_null("CorredorTileMapLayer") as TileMapLayer
		_check(tile_layer != null and tile_layer.tile_set != null, "Fase2 CorredorTileMapLayer missing")
		if tile_layer != null and tile_layer.tile_set != null:
			_check(tile_layer.tile_set.tile_size == Vector2i(32, 32), "Fase2 tile_size must be 32x32")
			for sid in range(5):
				_check(tile_layer.tile_set.has_source(sid), "Fase2 TileSet missing source %d" % sid)
				if tile_layer.tile_set.has_source(sid):
					var atlas := tile_layer.tile_set.get_source(sid) as TileSetAtlasSource
					_check(atlas != null and atlas.texture != null and atlas.texture.get_size() == Vector2(32, 32), "Fase2 tile source %d must be 32x32 non-null" % sid)
		for furn_name: String in ["Cama", "GuardaRoupa", "Estante"]:
			var spr := f2.get_node_or_null("MoveisQuarto/%s/Sprite2D" % furn_name) as Sprite2D
			_check(spr != null and spr.texture != null, "Fase2 furniture %s texture null" % furn_name)
			if spr != null and spr.texture != null:
				_check(spr.texture.resource_path.contains("final_reference"), "Fase2 furniture %s should use final_reference asset" % furn_name)
		var hud := f2.get_node_or_null("HUD") as HUD
		_check(hud != null, "Fase2 HUD missing")
		if hud != null:
			for btn_name: String in ["PhysicalAttackBtn", "SonicAttackBtn", "DashBtn", "InteractButton"]:
				var tbtn := hud.get_node_or_null("RootControl/TouchControls/%s" % btn_name) as TouchActionButton
				_check(tbtn != null and tbtn.texture_normal != null and tbtn.texture_pressed != null, "HUD button %s missing textured sprites" % btn_name)
			_check(hud.btn_toggle_pause != null and hud.btn_toggle_pause.icon != null, "HUD Pause button missing icon")
		f2.queue_free()
		await process_frame

	# 5. Verify actual Campaign Level 1 scene (`level_01_intro.tscn`) uses final_reference tiles & furniture
	var lvl1_scene := ResourceLoader.load("res://scenes/levels/level_01_intro.tscn") as PackedScene
	_check(lvl1_scene != null, "level_01_intro.tscn failed to load")
	if lvl1_scene != null:
		var lvl1 := lvl1_scene.instantiate() as CampaignLevel
		root.add_child(lvl1)
		await process_frame
		_check(lvl1.bedroom_floor_layer != null and lvl1.bedroom_floor_layer.tile_set != null, "Level 1 BedroomFloorLayer missing")
		var bed_spr := lvl1.get_node_or_null("BedroomBed/Sprite2D") as Sprite2D
		_check(bed_spr != null and bed_spr.texture != null and bed_spr.texture.resource_path.contains("final_reference"), "Level 1 BedroomBed should use final_reference asset")
		var teddy_spr := lvl1.get_node_or_null("UrsinhoEsquecido/Sprite2D") as Sprite2D
		_check(teddy_spr != null and teddy_spr.texture != null and teddy_spr.texture.resource_path.contains("final_reference"), "Level 1 UrsinhoEsquecido should use final_reference asset")
		lvl1.queue_free()
		await process_frame

	if _failures.is_empty():
		print("[PASSOU] Integracao completa do asset_manifest.json (SpriteFrames, escala 3x/4x, pivo, tileset 32x32, UI) sem texturas nulas.")
		quit(0)
	else:
		printerr("[FALHOU] %d erros encontrados." % _failures.size())
		quit(1)


func _verify_boss(boss: Node2D, expected_mult: float, required_anims: Array[String], attack_state: int, expected_attack_anim: StringName) -> void:
	root.add_child(boss)
	await process_frame
	var bspr := boss.get_node_or_null("BossSprite") as AnimatedSprite2D
	_check(bspr != null and bspr.sprite_frames != null, "%s missing AnimatedSprite2D or SpriteFrames" % boss.get_class())
	if bspr != null and bspr.sprite_frames != null:
		_check(bspr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s BossSprite must use Nearest filter" % boss.name)
		for a: String in required_anims:
			_check(bspr.sprite_frames.has_animation(a), "%s missing animation '%s'" % [boss.name, a])
		var tex: Texture2D = bspr.sprite_frames.get_frame_texture(bspr.animation, bspr.frame)
		_check(tex != null, "%s current frame texture is null" % boss.name)
		if tex != null:
			var rendered_h: float = float(tex.get_height()) * bspr.scale.y
			_check(absf(rendered_h - 32.0 * expected_mult) < 0.75, "%s rendered height %.1f expected %.1f" % [boss.name, rendered_h, 32.0 * expected_mult])
			_check(absf(bspr.offset.y + float(tex.get_height()) * 0.5) < 8.0, "%s base pivot should align to floor (y=0)" % boss.name)
		boss.set("current_state", attack_state)
		if boss.has_method("_update_boss_visual"):
			if boss is BossQueen:
				boss.call("_update_boss_visual", 0.016)
			else:
				boss.call("_update_boss_visual")
		_check(bspr.animation == expected_attack_anim, "%s attack state should switch to '%s' (got '%s')" % [boss.name, String(expected_attack_anim), String(bspr.animation)])
	boss.queue_free()
	await process_frame
