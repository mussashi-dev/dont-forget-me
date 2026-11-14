class_name BossRobot
extends CharacterBody2D
## Chefe da Fase 7: O Robô Esquecido (Tema: Ritmo e Sincronização).
## Ataques:
## 1. Pulso mecânico (anéis rítmicos de projéteis)
## 2. Marcha acelerada (avanço cadenciado em direção a Pablita)
## 3. Batida de fábrica (impacto circular de curto alcance)
## 4. Sobrecarga (sequência acelerada na Fase 2)
## Mecânica Central: O núcleo do robô vibra em uma janela de RESSONÂNCIA claramente visível e tolerante
## para controles touch. Um ataque SÔNICO nessa janela interrompe a ressonância e expõe as partes
## mecânicas (EXPOSED_VULNERABLE) para ataques FÍSICOS pesados!

signal boss_health_changed(boss_name: String, current: int, maximum: int)
signal boss_defeated

enum State {
	IDLE,
	RESONANCE_WINDOW, # Núcleo vibrando: janela tolerante para ataque SÔNICO!
	TELEGRAPH,
	MECHANICAL_PULSE,
	ACCELERATED_MARCH,
	FACTORY_BEAT,
	OVERLOAD,
	EXPOSED_VULNERABLE, # Partes mecânicas expostas para ataque FÍSICO!
	DEAD
}

@export var boss_title: String = "O Robô Esquecido"
@export var max_health: int = 420
@export var body_size: Vector2 = Vector2(46, 46)
@export var resonance_window_duration: float = 1.65 # Janela ampla e justa para controles mobile

var current_state: State = State.IDLE
var current_phase: int = 1
var state_timer: float = 0.9
var attack_cycle: int = 0
var queued_attack: State = State.MECHANICAL_PULSE
var target_dir: Vector2 = Vector2.DOWN

var health_component: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox
var body_collision: CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	_setup_components()
	queue_redraw()

func _setup_components() -> void:
	collision_layer = 4
	collision_mask = 3

	body_collision = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body_size * 0.85
	body_collision.shape = r
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
	var hr := RectangleShape2D.new()
	hr.size = body_size * 1.15
	hb_cs.shape = hr
	hurtbox.add_child(hb_cs)
	hurtbox.hit_received.connect(_on_hit_received)
	add_child(hurtbox)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.source_owner = self
	hitbox.damage = 22
	hitbox.knockback_force = 280.0
	var hit_cs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = 34.0
	hit_cs.shape = hc
	hitbox.add_child(hit_cs)
	_set_hitbox_active(false)
	add_child(hitbox)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	var player := _get_player()
	if player:
		target_dir = (player.global_position - global_position).normalized()

	match current_state:
		State.IDLE:
			velocity = target_dir * 45.0
			move_and_slide()
			state_timer -= delta
			if state_timer <= 0.0:
				# Entra na janela rítmica de vibração do núcleo antes de atacar
				current_state = State.RESONANCE_WINDOW
				state_timer = resonance_window_duration

		State.RESONANCE_WINDOW:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_select_next_attack()

		State.TELEGRAPH:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_execute_queued_attack()

		State.MECHANICAL_PULSE, State.OVERLOAD:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.85

		State.ACCELERATED_MARCH:
			state_timer -= delta
			move_and_slide()
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				current_state = State.IDLE
				state_timer = 0.85

		State.FACTORY_BEAT:
			state_timer -= delta
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				current_state = State.IDLE
				state_timer = 0.95

		State.EXPOSED_VULNERABLE:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.8

	queue_redraw()

func _select_next_attack() -> void:
	var pattern: Array[State] = [
		State.MECHANICAL_PULSE,
		State.ACCELERATED_MARCH,
		State.FACTORY_BEAT,
		State.OVERLOAD if current_phase == 2 else State.MECHANICAL_PULSE
	]
	queued_attack = pattern[attack_cycle % pattern.size()]
	attack_cycle += 1
	current_state = State.TELEGRAPH
	state_timer = 0.50

