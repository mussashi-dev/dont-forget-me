---
name: game-feel
description: Game feel and juice techniques for Godot 4.x — screen shake, hitstop, particles, tweens, and responsive feedback systems.
---

# Game Feel Skill

Techniques for making Godot 4.x games feel responsive, satisfying, and "juicy."

## Screen Shake (Trauma System)

```gdscript
# Attach to Camera2D
class_name ShakeCamera
extends Camera2D

@export var max_shake_offset: Vector2 = Vector2(8, 6)
@export var max_shake_roll: float = 0.05
@export var shake_decay: float = 3.0  # how fast trauma fades

var trauma: float = 0.0  # current trauma (0-1)
var noise := FastNoiseLite.new()
var noise_y: int = 0

func _ready() -> void:
    noise.seed = randi()
    noise.frequency = 4.0

func _process(delta: float) -> void:
    if trauma > 0:
        trauma = maxf(trauma - shake_decay * delta, 0.0)
        _apply_shake()
    else:
        offset = Vector2.ZERO
        rotation = 0.0

func add_trauma(amount: float) -> void:
    trauma = minf(trauma + amount, 1.0)

func _apply_shake() -> void:
    var shake := trauma * trauma  # quadratic for feel
    noise_y += 1
    offset.x = max_shake_offset.x * shake * noise.get_noise_2d(noise.seed, noise_y)
    offset.y = max_shake_offset.y * shake * noise.get_noise_2d(noise.seed * 2, noise_y)
    rotation = max_shake_roll * shake * noise.get_noise_2d(noise.seed * 3, noise_y)
```

Usage: `camera.add_trauma(0.5)` on hit, `camera.add_trauma(1.0)` on big explosion.

## Hitstop (Freeze Frames)

```gdscript
# In an autoload: res://autoload/game_effects.gd
extends Node

func hitstop(duration: float = 0.05) -> void:
    Engine.time_scale = 0.01
    await get_tree().create_timer(duration, true, false, true).timeout  # process_always=true
    Engine.time_scale = 1.0
```

Usage: `GameEffects.hitstop(0.08)` when landing a heavy attack.

## Squash & Stretch

```gdscript
func squash() -> void:
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
    tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.05)
    tween.tween_property(sprite, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

func stretch_on_jump() -> void:
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.08)
    tween.tween_property(sprite, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

func land_squash() -> void:
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.05)
    tween.tween_property(sprite, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
```

## Flash White on Hit (Shader)

```gdscript
# res://shaders/flash_white.gdshader
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, flash_color * tex.a, flash_amount);
}

# Usage in GDScript:
func flash_hit() -> void:
    (sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", 1.0)
    var tween := create_tween()
    tween.tween_property(sprite.material, "shader_parameter/flash_amount", 0.0, 0.15)
```

## Knockback

```gdscript
var knockback_velocity: Vector2 = Vector2.ZERO

func apply_knockback(direction: Vector2, force: float) -> void:
    knockback_velocity = direction.normalized() * force

func _physics_process(delta: float) -> void:
    # Apply knockback
    velocity += knockback_velocity
    knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800 * delta)
    move_and_slide()
```

## Particles — Hit Effect

```gdscript
# GPUParticles2D settings for hit sparks:
# - amount: 8
# - one_shot: true
# - explosiveness: 1.0
# - lifetime: 0.3
# - Process Material:
#   - direction: (0, -1) with spread 45°
#   - initial_velocity: 100-200
#   - gravity: (0, 400)
#   - scale: 2→0 curve
#   - color: white → yellow → orange

func spawn_hit_particles(pos: Vector2) -> void:
    var particles := hit_particles_scene.instantiate()
    particles.global_position = pos
    particles.emitting = true
    get_tree().current_scene.add_child(particles)
    # Auto-free after emission
    await get_tree().create_timer(particles.lifetime).timeout
    particles.queue_free()
```

## Damage Numbers (Floating Text)

```gdscript
class_name DamageNumber
extends Node2D

@onready var label: Label = $Label

func _ready() -> void:
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:y", position.y - 40, 0.6).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.3)
    tween.chain().tween_callback(queue_free)

func set_value(amount: int, is_crit: bool = false) -> void:
    label.text = str(amount)
    if is_crit:
        label.add_theme_color_override("font_color", Color.YELLOW)
        label.add_theme_font_size_override("font_size", 24)
        scale = Vector2(1.5, 1.5)
```

## Trail Effect (Line2D)

```gdscript
class_name Trail
extends Line2D

@export var trail_length: int = 10
var target: Node2D

func _process(_delta: float) -> void:
    if not target:
        return
    global_position = Vector2.ZERO
    add_point(target.global_position)
    while get_point_count() > trail_length:
        remove_point(0)
```

## Slow Motion

```gdscript
func enter_slow_mo(time_scale: float = 0.3, duration: float = 1.0) -> void:
    Engine.time_scale = time_scale
    # Keep UI and audio at normal speed with process_always timers
    await get_tree().create_timer(duration * time_scale, true, false, true).timeout
    Engine.time_scale = 1.0
```

## Game Feel Checklist

| Action | Feedback to Add |
|--------|----------------|
| Jump | Squash on launch, stretch in air, dust particles, SFX |
| Land | Squash, dust particles, screen shake (small), SFX |
| Attack hit | Hitstop, screen shake, particles, flash white, knockback, SFX |
| Take damage | Flash red/white, invincibility blink, screen shake, controller rumble |
| Collect item | Scale pop tween, particles, UI animation, SFX |
| Dash | Speed lines, ghost trail, SFX, brief invincibility |
| Death | Slow motion, particles, screen shake, fade out |
| Menu select | Scale bounce, SFX, highlight animation |
