class_name Pablita
extends CharacterBody2D
## Protagonista (top-down). Representada por placeholder geométrico (cápsula + indicador de direção).
## Movimentação em 8 direções, velocidade normalizada nas diagonais, memorização da última direção válida,
## integração com Pipop, encartes e sistema de vida/interação.

signal interaction_prompt_updated(message: String, is_visible: bool)
signal health_updated(current: int, maximum: int)
signal died

enum State { IDLE, WALK, DASH, ATTACK_PHYSICAL, ATTACK_SONIC, HURT, DEAD }

@export var base_move_speed: float = 95.0
@export var acceleration: float = 820.0
@export var friction: float = 760.0

@export var dash_speed: float = 210.0
@export var dash_duration: float = 0.16
@export var base_dash_cooldown: float = 0.45

@export var base_max_health: int = 100
@export var base_interact_radius: float = 24.0

var move_speed: float = 95.0
var dash_cooldown: float = 0.45
var speed_modifier_zone: float = 1.0 # Para teias/restrições de movimento

var current_state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN
var dash_direction: Vector2 = Vector2.DOWN
var can_dash: bool = true

var _state_timer: float = 0.0
var _dash_cd_timer: float = 0.0
var _hurt_flash_timer: float = 0.0

var nearby_interactables: Array[Interactable] = []
var focused_interactable: Interactable = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var pipop: PipopComponent = $PipopComponent
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var interaction_shape: CollisionShape2D = $InteractionDetector/CollisionShape2D
@onready var pipop_companion: PipopCompanion = $PipopCompanion
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	# Desativar sprites originais e usar placeholder geométrico
	if sprite:
		sprite.visible = false
	var shadow: Node = get_node_or_null("Shadow")
	if shadow and shadow is CanvasItem:
		(shadow as CanvasItem).visible = false

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	interaction_detector.area_entered.connect(_on_interaction_area_entered)
	interaction_detector.area_exited.connect(_on_interaction_area_exited)

	if pipop_companion:
		pipop_companion.target_follow = self
	if pipop and pipop_companion:
		pipop.set_companion(pipop_companion)

	var gm := GameManagerService.get_gm()
	if gm:
		gm.equipment_changed.connect(apply_encarte_modifiers)
	apply_encarte_modifiers()
	health_updated.emit(health_component.current_health, health_component.max_health)
	queue_redraw()

func set_camera_limits(rect: Rect2i) -> void:
	if camera:
		camera.limit_left = rect.position.x
		camera.limit_top = rect.position.y
		camera.limit_right = rect.end.x
		camera.limit_bottom = rect.end.y

func apply_encarte_modifiers() -> void:
	var gm := GameManagerService.get_gm()
	var mods: Dictionary = gm.get_active_modifiers() if gm else {}
	var spd_mult: float = float(mods.get("move_speed_mult", 1.0))
	var dash_mult: float = float(mods.get("dash_cooldown_mult", 1.0))
	var hp_bonus: int = int(mods.get("max_health_bonus", 0))
	var dmg_taken_mult: float = float(mods.get("damage_taken_mult", 1.0))
	var interact_mult: float = float(mods.get("interact_radius_mult", 1.0))

	move_speed = base_move_speed * spd_mult
	dash_cooldown = maxf(0.15, base_dash_cooldown * dash_mult)
	if hurtbox:
		hurtbox.damage_multiplier = dmg_taken_mult

	if health_component:
		var old_max: int = health_component.max_health
		var new_max: int = maxi(20, base_max_health + hp_bonus)
		health_component.max_health = new_max
		if health_component.current_health > new_max:
			health_component.current_health = new_max
		elif new_max > old_max:
			health_component.current_health += (new_max - old_max)
		health_updated.emit(health_component.current_health, health_component.max_health)

	if interaction_shape and interaction_shape.shape is CircleShape2D:
		(interaction_shape.shape as CircleShape2D).radius = base_interact_radius * interact_mult

