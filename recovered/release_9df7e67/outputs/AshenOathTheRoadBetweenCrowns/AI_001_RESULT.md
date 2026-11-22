# AI-001 Result - Navigation-Safe Tactical Roles

Status: accepted on 2026-09-21.

## Delivered

- Released Wychwood enemies use navigation-backed engagement lanes and
  CharacterBody velocity steering rather than post-slide position correction.
- Skirmisher, flanker, feinter, and brute profiles retain distinct preferred
  distances, approach angles, cadence, and tactical targets.
- A single encounter-level reservation owns the attack lane; rear actors may
  not strike through allies.
- Dormant staging, skeleton-driven attack contact, perception memory, retreat,
  leash return, river exclusions, and obstacle collision remain authoritative.

## Verification

- `tools/verify_ai_001.gd`: PASS for five-enemy staging, distinct profiles,
  navigation, minimum spacing, single attack token, lane clearance, and
  skeleton contact motion.
- `tools/verify_ai_002.gd`: PASS for all eight released family profiles,
  perception contracts, velocity-owned spacing, and absence of teleport
  correction.
- `tools/verify_ai_003.gd`: PASS at a forced 30 Hz physics cadence. The live
  pack preserves route safety and spacing, cannot cross a runtime blocking
  body, retreats after attack, and returns toward home beyond its leash.

Detailed logs:

- `D:\Temp\AshenOath\ai001_current.log`
- `D:\Temp\AshenOath\ai002_current.log`
- `D:\Temp\AshenOath\ai001_lowframe_final_v2.log`

## Remaining Scope

Boss phase-specific behavior remains owned by `BOSS-001`; complete production
campaign certification remains owned by `CERT-001`.

## Running Steps

```powershell
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --path . --script res://tools/verify_ai_001.gd
& $godot --path . --script res://tools/verify_ai_002.gd
& $godot --path . --script res://tools/verify_ai_003.gd
```
