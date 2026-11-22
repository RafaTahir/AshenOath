# WORLD-002 Vargan Composition Pass

Date: 2026-09-27. **Retained partial evidence; WORLD-002 is not accepted.**

## Changes

- Replaced skipped/floating gatehouse trim, cylindrical towers and incomplete
  keep with eight deterministic, indexed, two-surface authored meshes from the
  retained CC0 Quaternius Medieval Village MegaKit. Total resource size: 269365
  bytes. Embedded source checksums, license, campaign export ownership and a
  runtime manifest prevent silent asset drift.
- The actual gatehouse mesh now owns its masonry collision. Its wide central
  passage and west return remain open; walking into its wing blocks movement.
  Split north curtain collision around the route, retain tower footprints, and
  place the nonblocking backdrop keep wholly beyond the playable boundary.
- Replaced dashed/asphalt-looking road dressing with stone paving; grounded
  imported walls; replaced the stable, cistern and forge blockout presentation.
  Corrected the forge table collision height and moved the servant out of the
  stable footprint without changing its interaction ID, dialogue or quest.
- Castle doors retain their original nonblocking Areas, focus, destination and
  arrival contracts; native wooden doors and an open frame replace solid frames.
  One root-owned material is shared by repeated authored masonry instances.
- Added a scoped capsule/resource verifier, targeted profile and mandatory full
  release entry. No export or production Web output was changed.

## Evidence

- `D:/Temp/AshenOath/world002_vargan_architecture_contract_v5.log`: PASS, clean
  shutdown. Real CharacterBody capsule sweeps test both directions at seven
  lateral offsets; the wing contact, visible arch, materials, source hashes,
  runtime registration and campaign export filter pass.
- `world002_vargan_architecture_determinism_v1.log`: all eight rebakes reproduce
  byte-identical output. Manifest/profile JSON and release PowerShell parse.
- `world002_castle_current_v1.log` plus stderr: PASS, genuine Continue, physical
  marker/cart approaches, normal focused E, courtyard entry, guard conversation,
  notice, three-clue completion and pause-menu save. ANGLE driver advisory only.
- `world002_castle_return_v3.log` plus stderr: PASS, genuine courtyard save,
  keyboard Record Hall entry, manual save, Escape resume, focused return,
  south-arch crossing, west return, Approach arrival and manual save. No active
  or unclassified shutdown error. These are resumed native legs, not a complete
  uninterrupted campaign or browser route.
- Grounded before views: `.release-gate/world002_campaign_grounded_baseline/`.
  Fresh final views: `.release-gate/world002_vargan_architecture_final_current/`.
  Codex inspected both 1280x720 frames. They improve architecture, road contact,
  skyline, functional court landmarks and supported composition; they do not
  prove all campaign art, night states or performance acceptance. Gallery copies:
  `WORLD-002_Vargan_Approach_Authored.png` and
  `WORLD-002_Vargan_Courtyard_Authored.png`.

## Rejected Evidence And Remaining Blockers

- Contract v2 emitted a cleanup null-material error and is not a clean pass.
  The fixture now uses the existing renderer-safe retirement path; v3-v5 are
  clean. Return v2 and final capture v1 emitted a missing material-cache metadata
  error and are rejected for runtime acceptance; guarded cache lookup resolves
  it in current v3/final v2 evidence.
- Return v1 attempted movement from the manual-save pause menu. The driver now
  resumes through real Escape. That run also shows player movement while the
  menu is paused; record it as an ACCESS-001 blocker, not a successful route or
  an excused game behavior.
- Performance remains red. The clean return leg measured Record Hall 116.0 ms,
  Court return 91.9 ms, but cold Approach 929.9 ms exceeds 900 ms. Prior Record
  Hall 1576.7/1745.1 ms and unsettled Greyfen lows remain failures; cache-sensitive
  variation is not proof that either competing PERF-001 hypothesis is resolved.
- Old Mill, undercroft, assembly, Hart depth, remaining campaign states, full
  physical/browser route, current graphical FPS and payload remain unaccepted.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, set only the
child process APPDATA/LOCALAPPDATA under `D:/Temp/AshenOath`. Use Godot 4.6.3:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_vargan_architecture.gd
```

For the graphical return leg, copy the preserved genuine
`castle_evidence_v2_fixture` save into an isolated test profile and run:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --path . --script res://tools/verify_opening_real_input_native.gd `
  -- --continue-record-hall --castle-return-proof
```

No commit, push, merge, export or deployment. HEAD remains
`5b530361a5aae8612626532287b5bd27d7b244b8` on `codex/masterpiece-rebuild`.
