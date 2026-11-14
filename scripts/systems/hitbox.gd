class_name Hitbox
extends Area2D

signal target_hit(target_owner: Node, damage_dealt: int, damage_type: DamageType)

enum DamageType { PHYSICAL, SONIC }

@export var damage: int = 25
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var knockback_force: float = 250.0
@export var stun_time: float = 0.2
@export var source_owner: Node2D

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		var hurtbox: Hurtbox = area as Hurtbox
		var effective_source: Node = source_owner if source_owner != null else owner
		if hurtbox.owner == effective_source or hurtbox.get_parent() == effective_source:
			return # Não acerta a si mesmo
		var knockback_dir: Vector2 = (hurtbox.global_position - global_position).normalized()
		if knockback_dir == Vector2.ZERO:
			knockback_dir = Vector2.RIGHT
		hurtbox.receive_hit(damage, damage_type, knockback_dir * knockback_force, stun_time)
		target_hit.emit(hurtbox.owner if hurtbox.owner != null else hurtbox.get_parent(), damage, damage_type)
