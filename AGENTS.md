# Godot 4.x Game Development Rules

## Code Safety
- **Never modify existing game files** (`.gd`, `.tscn`, `.tres`, `.cfg`, `.godot`) without explicit user authorization.
- When suggesting changes to existing files, always present the diff first and wait for approval.
- New files created by the agent should follow the project's existing structure and conventions.

## Godot Conventions
- Use GDScript as the primary language unless the user specifically requests C# or GDExtension.
- Follow the official GDScript style guide: `PascalCase` for classes and nodes, `snake_case` for functions and variables, `UPPER_SNAKE_CASE` for constants.
- Use static typing (type hints) in all GDScript code: `var speed: float = 200.0`.
- Prefer `@export` over magic numbers for tunable game parameters.
- Use `@onready` for node references instead of `get_node()` in `_ready()`.
- Prefer signals for upward communication and direct method calls for downward communication in the scene tree.

## Project Structure
- Follow a consistent folder structure: `res://scenes/`, `res://scripts/`, `res://assets/`, `res://resources/`, `res://addons/`, `res://autoload/`.
- Keep scenes and their scripts co-located or in parallel directory structures.
- Use Godot's resource system (`.tres`) for data-driven design.

## Performance
- Avoid heavy computation in `_process()` and `_physics_process()` when possible.
- Use `set_process(false)` and `set_physics_process(false)` to disable unused callbacks.
- Prefer object pooling for frequently spawned objects (bullets, particles, enemies).
- Use `call_deferred()` for operations that shouldn't happen mid-physics step.

## Testing
- Write tests for core game systems (movement, combat, inventory, save/load).
- Test edge cases: boundary conditions, zero values, maximum values.
- Verify that exported variables have sensible default values.

## Asset Pipeline
- Import pixel art textures with **Nearest** filter (never Linear) for crisp rendering.
- Use `.ogg` for music loops and `.wav` for short sound effects.
- Organize sprite sheets in consistent grid layouts.
