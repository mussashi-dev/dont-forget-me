class_name PipopComponent
extends Node2D
## Componente central de combate de Pipop acoplado a Pablita.
## Coordena ataque físico (manopla + combo + hitbox temporária) e ataque sônico
## (deslocamento de Pipop para a frente + disparo direcionado + retorno).

signal physical_attack_started(combo_step: int)
signal sonic_attack_started
signal capacity_changed(used_slots: int, total_slots: int)
signal debug_combat_updated(info: Dictionary)

@export var max_capacity_slots: int = 4
@export var sonic_wave_scene: PackedScene = preload("res://scenes/characters/sonic_wave.tscn")

# Parâmetros base configuráveis de ataque físico
@export var base_physical_cooldown: float = 0.28
@export var base_physical_active_window: float = 0.14
@export var base_physical_damage: int = 35
@export var base_physical_knockback: float = 260.0
@export var base_physical_reach: float = 16.0
@export var combo_reset_time: float = 0.55
@export var max_combo_steps: int = 3

# Parâmetros base configuráveis de ataque sônico
@export var base_sonic_cooldown: float = 0.55
@export var base_sonic_damage: int = 30
@export var base_sonic_speed: float = 280.0
@export var base_sonic_lifetime: float = 0.52
@export var base_sonic_knockback: float = 360.0

# Atributos efetivos (calculados com modificadores de encartes)
var physical_cooldown: float = 0.28
var physical_damage: int = 35
var physical_knockback: float = 260.0
var physical_reach: float = 16.0

var sonic_cooldown: float = 0.55
var sonic_damage: int = 30
var sonic_lifetime: float = 0.52
var sonic_area_mult: float = 1.0
var sonic_spread_degrees: float = 0.0

var current_used_slots: int = 0
var can_physical: bool = true
var can_sonic: bool = true
var is_hitbox_active: bool = false
var current_combo_step: int = 0
var combo_timer: float = 0.0
var _last_attack_dir: Vector2 = Vector2.DOWN
var _hitbox_timer: float = 0.0
var _physical_cd_timer: float = 0.0
var _sonic_cd_timer: float = 0.0

var companion: PipopCompanion = null

# Dados de depuração em tempo real (Seção 6)
var last_command_received: String = "NENHUM"
var last_ability_executed: String = "NENHUMA"
var last_target_hit: String = "NENHUM"
var last_damage_applied: int = 0
var active_sonic_waves_count: int = 0

@onready var physical_hitbox: Hitbox = $PhysicalHitbox
@onready var physical_collision: CollisionShape2D = $PhysicalHitbox/CollisionShape2D

func _ready() -> void:
	var slash_node: Node = get_node_or_null("SlashSprite")
	if slash_node and slash_node is CanvasItem:
		(slash_node as CanvasItem).visible = false

	physical_hitbox.monitoring = false
	physical_hitbox.monitorable = false
	physical_hitbox.collision_mask = 12 # Inimigos (4) + Objetos interativos/ambientais (8)
	physical_hitbox.damage_type = Hitbox.DamageType.PHYSICAL
	if not physical_hitbox.target_hit.is_connected(_on_physical_hitbox_target_hit):
		physical_hitbox.target_hit.connect(_on_physical_hitbox_target_hit)

	var gm := GameManagerService.get_gm()
	if gm:
		gm.equipment_changed.connect(apply_encarte_modifiers)
		gm.capacity_updated.connect(_on_game_manager_capacity_updated)
	apply_encarte_modifiers()
	_emit_debug_info()

func set_companion(comp: PipopCompanion) -> void:
	if companion and companion.sonic_pulse_emitted.is_connected(_on_companion_sonic_pulse):
		companion.sonic_pulse_emitted.disconnect(_on_companion_sonic_pulse)
	if companion and companion.state_changed.is_connected(_on_companion_state_changed):
		companion.state_changed.disconnect(_on_companion_state_changed)
	companion = comp
	if companion:
		companion.sonic_pulse_emitted.connect(_on_companion_sonic_pulse)
		companion.state_changed.connect(_on_companion_state_changed)
	_emit_debug_info()

func _on_companion_state_changed(_new_state: int) -> void:
	_emit_debug_info()

func _on_physical_hitbox_target_hit(target_owner: Node, damage_dealt: int, _damage_type: int) -> void:
	last_target_hit = "%s (FÍSICO)" % (target_owner.name if target_owner else "Alvo")
	last_damage_applied = damage_dealt
	_emit_debug_info()

func _on_sonic_wave_target_hit(target_owner: Node, damage_dealt: int) -> void:
	last_target_hit = "%s (SÔNICO)" % (target_owner.name if target_owner else "Alvo")
	last_damage_applied = damage_dealt
	_emit_debug_info()

