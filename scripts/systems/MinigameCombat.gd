class_name MinigameCombat
extends CanvasLayer
## Base de combate por minigame estilo Heartbound (Timing Bar / Reflexo Sônico).

enum MinigameType { TIMING_BAR, SONIC_REFLEX }

signal minigame_started(minigame_type: int)
signal minigame_completed(success: bool, result_data: Dictionary)
signal critical_hit_achieved(damage_multiplier: float)
signal normal_hit_achieved(damage_multiplier: float)
signal deflect_succeeded
signal minigame_failed

@export var minigame_type: MinigameType = MinigameType.TIMING_BAR
@export var target_action: StringName = &"attack_physical"
@export var marker_speed: float = 1.55
@export var green_zone_start: float = 0.36
@export var green_zone_end: float = 0.64
@export var timing_timeout: float = 2.6
@export var reflex_duration: float = 1.15
@export var reflex_window_start: float = 0.15
@export var reflex_window_end: float = 0.88

var is_active: bool = false
var is_resolved: bool = false
var marker_position: float = 0.0
var _marker_dir: float = 1.0
var _elapsed: float = 0.0
var _arm_timer: float = 0.06
var _cleanup_timer: float = -1.0

var panel: PanelContainer
var title_label: Label
var track_bg: ColorRect
var green_zone_rect: ColorRect
var marker_rect: ColorRect
var hint_label: Label

const TRACK_WIDTH: float = 220.0
const TRACK_HEIGHT: float = 14.0

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("minigame_combats")
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.name = "QTEPanel"
	panel.custom_minimum_size = Vector2(256, 68)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.68
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.68
	panel.offset_left = -128.0
	panel.offset_top = -34.0
	panel.offset_right = 128.0
	panel.offset_bottom = 34.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.14, 0.92)
	style.border_color = Color(0.86, 0.52, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.modulate = Color(0.96, 0.92, 1.0, 1.0)
	vbox.add_child(title_label)

	var track_holder := Control.new()
	track_holder.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT + 4.0)
	track_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(track_holder)

	track_bg = ColorRect.new()
	track_bg.position = Vector2(0, 2)
	track_bg.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	track_bg.color = Color(0.16, 0.12, 0.24, 1.0)
	track_holder.add_child(track_bg)

	green_zone_rect = ColorRect.new()
	green_zone_rect.color = Color(0.24, 0.88, 0.44, 0.9)
	track_bg.add_child(green_zone_rect)

	marker_rect = ColorRect.new()
	marker_rect.size = Vector2(6.0, TRACK_HEIGHT + 4.0)
	marker_rect.color = Color(1.0, 0.96, 0.65, 1.0)
	track_holder.add_child(marker_rect)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.modulate = Color(0.82, 0.94, 0.96, 0.95)
	vbox.add_child(hint_label)

	_sync_visuals()

func start_minigame(p_type: MinigameType, p_action: StringName = &"", p_title: String = "") -> void:
	minigame_type = p_type
	if p_action != &"":
		target_action = p_action
	elif p_type == MinigameType.SONIC_REFLEX:
		target_action = &"attack_sonic"
	else:
		target_action = &"attack_physical"

	is_active = true
	is_resolved = false
	_elapsed = 0.0
	_arm_timer = 0.06
	_cleanup_timer = -1.0
	marker_position = 0.0
	_marker_dir = 1.0

	if title_label:
		if p_title != "":
			title_label.text = p_title
		elif minigame_type == MinigameType.TIMING_BAR:
			title_label.text = "GOLPE DE CORDA! Acerte a zona verde"
		else:
			title_label.text = "ESPORO À VISTA! Rebata com SOM do Pipop"

	if hint_label:
		hint_label.text = "[ATAQUE] Crítico na zona verde" if minigame_type == MinigameType.TIMING_BAR else "[SOM] Quando entrar na zona de reflexo"

	_sync_visuals()
	minigame_started.emit(minigame_type)

func set_marker_position(norm_pos: float) -> void:
	marker_position = clampf(norm_pos, 0.0, 1.0)
	_sync_visuals()

