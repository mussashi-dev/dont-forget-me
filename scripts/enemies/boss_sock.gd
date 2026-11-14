class_name BossSock
extends CharacterBody2D
## Chefe da Fase 3: A Meia Esquecida (Tema: Controle de Espaço).
## Ataques:
## 1. Costura rastejante (fios avançam pelo chão e podem prender/desacelerar Pablita)
## 2. Teia de contenção (cria áreas de restrição na arena)
## 3. Salto de costura (deslocamento rápido seguido de recuperação)
## 4. Chicote de fiapos (ataque horizontal de varredura)
## Mecânica Central: Pontos de ancoragem na arena podem ser rompidos com ataques SÔNICOS.
## Romper as âncoras reduz o controle da arena e abre janela de vulnerabilidade para ataques FÍSICOS.

signal boss_health_changed(boss_name: String, current: int, maximum: int)
signal boss_defeated

enum State {
	IDLE,
	TELEGRAPH,
	CREEPING_STITCH,
	CONTAINMENT_WEB,
	STITCH_LEAP,
	LINT_WHIP,
	VULNERABLE_RECOVERY,
	DEAD
}

@export var boss_title: String = "A Meia Esquecida"
@export var max_health: int = 320
@export var move_speed: float = 70.0
@export var body_radius: float = 24.0

var current_state: State = State.IDLE
var current_phase: int = 1 # Fase 1 (100%..50%), Fase 2 (<50%)
var state_timer: float = 0.0
var queued_attack: State = State.CREEPING_STITCH
var attack_cycle_index: int = 0
var target_dir: Vector2 = Vector2.DOWN

var active_anchors: Array[WorldObject] = []
var health_component: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox
var body_collision: CollisionShape2D
var boss_sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	_setup_components()
	_setup_boss_sprite()
	call_deferred("_spawn_arena_anchors")
	_update_boss_visual()
	queue_redraw()

func _setup_components() -> void:
	collision_layer = 4
	collision_mask = 3

	body_collision = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = body_radius * 0.85
	body_collision.shape = c
	add_child(body_collision)

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	add_child(health_component)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	hurtbox.invulnerability_duration = 0.14
	var hb_cs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = body_radius * 1.15
	hb_cs.shape = hc
	hurtbox.add_child(hb_cs)
	hurtbox.hit_received.connect(_on_hit_received)
	add_child(hurtbox)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.source_owner = self
	hitbox.damage = 20
	hitbox.knockback_force = 250.0
	var hit_cs := CollisionShape2D.new()
	var hit_c := CircleShape2D.new()
	hit_c.radius = body_radius * 1.25
	hit_cs.shape = hit_c
	hitbox.add_child(hit_cs)
	_set_hitbox_active(false)
	add_child(hitbox)

func _spawn_arena_anchors() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	for anc: WorldObject in active_anchors:
		if is_instance_valid(anc):
			anc.queue_free()
	active_anchors.clear()

	var offsets: Array[Vector2] = [
		Vector2(-130, -75),
		Vector2(130, -75),
		Vector2(0, 85)
	]
	var center := Vector2(320, 210)
	for off: Vector2 in offsets:
		var anchor := WorldObject.new()
		anchor.object_type = WorldObject.ObjectType.SONIC_CRYSTAL
		anchor.global_position = center + off
		anchor.activated.connect(_on_anchor_broken)
		get_tree().current_scene.add_child(anchor)
		active_anchors.append(anchor)
	_update_boss_visual()
	queue_redraw()

func get_intact_anchor_count() -> int:
	var count: int = 0
	for anc: WorldObject in active_anchors:
		if is_instance_valid(anc) and not anc.is_activated:
			count += 1
	return count

