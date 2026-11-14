class_name HUD
extends CanvasLayer
## Interface completa de Gameplay e Mobile:
## - Indicador de Vida e Capacidade dos Encartes
## - Joystick Virtual (esquerdo) e BotÃµes de AÃ§Ã£o Touch (direito: FÃ­sico, SÃ´nico, Dash, InteraÃ§Ã£o)
## - Caixa de DiÃ¡logo com avanÃ§o de texto e encerramento
## - Painel de Equipamento de Encartes com comparaÃ§Ã£o de atributos
## - Painel de Pausa (interrompendo a simulaÃ§Ã£o), Tela de Morte e Tela de VitÃ³ria/Encerramento
## - Barra de Vida de Chefe (quando aplicÃ¡vel)

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var capacity_slots_container: HBoxContainer = %CapacitySlotsContainer
@onready var prompt_container: PanelContainer = %PromptContainer
@onready var prompt_label: Label = %PromptLabel
@onready var dialogue_box: PanelContainer = %DialogueBox
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_text_label: Label = %DialogueTextLabel
@onready var interact_button: TouchActionButton = %InteractButton
@onready var pipop_icon: TextureRect = %PipopIcon

var current_dialogue_tween: Tween = null
var _dialogue_queue: Array[String] = []
var _current_speaker: String = ""
var _is_dialogue_open: bool = false

# NÃ³s criados programaticamente para Pausa, Encartes, Barra de Chefe e Estados Finais
var level_title_label: Label
var objective_label: Label
var debug_combat_label: Label
var boss_bar_panel: PanelContainer
var boss_name_label: Label
var boss_health_bar: ProgressBar

var top_right_bar: HBoxContainer
var btn_open_encartes: Button
var btn_toggle_pause: Button

var encartes_panel: PanelContainer
var encartes_capacity_label: Label
var encartes_list_vbox: VBoxContainer
var encartes_comparison_label: Label
var _selected_preview_id: String = ""

var pause_panel: PanelContainer
var state_overlay_panel: PanelContainer
var state_title_label: Label
var state_subtitle_label: Label
var state_btn_primary: Button
var state_btn_secondary: Button

var dialogue_next_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pipop_icon:
		pipop_icon.texture = null
		pipop_icon.custom_minimum_size = Vector2(22, 22)
		var ph := ColorRect.new()
		ph.color = Color(0.95, 0.3, 0.65, 1.0)
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		pipop_icon.add_child(ph)

	prompt_container.visible = false
	dialogue_box.visible = false
	if interact_button:
		interact_button.visible = false

	_build_dynamic_ui()
	_connect_player_and_managers()

func _connect_player_and_managers() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var pablita := players[0] as Pablita
		if not pablita.health_updated.is_connected(update_health):
			pablita.health_updated.connect(update_health)
		if not pablita.interaction_prompt_updated.is_connected(update_interaction_prompt):
			pablita.interaction_prompt_updated.connect(update_interaction_prompt)
		if not pablita.died.is_connected(_on_player_died):
			pablita.died.connect(_on_player_died)
		update_health(pablita.health_component.current_health, pablita.health_component.max_health)
		if pablita.pipop:
			if not pablita.pipop.capacity_changed.is_connected(update_pipop_capacity):
				pablita.pipop.capacity_changed.connect(update_pipop_capacity)
			if not pablita.pipop.debug_combat_updated.is_connected(update_debug_combat):
				pablita.pipop.debug_combat_updated.connect(update_debug_combat)
			update_pipop_capacity(pablita.pipop.current_used_slots, pablita.pipop.max_capacity_slots)
			pablita.pipop._emit_debug_info()

	if GameManagerService.get_gm():
		if not GameManagerService.get_gm().capacity_updated.is_connected(update_pipop_capacity):
			GameManagerService.get_gm().capacity_updated.connect(update_pipop_capacity)
		if not GameManagerService.get_gm().equipment_changed.is_connected(_refresh_encartes_ui):
			GameManagerService.get_gm().equipment_changed.connect(_refresh_encartes_ui)
		if not GameManagerService.get_gm().encarte_collected.is_connected(_on_encarte_collected):
			GameManagerService.get_gm().encarte_collected.connect(_on_encarte_collected)
		if not GameManagerService.get_gm().game_state_changed.is_connected(_on_game_state_changed):
			GameManagerService.get_gm().game_state_changed.connect(_on_game_state_changed)
		update_pipop_capacity(GameManagerService.get_gm().get_used_capacity(), GameManagerService.get_gm().max_capacity)
		var lvl_idx: int = GameManagerService.get_gm().current_level_index
		if level_title_label:
			level_title_label.text = GameManagerService.get_gm().LEVEL_TITLES.get(lvl_idx, "Fase %d" % lvl_idx)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if encartes_panel and encartes_panel.visible:
			_close_encartes_panel()
		else:
			_on_pause_button_pressed()
		get_viewport().set_input_as_handled()
	elif _is_dialogue_open and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		advance_dialogue()
		get_viewport().set_input_as_handled()

