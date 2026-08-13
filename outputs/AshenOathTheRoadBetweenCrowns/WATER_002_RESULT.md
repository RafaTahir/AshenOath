# WATER-002 Result — Living River

## Files changed

- `scripts/zones/river_section.gd`
- `scripts/river_motion_controller.gd`
- `tools/verify_water_002.gd`
- `tools/capture_water_002.gd`
- `tools/gate_profiles.json`
- `Development_Gallery/screenshots/WATER-002_*.png`

## Implementation

- Added one shared `RiverMotionController` for lightweight floating leaves and seven animated surface ripples per river section.
- Reworked the existing river shader with directional UV flow, layered current bands, depth tint, shoreline foam, ripple highlights, and controlled normal variation.
- Added north/south bank wetness strips so the water reads as integrated with the ground rather than a raised blue slab.
- Kept spatial current audio short, local, restrained, and generated through the existing runtime path.
- Preserved bridge-only traversal, river barriers, same-bank recovery, NPC/enemy route safety, and existing river dimensions.

## Verification

Run from the project directory:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_water_002.gd
& "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns\tools\run_ticket_gate.ps1" -Profiles water -ChangedViews river_life -NoCache
```

The profile includes content integrity, runtime smoke, the new river-life contract, the existing water contract, river-safety, navigation, and zone-budget checks, followed by the two changed-view captures.

## Running steps

1. Open PowerShell in this project directory.
2. Run the local game: `& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .`.
3. Choose **New Game**, walk to a Greyfen bridge, and observe the moving current, shore foam, wet banks, leaves, and ripples.
4. Cross only by the bridge and continue toward Wychwood; accidental channel entry should recover to the same bank.
5. For the Web candidate, serve the already-exported folder with `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 -d ..\AshenOath_Web` and open `http://127.0.0.1:8787/index.html`.

## Known limitations

- The river remains a lightweight procedural channel, not a simulated fluid surface.
- The current project still uses stylized browser-safe world materials; later Wychwood authoring is handled by `WORLD-013`.
- No Web export or production deployment is performed for this ordinary ticket.

## Next ticket

`WORLD-013 — Authored Wychwood`.
