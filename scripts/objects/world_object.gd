class_name WorldObject
extends StaticBody2D
## Elemento ambiental / interativo genérico (com placeholders geométricos):
## - BREAKABLE_CRATE: Obstáculo quebrável com ataque FÍSICO
## - SONIC_CRYSTAL: Interruptor / âncora ressonante ativável com ataque SÔNICO
## - LEVEL_PORTAL: Porta / passagem para a próxima fase (pode exigir derrotar inimigos ou ativar cristais)
## - LORE_PLINTH: Objeto examinável que exibe texto no diálogo

signal activated(obj: WorldObject)
signal destroyed(obj: WorldObject)

enum ObjectType {
	BREAKABLE_CRATE,
	SONIC_CRYSTAL,
	LEVEL_PORTAL,
	LORE_PLINTH
}

@export var object_type: ObjectType = ObjectType.BREAKABLE_CRATE
@export var size_vec: Vector2 = Vector2(26, 26)
@export var is_locked: bool = false
@export var target_level_index: int = 0 # 0 = avança automaticamente para current_level_index + 1
@export var prompt_text: String = "Interagir"
@export_multiline var lore_lines: Array[String] = ["Um objeto esquecido pelo tempo."]

var is_activated: bool = false
var _col_shape: CollisionShape2D
var _hurtbox: Hurtbox
var _interactable: Interactable

func _ready() -> void:
	_setup_by_type()
	queue_redraw()

func _setup_by_type() -> void:
	match object_type:
		ObjectType.BREAKABLE_CRATE:
			collision_layer = 2
			collision_mask = 0
			_add_solid_collision(size_vec)
			_add_reaction_hurtbox(size_vec + Vector2(6, 6))

		ObjectType.SONIC_CRYSTAL:
			collision_layer = 2
			collision_mask = 0
			_add_solid_collision(Vector2(18, 18))
			_add_reaction_hurtbox(Vector2(26, 26))

		ObjectType.LEVEL_PORTAL:
			collision_layer = 0
			collision_mask = 0
			_add_interactable(32.0, prompt_text if prompt_text != "Interagir" else "Avançar de Fase", 20)

		ObjectType.LORE_PLINTH:
			collision_layer = 2
			collision_mask = 0
			_add_solid_collision(Vector2(20, 20))
			_add_interactable(28.0, prompt_text if prompt_text != "Interagir" else "Examinar Objeto", 8)

func _add_solid_collision(rect_size: Vector2) -> void:
	_col_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect_size
	_col_shape.shape = r
	add_child(_col_shape)

func _add_reaction_hurtbox(rect_size: Vector2) -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 8 # Camada 8 atingida por PhysicalHitbox e SonicWave (máscara 12)
	_hurtbox.collision_mask = 0
	_hurtbox.invulnerability_duration = 0.1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect_size
	cs.shape = r
	_hurtbox.add_child(cs)
	_hurtbox.hit_received.connect(_on_hurtbox_hit)
	add_child(_hurtbox)

func _add_interactable(radius: float, msg: String, prio: int) -> void:
	_interactable = Interactable.new()
	_interactable.collision_layer = 8
	_interactable.collision_mask = 0
	_interactable.prompt_message = msg
	_interactable.interaction_priority = prio
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	_interactable.add_child(cs)
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	_update_portal_prompt()

func set_locked(locked: bool) -> void:
	is_locked = locked
	_update_portal_prompt()
	queue_redraw()

func _update_portal_prompt() -> void:
	if object_type == ObjectType.LEVEL_PORTAL and _interactable:
		if is_locked:
			_interactable.prompt_message = "Passagem Trancada (Resolva a sala)"
		else:
			var default_txt: String = prompt_text if prompt_text != "" and prompt_text != "Interagir" else "Avançar para a Próxima Fase"
			_interactable.prompt_message = default_txt

func _on_hurtbox_hit(_damage: int, damage_type: int, _knockback: Vector2, _stun: float) -> void:
	if object_type == ObjectType.BREAKABLE_CRATE:
		if damage_type == Hitbox.DamageType.PHYSICAL:
			if _col_shape:
				_col_shape.set_deferred("disabled", true)
			destroyed.emit(self)
			queue_free()
	elif object_type == ObjectType.SONIC_CRYSTAL:
		if damage_type == Hitbox.DamageType.SONIC and not is_activated:
			is_activated = true
			var am := AudioManagerService.get_am()
			if am:
				am.play_sfx("crystal_activate")
			activated.emit(self)
			queue_redraw()

func _on_interacted(_by_who: Node2D) -> void:
	if object_type == ObjectType.LEVEL_PORTAL:
		if is_locked:
			var hud_node := get_tree().current_scene.get_node_or_null("HUD") as HUD
			if hud_node:
				hud_node.show_dialogue("Passagem Bloqueada", "Esta passagem está trancada. Derrote a ameaça da sala antes de utilizá-la.")
			return
		activated.emit(self)
		var gm := GameManagerService.get_gm()
		if gm:
			if target_level_index > 0:
				gm.load_level(target_level_index)
			else:
				gm.advance_to_next_level()
	elif object_type == ObjectType.LORE_PLINTH:
		activated.emit(self)
		if not lore_lines.is_empty():
			var hud_node := get_tree().current_scene.get_node_or_null("HUD") as HUD
			if hud_node:
				hud_node.show_dialogue_sequence("Memória do Ambiente", lore_lines)

func _draw() -> void:
	var half := size_vec * 0.5
	var rect := Rect2(-half, size_vec)
	match object_type:
		ObjectType.BREAKABLE_CRATE:
			draw_rect(rect, Color(0.65, 0.42, 0.22, 1.0), true)
			draw_rect(rect, Color(0.95, 0.75, 0.45, 1.0), false, 2.0)
			draw_line(-half, half, Color(0.95, 0.75, 0.45, 0.8), 1.5)
			draw_line(Vector2(-half.x, half.y), Vector2(half.x, -half.y), Color(0.95, 0.75, 0.45, 0.8), 1.5)

		ObjectType.SONIC_CRYSTAL:
			var col: Color = Color(0.2, 0.95, 0.55, 1.0) if is_activated else Color(0.2, 0.65, 0.95, 1.0)
			var pts := PackedVector2Array([
				Vector2(0, -14),
				Vector2(12, 0),
				Vector2(0, 14),
				Vector2(-12, 0)
			])
			draw_colored_polygon(pts, col)
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 18, col.lightened(0.3), 1.8)

		ObjectType.LEVEL_PORTAL:
			var p_col: Color = Color(0.55, 0.25, 0.35, 0.85) if is_locked else Color(0.3, 0.95, 0.55, 0.9)
			draw_rect(Rect2(Vector2(-18, -24), Vector2(36, 48)), p_col, true)
			draw_rect(Rect2(Vector2(-18, -24), Vector2(36, 48)), Color.WHITE, false, 2.2)
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE if not is_locked else Color(0.9, 0.3, 0.3))

		ObjectType.LORE_PLINTH:
			draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color(0.55, 0.5, 0.75, 1.0), true)
			draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color(0.9, 0.85, 1.0, 1.0), false, 1.5)
