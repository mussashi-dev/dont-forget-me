class_name PipopCompanion
extends CharacterBody2D
## Pipop: Fuggler único que acompanha Pablita e assume duas manifestações de combate.
## Estados explícitos: FOLLOW, PHYSICAL, SONIC_APPROACH, SONIC_ATTACK, SONIC_RETURN.
## Representação visual: Placeholder geométrico (sem sprites).

signal state_changed(new_state: State)
signal sonic_pulse_emitted(front_global_pos: Vector2, direction: Vector2)

enum State {
	FOLLOW,
	PHYSICAL,
	SONIC_APPROACH,
	SONIC_ATTACK,
	SONIC_RETURN
}

@export var target_follow: Node2D
@export var follow_distance: float = 18.0
@export var follow_lerp_speed: float = 12.0
@export var front_attack_distance: float = 16.0
@export var gauntlet_distance: float = 10.0

@export var sonic_approach_duration: float = 0.06
@export var sonic_attack_hold_duration: float = 0.14
@export var sonic_return_duration: float = 0.12

var current_state: State = State.FOLLOW
var state_timer: float = 0.0
var attack_direction: Vector2 = Vector2.DOWN
var _start_offset: Vector2 = Vector2.ZERO
var _current_local_offset: Vector2 = Vector2(0, 18)

func _ready() -> void:
	var spr: Node = get_node_or_null("Sprite")
	if spr and spr is AnimatedSprite2D:
		(spr as AnimatedSprite2D).visible = true
		(spr as AnimatedSprite2D).play("idle_south")
	var shadow: Node = get_node_or_null("Shadow")
	if shadow and shadow is CanvasItem:
		(shadow as CanvasItem).visible = true

	collision_layer = 0
	collision_mask = 0
	top_level = false
	_current_local_offset = Vector2(0, follow_distance)
	position = _current_local_offset
	queue_redraw()

func _physics_process(delta: float) -> void:
	if target_follow == null:
		target_follow = get_parent() as Node2D
		if target_follow == null:
			return

	var pablita_dir: Vector2 = Vector2.DOWN
	if "facing_direction" in target_follow:
		var fd: Vector2 = target_follow.get("facing_direction")
		if fd != Vector2.ZERO:
			pablita_dir = fd.normalized()

	var desired_follow_offset: Vector2 = -pablita_dir * follow_distance + Vector2(0, -6)

	match current_state:
		State.FOLLOW:
			_current_local_offset = _current_local_offset.lerp(desired_follow_offset, clampf(follow_lerp_speed * delta, 0.0, 1.0))
			position = _current_local_offset

		State.PHYSICAL:
			state_timer -= delta
			var gauntlet_offset: Vector2 = attack_direction * gauntlet_distance + Vector2(0, -10)
			_current_local_offset = _current_local_offset.lerp(gauntlet_offset, clampf(28.0 * delta, 0.0, 1.0))
			position = _current_local_offset
			if state_timer <= 0.0:
				_transition_to(State.FOLLOW)

		State.SONIC_APPROACH:
			state_timer -= delta
			var t: float = 1.0 - clampf(state_timer / maxf(sonic_approach_duration, 0.01), 0.0, 1.0)
			# Arco rápido ao redor de Pablita até a frente
			var front_offset: Vector2 = attack_direction * front_attack_distance + Vector2(0, -10)
			var side_normal: Vector2 = Vector2(-attack_direction.y, attack_direction.x)
			var arc_boost: Vector2 = side_normal * sin(t * PI) * 10.0
			_current_local_offset = _start_offset.lerp(front_offset, t) + arc_boost
			position = _current_local_offset
			if state_timer <= 0.0:
				_current_local_offset = front_offset
				position = _current_local_offset
				_transition_to(State.SONIC_ATTACK)
				sonic_pulse_emitted.emit(global_position, attack_direction)

		State.SONIC_ATTACK:
			state_timer -= delta
			var front_offset: Vector2 = attack_direction * front_attack_distance + Vector2(0, -10)
			_current_local_offset = front_offset
			position = _current_local_offset
			if state_timer <= 0.0:
				_start_offset = _current_local_offset
				_transition_to(State.SONIC_RETURN)

		State.SONIC_RETURN:
			state_timer -= delta
			var t: float = 1.0 - clampf(state_timer / maxf(sonic_return_duration, 0.01), 0.0, 1.0)
			_current_local_offset = _start_offset.lerp(desired_follow_offset, t)
			position = _current_local_offset
			if state_timer <= 0.0:
				_transition_to(State.FOLLOW)

	_update_sprite_animation(pablita_dir)
	queue_redraw()

