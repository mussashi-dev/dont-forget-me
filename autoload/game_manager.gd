class_name GameManagerService
extends Node
## Autoload global para gerenciar estado da campanha, progressão de fases,
## inventário e equipamento de encartes, capacidade e salvamento.

static var instance: GameManagerService = null

signal game_state_changed(new_state: GameState)
signal encarte_collected(encarte_id: String)
signal equipment_changed
signal capacity_updated(used: int, maximum: int)
signal level_changed(level_index: int)
signal story_flag_changed(flag_name: String, value: Variant)
signal input_device_changed(is_mobile: bool)
signal accessibility_changed

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	DEAD,
	VICTORY,
	TRANSITION,
	CAMPAIGN_COMPLETE
}

const SAVE_PATH: String = "user://dont_forget_me_save.cfg"
const TOTAL_LEVELS: int = 10

const LEVEL_PATHS: Dictionary = {
	1: "res://scenes/levels/level_01_intro.tscn",
	2: "res://scenes/levels/level_02.tscn",
	3: "res://scenes/levels/level_03_boss_sock.tscn",
	4: "res://scenes/levels/level_04.tscn",
	5: "res://scenes/levels/level_05.tscn",
	6: "res://scenes/levels/level_06.tscn",
	7: "res://scenes/levels/level_07_boss_robot.tscn",
	8: "res://scenes/levels/level_08.tscn",
	9: "res://scenes/levels/level_09.tscn",
	10: "res://scenes/levels/level_10_boss_queen.tscn"
}

const LEVEL_TITLES: Dictionary = {
	1: "O Quarto de Pablita e a Passagem Secreta",
	2: "Trilha das Lembranças — Primeiros Ecos",
	3: "Covil de Costura — A Meia Esquecida",
	4: "Vila dos Achados — Comunidade do Esquecido",
	5: "Passagens Trancadas — Ruínas Sonoras",
	6: "Antecâmara da Engrenagem",
	7: "Forja Rítmica — O Robô Esquecido",
	8: "Profundezas Desbotadas",
	9: "Salão Antes do Trono",
	10: "O Vitral Empoeirado — A Rainha Empoeirada"
}

var current_state: GameState = GameState.MENU
var current_level_index: int = 1
var max_unlocked_level: int = 1

var base_max_capacity: int = 4
var bonus_capacity: int = 0
var max_capacity: int:
	get:
		return base_max_capacity + bonus_capacity

var catalog: Dictionary = {} # id -> EncarteData
var collected_encartes: Array[String] = []
var equipped_encartes: Array[String] = []
var world_flags: Dictionary = {}
var campaign_completed_once: bool = false
var is_mobile_device: bool = false
var screen_shake_enabled: bool = true
var high_legibility_text: bool = false

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile_device = OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]
	_build_encarte_catalog()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if is_mobile_device and not (OS.get_name() in ["Android", "iOS"]):
			is_mobile_device = false
			input_device_changed.emit(is_mobile_device)
	elif event is InputEventScreenTouch and event.pressed:
		if OS.get_name() in ["Android", "iOS"] or OS.has_feature("mobile"):
			if not is_mobile_device:
				is_mobile_device = true
				input_device_changed.emit(is_mobile_device)

func set_mobile_mode_override(mobile: bool) -> void:
	if is_mobile_device != mobile:
		is_mobile_device = mobile
		input_device_changed.emit(is_mobile_device)

func set_screen_shake_enabled(enabled: bool) -> void:
	screen_shake_enabled = enabled
	accessibility_changed.emit()
	save_game()

func set_high_legibility_text(enabled: bool) -> void:
	high_legibility_text = enabled
	accessibility_changed.emit()
	save_game()

func is_pipop_acquired() -> bool:
	return has_story_flag("pipop_acquired")

func unlock_pipop() -> void:
	set_story_flag("pipop_acquired", true)

static func get_gm() -> GameManagerService:
	return instance

