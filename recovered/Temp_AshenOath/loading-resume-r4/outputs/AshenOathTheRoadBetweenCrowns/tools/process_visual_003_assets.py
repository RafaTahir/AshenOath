from __future__ import annotations

from pathlib import Path

from PIL import Image
from PIL import ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets_external" / "textures" / "pbr"
OUTPUT = ROOT / "assets_external" / "textures" / "runtime"

SURFACES = {
    "forest_ground": ("forest_ground", "Ground071"),
    "wet_mud": ("wet_mud", "Ground029"),
    "cobblestone": ("cobblestone", "PavingStones150"),
    "plaster": ("plaster", "Plaster001"),
    "timber": ("timber", "Planks037B"),
    "roof_tiles": ("roof_tiles", "RoofingTiles014A"),
    "medieval_brick": ("medieval_brick", "Bricks008"),
}


def find_map(folder: Path, prefix: str, token: str) -> Path | None:
    matches = sorted(folder.glob(f"{prefix}*_{token}.*"))
    return matches[0] if matches else None


def save_jpeg(image: Image.Image, path: Path, quality: int = 82) -> None:
    image.convert("RGB").save(path, "JPEG", quality=quality, optimize=True, progressive=True)


def process_surface(output_name: str, source_folder: str, prefix: str) -> None:
    folder = SOURCE / source_folder
    albedo_path = find_map(folder, prefix, "Color")
    normal_path = find_map(folder, prefix, "NormalGL")
    roughness_path = find_map(folder, prefix, "Roughness")
    ao_path = find_map(folder, prefix, "AmbientOcclusion")
    if not albedo_path or not normal_path or not roughness_path:
        raise RuntimeError(f"Incomplete PBR source for {output_name}: {folder}")

    albedo = Image.open(albedo_path).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    normal = Image.open(normal_path).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    roughness = Image.open(roughness_path).convert("L").resize((1024, 1024), Image.Resampling.LANCZOS)
    ao = Image.open(ao_path).convert("L").resize((1024, 1024), Image.Resampling.LANCZOS) if ao_path else Image.new("L", (1024, 1024), 255)
    orm = Image.merge("RGB", (ao, roughness, Image.new("L", (1024, 1024), 255)))

    save_jpeg(albedo, OUTPUT / f"{output_name}_albedo.jpg")
    save_jpeg(normal, OUTPUT / f"{output_name}_normal.jpg", 86)
    save_jpeg(orm, OUTPUT / f"{output_name}_orm.jpg", 86)


def process_grass() -> None:
    source = ROOT / "assets_external" / "textures" / "generated" / "GrassTufts_Alpha.png"
    if not source.exists():
        if (OUTPUT / "grass_tuft.png").exists():
            return
        raise RuntimeError(f"Missing generated grass atlas: {source}")
    atlas = Image.open(source).convert("RGBA")
    width, height = atlas.size
    crop = atlas.crop((width // 2, 0, width, height // 2))
    crop.thumbnail((512, 512), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((512 - crop.width) // 2, 512 - crop.height))
    canvas.save(OUTPUT / "grass_tuft.png", "PNG", optimize=True)


def process_monster_skins() -> None:
    # Monster roles now derive their silhouettes from the retained animated
    # Skeleton source. The three compact role skins are already checked into
    # the runtime texture set; never regenerate them from a retired source.
    expected = [OUTPUT / "ghoulkin_skin.jpg", OUTPUT / "stalker_skin.jpg", OUTPUT / "brute_skin.jpg"]
    missing = [path.name for path in expected if not path.is_file()]
    if missing:
        raise RuntimeError(
            "Missing retained Skeleton-family skins: %s. Restore them from the approved runtime texture source before processing."
            % ", ".join(missing)
        )


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, (source_folder, prefix) in SURFACES.items():
        process_surface(output_name, source_folder, prefix)
    process_grass()
    process_monster_skins()
    files = [path for path in OUTPUT.iterdir() if path.is_file()]
    total = sum(path.stat().st_size for path in files)
    print(f"VISUAL-003 runtime textures: {len(files)} files, {total / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
