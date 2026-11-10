"""Render an existing verified candidate without saving or regenerating assets."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from living_creature_motion_profiles import REPLACED_CLIPS, SPECIES
from living_creature_preview import render_views

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def binding(owner, clip):
    animation = owner.animation_data
    if animation is None:
        raise ValueError('Imported source animation owner is missing: ' + clip)
    matches = [strip for track in animation.nla_tracks if track.name == clip for strip in track.strips]
    if len(matches) != 1 or matches[0].action is None or matches[0].action_slot is None:
        raise ValueError('Imported clip/slot is absent or ambiguous: ' + clip)
    strip = matches[0]
    return strip.action, strip.action_slot


def main(asset, revision):
    folder = ROOT/'models/living_assets_stage3_20261107/creatures'/asset
    carrier = folder/(asset+'_living_candidate.glb')
    proof = json.loads((folder/'source_contract.json').read_text())
    authored = json.loads((folder/'authoring.json').read_text())
    if proof.get('status') != 'source_contract_pass' or sha(carrier) != proof['candidate_sha256']:
        raise ValueError('Rendering requires the exact already-verified source candidate')
    if sha(folder/(asset+'_living_v001.blend')) != authored['blend_sha256']:
        raise ValueError('Retained editable source changed before preview')
    before = {path.relative_to(folder).as_posix(): sha(path) for path in folder.rglob('*')
              if path.is_file() and 'review_iterations' not in path.parts}
    output = folder/'review_iterations'/revision
    if output.exists():
        raise ValueError('Keep prior preview provenance; choose a fresh revision directory')
    output.mkdir(parents=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(carrier))
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    if len(rigs) != 1:
        raise ValueError('Exactly one retained creature rig is required')
    rig = rigs[0]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    owners = [rig] + [obj.data.shape_keys for obj in meshes if obj.data.shape_keys]
    for owner in owners:
        if owner.animation_data:
            owner.animation_data.action = None
            for track in owner.animation_data.nla_tracks:
                track.mute = True
    actions = {}
    for clip in REPLACED_CLIPS:
        action, slot = binding(rig, clip)
        morphs = []
        for obj in meshes:
            keys = obj.data.shape_keys
            if keys is None or len(keys.key_blocks) < 2:
                continue
            morph_action, morph_slot = binding(keys, clip)
            morphs.append((obj, morph_slot, morph_action))
        actions[clip] = (action, slot, morphs, float(proof['durations'][clip]))
    frames = render_views(rig, actions, meshes, output, bpy.context.scene.render.fps)
    after = {relative: sha(folder/relative) for relative in before}
    if after != before:
        raise ValueError('Read-only source preview modified an authored input')
    # Archive this preview-only recipe separately from the immutable authoring
    # recipe which produced the carrier; no source/export receipt is rewritten.
    recipe = {}
    for source in (Path(__file__), Path(__file__).with_name('living_creature_preview.py')):
        digest = sha(source)
        destination = output/(source.stem+'_'+digest[:16]+source.suffix)
        destination.write_bytes(source.read_bytes())
        recipe[source.name] = {'sha256': digest, 'snapshot': destination.name}
    receipt = {'schema_version': 1, 'asset': asset, 'candidate_sha256': sha(carrier),
               'source_contract_sha256': before['source_contract.json'], 'authoring_sha256': before['authoring.json'],
               'recipe': recipe, 'fixed_comparison_camera': True, 'imported_candidate_rendered': True,
               'authored_inputs_unchanged': before == after,
               'frames': [{'path': str(Path(path).relative_to(folder)), 'sha256': sha(path)} for path in frames],
               'native_gameplay_verified': False, 'visual_accepted': False, 'user_accepted': False}
    (output/'preview_receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print('CREATURE_EXISTING_CANDIDATE_RENDERED', asset, str(output), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', required=True, choices=SPECIES)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if not args.revision or any(ch not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for ch in args.revision):
        raise ValueError('Preview revision must be a simple new directory name')
    main(args.asset, args.revision)
