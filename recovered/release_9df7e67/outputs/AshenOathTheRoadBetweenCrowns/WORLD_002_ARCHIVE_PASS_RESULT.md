# WORLD-002 Record Hall Composition Pass

## Status

Retained partial evidence, 2026-09-27. WORLD-002 remains visually rejected at
full campaign scope. Formal recovery count remains 26/37 accepted.

## Changes

- Corrected the screenshot fixture: spatial validation preserves requested Y,
  so ordinary world captures now raycast physical support, place Kael's feet
  above that floor, and require grounded capture. Forced-recovery evidence keeps
  its intentionally invalid placement. The old airborne comparison is rejected.
- Baked the existing CC0 Quaternius cabinet, chair, table and book meshes into
  one indexed two-surface archive. Preserved all twenty cabinets and their
  layout; added 120 shelf book groups and reading-table stacks.
- Replaced pale furniture with timber, the mud-looking aisle with stone, and
  road-like dashed markings with restrained floor insets.
- Grounded visible ledger pages and consequence seals on the actual 0.82 m
  reading table rather than floating them at 1.70 m.
- Preserved room collision, actors, gates, navigation, quest interaction
  positions, light count, story choices and save format.
- Registered the generated campaign-owned asset and focused resource gate.

## Evidence

- `D:/Temp/AshenOath/world002_grounded_capture_parse_v2.log`: PASS.
- `world002_record_grounded_v1`: FAIL; the first candidate still preserved Y=1
  and did not land in time. Its pixels are not accepted evidence.
- `world002_record_grounded_v2.{log,stderr.log}`: PASS, physical support and
  grounded normal camera; environmental ANGLE advisory only.
- `world002_archive_contract_v1.log`: PASS at resource-contract scope.
- `world002_archive_rebuild_v1.log`: repeated bake has identical SHA-256.
- `world002_record_archive_candidate_v1.{log,stderr.log}`: PASS, two current
  1280x720 frames inspected against grounded before frames. Shelf contents,
  furniture, aisle and ledger emphasis improve without black strips or floating
  books. This is a staged visual fixture, not player-route evidence.
- `world002_archive_ledger_v1.{log,stderr.log}`: PASS, real keyboard Continue
  from a byte-copy of the genuine pre-ledger save, physical north aisle movement,
  focused E, visible choice, haunting staging, and pause-menu manual save. Clean
  shutdown; ANGLE advisory only. This is a resumed native leg, not full campaign
  or browser certification.

Before: `.release-gate/world002_record_grounded/38_record_hall.png`

After: `.release-gate/world002_record_archive_candidate/38_record_hall.png` and
`57_castle_record_hall_haunting.png`. Corresponding timestamps remain alongside.

The archive is 1,134,548 bytes, 65,170 triangles, two surfaces.
SHA-256: `ddc3f75b2aa6937783d59350bd780ee42dfce18c3aefb76d6416191fce27486f`.
Sources and their checksums are embedded in the generated mesh; CC0 evidence is
`assets_external/licenses/quaternius_fantasy_props_megakit/License_Standard.txt`.

## Remaining Blockers

Full Castle, Old Mill, undercroft, assembly and Hart composition review remains
open. The successful ledger run still takes 1,576.7 ms to activate Record Hall;
this fails PERF-001 and is not transition acceptance. No FPS, memory, packed Web,
browser or production claim is made. No Web export, commit, push, merge or deploy.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use the Godot
4.6.3 executable at `C:/Temp/AshenOathGodot4.6.3/`:

```powershell
& $godot --headless --path . --script res://tools/build_record_archive.gd
& $godot --headless --path . --script res://tools/verify_record_archive.gd
& $godot --path . --resolution 1280x720 --script res://tools/capture_slice_screenshots.gd -- --record-only --candidate-dir=res://.release-gate/world002_record_review
```

Set APPDATA/LOCALAPPDATA for that child process only to an isolated directory
under `D:/Temp/AshenOath`; leave system environment and original saves untouched.
For the ledger test, copy the preserved genuine Record Hall pre-choice profile
to a new D: fixture and run `verify_opening_real_input_native.gd` with
`--continue-record-ledger`. Do not replay unaffected opening gates.
