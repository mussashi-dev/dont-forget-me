class_name MainMenu
extends Control
## Menu Inicial de DON'T FORGET ME.
## Apresenta Novo Jogo (com confirmação se já houver save), Continuar, Comandos/Controles,
## e Rever Chefes (desbloqueado após concluir a campanha). Seleção livre de fases restrita a F3 (Debug).

var continue_btn: Button
var boss_rush_box: VBoxContainer
var debug_level_box: VBoxContainer
var level_select_container: HFlowContainer
var confirm_new_game_modal: PanelContainer
var controls_modal: PanelContainer

func _ready() -> void:
	get_tree().paused = false
	var gm := GameManagerService.get_gm()
	if gm:
		gm.set_game_state(GameManagerService.GameState.MENU)
		gm.load_game()
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if debug_level_box:
			debug_level_box.visible = not debug_level_box.visible
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 290)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.10, 0.19, 0.96)
	style.border_color = Color(0.85, 0.4, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DON'T FORGET ME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "O Que Cai Atrás do Guarda-Roupa Nunca Desaparece por Completo"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.modulate = Color(0.85, 0.80, 0.95, 0.92)
	vbox.add_child(sub)

	var gm := GameManagerService.get_gm()
	var has_save: bool = gm != null and gm.has_save_file()

	var btn_new := Button.new()
	btn_new.name = "StartNewGameButton"
	btn_new.text = "Novo Jogo"
	btn_new.custom_minimum_size = Vector2(240, 32)
	_apply_menu_button_theme(btn_new, true)
	btn_new.pressed.connect(_on_start_new_pressed)
	vbox.add_child(btn_new)

	continue_btn = Button.new()
	continue_btn.name = "ContinueGameButton"
	var saved_lvl: int = gm.current_level_index if gm else 1
	var saved_title: String = gm.LEVEL_TITLES.get(saved_lvl, "Capítulo %d" % saved_lvl) if gm else "Início"
	continue_btn.text = "Continuar — %s" % saved_title if has_save else "Continuar (Sem Jogo Salvo)"
	continue_btn.disabled = not has_save
	continue_btn.custom_minimum_size = Vector2(240, 30)
	_apply_menu_button_theme(continue_btn, false)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

	var btn_controls := Button.new()
	btn_controls.name = "ControlsGuideButton"
	btn_controls.text = "Comandos / Controles"
	btn_controls.custom_minimum_size = Vector2(240, 28)
	_apply_menu_button_theme(btn_controls, false)
	btn_controls.pressed.connect(func():
		if controls_modal:
			controls_modal.visible = true
	)
	vbox.add_child(btn_controls)

	# Rever Chefes / Boss Rush (visível quando a campanha já foi concluída ao menos uma vez)
	boss_rush_box = VBoxContainer.new()
	boss_rush_box.visible = gm != null and gm.campaign_completed_once
	boss_rush_box.add_theme_constant_override("separation", 4)
	vbox.add_child(boss_rush_box)

	var boss_lbl := Label.new()
	boss_lbl.text = "Rever Confrontos Marcantes:"
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.add_theme_font_size_override("font_size", 10)
	boss_rush_box.add_child(boss_lbl)

	var boss_hbox := HBoxContainer.new()
	boss_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_hbox.add_theme_constant_override("separation", 6)
	boss_rush_box.add_child(boss_hbox)

	var boss_entries: Array[Dictionary] = [
		{"lvl": 3, "label": "A Meia Esquecida"},
		{"lvl": 7, "label": "O Robô Esquecido"},
		{"lvl": 10, "label": "A Rainha Empoeirada"}
	]
	for entry: Dictionary in boss_entries:
		var b_btn := Button.new()
		b_btn.text = String(entry["label"])
		b_btn.custom_minimum_size = Vector2(115, 24)
		b_btn.add_theme_font_size_override("font_size", 9)
		var target_lvl: int = int(entry["lvl"])
		b_btn.pressed.connect(func():
			var gm_ref := GameManagerService.get_gm()
			if gm_ref:
				gm_ref.unlock_pipop()
				gm_ref.set_story_flag("boss_rush_revisit", true)
				gm_ref.load_level(target_lvl)
		)
		boss_hbox.add_child(b_btn)

	# Seleção de fases oculta por padrão (ferramenta de debug via F3)
	debug_level_box = VBoxContainer.new()
	debug_level_box.visible = false
	debug_level_box.add_theme_constant_override("separation", 4)
	vbox.add_child(debug_level_box)

	var select_lbl := Label.new()
	select_lbl.text = "[DEBUG F3] Acesso Rápido de Teste:"
	select_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_lbl.add_theme_font_size_override("font_size", 9)
	debug_level_box.add_child(select_lbl)

	level_select_container = HFlowContainer.new()
	level_select_container.alignment = FlowContainer.ALIGNMENT_CENTER
	level_select_container.add_theme_constant_override("h_separation", 6)
	level_select_container.add_theme_constant_override("v_separation", 6)
	debug_level_box.add_child(level_select_container)

	for i in range(1, 11):
		var lvl_btn := Button.new()
		lvl_btn.text = "Cap.%d" % i
		lvl_btn.custom_minimum_size = Vector2(56, 22)
		lvl_btn.add_theme_font_size_override("font_size", 8)
		var idx: int = i
		lvl_btn.pressed.connect(func():
			var gm_ref := GameManagerService.get_gm()
			if gm_ref:
				gm_ref.load_level(idx)
		)
		level_select_container.add_child(lvl_btn)

	_build_confirm_new_game_modal()
	_build_controls_modal()

func _build_confirm_new_game_modal() -> void:
	confirm_new_game_modal = PanelContainer.new()
	confirm_new_game_modal.name = "ConfirmNewGameModal"
	confirm_new_game_modal.visible = false
	confirm_new_game_modal.set_anchors_preset(Control.PRESET_CENTER)
	confirm_new_game_modal.offset_left = -175.0
	confirm_new_game_modal.offset_top = -75.0
	confirm_new_game_modal.offset_right = 175.0
	confirm_new_game_modal.offset_bottom = 75.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.15, 0.98)
	style.border_color = Color(0.95, 0.65, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	confirm_new_game_modal.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	confirm_new_game_modal.add_child(vbox)

	var title := Label.new()
	title.text = "Iniciar Novo Jogo?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "Já existe uma jornada salva. Iniciar um Novo Jogo substituirá o progresso atual."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 10)
	vbox.add_child(msg)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var btn_confirm := Button.new()
	btn_confirm.name = "ConfirmOverwriteButton"
	btn_confirm.text = "Confirmar Novo Jogo"
	btn_confirm.custom_minimum_size = Vector2(140, 28)
	btn_confirm.pressed.connect(_execute_start_new_game)
	hbox.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.name = "CancelOverwriteButton"
	btn_cancel.text = "Cancelar"
	btn_cancel.custom_minimum_size = Vector2(110, 28)
	btn_cancel.pressed.connect(func(): confirm_new_game_modal.visible = false)
	hbox.add_child(btn_cancel)

	add_child(confirm_new_game_modal)

func _build_controls_modal() -> void:
	controls_modal = PanelContainer.new()
	controls_modal.name = "ControlsModal"
	controls_modal.visible = false
	controls_modal.set_anchors_preset(Control.PRESET_CENTER)
	controls_modal.offset_left = -210.0
	controls_modal.offset_top = -125.0
	controls_modal.offset_right = 210.0
	controls_modal.offset_bottom = 125.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.16, 0.98)
	style.border_color = Color(0.45, 0.80, 0.95, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	controls_modal.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	controls_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "COMANDOS E CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 10)
	info.text = (
		"TECLADO (PC):\n" +
		"• Movimentação: WASD ou Setas Direcionais\n" +
		"• Interagir / Conversar / Avançar Texto: [E] ou [Enter]\n" +
		"• Esquiva Rápida (Dash): [Espaço] ou [Shift]\n" +
		"• Ataque Físico (Manopla do Pipop): [J]\n" +
		"• Ataque Sônico (Grito do Pipop): [K]\n" +
		"• Pausa / Menu: [ESC]\n\n" +
		"TELA DE TOQUE (ANDROID / MOBILE):\n" +
		"• Lado Esquerdo: Joystick Virtual Contínuo\n" +
		"• Lado Direito: Botões de Ação, Esquiva, Soco e Som"
	)
	vbox.add_child(info)

	var btn_close := Button.new()
	btn_close.text = "Fechar"
	btn_close.custom_minimum_size = Vector2(120, 26)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func(): controls_modal.visible = false)
	vbox.add_child(btn_close)

	add_child(controls_modal)

