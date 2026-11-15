"""Procedurally draw Pablita and Forgotten Realm pixel-art assets with Pillow.

This generator paints every shape on the 32x32 pixel grid with Pillow; it does
not crop or reuse character pixels from the reference. Reference-derived warm
rust hair, cocoa outlines, brown skin, muted gray shirt and dark shorts are kept
as a compact palette for a clean game-ready silhouette.

Run from the repository root after reviewing this source:
    uv run --with pillow --python 3.12 -- python tools/generate_pablita_sheet.py
"""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "sprites" / "procedural"
FRAME_SIZE = 32
DIRECTIONS = ("south", "west", "north", "east")
ACTIONS = ("idle", "walk", "run")
TILE_NAMES = (
    "ground_ash", "ground_flecked", "stone_cracked", "stone_rubble",
    "crystal_floor", "crystal_cluster", "mist_overlay", "wood_stone_transition",
)

# Compact, reference-sampled colors from the supplied Pablita concept sheet.
P = {
    "outline": (31, 18, 22, 255),
    "outline_light": (55, 34, 38, 255),
    "hair_shadow": (82, 31, 31, 255),
    "hair": (121, 47, 41, 255),
    "hair_light": (151, 65, 54, 255),
    "hair_glint": (176, 81, 62, 255),
    "skin_shadow": (145, 79, 68, 255),
    "skin": (199, 126, 103, 255),
    "skin_light": (222, 152, 126, 255),
    "shirt_shadow": (112, 91, 89, 255),
    "shirt": (181, 151, 145, 255),
    "shirt_light": (212, 185, 178, 255),
    "shirt_seam": (144, 119, 119, 255),
    "shorts": (69, 52, 53, 255),
    "shorts_light": (94, 70, 68, 255),
    "leg": (190, 119, 98, 255),
    "shoe": (184, 156, 148, 255),
    "shoe_light": (220, 194, 183, 255),
}

# Cool, low-saturation Esquecido palette: violet stone, lavender crystal and
# blue-violet mist. Colors are deliberately stepped for clean pixel clusters.
E = {
    "outline": (24, 20, 39, 255),
    "deep": (40, 33, 61, 255),
    "soil": (54, 43, 75, 255),
    "soil_light": (69, 55, 91, 255),
    "stone": (82, 69, 111, 255),
    "stone_light": (112, 97, 142, 255),
    "stone_glint": (151, 137, 176, 255),
    "crystal_dark": (75, 57, 132, 255),
    "crystal": (128, 100, 202, 255),
    "crystal_light": (190, 168, 243, 255),
    "mist": (146, 151, 204, 112),
    "wood_dark": (89, 54, 49, 255),
    "wood": (135, 79, 60, 255),
    "wood_light": (174, 108, 75, 255),
}


def rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: str) -> None:
    draw.rectangle(box, fill=P[color])


def poly(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str, outline: str) -> None:
    draw.polygon(points, fill=P[color], outline=P[outline])


def hair(draw: ImageDraw.ImageDraw, facing: str, bob: int = 0) -> None:
    """Large, irregular rust curls frame the face and define her silhouette."""
    y = bob
    silhouette = [
        (8, 10 + y), (7, 7 + y), (9, 5 + y), (10, 3 + y), (13, 2 + y),
        (15, 1 + y), (19, 2 + y), (22, 3 + y), (24, 6 + y), (25, 9 + y),
        (24, 13 + y), (22, 16 + y), (19, 18 + y), (12, 17 + y),
        (9, 15 + y), (7, 13 + y),
    ]
    poly(draw, silhouette, "hair", "outline")
    # Pixel clumps break the round mass into loose curls.
    for x, yy, color in [
        (10, 5, "hair_shadow"), (14, 3, "hair_light"), (18, 4, "hair_shadow"),
        (21, 6, "hair_light"), (8, 9, "hair_shadow"), (11, 8, "hair_light"),
        (16, 6, "hair_shadow"), (20, 9, "hair_light"), (23, 11, "hair_shadow"),
        (9, 13, "hair_light"), (13, 15, "hair_shadow"), (18, 14, "hair_light"),
    ]:
        rect(draw, (x, yy + y, x + 2, yy + y + 1), color)
    rect(draw, (12, 5 + y, 13, 6 + y), "hair_glint")
    rect(draw, (19, 7 + y, 20, 8 + y), "hair_glint")

    if facing == "north":
        # Back of the head: full curls, no exposed face.
        rect(draw, (10, 11 + y, 22, 16 + y), "hair")
        rect(draw, (12, 13 + y, 16, 15 + y), "hair_shadow")
        rect(draw, (19, 12 + y, 22, 14 + y), "hair_light")
    elif facing in ("west", "east"):
        side = facing == "west"
        # Deep side fringe and a small cheek opening preserve the profile.
        if side:
            rect(draw, (8, 8 + y, 16, 15 + y), "hair")
            rect(draw, (12, 11 + y, 17, 15 + y), "skin")
            rect(draw, (12, 10 + y, 16, 11 + y), "hair_shadow")
            rect(draw, (10, 12 + y, 12, 14 + y), "hair_light")
        else:
            rect(draw, (16, 8 + y, 24, 15 + y), "hair")
            rect(draw, (15, 11 + y, 20, 15 + y), "skin")
            rect(draw, (16, 10 + y, 20, 11 + y), "hair_shadow")
            rect(draw, (21, 12 + y, 23, 14 + y), "hair_light")
    else:
        # Front-facing fringe leaves the eyes and nose visible.
        rect(draw, (9, 9 + y, 13, 13 + y), "hair_shadow")
        rect(draw, (19, 9 + y, 23, 13 + y), "hair_shadow")
        rect(draw, (12, 10 + y, 20, 15 + y), "skin")


