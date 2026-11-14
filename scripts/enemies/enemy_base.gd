class_name EnemyBase
extends CharacterBody2D
## Estrutura base reutilizável de Inteligência Artificial para Mobs.
## Estados explícitos: IDLE, DETECT, APPROACH, TELEGRAPH, ATTACK, RECOVERY, HURT, DEAD.
## Representação visual 100% em placeholders geométricos (sem sprites).

signal enemy_died(enemy: EnemyBase)

enum State {
	IDLE,
	DETECT,
	APPROACH,
	TELEGRAPH,
	ATTACK,
	RECOVERY,
	HURT,
	DEAD
}

enum Archetype {
	MELEE_RUSHER,     # Exige aproximação e esquiva
	SONIC_SHIELDED,   # Possui escudo frontal quebrável apenas com ataque sônico
	THREAD_TRAPPER,   # Dispara fios/áreas que limitam movimentação de Pablita
	RHYTHM_BRUTE,     # Exige atenção ao ritmo dos ataques (pulsos rítmicos)
	HYBRID_WEAVER     # Combina escudo sônico, fios e investida
}

@export var archetype: Archetype = Archetype.MELEE_RUSHER
@export var max_health: int = 60
@export var move_speed: float = 55.0
@export var approach_speed: float = 82.0
@export var base_detection_radius: float = 175.0
@export var attack_range: float = 40.0
@export var contact_damage: int = 15

@export var detect_pause_duration: float = 0.20
@export var telegraph_duration: float = 0.45
@export var attack_duration: float = 0.32
@export var recovery_duration: float = 0.65

@export var drop_encarte_id: String = ""
@export var body_radius: float = 11.0
@export var placeholder_color: Color = Color(0.88, 0.32, 0.32, 1.0)

var current_state: State = State.IDLE
var state_timer: float = 0.0
var target_player: CharacterBody2D = null
var attack_dir: Vector2 = Vector2.LEFT
var has_sonic_shield: bool = false
var rhythm_cycle_count: int = 0

var health_component: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox
var body_collision: CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	var spr: Node = get_node_or_null("Sprite2D")
	if spr and spr is CanvasItem:
		(spr as CanvasItem).visible = false

	_ensure_components()
	_configure_archetype()
	queue_redraw()

func _ensure_components() -> void:
	collision_layer = 4
	collision_mask = 7 # Colide com mundo (2), jogador (1) e outros inimigos (4)

	body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision == null:
		body_collision = CollisionShape2D.new()
		body_collision.name = "CollisionShape2D"
		var c_shape := CircleShape2D.new()
		c_shape.radius = body_radius * 0.85
		body_collision.shape = c_shape
		add_child(body_collision)

	health_component = get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	health_component.max_health = max_health
	health_component.current_health = max_health
	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox == null:
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 4
		hurtbox.collision_mask = 0
		var hb_shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = body_radius * 1.15
		hb_shape.shape = c
		hurtbox.add_child(hb_shape)
		add_child(hurtbox)
	hurtbox.health_component = null # Gerenciamos dano manualmente para permitir escudo sônico
	hurtbox.invulnerability_duration = 0.12
	if not hurtbox.hit_received.is_connected(_on_hit_received):
		hurtbox.hit_received.connect(_on_hit_received)

	hitbox = get_node_or_null("Hitbox") as Hitbox
	if hitbox == null:
		hitbox = Hitbox.new()
		hitbox.name = "Hitbox"
		hitbox.collision_layer = 0
		hitbox.collision_mask = 2 # Hurtbox de Pablita está na layer 2
		var hit_cs := CollisionShape2D.new()
		var hc := CircleShape2D.new()
		hc.radius = body_radius * 1.15
		hit_cs.shape = hc
		hitbox.add_child(hit_cs)
		add_child(hitbox)
	hitbox.source_owner = self
	hitbox.damage = contact_damage
	hitbox.damage_type = Hitbox.DamageType.PHYSICAL
	hitbox.knockback_force = 200.0
	# A hitbox ofensiva só fica ativa durante o estado ATTACK para evitar múltiplos danos indevidos por contato passivo
	_set_hitbox_active(false)

