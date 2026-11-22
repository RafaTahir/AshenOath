# STORY-001 Choice Coverage - Recovery-004

Updated 2026-09-28. This is an evidence-gap map, not ticket acceptance.
Authoritative status: RECOVERY_004_ISSUE_REGISTRY.json. All named logs below
are under D:/Temp/AshenOath. Native branch checks do not replace continuous
campaign, browser, visual, or performance acceptance.

The five Road clues now pass 120 logic-order permutations plus a graphical
post-fight drag-marks/Oren route without ghost credit. A separate graphical
board Escape refusal, ordinary Save, Continue, later Bitter Roots acceptance
and Save pass. See STORY_001_CONTINUOUS_ROUTE_RESULT.md. These are bounded
native checks, not all refusal/quest combinations or production certification.

All ten default side quests have preserved graphical real-input PASS logs with
ordinary saved outcomes under `D:/Temp/AshenOath`: `side_widow_native_v4`,
`side_iron_native_v5`, `side_bitter_native_v3`, `side_black_dog_native_v7`,
`side_empty_native_v2`, `side_oren_native_v4`, `side_candles_native_v1`,
`side_measure_native_v2`, `side_rook_native_v1`, and `side_banner_native_v1`.
Alternative decisions and reloads remain separately documented below. These
native results cannot substitute for the required production-player level.

## Main Campaign Gaps

Source: data/campaign_dialogue.json and the current real-input driver.
Reconcile historical evidence before executing any row; do not replay an
already-proven branch merely because it is absent from this compact table.

| Choice group | Driver's established path | Additional paths needing explicit evidence reconciliation |
| --- | --- | --- |
| Miller record | Preserve ledger | Burned/exposed and normal Continue/manual save pass in STORY_001_MAIN_ALTERNATIVES_RESULT.md |
| Captain Senn | Testify | Exile/punished and normal Continue/manual save pass in the same result |
| Halvern | Witness | Released/destroyed and normal Continue/manual save pass in the same result |
| Assembly | Witness route | Kael/Edric and normal Continue/manual save pass in the same result |
| Edric | Cooperate | Exposed/compelled and normal Continue/manual save now pass; see STORY_001_EDRIC_CHOICES_RESULT.md |
| Crow Shrine | Cleansed | Disturbed/bound and Continue/manual-save pass in STORY_001_EARLY_ALTERNATIVES_RESULT.md |
| Bog core | Destroyed | Preserved/returned and Continue/manual-save pass in the same result |
| Recovered names | Published | Withheld/use against curse and Continue/manual-save pass in the same result |
| Vargan ledger | Taken openly | Hidden/copied and Continue/manual-save pass in the same result |

All four Hart endings have preserved native real-input evidence in the registry.
They do not establish all preceding choice combinations or refusal routes.
Senn and assembly side-evidence actions are covered separately below.
The seventeen new main decisions and seventeen reloads also pass exact saved
flag/value/reward comparison against authored actions. First-hour reporting,
other refusal combinations, actor aftermath and final current-source campaign
acceptance remain open.
Public and retained Road of Crows reports now have two real-input native
decisions and two Continue/manual-save/resume passes; see
STORY_001_REPORT_ALTERNATIVES_RESULT.md. Their exact consequences and actual
Anwen relocation pass. Terms/report first replies and separate actual reloads
also pass in STORY_001_ANWEN_REPLIES_RESULT.md. Combined and production-browser
acceptance remain open.
Senn exile/punishment and Halvern release/destruction now retire the actual
obsolete conversation bodies live and on rebuild. Four decision/four reload,
four legacy resolved and two retained witness cases pass; see
STORY_001_ACTOR_AFTERMATH_RESULT.md. Final aftermath artwork and combined
consequence routes are still open.
Two actual combined Castle-to-ending routes now pass; see
STORY_001_COMBINED_ROUTES_RESULT.md. Exile/compelled/released/Edric/Mercy and
punished/exposed/destroyed/Kael/Ash preserve their exact earlier choices through
combat, parries, assembly and ending saves. This is resumed native proof only;
all permutations, New Game-to-end, first-hour/refusals and browser remain open.