func _build_encarte_catalog() -> void:
	catalog.clear()

	# 1. Físico: Velocidade de ataque físico maior, mas menor dano por golpe
	var e1 := EncarteData.new()
	e1.id = "agulha_veloz"
	e1.title = "Encarte da Agulha Veloz"
	e1.category = EncarteData.Category.PHYSICAL
	e1.capacity_cost = 2
	e1.benefit_text = "+35% velocidade de ataque físico (menor recarga)"
	e1.limitation_text = "-25% dano por golpe físico"
	e1.description = "Altera a manifestação da manopla para golpes rápidos e leves."
	e1.physical_cooldown_mult = 0.65
	e1.physical_damage_mult = 0.75
	catalog[e1.id] = e1

	# 2. Físico: Maior dano físico, mas recuperação mais longa
	var e2 := EncarteData.new()
	e2.id = "punho_chumbo"
	e2.title = "Encarte do Punho de Chumbo"
	e2.category = EncarteData.Category.PHYSICAL
	e2.capacity_cost = 2
	e2.benefit_text = "+50% dano físico e +15% alcance físico"
	e2.limitation_text = "+40% tempo de recuperação entre golpes físicos"
	e2.description = "Torna a manopla de Pipop muito pesada, exigindo precisão."
	e2.physical_damage_mult = 1.50
	e2.physical_reach_mult = 1.15
	e2.physical_cooldown_mult = 1.40
	catalog[e2.id] = e2

	# 3. Sônico: Maior potência sônica, mas maior alcance de detecção inimiga
	var e3 := EncarteData.new()
	e3.id = "amplificador_ruido"
	e3.title = "Encarte do Amplificador de Ruído"
	e3.category = EncarteData.Category.SONIC
	e3.capacity_cost = 2
	e3.benefit_text = "+50% dano sônico"
	e3.limitation_text = "+45% alcance de detecção dos inimigos"
	e3.description = "Aumenta a reverberação de Pipop, mas atrai inimigos de mais longe."
	e3.sonic_damage_mult = 1.50
	e3.enemy_detection_mult = 1.45
	catalog[e3.id] = e3

	# 4. Sônico: Maior alcance sônico, mas menor precisão
	var e4 := EncarteData.new()
	e4.id = "eco_distante"
	e4.title = "Encarte do Eco Distante"
	e4.category = EncarteData.Category.SONIC
	e4.capacity_cost = 1
	e4.benefit_text = "+55% alcance sônico"
	e4.limitation_text = "Menor precisão direcional (desvio de até 14 graus)"
	e4.description = "Projeta o som de Pipop a longa distância com instabilidade."
	e4.sonic_range_mult = 1.55
	e4.sonic_spread_degrees = 14.0
	catalog[e4.id] = e4

	# 5. Sônico: Maior área sônica, mas menor dano em alvo único
	var e5 := EncarteData.new()
	e5.id = "onda_larga"
	e5.title = "Encarte da Onda Larga"
	e5.category = EncarteData.Category.SONIC
	e5.capacity_cost = 2
	e5.benefit_text = "+65% tamanho da área de impacto sônico"
	e5.limitation_text = "-30% dano sônico por impacto"
	e5.description = "Espalha a frequência para atingir múltiplos alvos ou âncoras."
	e5.sonic_area_mult = 1.65
	e5.sonic_damage_mult = 0.70
	catalog[e5.id] = e5

	# 6. Defesa: Maior defesa, mas menor capacidade ofensiva
	var e6 := EncarteData.new()
	e6.id = "casulo_retalhos"
	e6.title = "Encarte do Casulo de Retalhos"
	e6.category = EncarteData.Category.DEFENSE
	e6.capacity_cost = 2
	e6.benefit_text = "-35% dano recebido e +25 vida máxima"
	e6.limitation_text = "-20% dano físico e sônico"
	e6.description = "Amortece impactos contra Pablita ao custo da força ofensiva."
	e6.damage_taken_mult = 0.65
	e6.max_health_bonus = 25
	e6.physical_damage_mult = 0.80
	e6.sonic_damage_mult = 0.80
	catalog[e6.id] = e6

	# 7. Mobilidade: Passo Leve
	var e7 := EncarteData.new()
	e7.id = "passo_vento"
	e7.title = "Encarte do Passo de Vento"
	e7.category = EncarteData.Category.MOBILITY
	e7.capacity_cost = 2
	e7.benefit_text = "+25% velocidade de movimento e -25% recarga de esquiva"
	e7.limitation_text = "+20% dano recebido"
	e7.description = "Acelera os passos de Pablita, deixando sua guarda mais exposta."
	e7.move_speed_mult = 1.25
	e7.dash_cooldown_mult = 0.75
	e7.damage_taken_mult = 1.20
	catalog[e7.id] = e7

	# 8. Utilidade: Memória Atenta
	var e8 := EncarteData.new()
	e8.id = "olhar_atento"
	e8.title = "Encarte do Olhar Atento"
	e8.category = EncarteData.Category.UTILITY
	e8.capacity_cost = 1
	e8.benefit_text = "+50% raio de interação e -20% recarga sônica"
	e8.limitation_text = "-10% velocidade de movimento"
	e8.description = "Facilita interagir com objetos e sintonizar frequências com calma."
	e8.interact_radius_mult = 1.50
	e8.sonic_cooldown_mult = 0.80
	e8.move_speed_mult = 0.90
	catalog[e8.id] = e8

