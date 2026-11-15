class_name BossQueen
extends CharacterBody2D
## Chefe Final da Fase 10: A Rainha Empoeirada (Tema: Combinação dos fundamentos anteriores).
## Possui 3 fases distintas:
## 1. Vitrine (100%..66%): Escudo de vitrine (quebrável com SÔNICO) + Vestido Imperial e Fragmentos da Memória
## 2. Boneca Desfeita (66%..33%): Linhas de Marionete + Tapeçaria Esquecida + Âncoras Sônicas
## 3. O Que Restou Dela (<33%): A Última Pose (combina ressonância rítmica + investida + abertura física)
## Todos os ataques possuem antecipação clara (TELEGRAPH) e janelas justas.

signal boss_health_changed(boss_name: String, current: int, maximum: int)
signal boss_defeated
signal phase_changed(new_phase: int)

enum State {
	IDLE,
	TELEGRAPH,
	IMPERIAL_DRESS,
	PUPPET_STRINGS,
	MEMORY_FRAGMENTS,
	FORGOTTEN_TAPESTRY,
	THE_LAST_POSE,
	VULNERABLE_WINDOW,
	DEAD
}

@export var boss_title: String = "A Rainha Empoeirada"
@export var max_health: int = 540
@export var body_radius: float = 26.0

var current_phase: int = 1 # 1 = Vitrine, 2 = Boneca Desfeita, 3 = O Que Restou Dela
var current_state: State = State.IDLE
var state_timer: float = 1.0
var queued_attack: State = State.IMPERIAL_DRESS
var attack_index: int = 0
var target_dir: Vector2 = Vector2.DOWN
var has_vitrine_barrier: bool = true

var health_component: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox
var body_collision: CollisionShape2D
var boss_sprite: Sprite2D = null
var _float_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	y_sort_enabled = true
	_setup_components()
	_setup_boss_sprite()
	queue_redraw()

func reset_boss(initial_pos: Vector2 = Vector2.INF) -> void:
	if initial_pos != Vector2.INF:
		global_position = initial_pos
	velocity = Vector2.ZERO
	current_phase = 1
	current_state = State.IDLE
	state_timer = 1.0
	attack_index = 0
	queued_attack = State.IMPERIAL_DRESS
	has_vitrine_barrier = true
	_set_hitbox_active(false)
	if hurtbox != null:
		hurtbox.is_invulnerable = false
	if get_tree():
		for h in get_tree().get_nodes_in_group("boss_hazards"):
			if is_instance_valid(h):
				h.queue_free()
	if health_component != null:
		health_component.current_health = max_health
		boss_health_changed.emit(get_phase_title(), max_health, max_health)
	_update_boss_visual(0.0)
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
	hurtbox.invulnerability_duration = 0.12
	var hb_cs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = body_radius * 1.2
	hb_cs.shape = hc
	hurtbox.add_child(hb_cs)
	hurtbox.hit_received.connect(_on_hit_received)
	add_child(hurtbox)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.source_owner = self
	hitbox.damage = 22
	hitbox.knockback_force = 270.0
	var hit_cs := CollisionShape2D.new()
	var hit_c := CircleShape2D.new()
	hit_c.radius = body_radius * 1.35
	hit_cs.shape = hit_c
	hitbox.add_child(hit_cs)
	_set_hitbox_active(false)
	add_child(hitbox)

func get_phase_title() -> String:
	match current_phase:
		1: return "%s — Fase 1: Vitrine" % boss_title
		2: return "%s — Fase 2: Boneca Desfeita" % boss_title
		3: return "%s — Fase 3: O Que Restou Dela" % boss_title
	return boss_title

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	var player := _get_player()
	if player:
		target_dir = (player.global_position - global_position).normalized()

	match current_state:
		State.IDLE:
			var spd: float = 55.0 + float(current_phase - 1) * 15.0
			velocity = target_dir * spd
			move_and_slide()
			state_timer -= delta
			if state_timer <= 0.0:
				_choose_next_attack()

		State.TELEGRAPH:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_perform_queued_attack()

		State.IMPERIAL_DRESS, State.PUPPET_STRINGS, State.THE_LAST_POSE:
			state_timer -= delta
			move_and_slide()
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				current_state = State.VULNERABLE_WINDOW
				state_timer = 1.65

		State.MEMORY_FRAGMENTS, State.FORGOTTEN_TAPESTRY:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.VULNERABLE_WINDOW
				state_timer = 1.55

		State.VULNERABLE_WINDOW:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				if current_phase >= 2 and attack_index % 2 == 0:
					has_vitrine_barrier = true
				current_state = State.IDLE
				state_timer = 0.85

	_update_boss_visual(delta)
	queue_redraw()