func get_pipop_state_name() -> String:
	if companion == null:
		return "FOLLOW"
	match companion.current_state:
		PipopCompanion.State.FOLLOW: return "FOLLOW"
		PipopCompanion.State.PHYSICAL: return "PHYSICAL"
		PipopCompanion.State.SONIC_APPROACH: return "SONIC_APPROACH"
		PipopCompanion.State.SONIC_ATTACK: return "SONIC_ATTACK"
		PipopCompanion.State.SONIC_RETURN: return "SONIC_RETURN"
	return "UNKNOWN"

func get_active_hitbox_name() -> String:
	if is_hitbox_active and active_sonic_waves_count > 0:
		return "FÍSICA + ÁREA SÔNICA"
	elif is_hitbox_active:
		return "HITBOX FÍSICA (MANOPLA)"
	elif active_sonic_waves_count > 0:
		return "ÁREA SÔNICA (ONDA ATIVA)"
	return "NENHUMA"

func _emit_debug_info() -> void:
	debug_combat_updated.emit({
		"command": last_command_received,
		"ability": last_ability_executed,
		"pipop_state": get_pipop_state_name(),
		"active_hitbox": get_active_hitbox_name(),
		"last_target": last_target_hit,
		"last_damage": last_damage_applied
	})

func _physics_process(delta: float) -> void:
	if is_hitbox_active:
		_hitbox_timer -= delta
		if _hitbox_timer <= 0.0:
			_deactivate_physical_hitbox()

	if not can_physical:
		_physical_cd_timer -= delta
		if _physical_cd_timer <= 0.0:
			can_physical = true

	if not can_sonic:
		_sonic_cd_timer -= delta
		if _sonic_cd_timer <= 0.0:
			can_sonic = true

	if current_combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			current_combo_step = 0

func apply_encarte_modifiers() -> void:
	var gm := GameManagerService.get_gm()
	var mods: Dictionary = gm.get_active_modifiers() if gm else {}
	var p_dmg_mult: float = float(mods.get("physical_damage_mult", 1.0))
	var p_cd_mult: float = float(mods.get("physical_cooldown_mult", 1.0))
	var p_reach_mult: float = float(mods.get("physical_reach_mult", 1.0))

	var s_dmg_mult: float = float(mods.get("sonic_damage_mult", 1.0))
	var s_cd_mult: float = float(mods.get("sonic_cooldown_mult", 1.0))
	var s_range_mult: float = float(mods.get("sonic_range_mult", 1.0))
	var s_area: float = float(mods.get("sonic_area_mult", 1.0))
	var s_spread: float = float(mods.get("sonic_spread_degrees", 0.0))

	physical_damage = maxi(1, int(round(base_physical_damage * p_dmg_mult)))
	physical_cooldown = maxf(0.10, base_physical_cooldown * p_cd_mult)
	physical_reach = base_physical_reach * p_reach_mult
	physical_knockback = base_physical_knockback

	sonic_damage = maxi(1, int(round(base_sonic_damage * s_dmg_mult)))
	sonic_cooldown = maxf(0.15, base_sonic_cooldown * s_cd_mult)
	sonic_lifetime = base_sonic_lifetime * s_range_mult
	sonic_area_mult = s_area
	sonic_spread_degrees = s_spread

	if physical_hitbox:
		physical_hitbox.damage = physical_damage
		physical_hitbox.knockback_force = physical_knockback

	if gm:
		max_capacity_slots = gm.max_capacity
		current_used_slots = gm.get_used_capacity()
	capacity_changed.emit(current_used_slots, max_capacity_slots)

func _on_game_manager_capacity_updated(used: int, maximum: int) -> void:
	current_used_slots = used
	max_capacity_slots = maximum
	capacity_changed.emit(current_used_slots, max_capacity_slots)

func perform_physical_attack(facing_dir: Vector2) -> bool:
	last_command_received = "attack_physical"
	if not can_physical:
		_emit_debug_info()
		return false
	if companion and (companion.current_state == PipopCompanion.State.SONIC_APPROACH or companion.current_state == PipopCompanion.State.SONIC_ATTACK):
		_emit_debug_info()
		return false

	can_physical = false
	_last_attack_dir = facing_dir.normalized() if facing_dir != Vector2.ZERO else Vector2.DOWN

	# Avança combo (1 -> 2 -> 3)
	current_combo_step = (current_combo_step % max_combo_steps) + 1
	combo_timer = combo_reset_time
	last_ability_executed = "MANOPLA FÍSICA (Combo %d)" % current_combo_step

	var combo_damage_bonus: float = 1.0 + float(current_combo_step - 1) * 0.15
	physical_hitbox.damage = int(round(physical_damage * combo_damage_bonus))
	physical_hitbox.knockback_force = physical_knockback * (1.25 if current_combo_step == max_combo_steps else 1.0)

	var angle: float = _last_attack_dir.angle()
	physical_hitbox.rotation = angle
	physical_hitbox.position = _last_attack_dir * physical_reach

	physical_hitbox.monitoring = true
	physical_hitbox.monitorable = true
	is_hitbox_active = true
	_hitbox_timer = minf(base_physical_active_window, physical_cooldown * 0.75)
	_physical_cd_timer = physical_cooldown

	if companion:
		companion.enter_physical_state(_last_attack_dir, physical_cooldown * 0.85)

	physical_attack_started.emit(current_combo_step)
	_emit_debug_info()
	queue_redraw()
	return true

