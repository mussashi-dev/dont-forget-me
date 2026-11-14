---
name: godot-2d-movement
description: 2D character movement systems for Godot 4.x — platformers, top-down, physics-based, and kinematic controllers.
---

# Godot 2D Movement Skill

Comprehensive 2D movement patterns for Godot 4.x with CharacterBody2D.

## Platformer Movement — Complete Controller

```gdscript
class_name PlatformerController
extends CharacterBody2D

# Movement
@export var speed: float = 200.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var air_friction: float = 200.0

# Jumping
@export var jump_force: float = -350.0
@export var jump_cut_multiplier: float = 0.4
@export var gravity: float = 980.0
@export var max_fall_speed: float = 600.0

# Coyote time & jump buffer
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12

# Double jump
@export var max_jumps: int = 2

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jumps_remaining: int = 0
var was_on_floor: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
    var on_floor := is_on_floor()

    # Coyote time
    if on_floor:
        coyote_timer = coyote_time
        jumps_remaining = max_jumps
    else:
        coyote_timer -= delta

    # Jump buffer
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time
    else:
        jump_buffer_timer -= delta

    # Gravity
    if not on_floor:
        velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

    # Jump
    if jump_buffer_timer > 0.0:
        if coyote_timer > 0.0 or jumps_remaining > 0:
            velocity.y = jump_force
            jump_buffer_timer = 0.0
            coyote_timer = 0.0
            jumps_remaining -= 1

    # Variable jump height — cut jump short on release
    if Input.is_action_just_released("jump") and velocity.y < 0:
        velocity.y *= jump_cut_multiplier

    # Horizontal movement
    var input_dir := Input.get_axis("move_left", "move_right")
    if input_dir != 0:
        velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
    else:
        var fric := friction if on_floor else air_friction
        velocity.x = move_toward(velocity.x, 0, fric * delta)

    # Flip sprite
    if input_dir != 0:
        sprite.flip_h = input_dir < 0

    # Animate
    _update_animation(on_floor, input_dir)

    was_on_floor = on_floor
    move_and_slide()

func _update_animation(on_floor: bool, input_dir: float) -> void:
    if not on_floor:
        sprite.play("jump" if velocity.y < 0 else "fall")
    elif abs(input_dir) > 0:
        sprite.play("run")
    else:
        sprite.play("idle")
```

## Top-Down 8-Directional Movement

```gdscript
class_name TopDownController
extends CharacterBody2D

@export var speed: float = 150.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

    if input != Vector2.ZERO:
        # Normalize to prevent faster diagonal movement
        velocity = velocity.move_toward(input.normalized() * speed, acceleration * delta)
        _update_facing(input)
        sprite.play("walk")
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
        sprite.play("idle")

    move_and_slide()

func _update_facing(input: Vector2) -> void:
    if abs(input.x) > abs(input.y):
        sprite.flip_h = input.x < 0
```

## Wall Jump & Wall Slide

```gdscript
@export var wall_slide_speed: float = 50.0
@export var wall_jump_force: Vector2 = Vector2(300, -350)
@export var wall_stick_time: float = 0.15

var wall_stick_timer: float = 0.0

func _physics_process(delta: float) -> void:
    var on_wall := is_on_wall_only()

    # Wall slide — slow descent when pressing into wall
    if on_wall and velocity.y > 0:
        velocity.y = minf(velocity.y, wall_slide_speed)
        sprite.play("wall_slide")

    # Wall jump
    if on_wall and Input.is_action_just_pressed("jump"):
        var wall_normal := get_wall_normal()
        velocity = Vector2(wall_normal.x * wall_jump_force.x, wall_jump_force.y)
        jumps_remaining = max_jumps - 1
```

## Dash Mechanic

```gdscript
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.RIGHT

func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("dash") and can_dash:
        _start_dash()

    if is_dashing:
        velocity = dash_direction * dash_speed
        # Skip gravity during dash

func _start_dash() -> void:
    is_dashing = true
    can_dash = false
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    dash_direction = input.normalized() if input != Vector2.ZERO else Vector2((-1 if sprite.flip_h else 1), 0)

    # Dash trail effect
    modulate.a = 0.5

    await get_tree().create_timer(dash_duration).timeout
    is_dashing = false
    modulate.a = 1.0

    await get_tree().create_timer(dash_cooldown).timeout
    can_dash = true
```

## State Machine Pattern

```gdscript
class_name PlayerStateMachine
extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE }
var current_state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE: _state_idle(delta)
        State.RUN: _state_run(delta)
        State.JUMP: _state_jump(delta)
        State.FALL: _state_fall(delta)
        State.DASH: _state_dash(delta)
        State.WALL_SLIDE: _state_wall_slide(delta)
    move_and_slide()

func _change_state(new_state: State) -> void:
    _exit_state(current_state)
    current_state = new_state
    _enter_state(new_state)

func _enter_state(state: State) -> void:
    match state:
        State.JUMP: velocity.y = jump_force
        State.DASH: _start_dash()

func _exit_state(state: State) -> void:
    pass  # cleanup for each state

func _state_idle(delta: float) -> void:
    _apply_gravity(delta)
    _apply_friction(delta)
    if Input.get_axis("move_left", "move_right") != 0:
        _change_state(State.RUN)
    if Input.is_action_just_pressed("jump") and is_on_floor():
        _change_state(State.JUMP)
    if not is_on_floor():
        _change_state(State.FALL)
```

## Camera Setup

```gdscript
# Camera2D settings for platformer
# - Position Smoothing: enabled, speed ~5
# - Drag: horizontal enabled, margins 0.2
# - Limits: set to level bounds

# Pixel-perfect camera snap
func _process(_delta: float) -> void:
    global_position = global_position.round()
```

## Slopes & One-Way Platforms

```gdscript
# CharacterBody2D properties for slopes:
# floor_max_angle = deg_to_rad(46)  # max slope angle walkable
# floor_snap_length = 8.0  # snap to floor on slopes
# floor_stop_on_slope = true  # don't slide down slopes when idle

# One-way platforms: set collision shape's one_way_collision = true
# Drop through:
func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("move_down") and is_on_floor():
        position.y += 1  # nudge through
```

## Collision Layers Best Practice

| Layer | Name | Use |
|-------|------|-----|
| 1 | World | Static terrain, walls |
| 2 | Player | Player body |
| 3 | Enemy | Enemy bodies |
| 4 | PlayerHurtbox | Areas that damage player |
| 5 | EnemyHurtbox | Areas that damage enemies |
| 6 | Pickup | Collectibles, items |
| 7 | Interactable | Doors, NPCs, chests |
| 8 | Projectile | Bullets, arrows |
