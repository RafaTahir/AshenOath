# CHAR-006 Result — Kael Shared-Rig Replacement

## Status

Implemented and verified on the development branch. Kael now resolves to a shared Quaternius humanoid ecosystem at runtime: a native-face male base combined with the matching CC0 modular male peasant clothing scene. Both skinned layers use the same 65-bone humanoid contract and shared UAL2 animation clips.

## Changes

- Added the matching modular outfit source and CC0 license record.
- Composed the native-face male body with the skinned clothing layer instead of adding root-mounted costume geometry.
- Fused the UAL2 animation library onto every matching rig in the composite and updated `CharacterAnimationDriver` to drive all animation players together.
- Switched Kael’s runtime visual role to the shared composite body.
- Preserved physics-authoritative movement, normalized role height, bone-bound sword socket, Oathfire hand sockets, and existing combat state calls.
- Preserved the old runtime fallback for every role that has not passed its own replacement gate.
- Fixed textured character materials so role palette colors no longer darken or erase imported face/cloth atlases.
- Added a real Kael fused-rig and sword-motion capture view.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews character -NoCache
```

The direct CHAR-006 gate passed: Kael instantiates, has two synchronized animation players, native head and hand bones, a `hand_r` sword socket, fused UAL2 clips, and measurable hand-bone movement during the attack clip. The full targeted gate should be rerun after this result is staged so its cache includes the final ticket files.

Fresh visual evidence:

- `Development_Gallery/screenshots/CHAR_006_Kael_Fused_Rig.png`
- `Development_Gallery/screenshots/CHAR_006_Kael_Sword_Attack.png`

## Honest Limitation

The current Kael composite is a strong shared-body and clothing foundation, not photorealism. The face is native mesh/texture and readable, but the source remains stylized. Anwen, crowd roles, monsters, and final role-specific outfit recipes remain separate tickets.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

For the ticket gate, use the command above. Production Web export and Vercel deployment remain deferred until the relevant milestone boundary.

## Next Ticket

`CHAR-007` — Sister Anwen Rebuild: compose the female native-face body with a matching modest outfit, preserve shrine staging, and verify stable player-facing dialogue orientation.
