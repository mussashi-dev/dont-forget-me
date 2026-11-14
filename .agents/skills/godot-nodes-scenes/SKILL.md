---
name: godot-nodes-scenes
description: Godot 4.x node hierarchy, scene composition, and architecture patterns for scalable game projects.
---

# Godot Nodes & Scenes Skill

Architecture and best practices for Godot 4.x scene tree, node lifecycle, and project structure.

## Node Lifecycle — Execution Order

```
_init()          → Object constructor (no tree access)
_enter_tree()    → Added to SceneTree (parent/children accessible)
_ready()         → All children are ready (safe to access @onready nodes)
_process(delta)  → Every visual frame (~60fps)
_physics_process(delta) → Every physics tick (default 60Hz, fixed)
_input(event)    → Raw input events (consumed with get_viewport().set_input_as_handled())
_unhandled_input(event) → Input not consumed by UI or _input()
_exit_tree()     → Removed from SceneTree
_notification()  → Low-level notifications (NOTIFICATION_WM_CLOSE_REQUEST, etc.)
```

### When to use each callback:
- **`_process`**: Visual updates, animations, UI, interpolation
- **`_physics_process`**: Movement, collision, physics logic (use `delta` here too)
- **`_input`**: Global input handling (pause, screenshot)
- **`_unhandled_input`**: Gameplay input (move, jump) — doesn't fire when UI consumes input

## Scene Communication Patterns

**Rule: Signals up, calls down.**

```gdscript
# PARENT calls DOWN to children (direct method calls)
func _on_attack_pressed() -> void:
    $Weapon.attack()  # parent calls child's method

# CHILD signals UP to parent (signals)
# In child:
signal health_depleted
func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        health_depleted.emit()

# In parent (connect in editor or code):
func _ready() -> void:
    $Player.health_depleted.connect(_on_player_died)
```

## Scene Composition vs Inheritance

**Prefer composition** — build entities from reusable component scenes:

```text
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── HealthComponent        ← reusable scene
├── HurtboxComponent       ← reusable scene
├── HitboxComponent        ← reusable scene
└── StateMachine           ← reusable scene
```

```gdscript
# res://components/health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
var health: int

func _ready() -> void:
    health = max_health

func take_damage(amount: int) -> void:
    health = maxi(health - amount, 0)
    health_changed.emit(health, max_health)
    if health == 0:
        died.emit()

func heal(amount: int) -> void:
    health = mini(health + amount, max_health)
    health_changed.emit(health, max_health)
```

## Node Groups

```gdscript
# Add to group in editor or code
add_to_group("enemies")

# Query groups
var enemies := get_tree().get_nodes_in_group("enemies")
for enemy in enemies:
    enemy.take_damage(50)

# Call method on all group members
get_tree().call_group("enemies", "take_damage", 50)

# Deferred group call (safe during physics)
get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "enemies", "queue_free")
```

## Scene Instantiation

```gdscript
@export var bullet_scene: PackedScene

func shoot() -> void:
    var bullet := bullet_scene.instantiate() as Bullet
    bullet.global_position = $Muzzle.global_position
    bullet.direction = Vector2.RIGHT * (-1 if sprite.flip_h else 1)
    get_tree().current_scene.add_child(bullet)  # add to scene root, not self
```

## Scene Transitions

```gdscript
# Simple change
get_tree().change_scene_to_file("res://scenes/levels/level_02.tscn")

# With packed scene
var next_level: PackedScene = preload("res://scenes/levels/level_02.tscn")
get_tree().change_scene_to_packed(next_level)

# With fade transition (via autoload)
# res://autoload/scene_manager.gd
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect  # full-screen black rect

func change_scene(path: String) -> void:
    var tween := create_tween()
    tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)
    tween.tween_callback(get_tree().change_scene_to_file.bind(path))
    tween.tween_property(color_rect, "modulate:a", 0.0, 0.3)
```

## Custom Resources for Data

```gdscript
# res://resources/weapon_data.gd
class_name WeaponData
extends Resource

@export var name: String = ""
@export var damage: int = 10
@export var attack_speed: float = 1.0
@export var icon: Texture2D
@export var swing_sound: AudioStream

# Create .tres in editor: New Resource → WeaponData
# Use in code:
@export var weapon: WeaponData
func attack() -> void:
    deal_damage(weapon.damage)
```

## Project Structure

```text
res://
├── addons/              # Third-party plugins
├── autoload/            # Singletons (GameManager, AudioManager, SceneManager)
│   ├── game_manager.gd
│   └── audio_manager.gd
├── assets/
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
├── components/          # Reusable component scenes
│   ├── health_component.tscn
│   ├── hitbox_component.tscn
│   └── hurtbox_component.tscn
├── resources/           # Custom Resource .tres files
│   ├── weapon_data.gd
│   └── weapons/
├── scenes/
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── enemies/
│   ├── levels/
│   ├── ui/
│   └── objects/
├── scripts/             # Standalone scripts not tied to a scene
├── shaders/
└── project.godot
```

## Saving & Loading with Resources

```gdscript
# Save
func save_game() -> void:
    var save_data := SaveData.new()
    save_data.player_position = player.global_position
    save_data.health = player.health
    save_data.inventory = player.inventory.duplicate()
    ResourceSaver.save(save_data, "user://save.tres")

# Load
func load_game() -> void:
    if ResourceLoader.exists("user://save.tres"):
        var save_data := ResourceLoader.load("user://save.tres") as SaveData
        player.global_position = save_data.player_position
        player.health = save_data.health
```

## Unique Name References (%)

```gdscript
# Mark a node as "unique" in the editor (right-click → Access as Unique Name)
# Then reference from anywhere in the scene:
@onready var health_bar: ProgressBar = %HealthBar
@onready var score_label: Label = %ScoreLabel
# Works regardless of where the node is in the tree hierarchy
```