func cancel_current_attack() -> void:
	_deactivate_physical_hitbox()
	if companion:
		companion.force_reset_to_follow()
	_emit_debug_info()
	queue_redraw()

func _deactivate_physical_hitbox() -> void:
	is_hitbox_active = false
	if physical_hitbox:
		physical_hitbox.monitoring = false
		physical_hitbox.monitorable = false
	_emit_debug_info()
	queue_redraw()

func perform_sonic_attack(facing_dir: Vector2, spawn_origin: Vector2) -> bool:
	last_command_received = "attack_sonic"
	if not can_sonic or sonic_wave_scene == null:
		_emit_debug_info()
		return false
	if is_hitbox_active or (companion and companion.current_state == PipopCompanion.State.PHYSICAL):
		_emit_debug_info()
		return false

	# Garante que a hitbox física esteja 100% desativada durante o ataque sônico
	if physical_hitbox:
		physical_hitbox.monitoring = false
		physical_hitbox.monitorable = false
	is_hitbox_active = false

	_last_attack_dir = facing_dir.normalized() if facing_dir != Vector2.ZERO else Vector2.DOWN
	can_sonic = false
	_sonic_cd_timer = sonic_cooldown
	last_ability_executed = "ROSNADO SÔNICO"
	sonic_attack_started.emit()

	if companion:
		if companion.enter_sonic_sequence(_last_attack_dir):
			_emit_debug_info()
			return true

	# Fallback imediato caso não haja nó companion separado
	_spawn_sonic_wave(spawn_origin + _last_attack_dir * 12.0, _last_attack_dir)
	_emit_debug_info()
	return true

func _on_companion_sonic_pulse(front_global_pos: Vector2, direction: Vector2) -> void:
	_spawn_sonic_wave(front_global_pos, direction)

func _spawn_sonic_wave(origin: Vector2, dir: Vector2) -> void:
	if sonic_wave_scene == null:
		return
	var wave := sonic_wave_scene.instantiate() as SonicWave
	if wave:
		var final_dir: Vector2 = dir.normalized()
		if sonic_spread_degrees > 0.0:
			var spread_rad: float = deg_to_rad(randf_range(-sonic_spread_degrees, sonic_spread_degrees))
			final_dir = final_dir.rotated(spread_rad)
		wave.direction = final_dir
		wave.damage = sonic_damage
		wave.speed = base_sonic_speed
		wave.lifetime = sonic_lifetime
		wave.knockback = base_sonic_knockback
		wave.area_scale = sonic_area_mult
		wave.global_position = origin
		wave.wave_hit_target.connect(_on_sonic_wave_target_hit)
		active_sonic_waves_count += 1
		wave.tree_exited.connect(func():
			active_sonic_waves_count = maxi(0, active_sonic_waves_count - 1)
			_emit_debug_info()
		)
		var target_parent: Node = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else (owner.get_parent() if owner != null else get_parent())
		if target_parent != null:
			target_parent.add_child(wave)
		_emit_debug_info()

func equip_enhancement(slot_cost: int) -> bool:
	if current_used_slots + slot_cost <= max_capacity_slots:
		current_used_slots += slot_cost
		capacity_changed.emit(current_used_slots, max_capacity_slots)
		return true
	return false

func unequip_enhancement(slot_cost: int) -> void:
	current_used_slots = maxi(current_used_slots - slot_cost, 0)
	capacity_changed.emit(current_used_slots, max_capacity_slots)

func _draw() -> void:
	if is_hitbox_active:
		# Placeholder geométrico temporário para a hitbox do golpe físico
		var center: Vector2 = _last_attack_dir * physical_reach
		var radius: float = 12.0 + float(current_combo_step - 1) * 2.0
		draw_circle(center, radius, Color(1.0, 0.5, 0.15, 0.45))
		draw_arc(center, radius, 0.0, TAU, 18, Color(1.0, 0.85, 0.3, 0.95), 2.0)
		draw_line(Vector2.ZERO, center, Color(1.0, 0.7, 0.2, 0.8), 2.0)

