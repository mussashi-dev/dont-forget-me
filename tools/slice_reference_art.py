"""Cut the supplied DFM art boards into native 32x32 gameplay sprites.

Usage:
    python tools/slice_reference_art.py \
        --characters-zip 01_personagens.zip \
        --environment-zip ambientacao.zip

The script reads the source ZIPs in place and writes only project assets and
their SpriteFrames resources. Source images remain untouched.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageChops, ImageFilter, ImageOps


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CHARACTER_FILES = {
    "pablita": "01_personagens/Pablita/02_a_clean_game_art_sprite_sheet_on_a_dark_muted_pur.png",
    "pipop": "01_personagens/Pipop/02_a_dark_purple_pixel_art_sprite_sheet_image_in_a_cu.png",
}
ENVIRONMENT_FILES = {
    "refined": "ambientação/03_a_large_polished_pixel_art_game_asset_sheet_and_l.png",
    "overview": "ambientação/02_a_high_resolution_pixel_art_game_asset_sheet_til.png",
}

# (left, top, width, height), measured from separated foreground components.
PABLITA_IDLE = {
    "south": (38, 815, 105, 129),
    "east": (161, 816, 87, 129),
    "north": (268, 816, 84, 129),
    "west": (374, 817, 90, 127),
}
PABLITA_WALK = {
    "north": (494, 73, 99, 159),
    "east": (610, 76, 92, 155),
    "south": (724, 73, 89, 158),
    "west": (835, 76, 92, 156),
}
PABLITA_DASH = {
    "north": (1015, 74, 102, 152),
    "east": (1141, 76, 99, 151),
    "south": (1267, 79, 93, 148),
    "west": (1389, 78, 97, 145),
}
PABLITA_ATTACK = [
    (576, 319, 98, 146),
    (693, 319, 98, 147),
    (813, 313, 110, 158),
    (951, 318, 96, 153),
]

PIPOP_IDLE = {
    "south": (42, 155, 82, 97),
    "north": (419, 153, 62, 96),
    "east": (1099, 153, 73, 98),
}
PIPOP_WALK = {
    "south": [
        (523, 156, 82, 97),
        (624, 156, 79, 96),
    ],
    "north": [
        (813, 155, 71, 96),
        (991, 153, 66, 97),
    ],
    "east": [
        (1099, 153, 73, 98),
        (1185, 157, 73, 98),
        (1268, 157, 75, 98),
        (1353, 155, 73, 96),
    ],
}
PIPOP_ROAR = [
    (50, 569, 88, 114),
    (185, 573, 87, 106),
    (312, 575, 83, 104),
    (434, 574, 80, 105),
    (552, 575, 71, 103),
]


def read_image(archive: ZipFile, member: str) -> Image.Image:
    with archive.open(member) as source:
        return Image.open(source).convert("RGBA")


def alpha_cutout(source: Image.Image, box: tuple[int, int, int, int], cutoff: int) -> Image.Image:
    x, y, width, height = box
    image = source.crop((x, y, x + width, y + height))
    image.putalpha(image.getchannel("A").point(lambda alpha: 255 if alpha >= cutoff else 0))
    return image


def largest_component(mask: Image.Image) -> Image.Image:
    """Keep the main connected foreground shape in a compact Pillow mask."""
    mask = mask.convert("L")
    width, height = mask.size
    pixels = mask.load()
    visited = bytearray(width * height)
    largest: list[int] = []

    for y in range(height):
        for x in range(width):
            start = y * width + x
            if visited[start] or pixels[x, y] == 0:
                continue
            visited[start] = 1
            pending = [start]
            component: list[int] = []
            while pending:
                current = pending.pop()
                component.append(current)
                cx = current % width
                cy = current // width
                for ny in range(max(0, cy - 1), min(height, cy + 2)):
                    for nx in range(max(0, cx - 1), min(width, cx + 2)):
                        neighbor = ny * width + nx
                        if not visited[neighbor] and pixels[nx, ny] != 0:
                            visited[neighbor] = 1
                            pending.append(neighbor)
            if len(component) > len(largest):
                largest = component

    result = Image.new("L", mask.size, 0)
    result_pixels = result.load()
    for index in largest:
        result_pixels[index % width, index // width] = 255
    return result


def pipop_cutout(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Remove the dark board, retaining the plush and its dark pixel outline."""
    x, y, width, height = box
    image = source.crop((x, y, x + width, y + height)).convert("RGBA")
    red, green, blue, _alpha = image.split()
    red_core = red.point(lambda value: 255 if value > 110 else 0)
    blue_core = blue.point(lambda value: 255 if value > 80 else 0)
    pink_core = ImageChops.subtract(red, green).point(lambda value: 255 if value > 40 else 0)
    mask = ImageChops.darker(ImageChops.darker(red_core, blue_core), pink_core)
    mask = largest_component(mask.filter(ImageFilter.MaxFilter(7)))
    image.putalpha(mask)
    return image


