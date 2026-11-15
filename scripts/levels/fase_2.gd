class_name Fase2Level
extends Node2D
## Fase 2: Corredor de transição entre o Quarto (madeira) e o Esquecido (roxo).

signal puzzle_door_opened
signal secret_object_revealed

@export var arena_rect: Rect2i = Rect2i(0, 0, 768, 320)

@onready var pablita: Pablita = $Pablita
@onready var hud: HUD = $HUD
@onready var corridor_layer: TileMapLayer = $CorredorTileMapLayer
@onready var resonance_crystal: ResonanceCrystal = get_node_or_null("Puzzles/ResonanceCrystal") as ResonanceCrystal
@onready var blocked_door: StaticBody2D = get_node_or_null("Puzzles/BlockedDoor") as StaticBody2D
@onready var secret_relic: CanvasItem = get_node_or_null("Puzzles/SecretRelic") as CanvasItem

func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var gm := GameManagerService.get_gm()
	if gm != null:
		gm.current_level_index = 2
		if not gm.is_pipop_acquired():
			gm.unlock_pipop()
		gm.set_game_state(GameManagerService.GameState.PLAYING)

	if pablita != null:
		pablita.add_to_group("player")
		pablita.set_camera_limits(arena_rect)

	if resonance_crystal != null and not resonance_crystal.puzzle_solved.is_connected(_on_resonance_crystal_solved):
		resonance_crystal.puzzle_solved.connect(_on_resonance_crystal_solved)

	var am := AudioManagerService.get_am()
	if am != null:
		am.set_music_for_level(2)

func _on_resonance_crystal_solved(_crystal: ResonanceCrystal) -> void:
	if blocked_door != null:
		for child: Node in blocked_door.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
		blocked_door.visible = false
		puzzle_door_opened.emit()
	if secret_relic != null:
		secret_relic.visible = true
		secret_object_revealed.emit()
	if hud != null:
		hud.set_objective_text("Passagem ressonante liberada! Avance pelo corredor.")
