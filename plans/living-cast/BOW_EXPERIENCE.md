# Kael's Bow Experience

## Implementation, 2026-10-23

- Retained Ranger bow/arrow, Kael body, atlas, skin and equipment authority. No replacement character, texture, save schema, damage balance or new projectile simulation.
- Selecting/drawing the bow transfers it from back to left hand. A dedicated upper-body pose extends the bow arm, draws the right hand toward a jaw-side anchor, curls the grip/hook fingers and follows through after release. Existing locomotion still owns the legs.
- The imported bow also contains a vertically packed display arrow. Hide that duplicate in both hand and back assemblies. Replace its rigid string with two tension segments and bend the retained limbs through one local blend shape. Nocked arrow and string use the same draw state.
- Hold Aim, hold Fire to draw, release Fire to loose. Lowering Aim cancels without spending an arrow. Touch keeps the existing Aim toggle and labels its held action Draw/Loose; sliding away cancels rather than firing. Existing remaps and controller vibration preferences remain authoritative.
- Third person uses a smoothly blended precision shoulder view; first person uses eye-level sighting. Neither rewrites the chosen zoom distance or saved sensitivity. Aim reduces effective sensitivity, without a forced perspective change or camera shake on release.
- First-person arms are index-filtered from Kael's existing skinned surfaces, retaining their atlas and skeleton. Head/torso remain shadow-only; no floating proxy hands or extra body textures are exported.
- Camera centre, reticle, bow presentation and release share an aim solution. Arrows leave the rendered arrow rest, not the camera. Camera-to-target and bow-to-target rays handle parallax; near scenery/eye-to-bow obstruction cancels the shot before ammo consumption. No hidden target-lock redirect at release.
- Reticle contracts during draw, highlights full draw and shows empty/blocked status. The practice range uses the same reticle. Existing combat remains hitscan with a visual trail, now terminated at its actual hit.
- Pause/context change, hit, dodge, death, weapon change, arrow change and Oathfire relinquish the bow action. No held-input release can fire a buffered shot after those interruptions.

## Reference

Guerrilla's [Horizon Forbidden West development account](https://blog.playstation.com/2021/10/25/horizon-forbidden-west-master-aloys-new-abilities/) informed readable maximum-draw feedback and integration with the existing toolkit. This is an adaptation, not a claim of equivalent animation fidelity or archery simulation.

## Delivery State

Implementation: present. Affected controller/UI compiler-only checks and the production Godot build completed without reported compiler/parser errors. Runtime/user acceptance: unverified. No gameplay/browser test was run; the previous actor-presence allocation is already consumed.

Candidate: `bow-experience-20261023`, 17 files, **104855895 bytes**, **1705 bytes below** the strict cap. PCK SHA-256: `68afa4234867988914ba0ff3c68077ac42acb806d02eb8c7fad4e51b47503c5f`. Initial packaging exceeded the complete-directory limit by 84 bytes; removing only JSON whitespace from the release manifest recovered 1789 bytes, preserving all fields, hashes, game bytes and artwork. The package inspector passed after that formatting correction; no second game build was required.

Source baseline: `2dc5ec77499d6c3c71c5a5bf8be46f3e83207a9f` plus these working changes. The CAST-010 publication receipt under `.release-gate/living-road/` records actual commit, push and deployment separately from user acceptance.

## Files

Under `outputs/AshenOathTheRoadBetweenCrowns/`:
- `scripts/bow_presentation.gd`, `scripts/bow_reticle.gd`: retained-mesh pose, hands, string, arrow and sight.
- `scripts/player_controller.gd`, `scripts/camera_controller.gd`, `scripts/character_life_modifier.gd`: bow input/state, physical aim, precision framing and optional elbow pole for the existing arm solver.
- `scripts/hud.gd`, `scripts/input_router.gd`, `scripts/mobile_touch_controls.gd`: reticle ownership, control descriptions and cancellation/Draw/Loose semantics.
- `scripts/game.gd`, `scripts/greyfen_archery_range.gd`, `scripts/preparation_view_model.gd`: hit-aligned trail, shared practice sight and truthful equipment description.
- `tools/build_web_runtime_manifest.py`: compact shipping metadata, retaining the original strict size and hash checks.

The normal build also refreshed its prepared actor/Bracken resources, pack ledgers and exact `web/` transport. No raw character atlas, encounter, quest or save content was removed.

## User Checks

1. Select, draw and stow the bow in third and first person. Check complete original hands, bow size, grip, nocked arrow, string and relaxed carry.
2. Aim high/low and turn through 360 degrees; draw partially/fully, loose, cancel and repeat. Check the shoulder/eye views and zoom transitions, including at walls.
3. Walk/reverse while aiming; check body/view heading, legs, hand contact and no spinning. Try hit/dodge, pause/Resume, weapon/Oathfire changes and Save/Continue during/after aim; no surprise shot or lost ammo on cancellation.
4. Check keyboard/mouse, remapped controls, gamepad and phone Aim/Draw/Loose. Slide off Draw to cancel; test empty ammo, arrow cycling, training targets and actual enemies.

Real phone appearance/input, controller hardware, hand fitting in motion, runtime errors and measured responsiveness remain UNVERIFIED - REQUIRES USER TESTING.
