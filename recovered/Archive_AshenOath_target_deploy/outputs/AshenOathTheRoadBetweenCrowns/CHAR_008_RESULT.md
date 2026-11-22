# CHAR-008 Result — Named NPC Identity

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. Route-visible named human roles now resolve through the same Quaternius Universal Base + Modular Character Outfit ecosystem instead of mixing Poly Pizza body families.

## Changes

- Mapped Mira, Rook, villagers, widow/pilgrim, worker, Castle guard, and road-ranger roles to the selected shared male/female peasant GLTF sources.
- Generalized the existing native-face composite hook so every matching shared outfit receives the correct male or female base, skeleton, and UAL2 animation library.
- Preserved role-specific deterministic palette profiles for herbalist, smuggler, worker, mourner, guard, ranger, and generic crowd identities.
- Fixed identity material application to preserve imported face/clothing atlases while applying a restrained role tint; imported textures are no longer replaced by a flat solid color.
- Kept physics, collision, equipment, interaction, schedule, and dialogue ownership unchanged.
- Added named-role contract verification and a four-actor 1280x720 lineup capture.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews character_named -NoCache
```

Direct `verify_char_008.gd` and graphical `capture_char_008.gd` passed. The targeted characters profile remains the required final gate before checkpointing.

## Evidence

- `Development_Gallery/screenshots/CHAR_008_Named_Ecosystem_Lineup.png`

## Honest Limitation

This ticket establishes source-family cohesion and native faces. The current outfit source is a compact shared peasant layer, so occupation silhouettes are still intentionally restrained; bespoke cleric, guard, ranger, and named wardrobe variants remain a later outfit/identity pass. The captured lineup is visibly coherent but still stylized rather than realistic.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

For the targeted gate, use the command above. Production Web export and Vercel deployment remain deferred until the milestone boundary.

## Next Ticket

`CHAR-009` — Crowd Cohesion and Variation: apply shared-base combinations, adult height limits, deterministic variation, and adjacent-actor duplicate rejection to villagers, guards, servants, travelers, and patrols.