func set_story_flag(flag_name: String, value: Variant = true) -> void:
	world_flags[flag_name] = value
	story_flag_changed.emit(flag_name, value)
	save_game()

func get_story_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return world_flags.get(flag_name, default_value)

func has_story_flag(flag_name: String) -> bool:
	return bool(world_flags.get(flag_name, false))

func reset_campaign() -> void:
	current_level_index = 1
	max_unlocked_level = 1
	bonus_capacity = 0
	collected_encartes.clear()
	equipped_encartes.clear()
	world_flags.clear()
	get_tree().paused = false
	current_state = GameState.PLAYING
	game_state_changed.emit(current_state)
	capacity_updated.emit(get_used_capacity(), max_capacity)
	equipment_changed.emit()

func get_used_capacity() -> int:
	var total: int = 0
	for id: String in equipped_encartes:
		if catalog.has(id):
			var data: EncarteData = catalog[id]
			total += data.capacity_cost
	return total

func get_available_capacity() -> int:
	return maxi(0, max_capacity - get_used_capacity())

func collect_encarte(id: String) -> bool:
	if not catalog.has(id):
		return false
	if not collected_encartes.has(id):
		collected_encartes.append(id)
		encarte_collected.emit(id)
		save_game()
		return true
	return false

func has_encarte(id: String) -> bool:
	return collected_encartes.has(id)

func is_equipped(id: String) -> bool:
	return equipped_encartes.has(id)

func can_equip(id: String) -> bool:
	if not collected_encartes.has(id) or equipped_encartes.has(id):
		return false
	if not catalog.has(id):
		return false
	var data: EncarteData = catalog[id]
	return get_used_capacity() + data.capacity_cost <= max_capacity

func equip_encarte(id: String) -> bool:
	if not can_equip(id):
		return false
	equipped_encartes.append(id)
	capacity_updated.emit(get_used_capacity(), max_capacity)
	equipment_changed.emit()
	save_game()
	return true

func unequip_encarte(id: String) -> bool:
	if not equipped_encartes.has(id):
		return false
	equipped_encartes.erase(id)
	capacity_updated.emit(get_used_capacity(), max_capacity)
	equipment_changed.emit()
	save_game()
	return true

func add_max_capacity(amount: int) -> void:
	bonus_capacity += amount
	capacity_updated.emit(get_used_capacity(), max_capacity)
	equipment_changed.emit()
	save_game()

## Calcula todos os modificadores acumulados para uma lista de IDs de encartes.
func compute_modifiers_for(encarte_ids: Array[String]) -> Dictionary:
	var mods := {
		"physical_damage_mult": 1.0,
		"physical_cooldown_mult": 1.0,
		"physical_reach_mult": 1.0,
		"sonic_damage_mult": 1.0,
		"sonic_cooldown_mult": 1.0,
		"sonic_range_mult": 1.0,
		"sonic_area_mult": 1.0,
		"sonic_spread_degrees": 0.0,
		"move_speed_mult": 1.0,
		"dash_cooldown_mult": 1.0,
		"max_health_bonus": 0,
		"damage_taken_mult": 1.0,
		"enemy_detection_mult": 1.0,
		"interact_radius_mult": 1.0
	}
	for id: String in encarte_ids:
		if catalog.has(id):
			var d: EncarteData = catalog[id]
			mods["physical_damage_mult"] *= d.physical_damage_mult
			mods["physical_cooldown_mult"] *= d.physical_cooldown_mult
			mods["physical_reach_mult"] *= d.physical_reach_mult
			mods["sonic_damage_mult"] *= d.sonic_damage_mult
			mods["sonic_cooldown_mult"] *= d.sonic_cooldown_mult
			mods["sonic_range_mult"] *= d.sonic_range_mult
			mods["sonic_area_mult"] *= d.sonic_area_mult
			mods["sonic_spread_degrees"] += d.sonic_spread_degrees
			mods["move_speed_mult"] *= d.move_speed_mult
			mods["dash_cooldown_mult"] *= d.dash_cooldown_mult
			mods["max_health_bonus"] += d.max_health_bonus
			mods["damage_taken_mult"] *= d.damage_taken_mult
			mods["enemy_detection_mult"] *= d.enemy_detection_mult
			mods["interact_radius_mult"] *= d.interact_radius_mult
	return mods

