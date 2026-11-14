class_name SonicWave
extends Node2D
## Onda sônica disparada por Pipop (representada por placeholder geométrico).
## Possui área de impacto própria e emite sinal ao atingir alvos para telemetria/depuração.

signal wave_hit_target(target_node: Node, damage_dealt: int)

@export var speed: float = 280.0
@export var lifetime: float = 0.55
@export var damage: int = 30
@export var knockback: float = 360.0
@export var area_scale: float = 1.0

@onready var hitbox: Hitbox = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var traveled_time: float = 0.0

func _ready() -> void:
	var sprite_node: Node = get_node_or_null("Sprite2D")
	if sprite_node and sprite_node is CanvasItem:
		(sprite_node as CanvasItem).visible = false

	hitbox.damage = damage
	hitbox.damage_type = Hitbox.DamageType.SONIC
	hitbox.knockback_force = knockback
	hitbox.stun_time = 0.42
	hitbox.monitoring = true
	hitbox.monitorable = true
	if not hitbox.target_hit.is_connected(_on_hitbox_target_hit):
		hitbox.target_hit.connect(_on_hitbox_target_hit)
	rotation = direction.angle()
	scale = Vector2.ONE * area_scale
	queue_redraw()

func _on_hitbox_target_hit(target_owner: Node, damage_dealt: int, _damage_type: int) -> void:
	wave_hit_target.emit(target_owner, damage_dealt)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	traveled_time += delta

	var progress: float = clampf(traveled_time / maxf(lifetime, 0.05), 0.0, 1.0)
	var scale_factor: float = area_scale * (1.0 + progress * 0.45)
	scale = Vector2(scale_factor, scale_factor)
	modulate.a = 1.0 - progress * 0.35
	queue_redraw()

	if traveled_time >= lifetime:
		queue_free()

func _draw() -> void:
	# Placeholder geométrico: arco/cone sônico ciano
	var radius: float = 18.0
	draw_circle(Vector2.ZERO, radius * 0.85, Color(0.2, 0.85, 1.0, 0.28))
	draw_arc(Vector2.ZERO, radius, -PI * 0.4, PI * 0.4, 16, Color(0.3, 0.95, 1.0, 0.95), 2.5)
	draw_arc(Vector2(-4, 0), radius * 0.6, -PI * 0.35, PI * 0.35, 12, Color(0.7, 0.98, 1.0, 0.8), 1.8)
	draw_line(Vector2(-8, 0), Vector2(radius, 0), Color(0.85, 1.0, 1.0, 0.7), 1.5)

