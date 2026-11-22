# WORLD-002 Record Hall Grounded Encounter and Aftermath

Verdict: finite native Record Hall composition, haunting, story-state and
aftermath cells accepted. WORLD-002 remains unaccepted; Recovery-004 is 27/37.

The current `ghoulkin_creature` mapping already supplies the complete authored
grounded cursed-human body. No new creature, quest, AI, collision, reward or
save-state substitution was needed. The old floating-skull rejection is
superseded for this room by inspected current gameplay-distance captures.
The retained witness memorial, archive and interior profile supply the room's
story focal point and readable encounter aisle.

The earned aftermath exposed a plain undercroft door panel. Both Record Hall
exits now use the existing two-surface Vargan fitted door through
`castle_vargan_section.gd::_make_castle_door`. Only visual ownership changed:
interaction areas, collision, destinations and arrivals are unchanged. The
outer gate still uses its accepted open gatehouse leaves.

Evidence:

- `.release-gate/world002_record_grounded_current_20260930/`: normal and
  haunting 1280x720 gameplay-camera views inspected; owned capture exit 0.
  These predate the fitted-exit edit. Their archive/actor/lighting content is
  unchanged by that edit; they are staged views, not route or FPS proof.
- `D:/Temp/AshenOath/record_grounded_combat_20260930_ledger/`: byte-copy of
  the genuine post-ledger save, keyboard Continue, actual sword combat,
  haunting defeat, objective advancement and pause-menu manual save. Owned
  process exit 0. No flags or interaction handlers were invoked by the driver.
- `.release-gate/world002_record_fitted_aftermath_20260930/`: inspected
  day/night frames from a byte-copy of that earned save. The previous capture
  report supplies identical camera transforms. The haunting is absent, the
  witness memorial remains readable, the fitted descent door replaces the
  plain panel and the tracker correctly directs descent to the last witness.
  Capture exit 0; these frames do not prove travel or FPS.
- Castle builder parser and `verify_world_005.gd`: exit 0 after the exit edit.
  All owned graphical runs have only the recorded Intel-to-ANGLE advisory,
  with no parser/resource/renderer/shutdown error.

One initial combat run used the misleadingly named `record_haunting_v1_fixture`
which already contained `castle_haunting_cleared=true`; it correctly failed
before combat. It is not acceptance evidence. The successful run used the
unmodified `record_ledger_v1_fixture` (SHA-256
`00f2ba2321a81dae279aaf16c171a3df9c7307902604c93f857d9b3ae54d8a3e`).
Both original fixtures remain untouched.

Cold Record Hall control was 5176.4 ms during combat and 5320.0 ms during the
final art fixture, above 900 ms. The combat-owned aftermath rebuild was
113.7 ms. These are observations, not controlled performance acceptance.
The capture preserves the actual HUD state, including an existing transient
Blood lost cue; it does not repaint or hide the world to pass visual review.

Running steps: launch the native project with the genuine post-ledger save
copied into an isolated D: QA profile, Continue, defeat the haunting, Save,
then Continue from the resulting save to inspect the last-witness objective.
The exact successful automated route is
`--script tools/verify_opening_real_input_native.gd -- --continue-record-haunting`.
The aftermath uses `capture_pres_001.gd --continue-fixture` with
`RecordHall_Day,RecordHall_Night` and the prior report's camera transforms.

Freeze these finite scene cells. Shared native performance, full-campaign
browser proof and remaining campaign scenes still block WORLD-002.
