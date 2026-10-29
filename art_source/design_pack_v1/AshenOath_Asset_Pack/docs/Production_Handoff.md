# AshenOath — production handoff

## Deliverable boundary

This collection supplies 20 monster designs and 12 major character designs as individual illustrated reference sheets, with appearance, narrative, encounter, and production specifications. It is a **2D art and 3D preproduction pack**. Images are suitable for art direction, bestiary/editorial presentation, and model reference after visual review.

The pack does not contain finished 3D meshes, UV layouts, baked PBR texture maps, skin weights, animation clips, collision shapes, audio, or validated Godot actor scenes. Drawn rear and side views are design guidance, not a mechanically exact orthographic reconstruction. A modeler must resolve cross-view discrepancies before sculpting. Do not report any entry as “game-ready,” “rigged,” or “performance-tested” until those assets actually exist and pass the game's acceptance route.

Existing names and story facts remain canonical only where identified by repository evidence. New biology, visual treatments, encounter mechanics, and story extensions are proposed designs. Preserve the game's current protagonist identity, quests, save keys, and actor identifiers during integration.

## Folder and naming contract

- `M01` through `M20`: monster identities, stable regardless of later display-name changes.
- `C01` through `C12`: major character identities, stable regardless of costume changes.
- Delivered art master: `{ID}_{Name_With_Underscores}.png`, for example `M01_Ghoulkin.png` or `C01_Anwen.png`.
- Future production source: `M01_descriptive_name_v001.blend`.
- Future runtime export: `M01_descriptive_name.glb`.
- Future textures: `M01_descriptive_name_basecolor.png`, `_normal.png`, `_orm.png`, and `_emissive.png` only when required.
- Future Godot actor scene: `m01_descriptive_name.tscn`, owned by the existing actor system.
- Future animation clips: descriptive names such as `idle_loop`, `walk_loop`, `attack_heavy`, `hit_front`, and `death`; connect these to the existing animation contract rather than replacing it.

These future filenames describe a handoff convention. Their presence in documentation does not mean these files have been delivered.

Keep high-resolution art masters and this production pack outside the runtime export. Export only selected derivatives when the UI actually uses them. Store editable modeling sources separately from final engine assets, with provenance and version history intact.

## Visual construction rules

**Bodies carry weight.** Establish foot contacts, plausible centers of mass, joint limits, and a locomotion signature before adding surface detail. Distinguish species through silhouette, limb proportions, locomotion, and ecological adaptations. A new color or larger size is a variant, not another species.

**Humans look like people with occupations.** Preserve distinct age, proportions, facial structure, posture, wear patterns, and practical costume construction. Fasteners need somewhere to attach. Bags need straps. Armor needs articulated openings. Garments need room for shoulders, elbows, hips, and knees to move. Protect silhouette differences when clothing is dirtied or seen under Greyfen fog.

**The face remains readable.** In particular, Anwen's face must be a continuous, intentional facial surface without loose geometry embedded across the nose, mouth, or eyes. Sculpted scars and age lines belong in the model/material; jewelry, hair cards, eyebrows, lashes, masks, and props must be independently identified and inspected. Do not use a primitive or intersecting accessory to conceal a broken face. Verify eyes, teeth, mouth interior, hairline, and neck seam at dialogue distance.

**Materials describe substances.** Use dry and damp cloth, worn leather, bone, horn, bark, stone, corroded metal, skin, and sparse emissive effects deliberately. Avoid uniform plastic roughness, painted highlights in albedo, and excessive glow that erases surface form. Concept-sheet lighting is not a texture map and must not be baked wholesale onto a 3D body.

## Proposed runtime targets — unmeasured

The following are initial art-production targets for AshenOath's constrained browser build, not official Godot limits or measured performance guarantees. The existing release-size ceiling applies to the complete game. There is no evidence yet that all 32 actors can be added inside the remaining budget.

| Asset class | Initial LOD0 target | Initial texture target | Material/surface target | Initial deforming skeleton target |
| --- | ---: | --- | ---: | ---: |
| Frequent small/medium monster | 6–12k triangles | One 1k set | 1–2 | 30–50 bones |
| Large or elite monster | 12–20k triangles | One 1k–2k set | 1–2 | 40–65 bones |
| Major human NPC | 12–20k triangles | One 1k body set; optional 1k face set | 2–3 | 55–75 bones |
| Boss visible alone | 20–35k triangles | One 2k set initially | 2–3 | 50–90 bones |

