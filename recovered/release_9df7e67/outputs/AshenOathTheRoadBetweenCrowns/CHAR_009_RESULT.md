# CHAR-009 Result — Crowd Cohesion and Variation

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. Greyfen ambient routines now use a deterministic, shared humanoid crowd contract with adult-scale variation and adjacent-silhouette protection.

## Changes

- Removed the old `0.82` young-villager multiplier that created undersized adults and compounded normalized transforms.
- Bounded ambient scale variation to `0.96–1.04` after role normalization.
- Alternated the existing male/female shared body roles so adjacent ambient routines do not repeat the same body family.
- Added deterministic identity profiles for villagers, farmer, widow, herbalist, smuggler, worker, and generic crowd roles.
- Preserved bridge-safe schedules, NavigationAgent3D contracts, distance suspension, animation rates, and named-NPC routines.
- Removed the legacy hard-coded 180-degree override so shared humanoid forward axes remain consistent with the role contract.
- Added crowd-scale, identity, skeleton, animation, grounding-contract, and proxy-anatomy verification.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews crowd -NoCache
```

Direct `verify_char_009.gd` and graphical `capture_char_009.gd` passed. The full characters profile is the final ticket gate before checkpointing.

## Evidence

- `Development_Gallery/screenshots/CHAR_009_Greyfen_Crowd_Variation.png`

## Honest Limitation

The selected CC0 outfit source remains a compact peasant layer, so variation is currently driven by shared body sex, normalized proportion, deterministic complexion/material treatment, and role identity rather than bespoke armor, robes, tools, or hair sets. Those stronger occupation silhouettes belong in later wardrobe/world tickets.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

For the targeted gate, use the command above. Production Web export and Vercel deployment remain deferred until the milestone boundary.

## Next Ticket

`ANIM-003` — Shared Animation Presentation: map the shared clips to locomotion, combat, work, dialogue, and death states without sliding, snapping, synchronized crowd motion, or detached equipment.
