# CHAR-007 Result — Sister Anwen Shared-Rig Rebuild

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. Sister Anwen now uses the same Quaternius Universal Base humanoid family as Kael: a native-face female base fused with the matching skinned female peasant outfit and the shared UAL2 animation library.

## Changes

- Replaced Anwen's old Poly Pizza role mapping with `Female_Peasant.gltf` from the CC0 Modular Character Outfits: Fantasy pack.
- Added the selected female outfit GLB source and imported it through Godot's normal GLTF pipeline.
- Generalized the existing Kael composite hook into a shared male/female native-face body plus clothing-layer contract.
- Kept normalization, collision ownership, staff/equipment hooks, dialogue ownership, and physics-authoritative movement unchanged.
- Tightened Anwen's approach attention radius and turn response, reduced idle sway, and extended attention hold so she remains oriented toward Kael instead of drifting away at conversation range.
- Added a direct Anwen verifier for native head/hand bones, two synchronized animation players, rendered grounding, proxy-anatomy rejection, and player-facing approach behavior.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews character_anwen -NoCache
```

Direct `verify_char_007.gd` and the graphical `capture_char_007.gd` passed. The captures are 1280x720 and show Anwen's connected native-face body in front and three-quarter views.

## Evidence

- `Development_Gallery/screenshots/CHAR_007_Anwen_Shared_Rig.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_ThreeQuarter.png`

## Honest Limitation

This ticket establishes the shared body, face, clothing, animation, and facing contract. The source is intentionally stylized rather than photoreal. Older cleric styling, grey hair, bespoke stole/prayer details, eye motion, and final named-NPC identity treatment remain later character tickets; no detached face cards or fake neck geometry were added.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

For the ticket gate, use the command above. Production Web export and Vercel deployment remain deferred until the milestone boundary.

## Next Ticket

`CHAR-008` — Named NPC Identity: apply deterministic face, hair, complexion, occupation, and outfit recipes to Mira, Rook, Edric, Elna, Tor, Toma, Senn, and the remaining named actors.
