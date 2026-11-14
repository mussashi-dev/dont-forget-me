# DON'T FORGET ME — Agent Instructions (`CLAUDE.md`)

## Run and check
- **Run:** `godot --path .` (main scene: `res://scenes/ui/main_menu.tscn`)
- **Check (must pass before any commit):** `godot --headless --path . -s res://tests/test_vertical_slice.gd`
- **Engine:** Godot 4.7.2-stable (Mobile renderer, GDScript with mandatory static typing)
- **Never edit:** `.godot/`, `*.uid` (engine-generated), `assets/_reference/` (approved reference sheets)
- **Code safety:** Never modify existing `.gd`, `.tscn`, `.tres`, `.cfg`, `.godot` files without explicit user authorization (see `AGENTS.md`).
- **State:** Read `.gameforge/project.json` and `production/session-state/active.md` first; update `production/session-state/active.md` when you stop.

<!-- gameforge:start (managed by /gameforge:game-start; edit freely, re-runs update only this block) -->
## GameForge Project Configuration
- **Project:** DON'T FORGET ME (`jogo_pablita`)
- **Config:** `.gameforge/project.json` (`engine: "godot"`, `engine_version: "4.7"`, `phase: "prototype"`)
- **Session State:** `production/session-state/active.md`
- **Workspace Rules:** `AGENTS.md` and `.agents/rules/GAMEFORGE.md`

## Architecture & Conventions
- **Resolution & Scale:** 640x360 viewport (1280x720 window override), `canvas_items` stretch, pixel-perfect snap. Base scale: 1 m ≈ 18–19 px.
- **Characters:**
  - Pablita: 32x32 frame, foot pivot `offset = Vector2(-16, -30)`, foot collider `10x6`, layer 1, mask 14.
  - Pipop: single companion character (GDD v0.3), 24x24 frame, `offset = Vector2(-12, -23)`, sonic wave/grunt ability.
  - Shadows: independent `Polygon2D` nodes (not baked into sprites).
- **Layout:**
  - Engine directories: `autoload/`, `scenes/`, `scripts/`, `resources/`, `assets/`, `tests/`, `tools/`
  - GameForge overlay: `design/`, `docs/`, `production/`, `prototypes/`
- **One change per commit:** Follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`). Keep binary assets under `lfs_threshold_mb` (20 MB) or tracked in Git LFS.
<!-- gameforge:end -->
