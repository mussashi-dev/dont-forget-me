class_name ResonanceCrystal
extends Area2D
## Cristal de Ressonância Ambiental.
## Emite `puzzle_solved` quando Pipop usa a manifestação sonora (SonicAttack / SonicWave) na área.

signal puzzle_solved(crystal: ResonanceCrystal)

@export var crystal_id: String = "crystal_fase2"
@export var is_solved: bool = false
@export var one_shot: bool = true
@export var resonance_radius: float = 42.0
@export var target_door_path: NodePath
@export var target_reveal_path: NodePath

var _pulse_time: float = 0.0
var _player_inside: bool = false
var _connected_pipop: PipopComponent = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	add_to_group("resonance_crystals")
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 8
	collision_mask = 1 | 8 | 16 # Pablita (1), Interactables/Hurtboxes (8), SonicHitbox (16)
	monitoring = true
	monitorable = true

	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = resonance_radius
		cs.shape = circle
		add_child(cs)

	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sprite.offset == Vector2.ZERO:
			sprite.offset = Vector2(0, -16)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	call_deferred("_bind_player_pipop")
	queue_redraw()

func _bind_player_pipop() -> void:
	if get_tree() == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Pablita
	if player != null and player.pipop != null and _connected_pipop != player.pipop:
		_connected_pipop = player.pipop
		if not _connected_pipop.sonic_attack_started.is_connected(_on_pipop_sonic_attack_started):
			_connected_pipop.sonic_attack_started.connect(_on_pipop_sonic_attack_started)

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_inside = true
		_bind_player_pipop()

func _on_body_exited(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_inside = false

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		var hb := area as Hitbox
		if hb.damage_type == Hitbox.DamageType.SONIC:
			trigger_resonance(hb)

func _on_pipop_sonic_attack_started() -> void:
	if _player_inside:
		trigger_resonance(_connected_pipop)
		return
	# Fallback espacial por distância direta em testes/cutscenes
	if get_tree() != null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(global_position) <= resonance_radius + 24.0:
			trigger_resonance(_connected_pipop)

func trigger_resonance(_source: Node = null) -> bool:
	if is_solved and one_shot:
		return false
	is_solved = true
	_apply_environmental_effects()
	if sprite != null:
		sprite.modulate = Color(0.55, 1.35, 1.45, 1.0)
	queue_redraw()
	puzzle_solved.emit(self)
	return true

func _apply_environmental_effects() -> void:
	if not target_door_path.is_empty():
		var door := get_node_or_null(target_door_path)
		if door != null:
			_open_door_node(door)
	if not target_reveal_path.is_empty():
		var reveal := get_node_or_null(target_reveal_path)
		if reveal != null and reveal is CanvasItem:
			(reveal as CanvasItem).visible = true

func _open_door_node(door: Node) -> void:
	if door is StaticBody2D:
		for child: Node in door.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
			elif child is CollisionPolygon2D:
				(child as CollisionPolygon2D).set_deferred("disabled", true)
	if door is CanvasItem:
		(door as CanvasItem).visible = false

func _draw() -> void:
	var glow_alpha: float = 0.25 + 0.12 * sin(_pulse_time * 3.5)
	var base_color: Color = Color(0.25, 0.95, 0.85, 1.0) if is_solved else Color(0.76, 0.34, 0.98, 1.0)
	draw_circle(Vector2.ZERO, resonance_radius, Color(base_color.r, base_color.g, base_color.b, glow_alpha * 0.45))
	draw_arc(Vector2.ZERO, resonance_radius, 0.0, TAU, 24, Color(base_color.r, base_color.g, base_color.b, 0.75), 1.5)

	if sprite == null or sprite.texture == null:
		var pts := PackedVector2Array([
			Vector2(0, -24),
			Vector2(10, -10),
			Vector2(6, 0),
			Vector2(-6, 0),
			Vector2(-10, -10)
		])
		draw_colored_polygon(pts, base_color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
