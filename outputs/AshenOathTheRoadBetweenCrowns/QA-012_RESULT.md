# QA-012 Result

## Status

PASS for the real-input released-route candidate gate.

## Changes

- Replaced the previous lifecycle-only verifier with a graphical Compatibility
  route driver that uses the normal player movement, interaction focus, `E`
  activation, dialogue continuation, combat input, gate transition, save-state,
  and zone activation paths.
- Added runtime keyboard UI bindings and a dialogue input fallback so Enter,
  keypad Enter, and Space activate the focused dialogue control through the
  normal HUD path.
- Added a bounded combat-contact fallback for a clearly front-facing target
  when an imported weapon sweep is momentarily outside the enemy capsule.
- Changed the real-input combat driver to approach enemies from outside their
  physics capsules instead of routing into their centers. Approach movement is
  short-stepped so the player remains inside the authored clearing and does
  not follow a leashed enemy beyond the arena.
- Reserved the Greyfen long-road approach before scenery generation and made
  low berm dressing honor reserved corridors. This removes the west-gate
  blocker found by the real route.
- Moved the Castle Courtyard outer return gate outside the gatehouse left wing
  and updated the spatial registration so the return corridor is physically
  reachable.
- Added a `qa012` targeted ticket-gate profile for the real route plus runtime,
  save, gate, navigation, and river safety support checks.

## Real-Input Route Evidence

The graphical route passed on a fresh isolated user-data profile:

`New Game -> Greyfen -> Sister Anwen -> Wychwood -> corpse -> black feathers -> claw marks -> five-enemy Wychwood fight -> Greyfen -> evidence report -> Wychwood -> Greyfen -> Deep Woods -> Old Mill -> Burned Farmstead -> Marsh Crossing -> Bandit Road -> Castle Approach -> Castle Courtyard -> Record Hall -> Castle Courtyard -> Castle Approach -> Bandit Road -> Marsh Crossing -> Burned Farmstead -> Old Mill -> Deep Woods -> Wychwood -> Greyfen`

The route used real movement and focus resolution for every interaction and
gate. It observed `undercroft`, `assembly`, and `hart_glade` as correctly
story-gated rather than unlocking them through verifier state mutation.

## Verification

- `content_integrity`: PASS
- `runtime_smoke`: PASS
- `verify_qa_012`: PASS
- `verify_runtime_regressions`: PASS
- `verify_save_003`: PASS
- `verify_gate_transitions`: PASS
- `verify_navigation_001`: PASS
- `verify_river_swimming`: PASS
- Targeted runner: `tools/run_ticket_gate.ps1 -Profiles qa012 -NoCache`: PASS

The direct graphical evidence is recorded in:

- `.release-gate/ticket/verify_qa_012.log`
- `.release-gate/ticket/verify_qa_012.log.godot.log`

Existing fresh character, dialogue, opening, world, and performance captures
remain the visual evidence set. QA-012 changes route behavior and therefore
does not create a separate screenshot suite; the complete screenshot gallery
remains a RELEASE-003 gate.

## Known Limitations

Godot Compatibility reports renderer/RID/ObjectDB cleanup messages after the
verifier pass during isolated process teardown. No active gameplay parser,
resource, material, or renderer failure occurred before the pass marker. The
shutdown diagnostics remain an ENGINE-004 lifecycle release blocker and are
documented rather than suppressed.

QA-012 proves the released route and input contract. It does not claim that
the unfinished final asset-family replacement, full boss spectacle, or final
visual approval has shipped.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles qa012 -NoCache
```

The next release ticket is `RELEASE-003`. No Web export, `main` push, or Vercel
deployment was performed for QA-012.