func can_start_action() -> bool:
	return current_state == State.FOLLOW or current_state == State.SONIC_RETURN

func enter_physical_state(dir: Vector2, duration: float) -> bool:
	if current_state == State.SONIC_APPROACH or current_state == State.SONIC_ATTACK:
		return false
	attack_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	state_timer = maxf(duration, 0.12)
	_transition_to(State.PHYSICAL)
	return true

func enter_sonic_sequence(dir: Vector2) -> bool:
	if current_state != State.FOLLOW and current_state != State.SONIC_RETURN:
		return false
	attack_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_start_offset = _current_local_offset
	state_timer = sonic_approach_duration
	_transition_to(State.SONIC_APPROACH)
	return true

func force_reset_to_follow() -> void:
	_transition_to(State.FOLLOW)

func react_to_attack() -> void:
	queue_redraw()

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.SONIC_ATTACK:
			state_timer = sonic_attack_hold_duration
		State.SONIC_RETURN:
			state_timer = sonic_return_duration
	state_changed.emit(current_state)
	queue_redraw()

func _update_sprite_animation(pablita_dir: Vector2) -> void:
	var spr: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D
	var shadow: CanvasItem = get_node_or_null("Shadow") as CanvasItem
	if spr == null:
		return
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if current_state == State.PHYSICAL:
		# Na forma de manopla, o corpo acompanhante se acopla ao braço de Pablita
		spr.visible = false
		if shadow:
			shadow.visible = false
		return
	spr.visible = true
	if shadow:
		shadow.visible = true
	var look_dir: Vector2 = attack_direction if (current_state == State.SONIC_APPROACH or current_state == State.SONIC_ATTACK) else pablita_dir
	var dir_str: String = Pablita.direction_name(look_dir)
	var is_moving: bool = false
	if target_follow and "velocity" in target_follow:
		var v: Vector2 = target_follow.get("velocity")
		is_moving = v.length() > 10.0
	if current_state == State.SONIC_APPROACH or current_state == State.SONIC_RETURN:
		is_moving = true

	var anim_name: String = ("walk_" if is_moving else "idle_") + dir_str
	if (current_state == State.SONIC_APPROACH or current_state == State.SONIC_ATTACK) and spr.sprite_frames and spr.sprite_frames.has_animation("sonic_roar"):
		anim_name = "sonic_roar"
		spr.flip_h = look_dir.x < -0.1
	else:
		spr.flip_h = false

	if spr.sprite_frames and spr.sprite_frames.has_animation(anim_name):
		if spr.animation != anim_name or not spr.is_playing():
			spr.play(anim_name)

func _draw() -> void:
	match current_state:
		State.FOLLOW, State.SONIC_RETURN:
			# Halo sutil rosado de Pipop e coração costurado
			draw_arc(Vector2(0, -8), 7.5, 0.0, TAU, 16, Color(1.0, 0.55, 0.85, 0.35), 1.2)
		State.PHYSICAL:
			# Manopla felpuda rosa de Pipop com o coração quebrado remendado
			var rect := Rect2(Vector2(-7, -7), Vector2(14, 14))
			draw_rect(rect, Color(0.95, 0.28, 0.62, 0.96), true)
			draw_rect(rect, Color(1.0, 0.65, 0.85, 0.95), false, 1.8)
			draw_circle(Vector2(0, 0), 3.4, Color(0.96, 0.22, 0.55, 1.0))
			# Rachadura preta + curativo cinza costurado
			draw_line(Vector2(-1, -3), Vector2(1, 3), Color(0.12, 0.06, 0.14, 1.0), 1.3)
			draw_rect(Rect2(Vector2(-2.5, -1.0), Vector2(5.0, 2.2)), Color(0.76, 0.78, 0.84, 0.95), true)
		State.SONIC_APPROACH:
			draw_arc(Vector2(0, -8), 9.0, 0.0, TAU, 18, Color(0.96, 0.42, 0.78, 0.75), 1.8)
		State.SONIC_ATTACK:
			# Anéis concêntricos de grunhido sônico (roxo e rosa conforme Bíblia 3.2)
			draw_arc(Vector2(0, -8), 10.5, 0.0, TAU, 22, Color(0.72, 0.30, 1.0, 0.95), 2.2)
			draw_arc(Vector2(0, -8), 15.0, 0.0, TAU, 24, Color(0.98, 0.38, 0.75, 0.85), 1.8)
			draw_arc(Vector2(0, -8), 19.5, 0.0, TAU, 24, Color(0.58, 0.20, 0.88, 0.55), 1.3)


