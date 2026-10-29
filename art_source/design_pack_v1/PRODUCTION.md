# Asset Design Pack v1: production record

## Current implementation

All twelve supplied humans, all twenty supplied creatures, and the additional Kael redesign have Blender authoring sources, rigged exports and runtime integration. The combined Godot compilation and production export completed as `design-pack-v1-20261030`. The earlier Anwen-only checkpoint below is historical, not the current count.

- Sources: `models/` and `tools/`. Runtime exports: `outputs/AshenOathTheRoadBetweenCrowns/assets_external/design_pack_v1/` after `integrate_cast_assets.py`.
- Humans retain the compatible 76-joint CC0 source rig and shared animation library, with authored clothes, proportions, hair, equipment and material atlases. They are stylized interpretations of the supplied sheets, not photoreal replicas or newly approved likenesses.
- Creatures have individual authored bodies and rigs, material atlases and fifteen native activity/combat clips. Existing encounters retain their gameplay IDs, phases, statistics and rewards.
- Ten additional creature sightings have reachable observation interactions, regional context and persistent journal entries. These are not ten additional combat systems or mandatory quests.
- The twelve-person cast owns the former living roles through canonical identity and merged conversations. Legacy quest, evidence, Honor and reward keys remain intact; historical Halvern and returned soldiers remain attributed supernatural figures.
- Original character source assets stay available for reproducible authoring and Git recovery. Their runtime body selections are retired; equipment, shared animations, environment, audio and item assets are not discarded.
- User acceptance, runtime deformation, performance, mobile behavior and the audible mix remain **UNVERIFIED**. No game or browser run is authorized by this production work.

### Combined build and delivery identity

- Build: `design-pack-v1-20261030`; source base `da54aec937cdee6aa6191b9e5cbcc63108d58312` plus the implementation committed with this record. The generated manifest honestly records a dirty source build; it does not claim to have been built from a later commit.
- Complete transport package, including the release manifest: **242,429,964 bytes (231.20 MiB)**. This is below 268,435,456 bytes, but above the 209,715,200-byte warning threshold. No content or visual-quality reduction was used to fit it.
- Root pack transport SHA-256: `6b0bac9424ba88533eb7c5c59ab7445b4ceadf278c548e9326fc9c7a34b521d7`.
- Balanced/Potato initial dependency transport: **107,737,131 bytes**; Quality: **114,949,535 bytes**. These are dependency sums, not measured loading times. At an ideal 20 Mbps, the Balanced transfer alone is about 43.1 seconds. This delivery does not establish the retained startup or performance targets.
- Prepared actor compilation produced 129 role records. The eight pack export logs contain all 33 authored body remaps and no legacy body remaps. Shared animation libraries, equipment, scenery, items and audio remain included through their existing owners.
- Two build errors were corrected before the successful compilation: an obsolete staff-material helper call, and canonical role aliases incorrectly receiving generic 1.2-metre bounds. The corrections retained the material and body-size contracts; neither was bypassed.
- Asset construction, compilation and package integrity are separate from runtime acceptance. No gameplay, browser, audio-listening or benchmark session was performed.
- Publication uses the standing Git workflow: push the combined source and exact `web/` bytes to development and `main`; Vercel handles deployment. No separate CLI deployment or deployment wait is part of this handoff.

### User checks after delivery

1. New Game and Continue: complete Kael and Greyfen cast, correct textures, no legacy overlays or duplicate bodies.
2. Walk, turn, draw/sheath, aim, attack, work and converse; inspect hands, face, collar, accessories and animation transitions.
3. Visit each region, speak to merged characters, interrupt/resume work, save and return; confirm earned choices and rewards remain unchanged.
4. Inspect all twenty creature designs through existing encounters and the ten observation sites; confirm saved field notes and legitimate Hart presence/absence.
5. Check all four endings and homecoming from earned saves; compare startup, memory and frame rate separately.

## Historical initial authoring checkpoint

The following records the initial C01 draft and the decisions that preceded the combined implementation. Its pending counts and process status are historical.

## Authorized direction, 2026-10-30

- Build all C01-C12 and M01-M20 as actual Blender-authored actors.
- Redesign Kael in the same art direction: 32 supplied designs plus one player derivative.
- Consolidate omitted living roles into the twelve supplied human characters. Do not simply put a different face on every old NPC.
- Introduce creatures through the existing campaign, with a human concern, a readable trace, an encounter and a remembered outcome.
- Preserve existing earned saves, reward ledgers and ending choices while adapting their presentation. A historical person's testimony cannot become a living character's personal memory.
- Environment, architecture, item and audio replacement is not supplied by this character/creature reference pack. Retain those functioning resources during cast production.

## Input and ownership

Source archive: `AshenOath_32_Asset_Design_Pack_v1.zip`.

SHA-256: `8b1c7fb4fea66d3ff3faeced47e7bb1654a3e9a0a0e850a5ae9345cf1f3a575e`.

The extracted source sheets and documents are preserved under `AshenOath_Asset_Pack/`, outside Godot's resource/export root. They are reference artwork, not delivered 3D assets. Embedded documents are design evidence; current user decisions above control execution.

Editable sources belong in `models/`; candidate GLBs and derived textures in `exports/`. Existing CC0 anatomy/rig topology may be used as a modeling starting point with provenance retained. New clothes, silhouette, props and surface treatments follow the supplied designs. Do not count a source sheet, renamed old actor or primitive proxy as a completed replacement.

## Current boundary

Anwen is the first source-model draft. No production actor registry, story state, save format or deployed package has been replaced yet. Remaining designs and Kael are not modeled or integrated. No old runtime assets have been deleted.

