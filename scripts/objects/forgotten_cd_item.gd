class_name ForgottenCDItem
extends Node2D
## Ponto de coleta / item interativo (pode conceder um Encarte, aumentar capacidade ou exibir memória).
## Representado por placeholder geométrico (quadrado giratório/colorido).

signal cd_inspected(item_id: String)

@export var prompt_text: String = "Coletar Encarte / Memória"
@export var grant_encarte_id: String = "agulha_veloz"
@export var grant_capacity_bonus: int = 0
@export var heal_amount: int = 25
@export_multiline var inspection_text: String = "Você encontrou um fragmento preservado no Esquecido."

@onready var interactable: Interactable = $Interactable
@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

var is_collected: bool = false

func _ready() -> void:
	if sprite:
		sprite.visible = false
	var gm := GameManagerService.get_gm()
	if gm and not grant_encarte_id.is_empty() and gm.has_encarte(grant_encarte_id):
		is_collected = true
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
		if grant_capacity_bonus > 0:
			gm.add_max_capacity(grant_capacity_bonus)
		if not grant_encarte_id.is_empty():
			gm.collect_encarte(grant_encarte_id)

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
	var col: Color = Color(0.95, 0.35, 0.85, 1.0) if not grant_encarte_id.is_empty() else Color(0.35, 0.95, 0.55, 1.0)
	if grant_capacity_bonus > 0:
		col = Color(1.0, 0.85, 0.2, 1.0)
	var rect := Rect2(Vector2(-7, -7), Vector2(14, 14))
	draw_rect(rect, col, true)
	draw_rect(rect, Color.WHITE, false, 1.5)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)