func _physics_process(delta: float) -> void:
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		queue_redraw()

	if not can_dash:
		_dash_cd_timer -= delta
		if _dash_cd_timer <= 0.0:
			can_dash = true

	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match current_state:
		State.IDLE, State.WALK:
			_handle_movement(delta)
			_handle_actions()
		State.DASH:
			_state_timer -= delta
			velocity = dash_direction * dash_speed * speed_modifier_zone
			move_and_slide()
			if _state_timer <= 0.0:
				hurtbox.is_invulnerable = false
				current_state = State.IDLE
				queue_redraw()
		State.ATTACK_PHYSICAL, State.ATTACK_SONIC:
			_state_timer -= delta
			# Permite leve ajuste de movimento durante ataque ou cancelamento por esquiva
			var input_vec: Vector2 = _read_movement_input()
			if input_vec != Vector2.ZERO:
				velocity = velocity.move_toward(input_vec * (move_speed * 0.35 * speed_modifier_zone), acceleration * delta)
			else:
				velocity = velocity.move_toward(Vector2.ZERO, friction * 1.5 * delta)
			move_and_slide()
			if Input.is_action_just_pressed("dash") and can_dash:
				if pipop:
					pipop.cancel_current_attack()
				_start_dash()
				return
			if _state_timer <= 0.0:
				current_state = State.IDLE
				queue_redraw()
		State.HURT:
			_state_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			if _state_timer <= 0.0:
				current_state = State.IDLE
				queue_redraw()

	if not nearby_interactables.is_empty():
		_update_focused_interactable()

static func direction_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "east" if dir.x > 0.0 else "west"
	return "south" if dir.y >= 0.0 else "north"

func _read_movement_input() -> Vector2:
	var raw_vec: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if raw_vec.length() < 0.12:
		return Vector2.ZERO
	# Normaliza para garantir velocidade consistente em todas as 8 direções (incluindo diagonais)
	return raw_vec.normalized()

func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
		var target_vel: Vector2 = facing_direction * (move_speed * speed_modifier_zone)
		velocity = velocity.move_toward(target_vel, acceleration * delta)
		current_state = State.WALK
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		current_state = State.IDLE
	move_and_slide()
	queue_redraw()

func _handle_actions() -> void:
	if Input.is_action_just_pressed("dash") and can_dash:
		_start_dash()
		return
	var phys_pressed: bool = Input.is_action_just_pressed("attack_physical")
	var sonic_pressed: bool = Input.is_action_just_pressed("attack_sonic")
	# Regra de prioridade explícita: se ambos forem acionados no mesmo frame, apenas um é executado (nunca ambos)
	if sonic_pressed and not phys_pressed:
		_start_sonic_attack()
	elif phys_pressed and not sonic_pressed:
		_start_physical_attack()
	elif phys_pressed and sonic_pressed:
		_start_physical_attack()
	elif Input.is_action_just_pressed("interact"):
		_try_interact()

func _start_dash() -> void:
	can_dash = false
	_dash_cd_timer = dash_cooldown
	current_state = State.DASH
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
	dash_direction = facing_direction.normalized() if facing_direction != Vector2.ZERO else Vector2.DOWN
	_state_timer = dash_duration
	hurtbox.is_invulnerable = true
	queue_redraw()

func _start_physical_attack() -> void:
	if not pipop:
		return
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
	if pipop.perform_physical_attack(facing_direction):
		current_state = State.ATTACK_PHYSICAL
		_state_timer = minf(pipop.physical_cooldown * 0.75, 0.22)
		velocity = facing_direction * 45.0 # Pequeno impulso tático
		queue_redraw()

func _start_sonic_attack() -> void:
	if not pipop:
		return
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
	if pipop.perform_sonic_attack(facing_direction, global_position + Vector2(0, -10)):
		current_state = State.ATTACK_SONIC
		_state_timer = minf(pipop.sonic_cooldown * 0.45, 0.20)
		queue_redraw()

func _try_interact() -> void:
	_update_focused_interactable()
	if focused_interactable != null and is_instance_valid(focused_interactable):
		focused_interactable.interact(self)

