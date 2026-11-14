class_name MainMenu
extends Control
## Menu Inicial funcional de DON'T FORGET ME.
## Todos os botões executam ações reais (Nova Partida, Continuar Partida Salva, Seleção de Fase).

var continue_btn: Button
var level_select_container: HFlowContainer

func _ready() -> void:
	get_tree().paused = false
	var gm := GameManagerService.get_gm()
	if gm:
		gm.set_game_state(GameManagerService.GameState.MENU)
		gm.load_game()
	_build_ui()

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
	sub.text = "Reconstrução Funcional de Gameplay — Placeholders Geométricos"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.modulate = Color(0.8, 0.78, 0.92, 0.9)
	vbox.add_child(sub)

	var btn_new := Button.new()
	btn_new.name = "StartNewGameButton"
	btn_new.text = "Iniciar Nova Partida (Fase 1)"
	btn_new.custom_minimum_size = Vector2(240, 32)
	btn_new.pressed.connect(_on_start_new_pressed)
	vbox.add_child(btn_new)

	var gm := GameManagerService.get_gm()
	continue_btn = Button.new()
	continue_btn.name = "ContinueGameButton"
	var has_save: bool = gm != null and gm.has_save_file()
	var saved_lvl: int = gm.current_level_index if gm else 1
	continue_btn.text = "Continuar Progresso (Fase %d)" % saved_lvl if has_save else "Continuar (Sem Jogo Salvo)"
	continue_btn.disabled = not has_save
	continue_btn.custom_minimum_size = Vector2(240, 30)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

	var select_lbl := Label.new()
	select_lbl.text = "Acesso Direto às 10 Fases da Campanha:"
	select_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(select_lbl)

	level_select_container = HFlowContainer.new()
	level_select_container.alignment = FlowContainer.ALIGNMENT_CENTER
	level_select_container.add_theme_constant_override("h_separation", 6)
	level_select_container.add_theme_constant_override("v_separation", 6)
	vbox.add_child(level_select_container)

	for i in range(1, 11):
		var lvl_btn := Button.new()
		var suffix: String = ""
		if i in [3, 7, 10]:
			suffix = " [CHEFE]"
		lvl_btn.text = "F%d%s" % [i, suffix]
		lvl_btn.custom_minimum_size = Vector2(68, 26)
		lvl_btn.add_theme_font_size_override("font_size", 9)
		var idx: int = i
		lvl_btn.pressed.connect(func():
			var gm_ref := GameManagerService.get_gm()
			if gm_ref:
				gm_ref.load_level(idx)
		)
		level_select_container.add_child(lvl_btn)

func _on_start_new_pressed() -> void:
	var gm := GameManagerService.get_gm()
	if gm:
		gm.start_new_game()
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_01_intro.tscn")

func _on_continue_pressed() -> void:
	var gm := GameManagerService.get_gm()
	if gm:
		gm.continue_game()