func _on_anchor_broken(_anchor: WorldObject) -> void:
	if current_state == State.DEAD:
		return
	if get_intact_anchor_count() == 0:
		# Todas as âncoras foram rompidas por ataques sônicos -> Chefe fica vulnerável!
		_set_hitbox_active(false)
		velocity = Vector2.ZERO
		current_state = State.VULNERABLE_RECOVERY
		state_timer = 3.2
	_update_boss_visual()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	var player := _get_player()
	if player:
		target_dir = (player.global_position - global_position).normalized()

	match current_state:
		State.IDLE:
			state_timer -= delta
			if player:
				velocity = target_dir * (move_speed * (1.25 if current_phase == 2 else 1.0))
			move_and_slide()
			if state_timer <= 0.0:
				_select_next_attack()

		State.TELEGRAPH:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			move_and_slide()
			state_timer -= delta
			if state_timer <= 0.0:
				_start_queued_attack()

		State.CREEPING_STITCH:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_post_attack_recovery(0.9)

		State.CONTAINMENT_WEB:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_post_attack_recovery(0.85)

		State.STITCH_LEAP:
			state_timer -= delta
			move_and_slide()
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				_enter_post_attack_recovery(1.35)

		State.LINT_WHIP:
			state_timer -= delta
			move_and_slide()
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				_enter_post_attack_recovery(1.0)

		State.VULNERABLE_RECOVERY:
			velocity = velocity.move_toward(Vector2.ZERO, 450.0 * delta)
			move_and_slide()
			state_timer -= delta
			if state_timer <= 0.0:
				if get_intact_anchor_count() == 0:
					_spawn_arena_anchors()
				current_state = State.IDLE
				state_timer = 1.1

	_update_boss_visual()
	queue_redraw()

func _select_next_attack() -> void:
	var pattern: Array[State] = [
		State.CREEPING_STITCH,
		State.CONTAINMENT_WEB,
		State.STITCH_LEAP,
		State.LINT_WHIP
	]
	queued_attack = pattern[attack_cycle_index % pattern.size()]
	attack_cycle_index += 1
	current_state = State.TELEGRAPH
	state_timer = 0.55 if current_phase == 2 else 0.72

func _start_queued_attack() -> void:
	current_state = queued_attack
	match queued_attack:
		State.CREEPING_STITCH:
			state_timer = 0.45
			_fire_creeping_stitches()
		State.CONTAINMENT_WEB:
			state_timer = 0.45
			_spawn_containment_webs()
		State.STITCH_LEAP:
			state_timer = 0.48
			_set_hitbox_active(true)
			velocity = target_dir * (230.0 if current_phase == 1 else 270.0)
		State.LINT_WHIP:
			state_timer = 0.42
			_set_hitbox_active(true)
			var horiz_dir := Vector2(signf(target_dir.x) if absf(target_dir.x) > 0.05 else 1.0, 0.0)
			velocity = horiz_dir * 260.0

func _fire_creeping_stitches() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var count: int = 3 if current_phase == 1 else 5
	var base_angle: float = target_dir.angle()
	for i in range(count):
		var offset_angle: float = deg_to_rad((i - (count - 1) * 0.5) * 20.0)
		var proj := BossProjectile.new()
		proj.global_position = global_position
		proj.direction = Vector2.RIGHT.rotated(base_angle + offset_angle)
		proj.speed = 155.0
		proj.damage = 14
		proj.leaves_web_on_expire = true
		proj.projectile_color = Color(0.85, 0.45, 0.95, 1.0)
		get_tree().current_scene.add_child(proj)

func _spawn_containment_webs() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var player := _get_player()
	var base_pos: Vector2 = player.global_position if player else global_position + Vector2(80, 0)
	var offsets: Array[Vector2] = [Vector2(-36, 0), Vector2(36, 0)]
	if current_phase == 2:
		offsets.append(Vector2(0, 36))
	for off: Vector2 in offsets:
		var web := Area2D.new()
		web.global_position = base_pos + off
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 24.0
		cs.shape = c
		web.add_child(cs)
		web.set_script(load("res://scripts/objects/web_slow_zone.gd"))
		get_tree().current_scene.add_child(web)

func _enter_post_attack_recovery(dur: float) -> void:
	current_state = State.VULNERABLE_RECOVERY
	state_timer = dur

