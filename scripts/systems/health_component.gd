class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal took_damage(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	took_damage.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0
