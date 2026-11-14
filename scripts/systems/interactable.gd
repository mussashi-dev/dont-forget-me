class_name Interactable
extends Area2D

signal interacted(by_who: Node2D)
signal focused
signal unfocused

@export var prompt_message: String = "Interagir"
@export var is_active: bool = true
@export var interaction_priority: int = 0

func _ready() -> void:
	add_to_group("interactables")
	monitoring = true
	monitorable = true

func interact(by_who: Node2D) -> void:
	if not is_active:
		return
	interacted.emit(by_who)

func gain_focus() -> void:
	focused.emit()

func lose_focus() -> void:
	unfocused.emit()
