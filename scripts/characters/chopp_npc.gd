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
		sprite.visible = (speaker_name == "Chopp")
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

func stop_following_and_enable_dialogue(new_lines: Array[String] = []) -> void:
	follow_target = null
	if not new_lines.is_empty():
		dialogue_lines = new_lines
	_update_collision_for_follow()

func _update_collision_for_follow() -> void:
	# Se estiver acompanhando Pablita, desativa colisão física e interação contínua para nunca bloquear o movimento nem poluir a tela
	var is_following: bool = follow_target != null
	if body_collision:
		body_collision.set_deferred("disabled", is_following)
	collision_layer = 0 if is_following else 2
	if interactable:
		interactable.is_active = not is_following and not dialogue_lines.is_empty()
		if not interactable.is_active:
			interactable.lose_focus()
	if prompt_label and is_following:
		prompt_label.visible = false

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
	draw_circle(Vector2(0, 2), 8.0, Color(0.06, 0.04, 0.1, 0.45))
	if sprite and sprite.visible and sprite.texture != null:
		return
	if speaker_name.begins_with("Luffy"):
		# Cachorrinho caramelo/dourado deitado na almofada
		draw_circle(Vector2(0, -4), 8.5, Color(0.88, 0.62, 0.28, 1.0))
		draw_circle(Vector2(-6, -8), 3.5, Color(0.55, 0.34, 0.14, 1.0))
		draw_circle(Vector2(6, -8), 3.5, Color(0.55, 0.34, 0.14, 1.0))
		draw_circle(Vector2(-2.5, -5), 1.3, Color(0.12, 0.08, 0.06, 1.0))
		draw_circle(Vector2(2.5, -5), 1.3, Color(0.12, 0.08, 0.06, 1.0))
		draw_circle(Vector2(0, -2.5), 1.8, Color(0.2, 0.12, 0.1, 1.0))
		return
	# Silhueta estilizada de habitante da Vila dos Achados (despertador, xícara, soldadinho)
	draw_circle(Vector2(0, -8), 8.5, npc_color)
	draw_arc(Vector2(0, -8), 8.5, 0.0, TAU, 18, Color(1.0, 0.96, 0.88, 0.9), 1.5)
	draw_circle(Vector2(-3, -9), 1.4, Color(0.15, 0.1, 0.2, 1.0))
	draw_circle(Vector2(3, -9), 1.4, Color(0.15, 0.1, 0.2, 1.0))
	draw_circle(Vector2(0, -19), 2.5, Color(1.0, 0.92, 0.45, 0.95))



