class_name ChoppNPC
extends StaticBody2D
## NPC e/ou acompanhante narrativo (Chopp ou habitantes do Esquecido).
## Quando follow_target é atribuído, Chopp passa a acompanhar Pablita pelo cenário sem controle direto do jogador!

signal dialogue_requested(speaker_name: String, lines: Array[String])

@export var speaker_name: String = "Chopp"
@export_multiline var dialogue_lines: Array[String] = [
	"Pablita! Então você seguiu aquela meia ladra até aqui no Esquecido!",
	"Meu nome é Chopp. Conheço cada atalho e comunidade deste mundo.",
	"Vou acompanhar você até recuperarmos o seu CD e encontrarmos o caminho de volta!"
]
@export var npc_color: Color = Color(0.95, 0.72, 0.25, 1.0)
@export var follow_target: Node2D = null
@export var follow_offset: Vector2 = Vector2(-26, 14)
@export var follow_lerp_speed: float = 4.5

var current_dialogue_index: int = 0

@onready var interactable: Interactable = $Interactable
@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var body_collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if sprite:
		sprite.visible = false
	interactable.prompt_message = "Falar com %s" % speaker_name
	interactable.interaction_priority = 5
	interactable.interacted.connect(_on_interacted)
	interactable.focused.connect(_on_focused)
	interactable.unfocused.connect(_on_unfocused)
	if prompt_label:
		prompt_label.text = "[AÇÃO] %s" % speaker_name
		prompt_label.visible = false
	_update_collision_for_follow()
	queue_redraw()

func start_following(target: Node2D) -> void:
	follow_target = target
	_update_collision_for_follow()

func _update_collision_for_follow() -> void:
	# Se estiver acompanhando Pablita, desativa colisão física para nunca bloquear o movimento da protagonista
	if body_collision:
		body_collision.set_deferred("disabled", follow_target != null)
	collision_layer = 0 if follow_target != null else 2

func _physics_process(delta: float) -> void:
	if follow_target != null and is_instance_valid(follow_target):
		var desired_pos: Vector2 = follow_target.global_position + follow_offset
		if global_position.distance_to(desired_pos) > 8.0:
			global_position = global_position.lerp(desired_pos, clampf(follow_lerp_speed * delta, 0.0, 1.0))

func _on_interacted(_by_who: Node2D) -> void:
	if dialogue_lines.is_empty():
		return
	dialogue_requested.emit(speaker_name, dialogue_lines)

func _on_focused() -> void:
	if prompt_label:
		prompt_label.visible = true

func _on_unfocused() -> void:
	if prompt_label:
		prompt_label.visible = false

func _draw() -> void:
	var pts := PackedVector2Array([
		Vector2(0, -14),
		Vector2(10, -4),
		Vector2(0, 6),
		Vector2(-10, -4)
	])
	draw_colored_polygon(pts, npc_color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.5)
	draw_circle(Vector2(0, -18), 2.5, Color(1.0, 0.95, 0.4, 1.0))


