---
name: level-design
description: Level design principles, tools, and workflows for Godot 4.x — tilemaps, procedural generation, and spatial design.
---

# Level Design Skill

Level design principles, TileMap workflows, and procedural generation for Godot 4.x.

## Level Design Fundamentals

### Pacing & Flow
- **Introduce** — Teach a mechanic in a safe space
- **Develop** — Combine with previous mechanics
- **Twist** — Subvert expectations
- **Conclude** — Test mastery (boss/challenge)

### Leading the Player
- Light draws attention (use Light2D to guide)
- Enemies placed along the intended path
- Reward exploration with secrets off the main path
- Visual landmarks for orientation
- "Breadcrumb" collectibles along the correct path

## TileMap in Godot 4.x

Godot 4.x uses `TileMapLayer` nodes (one per layer):

```text
Level (Node2D)
├── BackgroundLayer (TileMapLayer)  ← decoration behind player
├── TerrainLayer (TileMapLayer)     ← solid ground, walls
├── ForegroundLayer (TileMapLayer)  ← decoration in front of player
├── Player
└── Enemies
```

### TileSet Setup
1. Create a TileSet resource with your spritesheet
2. Set tile size (e.g., 16×16)
3. Add physics layers for collision
4. Use **Terrain Sets** for autotiling (connect, path, or corner modes)

### Terrain (Autotile) Setup
```
Terrain set mode: Match Corners and Sides
Terrain 0: Ground
- Paint terrain bits on each tile
- Godot auto-selects correct tile variant when painting
```

## Procedural Generation Algorithms

### Drunk Walk (Random Walk)
```gdscript
func generate_drunk_walk(steps: int, start: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = [start]
    var current := start
    var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for i in steps:
        current += directions.pick_random()
        path.append(current)
    return path
```

### BSP (Binary Space Partitioning)
```gdscript
func bsp_split(rect: Rect2i, min_size: int) -> Array[Rect2i]:
    if rect.size.x <= min_size * 2 and rect.size.y <= min_size * 2:
        return [rect]
    var results: Array[Rect2i] = []
    var split_h := randf() > 0.5 if rect.size.x > min_size and rect.size.y > min_size \
        else rect.size.x <= min_size
    if split_h:
        var split := randi_range(min_size, rect.size.y - min_size)
        results.append_array(bsp_split(Rect2i(rect.position, Vector2i(rect.size.x, split)), min_size))
        results.append_array(bsp_split(Rect2i(rect.position + Vector2i(0, split), Vector2i(rect.size.x, rect.size.y - split)), min_size))
    else:
        var split := randi_range(min_size, rect.size.x - min_size)
        results.append_array(bsp_split(Rect2i(rect.position, Vector2i(split, rect.size.y)), min_size))
        results.append_array(bsp_split(Rect2i(rect.position + Vector2i(split, 0), Vector2i(rect.size.x - split, rect.size.y)), min_size))
    return results
```

### Cellular Automata (Cave Generation)
```gdscript
func cellular_automata(width: int, height: int, fill_chance: float, iterations: int) -> Array:
    # Initialize random grid
    var grid: Array = []
    for y in height:
        var row: Array = []
        for x in width:
            row.append(randf() < fill_chance)
        grid.append(row)

    # Smooth iterations
    for _i in iterations:
        var new_grid := grid.duplicate(true)
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                var neighbors := _count_neighbors(grid, x, y)
                new_grid[y][x] = neighbors >= 5
        grid = new_grid
    return grid

func _count_neighbors(grid: Array, x: int, y: int) -> int:
    var count := 0
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            if dx == 0 and dy == 0:
                continue
            if grid[y + dy][x + dx]:
                count += 1
    return count
```

## Parallax Backgrounds

```text
ParallaxBackground
├── ParallaxLayer (motion_scale: 0.1, 0.1)   ← far sky
│   └── Sprite2D
├── ParallaxLayer (motion_scale: 0.3, 0.3)   ← mountains
│   └── Sprite2D
├── ParallaxLayer (motion_scale: 0.6, 0.6)   ← trees
│   └── Sprite2D
└── ParallaxLayer (motion_scale: 0.8, 0.8)   ← near foliage
    └── Sprite2D

# Enable mirroring for seamless scroll:
# motion_mirroring = (texture_width, 0)
```

## Lighting in 2D

```gdscript
# CanvasModulate for global ambient
# Set color to dark blue for night: Color(0.1, 0.1, 0.3)

# PointLight2D for torches, lamps
# - texture: soft radial gradient
# - energy: 1.0-2.0
# - range: adjust texture_scale

# LightOccluder2D for shadow casting
# - Add to walls and solid objects
# - Set occluder polygon matching the shape
```

## Level Transitions

```gdscript
# Door/portal system
class_name LevelDoor
extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_point: String = "default"

func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        SceneManager.change_scene(target_scene, spawn_point)
```

## Performance for Large Levels

- Use **visibility culling**: nodes off-screen aren't rendered by default
- For very large TileMaps, split into chunks loaded/unloaded dynamically
- Use `VisibleOnScreenNotifier2D` to disable enemy AI when off-screen
- Prefer `StaticBody2D` over `RigidBody2D` for terrain
- Reduce physics collision shapes to simple rectangles where possible
