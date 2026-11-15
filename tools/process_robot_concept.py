"""Remove the generated concept's white backdrop and make a 32x32 robot sprite.

The source remains untouched. Background removal is edge-connected so white
metal highlights inside the robot survive. The final sprite uses a maximum of
32 RGB colors sampled from the supplied robot reference photo.

Example:
    uv run --with pillow --python 3.12 -- python tools/process_robot_concept.py \
        --concept assets/sprites/procedural/robot_concept_chatgpt.png \
        --reference "C:/Users/dann1/AppData/Local/Temp/codex-clipboard-b56dfce2-adc9-480f-bd7c-aae73a0885dd.png"
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONCEPT = ROOT / "assets/sprites/procedural/robot_concept_chatgpt.png"
OUTPUT_DIR = ROOT / "assets/sprites/procedural"
SIZE = 32
PALETTE_LIMIT = 32


def extract_reference_palette(concept: Image.Image, path: Path) -> list[tuple[int, int, int]]:
    """Combine 24 concept colors with 8 semantic colors sampled from the photo."""
    ref = Image.open(path).convert("RGB")
    pixels = [
        rgb for rgb in ref.getdata()
        if min(rgb) < 242 or max(rgb) - min(rgb) > 14
    ]
    if not pixels:
        raise ValueError(f"No foreground robot colors found in {path}")

    # Preserve the generated concept's key reds and steel shading, then reserve
    # eight slots for source-photo medoids: deep metal, silver, eye red, and gold.
    reference_strip = Image.new("RGB", (len(pixels), 1))
    reference_strip.putdata(pixels)
    reference_reduced = reference_strip.quantize(colors=PALETTE_LIMIT, method=Image.Quantize.MEDIANCUT)
    raw_reference = reference_reduced.getpalette() or []
    reference_counts = reference_reduced.getcolors(len(pixels)) or []
    ref_order = [index for _count, index in sorted(reference_counts, reverse=True)]
    source_colors = [tuple(raw_reference[index * 3:index * 3 + 3]) for index in ref_order]

    concept_pixels = [pixel[:3] for pixel in concept.getdata() if pixel[3] > 0]
    concept_strip = Image.new("RGB", (len(concept_pixels), 1))
    concept_strip.putdata(concept_pixels)
    concept_reduced = concept_strip.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
    raw_concept = concept_reduced.getpalette() or []
    concept_counts = concept_reduced.getcolors(len(concept_pixels)) or []
    concept_order = [index for _count, index in sorted(concept_counts, reverse=True)]
    concept_colors = [tuple(raw_concept[index * 3:index * 3 + 3]) for index in concept_order[:24]]

    # Select source-photo colors by semantic hue/value instead of frequency so
    # the 32px sprite keeps eye reds and warm panel accents after quantization.
    forced = (
        (17, 12, 12), (77, 74, 73), (147, 143, 138), (233, 223, 216),
        (225, 85, 77), (186, 89, 85), (255, 166, 115), (233, 170, 98),
    )
    exact_source = []
    reference_set = set(pixels)
    for desired in forced:
        nearest = min(reference_set, key=lambda color: sum((color[i] - desired[i]) ** 2 for i in range(3)))
        if nearest not in exact_source:
            exact_source.append(nearest)
    return list(dict.fromkeys(concept_colors + exact_source))[:PALETTE_LIMIT]


def palette_image(colors: list[tuple[int, int, int]]) -> Image.Image:
    padded = colors + [colors[-1]] * (PALETTE_LIMIT - len(colors))
    image = Image.new("P", (1, 1))
    image.putpalette([channel for color in padded for channel in color])
    return image


def remove_edge_white(image: Image.Image, threshold: int = 28) -> Image.Image:
    """Flood only white-ish pixels connected to canvas edges."""
    rgb = image.convert("RGB")
    magenta = (255, 0, 255)
    seeds = ((0, 0), (rgb.width - 1, 0), (0, rgb.height - 1), (rgb.width - 1, rgb.height - 1))
    for seed in seeds:
        if rgb.getpixel(seed) != magenta:
            ImageDraw.floodfill(rgb, seed, magenta, thresh=threshold)

    rgba = rgb.convert("RGBA")
    rgba.putalpha(Image.eval(rgb.convert("L"), lambda _value: 255))
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if rgb.getpixel((x, y)) == magenta:
                px[x, y] = (0, 0, 0, 0)
    return rgba


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--concept", type=Path, default=DEFAULT_CONCEPT)
    parser.add_argument("--reference", type=Path, required=True, help="Robot reference photo used to derive the 32-color palette")
    args = parser.parse_args()

    source = Image.open(args.concept).convert("RGBA")
    isolated = remove_edge_white(source)
    bounds = isolated.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Background removal erased the whole robot; check the white threshold")

    # A one-source-pixel guard preserves the outer pixel outline while cropping.
    left, top, right, bottom = bounds
    crop = isolated.crop((max(0, left - 1), max(0, top - 1), min(source.width, right + 1), min(source.height, bottom + 1)))

    # Fit the full body inside the 32px cell with a one-pixel transparent margin.
    target_w, target_h = 30, 30
    scale = min(target_w / crop.width, target_h / crop.height)
    scaled_size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    alpha = crop.getchannel("A").resize(scaled_size, Image.Resampling.LANCZOS).point(
        lambda value: 255 if value >= 128 else 0
    )
    rgb = crop.convert("RGB").resize(scaled_size, Image.Resampling.LANCZOS)

    palette_source = rgb.convert("RGBA")
    palette_source.putalpha(alpha)
    colors = extract_reference_palette(palette_source, args.reference)
    quantized = rgb.quantize(palette=palette_image(colors), dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(alpha)

    sprite = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - scaled_size[0]) // 2
    y = (SIZE - scaled_size[1]) // 2
    sprite.alpha_composite(quantized, (x, y))

    # Restore the features that matter at a 32px scale after color reduction:
    # bright eyes, red antenna tips, and two legible chest instrument windows.
    ink = (17, 13, 12, 255)          # dark outline medoid from the robot photo
    red = (225, 85, 77, 255)         # red eye/antenna medoid from the photo
    silver_glint = (233, 223, 216, 255)
    amber = (233, 170, 98, 255)
    details = ImageDraw.Draw(sprite)
    for ex in (11, 18):
        details.rectangle((ex, 6, ex + 2, 8), fill=ink)
        details.rectangle((ex + 1, 6, ex + 2, 8), fill=red)
        details.point((ex + 1, 6), fill=silver_glint)
    for ax in (8, 23):
        details.point((ax, 4), fill=red)
        details.point((ax, 3), fill=silver_glint)
    for px in (11, 17):
        details.rectangle((px, 14, px + 4, 19), fill=ink)
        details.rectangle((px + 1, 15, px + 3, 16), fill=amber)
        details.line((px + 1, 17, px + 3, 17), fill=red, width=1)
        details.point((px + 2, 18), fill=silver_glint)
    details.rectangle((14, 21, 17, 21), fill=red)

    visible_colors = {pixel[:3] for pixel in sprite.getdata() if pixel[3] > 0}
    if len(visible_colors) > PALETTE_LIMIT:
        raise ValueError(f"Sprite uses {len(visible_colors)} colors; limit is {PALETTE_LIMIT}")

    sprite_path = OUTPUT_DIR / "robot_forgotten_32x32.png"
    preview_path = OUTPUT_DIR / "robot_forgotten_32x32_preview.png"
    manifest_path = OUTPUT_DIR / "asset_manifest.json"
    sprite.save(sprite_path, optimize=True)

    scale_preview = 16
    preview_bg = Image.new("RGBA", (SIZE * scale_preview, SIZE * scale_preview), (45, 39, 52, 255))
    # Checker squares distinguish transparency from dark outlines.
    tile = 8 * scale_preview
    checker = ImageDraw.Draw(preview_bg)
    for row in range(4):
        for col in range(4):
            if (row + col) % 2:
                x0, y0 = col * tile, row * tile
                checker.rectangle((x0, y0, x0 + tile - 1, y0 + tile - 1), fill=(66, 57, 73, 255))
    preview_bg.alpha_composite(sprite.resize((SIZE * scale_preview, SIZE * scale_preview), Image.Resampling.NEAREST))
    preview_bg.save(preview_path, optimize=True)

    palette_used = sorted(visible_colors)
    manifest = {
        "robot_forgotten": {
            "source_concept": "robot_concept_chatgpt.png",
            "reference_palette_source": args.reference.name,
            "file": sprite_path.name,
            "sheet_size": {"width": SIZE, "height": SIZE},
            "frame_size": {"width": SIZE, "height": SIZE},
            "frames": {
                "idle_south": {"x": 0, "y": 0, "width": SIZE, "height": SIZE}
            },
            "palette_limit": PALETTE_LIMIT,
            "palette_used": ["#%02X%02X%02X" % color for color in palette_used],
            "transparent_background": True,
        }
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Saved {sprite_path.relative_to(ROOT)}: {sprite.size[0]}x{sprite.size[1]} RGBA")
    print(f"Saved {preview_path.relative_to(ROOT)}: nearest-neighbor 16x preview")
    print(f"Saved {manifest_path.relative_to(ROOT)}: one 32x32 frame, {len(palette_used)} reference-derived colors")
    print(f"Visible alpha bounds: {sprite.getchannel('A').getbbox()}")


if __name__ == "__main__":
    main()
