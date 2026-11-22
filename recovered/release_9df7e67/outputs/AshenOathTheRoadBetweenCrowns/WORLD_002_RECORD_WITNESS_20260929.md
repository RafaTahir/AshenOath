# WORLD-002 Record Hall Witness Role

Verdict: retained, partial visual and gameplay evidence. Formal Recovery-004
acceptance remains 27/37; WORLD-002 is visually rejected.

The Record Hall haunting keeps its existing `wychwood_stalker` enemy ID, AI,
health, collision, quest completion, rewards and save-compatible state. The
zone supplies `ghoulkin_creature` as an explicit visual-role override, so the
room uses the already exported spectral body and animation instead of the
bright red outdoor Demon. The mapped-body path now honors explicit overrides
for known enemy IDs; Captain Senn's existing bandit override is unchanged.

Evidence:

- `D:/Temp/AshenOath/world002_record_witness_contract_20260929.log`: Castle
  contract, mapped role and animation driver PASS, owned exit 0.
- `D:/Temp/AshenOath/world002_record_witness_quest_20260929.log`: Blood Under
  Stone structural progression PASS, owned exit 0.
- `.release-gate/world002_record_witness_final_20260929/57_castle_record_hall_haunting.png`:
  current 1280x720 gameplay-camera frame inspected against the earlier
  `.release-gate/world002_record_grounded/57_castle_record_hall_haunting.png`.
  The spectral silhouette reads more like an apparition, but remains a small
  flying skull-and-claw creature in an under-staged hall. The fixture now
  stages its preceding quest objectives alongside the ledger flag, so the HUD
  shows the actual haunting objective. It also waits for a rendered frame
  after hiding transient overlays. The first two candidate captures had a
  stale objective and then a stale completion toast; they are rejected.
  This final frame is staged visual evidence only.
- `D:/Temp/AshenOath/record_witness_20260929.log`: graphical
  `--continue-record-haunting` from a byte-copy of the genuine post-ledger
  manual save. Continue, real combat input, haunting defeat, objective clear,
  and pause-menu save PASS with owned exit 0. No route flags were injected.

Limitations: neither the room composition nor the encounter/aftermath visual
cells pass. The same spectral role remains used elsewhere, so this does not
establish distinct campaign identity. The genuine saved route and objective
completion are proven separately. Cold Record Hall arrival measured
7,085.6 ms in this isolated graphical run, exceeding the 900 ms target; this
is PERF-001 debt, not a performance improvement claim. No Web export or browser
proof was run.

The final staged capture passed Godot script parsing and the owned graphical
two-view run exited 0; raw log:
`D:/Temp/AshenOath/record_witness_capture_final_20260929/capture.log`.

Next: one room-scale testimony/haunting composition pass with a matching-camera
encounter and aftermath review, preserving the proven route and combat. Do not
repeat isolated shelf or light-placement trials.
