class_name MobileVirtualJoystick
extends Control
## Joystick virtual para o lado esquerdo da tela.
## Suporta toque contínuo, parada imediata ao soltar e operação simultânea com botões de ataque.

@export var max_radius: float = 48.0
@export var deadzone: float = 0.15

var touch_index: int = -1
var is_active: bool = false
var joystick_vector: Vector2 = Vector2.ZERO

@onready var base_circle: Control = $Base
@onready var knob: Control = $Base/Knob

func _ready() -> void:
	_reset_knob()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if is_active:
			_release_joystick()
		return
	var gm := GameManagerService.get_gm()
	if gm != null and not gm.is_mobile_device:
		if is_active:
			_release_joystick()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Só captura toque no lado esquerdo da tela (abaixo do cabeçalho)
			var vp_size: Vector2 = get_viewport_rect().size
			if touch_index == -1 and touch.position.x < vp_size.x * 0.45 and touch.position.y > 64.0:
				touch_index = touch.index
				is_active = true
				_update_joystick(touch.position)
		elif touch.index == touch_index:
			_release_joystick()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_index:
			_update_joystick(drag.position)

func _update_joystick(screen_pos: Vector2) -> void:
	var base_global_center := base_circle.global_position + base_circle.size * 0.5
	var diff := screen_pos - base_global_center
	var dist := diff.length()

	if dist > max_radius:
		diff = diff.normalized() * max_radius

	knob.position = (base_circle.size * 0.5) + diff - (knob.size * 0.5)

	var normalized_dist := clampf(dist / max_radius, 0.0, 1.0)
	if normalized_dist < deadzone:
		joystick_vector = Vector2.ZERO
	else:
		joystick_vector = diff.normalized() * ((normalized_dist - deadzone) / (1.0 - deadzone))

	_inject_input_actions()

func _release_joystick() -> void:
	touch_index = -1
	is_active = false
	joystick_vector = Vector2.ZERO
	_reset_knob()
	_inject_input_actions()

func _exit_tree() -> void:
	if is_active:
		_release_joystick()

func _reset_knob() -> void:
	if knob and base_circle:
		knob.position = (base_circle.size * 0.5) - (knob.size * 0.5)

func _inject_input_actions() -> void:
	_set_action_strength("move_left", maxf(0.0, -joystick_vector.x))
	_set_action_strength("move_right", maxf(0.0, joystick_vector.x))
	_set_action_strength("move_up", maxf(0.0, -joystick_vector.y))
	_set_action_strength("move_down", maxf(0.0, joystick_vector.y))

func _set_action_strength(action: String, strength: float) -> void:
	if strength > 0.08:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)

