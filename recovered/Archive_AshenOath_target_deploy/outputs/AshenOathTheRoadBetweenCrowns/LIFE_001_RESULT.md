# LIFE-001 Result — Greyfen Daily Life

## Status

Implemented and checkpointed on `codex/soul-rebuild`. The existing Greyfen population now has deterministic authored routine beats while preserving the current seven-actor minimum, river-aware paths, named NPC ownership, minigames, quests, and save systems.

## Changes

- Added explicit routine profiles for the well, notice board, shrine, forge, herb stall, lookout, market, and named occupations.
- Added activity states for working, prayer, notice reading, and road attention with clean transitions back to locomotion.
- Added deterministic actor metadata for ticket ownership, routine, occupation, current life state, and story reaction.
- Added report and cemetery-bell reaction state so ambient life acknowledges Road of Crows aftermath without changing quest progression.
- Kept all route segments validated through `ZoneSpatialService`; no new actor, asset, zone, or river crossing was introduced.
- Added a public routine snapshot used by the LIFE-001 verifier.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles life -ChangedViews greyfen_life -NoCache
```

Result: **PASS**.

Passed gates: content integrity, runtime smoke, Greyfen life regression, LIFE-001 routine/pose/reaction checks, navigation, river safety, and graphical capture. Captures ran through Compatibility/ANGLE at 1280x720.

## Evidence

- `Development_Gallery/screenshots/LIFE_001_01_Greyfen_Spawn_Life.png`
- `Development_Gallery/screenshots/LIFE_001_02_Shrine_Pilgrim.png`
- `Development_Gallery/screenshots/LIFE_001_03_Forge_Helper.png`

The three frames were inspected for nonblank output, route readability, grounded actors, and visible activity staging.

## Known Limitations

- The routines remain lightweight procedural schedules; they are not full navigation-driven schedules with door interiors or voiced conversations.
- Greyfen architecture and character fidelity remain within the current stylized asset foundation. Later material, character, world, and audio tickets own larger presentation upgrades.
- Standalone Godot checks still emit known shutdown-only RID/ObjectDB diagnostics after their pass marker; no active gate assertion or null-material surface failed.
- This ordinary ticket does not export, modify tracked `web/`, push `main`, or deploy Vercel.

## Running Steps

Targeted ticket gate:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles life -ChangedViews greyfen_life -NoCache
```

Direct routine verification:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_life_001.gd
```

Graphical capture:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools\capture_life_001.gd
```

Normal play:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

## Next Ticket

`WATER-002` — Living River.