func _configure_archetype() -> void:
	match archetype:
		Archetype.MELEE_RUSHER:
			placeholder_color = Color(0.9, 0.32, 0.32)
			has_sonic_shield = false
		Archetype.SONIC_SHIELDED:
			placeholder_color = Color(0.25, 0.65, 0.95)
			has_sonic_shield = true
			max_health = 70
			health_component.max_health = max_health
			health_component.current_health = max_health
		Archetype.THREAD_TRAPPER:
			placeholder_color = Color(0.75, 0.4, 0.9)
			attack_range = 125.0
			telegraph_duration = 0.50
			recovery_duration = 0.90
		Archetype.RHYTHM_BRUTE:
			placeholder_color = Color(0.95, 0.65, 0.2)
			body_radius = 14.0
			max_health = 95
			health_component.max_health = max_health
			health_component.current_health = max_health
			attack_range = 52.0
			telegraph_duration = 0.55
			recovery_duration = 0.85
		Archetype.HYBRID_WEAVER:
			placeholder_color = Color(0.9, 0.25, 0.65)
			has_sonic_shield = true
			max_health = 90
			health_component.max_health = max_health
			health_component.current_health = max_health
			attack_range = 95.0

func get_effective_detection_radius() -> float:
	var mult: float = 1.0
	var gm := GameManagerService.get_gm()
	if gm:
		var mods: Dictionary = gm.get_active_modifiers()
		mult = float(mods.get("enemy_detection_mult", 1.0))
	return base_detection_radius * mult

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	_locate_player()

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if target_player != null:
				_change_state(State.DETECT, detect_pause_duration)

		State.DETECT:
			velocity = Vector2.ZERO
			state_timer -= delta
			if target_player != null:
				attack_dir = (target_player.global_position - global_position).normalized()
			if state_timer <= 0.0:
				_change_state(State.APPROACH)

		State.APPROACH:
			if target_player == null or not is_instance_valid(target_player):
				_change_state(State.IDLE)
			else:
				var to_player: Vector2 = target_player.global_position - global_position
				var dist: float = to_player.length()
				if dist > get_effective_detection_radius() * 1.6:
					target_player = null
					_change_state(State.IDLE)
				elif dist <= attack_range:
					attack_dir = to_player.normalized() if dist > 0.01 else Vector2.DOWN
					_change_state(State.TELEGRAPH, telegraph_duration)
				else:
					attack_dir = to_player.normalized()
					velocity = attack_dir * approach_speed

		State.TELEGRAPH:
			velocity = velocity.move_toward(Vector2.ZERO, 450.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_execute_attack()

		State.ATTACK:
			state_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 260.0 * delta)
			if state_timer <= 0.0:
				_set_hitbox_active(false)
				_change_state(State.RECOVERY, recovery_duration)

		State.RECOVERY:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_change_state(State.APPROACH if target_player != null else State.IDLE)

		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 550.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_change_state(State.APPROACH if target_player != null else State.IDLE)

	move_and_slide()
	queue_redraw()

func _locate_player() -> void:
	if target_player != null and is_instance_valid(target_player):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var candidate := players[0] as CharacterBody2D
	if candidate and global_position.distance_to(candidate.global_position) <= get_effective_detection_radius():
		target_player = candidate

func _execute_attack() -> void:
	_change_state(State.ATTACK, attack_duration)
	match archetype:
		Archetype.MELEE_RUSHER:
			_set_hitbox_active(true)
			velocity = attack_dir * (approach_speed * 2.3)
		Archetype.SONIC_SHIELDED:
			_set_hitbox_active(true)
			velocity = attack_dir * (approach_speed * 2.0)
		Archetype.THREAD_TRAPPER:
			_spawn_thread_hazard(global_position + attack_dir * minf(attack_range * 0.85, 80.0))
			velocity = -attack_dir * 45.0
		Archetype.RHYTHM_BRUTE:
			rhythm_cycle_count += 1
			_set_hitbox_active(true)
			velocity = attack_dir * (approach_speed * 2.5 if rhythm_cycle_count % 2 == 0 else approach_speed * 1.6)
		Archetype.HYBRID_WEAVER:
			_set_hitbox_active(true)
			velocity = attack_dir * (approach_speed * 2.1)
			_spawn_thread_hazard(global_position + attack_dir * 48.0)

