---
name: game-ui-ux
description: Game UI/UX design and implementation with Godot 4.x Control nodes — menus, HUDs, inventory systems, and responsive layouts.
---

# Game UI/UX Skill for Godot 4.x

Expert guidance for creating scalable, responsive, and polished game user interfaces and menus using Godot 4.x Control nodes.

## Responsive UI Architecture

### 1. Viewport & Stretch Settings
In `project.godot`:
- **Window Width/Height:** e.g., 1920×1080 (HD) or 480×270 / 320×180 (Pixel Art)
- **Stretch Mode:** `canvas_items` (preserves resolution scaling) or `viewport` (pixelated retro scaling)
- **Aspect:** `keep` (letterbox) or `expand` (shows more world on ultrawide)

### 2. Container Hierarchy
Never position UI elements manually with absolute pixels. Always use layout containers:
- `MarginContainer`: Adds padding around UI edges
- `VBoxContainer` / `HBoxContainer`: Arranges controls vertically or horizontally
- `GridContainer`: Tabular layouts (inventories, shop grids)
- `CenterContainer`: Centers menus or dialog popups
- `PanelContainer`: Background panel wrapping nested elements

```text
CanvasLayer (HUD / Menu)
└── Control (Full Rect - Anchors Preset: 15)
    └── MarginContainer (Theme overrides: margin_top=16, margin_left=16, ...)
        └── VBoxContainer
            ├── HBoxContainer (Top Bar)
            │   ├── TextureProgressBar (%HealthBar)
            │   └── Label (%ScoreLabel)
            └── Control (Spacer with size_flags_vertical = SIZE_EXPAND_FILL)
```

## HUD Implementation

```gdscript
class_name PlayerHUD
extends CanvasLayer

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
    # Connect to player or GameManager signals
    if GameManager:
        GameManager.score_changed.connect(_on_score_changed)

func update_health(current: int, max_health: int) -> void:
    health_bar.max_value = max_health
    # Smooth bar transition using Tween
    var tween := create_tween()
    tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    health_label.text = "%d / %d" % [current, max_health]

func _on_score_changed(new_score: int) -> void:
    score_label.text = "Score: %d" % new_score
    # Punch scale animation for score update
    var tween := create_tween()
    score_label.pivot_offset = score_label.size / 2.0
    tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.08)
    tween.tween_property(score_label, "scale", Vector2.ONE, 0.12)
```

## Pause Menu Implementation

**Important:** The Pause Menu node must have `process_mode = Node.PROCESS_MODE_ALWAYS` so it continues processing input when `get_tree().paused = true`.

```gdscript
class_name PauseMenu
extends Control

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    resume_button.pressed.connect(_on_resume_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"): # Escape or Start button
        toggle_pause()

func toggle_pause() -> void:
    var is_paused := not get_tree().paused
    get_tree().paused = is_paused
    visible = is_paused
    if is_paused:
        resume_button.grab_focus()

func _on_resume_pressed() -> void:
    toggle_pause()

func _on_restart_pressed() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
```

## Gamepad & Keyboard Navigation
1. Set `focus_mode` to `FOCUS_ALL` on all interactive buttons/sliders.
2. Configure `focus_neighbor_top`, `bottom`, `left`, `right` if automatic navigation is ambiguous.
3. Automatically grab focus on the initial element when opening a menu:
```gdscript
func _on_menu_opened() -> void:
    first_interactive_button.grab_focus()
```

## Inventory Drag & Drop Pattern

```gdscript
# Slot control script
extends PanelContainer
class_name InventorySlot

@export var slot_index: int = 0
var item_data: Dictionary = {}

func _get_drag_data(_at_position: Vector2) -> Variant:
    if item_data.is_empty():
        return null
    
    # Create drag preview
    var preview := TextureRect.new()
    preview.texture = item_data.get("icon")
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.custom_minimum_size = Vector2(40, 40)
    set_drag_preview(preview)
    return {"from_slot": slot_index, "item": item_data}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    return data is Dictionary and data.has("from_slot")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    var from_slot: int = data["from_slot"]
    # Notify inventory manager to swap items
    InventoryManager.swap_slots(from_slot, slot_index)
```

## Dialog Box with BBCode Typing Effect

```gdscript
class_name DialogBox
extends PanelContainer

@onready var rich_label: RichTextLabel = %RichTextLabel
@export var chars_per_second: float = 30.0

signal text_finished

func display_text(bbcode_text: String) -> void:
    rich_label.text = bbcode_text
    rich_label.visible_characters = 0
    
    var total_chars := rich_label.get_total_character_count()
    var duration := float(total_chars) / chars_per_second
    
    var tween := create_tween()
    tween.tween_property(rich_label, "visible_characters", total_chars, duration)
    await tween.finished
    text_finished.emit()
```

## Polish & UI Feedback Checklist
- **Hover/Click sounds:** Always connect button `mouse_entered` to a hover tick SFX and `pressed` to a confirmation SFX.
- **Button Tweens:** Scale up by 1.05 on focus/hover, scale down slightly on press.
- **NinePatchRect:** Use for scalable panels, borders, and modal boxes without texture distortion.
- **Theme Overrides:** Use a central `.theme` resource with custom `StyleBoxFlat` or `StyleBoxTexture` for consistent borders and colors across all widgets.