Prefer four or fewer weights per vertex as a portable production target. Limit costly secondary motion to features the camera can read. Keep hair and cloth geometry economical; alpha-overdraw and material count may matter more than polygon count. Do not infer actual draw calls directly from the material/surface targets; rendering passes and project settings also affect them.

Begin with base color, tangent-space normal, and packed occlusion/roughness/metallic where the receiving material contract supports it. Author base color for color sampling and data maps for linear sampling. Preserve texture channel assignments through export. Use an emissive map only for a meaningful visual signal. Most cloth, skin, wood, and bone should not behave as metal. Validate the exact existing Godot import settings instead of assuming a new compression scheme is safe.

For scale, a 1024×1024 RGBA8 image contains 4 MiB of raw texels before mipmaps; a 2048×2048 image contains 16 MiB. A complete mip chain adds approximately one third. These arithmetic examples describe uncompressed texel storage only, not the compressed file size, actual GPU format, or browser memory consumption. The final textures must be measured in the exported build.

Record before/after export bytes, cold-start time, peak memory, frame time, animation cost, and visual defects on the established target device. Reduce or rescope an asset when measurements fail the current release gate. Avoid creating a new shader/material variant per character merely to distinguish costume colors.

## Skeleton and animation strategy

Share a skeleton only when joint layout, limb function, rest pose, and articulation are compatible. Reuse authored animation selectively; each silhouette needs its own weight, rhythm, and attack preparation.

| Family | Suitable uses | Differences that still need individual work |
| --- | --- | --- |
| Human biped | Major NPCs and armored humanoids | Facial shapes, proportions, gait, clothing skinning, hands, and equipment |
| Crouched biped | Ghoulkin-like bodies | Spine range, forelimb reach, foot placement, floor contact |
| Quadruped | Land predators and cervids where appropriate | Hooves versus paws, digitigrade joints, neck lengths, charge and recovery |
| Heavy biped/giant | Large grounded creatures | Mass transfer, reach, stomp spacing, camera framing |
| Winged body | Ashwing and compatible flyers | Wing topology, membrane folds, takeoff/landing, grounded state |
| Bespoke | Bell-Eater or other mechanically unusual bodies | Dedicated articulation and animation instead of forced retargeting |

These are planning families, not delivered rigs. Extra limbs, shells, external organs, hanging mechanisms, or extreme body plans may require another family. Do not compress 20 distinct monster designs into a single humanoid rig at the cost of believable movement.

**Minimum humanoid coverage:** relaxed idle, attentive idle, walk, turn, sit/stand when used, dialogue gestures, at least two emotional states, reach/pickup, hit/fall if the story permits, and prop-hand interactions. Include blink, jaw, and mouth shapes only when the actual dialogue presentation uses them. Preserve visual individuality even when a locomotion library is shared.

**Minimum hostile-creature coverage:** idle, locomotion, turn, alert, approach, attack anticipation, active attack, recovery, hit reaction, stagger where supported, defeat, and disengage. Add species-specific traversal, charge, burrow, flight, or phase transitions only where the encounter requires them. Hit windows belong in animation/gameplay events, not assumptions from a concept pose.

Every dangerous attack needs a visible preparation signal and a readable recovery. Sound can reinforce the signal but must not be the only cue. Colors alone must not distinguish unavoidable damage from a safe opening. Boss changes should alter stance, movement, or silhouette as well as effects.

## Import and source ownership

Use glTF 2.0/GLB as the preferred interchange format for the modeled actors. Godot recommends glTF; OBJ cannot carry the skeleton, animation, or PBR material data needed here. Keep the editable DCC source available. Direct `.blend` import invokes Blender and therefore creates an extra environment dependency; explicit GLB exports make the production handoff easier to reproduce. [G1]

Fix topology, transform, weighting, and source-material defects in the source asset where practical. Godot's import workflow supports scene-level and per-object configuration, model/animation previews, and inherited scenes. Place gameplay bindings in the project's owned actor wrapper rather than relying on manual edits to generated import data. [G2]

Use the existing scale and orientation contract. Author humans at plausible meter-based dimensions, with neutral applied transforms and a ground-consistent root. Verify the resulting forward direction inside the actual controller; do not fix a wrong axis with unexplained nested rotations. Preserve the existing disabled-root-motion/in-place animation contract documented in `STORY_ART_AND_SOUND_BIBLE.md` and `monster_family_manifest.json`. Do not introduce root-motion locomotion as part of an asset replacement.

