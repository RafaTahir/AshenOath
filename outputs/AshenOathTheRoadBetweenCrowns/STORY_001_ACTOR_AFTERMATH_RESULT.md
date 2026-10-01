# STORY-001 - Consequence-Aware Actor Presence

2026-09-28. Retained functional repair and resumed graphical native evidence;
not complete STORY-001, world-art or browser acceptance. Formal count 27/37.

## Defect And Repair

Bandit Road always spawned Captain Senn after exile or punishment. The
undercroft likewise respawned Halvern's conversation body after release or
destruction, even though his boss controller already retired its combat body.
Live decisions also left those conversation actors available.

`scripts/story_actor_presence.gd` now defines the exact departed outcomes.
Both builders consult it, including when a legacy save has no removal record.
`game.gd` uses its existing interaction retirement path after the live choice.
Unresolved actors, Senn's testimony, Halvern's witness, unrelated actors and
unknown legacy outcomes remain. Quest actions, values, rewards, combat actors,
collision routes and save schema are unchanged. This is narrative staging,
not population reduction for performance.

## Current Evidence

- `D:/Temp/AshenOath/story_actor_presence_20260928/presence.log`: isolated
  exact-policy logic passes, clean exit 0. Not graphical proof.
- `story_actor_aftermath_20260928/`: four real decisions plus four separate
  Continue/manual-save/Escape-resume runs pass with eight owned clean exits 0.
  Each actual scene has no departed body or active focus for it.
- `story_actor_legacy_v2_20260928/`: four unchanged genuine older resolved
  saves and two older testimony/witness saves pass through normal Continue,
  Save and Escape. Six owned clean exits 0. The retained actors still have
  visible skeleton-driven bodies. Original saves remain byte-identical.
- Each graphical wrapper records and rechecks affected source hashes. Actual
  gameplay-camera 1280x720 PNGs remain beside each isolated save. Codex reviewed
  the four live departure views and both retained witness views: actor presence
  matches the choice, but unfinished surroundings and poses are NOT approved
  final art. No scripted camera transform or story mutation is used.

The first legacy attempt fails a verifier-only inferred-Node parser error;
it is preserved under `story_actor_legacy_20260928/`, not counted as a pass.
The explicitly typed driver passes its cheap parser check before the corrected
matrix. The earlier eight passing runs retain their original driver identities.

## Scope And Running

Use an actual unresolved surrendered-guard or post-parry checkpoint. Continue,
approach physically, press E and select the authored outcome, then Save through
Pause and Escape back to play. Reload that save or an older genuine resolved
save; the departed actor must not reappear. Test testimony/witness saves too.
Exact commands, isolated D: profiles, hashes and owned exit codes are retained
in each evidence-directory `run.ps1` and `*.wrapper.log`.

No whole-campaign permutation, new aftermath artwork, FPS, startup, loading,
browser or production acceptance follows. PERF remains red; no export, commit,
push, merge or deployment occurred. Next STORY dependency is the remaining
Anwen replies, followed by combined consequence routes and clue/refusal gaps.
