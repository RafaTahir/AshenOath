"""Track every selected retained scenery derivative without inventing motion."""
import hashlib
import json
from pathlib import Path
from copy import deepcopy
from living_asset_coverage import current_scenery_units, digest, flatten_environment, read
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs

ART = Path(__file__).resolve().parents[1]
GAME = ART.parents[1]/"outputs/AshenOathTheRoadBetweenCrowns"
EVIDENCE = ART/"evidence/living_assets_stage3_20261107"

SPLITS = {
    "road_checkpoint": ("checkpoint_cloth", "cloth", 2, "Two existing banner panels pivot at their upper suspension; buildings, beam and poles stay static."),
    "marsh_landscape": ("marsh_reeds", "foliage", 5, "Five retained reed groups move from their ground roots; boardwalk, mud and pool geometry keep their original transforms."),
    "hart_fitted_woodland": ("hart_ferns", "foliage", 6, "Six retained fern clusters move from their roots; adjoining terrain and tree trunks are separate static geometry."),
    "ash_mill_architecture": ("ash_mill_wheel", "mill_wheel", 1, "Existing wheel spins about its real X-axis axle only when the existing story flow state permits; masonry and roof remain static."),
}


def classification(identity):
    if identity in SPLITS:
        scene, kind, count, reason = SPLITS[identity]
        return {"treatment": "extract_retained_moving_part", "reason": reason,
                "runtime_scene": "res://assets_external/environment_prepared/living_world/"+scene+".scn",
                "moving_kind": kind, "moving_part_count": count, "source_recipe_implemented": True,
                "compiled": False, "native_verified": False}
    if identity.startswith("sky_cloud_volume_"):
        return {"treatment": "retain_existing_atmosphere_owner", "reason": "Cloud geometry already belongs to VisualDirector; preserve its depth, drift and day/night tint without adding a second ticker.",
                "runtime_owner": "res://scripts/visual_director.gd", "geometry_changed": False}
    if identity == "cemetery_bell":
        return {"treatment": "separate_clapper_suspension", "reason": "Existing clapper child receives its true upper pivot; bell housing and stone frame retain fixed geometry.",
                "runtime_owner": "res://scripts/zones/cemetery_section.gd", "moving_kind": "clapper", "geometry_changed": False, "native_verified": False}
    if identity.startswith("campaign_record_") or identity.startswith("hart_aftermath_"):
        return {"treatment": "retain_story_selected_static_state", "reason": "This is a consequential state-specific object/arrangement. Its authored evidence remains still; the existing story state selects the appropriate variant.", "geometry_changed": False}
    if identity.startswith("wychwood_evidence_"):
        return {"treatment": "retain_evidence_readability", "reason": "Forensic evidence and the dead body retain their exact physical placement; ambient environment and lighting provide surrounding life.", "geometry_changed": False}
    if identity == "record_hall_witness_relief":
        return {"treatment":"retain_artwork_readability", "reason":"Existing witness relief artwork remains still and readable in its supported architectural placement; assess light/material response in context.", "geometry_changed":False}
    if identity in ("greyfen_fitted_forge_work", "greyfen_social_common_table", "greyfen_social_mira_apothecary", "record_hall_archive"):
        return {"treatment": "supported_npc_contact_activity", "reason": "Retained furniture remains solid and supported. Authored NPC hands and separately supported work materials provide the visible activity.", "geometry_changed": False, "native_verified": False}
    return {"treatment": "retain_static_material_response", "reason": "Fixed terrain, masonry, timber or supported object geometry remains physically stable. Retained materials respond to the existing light/weather owner; no whole-building or whole-ground sway is introduced.", "geometry_changed": False}