func is_marker_in_green_zone() -> bool:
	if minigame_type == MinigameType.SONIC_REFLEX:
		return marker_position >= reflex_window_start and marker_position <= reflex_window_end
	return marker_position >= green_zone_start and marker_position <= green_zone_end

func _sync_visuals() -> void:
	if green_zone_rect == null or marker_rect == null:
		return
	var z_start: float = reflex_window_start if minigame_type == MinigameType.SONIC_REFLEX else green_zone_start
	var z_end: float = reflex_window_end if minigame_type == MinigameType.SONIC_REFLEX else green_zone_end
	green_zone_rect.position = Vector2(z_start * TRACK_WIDTH, 0.0)
	green_zone_rect.size = Vector2(maxf(4.0, (z_end - z_start) * TRACK_WIDTH), TRACK_HEIGHT)
	green_zone_rect.color = Color(0.75, 0.34, 0.98, 0.88) if minigame_type == MinigameType.SONIC_REFLEX else Color(0.24, 0.88, 0.44, 0.9)
	marker_rect.position = Vector2(clampf(marker_position, 0.0, 1.0) * (TRACK_WIDTH - marker_rect.size.x), 0.0)

func _process(delta: float) -> void:
	if _cleanup_timer > 0.0:
		_cleanup_timer -= delta
		if _cleanup_timer <= 0.0:
			queue_free()
		return

	if not is_active or is_resolved:
		return

	_elapsed += delta
	_arm_timer = maxf(0.0, _arm_timer - delta)

	if minigame_type == MinigameType.TIMING_BAR:
		marker_position += _marker_dir * marker_speed * delta
		if marker_position >= 1.0:
			marker_position = 1.0
			_marker_dir = -1.0
		elif marker_position <= 0.0:
			marker_position = 0.0
			_marker_dir = 1.0
	else:
		marker_position = clampf(_elapsed / maxf(0.1, reflex_duration), 0.0, 1.0)

	_sync_visuals()

	if _arm_timer <= 0.0 and Input.is_action_just_pressed(target_action):
		trigger_player_input()
		return

	if minigame_type == MinigameType.TIMING_BAR and _elapsed >= timing_timeout:
		_resolve(false, true)
	elif minigame_type == MinigameType.SONIC_REFLEX and _elapsed >= reflex_duration:
		_resolve(false, false)

func trigger_player_input() -> bool:
	if not is_active or is_resolved:
		return false
	var hit_zone: bool = is_marker_in_green_zone()
	_resolve(hit_zone, false)
	return hit_zone

func _resolve(in_zone: bool, timed_out: bool) -> void:
	if is_resolved:
		return
	is_resolved = true
	is_active = false

	if minigame_type == MinigameType.TIMING_BAR:
		if in_zone:
			if hint_label:
				hint_label.text = "CRÍTICO! Dano dobrado!"
				hint_label.modulate = Color(0.35, 1.0, 0.55, 1.0)
			critical_hit_achieved.emit(2.0)
			minigame_completed.emit(true, {"critical": true, "multiplier": 2.0, "timeout": timed_out})
		else:
			if hint_label:
				hint_label.text = "Dano normal." if not timed_out else "Tempo esgotado — dano normal."
				hint_label.modulate = Color(1.0, 0.85, 0.45, 1.0)
			normal_hit_achieved.emit(1.0)
			minigame_completed.emit(false, {"critical": false, "multiplier": 1.0, "timeout": timed_out})
	else:
		if in_zone:
			if hint_label:
				hint_label.text = "REBATIDO! Esporo devolvido!"
				hint_label.modulate = Color(0.85, 0.55, 1.0, 1.0)
			deflect_succeeded.emit()
			minigame_completed.emit(true, {"deflected": true, "timeout": timed_out})
		else:
			if hint_label:
				hint_label.text = "Tente no momento exato!"
				hint_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
			minigame_failed.emit()
			minigame_completed.emit(false, {"deflected": false, "timeout": timed_out})

	_cleanup_timer = 0.28
