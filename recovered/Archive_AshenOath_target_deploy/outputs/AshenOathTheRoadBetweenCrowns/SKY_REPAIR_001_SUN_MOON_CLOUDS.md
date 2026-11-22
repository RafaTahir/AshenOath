# SKY-REPAIR-001: Sun, Moon, Stars, Clouds, and Lighting

## Files changed

- `scripts/visual_director.gd`
- `Development_Gallery/screenshots/LIGHT_001_*` (generated capture evidence; ignored by the source repository)

## Repair

- Balanced now exposes four cloud clusters, Quality exposes seven, and Potato keeps two low-overdraw clusters.
- Cloud formations remain visible from ordinary Greyfen, Wychwood, and Castle camera framing instead of being placed behind the camera.
- The sun and moon use round emissive discs rather than tiny rectangular cards. Their positions are camera-readable, mutually exclusive, and still driven by the existing 36-minute cycle.
- Celestial materials are depth-safe against distant scenery while remaining small and restrained; indoor profiles continue to suppress sky geometry.
- Night remains readable and visibly nocturnal, with stars and the moon present in captured play views.

## Verification

- `tools/verify_light_001.gd`: PASS.
- `tools/capture_light_001.gd`: PASS, eight native 1280x720 views.
- Manual review: Greyfen day/night and Wychwood day show the sun/cloud state; Greyfen night shows the moon/stars and readable routes.

The graphical run still emits Godot's known teardown allocator/RID warnings after the successful capture. They occur during process shutdown, not while the scene is rendering; active resource verification remains a later release gate.

## Running steps

From `outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools/verify_light_001.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools/capture_light_001.gd
```

## Remaining issues

The current world art and cloud texture are still stylized and below the Witcher 3 benchmark. This ticket makes celestial states visible and readable; it does not replace buildings, trees, terrain, or character meshes.

## Next repair

Continue Milestone 2 with the sword/parry/Oathfire presentation repair, then tighten the character visual gate so incomplete or primitive major actors cannot pass as finished.