def draw_frame(action: str, facing: str, phase: int = 0) -> Image.Image:
    im = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    moving = action != "idle"
    running = action == "run"
    bob = (1 if phase % 2 else 0) if moving else 0
    step = phase % 2 if moving else 0
    hair(d, facing, bob)

    # Neck and roomy tunic. Side directions turn the shirt profile without
    # changing the recognizable wide, soft outline.
    rect(d, (14, 16 + bob, 18, 18 + bob), "skin_shadow")
    shirt_y = 17 + bob
    shirt = [
        (12, shirt_y), (10, shirt_y + 2), (8, shirt_y + 6), (10, shirt_y + 8),
        (12, shirt_y + 7), (13, shirt_y + 9), (19, shirt_y + 9),
        (20, shirt_y + 7), (22, shirt_y + 8), (24, shirt_y + 6),
        (22, shirt_y + 2), (20, shirt_y),
    ]
    poly(d, shirt, "shirt", "outline")
    rect(d, (13, shirt_y + 1, 18, shirt_y + 3), "shirt_light")
    rect(d, (10, shirt_y + 4, 12, shirt_y + 6), "shirt_shadow")
    rect(d, (21, shirt_y + 4, 22, shirt_y + 6), "shirt_shadow")
    rect(d, (14, shirt_y + 8, 18, shirt_y + 8), "shirt_seam")

    if facing == "north":
        # Rear-facing: hair drops onto the shirt collar, with a center seam.
        rect(d, (11, shirt_y + 1, 20, shirt_y + 4), "hair")
        rect(d, (14, shirt_y + 4, 17, shirt_y + 6), "hair_shadow")
        rect(d, (15, shirt_y + 6, 15, shirt_y + 8), "shirt_seam")

    # Bare legs and two small dark shorts legs. Staggering creates a readable
    # walk/run cycle while every pixel remains on the strict 32px grid.
    rect(d, (13, 26 + bob, 18, 27 + bob), "shorts")
    rect(d, (14, 28 + bob, 15, 29 + bob), "leg")
    rect(d, (17, 28 + bob, 18, 29 + bob), "leg")
    if moving:
        left_x = 12 - step * (1 if running else 0)
        right_x = 18 + step * (1 if running else 0)
    else:
        left_x, right_x = 12, 18

    # Front/back are symmetric; profile view draws the far foot partially tucked.
    if facing in ("west", "east"):
        near_x = left_x if facing == "west" else right_x
        far_x = right_x if facing == "west" else left_x
        rect(d, (far_x, 28 + bob, far_x + 1, 29 + bob), "leg")
        rect(d, (near_x, 28 + bob, near_x + 2, 29 + bob), "leg")
        rect(d, (near_x - 1, 30, near_x + 2, 31), "shoe")
        rect(d, (near_x, 30, near_x + 1, 30), "shoe_light")
        if running:
            rect(d, (far_x + (1 if facing == "west" else -1), 30, far_x + (2 if facing == "west" else 0), 30), "shoe")
    else:
        rect(d, (left_x, 28 + bob, left_x + 1, 29 + bob), "leg")
        rect(d, (right_x, 28 + bob, right_x + 1, 29 + bob), "leg")
        rect(d, (left_x - 1, 30, left_x + 2, 31), "shoe")
        rect(d, (right_x - 1, 30, right_x + 2, 31), "shoe")
        rect(d, (left_x, 30, left_x + 1, 30), "shoe_light")
        rect(d, (right_x, 30, right_x + 1, 30), "shoe_light")

    # Hem and shorts peek below the oversized sweater.
    rect(d, (13, shirt_y + 8, 18, shirt_y + 9), "shorts")
    rect(d, (13, shirt_y + 9, 14, shirt_y + 9), "shorts_light")
    rect(d, (17, shirt_y + 9, 18, shirt_y + 9), "shorts_light")

    # Face features go over the hair base for front and profile views.
    if facing == "south":
        rect(d, (14, 11 + bob, 14, 12 + bob), "outline")
        rect(d, (18, 11 + bob, 18, 12 + bob), "outline")
        rect(d, (15, 14 + bob, 17, 14 + bob), "skin_shadow")
        rect(d, (13, 13 + bob, 13, 14 + bob), "skin_light")
    elif facing == "west":
        rect(d, (12, 12 + bob, 12, 13 + bob), "outline")
        rect(d, (11, 14 + bob, 12, 14 + bob), "skin_light")
    elif facing == "east":
        rect(d, (19, 12 + bob, 19, 13 + bob), "outline")
        rect(d, (19, 14 + bob, 20, 14 + bob), "skin_light")

    # Animation cues: lifted forearm and sleeve for the moving frames.
    if moving:
        arm_x = 22 if facing != "west" else 8
        rect(d, (arm_x, shirt_y + 4 - step, arm_x + 1, shirt_y + 6 - step), "skin")
        if running:
            rect(d, (arm_x, shirt_y + 3 - step, arm_x + 2, shirt_y + 4 - step), "shirt_light")

    return im