func _choose_next_attack() -> void:
	var pool: Array[State] = []
	match current_phase:
		1:
			pool = [State.IMPERIAL_DRESS, State.MEMORY_FRAGMENTS]
		2:
			pool = [State.PUPPET_STRINGS, State.FORGOTTEN_TAPESTRY, State.MEMORY_FRAGMENTS]
		3:
			pool = [State.THE_LAST_POSE, State.IMPERIAL_DRESS, State.FORGOTTEN_TAPESTRY, State.PUPPET_STRINGS]

	queued_attack = pool[attack_index % pool.size()]
	attack_index += 1
	current_state = State.TELEGRAPH
	state_timer = 0.65 if current_phase < 3 else 0.55

func _perform_queued_attack() -> void:
	current_state = queued_attack
	match queued_attack:
		State.IMPERIAL_DRESS:
			state_timer = 0.45
			_set_hitbox_active(true)
			velocity = target_dir * 210.0
			_spawn_projectile_ring(6, false)
		State.PUPPET_STRINGS:
			state_timer = 0.48
			_spawn_projectile_fan(4, true)
			velocity = -target_dir * 60.0
		State.MEMORY_FRAGMENTS:
			state_timer = 0.45
			_spawn_projectile_fan(5, false)
		State.FORGOTTEN_TAPESTRY:
			state_timer = 0.50
			_spawn_projectile_ring(8, true)
		State.THE_LAST_POSE:
			state_timer = 0.55
			_set_hitbox_active(true)
			velocity = target_dir * 245.0
			_spawn_projectile_ring(8, false)

func _spawn_projectile_ring(count: int, leaves_web: bool) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	for i in range(count):
		var a: float = i * TAU / float(count)
		var proj := BossProjectile.new()
		proj.global_position = global_position
		proj.direction = Vector2(cos(a), sin(a))
		proj.speed = 150.0
		proj.damage = 16
		proj.leaves_web_on_expire = leaves_web
		proj.projectile_color = Color(0.95, 0.75, 0.3, 1.0)
		get_tree().current_scene.add_child(proj)

func _spawn_projectile_fan(count: int, leaves_web: bool) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var base_a: float = target_dir.angle()
	for i in range(count):
		var offset_a: float = deg_to_rad((i - (count - 1) * 0.5) * 18.0)
		var proj := BossProjectile.new()
		proj.global_position = global_position
		proj.direction = Vector2.RIGHT.rotated(base_a + offset_a)
		proj.speed = 165.0
		proj.damage = 16
		proj.leaves_web_on_expire = leaves_web
		proj.projectile_color = Color(0.95, 0.4, 0.75, 1.0)
		get_tree().current_scene.add_child(proj)

