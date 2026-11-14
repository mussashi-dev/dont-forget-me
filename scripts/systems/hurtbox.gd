class_name Hurtbox
extends Area2D

signal hit_received(damage: int, damage_type: int, knockback: Vector2, stun_duration: float)

@export var invulnerability_duration: float = 0.3
@export var health_component: HealthComponent
@export var damage_multiplier: float = 1.0

var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = true

func _process(delta: float) -> void:
	if is_invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			is_invulnerable = false

func receive_hit(damage: int, damage_type: int, knockback: Vector2, stun_duration: float) -> void:
	if is_invulnerable:
		return

	if invulnerability_duration > 0.0:
		is_invulnerable = true
		invulnerable_timer = invulnerability_duration

	var final_damage: int = maxi(1, int(round(float(damage) * damage_multiplier))) if damage > 0 else 0
	if health_component != null and final_damage > 0:
		health_component.take_damage(final_damage)

	hit_received.emit(final_damage, damage_type, knockback, stun_duration)
