---
name: pixel-art
description: Pixel art asset creation guidelines, sprite sheet workflows, and Godot 4.x import settings for crisp retro-style game graphics.
---

# Pixel Art Asset Creation & Integration Skill for Godot 4.x

Complete guidelines for creating, exporting, importing, and rendering pixel art assets crisply in Godot 4.x without blurring or visual artifacts.

## Godot 4.x Pixel Art Project Settings

To guarantee pixel-perfect rendering across all viewports and resolutions:

### 1. Project Settings -> Rendering -> Textures
- **Default Texture Filter:** `Nearest` (Crucial: Prevents bilinear filtering blur).
- **Default Texture Repeat:** `Disabled` (unless explicitly needed).

### 2. Project Settings -> Display -> Window
- **Viewport Width:** e.g., `320` or `480`
- **Viewport Height:** e.g., `180` or `270`
- **Window Width Override:** `1280` or `1920` (Preview scale)
- **Window Height Override:** `720` or `1080`
- **Stretch Mode:** `viewport` (rigid pixel grid) OR `canvas_items` (smoother sub-pixel movement).
- **Stretch Aspect:** `keep` (standard 16:9 pillarbox/letterbox) or `expand`.

### 3. Individual Texture Import Preset
When importing individual textures or sprite sheets:
- Open the **Import** dock.
- Set Preset to **2D Pixel**.
- Verify `Mipmaps` is unchecked.
- Click **Reimport** (and click *Set as Default for '2D Pixel'*).

## Pixel Art Canvas Standards

| Asset Type | Recommended Grid | Notes |
| :--- | :--- | :--- |
| **Micro Characters** | 16×16 px | Ultra-retro, high readability required |
| **Standard Characters** | 24×24 or 32×32 px | Most common indie size, balanced detail |
| **Large Characters / Bosses** | 48×48 to 64×64 px | High impact, expressive silhouettes |
| **Terrain Tiles** | 16×16 px | Ideal for Godot TileMapLayer autotiling |
| **UI Icons** | 16×16 or 24×24 px | Inventory, stats, action indicators |

## Palette Guidelines
- **Limit Colors:** Avoid excessive gradients; keep individual sprites to 3–6 colors.
- **Popular Curated Palettes:**
  - *Pico-8:* 16 vibrant retro colors.
  - *Endesga 32:* 32 versatile natural tones.
  - *AAP-64:* Rich fantasy palette.
- **Hue Shifting:** Shift shadow hues toward cool colors (blue/purple) and highlight hues toward warm colors (yellow/orange), rather than just adjusting brightness.

## Sprite Sheet Layout & Workflow

Maintain a strict uniform grid for sprite sheets:
- All frames must have the exact same pixel width and height (e.g., 32×32 per frame).
- Keep the character's ground contact point (pivot) at the same relative pixel position (e.g., center-bottom).

```text
spritesheet_hero_walk.png (192 x 32 px = 6 frames of 32x32)
[ Frame 1 ][ Frame 2 ][ Frame 3 ][ Frame 4 ][ Frame 5 ][ Frame 6 ]
```

### Animation Frame Budgets
- **Idle:** 4 to 6 frames (subtle breathing / bounce, 6–8 FPS)
- **Walk:** 6 to 8 frames (10–12 FPS)
- **Run:** 6 to 8 frames (12–15 FPS)
- **Jump Launch:** 1 to 2 frames (anticipation + stretch)
- **Jump Apex / Fall:** 2 frames (float + fall)
- **Attack:** 3 to 4 frames (anticipation 1 frame, active strike 1 frame, follow-through 1-2 frames)
- **Hurt / Death:** 2 to 4 frames (impact flash, recoil, collapse)

## Aseprite Automation (CLI)

Export sprite sheets directly from Aseprite via command line:
```bash
aseprite -b hero.aseprite --sheet hero_sheet.png --data hero_sheet.json --format json-array --list-tags
```

## Godot Pixel-Perfect Camera & Shimmer Prevention

To prevent tile bleeding and texture shimmering when the camera moves:
1. Enable **Snap 2D Transforms to Pixel** in `Project Settings -> Rendering -> 2D -> Snap 2D Transforms to Pixel`.
2. Enable **Snap 2D Vertices to Pixel** in `Project Settings -> Rendering -> 2D -> Snap 2D Vertices to Pixel`.
3. In your Camera script:
```gdscript
func _process(_delta: float) -> void:
    # Snap camera global position to nearest integer pixel
    global_position = global_position.round()
```

## NinePatchRect for Pixel Art UI
- Divide 9-patch frames with margin offsets equal to corner sizes (e.g. 4px corners).
- Set `Axis Stretch -> Horizontal` and `Vertical` to `Tile` (never `Stretch`, which distorts pixel geometry).