def main():
    inventory = json.loads((EVIDENCE/"retained_source_inventory.json").read_text())
    repo = ART.parents[1]
    ledger = read(GAME/'release_reports/living_cast_20261107/asset_coverage.json')
    selected = {row['path']:row['pack_owners'] for row in ledger['runtime_asset_resources']}
    current_manifest = read(GAME/'runtime_asset_manifest.json')
    roster = flatten_environment(current_manifest['authored_environment_derivatives'], selected)
    baseline = {row['id']:row for row in inventory['selected_authored_environment']}
    destination = EVIDENCE/"scenery_coverage.json"
    previous = read(destination) if destination.is_file() else {}
    previous_rows = {row['id']:row for row in previous.get('entries',[])}
    units = current_scenery_units(repo,GAME)
    sources = {}
    for directory in (GAME/"scripts", GAME/"tools"):
        for path in directory.rglob("*.gd"):
            if path.name.startswith(("verify_", "capture_")):
                continue
            sources[path] = path.read_text(encoding="utf-8-sig").splitlines()
    rows = []
    for source in roster:
        identity = source['id']
        old = previous_rows.get(identity,{})
        path = GAME/source['path'][6:]
        row = {key:source[key] for key in ('id','path','pack_owner','pack_owners')}
        row.update({key:source[key] for key in ('group_id','variant','declared_pack_owner') if key in source})
        row['baseline_status'] = baseline.get(identity,source).get('status')
        row['baseline_sha256'] = baseline.get(identity,source).get('sha256')
        row['sha256'] = digest(path)
        row['bytes'] = path.stat().st_size if path.is_file() else None
        row['resource_present_in_checkout'] = path.is_file()
        row['present_in_selected_export'] = True
        row['current_bytes_verified_in_selected_export'] = False
        row['previously_enumerated_in_frozen_scenery_inventory'] = identity in baseline
        row["source_builder"] = source.get("build_tool")
        row["source_builder_sha256"] = digest(GAME/row['source_builder'][6:]) if row['source_builder'] else None
        filename = Path(source["path"]).name
        references = []
        for path, lines in sources.items():
            for number, line in enumerate(lines, 1):
                if filename in line:
                    references.append({"source": "res://"+path.relative_to(GAME).as_posix(), "line": number})
        row["direct_source_references"] = references
        row["life_integration"] = classification(row["id"])
        row.update(authored=False,native_verified=False,visual_accepted=False,user_accepted=False,
                   in_level_accepted=False,performance_verified=False)
        paths = [row['path']] + ([row['source_builder']] if row['source_builder'] else [])
        paths += [key for key in old.get('verification_inputs',{}) if key.startswith('res://')]
        inputs = resource_inputs(GAME,paths)
        unit = units.get(identity)
        if unit:
            inputs.update(unit['inputs'])
        row = refresh_review(row,old,inputs)
        if unit:
            row.update(authored=unit['authored'],native_verified=unit['native_verified'])
            row['current_authoring']={k:deepcopy(v) for k,v in unit.items() if k!='inputs'}
            candidate_path=unit.get('runtime_scene',unit.get('path'))
            row['current_authoring']['runtime_scene_present_in_selected_export']=candidate_path in selected
            row['current_authoring']['actual_selected_pack_owners']=selected.get(candidate_path,[])
            row['life_integration'].update(compiled=unit['compiled'],native_verified=unit['native_verified'])
        rows.append(row)
    endings = []
    for identity in ("concord", "open_road"):
        resource = "res://assets_external/environment/forest/HartAftermath_"+identity+"_Authored.res"
        path = GAME/resource[6:]
        record={"id": "hart_aftermath_"+identity, "path": resource, "pack_owner": "community",
            "expected_pack_owner":"community","actual_selected_pack_owners":selected.get(resource,[]),
            "pack_owner_kind":"expected_current_partition","current_bytes_verified_in_selected_export":False,
            "source_builder": "res://tools/build_hart_aftermath.gd", "generated": path.is_file(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None,
            "bytes": path.stat().st_size if path.is_file() else None, "native_verified": False,
            "authored":False,"visual_accepted": False, "user_accepted": False,"in_level_accepted":False,
            "performance_verified":False,"present_in_selected_export":resource in selected}
        old=next((v for v in previous.get('stage4_added_derivatives',[]) if v['id']==record['id']),{})
        unit=units.get(record['id'])
        inputs=resource_inputs(GAME,[resource,record['source_builder']])
        if unit:inputs.update(unit['inputs'])
        record=refresh_review(record,old,inputs)
        if unit:
            record.update(authored=unit['authored'],native_verified=unit['native_verified'])
            record['current_authoring']={k:deepcopy(v) for k,v in unit.items() if k!='inputs'}
        endings.append(record)
    result = {"schema_version": 2, "scope": "Current selected authored scenery resources plus separately identified new memorial candidates; source/native evidence is not visual acceptance",
              "source_inventory_sha256": hashlib.sha256((EVIDENCE/"retained_source_inventory.json").read_bytes()).hexdigest(),
              "retained_art_direction": True, "runtime_owner": "Existing WorldPropController/VisualDirector/story-state owners",
              "new_independent_tickers": 0, "required_inline_part_scenes": 4, "new_moving_mesh_children": 14,
              "selected_export":ledger['baseline'],
              "current_manifest_sha256":digest(GAME/'runtime_asset_manifest.json'),
              "coverage_counts":{"frozen_baseline_entries":len(baseline),"selected_resources":len(rows),
                  "selected_mesh_derivatives":sum(Path(row['path']).suffix in ('.res','.scn','.tscn','.glb') for row in rows),
                  "selected_artwork":sum(Path(row['path']).suffix in ('.jpg','.png','.svg') for row in rows),
                  "added_memorial_candidates":len(endings),"review_items":len(rows)+sum(not row['present_in_selected_export'] for row in endings),
                  "native_verified_split_assemblies":sum(bool(row.get('native_verified')) for row in rows if row['id'] in SPLITS),
                  "native_verified_memorial_resources":sum(bool(row.get('native_verified')) for row in endings)},
              "entries": rows, "stage4_added_derivatives": endings}
    for key,value in previous.items():
        if key not in result:result[key]=deepcopy(value)
    result['removed_from_runtime_scope']=preserve_removed(previous.get('entries',[]),rows,previous.get('removed_from_runtime_scope',[]))
    destination.write_text(json.dumps(result, indent=2)+"\n")
    print("SCENERY_CURRENT_COVERAGE",json.dumps(result['coverage_counts']))


if __name__ == "__main__":
    main()
