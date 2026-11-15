class_name Pablita
extends CharacterBody2D
## Protagonista (top-down). Representada por placeholder geométrico (cápsula + indicador de direção).
## Movimentação em 8 direções, velocidade normalizada nas diagonais, memorização da última direção válida,
## integração com Pipop, encartes e sistema de vida/interação.

signal interaction_prompt_updated(message: String, is_visible: bool)
signal health_updated(current: int, maximum: int)
signal died

enum State { IDLE, WALK, DASH, ATTACK_PHYSICAL, ATTACK_SONIC, HURT, DEAD, CINEMATIC_LOCKED }

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
var _active_slow_zones: Dictionary = {} # instance_id -> slow_factor

var current_state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN
var dash_direction: Vector2 = Vector2.DOWN
var can_dash: bool = true

var _state_timer: float = 0.0
var _dash_cd_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

var nearby_interactables: Array[Interactable] = []
var focused_interactable: Interactable = null

var _orig_camera_pos: Vector2 = Vector2(0, -14)
var _orig_camera_zoom: Vector2 = Vector2(2, 2)
var _orig_camera_smoothing: bool = true
var _active_camera_tween: Tween = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var pipop: PipopComponent = $PipopComponent
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var interaction_shape: CollisionShape2D = $InteractionDetector/CollisionShape2D
@onready var pipop_companion: PipopCompanion = $PipopCompanion
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	y_sort_enabled = true
	add_to_group("player")
	# Ativar sprite pixel-art e sombra na base
	if sprite:
		sprite.visible = true
		sprite.play("idle_south")
	var shadow: Node = get_node_or_null("Shadow")
	if shadow and shadow is CanvasItem:
		(shadow as CanvasItem).visible = true

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
		if not gm.story_flag_changed.is_connected(_on_story_flag_changed):
			gm.story_flag_changed.connect(_on_story_flag_changed)
	apply_encarte_modifiers()
	_refresh_pipop_acquisition_state()
	health_updated.emit(health_component.current_health, health_component.max_health)
	if camera:
		_orig_camera_pos = camera.position
		_orig_camera_zoom = camera.zoom
		_orig_camera_smoothing = camera.position_smoothing_enabled
	queue_redraw()

func is_pipop_available() -> bool:
	var gm := GameManagerService.get_gm()
	if gm == null:
		return true
	return gm.is_pipop_acquired()

func _on_story_flag_changed(flag_name: String, _value: Variant) -> void:
	if flag_name == "pipop_acquired":
		_refresh_pipop_acquisition_state()

func _refresh_pipop_acquisition_state() -> void:
	var available: bool = is_pipop_available()
	if pipop_companion:
		pipop_companion.visible = available
		pipop_companion.set_physics_process(available)
	if pipop:
		pipop.visible = available
		if not available:
			pipop.cancel_current_attack()

func register_slow_zone(zone: Area2D, factor: float) -> void:
	if zone == null:
		return
	_active_slow_zones[zone.get_instance_id()] = clampf(factor, 0.1, 1.0)
	_recompute_slow_zone_modifier()

func unregister_slow_zone(zone: Area2D) -> void:
	if zone == null:
		return
	_active_slow_zones.erase(zone.get_instance_id())
	_recompute_slow_zone_modifier()

func _recompute_slow_zone_modifier() -> void:
	var to_remove: Array = []
	var min_factor: float = 1.0
	for id_key in _active_slow_zones.keys():
		var obj: Object = instance_from_id(int(id_key))
		if obj == null or not is_instance_valid(obj):
			to_remove.append(id_key)
		else:
			min_factor = minf(min_factor, float(_active_slow_zones[id_key]))
	for k in to_remove:
		_active_slow_zones.erase(k)
	speed_modifier_zone = min_factor

func apply_screen_shake(intensity: float = 2.5, duration: float = 0.12) -> void:
	var gm := GameManagerService.get_gm()
	if gm != null and not gm.screen_shake_enabled:
		return
	if camera == null or camera.top_level:
		return
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)

func set_camera_limits(rect: Rect2i) -> void:
	if camera:
		camera.limit_left = rect.position.x
		camera.limit_top = rect.position.y
		camera.limit_right = rect.end.x
		camera.limit_bottom = rect.end.y

func set_cinematic_locked(locked: bool) -> void:
	if locked:
		velocity = Vector2.ZERO
		current_state = State.CINEMATIC_LOCKED
		queue_redraw()
	else:
		if current_state == State.CINEMATIC_LOCKED:
			current_state = State.IDLE
			queue_redraw()

func focus_camera_on(world_position: Vector2, duration: float = 1.0, zoom_factor: float = 2.4) -> Tween:
	if not camera:
		return null
	if _active_camera_tween and _active_camera_tween.is_valid():
		_active_camera_tween.kill()
	var start_global: Vector2 = camera.global_position
	camera.top_level = true
	camera.global_position = start_global
	camera.position_smoothing_enabled = false
	_active_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_camera_tween.tween_property(camera, "global_position", world_position, duration)
	_active_camera_tween.tween_property(camera, "zoom", Vector2(zoom_factor, zoom_factor), duration)
	return _active_camera_tween

