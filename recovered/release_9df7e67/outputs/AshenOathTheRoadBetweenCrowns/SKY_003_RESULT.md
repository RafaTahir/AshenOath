# SKY-003 Result — Living Sky and Weather

## Files changed

- `scripts/sky_backdrop.gd`
- `scripts/visual_director.gd`
- `tools/verify_sky_003.gd`
- `tools/capture_sky_003.gd`
- `tools/gate_profiles.json`
- `Development_Gallery/screenshots/SKY-003_*.png`

## Implementation

- Added a lightweight authored sky state layer. The native `Environment.BG_SKY` supplies the world gradient; a star-only additive overlay supplies camera-reliable night stars without covering gameplay geometry.
- Added authored vertical sky gradients for day, dusk, night, and zone-specific profile tints instead of exposing a flat clear color.
- Added mutually exclusive procedural sun and moon discs, subtle halos, deterministic stars, and irregular multi-lobe cloud formations. The star overlay is limited to the upper sky and is hidden indoors.
- Added quality budgets: Potato 2 clouds/28 stars, Balanced 4 clouds/62 stars, Quality 6 clouds/96 stars.
- Kept the existing 3D celestial nodes and cloud pool for compatibility with prior contracts; interiors suppress both systems and the backdrop.
- No external textures, shaders, gameplay systems, or save fields were added.

## Verification and captures

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_sky_003.gd
& .\tools\run_ticket_gate.ps1 -Profiles sky_003 -ChangedFiles @('outputs/AshenOathTheRoadBetweenCrowns/scripts/visual_director.gd','outputs/AshenOathTheRoadBetweenCrowns/scripts/sky_backdrop.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/verify_sky_003.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/capture_sky_003.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/gate_profiles.json','outputs/AshenOathTheRoadBetweenCrowns/SKY_003_RESULT.md') -NoCache
```

The capture helper writes six fresh 1280x720 views into `Development_Gallery/screenshots/`:

- `SKY-003_01_Greyfen_Day_Sun_Clouds_20260813_101934.png`
- `SKY-003_02_Greyfen_Night_Moon_Stars_20260813_101934.png`
- `SKY-003_03_Wychwood_Day_Sun_Clouds_20260813_101934.png`
- `SKY-003_04_Wychwood_Night_Moon_Stars_20260813_101934.png`
- `SKY-003_05_Castle_Day_Sun_Clouds_20260813_101934.png`
- `SKY-003_06_RecordHall_Interior_NoSky_20260813_101934.png`

Codex visual review confirmed nonblank 1280x720 frames, a readable circular sun by day, a readable moon and star field by night, and no sky objects in Record Hall. This ticket uses targeted verification only; it does not export or deploy production.

## Running steps

1. Open PowerShell in this project directory.
2. Run `& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .`.
3. Choose **New Game**.
4. Look up during daytime: the sun and layered clouds should be visible over the route.
5. Set or wait for night: the moon and stars should be visible while the road and actors remain readable.
6. Enter Record Hall: outdoor sky layers should disappear while authored interior lighting remains.

## Known limitations

- The sky remains procedural and stylized; it is not a volumetric atmosphere or photographic cloud system.
- Existing Godot shutdown RID/ObjectDB diagnostics and the river controller interpolation warning remain tracked separately from this ticket.
- The old 3D cloud pool remains resident for compatibility and budget verification. The native sky supplies the gradient and celestial environment, while the additive star pass supplies visible night stars in Compatibility/Web framing.

## Next ticket

`PROP-003 — Functional World Objects`.
