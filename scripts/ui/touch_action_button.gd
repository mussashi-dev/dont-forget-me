class_name TouchActionButton
extends TextureButton
## Botão touch mobile com área de toque ampla, placeholder geométrico limpo,
## suporte a multi-touch sem comandos duplicados e consumo explícito de eventos para
## impedir que um toque em botão acione outra ação global.

@export var action_name: String = ""
@export var button_color: Color = Color(0.4, 0.2, 0.5, 0.8)
@export var pressed_color: Color = Color(0.95, 0.65, 0.8, 0.95)

var _active_touch_index: int = -1
var _is_action_active: bool = false

func _ready() -> void:
	texture_normal = null
	texture_pressed = null
	texture_hover = null
	custom_minimum_size = Vector2(80, 80)
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
	if action_name == "attack_physical":
		fill = pressed_color if _is_action_active else Color(0.72, 0.32, 0.52, 0.82)
	elif action_name == "attack_sonic":
		fill = pressed_color if _is_action_active else Color(0.42, 0.22, 0.56, 0.85)
	elif action_name == "dash":
		fill = pressed_color if _is_action_active else Color(0.32, 0.22, 0.44, 0.82)
	elif action_name == "interact":
		fill = pressed_color if _is_action_active else Color(0.55, 0.34, 0.62, 0.85)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 28, Color(0.92, 0.82, 0.96, 0.85), 2.0)


