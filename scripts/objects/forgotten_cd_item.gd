class_name ForgottenCDItem
extends Node2D
## Ponto de coleta / item interativo (pode conceder um Encarte, aumentar capacidade ou exibir memória).
## Representado por placeholder geométrico (quadrado giratório/colorido).

signal cd_inspected(item_id: String)

@export var prompt_text: String = "Coletar Encarte / Memória"
@export var grant_encarte_id: String = "agulha_veloz"
@export var grant_capacity_bonus: int = 0
@export var heal_amount: int = 25
@export var unique_world_flag: String = ""
@export_multiline var inspection_text: String = "Você encontrou um fragmento preservado no Esquecido."

@onready var interactable: Interactable = $Interactable
@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

var is_collected: bool = false

func _ready() -> void:
	if sprite:
		sprite.visible = false
	var gm := GameManagerService.get_gm()
	var already_taken: bool = false
	if gm:
		if not grant_encarte_id.is_empty() and gm.has_encarte(grant_encarte_id):
			already_taken = true
		elif not unique_world_flag.is_empty() and gm.has_story_flag(unique_world_flag):
			already_taken = true
	if already_taken:
		is_collected = true
		if interactable:
			interactable.is_active = false
		visible = false
		return

	if interactable == null:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		interactable.collision_layer = 8
		interactable.collision_mask = 0
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 24.0
		cs.shape = c
		interactable.add_child(cs)
		add_child(interactable)

	interactable.prompt_message = prompt_text
	interactable.interaction_priority = 10
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	if not interactable.focused.is_connected(_on_focused):
		interactable.focused.connect(_on_focused)
	if not interactable.unfocused.is_connected(_on_unfocused):
		interactable.unfocused.connect(_on_unfocused)
	if prompt_label:
		prompt_label.visible = false
	queue_redraw()

func _on_interacted(by_who: Node2D) -> void:
	if is_collected:
		return
	is_collected = true
	interactable.is_active = false

	if by_who is Pablita and heal_amount > 0:
		(by_who as Pablita).health_component.heal(heal_amount)

	var gm := GameManagerService.get_gm()
	if gm:
		var flag_already_set: bool = (not unique_world_flag.is_empty() and gm.has_story_flag(unique_world_flag))
		if grant_capacity_bonus > 0 and not flag_already_set:
			gm.add_max_capacity(grant_capacity_bonus)
		if not unique_world_flag.is_empty() and not flag_already_set:
			gm.set_story_flag(unique_world_flag, true)
		if not grant_encarte_id.is_empty():
			gm.collect_encarte(grant_encarte_id)

	var am := AudioManagerService.get_am()
	if am:
		am.play_sfx("pickup_encarte")
	cd_inspected.emit(grant_encarte_id)
	queue_free()

func _on_focused() -> void:
	if not is_collected and prompt_label:
		prompt_label.visible = true

func _on_unfocused() -> void:
	if prompt_label:
		prompt_label.visible = false

func _draw() -> void:
	if is_collected:
		return
	draw_circle(Vector2(0, 3), 8.0, Color(0.05, 0.03, 0.09, 0.45))
	var col: Color = Color(0.95, 0.42, 0.88, 1.0) if not grant_encarte_id.is_empty() else Color(0.35, 0.95, 0.65, 1.0)
	if grant_capacity_bonus > 0:
		col = Color(1.0, 0.85, 0.25, 1.0)
	# Disco / Encarte iridescente com furo central
	draw_circle(Vector2.ZERO, 8.5, col)
	draw_arc(Vector2.ZERO, 8.5, 0.0, TAU, 20, Color(1.0, 0.98, 0.95, 0.95), 1.5)
	draw_arc(Vector2.ZERO, 5.5, 0.4, 2.2, 10, Color(0.65, 0.95, 1.0, 0.85), 1.4)
	draw_circle(Vector2.ZERO, 2.5, Color(0.12, 0.09, 0.18, 1.0))
	draw_arc(Vector2.ZERO, 2.5, 0.0, TAU, 12, Color.WHITE, 1.0)


