"""Reject QA-only content that masks missing production runtime packs."""
import configparser
import json
from pathlib import Path


def validate(path):
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read(path, encoding="utf-8-sig")
    presets = {s.get("name", "").strip('"'): s for s in config.values()}
    production = presets["Web Browser"]
    qa = presets["Web QA Browser"]
    opening = presets["Runtime Pack Opening"]
    characters = presets["Runtime Pack Characters"]
    quality_materials = presets["Runtime Pack Quality Materials"]
    telemetry = "res://scripts/qa_browser_telemetry.gd"

    def files(section):
        return set(json.loads("[" + section["export_files"].removeprefix("PackedStringArray(")[:-1] + "]"))

    def filters(section, key):
        return set(section[key].strip('"').split(","))

    assert files(qa) == files(production) | {telemetry}, "QA explicit resources differ from production"
    assert filters(qa, "include_filter") == filters(production, "include_filter"), "QA includes extra runtime content"
    assert filters(qa, "exclude_filter") == filters(production, "exclude_filter") - {telemetry.removeprefix("res://")}, "QA exclusions differ beyond telemetry"
    owned = filters(opening, "include_filter")
    production_excluded = filters(production, "exclude_filter")
    production_files = files(production)
    assert any(p.startswith("assets_external/environment/") for p in owned), "Opening pack owns no environment content"
    for opening_prop in ("Bucket_Wooden_1.fbx", "Book_Simplified_Single.fbx", "Axe_Bronze.fbx"):
        path = f"assets_external/environment/props/{opening_prop}"
        assert path in owned, f"Opening pack lacks staged villager equipment: {path}"
        assert f"res://{path}" not in production_files, f"Root PCK duplicates staged villager equipment: {path}"
    character_owned = filters(characters, "include_filter")
    crowd_assemblies = (
        "Villager_Male_Atlas",
        "Villager_Female_Atlas",
        "Villager_Worker_Atlas",
        "Villager_Hooded_Atlas",
    )
    deferred_character_resources = tuple(
        f"assets_external/characters_universal/runtime/{name}.{extension}"
        for name in crowd_assemblies
        for extension in ("gltf", "bin", "png")
    ) + (
        "assets_external/characters_ranger/Male_Ranger_Runtime.gltf",
        "assets_external/characters_ranger/Male_Ranger_Runtime.bin",
        "assets_external/characters_universal/Male_Head.gltf",
        "assets_external/characters_universal/Male_Head.bin",
        "assets_external/characters_universal/Hair_SimpleParted.gltf",
        "assets_external/characters_universal/Hair_SimpleParted.bin",
        "assets_external/characters_universal/T_Regular_Male_Dark_BaseColor_1K.png",
        "assets_external/characters_universal/T_Regular_Male_Normal_1K.png",
        "assets_external/characters_universal/T_Regular_Male_Roughness_1K.png",
        "assets_external/characters_universal/T_Superhero_Male_Dark_1K.png",
        "assets_external/characters_universal/T_Superhero_Male_Normal_1K.png",
        "assets_external/characters_universal/T_Superhero_Male_Roughness_1K.png",
        "assets_external/characters_universal/T_Hair_1_BaseColor_1K.png",
        "assets_external/characters_universal/T_Hair_1_Normal_1K.png",
        "assets_external/characters_universal/T_Eye_Brown.png",
        "assets_external/characters_universal/T_Eye_Normal.png",
    )
    for pattern in deferred_character_resources:
        assert pattern in character_owned, f"Character pack lacks deferred crowd ownership: {pattern}"
        assert pattern not in owned, f"Opening startup pack still owns deferred crowd resource: {pattern}"
        assert f"res://{pattern}" not in production_files, f"Root Web PCK explicitly owns deferred character resource: {pattern}"
        if "/runtime/" not in pattern:
            assert pattern in production_excluded or pattern.startswith("assets_external/characters_ranger/"), (
                f"Root Web PCK does not exclude deferred character dependency: {pattern}"
            )
    for raw_crowd_resource in (
        "assets_external/characters_universal/Male_Peasant.gltf",
        "assets_external/characters_universal/Female_Peasant.gltf",
        "assets_external/characters_universal/Female_Head.gltf",
        "assets_external/characters_universal/Hair_Buns.gltf",
        "assets_external/characters_universal/Hair_Buzzed.gltf",
    ):
        assert raw_crowd_resource not in character_owned, f"Character pack still owns raw crowd resource: {raw_crowd_resource}"
    for runtime_role in ("Kael_A_Set_Atlas.gltf", "Anwen_A_Set_Atlas.gltf"):
        runtime_path = f"res://assets_external/characters_universal/runtime/{runtime_role}"
        assert runtime_path in production_files, f"Root Web PCK lacks required A-set assembly: {runtime_path}"
        assert runtime_path.removeprefix("res://") not in production_excluded, f"Root excludes required A-set assembly: {runtime_path}"
    assert "assets_external/textures/runtime/*_albedo.jpg" in owned, "Opening pack lacks lightweight albedo materials"
    assert "assets_external/textures/runtime/grass_tuft.png" in owned, "Opening pack lacks opening foliage texture"
    assert "assets_external/textures/runtime/*_normal.jpg" not in owned, "Opening pack still owns optional normal maps"
    quality_owned = filters(quality_materials, "include_filter")
    assert "assets_external/textures/runtime/*_normal.jpg" in quality_owned, "Quality pack lacks normal maps"
    assert "assets_external/textures/runtime/*_orm.jpg" in quality_owned, "Quality pack lacks ORM maps"


if __name__ == "__main__":
    validate(Path(__file__).resolve().parents[1] / "export_presets.cfg")
    print("WEB PRESET PARITY: PASS (static resource selection only)")
