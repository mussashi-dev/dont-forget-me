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
	# Desativar sprites originais e usar placeholder geométrico
	var spr: Node = get_node_or_null("Sprite")
	if spr and spr is CanvasItem:
		(spr as CanvasItem).visible = false
	var shadow: Node = get_node_or_null("Shadow")
	if shadow and shadow is CanvasItem:
		(shadow as CanvasItem).visible = false

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

func _draw() -> void:
	match current_state:
		State.FOLLOW, State.SONIC_RETURN:
			# Círculo magenta/rosa representando Pipop acompanhante
			draw_circle(Vector2.ZERO, 6.0, Color(0.95, 0.3, 0.65, 0.95))
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.95), 1.2)
		State.PHYSICAL:
			# Manopla envolvendo a mão de Pablita (retângulo/polígono laranja-avermelhado)
			var rect := Rect2(Vector2(-7, -7), Vector2(14, 14))
			draw_rect(rect, Color(1.0, 0.45, 0.2, 0.95), true)
			draw_rect(rect, Color(1.0, 0.9, 0.4, 1.0), false, 1.8)
		State.SONIC_APPROACH:
			# Pipop em deslocamento rápido (ciano/rosa brilhante)
			draw_circle(Vector2.ZERO, 6.5, Color(0.5, 0.9, 1.0, 0.95))
		State.SONIC_ATTACK:
			# Pipop à frente emitindo pulso sônico
			draw_circle(Vector2.ZERO, 7.5, Color(0.2, 0.95, 1.0, 1.0))
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color(0.6, 1.0, 1.0, 0.85), 2.0)