func _on_hit_received(_damage: int, _damage_type: int, knockback: Vector2, stun_duration: float) -> void:
	if current_state == State.DEAD:
		return
	if pipop:
		pipop.cancel_current_attack()
	current_state = State.HURT
	velocity = knockback
	_state_timer = clampf(stun_duration, 0.1, 0.35)
	_hurt_flash_timer = 0.25
	queue_redraw()

func _on_health_changed(current: int, maximum: int) -> void:
	health_updated.emit(current, maximum)

func _on_died() -> void:
	current_state = State.DEAD
	if pipop:
		pipop.cancel_current_attack()
	queue_redraw()
	died.emit()

# ---------- Interação com Prioridade e Proximidade ----------
func _on_interaction_area_entered(area: Area2D) -> void:
	if area is Interactable:
		if not nearby_interactables.has(area):
			nearby_interactables.append(area as Interactable)
		_update_focused_interactable()

func _on_interaction_area_exited(area: Area2D) -> void:
	if area is Interactable:
		var interactable: Interactable = area as Interactable
		if interactable == focused_interactable:
			interactable.lose_focus()
			focused_interactable = null
		nearby_interactables.erase(interactable)
		_update_focused_interactable()

func _update_focused_interactable() -> void:
	# Limpa referências inválidas ou inativas
	for i in range(nearby_interactables.size() - 1, -1, -1):
		var item: Interactable = nearby_interactables[i]
		if not is_instance_valid(item) or not item.is_active:
			if item == focused_interactable and is_instance_valid(item):
				item.lose_focus()
				focused_interactable = null
			nearby_interactables.remove_at(i)

	if nearby_interactables.is_empty():
		if focused_interactable != null and is_instance_valid(focused_interactable):
			focused_interactable.lose_focus()
		focused_interactable = null
		interaction_prompt_updated.emit("", false)
		return

	var best: Interactable = null
	var best_priority: int = -999999
	var min_dist: float = INF
	for item: Interactable in nearby_interactables:
		var d: float = global_position.distance_to(item.global_position)
		if item.interaction_priority > best_priority or (item.interaction_priority == best_priority and d < min_dist):
			best_priority = item.interaction_priority
			min_dist = d
			best = item

	if best != focused_interactable:
		if focused_interactable != null and is_instance_valid(focused_interactable):
			focused_interactable.lose_focus()
		focused_interactable = best
		if focused_interactable != null:
			focused_interactable.gain_focus()
	if focused_interactable != null:
		interaction_prompt_updated.emit(focused_interactable.prompt_message, true)

func _draw() -> void:
	# Placeholder geométrico para Pablita:
	# Sombra elíptica na base + cápsula/retângulo arredondado + seta/linha indicando facing_direction
	draw_circle(Vector2(0, -2), 6.0, Color(0.05, 0.03, 0.08, 0.5))

	var body_color: Color = Color(0.25, 0.78, 0.98, 1.0) # Azul claro Pablita
	if current_state == State.DEAD:
		body_color = Color(0.35, 0.35, 0.4, 0.7)
	elif _hurt_flash_timer > 0.0 or current_state == State.HURT:
		body_color = Color(1.0, 0.25, 0.25, 1.0)
	elif current_state == State.DASH:
		body_color = Color(0.65, 0.95, 1.0, 0.8)
	elif current_state == State.ATTACK_PHYSICAL:
		body_color = Color(0.4, 0.88, 1.0, 1.0)

	# Corpo (cápsula composta por retângulo e dois círculos)
	var top_center := Vector2(0, -18)
	var bot_center := Vector2(0, -6)
	draw_circle(top_center, 6.5, body_color)
	draw_circle(bot_center, 6.5, body_color)
	draw_rect(Rect2(Vector2(-6.5, -18), Vector2(13, 12)), body_color, true)
	draw_arc(Vector2(0, -12), 7.5, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)

	# Indicador claro de orientação (memoriza última direção válida)
	var dir_origin := Vector2(0, -12)
	var dir_tip := dir_origin + facing_direction.normalized() * 13.0
	draw_line(dir_origin, dir_tip, Color(1.0, 0.95, 0.3, 1.0), 2.2)
	draw_circle(dir_tip, 2.5, Color(1.0, 0.95, 0.3, 1.0))

