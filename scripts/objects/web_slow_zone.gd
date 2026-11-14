class_name WebSlowZone
extends Area2D
## Área temporária de teia/fios que reduz a velocidade de Pablita (usada por mobs e pelo Chefe 1).
## Pode ser dissipada instantaneamente por um ataque sônico!

@export var duration: float = 5.5
@export var radius: float = 22.0
@export var slow_factor: float = 0.42

var _timer: float = 0.0
var _affected_player: Pablita = null

func _ready() -> void:
	_timer = duration
	collision_layer = 8
	collision_mask = 1 # Jogador
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_restore_player()
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Pablita:
		_affected_player = body as Pablita
		_affected_player.speed_modifier_zone = slow_factor

func _on_body_exited(body: Node2D) -> void:
	if body == _affected_player:
		_restore_player()

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		var hb := area as Hitbox
		if hb.damage_type == Hitbox.DamageType.SONIC:
			_restore_player()
			queue_free()

func _restore_player() -> void:
	if _affected_player != null and is_instance_valid(_affected_player):
		_affected_player.speed_modifier_zone = 1.0
		_affected_player = null

func _exit_tree() -> void:
	_restore_player()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.75, 0.95, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color(0.9, 0.8, 1.0, 0.75), 1.5)
	draw_line(Vector2(-radius * 0.8, -radius * 0.8), Vector2(radius * 0.8, radius * 0.8), Color(0.9, 0.8, 1.0, 0.6), 1.2)
	draw_line(Vector2(-radius * 0.8, radius * 0.8), Vector2(radius * 0.8, -radius * 0.8), Color(0.9, 0.8, 1.0, 0.6), 1.2)