func _spawn_thread_hazard(pos: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var hazard := Area2D.new()
	hazard.name = "ThreadWebHazard"
	hazard.global_position = pos
	hazard.collision_layer = 0
	hazard.collision_mask = 1 # Pablita CharacterBody2D layer 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 22.0
	cs.shape = c
	hazard.add_child(cs)
	hazard.set_script(load("res://scripts/objects/web_slow_zone.gd"))
	get_tree().current_scene.add_child(hazard)

func _set_hitbox_active(active: bool) -> void:
	if hitbox:
		hitbox.set_deferred("monitoring", active)
		hitbox.set_deferred("monitorable", active)

func _change_state(new_state: State, duration: float = 0.0) -> void:
	current_state = new_state
	state_timer = duration
	queue_redraw()

func _on_hit_received(damage: int, damage_type: int, knockback: Vector2, stun_duration: float) -> void:
	if current_state == State.DEAD:
		return

	_set_hitbox_active(false)

	# Reações diferentes a ataques Físicos vs Sônicos
	var effective_damage: int = damage
	var effective_stun: float = stun_duration
	var effective_kb: Vector2 = knockback

	if has_sonic_shield:
		if damage_type == Hitbox.DamageType.SONIC:
			# Ataque sônico rompe o escudo e atordoa fortemente!
			has_sonic_shield = false
			effective_stun = maxf(stun_duration * 2.0, 0.55)
			effective_kb = knockback * 1.4
		else:
			# Ataque físico contra escudo sônico é quase bloqueado (ensina a usar o ataque sônico)
			effective_damage = maxi(2, int(damage * 0.15))
			effective_stun = 0.08
			effective_kb = knockback * 0.25
	else:
		if damage_type == Hitbox.DamageType.SONIC:
			# Ataque sônico interrompe antecipações e empurra mais longe
			effective_stun = maxf(stun_duration * 1.6, 0.42)
			effective_kb = knockback * 1.45
		else:
			# Ataque físico causa alto impacto direto
			effective_stun = maxf(stun_duration, 0.22)

	health_component.take_damage(effective_damage)
	if current_state != State.DEAD and health_component.current_health > 0:
		velocity = effective_kb
		_change_state(State.HURT, effective_stun)

func _on_died() -> void:
	_change_state(State.DEAD)
	_set_hitbox_active(false)
	if hurtbox:
		hurtbox.is_invulnerable = true
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if body_collision:
		body_collision.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0

	var gm := GameManagerService.get_gm()
	if not drop_encarte_id.is_empty() and gm and not gm.has_encarte(drop_encarte_id):
		gm.collect_encarte(drop_encarte_id)

	enemy_died.emit(self)
	queue_free()

func _draw() -> void:
	if current_state == State.DEAD:
		return

	var col: Color = placeholder_color
	if current_state == State.HURT:
		col = Color(1.0, 1.0, 1.0, 1.0)
	elif current_state == State.TELEGRAPH:
		col = Color(1.0, 0.9, 0.2, 1.0) # Amarelo forte avisando antecipação de ataque
	elif current_state == State.RECOVERY:
		col = placeholder_color.darkened(0.35)

	# Forma geométrica distinta por arquétipo
	match archetype:
		Archetype.MELEE_RUSHER:
			draw_circle(Vector2.ZERO, body_radius, col)
		Archetype.SONIC_SHIELDED:
			draw_rect(Rect2(Vector2(-body_radius, -body_radius), Vector2(body_radius * 2, body_radius * 2)), col, true)
		Archetype.THREAD_TRAPPER:
			var pts := PackedVector2Array([
				Vector2(0, -body_radius * 1.2),
				Vector2(body_radius * 1.1, body_radius * 0.9),
				Vector2(-body_radius * 1.1, body_radius * 0.9)
			])
			draw_colored_polygon(pts, col)
		Archetype.RHYTHM_BRUTE:
			draw_circle(Vector2.ZERO, body_radius, col)
			draw_arc(Vector2.ZERO, body_radius - 3.0, 0.0, TAU, 16, Color.BLACK, 2.0)
		Archetype.HYBRID_WEAVER:
			var hex := PackedVector2Array()
			for i in range(6):
				var a: float = i * TAU / 6.0
				hex.append(Vector2(cos(a), sin(a)) * body_radius)
			draw_colored_polygon(hex, col)

	# Indicador de escudo sônico ativo
	if has_sonic_shield:
		draw_arc(Vector2.ZERO, body_radius + 4.5, 0.0, TAU, 20, Color(0.25, 0.95, 1.0, 0.95), 2.5)

	# Indicador visual de TELEGRAPH (linha/cone de antecipação do ataque)
	if current_state == State.TELEGRAPH:
		draw_line(Vector2.ZERO, attack_dir * 26.0, Color(1.0, 0.2, 0.2, 0.9), 2.5)
		draw_arc(Vector2.ZERO, body_radius + 3.0, 0.0, TAU, 16, Color(1.0, 0.2, 0.2, 0.95), 2.0)

	# Mini barra de vida acima do inimigo
	if health_component and health_component.current_health < health_component.max_health:
		var ratio: float = clampf(float(health_component.current_health) / float(health_component.max_health), 0.0, 1.0)
		var bar_w: float = 22.0
		draw_rect(Rect2(Vector2(-bar_w * 0.5, -body_radius - 9.0), Vector2(bar_w, 3.5)), Color(0.1, 0.1, 0.1, 0.85), true)
		draw_rect(Rect2(Vector2(-bar_w * 0.5, -body_radius - 9.0), Vector2(bar_w * ratio, 3.5)), Color(0.95, 0.25, 0.3, 1.0), true)