def fit_to_canvas(image: Image.Image, size: tuple[int, int], *, bottom_align: bool = True) -> Image.Image:
    """Resize with nearest-neighbor, preserve aspect ratio, and add transparency."""
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Cannot place an empty sprite")
    image = image.crop(bounds)
    target_width, target_height = size
    ratio = min(target_width / image.width, target_height / image.height)
    scaled_size = (
        max(1, round(image.width * ratio)),
        max(1, round(image.height * ratio)),
    )
    image = image.resize(scaled_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    left = (target_width - image.width) // 2
    top = target_height - image.height if bottom_align else (target_height - image.height) // 2
    canvas.alpha_composite(image, (left, top))
    return canvas


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def godot_frames_resource(animations: list[tuple[str, list[str], bool, float]]) -> str:
    resource_paths: list[str] = []
    for _name, paths, _loop, _speed in animations:
        for path in paths:
            if path not in resource_paths:
                resource_paths.append(path)
    ids = {path: f"tex{index}" for index, path in enumerate(resource_paths, start=1)}
    lines = ["[gd_resource type=\"SpriteFrames\" format=3]", ""]
    for path in resource_paths:
        godot_path = "res://" + Path(path).as_posix()
        lines.append(f'[ext_resource type="Texture2D" path="{godot_path}" id="{ids[path]}"]')
    lines.extend(["", "[resource]", "animations = ["])
    entries: list[str] = []
    for name, paths, loop, speed in animations:
        frame_rows = ", ".join(
            f'{{"duration": 1.0, "texture": ExtResource("{ids[path]}")}}'
            for path in paths
        )
        entries.append(
            "{\n"
            f'"frames": [{frame_rows}],\n'
            f'"loop": {1 if loop else 0},\n'
            f'"name": &"{name}",\n'
            f'"speed": {speed:.1f}\n'
            "}"
        )
    lines.append(",\n".join(entries))
    lines.extend(["]",
                  ""])
    return "\n".join(lines)


def texture_path(root: Path, relative_path: str) -> str:
    return str(root / relative_path)


def build_pablita(source: Image.Image, root: Path) -> None:
    out_dir = root / "assets/sprites/pablita"
    paths: dict[str, str] = {}

    def save(name: str, box: tuple[int, int, int, int]) -> str:
        path = out_dir / f"{name}.png"
        sprite = fit_to_canvas(alpha_cutout(source, box, 128), (32, 32))
        save_png(sprite, path)
        relative = path.relative_to(root).as_posix()
        paths[name] = relative
        return relative

    idle_paths: dict[str, str] = {}
    walk_paths: dict[str, str] = {}
    dash_paths: dict[str, str] = {}
    for direction, box in PABLITA_IDLE.items():
        idle_paths[direction] = save(f"idle_{direction}", box)
    for direction, box in PABLITA_WALK.items():
        walk_paths[direction] = save(f"walk_{direction}", box)
    for direction, box in PABLITA_DASH.items():
        dash_paths[direction] = save(f"dash_{direction}", box)
    attack_paths = [save(f"attack_phys_{index}", box) for index, box in enumerate(PABLITA_ATTACK)]

    animations: list[tuple[str, list[str], bool, float]] = []
    for direction in ("north", "east", "south", "west"):
        animations.append((f"idle_{direction}", [idle_paths[direction]], True, 1.0))
        walk_cycle = [walk_paths[direction], idle_paths[direction]] * 2
        animations.append((f"walk_{direction}", walk_cycle, True, 8.0))
        animations.append((f"dash_{direction}", [dash_paths[direction]], True, 1.0))
    animations.append(("attack_phys", attack_paths, False, 18.0))
    resource = godot_frames_resource(animations)
    (root / "resources/pablita_topdown_frames.tres").write_text(resource, encoding="utf-8")


def build_pipop(source: Image.Image, root: Path) -> None:
    out_dir = root / "assets/sprites/pipop"
    idle_paths: dict[str, str] = {}
    walk_paths: dict[str, list[str]] = {}
    roar_paths: list[str] = []

    def save(name: str, image: Image.Image) -> str:
        path = out_dir / f"{name}.png"
        save_png(fit_to_canvas(image, (32, 32)), path)
        return path.relative_to(root).as_posix()

    def cut(box: tuple[int, int, int, int]) -> Image.Image:
        return pipop_cutout(source, box)

    idle_paths["south"] = save("idle_south", cut(PIPOP_IDLE["south"]))
    idle_paths["north"] = save("idle_north", cut(PIPOP_IDLE["north"]))
    east_idle = cut(PIPOP_IDLE["east"])
    idle_paths["east"] = save("idle_east", east_idle)
    idle_paths["west"] = save("idle_west", ImageOps.mirror(east_idle))

    for direction in ("south", "north", "east"):
        boxes = PIPOP_WALK[direction]
        if len(boxes) == 2:
            frames = [cut(boxes[0]), cut(boxes[1])] * 2
        else:
            frames = [cut(box) for box in boxes]
        walk_paths[direction] = [
            save(f"walk_{direction}_{index}", frame)
            for index, frame in enumerate(frames)
        ]
    walk_paths["west"] = []
    for index, path in enumerate(walk_paths["east"]):
        east_frame = Image.open(root / path).convert("RGBA")
        walk_paths["west"].append(save(f"walk_west_{index}", ImageOps.mirror(east_frame)))

    roar_paths = [save(f"sonic_roar_{index}", cut(box)) for index, box in enumerate(PIPOP_ROAR)]
    legacy = {
        "defense": "assets/characters/pipop/topdown/pip_defense.png",
        "hold_box": "assets/characters/pipop/topdown/pip_box.png",
        "hurt": "assets/characters/pipop/topdown/pip_hurt.png",
        "read_book": "assets/characters/pipop/topdown/pip_book.png",
        "sleep": "assets/characters/pipop/topdown/pip_sleep.png",
    }

    animations: list[tuple[str, list[str], bool, float]] = []
    for name, path in legacy.items():
        animations.append((name, [path], name not in {"defense", "hurt"}, 4.0))
    for direction in ("north", "east", "south", "west"):
        animations.append((f"idle_{direction}", [idle_paths[direction]], True, 1.0))
        animations.append((f"walk_{direction}", walk_paths[direction], True, 7.0))
    animations.append(("sonic_roar", roar_paths, True, 10.0))
    resource = godot_frames_resource(animations)
    (root / "resources/pipop_topdown_frames.tres").write_text(resource, encoding="utf-8")


def build_bedroom_environment(overview: Image.Image, refined: Image.Image, root: Path) -> None:
    bedroom_dir = root / "assets/environments/bedroom"
    # Furniture pieces are exact transparent cutouts from the supplied boards.
    bed = alpha_cutout(refined, (760, 451, 66, 95), 200)
    wardrobe = alpha_cutout(overview, (491, 734, 66, 72), 200)
    rug = alpha_cutout(overview, (305, 642, 46, 27), 200)
    save_png(bed, bedroom_dir / "furn_bed.png")
    save_png(wardrobe, bedroom_dir / "furn_wardrobe.png")
    save_png(fit_to_canvas(rug, (96, 72), bottom_align=False), bedroom_dir / "furn_rug.png")

    # Two neighboring crops from the warm room floor sample preserve the 32px tile grid.
    floor_sample = (17, 447, 71, 96)
    sample_x, sample_y, _sample_w, _sample_h = floor_sample
    floor_a = alpha_cutout(refined, (sample_x + 10, sample_y + 15, 32, 32), 200)
    floor_b = alpha_cutout(refined, (sample_x + 10, sample_y + 50, 32, 32), 200)
    save_png(floor_a, bedroom_dir / "tile_bedroom_wood_0.png")
    save_png(floor_b, bedroom_dir / "tile_bedroom_wood_1.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--characters-zip", required=True, type=Path)
    parser.add_argument("--environment-zip", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT)
    args = parser.parse_args()
    root = args.project_root.resolve()

    with ZipFile(args.characters_zip) as characters, ZipFile(args.environment_zip) as environments:
        pablita = read_image(characters, CHARACTER_FILES["pablita"])
        pipop = read_image(characters, CHARACTER_FILES["pipop"])
        overview = read_image(environments, ENVIRONMENT_FILES["overview"])
        refined = read_image(environments, ENVIRONMENT_FILES["refined"])
        build_pablita(pablita, root)
        build_pipop(pipop, root)
        build_bedroom_environment(overview, refined, root)

    print("Generated Pablita and Pipop 32x32 sprites, SpriteFrames resources, and bedroom cutouts.")


if __name__ == "__main__":
    main()