func get_active_modifiers() -> Dictionary:
	return compute_modifiers_for(equipped_encartes)

## Simula os modificadores caso o encarte `candidate_id` seja alternado (equipado/desequipado).
func preview_modifiers_with_toggle(candidate_id: String) -> Dictionary:
	var sim_list: Array[String] = equipped_encartes.duplicate()
	if sim_list.has(candidate_id):
		sim_list.erase(candidate_id)
	else:
		sim_list.append(candidate_id)
	return compute_modifiers_for(sim_list)

# ---------- Fluxo de Jogo e Fases ----------

func set_game_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(current_state)

func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()

func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	get_tree().paused = true
	set_game_state(GameState.PAUSED)

func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	get_tree().paused = false
	set_game_state(GameState.PLAYING)

func start_new_game() -> void:
	reset_campaign()
	save_game()
	load_level(1)

func continue_game() -> bool:
	if not load_game():
		return false
	load_level(current_level_index)
	return true

func load_level(level_idx: int) -> void:
	get_tree().paused = false
	current_level_index = clampi(level_idx, 1, TOTAL_LEVELS)
	if current_level_index >= 2 and not has_story_flag("pipop_acquired"):
		world_flags["pipop_acquired"] = true
		story_flag_changed.emit("pipop_acquired", true)
	if current_level_index > max_unlocked_level:
		max_unlocked_level = current_level_index
	set_game_state(GameState.TRANSITION)
	save_game()
	var path: String = LEVEL_PATHS.get(current_level_index, LEVEL_PATHS[1])
	get_tree().change_scene_to_file(path)
	set_game_state(GameState.PLAYING)
	level_changed.emit(current_level_index)

func restart_current_level() -> void:
	get_tree().paused = false
	set_game_state(GameState.PLAYING)
	get_tree().reload_current_scene()

func advance_to_next_level() -> void:
	if current_level_index < TOTAL_LEVELS:
		load_level(current_level_index + 1)
	else:
		complete_campaign()

func complete_campaign() -> void:
	get_tree().paused = false
	campaign_completed_once = true
	world_flags["campaign_completed_once"] = true
	set_game_state(GameState.CAMPAIGN_COMPLETE)
	save_game()

func return_to_main_menu() -> void:
	get_tree().paused = false
	set_game_state(GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ---------- Persistência ----------

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level_index", current_level_index)
	cfg.set_value("progress", "max_unlocked_level", max_unlocked_level)
	cfg.set_value("progress", "bonus_capacity", bonus_capacity)
	cfg.set_value("progress", "collected_encartes", collected_encartes)
	cfg.set_value("progress", "equipped_encartes", equipped_encartes)
	cfg.set_value("progress", "world_flags", world_flags)
	cfg.set_value("progress", "campaign_completed_once", campaign_completed_once)
	cfg.set_value("settings", "screen_shake_enabled", screen_shake_enabled)
	cfg.set_value("settings", "high_legibility_text", high_legibility_text)
	cfg.save(SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return false
	current_level_index = int(cfg.get_value("progress", "current_level_index", 1))
	max_unlocked_level = int(cfg.get_value("progress", "max_unlocked_level", 1))
	bonus_capacity = int(cfg.get_value("progress", "bonus_capacity", 0))
	var col: Array = cfg.get_value("progress", "collected_encartes", [])
	collected_encartes.clear()
	for item in col:
		collected_encartes.append(String(item))
	var eq: Array = cfg.get_value("progress", "equipped_encartes", [])
	equipped_encartes.clear()
	for item in eq:
		if catalog.has(String(item)):
			equipped_encartes.append(String(item))
	world_flags = cfg.get_value("progress", "world_flags", {})
	campaign_completed_once = bool(cfg.get_value("progress", "campaign_completed_once", bool(world_flags.get("campaign_completed_once", false))))
	screen_shake_enabled = bool(cfg.get_value("settings", "screen_shake_enabled", true))
	high_legibility_text = bool(cfg.get_value("settings", "high_legibility_text", false))
	capacity_updated.emit(get_used_capacity(), max_capacity)
	equipment_changed.emit()
	accessibility_changed.emit()
	return true
