# WORLD-002 Bandit Road: Retained Route And Checkpoint Cells

Verdict: **partial native acceptance only; WORLD-002 remains visually rejected**.

## Retained Changes

- The authored mud road now joins the real southwest `(-7, 16.5)` and northeast
  `(7, -16.5)` exits. The old nearly north-south strip pointed elsewhere.
  The narrower approximately 3.2 m lane stays flush with the unchanged floor;
  the entire physical guard arena, trees, collisions and gameplay remain.
- Timber knee braces support the checkpoint crossbeam and watchpost frontage.
- Stone lower courses support the supply-store frontage inside its existing
  closed collision footprint. No new traversable interior is implied.

Final landscape: 13,950 bytes, two surfaces, 768 triangles,
SHA-256 `b540b31cfe7baaa7af821ef698f13ad378d252be433b80e8e096bd2bd9a78f3c`.
Final checkpoint: 45,789 bytes, four surfaces, 3,334 triangles,
SHA-256 `30c914365a831201d1abbfe4af2d24eabc30858f61fad50fdcf3e28e71a6cdae`.
Together they add 2,580 bytes to the previous resources. Manifest hashes match.

## Rejected Part Of The Pass

The quarry-face backdrop passed resource/corridor checks but failed actual
gameplay-camera review: it still looked like an oversized faceted perimeter
wall. Only that candidate's landform and material additions were removed.
The previous ridge geometry and shared material library were retained; no
unrelated work was restored or discarded. The first bake's typed BoxMesh to
ArrayMesh error was corrected before the successful bake. Initial failed logs
and rejected backdrop images remain preserved, never accepted.

## Direct Evidence

All run files are under
`D:/Temp/AshenOath/bandit_topology_candidate_20260930/`.

- `contract_final.log`: native headless resource/hash/material/budget checks
  and actual capsule sweeps pass, including the new bidirectional diagonal
  exit-to-exit road plus existing approaches. Exit 0, clean shutdown. This is
  physical proof, not graphical performance or visual acceptance.
- `capture_stdout_final.log`: graphical native Continue from a byte-copy
  genuine pre-fight save; physical melee approaches, both guard defeats,
  Senn testimony, chapter handoff and manual Save pass. Exit 0; original save
  unchanged at SHA-256
  `561ef38100fafec14a948ecd831a9c231c87cb40d7e4f53381c26e7df03ff3ad`.
- `captures_final/`: source-aligned 1280x720 arrival day/night, staged checkpoint
  day and three actual night-strike frames with camera/state/hash report.
  Road direction, supported frontage and local complete armed bodies were
  inspected. Staged camera/time preparation is explicitly not real-input travel.
- Existing close role captures in `bandit_identity_candidate_v3/captures/`
  retain unchanged model/skeleton/animation inputs. They show distinct fitted
  brown-armored deserter and dark-clothed buckler tracker, not two pale civilian
  clones. Final fight frames validate local night readability and actual
  animation/equipment use, not complete role/performance/export acceptance.

Two declared diagnostic-role warnings remain. No parser/resource/material,
renderer or shutdown error occurred. Required-role production approval remains
blocked; warnings are not suppressed or converted to a clean release claim.

## Still Red

The broader road clearing, distant horizon, aftermath/story composition and
complete runtime-role/payload/browser/performance proof remain incomplete.
Neither this pass nor the rejected backdrop closes WORLD-002 or PERF-001.
Do not repeat the faceted quarry wall, smooth berm or torch-relocation families.
No Web export, commit, push, merge or deployment was performed. Formal 27/37.