## Newly Closed Native Side-Branch Gaps

| Outcome | Real-input branch log | Continue/manual-save round trip |
| --- | --- | --- |
| Mira kept | side_bitter_kept_native_v2.log | side_bitter_kept_reload_v1.log |
| Black Dog hidden | side_black_dog_hidden_v2.log | side_black_dog_hidden_reload_v1.log |
| Widow comforted | side_widow_comfort_v1.log | side_widow_comfort_reload_v1.log |
| Iron weapon | side_iron_weapon_v1.log | side_iron_weapon_reload_v1.log |
| Returned soldier anonymous | side_empty_anonymous_v1.log | side_empty_anonymous_reload_v1.log |
| Miller public assembly | measure_live_exit_native_v2.log | measure_public_reload_native_v1.log |

These logs exited 0 with only the environmental ANGLE advisory. Earlier default
side outcomes and Rook/Bannerless alternatives retain their registry evidence.
Original genuine save fixtures were not modified; copied backups were loaded
through Continue, and actions used physical movement/focus/visible dialogue.

## Current Edric Operation

Current result: exposed/compelled and both reloads pass on 2026-09-28 using
real sprint on the north aisle. Earlier failures below remain history, not
current next actions. Strict deadlines are preserved; walking and performance
are not fixed by the sprint-route evidence.

### Timing discrimination (2026-09-27)

`edric_timing_v3.log` sampled the entire movement interval. The north leg
processed 60 physics frames (2.0 simulation seconds) and 116 process frames in
9146 ms. Every sampled tick retained movement input and control, with time
scale 1.0. This distinguishes simulation/render scheduling stalls from lost
input for this run; it does not identify the specific workload causing them.

The emitted PASS is rejected: the eight-second deadline expired and the old
helper retested position after three cleanup frames. Edric's exposed choice
and save happened afterward, so they are diagnostic downstream evidence,
not accepted route proof. Stderr also reports failure to read the Windows
root certificate store under the restricted environment; it is not suppressed.

The helper now rechecks the deadline after yielding, latches success only
inside the deadline, releases movement before diagnostics, and never upgrades
timeout during cleanup. `route_deadline_strict_parse.log` passes; graphical
regression proof is still required. The answered temporary timing probe was
removed. Physics settings and deadlines are unchanged.

The deadline helper now has isolated native regression proof:
`tools/verify_route_deadline.gd` inherits and calls the actual route helper,
rejects expired-at-target and cleanup-only arrival, and accepts timely arrival.
`route_deadline_regression_unrestricted.log` exits 0 with all three assertions
and no errors. Its sandboxed predecessor emitted the certificate-store error;
the unrestricted rerun with the same D: fixture did not. This is helper logic
proof only, not graphical route or performance acceptance.

Next: use the existing stage/frame profiler to locate the stalled interval
before another route attempt. Do not rerun an identical branch to hunt for
a lucky pass, change collision, or increase physics catch-up without evidence.
Any subsequent accepted route must use the strict deadline implementation.

- `--continue-edric --edric-exposed` and `--edric-compelled` select the exact
  visible dialogue labels and assert quest advancement plus saved stance.
- `edric_alternatives_parse.log` passes.
- `edric_exposed_v1.log` fails before dialogue: northward approach advances
  from z=-3.85 to -6.40 in its eight-second deadline. Collision output contains
  floor contacts only; forward ray is clear and commanded velocity is -3.4.
- Greyfen prewarm took 82.124 seconds and Record Hall activation 8318.5 ms.
  This run is not a progression, performance, or branch pass.
- An unrelated MTGA process was present afterward. Shared hardware contention
  is plausible but unproven; no user application was stopped and no test
  deadline or acceptance threshold was relaxed.
- Genuine pre-choice source: `edric_v2_fixture` manual-save backup. The failed
  run uses the separate `edric_exposed_v1_fixture`; retain both.
- Next: when graphical execution is uncontended, rerun this same exposed
  branch from a fresh byte-copy, then compelled and their reload checks.
  If the route still stalls, inspect frame/input evidence rather than move
  colliders or extend deadlines speculatively. No Web export while PERF-001 is red.
