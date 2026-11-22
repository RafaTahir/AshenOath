# CHAR-GAMEPLAY-QA-001 Result

Date: 2026-08-26
Branch: `codex/masterpiece-rebuild`
Scope: `CHAR-010` through `CHAR-013`, `EQUIP-001`, `ANIM-004`, `BOW-001`,
`BOW-002`, `AMMO-001`, and `SHOP-001`

## Changes

- Promoted the selected Quaternius animated human family to the runtime role
  contract: Warrior for Kael/guards, Cleric for Anwen, Rogue for agile roles,
  Monk for villagers, and the existing processed Ranger for Captain Senn.
- Kept each selected body as one connected imported hierarchy with one
  `Skeleton3D` and one `AnimationPlayer`; preserved the embedded legacy
  fallback for unavailable campaign monster families.
- Added `EquipmentLoadout` as the saved state owner for sword/bow mode,
  sheathing, selected arrow, hand sockets, diagonal back scabbard, bow, and
  quiver. Runtime transforms remain bone/equipment controlled.
- Mapped direct models to their actual imported animation names and kept root
  motion disabled. Kael's hand sword moves with the imported hand bone; the
  sheathed sword, bow, and quiver remain visible in back sockets.
- Preserved the first bow slice: target-aware aim/release, wall-clipped arrow
  resolution, Standard/Bodkin/Ashfire ammunition, HUD counts, Tor's Forge,
  Mira's Apothecary, emergency refill, and save/load compatibility.
- Made selected-family faces count as native face contracts without creating
  detached face cards or synthetic eye geometry. NPC wrappers inherit the
  selected body's identity metadata.
- Made pack hashing portable across the bundled PowerShell runtime and made
  Web export order explicit: build packs, sync hashes into both manifests,
  then export the embedded root PCK.

## Verification

Passed targeted gates:

- `run_ticket_gate.ps1 -Profiles char_gameplay_qa_001 -NoCache`
  (`content_integrity`, `runtime_smoke`, character QA, face QA, bow/shop)
- `run_ticket_gate.ps1 -Profiles characters -NoCache`
  (character roles, motion, animation, face, NPC-life, runtime checks)
- `verify_asset_acceptance.py`
- `verify_asset_005.py`
- `verify_pipe_003.py`
- `verify_load_qa_002.py --candidate-dir .release-gate/runtime-packs`
- `verify_runtime_packs.py`
- `verify_web_export.py ..\AshenOath_Web`
- Packed Web startup with the exported `index.pck`

The final export passed Chrome and Edge at native `1280x720` WebGL2 with no
JavaScript, resource, or Godot console errors. Latest browser readings:

| Browser | Engine ready | New Game | JS heap | Result |
|---|---:|---:|---:|---|
| Chrome | 8.13 s | 4.44 s | 11.8 MB | pass |
| Edge | 8.72 s | 4.33 s | 11.8 MB | pass |

## Screenshots

Fresh Codex-reviewed evidence:

- `Development_Gallery/screenshots/CHAR_006_Kael_Fused_Rig.png`
- `Development_Gallery/screenshots/CHAR_006_Kael_Sword_Attack.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_Shared_Rig.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_ThreeQuarter.png`
- `Development_Gallery/screenshots/CHAR_008_Named_Ecosystem_Lineup.png`
- `Development_Gallery/screenshots/CHAR_009_Greyfen_Crowd_Variation.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_01_Senn_Portrait.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_02_Senn_Walk.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_03_Senn_Gameplay.png`
- `Development_Gallery/screenshots/FACE_003_01_Kael_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_02_Anwen_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_03_Native_Face_Contact_Sheet.png`
- `.release-gate/ticket/milestone_c_browser_chrome.png`

The frames show the selected native bodies, front-facing NPC variation, Kael's
hand sword and back scabbard, and the non-placeholder Greyfen Web runtime.

## Known limitations

- The selected Quaternius bodies are cohesive stylized game characters, not
  photoreal or bespoke AAA faces. Richer facial expression and monster-family
  replacement remain Milestone E work.
- Monster roles remain explicit pending/fallback records in the asset
  manifests; this milestone does not claim `MON-002` completion.
- No physical controller was attached in this Windows run. Software action
  mapping, glyph/profile plumbing, and disconnect-safe paths passed; Xbox,
  DualShock, DualSense, Switch Pro, and generic physical certification remain
  `untested_no_hardware`.
- Isolated headless character checks may emit shutdown-only allocator/ObjectDB
  diagnostics after their pass marker. The final browser run had no active
  renderer, resource, or console error.

## Running

From the project root:

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN='C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles char_gameplay_qa_001 -NoCache
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles characters -NoCache
& .\Export_Web_Build.bat
node .\tools\verify_web_browser.mjs --export ..\AshenOath_Web --renderer hardware --timeout 120000
```

Select **New Game**. Use `1`/`2` to switch sword and bow, hold right mouse
button to aim, release to fire, and use `T` for soft lock. Tor's Forge and
Mira's Apothecary remain on the Greyfen route.