func return_camera_to_player(duration: float = 0.8) -> Tween:
	if not camera:
		return null
	if _active_camera_tween and _active_camera_tween.is_valid():
		_active_camera_tween.kill()
	var target_global: Vector2 = global_position + _orig_camera_pos
	_active_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_camera_tween.tween_property(camera, "global_position", target_global, duration)
	_active_camera_tween.tween_property(camera, "zoom", _orig_camera_zoom, duration)
	_active_camera_tween.chain().tween_callback(func():
		if camera:
			camera.top_level = false
			camera.position = _orig_camera_pos
			camera.zoom = _orig_camera_zoom
			camera.position_smoothing_enabled = _orig_camera_smoothing
	)
	return _active_camera_tween

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

	if _shake_timer > 0.0:
		_shake_timer -= delta
		if camera and not camera.top_level:
			if _shake_timer > 0.0:
				camera.offset = Vector2(
					randf_range(-_shake_intensity, _shake_intensity),
					randf_range(-_shake_intensity, _shake_intensity)
				)
			else:
				camera.offset = Vector2.ZERO
				_shake_intensity = 0.0
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	if not can_dash:
		_dash_cd_timer -= delta
		if _dash_cd_timer <= 0.0:
			can_dash = true

	_update_sprite_visuals()

	if current_state == State.DEAD or current_state == State.CINEMATIC_LOCKED:
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
	var am := AudioManagerService.get_am()
	if am:
		am.play_sfx("dash")
	queue_redraw()

func _start_physical_attack() -> void:
	if not pipop or not is_pipop_available():
		return
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
	if pipop.perform_physical_attack(facing_direction):
		current_state = State.ATTACK_PHYSICAL
		_state_timer = minf(pipop.physical_cooldown * 0.75, 0.22)
		velocity = facing_direction * 45.0 # Pequeno impulso tático
		var am := AudioManagerService.get_am()
		if am:
			am.play_sfx("physical_hit_%d" % clampi(pipop.current_combo_step, 1, 3))
		queue_redraw()

func _start_sonic_attack() -> void:
	if not pipop or not is_pipop_available():
		return
	var input_dir: Vector2 = _read_movement_input()
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
	if pipop.perform_sonic_attack(facing_direction, global_position + Vector2(0, -10)):
		current_state = State.ATTACK_SONIC
		_state_timer = minf(pipop.sonic_cooldown * 0.45, 0.20)
		var am := AudioManagerService.get_am()
		if am:
			am.play_sfx("sonic_pulse")
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
	apply_screen_shake(3.0, 0.14)
	var am := AudioManagerService.get_am()
	if am:
		am.play_sfx("hurt")
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

func _update_sprite_visuals() -> void:
	if sprite == null:
		return
	var dir_str: String = direction_name(facing_direction)
	var is_moving: bool = (current_state == State.WALK or current_state == State.DASH) and velocity.length() > 8.0
	var anim_name: String = ("walk_" if is_moving else "idle_") + dir_str
	if current_state == State.DASH and sprite.sprite_frames and sprite.sprite_frames.has_animation("dash_" + dir_str):
		anim_name = "dash_" + dir_str
	elif current_state == State.ATTACK_PHYSICAL and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack_phys"):
		anim_name = "attack_phys"
	sprite.flip_h = current_state == State.ATTACK_PHYSICAL and facing_direction.x < -0.1
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)

	if current_state == State.DEAD:
		sprite.modulate = Color(0.45, 0.4, 0.55, 0.7)
	elif _hurt_flash_timer > 0.0 or current_state == State.HURT:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif current_state == State.DASH:
		sprite.modulate = Color(0.65, 0.95, 1.0, 0.88)
	elif current_state == State.ATTACK_PHYSICAL:
		sprite.modulate = Color(1.0, 0.92, 0.82, 1.0)
	elif current_state == State.ATTACK_SONIC:
		sprite.modulate = Color(0.85, 0.95, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _draw() -> void:
	# Feedback tático complementar ao redor do sprite de Pablita (rastro de dash, manopla ativa, anel direcional sutil)
	if current_state == State.DASH:
		var trail_pos: Vector2 = -dash_direction * 10.0 + Vector2(0, -12)
		draw_circle(trail_pos, 7.0, Color(0.55, 0.9, 1.0, 0.38))
		draw_circle(trail_pos - dash_direction * 6.0, 5.0, Color(0.55, 0.9, 1.0, 0.22))
	elif current_state == State.ATTACK_PHYSICAL:
		var fist_pos: Vector2 = Vector2(0, -12) + facing_direction.normalized() * 11.0
		draw_circle(fist_pos, 5.5, Color(0.98, 0.42, 0.68, 0.85))
		draw_arc(fist_pos, 6.5, 0.0, TAU, 14, Color(1.0, 0.88, 0.45, 0.95), 1.5)
	elif current_state == State.ATTACK_SONIC:
		draw_arc(Vector2(0, -12), 11.0, 0.0, TAU, 20, Color(0.55, 0.88, 1.0, 0.65), 1.5)


