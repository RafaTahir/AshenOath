# FACE-003 Result — Native Faces and Eye Behavior

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. Route-visible humans and the first Wychwood enemy family now use an explicit native-face contract: imported head/skin/skull surfaces are accepted, synthetic face geometry is rejected, and existing imported eye meshes receive restrained focus and blink motion.

## Changes

- Added `CharacterFaceDriver`, a low-cost presentation node that only animates eye meshes already present in an imported character asset. It creates no face cards, eye boxes, hair meshes, or proxy anatomy.
- Connected the driver from `CharacterIdentityProfile` after material identity application and recorded native face-contract telemetry on the actor.
- Recognized imported human face/body surfaces and monster skull/body surfaces without treating the old procedural overlays as valid identity.
- Tightened proxy removal and verification so synthetic names such as `EyeWhite_L`, `Iris_R`, `Brow_L`, `NoseBridge`, `MouthLine`, and legacy face sockets fail while native `Eyes` and `Eyebrows` remain valid.
- Covered Kael, Sister Anwen, seven Greyfen life actors, and all five Wychwood encounter enemies through the runtime verifier.
- Added native-face portrait captures and a contact sheet at 1280x720.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews face -NoCache
```

The direct `verify_face_003.gd` gate passed, and the graphical capture passed on Compatibility/ANGLE. The full affected characters profile is the release checkpoint gate for this ticket.

## Evidence

- `Development_Gallery/screenshots/FACE_003_01_Kael_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_02_Anwen_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_03_Native_Face_Contact_Sheet.png`

## Honest Limitations

- The current Quaternius shared peasant layer is a stylized browser-safe source. Kael and Anwen now have real imported face geometry/materials, but bespoke hair, wardrobe, facial expressions, and occupation silhouettes remain later character tickets.
- Separate eye meshes exist on the native superhero base where exposed; peasant outfit meshes contribute textured body/face surfaces but do not invent eye geometry.
- Monster face acceptance covers the imported skull/body surfaces and keeps the current monster family mappings. A richer monster art pass remains in `MON-002`.
- Dummy/headless renderer teardown diagnostics remain known shutdown noise from the existing project; no new parser/resource failure was introduced.
- This ordinary ticket does not export or deploy Web production.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_face_003.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools\capture_face_003.gd
```

For normal play:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

## Next Ticket

`INPUT-003` — Universal Gamepad Core.