func _build_dynamic_ui() -> void:
	var root_ctrl: Control = $RootControl

	# Ajustar tamanho mÃ­nimo dos botÃµes touch existentes para facilitar toque mobile
	var touch_ctrl: Control = root_ctrl.get_node_or_null("TouchControls")
	if touch_ctrl:
		var phys_btn: Control = touch_ctrl.get_node_or_null("PhysicalAttackBtn")
		if phys_btn:
			phys_btn.offset_left = -68.0
			phys_btn.offset_top = -68.0
			phys_btn.offset_right = -4.0
			phys_btn.offset_bottom = -4.0
		var sonic_btn: Control = touch_ctrl.get_node_or_null("SonicAttackBtn")
		if sonic_btn:
			sonic_btn.offset_left = -136.0
			sonic_btn.offset_top = -60.0
			sonic_btn.offset_right = -78.0
			sonic_btn.offset_bottom = -2.0
		var dash_btn: Control = touch_ctrl.get_node_or_null("DashBtn")
		if dash_btn:
			dash_btn.offset_left = -64.0
			dash_btn.offset_top = -132.0
			dash_btn.offset_right = -8.0
			dash_btn.offset_bottom = -76.0
		var act_btn: Control = touch_ctrl.get_node_or_null("InteractButton")
		if act_btn:
			act_btn.offset_left = -136.0
			act_btn.offset_top = -126.0
			act_btn.offset_right = -78.0
			act_btn.offset_bottom = -68.0

	# RÃ³tulo da fase atual no topo
	level_title_label = Label.new()
	level_title_label.text = "Fase 1"
	level_title_label.add_theme_font_size_override("font_size", 10)
	level_title_label.modulate = Color(0.85, 0.85, 0.95, 0.9)
	level_title_label.position = Vector2(14, 62)
	root_ctrl.add_child(level_title_label)

	objective_label = Label.new()
	objective_label.text = "Objetivo: Explorar"
	objective_label.add_theme_font_size_override("font_size", 9)
	objective_label.modulate = Color(0.75, 0.95, 0.85, 0.95)
	objective_label.position = Vector2(14, 76)
	root_ctrl.add_child(objective_label)

	debug_combat_label = Label.new()
	debug_combat_label.name = "DebugCombatLabel"
	debug_combat_label.add_theme_font_size_override("font_size", 8)
	debug_combat_label.modulate = Color(0.85, 0.92, 1.0, 0.88)
	debug_combat_label.position = Vector2(14, 92)
	debug_combat_label.text = "[DEBUG COMBATE]\nCmd: NENHUM | Hab: NENHUMA\nPipop: FOLLOW | Hitbox: NENHUMA\nAlvo: NENHUM | Dano: 0"
	root_ctrl.add_child(debug_combat_label)

	# Barra superior direita: BotÃµes de ENCARTES e PAUSA (acessÃ­veis por toque)
	top_right_bar = HBoxContainer.new()
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_bar.offset_left = -190.0
	top_right_bar.offset_top = 10.0
	top_right_bar.offset_right = -12.0
	top_right_bar.offset_bottom = 42.0
	top_right_bar.alignment = BoxContainer.ALIGNMENT_END
	top_right_bar.add_theme_constant_override("separation", 8)
	root_ctrl.add_child(top_right_bar)

	btn_open_encartes = Button.new()
	btn_open_encartes.text = "ENCARTES"
	btn_open_encartes.custom_minimum_size = Vector2(88, 30)
	btn_open_encartes.add_theme_font_size_override("font_size", 10)
	btn_open_encartes.pressed.connect(_toggle_encartes_panel)
	top_right_bar.add_child(btn_open_encartes)

	btn_toggle_pause = Button.new()
	btn_toggle_pause.text = "PAUSA"
	btn_toggle_pause.custom_minimum_size = Vector2(72, 30)
	btn_toggle_pause.add_theme_font_size_override("font_size", 10)
	btn_toggle_pause.pressed.connect(_on_pause_button_pressed)
	top_right_bar.add_child(btn_toggle_pause)

	# Barra de vida do Chefe (topo central)
	boss_bar_panel = PanelContainer.new()
	boss_bar_panel.visible = false
	boss_bar_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar_panel.offset_left = -120.0
	boss_bar_panel.offset_top = 42.0
	boss_bar_panel.offset_right = 120.0
	boss_bar_panel.offset_bottom = 78.0
	var boss_vbox := VBoxContainer.new()
	boss_bar_panel.add_child(boss_vbox)
	boss_name_label = Label.new()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 10)
	boss_vbox.add_child(boss_name_label)
	boss_health_bar = ProgressBar.new()
	boss_health_bar.custom_minimum_size = Vector2(220, 12)
	boss_health_bar.show_percentage = false
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.9, 0.22, 0.3, 1.0)
	boss_health_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_vbox.add_child(boss_health_bar)
	root_ctrl.add_child(boss_bar_panel)

	# BotÃ£o de avanÃ§ar/fechar diÃ¡logo dentro da DialogueBox
	var dlg_vbox: Node = dialogue_box.get_node_or_null("Margin/VBox")
	if dlg_vbox:
		dialogue_next_btn = Button.new()
		dialogue_next_btn.text = "AvanÃ§ar / Fechar [AÃ‡ÃƒO]"
		dialogue_next_btn.custom_minimum_size = Vector2(140, 24)
		dialogue_next_btn.add_theme_font_size_override("font_size", 10)
		dialogue_next_btn.pressed.connect(advance_dialogue)
		dlg_vbox.add_child(dialogue_next_btn)

	_build_encartes_modal(root_ctrl)
	_build_pause_modal(root_ctrl)
	_build_state_overlay_modal(root_ctrl)