func _set_hitbox_active(active: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", active)
		hitbox.set_deferred("monitorable", active)

func _on_hit_received(damage: int, damage_type: int, _knockback: Vector2, _stun: float) -> void:
	if current_state == State.DEAD:
		return

	# Enquanto houver pontos de ancoragem intactos, a Meia Esquecida tem alta resistência,
	# incentivando o uso do ataque SÔNICO nos pontos de ancoragem ou diretamente para enfraquecer!
	var intact: int = get_intact_anchor_count()
	var final_dmg: int = damage
	if current_state == State.VULNERABLE_RECOVERY:
		final_dmg = int(round(damage * 1.35))
	elif intact > 0:
		if damage_type == Hitbox.DamageType.SONIC:
			# Ataque sônico direto no chefe também rompe 1 âncora próxima se houver
			for anc: WorldObject in active_anchors:
				if is_instance_valid(anc) and not anc.is_activated:
					anc.is_activated = true
					anc.queue_redraw()
					_on_anchor_broken(anc)
					break
		final_dmg = maxi(4, int(round(damage * 0.45)))

	health_component.take_damage(final_dmg)
	if health_component.current_health <= max_health / 2 and current_phase == 1:
		current_phase = 2
		_spawn_arena_anchors()

func _on_health_changed(current: int, maximum: int) -> void:
	boss_health_changed.emit(boss_title, current, maximum)

func _on_died() -> void:
	current_state = State.DEAD
	_set_hitbox_active(false)
	hurtbox.is_invulnerable = true
	for anc: WorldObject in active_anchors:
		if is_instance_valid(anc):
			anc.queue_free()
	active_anchors.clear()
	if get_tree():
		for h in get_tree().get_nodes_in_group("boss_hazards"):
			if is_instance_valid(h):
				h.queue_free()
	boss_health_changed.emit(boss_title, 0, max_health)
	boss_defeated.emit()
	queue_free()

func _get_player() -> Pablita:
	var p := get_tree().get_nodes_in_group("player")
	return p[0] as Pablita if not p.is_empty() else null

func _draw() -> void:
	if current_state == State.DEAD:
		return

	# Linhas conectando o chefe às âncoras ativas (mostrando controle de espaço)
	for anc: WorldObject in active_anchors:
		if is_instance_valid(anc) and not anc.is_activated:
			draw_line(Vector2.ZERO, to_local(anc.global_position), Color(0.85, 0.5, 1.0, 0.55), 2.0)

	# Sombra suave na arena (escala 300%)
	draw_circle(Vector2(0, 22), body_radius * 1.15, Color(0.06, 0.03, 0.1, 0.42))

	if boss_sprite == null or boss_sprite.texture == null:
		var col := Color(0.72, 0.32, 0.88, 1.0) if current_phase == 1 else Color(0.92, 0.22, 0.68, 1.0)
		if current_state == State.TELEGRAPH:
			col = Color(1.0, 0.88, 0.25, 1.0)
		elif current_state == State.VULNERABLE_RECOVERY:
			col = Color(0.35, 0.95, 0.55, 1.0)
		draw_circle(Vector2.ZERO, body_radius, col)
		draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color.WHITE, 2.2)

	if current_state == State.VULNERABLE_RECOVERY:
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 28, Color(0.35, 0.95, 0.55, 0.85), 2.6)
	elif current_state == State.TELEGRAPH:
		draw_line(Vector2.ZERO, target_dir * 48.0, Color(1.0, 0.25, 0.25, 0.95), 3.0)
		draw_arc(Vector2.ZERO, body_radius + 4.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.3, 0.85), 2.2)
	elif current_state == State.LINT_WHIP:
		draw_line(Vector2(-46, 0), Vector2(46, 0), Color(1.0, 0.9, 0.4, 0.95), 5.0)

func _setup_boss_sprite() -> void:
	var tex_path: String = "res://assets/characters/enemies/boss_sock.png"
	if not ResourceLoader.exists(tex_path):
		return
	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_sprite.texture = load(tex_path) as Texture2D
	boss_sprite.offset = Vector2(0, -10)
	add_child(boss_sprite)

func _update_boss_visual() -> void:
	if boss_sprite == null:
		return
	if current_state == State.DEAD:
		boss_sprite.visible = false
		return
	boss_sprite.visible = true
	if absf(target_dir.x) > 0.12:
		boss_sprite.flip_h = target_dir.x < 0.0
	if current_state == State.TELEGRAPH:
		boss_sprite.modulate = Color(1.3, 1.15, 0.55, 1.0)
	elif current_state == State.VULNERABLE_RECOVERY:
		boss_sprite.modulate = Color(0.65, 1.35, 0.80, 1.0)
	elif current_phase == 2:
		boss_sprite.modulate = Color(1.18, 0.82, 0.95, 1.0)
	else:
		boss_sprite.modulate = Color.WHITE