Godot can generate mesh LODs for imported scenes, but generated results can introduce artifacts, especially on skinned meshes. Inspect transitions around faces, fingers, straps, antlers, wing edges, and extreme deformations. Use reviewed manual lower-detail variants when automatic output damages identity. [G3]

The browser renderer is Godot's Compatibility/WebGL 2 path. Judge materials, transparency, fog interaction, and effects in that path early; native editor presentation alone is not acceptance for the browser build. [G4]

For a model using blend shapes, verify the exporter setting described in the Godot 4.6 glTF guide: export deformation bones only. Inspect the resulting shading and keep a tested source/export pairing. [G1]

## Eight-actor first production tranche

This sequence is a proposed order of model production, not permission to replace current actors in bulk. Preserve the project's existing one-playable-ticket acceptance process. Confirm exact NPC ordering against the current canonical roster.

| Order | Actor | Why it is useful first |
| --- | --- | --- |
| 1 | Anwen | Establishes close-up facial quality, cloth, hands, and the opening conversation standard. |
| 2 | Ghoulkin | Establishes frequent-enemy locomotion and a readable low-cost combat body. |
| 3 | Stalker | Proves that a second enemy has a distinct silhouette, anticipation, and movement rhythm. |
| 4 | Bog Wretch | Tests wet organic materials and a different encounter footprint. |
| 5 | Senn | Adds a distinct soldier's face, posture, clothing, and equipment language. |
| 6 | Rook | Tests another human silhouette and different clothing/equipment articulation. |
| 7 | Tor | Extends the human pipeline to another major NPC with an individually approved face, costume, and movement style. |
| 8 | Bell-Eater | Proves the bespoke boss pipeline, scale, phase readability, and browser cost. |

Next, finish the remaining major NPCs in chapter order and produce the creature families required by those chapters. Leave the largest unique bosses until their encounter spaces and camera requirements are stable. Build one representative per new skeleton family before commissioning the rest. Keep art approval and in-game acceptance as separate recorded milestones.

## Acceptance checklist per modeled actor

1. **Identity:** approved face and silhouette; matching forward/rear design decisions; intentional equipment; readable under the real level lighting.
2. **Geometry:** correct dimensions and origin; clean normals; no accidental duplicate surfaces; no floating face or body pieces; seams and interiors inspected.
3. **Deformation:** shoulders, elbows, wrists, fingers, hips, knees, ankles, neck, jaw, and all special appendages pass extreme-pose inspection. Clothing does not collapse through the body.
4. **Animation:** clips loop deliberately; turns and acceleration make sense; attacks telegraph and recover; feet do not skate or float; death/disable states stop damage correctly.
5. **Props:** hands grip intended points; attachments follow the right bones; staff/weapon sockets do not parent to the face; sheathing and pickup do not duplicate props.
6. **Materials:** no missing or black textures; normal direction and color-space sampling are correct; transparency works in Compatibility; metal and cloth retain different roughness.
7. **Gameplay:** collision and hurtboxes match the intended footprint; navigation and narrow passages work; interaction prompts attach correctly; established quest and save identifiers survive.
8. **Distance:** LOD transitions preserve silhouette; no facial or wing explosions; far actors stop unnecessary animation and effects according to the existing system.
9. **Browser:** one cold load and the relevant playable route on the target browser/device; no new shader stalls, resource leaks, console errors, or unacceptable memory/frame-time regressions.
10. **Evidence:** record the exact source/export revision, measured release-size delta, screenshots at gameplay and dialogue distance, remaining defects, and the user's acceptance status.

A beautiful sheet passes art direction only. A visually correct model passes modeling only. Runtime acceptance requires the complete relevant route and measured performance.

## Primary technical references

These references support the engine workflow. Numeric art budgets and production priorities above are authored proposals.

- [G1 — Godot 4.6: Available 3D formats](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [G2 — Godot 4.6: Import configuration](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
- [G3 — Godot 4.6: Mesh level of detail](https://docs.godotengine.org/en/4.6/tutorials/3d/mesh_lod.html)
- [G4 — Godot 4.6: Exporting for the Web](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)

Documentation checked 29 October 2026. Use the exact engine/exporter versions pinned by AshenOath for implementation.

Canonical repository baseline checked for this pack: `RafaTahir/AshenOath`, branch `codex/masterpiece-rebuild`, commit `08e5ef4b21dd75c1c90708c307de51f9a3812da0`. Senn is a soldier; Halvern is a dead figure retained through memory/story evidence and is not part of the 12-character roster. Preserve those distinctions.