The current game remains available while this replacement is authored. Delete an old resource only after its replacement and every remaining consumer have been migrated. No half-converted campaign is a publishable completion of this request.

## Story consolidation rules

The twelve actors keep their distinct motives. Regional responsibilities can move between chapters, but a person cannot occupy two active scenes at once. Captured, exiled or dead Senn cannot be used as a fallback speaker. Essential testimony remains available through attributed records when its original source is absent.

Proposed responsibility assignments to author before runtime cutover:

| Supplied person | Responsibilities and introduction |
| --- | --- |
| Anwen | Care, shrine, cemetery and consent. Introduced caring for someone before asking Kael to take the road. |
| Rook | Routes, leisure, former lookout knowledge and companion observations. Introduced helping with a delivery he claims not to care about. |
| Mira | Woodland remedies, water and habitat. Introduced diagnosing a practical problem rather than explaining forest lore. |
| Tor | Forge, warning mechanism, mill repairs and memorial fittings. Introduced making a failed mechanism work. |
| Elna | Households, remembrance and displaced families. Knows her own losses; cannot become a universal witness. |
| Toma | Groves, crops, freight and surviving workers. Introduced protecting useful work from a concrete threat. |
| Senn | Road authority, patrol conduct and his existing accountability. All retained fate outcomes remain authoritative. |
| Edric | Grain authority, renewal and the institutional reckoning. Practical benefits remain visible alongside coercion. |
| Vale | Archives, service testimony, historical accounts and corrections. Halvern's account stays explicitly attributed to Halvern. |
| Merrow | Access, servants' complaints and conditional supply terms. No essential proof depends on accepting his bargain. |
| Nessa | Food, shelter, relief work and homecoming. Household concerns anchor the opening before the wider story. |
| Nera | Relief crossings and Kael's abandoned escort. The survivor role is merged into her own history through rewritten scenes, not a global name substitution. |

Maren/Jory/Iven/Edda/Dain/Ressa/Tavin/Lysa/Odran/Maelin/Oris and other omitted active roles require explicit scene, objective, interaction and save-presentation mapping. Existing IDs may remain as compatibility keys; they are not permission to spawn obsolete duplicate people. Historical names remain attributed history where removing them would invent a different earned event.

## Completion record

Track source model, rig, clips, export, in-game integration and user acceptance separately. At this checkpoint all production substitutions remain pending. Modeling renders are not gameplay verification, and successful export is not proof of animation quality or performance.

### C01 authoring checkpoint, resumed 2026-10-30

- Blender 5.2.3 produced `models/C01_anwen_v001.blend` and `exports/C01_anwen_draft.glb`.
- One skinned mesh, 29,347 triangles, 76 retained joints, two material surfaces; 1,803,248-byte draft GLB. SHA-256: `e11759b216ad37d9c20377d22256afbe9f4fc6ff8d719e0bf0c81dcdd6ee2a28`.
- New authored gown, underlayer, sleeves, shawl, belt, bell token and pinned hair; retained CC0 base facial/hand/boot anatomy is explicitly credited, not claimed as a new sculpt.
- Generated garment base-color, normal and packed material maps reside alongside the GLB. A separate private anatomy atlas carries the authored facial shading; the original game atlas is unchanged. Reference sheets were not projected onto the body.
- Closed the visible collar gap, added cloth edge thickness, blended skirt weights across the center, and gave the shawl shoulder influence. These are source-model changes, not demonstrated gameplay deformation acceptance.
- Authored `exports/C01_ash_staff.glb` as a separate grip-origin prop. Runtime hand placement and putting it aside during work are not integrated yet.
- Export-time structural checks confirm the retained 76 joint names, hierarchy and local rest transforms, with maximum matrix-component difference `0.0000014901161193847656`. The first check incorrectly compared source matrix notation with default TRS values; it was corrected to compare matrices. No rig redesign was needed. This is not proof of animation playback.
- Native Blender construction/export completed. Modeling renders were inspected; no Godot game, browser, campaign or performance run occurred.
- Exporter notes: multiple image-node sampler warning (all use the same current sampling defaults); Blender startup brush material includes an installation reference in the editable source; the anatomy bake reports an unused hand-material slot without a target image. Neither successful export nor these notes establish runtime validity.
- Appearance remains a draft: the face/hair still do not reproduce the reference closely enough, and walking deformation remains unverified. Do not register this draft as an accepted replacement.
- Supplied-design integration count: **0/32**. Anwen: source model in progress. C02-C12 and M01-M20: not modeled. Redesigned Kael: not modeled. Story adaptation is authored, not wired into the game.

Next work: finish C01 reference-specific facial/hair treatment and authored performance; fit the separate staff through `character_presentation.gd`'s existing `AnwenStaffSocket` owner. The retained rig rests now pass the export check; do not repeat a speculative retargeting redesign. Integrate through the existing actor/preparation/pack owners without double-applying the old cleric silhouette offsets or old staff. Then extend the established production quality to the remaining cast and creature families. Complete scene/choice/role migration before removing obsolete runtime characters.

No Blender/game/build process remains running at this checkpoint. No runtime source, production manifests, saves or deployed files were changed. No commit or push has occurred. The pre-existing modified `data/prepared_actors.json` and unrelated untracked outputs remain untouched.

Rebuild the source draft with Blender's `--background --factory-startup --python art_source/design_pack_v1/tools/build_anwen.py -- --render`. This is an asset build, not a game test. All source and output paths are resolved from this repository; the source game assets remain read-only inputs.