def draw_tile(name: str, seed: int) -> Image.Image:
    """Paint one seamless 32px terrain tile, or a transparent mist overlay."""
    tile = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    rng = random.Random(seed)
    if name == "mist_overlay":
        # Transparent wisps are an overlay layer above the solid floor tiles.
        for x, y, w, h in ((1, 8, 11, 3), (12, 18, 13, 3), (5, 25, 10, 2)):
            d.rectangle((x, y, x + w, y + h), fill=E["mist"])
            d.rectangle((x + 2, y - 1, x + w - 2, y + h - 1), fill=E["mist"])
        return tile

    # Base fill: ground tiles are intentionally opaque so Godot can use them as
    # actual TileMapLayer floor cells; decorative details remain pixel crisp.
    base = {
        "ground_ash": "soil",
        "ground_flecked": "soil",
        "stone_cracked": "deep",
        "stone_rubble": "deep",
        "crystal_floor": "soil",
        "crystal_cluster": "deep",
        "wood_stone_transition": "soil",
    }[name]
    tile.paste(E[base], (0, 0, FRAME_SIZE, FRAME_SIZE))

    if name in ("ground_ash", "ground_flecked"):
        # Sparse deterministic grain avoids obvious repeating checker patterns.
        count = 9 if name == "ground_ash" else 17
        colors = ("deep", "soil_light", "stone")
        for _ in range(count):
            x, y = rng.randrange(1, 31), rng.randrange(1, 31)
            color = colors[rng.randrange(len(colors))]
            d.rectangle((x, y, x + rng.choice((0, 1)), y), fill=E[color])
        d.rectangle((4, 7, 5, 7), fill=E["soil_light"])
        d.rectangle((24, 22, 25, 22), fill=E["deep"])

    elif name == "stone_cracked":
        # Thin stepped fault line with muted edges, never antialiased.
        d.line(((5, 0), (5, 7), (10, 7), (10, 13), (15, 13), (15, 20), (22, 20), (22, 31)), fill=E["outline"], width=2)
        d.line(((6, 0), (6, 6), (11, 6), (11, 12), (16, 12), (16, 19), (23, 19), (23, 31)), fill=E["stone_light"], width=1)
        d.rectangle((18, 4, 24, 4), fill=E["stone"])
        d.rectangle((19, 5, 23, 5), fill=E["stone_light"])

    elif name == "stone_rubble":
        for x, y, w, h in ((3, 5, 6, 4), (18, 3, 8, 5), (11, 15, 7, 5), (22, 23, 6, 5), (2, 25, 6, 4)):
            d.rectangle((x, y, x + w, y + h), fill=E["outline"])
            d.rectangle((x + 1, y + 1, x + w - 1, y + h - 1), fill=E["stone"])
            d.rectangle((x + 1, y + 1, x + w - 2, y + 1), fill=E["stone_light"])

    elif name in ("crystal_floor", "crystal_cluster"):
        # Crystal silhouettes use stepped polygon facets and a small highlight.
        centers = ((9, 15, 6),) if name == "crystal_floor" else ((10, 19, 8), (23, 25, 5))
        for cx, cy, height in centers:
            top = cy - height
            points = [(cx, top), (cx + 3, top + 4), (cx + 3, cy - 2), (cx + 5, cy), (cx - 4, cy), (cx - 2, cy - 3), (cx - 2, top + 4)]
            d.polygon(points, fill=E["crystal"], outline=E["outline"])
            d.polygon([(cx, top + 1), (cx + 1, top + 4), (cx + 1, cy - 2), (cx - 1, cy - 1), (cx - 1, top + 4)], fill=E["crystal_light"])
        if name == "crystal_floor":
            d.rectangle((18, 24, 19, 25), fill=E["crystal_dark"])
            d.rectangle((21, 22, 21, 23), fill=E["crystal_light"])

    elif name == "wood_stone_transition":
        # A hand-pixelled diagonal seam moves the warm wood into cool stone.
        for y in range(FRAME_SIZE):
            seam_x = 13 + y // 4
            d.line((0, y, seam_x, y), fill=E["wood"])
            d.line((0, y, seam_x, y), fill=E["wood_light"], width=1)
            d.line((seam_x + 1, y, 31, y), fill=E["soil"])
        for y in (5, 12, 20, 27):
            d.line((0, y, 13 + y // 4, y), fill=E["wood_dark"], width=1)
        d.line((19, 6, 19, 10, 23, 10, 23, 14, 27, 14), fill=E["stone_light"], width=1)

    return tile


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE * 3), (0, 0, 0, 0))
    frames: dict[str, object] = {}

    for row, action in enumerate(ACTIONS):
        for col, direction in enumerate(DIRECTIONS):
            frame = draw_frame(action, direction, phase=col + row)
            x, y = col * FRAME_SIZE, row * FRAME_SIZE
            sheet.alpha_composite(frame, (x, y))
            frames[f"{action}_{direction}"] = {
                "x": x,
                "y": y,
                "width": FRAME_SIZE,
                "height": FRAME_SIZE,
                "column": col,
                "row": row,
            }

    sheet_path = OUTPUT_DIR / "pablita_4dir_3action.png"
    sheet.save(sheet_path, optimize=True)
    # Eight 32x32 forgotten-world tiles in a Godot-friendly 4x2 atlas.
    tile_sheet = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE * 2), (0, 0, 0, 0))
    tiles: dict[str, object] = {}
    for index, name in enumerate(TILE_NAMES):
        col, row = index % 4, index // 4
        x, y = col * FRAME_SIZE, row * FRAME_SIZE
        tile_sheet.alpha_composite(draw_tile(name, seed=100 + index), (x, y))
        tiles[name] = {"x": x, "y": y, "width": FRAME_SIZE, "height": FRAME_SIZE, "column": col, "row": row}
    tileset_path = OUTPUT_DIR / "esquecido_tileset_4x2.png"
    tile_sheet.save(tileset_path, optimize=True)

    complete_manifest = {
        "format": "Godot AtlasTexture-compatible pixel art assets",
        "frame_size": {"width": FRAME_SIZE, "height": FRAME_SIZE},
        "palette_pablita_rgba": {name: [*rgba] for name, rgba in P.items()},
        "palette_esquecido_rgba": {name: [*rgba] for name, rgba in E.items()},
        "sheets": {
            "pablita": {"file": "pablita_4dir_3action.png", "width": 128, "height": 96, "columns": list(DIRECTIONS), "rows": list(ACTIONS), "frames": frames},
            "esquecido": {"file": "esquecido_tileset_4x2.png", "width": 128, "height": 64, "columns": 4, "rows": 2, "tiles": tiles, "tile_alpha_note": "mist_overlay is transparent; terrain cells have opaque floor fills"},
        },
    }
    (OUTPUT_DIR / "asset_manifest.json").write_text(
        json.dumps(complete_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # A nearest-neighbor enlargement is for review only; place it on a muted
    # background so the sheet's true transparency is easy to inspect.
    scale = 8
    preview = Image.new("RGBA", (sheet.width * scale, sheet.height * scale), (51, 43, 53, 255))
    preview.alpha_composite(sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST))
    grid = ImageDraw.Draw(preview)
    for x in range(0, preview.width + 1, FRAME_SIZE * scale):
        grid.line((x, 0, x, preview.height), fill=(103, 82, 96, 255), width=2)
    for y in range(0, preview.height + 1, FRAME_SIZE * scale):
        grid.line((0, y, preview.width, y), fill=(103, 82, 96, 255), width=2)
    preview.save(OUTPUT_DIR / "pablita_4dir_3action_preview.png", optimize=True)
    print(f"Generated {sheet_path.relative_to(ROOT)} ({sheet.width}x{sheet.height}, RGBA)")
    print(f"Generated {tileset_path.relative_to(ROOT)} (8 tiles, 4x2 atlas)")
    print(f"Generated {(OUTPUT_DIR / 'asset_manifest.json').relative_to(ROOT)} (12 frames + 8 tiles)")
    print(f"Generated {(OUTPUT_DIR / 'pablita_4dir_3action_preview.png').relative_to(ROOT)} (nearest-neighbor preview)")


if __name__ == "__main__":
    main()