func _set_hitbox_active(active: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", active)
		hitbox.set_deferred("monitorable", active)

func _on_hit_received(damage: int, damage_type: int, _knockback: Vector2, _stun: float) -> void:
	if current_state == State.DEAD:
		return

	var final_damage: int = damage
	if has_vitrine_barrier:
		if damage_type == Hitbox.DamageType.SONIC:
			# Ataque sônico estilhaça a barreira de vitrine/marionete e abre janela física!
			has_vitrine_barrier = false
			_set_hitbox_active(false)
			current_state = State.VULNERABLE_WINDOW
			state_timer = 2.6
			final_damage = int(round(damage * 1.25))
		else:
			final_damage = maxi(3, int(round(damage * 0.25)))
	elif current_state == State.VULNERABLE_WINDOW:
		final_damage = int(round(damage * (1.45 if damage_type == Hitbox.DamageType.PHYSICAL else 1.1)))

	health_component.take_damage(final_damage)
	_check_phase_transitions()

func _check_phase_transitions() -> void:
	var hp_ratio: float = float(health_component.current_health) / float(max_health)
	if hp_ratio <= 0.33 and current_phase < 3:
		current_phase = 3
		has_vitrine_barrier = true
		phase_changed.emit(current_phase)
		boss_health_changed.emit(get_phase_title(), health_component.current_health, max_health)
	elif hp_ratio <= 0.66 and current_phase < 2:
		current_phase = 2
		has_vitrine_barrier = true
		phase_changed.emit(current_phase)
		boss_health_changed.emit(get_phase_title(), health_component.current_health, max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	boss_health_changed.emit(get_phase_title(), current, maximum)

func _on_died() -> void:
	current_state = State.DEAD
	_set_hitbox_active(false)
	hurtbox.is_invulnerable = true
	if get_tree():
		for h in get_tree().get_nodes_in_group("boss_hazards"):
			if is_instance_valid(h):
				h.queue_free()
	boss_health_changed.emit(get_phase_title(), 0, max_health)
	boss_defeated.emit()
	queue_free()

func _get_player() -> Pablita:
	var p := get_tree().get_nodes_in_group("player")
	return p[0] as Pablita if not p.is_empty() else null

func _draw() -> void:
	if current_state == State.DEAD:
		return

	# Sombra projetada da Rainha Empoeirada flutuante (400%)
	draw_circle(Vector2(0, 32), body_radius * 0.9, Color(0.06, 0.03, 0.1, 0.42))

	if boss_sprite == null or boss_sprite.texture == null:
		var col := Color(0.85, 0.68, 0.95, 1.0)
		if current_phase == 2:
			col = Color(0.9, 0.35, 0.65, 1.0)
		elif current_phase == 3:
			col = Color(0.95, 0.2, 0.35, 1.0)

		if current_state == State.TELEGRAPH:
			col = Color(1.0, 0.9, 0.25, 1.0)
		elif current_state == State.VULNERABLE_WINDOW:
			col = Color(0.35, 0.95, 0.55, 1.0)

		var pts := PackedVector2Array()
		for i in range(8):
			var a: float = i * TAU / 8.0
			var r: float = body_radius if i % 2 == 0 else body_radius * 0.78
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)
		draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(1.0, 0.9, 0.4), 2.2)

	if has_vitrine_barrier:
		draw_arc(Vector2.ZERO, body_radius + 10.0, 0.0, TAU, 28, Color(0.75, 0.35, 1.0, 0.95), 3.0)
		draw_arc(Vector2.ZERO, body_radius + 15.0, 0.0, TAU, 28, Color(0.98, 0.45, 0.80, 0.65), 1.8)

	if current_state == State.VULNERABLE_WINDOW:
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 26, Color(0.35, 0.95, 0.55, 0.90), 2.4)
	elif current_state == State.TELEGRAPH:
		draw_line(Vector2.ZERO, target_dir * 52.0, Color(1.0, 0.2, 0.2, 0.95), 3.0)
		draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.25, 0.85), 2.2)

func _setup_boss_sprite() -> void:
	var tex_path: String = "res://assets/characters/enemies/boss_queen.png"
	if not ResourceLoader.exists(tex_path):
		return
	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_sprite.texture = load(tex_path) as Texture2D
	boss_sprite.offset = Vector2(0, -18)
	add_child(boss_sprite)

func _update_boss_visual(delta: float) -> void:
	if boss_sprite == null:
		return
	if current_state == State.DEAD:
		boss_sprite.visible = false
		return
	boss_sprite.visible = true
	_float_timer += delta
	boss_sprite.offset = Vector2(0.0, -18.0 + sin(_float_timer * 2.4) * 5.0)
	if absf(target_dir.x) > 0.12:
		boss_sprite.flip_h = target_dir.x < 0.0
	if current_state == State.TELEGRAPH:
		boss_sprite.modulate = Color(1.30, 1.15, 0.55, 1.0)
	elif current_state == State.VULNERABLE_WINDOW:
		boss_sprite.modulate = Color(0.65, 1.35, 0.80, 1.0)
	elif current_phase == 2:
		boss_sprite.modulate = Color(1.12, 0.86, 1.0, 1.0)
	elif current_phase == 3:
		boss_sprite.modulate = Color(1.22, 0.72, 0.84, 1.0)
	else:
		boss_sprite.modulate = Color.WHITE