func _build_encartes_modal(parent: Control) -> void:
	encartes_panel = PanelContainer.new()
	encartes_panel.visible = false
	encartes_panel.set_anchors_preset(Control.PRESET_CENTER)
	encartes_panel.offset_left = -260.0
	encartes_panel.offset_top = -150.0
	encartes_panel.offset_right = 260.0
	encartes_panel.offset_bottom = 150.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.96)
	style.border_color = Color(0.85, 0.4, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	encartes_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	encartes_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var header := HBoxContainer.new()
	main_vbox.add_child(header)
	var title := Label.new()
	title.text = "EQUIPAMENTO DE ENCARTES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	header.add_child(title)

	encartes_capacity_label = Label.new()
	encartes_capacity_label.text = "Capacidade: 0 / 4"
	encartes_capacity_label.add_theme_font_size_override("font_size", 11)
	header.add_child(encartes_capacity_label)

	var close_btn := Button.new()
	close_btn.text = "Fechar [X]"
	close_btn.custom_minimum_size = Vector2(70, 24)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(_close_encartes_panel)
	header.add_child(close_btn)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	encartes_list_vbox = VBoxContainer.new()
	encartes_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encartes_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(encartes_list_vbox)

	encartes_comparison_label = Label.new()
	encartes_comparison_label.custom_minimum_size = Vector2(210, 0)
	encartes_comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encartes_comparison_label.add_theme_font_size_override("font_size", 9)
	encartes_comparison_label.text = "Selecione um encarte para comparar a configuraÃ§Ã£o atual com a nova."
	split.add_child(encartes_comparison_label)

	parent.add_child(encartes_panel)

func _build_pause_modal(parent: Control) -> void:
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -130.0
	pause_panel.offset_top = -105.0
	pause_panel.offset_right = 130.0
	pause_panel.offset_bottom = 105.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_color = Color(0.5, 0.75, 1.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	pause_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	pause_panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "JOGO PAUSADO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl)

	var btn_resume := Button.new()
	btn_resume.text = "Retomar Partida"
	btn_resume.custom_minimum_size = Vector2(180, 28)
	btn_resume.pressed.connect(func():
		pause_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().resume_game()
		else:
			get_tree().paused = false
	)
	vbox.add_child(btn_resume)

	var btn_encartes := Button.new()
	btn_encartes.text = "Gerenciar Encartes"
	btn_encartes.custom_minimum_size = Vector2(180, 28)
	btn_encartes.pressed.connect(func():
		pause_panel.visible = false
		_open_encartes_panel()
	)
	vbox.add_child(btn_encartes)

	var btn_restart := Button.new()
	btn_restart.text = "Reiniciar Fase"
	btn_restart.custom_minimum_size = Vector2(180, 28)
	btn_restart.pressed.connect(func():
		pause_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().restart_current_level()
		else:
			get_tree().paused = false
			get_tree().reload_current_scene()
	)
	vbox.add_child(btn_restart)

	var btn_menu := Button.new()
	btn_menu.text = "Menu Inicial"
	btn_menu.custom_minimum_size = Vector2(180, 28)
	btn_menu.pressed.connect(func():
		pause_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().return_to_main_menu()
	)
	vbox.add_child(btn_menu)

	parent.add_child(pause_panel)

func _build_state_overlay_modal(parent: Control) -> void:
	state_overlay_panel = PanelContainer.new()
	state_overlay_panel.visible = false
	state_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	state_overlay_panel.offset_left = -180.0
	state_overlay_panel.offset_top = -95.0
	state_overlay_panel.offset_right = 180.0
	state_overlay_panel.offset_bottom = 95.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.12, 0.96)
	style.border_color = Color(0.95, 0.8, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	state_overlay_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	state_overlay_panel.add_child(vbox)

	state_title_label = Label.new()
	state_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(state_title_label)

	state_subtitle_label = Label.new()
	state_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_subtitle_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(state_subtitle_label)

	state_btn_primary = Button.new()
	state_btn_primary.custom_minimum_size = Vector2(200, 30)
	vbox.add_child(state_btn_primary)

	state_btn_secondary = Button.new()
	state_btn_secondary.custom_minimum_size = Vector2(200, 28)
	vbox.add_child(state_btn_secondary)

	parent.add_child(state_overlay_panel)

# ---------- AtualizaÃ§Ã£o de Indicadores ----------

func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "Vida: %d / %d" % [current, maximum]

func set_objective_text(text: String) -> void:
	if objective_label:
		objective_label.text = "Objetivo: %s" % text

func update_debug_combat(info: Dictionary) -> void:
	if not debug_combat_label:
		return
	debug_combat_label.text = (
		"[DEBUG COMBATE]\n" +
		"Cmd: %s | Hab: %s\n" +
		"Pipop: %s | Hitbox: %s\n" +
		"Alvo: %s | Dano: %d"
	) % [
		String(info.get("command", "NENHUM")),
		String(info.get("ability", "NENHUMA")),
		String(info.get("pipop_state", "FOLLOW")),
		String(info.get("active_hitbox", "NENHUMA")),
		String(info.get("last_target", "NENHUM")),
		int(info.get("last_damage", 0))
	]

func update_pipop_capacity(used_slots: int, total_slots: int) -> void:
	for child in capacity_slots_container.get_children():
		child.queue_free()

	for i in range(total_slots):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(14, 14)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		if i < used_slots:
			style.bg_color = Color(0.92, 0.25, 0.55)
			style.border_color = Color(1.0, 0.7, 0.85)
		else:
			style.bg_color = Color(0.2, 0.16, 0.24, 0.7)
			style.border_color = Color(0.4, 0.35, 0.45)
		style.set_border_width_all(1)
		slot_panel.add_theme_stylebox_override("panel", style)
		capacity_slots_container.add_child(slot_panel)

func show_boss_health(boss_name: String, current: int, maximum: int) -> void:
	if not boss_bar_panel:
		return
	boss_bar_panel.visible = current > 0
	boss_name_label.text = boss_name
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current

func hide_boss_health() -> void:
	if boss_bar_panel:
		boss_bar_panel.visible = false

func update_interaction_prompt(prompt_text: String, is_visible: bool) -> void:
	prompt_label.text = prompt_text
	prompt_container.visible = is_visible
	if interact_button:
		interact_button.visible = is_visible or _is_dialogue_open

# ---------- DiÃ¡logos ----------

func show_dialogue(speaker: String, text: String) -> void:
	show_dialogue_sequence(speaker, [text])

func show_dialogue_sequence(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_current_speaker = speaker
	_dialogue_queue = lines.duplicate()
	_is_dialogue_open = true
	if interact_button:
		interact_button.visible = true
	_display_next_dialogue_line()

func _display_next_dialogue_line() -> void:
	if _dialogue_queue.is_empty():
		hide_dialogue()
		return
	var next_line: String = _dialogue_queue.pop_front()
	speaker_label.text = _current_speaker
	dialogue_box.visible = true
	if current_dialogue_tween:
		current_dialogue_tween.kill()
	dialogue_text_label.visible_characters = -1
	dialogue_text_label.text = next_line
	if dialogue_next_btn:
		dialogue_next_btn.text = "Continuar (%d)" % _dialogue_queue.size() if not _dialogue_queue.is_empty() else "Fechar [AÃ‡ÃƒO]"

func advance_dialogue() -> void:
	if not _is_dialogue_open:
		return
	if _dialogue_queue.is_empty():
		hide_dialogue()
	else:
		_display_next_dialogue_line()

func hide_dialogue() -> void:
	_is_dialogue_open = false
	_dialogue_queue.clear()
	dialogue_box.visible = false
	if interact_button:
		interact_button.visible = prompt_container.visible

# ---------- Encartes e ComparaÃ§Ã£o ----------

func _toggle_encartes_panel() -> void:
	if encartes_panel.visible:
		_close_encartes_panel()
	else:
		_open_encartes_panel()

func _open_encartes_panel() -> void:
	if GameManagerService.get_gm() and GameManagerService.get_gm().current_state == GameManagerService.get_gm().GameState.PLAYING:
		get_tree().paused = true
	pause_panel.visible = false
	encartes_panel.visible = true
	_refresh_encartes_ui()

func _close_encartes_panel() -> void:
	encartes_panel.visible = false
	if GameManagerService.get_gm() and GameManagerService.get_gm().current_state == GameManagerService.get_gm().GameState.PLAYING:
		get_tree().paused = false

func _on_encarte_collected(encarte_id: String) -> void:
	if GameManagerService.get_gm() and GameManagerService.get_gm().catalog.has(encarte_id):
		var data: EncarteData = GameManagerService.get_gm().catalog[encarte_id]
		show_dialogue("Encarte Coletado", "%s (Custo: %d)\nBenefÃ­cio: %s\nLimitaÃ§Ã£o: %s" % [
			data.title, data.capacity_cost, data.benefit_text, data.limitation_text
		])
	_refresh_encartes_ui()

func _refresh_encartes_ui() -> void:
	if not encartes_panel or not GameManagerService.get_gm():
		return
	encartes_capacity_label.text = "Capacidade: %d / %d (Livre: %d)" % [
		GameManagerService.get_gm().get_used_capacity(),
		GameManagerService.get_gm().max_capacity,
		GameManagerService.get_gm().get_available_capacity()
	]
	for child in encartes_list_vbox.get_children():
		child.queue_free()

	if GameManagerService.get_gm().collected_encartes.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum encarte coletado ainda.\nExplore as fases para encontrar encartes."
		empty_lbl.add_theme_font_size_override("font_size", 10)
		encartes_list_vbox.add_child(empty_lbl)
		_update_comparison_view("")
		return

	for id: String in GameManagerService.get_gm().collected_encartes:
		if not GameManagerService.get_gm().catalog.has(id):
			continue
		var data: EncarteData = GameManagerService.get_gm().catalog[id]
		var equipped: bool = GameManagerService.get_gm().is_equipped(id)
		var can_eq: bool = GameManagerService.get_gm().can_equip(id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var info_btn := Button.new()
		info_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_btn.add_theme_font_size_override("font_size", 10)
		var status_prefix: String = "[EQUIPADO] " if equipped else ""
		info_btn.text = "%s%s (%s | Custo %d)" % [
			status_prefix,
			data.title,
			EncarteData.category_to_string(data.category),
			data.capacity_cost
		]
		info_btn.pressed.connect(func():
			_selected_preview_id = id
			_update_comparison_view(id)
		)
		row.add_child(info_btn)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(78, 24)
		action_btn.add_theme_font_size_override("font_size", 9)
		if equipped:
			action_btn.text = "Desequipar"
			action_btn.pressed.connect(func():
				GameManagerService.get_gm().unequip_encarte(id)
				_selected_preview_id = id
				_refresh_encartes_ui()
			)
		else:
			action_btn.text = "Equipar"
			action_btn.disabled = not can_eq
			action_btn.pressed.connect(func():
				GameManagerService.get_gm().equip_encarte(id)
				_selected_preview_id = id
				_refresh_encartes_ui()
			)
		row.add_child(action_btn)
		encartes_list_vbox.add_child(row)

	if _selected_preview_id == "" and not GameManagerService.get_gm().collected_encartes.is_empty():
		_selected_preview_id = GameManagerService.get_gm().collected_encartes[0]
	_update_comparison_view(_selected_preview_id)

func _update_comparison_view(candidate_id: String) -> void:
	if not GameManagerService.get_gm() or candidate_id == "" or not GameManagerService.get_gm().catalog.has(candidate_id):
		encartes_comparison_label.text = "Selecione um encarte na lista para comparar os atributos atuais com a nova configuraÃ§Ã£o."
		return

	var data: EncarteData = GameManagerService.get_gm().catalog[candidate_id]
	var cur_mods: Dictionary = GameManagerService.get_gm().get_active_modifiers()
	var sim_mods: Dictionary = GameManagerService.get_gm().preview_modifiers_with_toggle(candidate_id)
	var is_eq: bool = GameManagerService.get_gm().is_equipped(candidate_id)
	var action_label: String = "Ao Desequipar" if is_eq else "Ao Equipar"

	var cur_phys_dmg: int = int(round(35.0 * float(cur_mods["physical_damage_mult"])))
	var new_phys_dmg: int = int(round(35.0 * float(sim_mods["physical_damage_mult"])))

	var cur_phys_cd: float = 0.28 * float(cur_mods["physical_cooldown_mult"])
	var new_phys_cd: float = 0.28 * float(sim_mods["physical_cooldown_mult"])

	var cur_sonic_dmg: int = int(round(30.0 * float(cur_mods["sonic_damage_mult"])))
	var new_sonic_dmg: int = int(round(30.0 * float(sim_mods["sonic_damage_mult"])))

	var cur_spd: int = int(round(95.0 * float(cur_mods["move_speed_mult"])))
	var new_spd: int = int(round(95.0 * float(sim_mods["move_speed_mult"])))

	var cur_hp: int = 100 + int(cur_mods["max_health_bonus"])
	var new_hp: int = 100 + int(sim_mods["max_health_bonus"])

	var cur_def: int = int(round(float(cur_mods["damage_taken_mult"]) * 100.0))
	var new_def: int = int(round(float(sim_mods["damage_taken_mult"]) * 100.0))

	encartes_comparison_label.text = (
		"[%s] (Custo: %d)\n" +
		"+ %s\n- %s\n\n" +
		"COMPARAÃ‡ÃƒO (Atual -> %s):\n" +
		"â€¢ Dano FÃ­sico: %d -> %d\n" +
		"â€¢ Recarga FÃ­sica: %.2fs -> %.2fs\n" +
		"â€¢ Dano SÃ´nico: %d -> %d\n" +
		"â€¢ Velocidade: %d -> %d\n" +
		"â€¢ Vida MÃ¡x: %d -> %d\n" +
		"â€¢ Dano Recebido: %d%% -> %d%%"
	) % [
		data.title, data.capacity_cost,
		data.benefit_text, data.limitation_text,
		action_label,
		cur_phys_dmg, new_phys_dmg,
		cur_phys_cd, new_phys_cd,
		cur_sonic_dmg, new_sonic_dmg,
		cur_spd, new_spd,
		cur_hp, new_hp,
		cur_def, new_def
	]

# ---------- Pausa e Estados de Jogo ----------

func _on_pause_button_pressed() -> void:
	if not GameManagerService.get_gm():
		get_tree().paused = not get_tree().paused
		pause_panel.visible = get_tree().paused
		return
	if GameManagerService.get_gm().current_state == GameManagerService.get_gm().GameState.PLAYING:
		GameManagerService.get_gm().pause_game()
	elif GameManagerService.get_gm().current_state == GameManagerService.get_gm().GameState.PAUSED:
		GameManagerService.get_gm().resume_game()

func _on_player_died() -> void:
	if GameManagerService.get_gm():
		GameManagerService.get_gm().set_game_state(GameManagerService.get_gm().GameState.DEAD)
	_show_death_overlay()

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManagerService.get_gm().GameState.PAUSED:
		pause_panel.visible = true
	elif new_state == GameManagerService.get_gm().GameState.PLAYING:
		pause_panel.visible = false
		state_overlay_panel.visible = false
	elif new_state == GameManagerService.get_gm().GameState.DEAD:
		_show_death_overlay()
	elif new_state == GameManagerService.get_gm().GameState.CAMPAIGN_COMPLETE:
		_show_campaign_complete_overlay()

func _show_death_overlay() -> void:
	pause_panel.visible = false
	encartes_panel.visible = false
	state_overlay_panel.visible = true
	state_title_label.text = "VOCÃŠ FOI ESQUECIDA"
	state_subtitle_label.text = "Sua presenÃ§a se dissipou nesta sala. Reinicie a fase para tentar novamente."
	_clear_button_connections(state_btn_primary)
	_clear_button_connections(state_btn_secondary)
	state_btn_primary.text = "Reiniciar Fase Agora"
	state_btn_primary.visible = true
	state_btn_primary.pressed.connect(func():
		state_overlay_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().restart_current_level()
		else:
			get_tree().reload_current_scene()
	)
	state_btn_secondary.text = "Voltar ao Menu Inicial"
	state_btn_secondary.visible = true
	state_btn_secondary.pressed.connect(func():
		state_overlay_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().return_to_main_menu()
	)

func show_level_victory_overlay(title_msg: String, subtitle_msg: String) -> void:
	pause_panel.visible = false
	encartes_panel.visible = false
	state_overlay_panel.visible = true
	state_title_label.text = title_msg
	state_subtitle_label.text = subtitle_msg
	_clear_button_connections(state_btn_primary)
	_clear_button_connections(state_btn_secondary)
	state_btn_primary.text = "AvanÃ§ar para PrÃ³xima Fase"
	state_btn_primary.visible = true
	state_btn_primary.pressed.connect(func():
		state_overlay_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().advance_to_next_level()
	)
	state_btn_secondary.visible = false

func _show_campaign_complete_overlay() -> void:
	pause_panel.visible = false
	encartes_panel.visible = false
	state_overlay_panel.visible = true
	state_title_label.text = "CAMPANHA CONCLUÃDA!"
	state_subtitle_label.text = "VocÃª derrotou A Rainha Empoeirada e atravessou todas as 10 fases do Esquecido!"
	_clear_button_connections(state_btn_primary)
	_clear_button_connections(state_btn_secondary)
	state_btn_primary.text = "Jogar Novamente (Fase 1)"
	state_btn_primary.visible = true
	state_btn_primary.pressed.connect(func():
		state_overlay_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().start_new_game()
	)
	state_btn_secondary.text = "Voltar ao Menu Inicial"
	state_btn_secondary.visible = true
	state_btn_secondary.pressed.connect(func():
		state_overlay_panel.visible = false
		if GameManagerService.get_gm():
			GameManagerService.get_gm().return_to_main_menu()
	)

func _clear_button_connections(btn: Button) -> void:
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])


