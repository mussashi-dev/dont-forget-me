"""Slice the user's final JPEG sprite and tileset boards into transparent PNGs.

The input JPEGs have a checkerboard flattened into their pixels. This script
removes only edge-connected neutral checker pixels, then exports manually
measured frame/object crops and a coordinate manifest. Coordinates refer to
the original 1600x1194 JPEG boards.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "queen": Path(r"C:\Users\dann1\OneDrive\Documents\documentos pessoais\boneca.jpeg"),
    "meia": Path(r"C:\Users\dann1\OneDrive\Documents\documentos pessoais\meia.jpeg"),
    "robot": Path(r"C:\Users\dann1\OneDrive\Documents\documentos pessoais\robo.jpeg"),
    "tileset": Path(r"C:\Users\dann1\OneDrive\Documents\documentos pessoais\tileset.jpeg"),
}


def box(x: int, y: int, right: int, bottom: int) -> tuple[int, int, int, int]:
    return x, y, right, bottom


# Each sequence follows the visible rows left-to-right. These are visual frame
# crops, not claims that the source board defines exact engine animation timing.
CHARACTERS = {
    "queen": {
        "directory": "assets/sprites/bosses/queen",
        "scale": 4.0,
        "rows": [
            ("locomotion", 60, 405, [box(65, 60, 278, 402), box(314, 60, 530, 402), box(565, 60, 780, 402), box(810, 60, 1040, 402), box(1070, 60, 1305, 402), box(1325, 60, 1545, 402)]),
            ("attack_web", 425, 810, [box(90, 425, 390, 810), box(800, 425, 1105, 810)]),
            ("hit_fall", 825, 1190, [box(70, 825, 395, 1185), box(430, 825, 805, 1185), box(1040, 825, 1535, 1185)]),
        ],
    },
    "meia": {
        "directory": "assets/sprites/bosses/meia",
        "scale": 4.0,
        "rows": [
            ("locomotion", 45, 405, [box(30, 45, 345, 405), box(355, 45, 665, 405), box(675, 45, 970, 405), box(975, 45, 1280, 405), box(1285, 45, 1575, 405)]),
            ("attack_web", 430, 805, [box(30, 430, 405, 805), box(405, 430, 815, 805), box(820, 430, 1220, 805), box(1215, 430, 1585, 805)]),
            ("impact_death", 820, 1185, [box(25, 820, 410, 1185), box(410, 820, 820, 1185), box(820, 820, 1215, 1185), box(1215, 820, 1590, 1185)]),
        ],
    },
    "robot": {
        "directory": "assets/sprites/bosses/robot",
        "scale": 4.0,
        "rows": [
            ("locomotion", 35, 405, [box(35, 35, 325, 405), box(350, 35, 660, 405), box(675, 35, 970, 405), box(980, 35, 1275, 405), box(1290, 35, 1585, 405)]),
            ("attack_sonic", 425, 800, [box(35, 425, 405, 800), box(405, 425, 1200, 800), box(1200, 425, 1590, 800)]),
            ("damage_death", 810, 1190, [box(25, 810, 520, 1190), box(520, 810, 1050, 1190), box(1050, 810, 1590, 1190)]),
        ],
    },
}


TILES = [
    ("floor_wood_clean_a", box(20, 57, 175, 220), "ground"),
    ("floor_wood_clean_b", box(20, 226, 175, 387), "ground"),
    ("floor_wood_overgrown_a", box(192, 57, 349, 220), "ground"),
    ("floor_wood_overgrown_b", box(192, 226, 349, 387), "ground"),
    ("floor_wood_broken_a", box(367, 57, 525, 220), "ground"),
    ("floor_wood_broken_b", box(367, 226, 525, 387), "ground"),
    ("forgotten_path", box(556, 57, 980, 535), "ground"),
    ("wall_wood_vines", box(998, 57, 1580, 193), "wall"),
    ("doors_and_archways", box(998, 230, 1580, 384), "wall"),
    ("rug_warm", box(998, 399, 1205, 529), "floor_detail"),
    ("rug_forgotten", box(1215, 399, 1407, 529), "floor_detail"),
    ("bed_clean", box(48, 600, 171, 783), "furniture"),
    ("nightstand", box(171, 620, 237, 710), "furniture"),
    ("bed_torn", box(238, 600, 344, 783), "furniture"),
    ("wardrobe", box(343, 600, 444, 754), "furniture"),
    ("dresser", box(452, 600, 550, 753), "furniture"),
    ("bookcase", box(558, 600, 673, 754), "furniture"),
    ("bookcase_broken", box(674, 600, 793, 754), "furniture"),
    ("chair_and_seating", box(25, 853, 252, 962), "furniture"),
    ("chest_clock_lamp", box(256, 853, 670, 962), "furniture"),
    ("potted_plants", box(815, 600, 1118, 783), "nature"),
    ("purple_vines", box(1127, 600, 1370, 796), "nature"),
    ("trees_and_shrubs", box(1266, 796, 1580, 968), "nature"),
    ("decor_webs_toys", box(22, 1016, 535, 1190), "detail"),
    ("decor_motes_crystals", box(534, 1016, 1090, 1190), "vfx"),
    ("lights_and_spirit_flames", box(1088, 1016, 1585, 1190), "light_vfx"),
]


def remove_edge_checkerboard(image: Image.Image, tolerance: int = 72) -> Image.Image:
    """Flood-fill neutral gray board pixels connected to the outside edge."""
    rgb = image.convert("RGB")
    width, height = rgb.size
    red, green, blue = rgb.split()
    high = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    low = ImageChops.darker(ImageChops.darker(red, green), blue)
    chroma = ImageChops.difference(high, low)
    neutral_lut = [255 if value <= tolerance else 0 for value in range(256)]
    brightness_lut = [255 if 125 <= value <= 235 else 0 for value in range(256)]
    neutral = chroma.point(neutral_lut)
    brightness = rgb.convert("L").point(brightness_lut)
    candidate = ImageChops.darker(neutral, brightness)
    remaining = candidate.copy()
    candidate_pixels, remaining_pixels = candidate.load(), remaining.load()
    seeds = [(x, y) for x in range(width) for y in (0, height - 1)]
    seeds.extend((x, y) for y in range(height) for x in (0, width - 1))
    for seed in seeds:
        if remaining_pixels[seed] == 255:
            ImageDraw.floodfill(remaining, seed, 0, thresh=0)
    background = ImageChops.difference(candidate, remaining)
    alpha = ImageChops.invert(background)
    rgba = image.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def remove_flattened_board_colors(image: Image.Image) -> Image.Image:
    """Remove the two JPEG checkerboard tones even inside isolated panels."""
    rgb = image.convert("RGB")
    channels = rgb.split()
    checker_mask = Image.new("L", rgb.size, 0)
    for color in ((148, 148, 148), (200, 198, 199)):
        close = []
        for channel, target in zip(channels, color):
            lut = [255 if abs(value - target) <= 23 else 0 for value in range(256)]
            close.append(channel.point(lut))
        tone_mask = ImageChops.darker(ImageChops.darker(close[0], close[1]), close[2])
        checker_mask = ImageChops.lighter(checker_mask, tone_mask)
    rgba = image.convert("RGBA")
    rgba.putalpha(ImageChops.darker(rgba.getchannel("A"), ImageChops.invert(checker_mask)))
    return rgba


def export_crop(source: Image.Image, crop: tuple[int, int, int, int], output: Path) -> dict[str, object]:
    left, top, right, bottom = crop
    output.parent.mkdir(parents=True, exist_ok=True)
    image = source.crop((left, top, right, bottom))
    image.save(output, format="PNG", optimize=True)
    return {"file": output.relative_to(ROOT).as_posix(), "source_rect": {"x": left, "y": top, "width": right-left, "height": bottom-top}, "size": {"width": image.width, "height": image.height}, "transparent_background": True}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources-dir", type=Path, help="Optional folder containing boneca.jpeg, meia.jpeg, robo.jpeg, tileset.jpeg")
    args = parser.parse_args()
    source_filenames = {"queen": "boneca.jpeg", "meia": "meia.jpeg", "robot": "robo.jpeg", "tileset": "tileset.jpeg"}
    sources = {key: (args.sources_dir / source_filenames[key]) if args.sources_dir else path for key, path in SOURCES.items()}

    manifest: dict[str, object] = {
        "schema_version": 1,
        "provenance": {
            "source": "User-supplied final JPEG sprite sheets and tileset",
            "background_processing": "Edge-connected checkerboard colors reconstructed as alpha; source JPEGs were not modified.",
            "animation_groups_are_visual_inferences": True,
            "character_identification_correction": "boneca.jpeg depicts the Dusty Queen boss, not Pablita. Pablita remains the separate red-haired protagonist asset.",
        },
        "source_dimensions": {},
    }
    for character, config in CHARACTERS.items():
        source_path = sources[character]
        source = Image.open(source_path).convert("RGB")
        cutout = remove_edge_checkerboard(source)
        manifest["source_dimensions"][source_path.name] = {"width": source.width, "height": source.height, "format": "JPEG; checker pattern reconstructed as alpha"}
        output_frames = []
        for row_name, _row_top, _row_bottom, crops in config["rows"]:
            for index, crop in enumerate(crops, 1):
                frame_name = f"{row_name}_{index:02d}"
                entry = export_crop(cutout, crop, ROOT / config["directory"] / f"{frame_name}.png")
                entry.update({"name": frame_name, "visual_group": row_name, "fps_suggested": 8 if row_name == "locomotion" else 10, "loop": row_name == "locomotion"})
                output_frames.append(entry)
        manifest[character] = {"scale_relative_to_pablita": config["scale"], "coordinate_space": "source_sheet_pixels", "frames": output_frames}

    # Keep Pablita mapped to her distinct, programmatically drawn 32x32 sheet.
    pablita_manifest_path = ROOT / "assets/sprites/procedural/manifest_assets.json"
    if pablita_manifest_path.exists():
        pablita_sheet = json.loads(pablita_manifest_path.read_text(encoding="utf-8"))
        manifest["pablita"] = {
            "scale_relative_to_pablita": 1.0,
            "sheet": "assets/sprites/procedural/" + pablita_sheet["sheet"],
            "frame_size": pablita_sheet["frame_size"],
            "frames": pablita_sheet["frames"],
            "source": "Separate procedural protagonist sheet; not boneca.jpeg.",
        }

    tile_source_path = sources["tileset"]
    tile_source = Image.open(tile_source_path).convert("RGB")
    tile_cutout = remove_flattened_board_colors(remove_edge_checkerboard(tile_source))
    manifest["source_dimensions"][tile_source_path.name] = {"width": tile_source.width, "height": tile_source.height, "format": "JPEG; checker pattern reconstructed as alpha"}
    tile_items = []
    for name, crop, category in TILES:
        entry = export_crop(tile_cutout, crop, ROOT / "assets/tilesets/final_reference" / f"{name}.png")
        entry.update({"name": name, "category": category, "godot_tile_size_hint": {"width": 32, "height": 32}, "note": "Source crop preserves original showcase scale; subdivide or scale to the 32x32 Godot grid after in-engine review."})
        tile_items.append(entry)
    manifest["tileset"] = {"coordinate_space": "source_sheet_pixels", "tile_size_reference": {"width": 32, "height": 32}, "items": tile_items}

    path = ROOT / "assets/asset_manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {sum(len(v['frames']) for k, v in manifest.items() if k in CHARACTERS)} character crops")
    print(f"Wrote {len(tile_items)} tileset/object crops")
    print(f"Manifest: {path.relative_to(ROOT)}")
    print("Source sheets: " + ", ".join(f"{key}={Image.open(p).size[0]}x{Image.open(p).size[1]}" for key, p in sources.items()))


if __name__ == "__main__":
    main()
