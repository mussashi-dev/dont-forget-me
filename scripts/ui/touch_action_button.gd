class_name TouchActionButton
extends TextureButton
## Botão touch mobile com área de toque ampla, placeholder geométrico limpo,
## suporte a multi-touch sem comandos duplicados e consumo explícito de eventos para
## impedir que um toque em botão acione outra ação global.

@export var action_name: String = ""
@export var button_color: Color = Color(0.85, 0.3, 0.45, 0.78)
@export var pressed_color: Color = Color(1.0, 0.75, 0.35, 0.95)

var _active_touch_index: int = -1
var _is_action_active: bool = false

func _ready() -> void:
	texture_normal = null
	texture_pressed = null
	texture_hover = null
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not _is_action_active:
				_active_touch_index = st.index
				_press_action()
			accept_event()
		elif st.index == _active_touch_index:
			_release_action()
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _is_action_active:
					_press_action()
			else:
				if _is_action_active:
					_release_action()
			accept_event()

func _on_button_down() -> void:
	if not _is_action_active:
		_press_action()

func _on_button_up() -> void:
	if _is_action_active:
		_release_action()

func _press_action() -> void:
	if _is_action_active:
		return
	_is_action_active = true
	if not action_name.is_empty():
		Input.action_press(action_name)
	scale = Vector2(0.92, 0.92)
	queue_redraw()

func _release_action() -> void:
	if not _is_action_active:
		return
	_is_action_active = false
	_active_touch_index = -1
	if not action_name.is_empty():
		Input.action_release(action_name)
	scale = Vector2.ONE
	queue_redraw()

func _exit_tree() -> void:
	if _is_action_active and not action_name.is_empty():
		Input.action_release(action_name)
		_is_action_active = false

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	var fill: Color = pressed_color if _is_action_active else button_color
	if action_name == "attack_sonic":
		fill = pressed_color if _is_action_active else Color(0.15, 0.72, 0.95, 0.85)
	elif action_name == "dash":
		fill = pressed_color if _is_action_active else Color(0.45, 0.55, 0.92, 0.80)
	elif action_name == "interact":
		fill = pressed_color if _is_action_active else Color(0.25, 0.85, 0.45, 0.85)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 24, Color(1, 1, 1, 0.92), 2.0)


