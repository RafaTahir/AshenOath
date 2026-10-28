# AshenOath Spectral Bestiary

Ten original spectral treatments for AshenOath's existing encounters. The
Wychwood trio has newly authored fused, carved and skinned anatomy; the other
seven are derivatives of the retained licensed bodies with spectral surface
authoring and skinned veils. The White Hart remains a white antlered stag.

| Encounter | Pack identity |
| --- | --- |
| Ghoulkin | Pallbearer |
| Wychwood Stalker | Thorn Veil |
| Wychwood Raider | Oathless Shade |
| Wychwood Brute | Hollow Crown |
| Bog Wretch | Fen Lantern |
| Gravebound Knight | Barrow Watcher |
| Bell-Eater | The Unrung |
| Rootbound Colossus | Root Revenant |
| Ashwing | Cinder Apparition |
| White Hart | The Moonlit Hart |

The style follows the user's supernatural direction: cool spectral pigment,
carved faces, exposed anatomical ridges, torn veils and flowing luminous seams.
No Witcher models, characters, textures, sounds or code are included. Retained
rigs and source bodies are Quaternius CC0 derivatives; each registered role
records its source URL, original hash and retained license file. See
`SPECTRAL_BESTIARY_BUILD.json` for model paths, geometry budgets and hashes.
Universal-rig models live in `characters_universal/runtime/spectral/` so the
existing shared animation library continues to bind correctly.

This is a Godot asset pack. Use the registered roles and
`data/spectral_monster_profiles.json`, rather than independently normalizing
from cosmetic bounds. That profile preserves the original rig frame, scale
and contact locations. The knight additionally binds its retained native FBX
rig/animation resources at preparation time, avoiding conversion resampling.
The runtime helper adds one cached veil material and a single setup rebind;
there are no new light nodes, particle farms, physics scans or gameplay ticks.

Build from the project directory:

```sh
python3 tools/build_spectral_wychwood_bodies.py
godot --headless --path . --script tools/export_spectral_sources.gd
python3 tools/build_spectral_monsters.py
python3 tools/register_spectral_monsters.py --write
godot --headless --editor --path . --import
godot --headless --path . --script tools/build_prepared_actors.gd
python3 tools/prepare_runtime_pack_layout.py
```

Authoring requires Blender, NumPy and Pillow. The retained source and runtime
oracles are bundled under `tools/fixtures/`; they are excluded from game packs.
The renderer tool produces studio comparisons under the repository's ignored
`.release-gate/spectral-monsters/` directory.

Validation: the ten actual spawned actors pass 1,740 checks, including all 350
clip-phase contacts within 2 mm, complete sampled bone poses, native bindings,
collisions and gameplay/save implementation hashes. Source rig/animation
contracts pass separately. Ordinary monsters stay below 18,000 triangles;
the shared authored surface texture is 512 square. The real startup grounding
fixture determines the Raider sole fit, rather than changing collision or
combat values. Scalar normalization bookkeeping may differ for baked source
files; complete world transforms and sampled contacts remain equivalent.

User-authorized game inclusion is recorded separately from visual approval.
Rendered appearance, browser performance and final art acceptance remain
unreviewed by the user. Studio images are source-art previews, not gameplay or
FPS evidence. The current global production-component check also reports 18
pre-existing stale human-asset hash/size records; no monster errors remain.

The complete rebuilt Web directory is **113,770,969 bytes (108.5 MiB)**, below
the strict 268,435,456-byte ceiling. Package integrity and isolated packed
startup pass. The exported monster resources separately pass **1,746 checks**
after mounting the declared packs, without source-resource fallback. The
combined architecture/opening-route/current-and-legacy-save gate passes
16,097 checks with zero engine errors or warnings. Source and prepared actor
checks pass 1,740 assertions; policy checks pass 9 Godot and 8 Python cases.
The verified candidate is synced to committed `web/`; no live deployment or
browser/FPS acceptance is claimed. GitHub protection/check information remains
inaccessible from this environment (`Forbidden`), so main is not advanced.
