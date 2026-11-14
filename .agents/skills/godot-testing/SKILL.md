---
name: godot-testing
description: Testing strategies and frameworks for Godot 4.x games, including unit tests, integration tests, and debugging.
---

# Godot 4.x Testing & Quality Assurance Skill

Complete methodology for automated testing, unit testing, scene integration testing, and debugging in Godot 4.x projects.

## Testing Frameworks Overview

The two primary testing frameworks for Godot 4.x:
1. **GUT (Godot Unit Testing):** Most widely used, extensive assertion library, editor panel and CLI runner.
2. **gdUnit4:** Modern, fluent assertion API, advanced mocking and fixture capabilities.

## GUT Framework Setup & Architecture

### Directory Structure
```text
res://
├── test/
│   ├── unit/
│   │   ├── test_player_controller.gd
│   │   ├── test_health_component.gd
│   │   └── test_inventory.gd
│   ├── integration/
│   │   ├── test_combat_flow.gd
│   │   └── test_level_transition.gd
│   └── gut_test.gd (runner script)
```

### Writing a Unit Test (GUT)

```gdscript
# res://test/unit/test_health_component.gd
extends GutTest

var health_comp: HealthComponent

func before_each() -> void:
    health_comp = HealthComponent.new()
    health_comp.max_health = 100
    add_child_autofree(health_comp)

func test_initial_health() -> void:
    assert_eq(health_comp.health, 100, "Health should initialize to max_health")

func test_take_damage() -> void:
    health_comp.take_damage(30)
    assert_eq(health_comp.health, 70, "Health should decrease by damage amount")

func test_damage_cannot_go_below_zero() -> void:
    health_comp.take_damage(150)
    assert_eq(health_comp.health, 0, "Health should clamp to zero")

func test_died_signal_emitted_on_zero() -> void:
    watch_signals(health_comp)
    health_comp.take_damage(100)
    assert_signal_emitted(health_comp, "died", "Should emit 'died' signal when health reaches 0")

func test_heal_caps_at_max() -> void:
    health_comp.take_damage(50)
    health_comp.heal(100)
    assert_eq(health_comp.health, 100, "Health should not exceed max_health")
```

### Testing Async and Timed Mechanics

```gdscript
# res://test/unit/test_dash_mechanic.gd
extends GutTest

var player: CharacterBody2D

func before_each() -> void:
    var scene: PackedScene = load("res://scenes/player/player.tscn")
    player = scene.instantiate()
    add_child_autofree(player)

func test_dash_cooldown() -> void:
    player._start_dash()
    assert_true(player.is_dashing, "Player should be dashing immediately")
    
    # Wait for dash duration
    await wait_seconds(player.dash_duration + 0.05)
    assert_false(player.is_dashing, "Player should finish dashing")
    assert_false(player.can_dash, "Dash should still be on cooldown")

    # Wait for cooldown to expire
    await wait_seconds(player.dash_cooldown + 0.05)
    assert_true(player.can_dash, "Dash should be ready after cooldown")
```

## Running Tests via Command Line (CLI / CI)

Run tests headlessly for continuous integration:

```bash
# Godot 4 CLI GUT runner
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

### GitHub Actions CI Workflow Example (`.github/workflows/godot-tests.yml`)

```yaml
name: "Godot 4 Unit Tests"
on: [push, pull_request]

jobs:
  gut-tests:
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.3
    steps:
      - uses: actions/checkout@v4
      - name: Run GUT Unit Tests
        run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

## Quality Assurance & Debugging Patterns

### 1. Defensive Assertions (Compile-Time / Debug)
```gdscript
func set_speed(new_speed: float) -> void:
    assert(new_speed >= 0.0, "Speed must be non-negative: %f" % new_speed)
    speed = new_speed
```

### 2. Save/Load Verification Tests
Always test serialization rounds to avoid corrupted game saves:
```gdscript
func test_save_and_load_integrity() -> void:
    var original_state := {"score": 540, "level": 3, "unlocked": ["double_jump"]}
    SaveSystem.write_save(original_state, "user://test_save.dat")
    
    var loaded_state := SaveSystem.read_save("user://test_save.dat")
    assert_eq(loaded_state.score, original_state.score)
    assert_eq(loaded_state.unlocked, original_state.unlocked)
```