func _execute_queued_attack() -> void:
	current_state = queued_attack
	match queued_attack:
		State.MECHANICAL_PULSE:
			state_timer = 0.45
			_fire_radial_pulses(6 if current_phase == 1 else 8)
		State.ACCELERATED_MARCH:
			state_timer = 0.55
			_set_hitbox_active(true)
			velocity = target_dir * (215.0 if current_phase == 1 else 255.0)
		State.FACTORY_BEAT:
			state_timer = 0.45
			_set_hitbox_active(true)
			_fire_radial_pulses(4)
		State.OVERLOAD:
			state_timer = 0.55
			_fire_radial_pulses(10)

func _fire_radial_pulses(count: int) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	for i in range(count):
		var a: float = i * TAU / float(count)
		var proj := BossProjectile.new()
		proj.global_position = global_position
		proj.direction = Vector2(cos(a), sin(a))
		proj.speed = 150.0
		proj.damage = 16
		proj.projectile_color = Color(0.25, 0.9, 1.0, 1.0)
		get_tree().current_scene.add_child(proj)

func _set_hitbox_active(active: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", active)
		hitbox.set_deferred("monitorable", active)

func _on_hit_received(damage: int, damage_type: int, _knockback: Vector2, _stun: float) -> void:
	if current_state == State.DEAD:
		return

	if current_state == State.RESONANCE_WINDOW and damage_type == Hitbox.DamageType.SONIC:
		# Ressonância interrompida com sucesso! Expõe partes mecânicas!
		_set_hitbox_active(false)
		current_state = State.EXPOSED_VULNERABLE
		state_timer = 3.2
		health_component.take_damage(int(round(damage * 1.4)))
		return

	var mult: float = 0.35
	if current_state == State.EXPOSED_VULNERABLE:
		mult = 1.65 if damage_type == Hitbox.DamageType.PHYSICAL else 1.15
	var final_dmg: int = maxi(4, int(round(damage * mult)))
	health_component.take_damage(final_dmg)

	if health_component.current_health <= max_health / 2 and current_phase == 1:
		current_phase = 2

func _on_health_changed(current: int, maximum: int) -> void:
	boss_health_changed.emit(boss_title, current, maximum)

func _on_died() -> void:
	current_state = State.DEAD
	_set_hitbox_active(false)
	hurtbox.is_invulnerable = true
	boss_health_changed.emit(boss_title, 0, max_health)
	boss_defeated.emit()
	queue_free()

func _get_player() -> Pablita:
	var p := get_tree().get_nodes_in_group("player")
	return p[0] as Pablita if not p.is_empty() else null

func _draw() -> void:
	if current_state == State.DEAD:
		return

	var half := body_size * 0.5
	var rect := Rect2(-half, body_size)
	var hull_col := Color(0.45, 0.52, 0.65, 1.0) if current_phase == 1 else Color(0.65, 0.42, 0.35, 1.0)
	if current_state == State.EXPOSED_VULNERABLE:
		hull_col = Color(0.3, 0.9, 0.45, 1.0)
	elif current_state == State.TELEGRAPH:
		hull_col = Color(1.0, 0.85, 0.2, 1.0)

	draw_rect(rect, hull_col, true)
	draw_rect(rect, Color.WHITE, false, 2.2)

	# Núcleo central rítmico
	var core_col := Color(0.2, 0.3, 0.4, 1.0)
	var core_radius: float = 10.0
	if current_state == State.RESONANCE_WINDOW:
		core_col = Color(0.15, 0.95, 1.0, 1.0) # Ciano brilhante indicando janela sônica!
		core_radius = 15.0
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(0.2, 0.95, 1.0, 0.95), 3.0)
	elif current_state == State.EXPOSED_VULNERABLE:
		core_col = Color(1.0, 0.45, 0.15, 1.0) # Laranja indicando vulnerabilidade física!
		core_radius = 14.0

	draw_circle(Vector2.ZERO, core_radius, core_col)