func _on_start_new_pressed() -> void:
	var gm := GameManagerService.get_gm()
	if gm != null and gm.has_save_file():
		if confirm_new_game_modal:
			confirm_new_game_modal.visible = true
		return
	_execute_start_new_game()

func _execute_start_new_game() -> void:
	if confirm_new_game_modal:
		confirm_new_game_modal.visible = false
	var gm := GameManagerService.get_gm()
	if gm:
		gm.start_new_game()
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_01_intro.tscn")

func _on_continue_pressed() -> void:
	var gm := GameManagerService.get_gm()
	if gm:
		gm.continue_game()

func _apply_menu_button_theme(btn: Button, use_red: bool) -> void:
	if btn == null:
		return
	var norm_p: String = "res://assets/ui/Button_Red_9Slides.png" if use_red else "res://assets/ui/Button_Blue_9Slides.png"
	var pres_p: String = "res://assets/ui/Button_Red_9Slides_Pressed.png" if use_red else "res://assets/ui/Button_Blue_9Slides_Pressed.png"
	var hov_p: String = "res://assets/ui/Button_Hover_9Slides.png"
	var dis_p: String = "res://assets/ui/Button_Disable_9Slides.png"
	if ResourceLoader.exists(norm_p):
		btn.add_theme_stylebox_override("normal", _make_9slice(norm_p))
	if ResourceLoader.exists(pres_p):
		btn.add_theme_stylebox_override("pressed", _make_9slice(pres_p))
	if ResourceLoader.exists(hov_p):
		btn.add_theme_stylebox_override("hover", _make_9slice(hov_p))
	if ResourceLoader.exists(dis_p):
		btn.add_theme_stylebox_override("disabled", _make_9slice(dis_p))
	btn.add_theme_color_override("font_color", Color(0.12, 0.1, 0.16, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.12, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.12, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.32, 0.30, 0.38, 0.9))

func _make_9slice(tex_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(tex_path) as Texture2D
	sb.texture_margin_left = 10.0
	sb.texture_margin_right = 10.0
	sb.texture_margin_top = 10.0
	sb.texture_margin_bottom = 12.0
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 6.0
	return sb
