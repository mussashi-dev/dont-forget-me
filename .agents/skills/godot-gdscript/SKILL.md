---
name: godot-gdscript
description: Expert GDScript coding patterns, best practices, and debugging for Godot 4.x game development.
---

# Godot GDScript 4.x Skill

Expert-level GDScript guidance for Godot 4.x. Use this skill when writing, reviewing, or debugging GDScript code.

## Core Syntax & Typing

Always use **static typing** for better performance and editor autocompletion:

```gdscript
# ✅ Good — typed variables
var speed: float = 200.0
var health: int = 100
var player_name: String = "Hero"
var direction: Vector2 = Vector2.ZERO
var items: Array[String] = []
var stats: Dictionary = {}

# ✅ Type inference
var pos := Vector2(100, 200)  # inferred as Vector2

# ❌ Bad — untyped
var speed = 200
```

## Annotations

```gdscript
# @export — expose to Inspector
@export var speed: float = 200.0
@export var jump_force: float = -400.0
@export_range(0, 100, 1) var health: int = 100
@export_enum("Sword", "Bow", "Staff") var weapon: int = 0
@export var enemy_scene: PackedScene
@export_group("Movement")
@export var acceleration: float = 500.0
@export_subgroup("Air")
@export var air_friction: float = 0.1
@export_category("Combat")

# @onready — resolve node refs after _ready()
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var collision: CollisionShape2D = $CollisionShape2D

# Unique name references (%)
@onready var health_bar: ProgressBar = %HealthBar
```

## Signals

```gdscript
# Define signals
signal health_changed(new_health: int)
signal died
signal item_collected(item_name: String, quantity: int)

# Emit signals
func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health)
    if health <= 0:
        died.emit()

# Connect signals in code
func _ready() -> void:
    health_changed.connect(_on_health_changed)
    # One-shot connection
    died.connect(_on_died, CONNECT_ONE_SHOT)
    # Connect with callable
    $Button.pressed.connect(func(): print("pressed"))

func _on_health_changed(new_health: int) -> void:
    health_bar.value = new_health
```

## Coroutines & Tweens

```gdscript
# await with signals
func spawn_enemy() -> void:
    var enemy = enemy_scene.instantiate()
    add_child(enemy)
    await enemy.died  # waits for signal
    score += 100

# await with timers
func flash_damage() -> void:
    sprite.modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    sprite.modulate = Color.WHITE

# Tweens
func bounce() -> void:
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1)
    tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
    tween.tween_property(sprite, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

func fade_out_and_free() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    tween.tween_callback(queue_free)
```

## Enums & Constants

```gdscript
enum State { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE }
enum Direction { LEFT = -1, RIGHT = 1 }

const MAX_SPEED: float = 300.0
const GRAVITY: float = 980.0
const TILE_SIZE: int = 16
```

## Class Inheritance & Composition

```gdscript
# Base class — res://scripts/entity.gd
class_name Entity
extends CharacterBody2D

var health: int = 100
signal died

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        died.emit()

# Inherited class
class_name Player
extends Entity

func _ready() -> void:
    health = 150  # Override default

# Inner class
class Inventory:
    var slots: Array[Dictionary] = []
    func add_item(item: String, qty: int) -> void:
        slots.append({"item": item, "qty": qty})
```

## Autoloads (Singletons)

Register via Project → Project Settings → Autoload. Access globally:

```gdscript
# res://autoload/game_manager.gd
extends Node

var score: int = 0
var current_level: int = 1
signal score_changed(new_score: int)

func add_score(points: int) -> void:
    score += points
    score_changed.emit(score)

# Usage anywhere:
GameManager.add_score(100)
```

## Resource & Preload

```gdscript
# preload — compile-time, use for known paths
const BulletScene: PackedScene = preload("res://scenes/bullet.tscn")
const HitSound: AudioStream = preload("res://audio/sfx/hit.wav")

# load — runtime, use for dynamic paths
var level_scene := load("res://scenes/levels/level_%d.tscn" % level_num)
```

## Performance Tips

- Disable unused callbacks: `set_process(false)`, `set_physics_process(false)`
- Use object pools for bullets/particles instead of `instantiate()`/`queue_free()` every frame
- Cache node references with `@onready` — never call `get_node()` in `_process()`
- Use `is_on_floor()` cache: `var was_on_floor := is_on_floor()` before `move_and_slide()`
- Prefer `StringName` over `String` for dictionary keys accessed in loops
- Use typed arrays: `Array[int]` not `Array`

## Error Handling & Debugging

```gdscript
# Debug output
print("Position: ", position)
print_debug("Called from: ", get_stack())
push_warning("Health is very low: %d" % health)
push_error("Invalid state: %s" % State.keys()[current_state])

# Assertions (debug builds only)
assert(health >= 0, "Health cannot be negative")
assert(speed > 0, "Speed must be positive")

# Null safety
if enemy and is_instance_valid(enemy):
    enemy.take_damage(10)
```

## File I/O

```gdscript
# Save data
func save_game() -> void:
    var file := FileAccess.open("user://save.json", FileAccess.WRITE)
    var data := {"health": health, "position": {"x": position.x, "y": position.y}}
    file.store_string(JSON.stringify(data, "\t"))

# Load data
func load_game() -> void:
    if not FileAccess.file_exists("user://save.json"):
        return
    var file := FileAccess.open("user://save.json", FileAccess.READ)
    var data: Dictionary = JSON.parse_string(file.get_as_text())
    health = data.get("health", 100)
    position = Vector2(data.position.x, data.position.y)
```

## Style Guide

| Element | Convention | Example |
|---------|-----------|---------|
| Classes/Nodes | PascalCase | `PlayerController`, `EnemySpawner` |
| Functions/Vars | snake_case | `move_and_slide()`, `jump_force` |
| Constants | UPPER_SNAKE | `MAX_SPEED`, `GRAVITY` |
| Signals | snake_case (past tense) | `health_changed`, `item_collected` |
| Enums | PascalCase type, UPPER values | `enum State { IDLE, RUNNING }` |
| File names | snake_case | `player_controller.gd` |
| Booleans | is_/has_/can_ prefix | `is_alive`, `has_key`, `can_jump` |
