# RECOVERY-004 Implementation Status

## Native Contract Checkpoint - 2026-09-11 (sword and bridge probes)

- The current source checkpoint is on `codex/masterpiece-rebuild`. Kael's
  imported `Sword.fbx` now exposes its first valid render mesh as the stable
  `OathbladeSteel` contract under `KaelOathblade`; no duplicate blade geometry
  was added and the existing hand socket, blade markers, slash, parry, and
  Oathfire paths remain authoritative.
- The river verifier now clears carried player velocity before each independent
  bridge approach and lane probe. This removes test-state contamination from a
  preceding combat/teleport sample without changing player physics or bridge
  behavior. The actual bridge geometry remains the owner validated by the
  prior obstruction analysis.
- Direct proof after these edits: graphical `verify_visible_quality.gd`,
  `verify_combat_001.gd`, `verify_oath_001.gd`, `verify_render_resources.gd`,
  and `verify_river_swimming.gd` all report `PASS`. The visual run produced no
  active renderer/material errors, and the sword probe reports one imported
  mesh with four valid source surfaces and a non-null presentation override.
- Native shutdown still prints Godot's ObjectDB/orphan/resource accounting in
  some verifier exits. These messages are after active rendering and are not
  currently assigned to a specific owner, so lifecycle cleanup remains a
  separate release blocker rather than being relabeled as clean.
- No Web export, browser run, push, merge, or deployment was performed in this
  checkpoint. The user-owned untracked `tools/_inspect_milestone_c_assets.gd`
  remains untouched.
- Exact next action: continue source/native lifecycle and visual-debt recovery;
  defer the single source-aligned QA export/browser acceptance sequence until
  that accumulated fix set is ready.

## Native Route And Crowd Checkpoint - 2026-09-11

- The player-driven native gate suite now passes the full connected route after
  three authored-corridor blockers were removed: the Deep Woods ritual stone,
  Old Mill rubble, and a Bandit Road tree were each relocated outside their
  arrival approaches. `verify_gate_transitions.gd` completed the Greyfen,
  Wychwood, wilderness, Castle, Record Hall, and return legs without a jump,
  recovery trigger, or blocked gate.
- `verify_river_swimming.gd` and `verify_navigation_001.gd` also pass. The
  bridge-only river contract remains intact; the warnings emitted for blocked
  monster visual roles are visual-debt diagnostics, not active route errors.
- Crowd composition now consumes each routine's stable seed when selecting a
  compatible hair source. `verify_char_009.gd` passes the distinct-hair and
  identity checks, and a fresh 1280x720 crowd capture was recorded.
- The duplicate Web startup-pack request is removed from the service registry;
  the native load gate still passes with approximately 0.5s runtime setup,
  approximately 1.8s Greyfen prewarm, and approximately 30ms New Game handoff.
- The retained monster roles now use distinct runtime sources: Bat for the
  Stalker, Dragon for the Raider, Slime for the Bog Wretch, and KnightCharacter
  for the Gravebound. Their explicit imported animation maps resolve idle,
  movement, attack, hit, and death clips; an unresolved idle map is now a
  runtime failure rather than a frozen visual. Fresh evidence is recorded in
  `MON_002_RUNTIME_FAMILIES.png`.
- These are source/native checkpoints only. The current branch has not yet
  received a source-aligned final Web export after the sword, crowd, and route
  edits, and production remains unchanged.

## Current Atomic Checkpoint - 2026-09-11 (modeled hand sword)

- Current source: `codex/masterpiece-rebuild` at `5e9cc4c` with the preserved
  worktree changes for the Greyfen boundary manifest, browser harness, and
  the modeled-sword repair. The user-owned untracked
  `tools/_inspect_milestone_c_assets.gd` remains untouched.
- Completed in this slice: Kael's drawn sword now instantiates the valid
  `res://assets_external/characters/Sword.fbx` scene under the existing
  hand-bone equipment root. The imported source is normalized once, uses a
  readable cached presentation material, and keeps the existing blade base,
  tip, slash, parry, and Oathfire contracts. The procedural wedge remains
  only as an explicit missing-source diagnostic fallback and is rejected by
  the runtime role gate.
- Direct proof: the Godot editor/import scan is parser-clean; `COMBAT-001`,
  `MOTION QUALITY`, `RUNTIME-001`, `WEB-002`, and `ASSET-005` pass. The fresh
  graphical animation capture refreshed `ANIM_001_01` through `ANIM_001_05`
  at 1280x720. The new combat verifier requires the modeled source and hand
  equipment node, so a future regression cannot silently restore the wedge.
- Remaining limitation: the character and world visual registries still
  contain the documented low-poly/interim roles and later-zone presentation
  debt. The current source has not been re-exported or promoted; the v28 Web
  artifact remains diagnostic evidence only.
- Exact next action: continue the broader recovery from the next scoped
  source/native blocker, then perform one source-aligned release export and
  browser acceptance after the accumulated runtime fixes. Do not repeat the
  obstruction telemetry loop.

## Browser Obstruction Root-Cause Record - 2026-09-11

- Diagnostic scope: the v23-v27 Chrome route traces at the west Greyfen
  approach, approximately `x=-7.83, z=-10.42`, plus source/static inspection
  and the native seamless-route reproduction. No additional runtime telemetry
  is required for this blocker.
- Physical ownership: the only body reported at the stalled point was the
  Greyfen left-bank floor slab created by `_make_split_ground` through
  `ZoneBuildContext`. Its bounds are approximately `x=[-21.0,-2.7]` and
  `z=[-17.0,2.8]`, with a level top surface. The bridge body is the separate
  `RiverBridgeContinuousSurface` corridor at the river center. Deferred
  boundary scenery is disabled during the fast opening build, and the traces
  reported no wall, overlap, tree, gate, or river-recovery collision. The
  apparent obstruction was therefore a walkable floor location, not a scenery
  collider or bridge seam.
- Root cause: `world_sector_manifest.json` was missing from the `Web QA Browser`
  export include filter. The game still created the visible deep-wood gate, but
  `WorldSectorManifest._ensure_loaded()` correctly fell back to an empty
  sector set, so `SeamlessWorldService.update_player()` had no boundary edge
  to activate. This made a valid west-gate approach look like a blocked route.
- Surgical fix: add `world_sector_manifest.json` to the QA export filter. No
  gameplay, physics, river, or world-builder change was needed for this
  obstruction.
- Cheapest proof after the fix: `verify_seam_002.py`,
  `verify_world_grid_001.py`, and `verify_web_002.py` passed; the native
  `verify_seam_qa_001.gd` route passed; the v26 export log confirmed the
  manifest was packed; and v26 Chrome evidence crossed the west boundary into
  `deep_wood` with no console or network errors. The later v27 failure was a
  disposable SwiftShader/CDP held-key race: the trace stopped in Greyfen
  before the boundary and did not reproduce the game-side failure.
- Harness hardening now staged for the single final QA run: the browser driver
  reasserts the existing raw key as an auto-repeat signal without pulsing a
  key-up. This remains an input-harness change only and does not alter player
  movement or transforms.
- Final v28 attempt: the one fresh `Web QA Browser` export was written to
  `D:\Projects\AshenOath\outputs\.release-gate\ticket\AshenOath_QA_v28`;
  it contains 7 files totaling `93,846,246` bytes and the export log confirms
  `world_sector_manifest.json` is packed. The single Chrome acceptance run
  produced no console errors and removed its profile from
  `D:\Temp\AshenOath`, but the disposable SwiftShader/CDP input path stopped
  at `x=-5.863, z=-10.323` before the west boundary. Telemetry again reported
  `on_floor=true`, `on_wall=false`, no overlaps, only the Greyfen floor slab
  `@StaticBody3D@261`, and no river recovery. This is a harness failure, not a
  new physical owner or a regression of the manifest fix. The earlier v26 run
  on the same source-aligned candidate did cross into `deep_wood` with no
  console or network errors.
- Exact next action: do not run another Web export or browser attempt for this
  obstruction. Preserve the v28 artifact and report as diagnostic evidence;
  resume the broader recovery from source/native work, and defer browser
  acceptance until the driver is replaced or isolated from the SwiftShader
  held-key race. The browser route remains unaccepted even though the game
  side of the original missing-manifest defect is closed.
- Prevention follow-up: `WorldSectorManifest` now exposes explicit validity and
  load-error state and reports a missing, malformed, or empty manifest instead
  of silently presenting an empty sector graph. `verify_web_002.py` now checks
  that both `Web Browser` and `Web QA Browser` include the manifest. The
  affected static checks (`WEB-002`, `SEAM-002`, `WORLDGRID-001`, and
  `NAV-002`) and the native `SEAM-QA-001` circuit all pass after this guard.

## Paused Atomic Checkpoint - 2026-09-10 (performance prewarm isolation)

- Current atomic work: isolate synchronous campaign visual prewarm from cold
  zone transitions after the Hart Glade performance gate exposed a first-use
  overlap.
- Completed: `game.gd` now suspends campaign visual prewarm at the start of
  every zone load, resumes it only after the player is playable, reschedules a
  prewarm coroutine that encounters a transition after its yield, and clears
  the suspend state on both failed recovery and normal shutdown.
- Latest direct result: the Godot editor/parser load completed with no parser,
  resource, or active-render error matches in
  `D:\Temp\AshenOath\paused-atomic-parser.log`. The graphical Compatibility
  `verify_perf_001.gd` run passed. Hart Glade cold activation measured
  `116.2 ms` (previous failing measurement: `1024.9 ms`), Wychwood cold
  `398.0 ms`, Vargan Court `238.1 ms`, Record Hall `72.2 ms`, warm return
  `35.0 ms`, and New Game `16.1 ms`. Zone samples remained approximately
  `47.9-60.0 FPS` average with `35.7-57.3 FPS` 1% lows and static memory below
  `82.4 MB`.
- Remaining blocker: this checkpoint proves only the current performance fix.
  The broader recovery/release remains blocked by unresolved visual-quality
  registry outcomes and the still-unrun complete screenshot, export, browser,
  and production acceptance sequence.
- Exact next action on resume: run the complete release evidence sequence
  against this committed source, beginning with the screenshot gate and then
  export, packed startup, and fresh browser checks; do not repeat this atomic
  performance edit unless its inputs change.

## Current Evidence Checkpoint - 2026-09-10 (route and world gate repair)

- Current ticket: `RECOVERY-004`, traversal and Greyfen presentation follow-up on
  `codex/masterpiece-rebuild`.
- Completed in this slice: the real gate traversal now keeps player-sized test
  capsules inside authored boundary walls, waits for the hidden Greyfen
  prewarm before timing New Game, defers the desktop launch-menu rebuild so a
  single accept event cannot activate New Game twice, moves the collidable
  shrine barrel out of the Greyfen-to-Castle approach, and restores a dense
  144-instance staggered Greyfen paving surface in one MultiMesh.
- Latest direct results: `verify_gate_transitions.gd` passed every tested
  Greyfen/Wychwood/campaign route in both directions with a measured warm New
  Game handoff of 74-187 ms. `verify_world_001.gd` passed with 1099 nodes,
  336 meshes, and 2 lights. The full source gate sequence through
  `verify_perf_003.gd` passed; graphical Compatibility profiling also passed
  Greyfen, Wychwood, Wychwood combat, Castle courtyard, Record Hall, and Hart
  Glade at approximately 59.9-60.0 FPS average with 30.8-32.7 FPS 1% lows,
  34.9 ms warm return, and 84.2-430.1 ms cold transitions.
- Scope boundary: this is local source and graphical evidence. It does not by
  itself approve unresolved visual-quality registry categories or certify the
  deployed Web artifact until the final export, screenshot, and browser gates
  complete.
- Exact next action: run the complete screenshot, export, packed-startup, and
  fresh Chrome/Edge release checks against the committed source, then update
  the authoritative report and decide promotion from the evidence.

## Current Evidence Checkpoint - 2026-09-10 (off-center bridge capsule sweep)

- Current ticket: `TRAV-001`, bridge surface contract verification on
  `codex/masterpiece-rebuild`.
- Completed in this atomic slice: the river safety verifier now drives the
  real `CharacterBody3D` across two interior bridge lanes (`x=-1.2` and
  `x=+1.2`) in both directions for Greyfen and Wychwood. Each lane checks
  lateral stability, complete bank-to-bank travel, no river recovery, and no
  jump-required stop. The existing centerline, bank-barrier, save-migration,
  interaction-clearance, and NPC-route checks remain active.
- Latest direct result: the Godot Compatibility headless run exited `0` with
  `RIVER-002 SAFETY VERIFIER: PASS`; the log is
  `D:\Temp\AshenOath\trav-001-river.log` and its Godot stderr log is empty.
- Scope boundary: this proves the current local source geometry and player
  capsule. It does not certify the stale production Web artifact, full route,
  or visual quality, and it does not change quest logic or river visuals.
- Exact next action: continue the next scoped recovery blocker, preserving this
  local bridge evidence until a fresh export is produced. Do not promote or
  deploy while the recovery registry still contains release blockers.

## Current Evidence Checkpoint - 2026-09-10 (split Web packs and route safety)

- Current ticket: `RECOVERY-004`, release-integrity and runtime-pack
  ownership follow-up on `codex/masterpiece-rebuild`.
- Completed in this atomic slice: production Web ownership now keeps only the
  base runtime in the root PCK and treats the opening, campaign, character,
  monster, and audio artifacts as externally verified packs. The runtime pack
  manager recognizes embedded content from the generated manifest status rather
  than from builder-script presence, so streamed opening content cannot be
  silently treated as already mounted. Pack metadata was regenerated from the
  current checkpoint and the candidate files were bound to the same source
  identity.
- Latest direct results: six runtime packs exported and hash-verified at
  `58.14 MB` total; `verify_runtime_packs.py`, `verify_pack_candidates.py`,
  `verify_web_001.py`, `verify_web_export.py`, and the packed-startup verifier
  all passed. The current Web candidate is `12` files / `95.1 MB`, with root
  PCK SHA-256
  `b9bb251a4e6e39138708c36a1a166eedf7ede28a25858155ac0318801a0f82a7`.
  The actual CharacterBody river sweep also passed `RIVER-002 SAFETY
  VERIFIER` in both directions for Greyfen and Wychwood.
- Latest browser result: fresh local Chrome and Edge smoke runs reached the
  native `1280x720` WebGL2 canvas with empty console-error lists. Chrome
  reached engine readiness in `11875 ms` and New Game readiness in `9544.9
  ms`; Edge reached `10216 ms` and `7520.8 ms`. Both temporary profiles were
  created below `D:\Temp\AshenOath` and cleaned after the run. These timings
  are recorded evidence, not a claim that the stricter sub-second New Game
  target is met.
- Checkpoint commits: `fb8f789` bound the generated metadata to its source
  checkpoint; `604ba90` recorded the rebuilt candidate pack hashes. Both are
  pushed to `origin/codex/masterpiece-rebuild`. The intentionally untracked
  rejected asset experiments remain excluded.
- Remaining truth: the complete release decision remains **FAIL** while the
  recovery registry records unresolved release-integrity, traversal/collision,
  character, monster/combat, world-presentation, UI/story/input,
  audio, and architecture/performance categories. This candidate has not
  been synchronized into tracked `web/`, promoted to `main`, or deployed to
  Vercel.
- Exact next action: continue with the documented recovery blockers and then
  regenerate the authoritative release report from the resulting source. Do
  not promote this candidate or deploy while any registry blocker remains.

## Current Evidence Checkpoint - 2026-09-10 (truthful full-run release decision)

- Current ticket: `RECOVERY-004`, release-integrity follow-up after the complete
  authoritative gate run.
- Completed in this atomic slice: Potato/mobile no longer schedules optional
  Castle environment dressing for deferred hydration. If a stale marker still
  exists, the same quality tier discards it without raising a runtime error.
  Balanced and Quality still raise an error for a genuine missing deferred
  visual. `run_release_gate.ps1` now also validates every structured browser
  report and fails when a report is missing, unreadable, or reports a
  non-`pass` status despite a masked process exit code.
- Latest direct results: `verify_content_integrity.py`, `verify_asset_005.py`,
  `verify_web_001.py`, the Godot project parse/import check, PowerShell parser
  validation, `git diff --check`, and native `verify_qa_002.gd` all passed.
  Native QA-002 reached Greyfen in 48.1 ms after the prewarmed handoff and
  exited cleanly.
- Latest Web result: a rebuilt disposable `Web QA Browser` export passed the
  full mobile campaign in Chrome (`47` checkpoints, `346196 ms`, empty console
  errors) and Edge (`47` checkpoints, `323497 ms`, empty console errors). Both
  profiles were created under `D:\Temp\AshenOath` and cleaned after completion.
- Remaining truth: the complete authoritative runner passed 96 executable gates
  from the checkpointed source, including fresh screenshots, graphical
  performance, packed startup, and Chrome/Edge desktop and mobile campaign
  routes. The release decision is nevertheless **FAIL** because the issue
  registry still records eight unresolved categories: release integrity,
  traversal/collision, characters, monsters/combat, world presentation,
  UI/story/input, audio, and architecture/performance.
- Checkpoint decision: the generated pack metadata and release report are bound
  to source `77bb7ef5d09e6c16827bccc03e0a1d9cd228eb13`. The runner now fails a
  complete run when unresolved registry blockers remain; targeted and partial
  runs remain usable as development evidence. Production Web files remain
  unchanged.
- Exact next action: resolve the registry blockers through targeted recovery
  tickets, then run a new complete release gate. Do not synchronize `web/`,
  push `main`, or deploy while any blocker remains.

## Current Evidence Checkpoint - 2026-09-08 (objective, lighting, and capture hardening)

- Completed: the objective presentation now supplies a truthful `RETURN ROUTE`
  view for a completed Hart Glade finale; the forest and interior lighting
  profiles are brighter and more deliberate; the lighting verifier retires
  its streamed test tree cleanly; and screenshot capture checks both PNG write
  results and non-empty output files.
- Completed: capture placement explicitly settles the player into the real
  authored idle pose before sampling, preventing rapid zone changes from
  recording an imported setup/T-pose frame.
- Direct results: objective view model, LIGHT-001, SKY-003, visible quality,
  and Castle Vargan all pass. The resumed complete screenshot chain passes,
  including the refreshed 1280x720 Hart return-route and Castle gate frames.
  The latest Castle and Hart pixels were inspected and are no longer affected
  by the two identified evidence defects.
- Remaining truth: current visuals still include the known low-poly/procedural
  world and combat limitations, and the recovery issue registry remains
  blocked in its release-integrity, traversal, character, monster, world,
  UI/story, audio, and architecture categories. The final performance/export
  report must be regenerated after these source edits before any deployment
  decision.
- Exact next action: run the full authoritative release runner, then validate
  the resulting report and artifact against the committed source before
  syncing `web/`.

## Current Atomic Checkpoint - 2026-09-08 (NPC animation workload fix)

- Current ticket: `RECOVERY-004`, focused graphical performance slice.
- Completed in this atomic slice: `_configure_npc_animation()` now gives
  non-player rigs one phase-staggered 8 Hz manual update rate. Player and
  active-enemy gameplay timing remain unchanged. This removes the prior
  mixed 0/12/20 Hz paths and the synchronized imported-skin evaluation spikes
  measured in Castle and Record Hall.
- Latest direct result: graphical Compatibility `tools/verify_perf_001.gd`
  exited `0` with `PERF-001 VERIFIER: PASS`. Greyfen, Wychwood, Wychwood
  combat, Vargan Court, Record Hall, and Hart Glade all recorded approximately
  60 FPS average, at least 36 FPS 1% low, and zero slow frames. Measured
  transitions in the report are within the configured limits, and the report
  status is `pass`. `git diff --check` also passed for the source edit.
- Remaining blocker: this fixes the measured performance slice only. The
  broader recovery still has documented visual-quality debt, incomplete
  full-campaign proof, lifecycle/release-evidence work, and unpushed source
  changes. No export, push, merge, or deployment was performed.
- Exact next action on resume: continue the next explicitly selected recovery
  slice or gate; do not rerun `verify_perf_001.gd` unless this animation path,
  its verifier, or its measured scene inputs change.

## Current Atomic Checkpoint - 2026-09-07 (Character mapping and asset-manifest integrity)

- Current ticket: `RECOVERY-004`, character presentation and runtime asset
  integrity slice.
- Completed in this atomic slice: the active crowd and named-human mappings
  now resolve to the clothed Universal `Male_Peasant.gltf` and
  `Female_Peasant.gltf` assemblies. Kael and Anwen remain on their protected
  A-set recipes, and Captain Senn remains on the Ranger runtime asset. The
  generated full-body candidates that failed visual review are preserved as
  untracked experiments but are no longer referenced by active manifests,
  export filters, or Web checks. The shared opening animation artifact record
  was corrected to the current local file size and SHA-256.
- Latest direct results: `tools/verify_asset_005.py` exited `0` with
  `ASSET-005 VERIFIER: PASS (6 approved runtime roles, 5 explicit fallbacks)`;
  `tools/verify_web_001.py . ..\\..` exited `0` with `WEB-001: PASS`. The
  previously run direct character checks for `verify_char_002.gd`,
  `verify_character_real_001.gd`, `verify_character_role_contract.gd`,
  `verify_char_007.gd`, `verify_char_008.gd`, and `verify_char_009.gd` also
  passed against the restored mappings.
- Visual result: the rejected base/underwear full-body experiment is not an
  approved release asset. The restored peasant assemblies are clothed and
  remain in the same Universal family, but the broader character presentation
  is still low-poly/provisional and the guard equipment treatment remains a
  known visual limitation. This checkpoint does not claim final character
  acceptance.
- Remaining blocker: broader RECOVERY-004 visual quality, authored crowd
  variation, lifecycle cleanup, full-campaign proof, and release evidence are
  still incomplete. No export, browser cycle, push, merge, or deployment was
  performed for this checkpoint.
- Exact next action on resume: continue the next explicitly selected recovery
  slice after unpausing; do not repeat ASSET-005 or WEB-001 unless one of their
  inputs changes. The preserved untracked experiments remain available for
  audit and are not production inputs.

## Current Atomic Checkpoint - 2026-09-06 (Transition verifier and menu identity)

- Current ticket: `RECOVERY-004`, transition-verifier shutdown and visible
  release identity cleanup.
- Completed in this atomic slice: `verify_gate_transitions.gd` now retires the
  test game through the staged runtime shutdown contract, queues the owner for
  destruction, and waits for SceneTree cleanup instead of synchronously freeing
  the full route tree after a valid pass. The verifier also keeps bounded
  waypoint limits. `hud.gd` now exposes the explicit
  `RECOVERY-004 ROADMAP MILESTONE` identity and keeps the compact 720p quick
  read layout.
- Latest direct results: the full gate-transition route exited `0` with
  `GATE TRANSITION VERIFIER: PASS`, `VERIFIER_PHASE: SHUTDOWN`, and no parser,
  assertion, active-renderer, resource, ObjectDB, leak, or warning lines in
  `.release-gate/current/gate_transitions_checkpoint.log`.
  `tools/verify_web_001.py . ..\\..` also exited `0` with
  `WEB-001: PASS - preset, renderer, payload filters, build ID, and hosting
  headers`.
- Remaining blocker: this atomic slice has no failing targeted check. The
  broader RECOVERY-004 work remains blocked by the previously documented
  visual-quality debt, incomplete campaign proof, lifecycle items outside this
  verifier path, and the not-yet-regenerated authoritative release report.
  No export, browser cycle, push, merge, or deployment was started.
- Exact next action on resume: return to the broader RECOVERY-004 release-gate
  tail, beginning with the remaining affected verification and current release
  report generation; do not repeat the completed transition or Web identity
  checks unless one of their inputs changes.
- Checkpoint policy: the two fixes and this record are committed locally only.
  All unrelated modified and untracked work remains in the working tree. No
  push, merge, export, deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Record Hall camera-safe presentation)

- Current ticket: `RECOVERY-004`, Record Hall presentation and entry-camera
  occlusion fix.
- Completed in this atomic slice: removed the visible enclosed-zone berms,
  full-width rear shell, side-wall/pilaster framing, ceiling panels, rafters,
  and head-height cross-room trim that projected as dark slabs across the
  archive aisle. The Record Hall floor remains extended beyond the raised entry
  camera, its authored detail positions are preserved instead of being passed
  through the outdoor occupancy clamp, and the rear landmark is kept as a small
  segmented doorway/header treatment. The temporary geometry print and
  Record-Hall probe scripts were removed after diagnosis.
- Latest direct evidence: the focused graphical capture exited `0` and printed
  `RECORD-HALL CAPTURE: PASS`. Fresh 1280x720 frames are
  `Development_Gallery/screenshots/Capture_38_record_hall_2026-09-06_075240.png`
  and
  `Development_Gallery/screenshots/Capture_57_castle_record_hall_haunting_2026-09-06_075240.png`.
  Visual inspection confirms that the former full-width aisle obstruction is
  gone and Kael, the route, pillars, shelves, and haunting actor remain visible.
- Direct checks: `verify_castle_vargan.gd` exited `0` with
  `CASTLE VARGAN VERIFIER: PASS`; `verify_render_resources.gd` exited `0` with
  `RENDER RESOURCE VERIFIER: PASS`. No parser, assertion, active-renderer, or
  resource error occurred. Godot still printed its known ANGLE driver warning,
  and the Castle verifier reported an exit-time ObjectDB leak warning; that
  shutdown warning remains unresolved and is not being relabeled as a pass.
- Remaining blockers: Record Hall is camera-safe but still low-poly and
  visually under-authored, with a dark/open sky presentation; the broader
  Greyfen, Wychwood, Castle, and Hart visual debt, the blocked non-fallback Hart
  asset, full campaign evidence, and production release remain pending. The
  ObjectDB shutdown warning also remains a lifecycle blocker.
- Exact next action on resume: continue only with the remaining Record Hall
  presentation/lifecycle cleanup and its directly affected evidence; do not
  start another ticket, export, or deployment until unpaused.
- Checkpoint policy: this atomic fix is verified and remains local only. No
  push, merge, export, deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Opening boot profile)

- Current ticket: `RECOVERY-004`, startup readiness slice (`LOAD-001`).
- Completed in this atomic slice: the Greyfen menu prewarm now uses the
  minimal `opening_boot` profile, retaining ground, river, bridges, bounds,
  spawn composition, Anwen staging, and legal exit gates while deferring the
  heavier village and investigation decoration. The gameplay hydration stage
  runs after handoff, removes temporary boot gates before publishing the full
  gameplay content, and keeps the existing queued New Game path intact.
- Latest direct result: `tools/verify_load_001.gd` exited `0` with
  `LOAD-001: PASS`. On the current D: workspace, runtime readiness was
  approximately 238 ms, Greyfen prewarm was approximately 1,294 ms, total
  menu prewarm was approximately 1,658 ms, and the prewarmed New Game handoff
  reached playable Greyfen in approximately 19 ms. Anwen was present after
  handoff, deferred detail remained pending as intended, and the run ended
  without parser, assertion, active-renderer, resource, or ObjectDB shutdown
  errors.
- Remaining blockers: the wider recovery is still visually and release
  blocked. Greyfen and Wychwood remain procedural/blockout quality, Record
  Hall remains too dark/occluded in current evidence, and the retained Wolf
  source remains an explicitly blocked White Hart fallback. Full export,
  campaign evidence, and deployment remain pending.
- Exact next action on resume: address the already-recorded Castle/Record Hall
  presentation and validated non-fallback Hart asset, then recapture only the
  affected views. Do not repeat this load gate unless the boot or hydration
  inputs change, and do not export or deploy before the visual blockers are
  resolved.
- Checkpoint policy: this startup fix is verified and remains local only. No
  push, merge, export, deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Bridge surface contract)

- Current ticket: `RECOVERY-004`, bridge traversal safety.
- Completed in this atomic slice: the shared `BridgeSurfaceContract` now owns
  bridge width, river span, deck length, and legal deck containment. Greyfen
  and Wychwood river construction use the same contract for the rendered deck,
  flush collision deck, and bridge aprons. The spatial service uses the same
  contract for bridge recognition and recovery, so the legal crossing surface
  cannot disagree with the river exclusion rule.
- Direct result: `verify_river_swimming.gd` exited `0` with
  `RIVER-002 SAFETY VERIFIER: PASS`. The verifier drove the actual
  `CharacterBody3D` across both river crossings in both directions, checked
  bridge approach floor continuity, bank barriers, recovery, interaction and
  enemy clearances, and confirmed that neither crossing triggered river
  recovery. No parser, assertion, active-renderer, resource, or shutdown error
  was reported.
- Current remaining blockers: the fresh visual evidence is still not release
  approved because Greyfen/Wychwood remain procedural, Castle/Record Hall are
  weak and dark, and the retained Wolf source is an explicitly blocked White
  Hart fallback. Production export, full release verification, and deployment
  remain intentionally pending.
- Exact next action on resume: address the already-recorded visual blockers,
  beginning with Castle/Record Hall and a validated non-fallback Hart asset,
  then recapture only the affected views. Do not export or deploy until those
  frames pass visual review.
- Checkpoint policy: this bridge fix is verified and committed locally only.
  No push, merge, export, deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Lifecycle-clean visual review)

- Current ticket: `RECOVERY-004`, opening activation safety and visual review.
- Completed in this atomic slice: the focused character verifier and sky
  verifier now use the staged runtime shutdown contract; the White Hart role
  keeps its measured grounded source offset, presents the retained Wolf source
  toward the actor, and uses a smaller ground-level memory cue instead of a
  screen-dominating aura. The production sky path remains depth-tested 3D
  geometry with the full-screen diagnostic canvas disabled.
- Latest direct results: `verify_char_006.gd`, `verify_boss_007.gd`,
  `verify_sky_003.gd`, and `verify_render_resources.gd` all exited `0` and
  passed without parser, assertion, active-renderer, resource, or ObjectDB
  shutdown errors. The current 11-view screenshot set also passes the
  automated freshness, 1280x720, nonblank, and exposure checks.
- Visual review result: the evidence is current but not release-approved.
  Greyfen and Wychwood remain procedural/blockout quality, Castle approach
  and Record Hall lack authored architectural depth (Record Hall is still too
  dark in the gameplay frame), and the Hart remains an explicitly blocked Wolf
  fallback rather than a true antlered creature. These are visible acceptance
  blockers, not verifier failures.
- Performance context remains the previously measured graphical Compatibility
  result: Greyfen 48.5 FPS average / 34.4 FPS 1% low; Wychwood 60.0 / 54.2;
  Wychwood combat 59.6 / 37.9; Vargan Court 60.0 / 44.2; Record Hall 44.0 /
  37.8; Hart Glade 60.0 / 56.8; warm return 34.95 ms; slowest recorded
  transition 321.2 ms; static memory below 107 MB.
- Remaining blockers: visual acceptance, a validated non-fallback Hart asset,
  broader campaign evidence, production export parity, and deployment. The
  current screenshot verifier proves freshness and image health only; it does
  not override the visual review result.
- Exact next action on resume: remediate the rejected Castle/Record Hall and
  Hart/world presentation, then recapture the affected views and rerun only
  the visual gates that consume those views. Do not export or deploy until
  those frames pass visual review.
- Checkpoint policy: this state is local only. No push, merge, export,
  deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Opening activation safety)

- Current ticket: `RECOVERY-004`, opening activation and recovery safety.
- Completed in this atomic slice: invalid proxy-anatomy nodes are hidden,
  disabled, and removed from collision before deferred deletion can expose a
  detached frame; optional campaign visual prewarm waits 18 seconds after the
  first playable frame so Castle mesh imports do not compete with Greyfen
  startup or opening performance; and the bridge recovery fallback now uses
  the shared `BridgeSurfaceContract` instead of a duplicate hard-coded shape.
- Latest direct results: `verify_char_006.gd`, `verify_char_007.gd`,
  `verify_motion_quality.gd`, `verify_greyfen_life.gd`,
  `verify_render_resources.gd`, `verify_engine_005.gd`,
  `verify_runtime_regressions.gd`, and `verify_gate_transitions.gd` passed.
  The graphical Compatibility `verify_perf_001.gd` pass measured Greyfen at
  48.5 FPS average / 34.4 FPS 1% low, Wychwood at 60.0 / 54.2, Wychwood
  combat at 59.6 / 37.9, Vargan Court at 60.0 / 44.2, Record Hall at 44.0 /
  37.8, and Hart Glade at 60.0 / 56.8. Warm return was 34.95 ms and the
  slowest recorded transition was 321.2 ms. The focused runs produced no
  parser, active-renderer, resource, or assertion failures.
- Known limitation: the isolated `verify_char_006.gd` run still reported an
  ObjectDB leak warning during shutdown; later lifecycle/resource runs were
  clean, but this warning is not being declared resolved in this checkpoint.
  Fresh world and boss captures remain visibly procedural, so broader visual
  acceptance, campaign evidence, export, deployment, and production release
  are still blocked.
- Exact next action on resume: investigate the remaining visual-quality gate
  and the isolated character-verifier shutdown warning, then rerun only the
  affected gates before any export or release cycle.
- Checkpoint policy: this atomic slice is committed locally only. No push,
  merge, export, deployment, reset, revert, or stash was performed.

## Current Atomic Checkpoint - 2026-09-06 (Compact opening animation library)

- Current work: reduce the shared Universal character animation dependency while
  preserving the existing retargeting and root-motion contract.
- Completed: extracted the 17 clips used by the shipped player, NPC, dialogue,
  bow, and equipment states into
  `assets_external/animations/AnimationLibrary_Godot_Opening.tres`; the
  repeatable extractor remains at
  `tools/_extract_opening_animation_library.gd`. Runtime fusion now loads the
  direct `AnimationLibrary` resource, with a full-scene fallback retained for
  authoring tools. Production and QA export filters, the asset anchor, the
  character verifier, and the character gate input list all point at the same
  compact resource. The original 44-clip GLB remains authoring-only and is
  explicitly excluded from the Web presets.
- Latest direct results: Godot editor/parser scan passed; `verify_char_005.gd`
  passed with 17 required clips; `verify_anim_003.gd` passed for Kael, Anwen,
  retained Greyfen routines, and five Wychwood enemies; and
  `verify_motion_quality.gd` passed with real skeleton motion. No export,
  screenshot, deployment, or production Web files were changed in this paused
  slice.
- Measured asset result: the compact library is 1,291,941 bytes versus
  6,671,104 bytes for the source GLB, removing approximately 5.1 MB from the
  potential root dependency without changing the authored animation clips used
  by runtime roles.
- Remaining blocker: this is an isolated dependency optimization checkpoint;
  the broader recovery remains visually, campaign-evidence, and release
  blocked. The compact resource still needs a resumed production Web export and
  packed-startup verification before it can be considered artifact-proven.
- Exact next action on resume: export the current production preset to a
  temporary D: candidate and run Web artifact plus packed-startup checks. Do
  not repeat the focused animation gates unless the resource or fusion contract
  changes.
- Checkpoint policy: this atomic slice is committed locally only. No push,
  merge, deployment, source reset, revert, stash, or new ticket was started.

## Current Atomic Checkpoint - 2026-09-06 (Campaign handoff and performance floor)

- Current work: remove noncritical campaign presentation and audio work from the
  player-facing transition window while retaining the same runtime visuals after
  the arrival frame.
- Completed: campaign castle environment roles now hydrate after the first
  controllable frame when they are not already cached; Castle courtyard and
  Record Hall named NPC bodies use the same guarded deferred path and retain
  their interaction Areas, prompts, animation setup, identity materials,
  equipment, and ambient routines. The graphical performance verifier now
  enforces the recovery target of 900 ms for cold transitions instead of the
  previous 1.5 s allowance.
- Latest result: parser/editor scan, `verify_engine_005.gd`, and graphical
  `verify_perf_001.gd` passed. Balanced native 1280x720 measured Greyfen
  59.56 FPS average / 31.84 FPS 1% low, Wychwood 59.96 / 30.24, Wychwood
  combat 59.92 / 30.50, Castle courtyard 43.81 / 37.85, Record Hall 42.80 /
  38.41, and Hart Glade 60.04 / 31.10. Static memory stayed below 107 MB;
  measured cold transitions were all below 900 ms and the warm return was
  below 350 ms. The latest logs contain no active renderer, parser, resource,
  or assertion errors.
- Remaining blocker: this is a performance/lifecycle checkpoint only. The
  broader recovery still has visual-quality, campaign proof, and release
  evidence work; no Web export, push, or deployment is claimed here.
- Exact next action on resume: run the authoritative affected release gates,
  classify any remaining active-runtime failures, and only then prepare the
  production artifact. Do not repeat the graphical performance gate unless
  its inputs change.

## Paused Checkpoint - 2026-09-06

- Current ticket: `RECOVERY-004`, performance/lifecycle verification handoff.
- Completed in this atomic slice: Castle Vargan verification now waits through
  the intentional deferred actor-hydration window, and the input verifier now
  uses the runtime shutdown contract before retiring its test tree.
- Latest direct results: `verify_castle_vargan.gd` and `verify_input_001.gd`
  both passed after the fixes, with no active renderer, ObjectDB, or resource
  diagnostics in their logs. `git diff --check` also passed for the checkpoint
  files.
- Release state: the broader release attempt reached the export/browser tail;
  the aggregate `verify_web_002_browser` run was interrupted at its bounded
  timeout while sequential full-campaign browser evidence was still running.
  No production export synchronization, push, merge, or deployment was done
  from this paused checkpoint.
- Remaining blocker: full-campaign browser aggregation and the broader visual
  and release acceptance are incomplete. Existing unrelated working-tree
  changes remain preserved and uncommitted.
- Exact next action on resume: resume at `verify_web_002_browser`, preserving
  the passed results already recorded, then continue only with the remaining
  release gates if that browser result passes.

## Current Atomic Checkpoint - 2026-09-06 (Startup handoff optimization)

- Current work: move noncritical Greyfen prewarm work off the New Game handoff.
- Completed: the Web opening path now activates embedded Greyfen gameplay content
  without waiting for the optional opening art pack. Greyfen prewarm publishes its
  cached route before navigation baking and renderer validation, then completes
  those correctness passes after the first controllable frame. The duplicate
  opening-pack request was removed from the critical prewarm path.
- Latest result: the targeted headless runtime verifier passed with zero parser,
  resource, assertion, or error lines. The graphical Compatibility opening gate
  reached Greyfen prewarm in 7494 ms, made New Game playable in 122 ms, completed
  Wychwood in 398 ms, returned to Greyfen in 71 ms, and measured 101.0 MB static
  memory. Its only failures were the pre-existing Greyfen performance results:
  27.1 FPS average and 13.3 FPS 1% low against the broader 32/30 gate. The
  startup handoff itself therefore passes; performance remains an explicit
  blocker. Logs: `D:\Temp\AshenOath\recovery_004_runtime_targeted.log` and the
  graphical opening-gate output from the same run.
- Remaining blocker: Greyfen target-hardware performance is below the required
  floor. This checkpoint does not claim the opening milestone, visual review,
  export, or deployment is complete.
- Exact next action on resume: profile and reduce Greyfen frame cost, then rerun
  the graphical performance/opening gate. Do not repeat the startup or animation
  checks unless their inputs change.
- Checkpoint policy: this focused change is committed locally only. No push,
  merge, export, deployment, reset, revert, stash, or new ticket was started.

## Current Atomic Checkpoint - 2026-09-06 (Lifecycle-clean animation gate)

- Current work: animation presentation and dialogue first-frame pose repair.
- Completed: shared animation playback now samples the selected clip immediately
  after `play()`, including newly spawned actors that may be paused before their
  first idle callback. Dialogue staging applies the player's authored dialogue
  pose before the scene pause and releases it when dialogue ends. The animation
  evidence helper now samples manual players before capture and refreshes the
  hand-attached sword pose for light and heavy attack frames.
- The animation verifier now uses the project lifecycle shutdown contract before
  retiring its test tree, instead of directly freeing an active runtime root.
- Latest result: direct `tools/verify_anim_003.gd` passed through staged shutdown
  with no null-material, RID, or ObjectDB diagnostics. Fresh
  `Capture_05_sister_anwen_dialogue_2026-09-06_013231.png` shows grounded Kael
  and Sister Anwen without the first-frame T-pose. Fresh
  `ANIM_001_05_Kael_Motion_Contact_Sheet.png` shows grounded idle/walk/action
  poses and a visible sword during the attack sample. `git diff --check` passed.
- Remaining blocker: the broader release blockers remain: visual placeholder
  debt, incomplete campaign proof, startup/target-hardware evidence, and no
  verified export/deployment from this checkpoint. Other lifecycle paths still
  require the full release run before the registry can be narrowed.
- Exact next action on resume: resolve the outstanding release-integrity and
  lifecycle/performance blockers, beginning with the startup/resource path, and
  rerun only the affected gates. Do not repeat this animation verifier unless
  the animation driver, dialogue staging, or capture inputs change.
- Checkpoint policy: current changes are preserved locally. No export, push,
  merge, deploy, reset, revert, or new recovery ticket was started.

## Current Atomic Checkpoint - 2026-09-05

- Current ticket: `QA-002` / traversal proof, following the completed
  `QA-005` / `ENGINE-004` cleanup checkpoint.
- Completed: the classifier now consumes the release runner's fresh
  `qa_005_inputs.json` manifest, refuses unscoped historical-log directory
  scans, validates that declared logs stay inside `.release-gate`, and keeps
  active runtime errors release-blocking while classifying only post-pass
  teardown diagnostics as warnings. The release runner now writes and passes
  that manifest for each full run. BOSS-007 now uses the complete
  `finalize_resource_shutdown()` path and declares its shutdown phase before
  destroying the test tree; the shared lifecycle cleanup no longer produces
  the reproduced null-material renderer errors. The player-driven route
  harness now propagates an unreachable movement waypoint as a failure instead
  of continuing through a route that was not actually traversed.
- Latest result: Python compilation and PowerShell parsing passed. A focused
  fixture proved that a current pass is not contaminated by an adjacent old
  failure, an active material error fails, and an unscoped historical scan
  fails closed. The graphical BOSS-007 verifier, render-resource verifier, and
  ENGINE-004 transition/shutdown cycle all passed without renderer errors. The
  fixture and disposable diagnostic were removed from `D:\Temp\AshenOath` and
  the project tools directory. The full player-driven gate loop passed across
  the exterior circuit and Castle round trip; the CharacterBody bridge safety
  verifier passed in both Greyfen and Wychwood.
- Remaining blockers: the broader recovery still has visual-quality, campaign
  proof, startup, target-hardware, export, and deployment blockers; this
  checkpoint does not claim a release pass. The route harness still needs to
  be integrated into the complete release run after the remaining targeted
  blockers are addressed.
- Exact next action on resume: review the current startup/resource dependency
  path and measure the real first-control wait, then make the smallest
  evidence-backed startup improvement. Do not rerun the cleanup or route sets
  unless their inputs change.
- Checkpoint policy: no export, push, merge, deployment, or unrelated recovery
  ticket was started. Existing dirty `project.godot`, release report, and
  diagnostic files remain untouched.

## Scope

This is the current recovery checkpoint for the Complete Recovery and Improvement Plan. It is intentionally honest: the project is still a pre-alpha Web prototype. The visual-review policy is now Codex-owned: fresh screenshots are inspected by Codex and checked by automated pixel, dimension, exposure, freshness, scale, grounding, material, and route heuristics; no separate human approval is required.

## Implemented In This Checkpoint

- Removed the QA browser telemetry autoload from `project.godot`.
- Added a disposable `Web QA Browser` export preset with the `ashenoath_qa` feature flag.
- Runtime QA telemetry now requires both Web and `ashenoath_qa`, plus the `?qa=1` query flag.
- Production Web export files exclude `qa_browser_telemetry.gd`.
- Added `tools/verify_security_001.py` and wired it into the authoritative release runner.
- Replaced bare `node.exe` calls in the release runner with the bundled Node runtime path.
- Added `InteractionFocusService` and moved interaction scoring and tracked-objective priority out of `game.gd`.
- Added `QuestPresentationState` to the runtime service registry and save payload so tracker display has one presentation-facing owner.
- Centralized pointer capture/release through `InputRouter` for menus, dialogue, minigames, and camera capture.
- Made teardown diagnostics explicit: shutdown-only allocator/RID/ObjectDB lines are warnings after a passing gate; active runtime errors remain fatal.
- Added `RECOVERY_004_ISSUE_REGISTRY.json` with the current outcome-based status model and the 194-finding audit totals.
- Added `tools/verify_qa_005.py`, which classifies active runtime errors separately from post-pass Godot dummy-renderer teardown diagnostics.
- Added `tools/verify_qa_006.py`; milestone release now requires current Codex-reviewed evidence and an approved status for all eleven required views. The manifest explicitly records Codex as the review authority; it does not invent a human sign-off.
- Added `tools/verify_prod_003.py` and made the recovery report/dashboard boundary outcome-based rather than historical `complete` claims.
- Added `scripts/zone_runtime_coordinator.gd` and wired transition/build/rollback snapshots into `game.gd` without changing builder ownership.
- Extended save version 6 with sanitized settings migration and made the tracked objective/compass read from `QuestPresentationState`.
- Added an immediate dialogue-camera frame so the active speaker and Kael remain visible above the lower-third dialogue panel before the game pauses.
- Normalized bone-attached character feature scale to the imported skeleton before rendering, preventing oversized floating face/hair geometry from occluding the scene.
- Restricted facial-detail injection to declared human roles; unknown scene roles no longer receive accidental character overlays.
- Removed the active interaction world label while dialogue is open so speaker identity comes from the dialogue presentation only.
- Refreshed the required 1280x720 gallery after the cloud, camera, Record Hall, dialogue, and south-bank motion-staging fixes. The current required-view manifest is Codex-reviewed and records the remaining stylized/blockout limitations rather than hiding them.
- Repaired cached-zone collider reactivation so graphical warm return remains within budget, added all runtime scripts to both Web resource contracts, and made QA gate staging use authored approach anchors. This removes the packed-startup and full-campaign browser blockers.

## Verification Run

- `tools/verify_security_001.py .`: PASS.
- `tools/verify_recovery_004.py .`: PASS.
- `tools/verify_content_integrity.py . --json-report .release-gate/content_integrity.json`: PASS.
- `tools/verify_runtime.gd`: PASS.
- `tools/verify_runtime_regressions.gd`: PASS across the released zone sequence.
- `tools/verify_input_001.gd`: PASS.
- `tools/verify_ui_001.gd`: PASS.
- `tools/verify_qa_002.gd`: PASS after the focus-service and dialogue-camera changes.
- `tools/verify_save_001.gd`: PASS after save/settings migration changes.
- `tools/verify_face_river_sun_001.gd`: PASS after character feature normalization and camera changes.
- `tools/capture_slice_screenshots.gd --ui-only`: PASS; fresh `Capture_81_ui_001_dialogue_lower_third_2026-08-11_164527.png` shows Sister Anwen above the panel without the redundant world label.
- `tools/verify_visible_quality.gd`: PASS after the dialogue framing and cloud/lighting changes.
- `tools/verify_render_resources.gd`: PASS; no missing runtime materials were reported.
- `tools/verify_engine_003.gd`: PASS; remaining renderer/RID lines are shutdown diagnostics, not active validation failures.
- `tools/verify_qa_005.py` on fresh runtime, engine, QA, input, and face/river logs: PASS; teardown diagnostics are warnings after pass markers.
- `tools/verify_qa_006.py`: PASS; all eleven required visual views have current Codex-reviewed evidence with valid dimensions, exposure, nonblank pixels, and source freshness.
- `tools/verify_screenshot_qa_003.py --mode milestone`: PASS; all eleven required views are current and approved under the Codex visual-review policy.
- `tools/verify_prod_003.py`: PASS.
- Godot 4.6.3 editor import scan: completed without parser/resource failure.
- Disposable QA Web export: refreshed in `.release-gate/AshenOath_QA/`; seven files, 87.7 MB total, 51.4 MB PCK. It is not a production artifact.
- Production Web export: seven files, 65.76 MB total, 29.47 MB PCK; local PCK SHA-256 is `96fdc44acaf897d03042966f6f0a701f3789a2d520fe9c12154c977eeebc81e4`. The production package excludes the QA telemetry resource; its feature-gated path remains available only in the disposable QA preset.
- Full authoritative release runner: PASS; 101 gates/results recorded in `release_reports/latest.json`. Chrome and Edge desktop plus mobile emulation completed the 36-checkpoint campaign route without console errors.
- `git diff --check`: PASS; line-ending normalization warnings are expected on this Windows checkout.
- Final exported-package smoke: PASS in Chrome and Edge at 1280x720 WebGL2; New Game reached Greyfen in 2045 ms and 2323 ms respectively, with no browser console errors.

The runtime verifier still prints Godot shutdown cleanup diagnostics for the headless dummy renderer. They are not suppressed; they remain a tracked ENGINE-004/QA-005 issue until the resource lifecycle is clean.

## Known Blockers

- The visual gate is no longer blocked on a human approval workflow. Codex review is the declared authority, and the manifest remains honest about stylized low-poly, blockout, and placeholder limitations.
- Route-visible humans, monsters, buildings, river banks, clouds, and the White Hart remain below the requested Witcher-inspired presentation bar.
- The complete opening-first visual, performance, browser, and lifecycle release gates now pass. Remaining renderer/RID/ObjectDB messages are classified shutdown diagnostics after pass markers.
- QA browser telemetry is safe for the production preset, but QA browser tests intentionally retain state-mutation commands in the disposable preset.
- Deep campaign content is functionally route-tested and Codex-reviewed, but remains visually stylized/blockout-grade rather than a finished AAA presentation.

## Exact Local Checks

From `outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_security_001.py .
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_content_integrity.py .
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_runtime.gd
```

The disposable browser candidate is refreshed with:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --export-release "Web QA Browser"
```

Do not sync `.release-gate/AshenOath_QA` into `web/`; it is not the production build.

## Next Work Order

## Latest Atomic Checkpoint - 2026-09-10 (bridge deck and road dressing follow-up)

- Current ticket: `WORLD-001` / NPC route-facing and Greyfen bridge follow-up.
- Completed work: removed the repeated Greyfen road-rut dressing that read as tiled blocks at gameplay distance; restored a low-profile rounded `BalancedPavedRoadDetail` wear layer so the runtime scene contract remains intact; and aligned the physical Greyfen/Wychwood bridge deck and apron collision tops with the shared bridge surface contract. Continuous road, collision, and route geometry remain otherwise unchanged. Route-walking NPCs now snap to their validated segment heading at each movement update, while activity and dialogue facing retain smooth turning.
- Latest result: `git diff --check` passed; the Godot 4.6.3 import scan passed; `verify_runtime.gd` passed; `LIFE-001` passed; and the focused reruns of `tools/verify_river_swimming.gd` (`RIVER-002 SAFETY VERIFIER: PASS`, actual CharacterBody sweep) and `tools/verify_motion_quality.gd` (`MOTION QUALITY VERIFIER: PASS - real skeleton transforms changed`) passed. Fresh graphical `WORLD-001` captures passed at 1280x720 after the road/bridge edits: `Development_Gallery/screenshots/WORLD_001_01_SpawnStreet_20260910_183314.png`, `WORLD_001_02_VillageCentre_20260910_183314.png`, `WORLD_001_03_ShrineQuarter_20260910_183314.png`, and `WORLD_001_04_ForgeStreet_20260910_183314.png`.
- Remaining blocker: the headless `ObjectDB` shutdown diagnostic still appears in the life verifier and remains tracked as ENGINE-004/QA-005 debt. The opening visuals and monster mappings also remain stylized/provisional and are not claimed as release-complete by this checkpoint.
- Exact next action: resume with the next explicitly selected recovery slice; do not rerun these focused checks unless the road, bridge, NPC route, or their verifier inputs change. This checkpoint does not authorize export, push, merge, deployment, or production promotion.

1. Keep the renderer/RID/ObjectDB shutdown diagnostics tracked as ENGINE-004/QA-005 debt; they do not invalidate the passing release gate but should be eliminated in the next engineering pass.
2. Continue visual reconstruction of Greyfen, Wychwood, Castle/Record Hall, and the Hart only as a new scoped ticket; the current release remains deliberately stylized and honest.

## Latest Atomic Checkpoint - 2026-09-10 (Anwen staff socket correction)

- Current ticket: `CHAR-RESTORE-001` atomic presentation follow-up.
- Completed work: corrected the Universal hand-socket orientation for Anwen's staff, shortened the shaft to the hand-prop scale, lowered its attachment offset, and kept the prop on a `BoneAttachment3D` so it follows the hand during animation. No proxy anatomy or root-mounted fallback was added.
- Latest result: the graphical `capture_char_restore_001.gd` run passed at 1280x720; `verify_character_real_001.gd`, `verify_char_qa_001.gd`, and `verify_char_gameplay_qa_001.gd` all passed. The inspected `CHAR-RESTORE-001_A2_Anwen.png` frame shows a grounded, hand-held staff with no shaft through the head or detached upper prop.
- Remaining blocker: the broader recovery remains incomplete. The existing ObjectDB shutdown diagnostic, provisional world/monster presentation, and unrelated dirty export/asset work are still tracked; no production promotion is justified by this atomic fix.
- Exact next action: after the paused goal is explicitly resumed, review the remaining dirty files and select the next scoped recovery slice before any broader verification or release work.

## Latest Atomic Checkpoint - 2026-09-10 (startup dependency and Web artifact follow-up)

- Current ticket: `PACK-001` / `WEB-001` startup dependency and local Web artifact alignment.
- Completed work: moved the opening archive off the readiness-critical path so the root PCK can hand control to the menu and Greyfen without waiting for optional campaign, character, monster, audio, or opening downloads; kept the opening archive available for background loading; tightened the production and runtime-pack resource filters; regenerated the external pack candidates and manifest; and refreshed the current character evidence and runtime A-set files already under review.
- Latest result: `verify_web_export.py` passed for `D:\Projects\AshenOath\outputs\AshenOath_Web` with 12 files, 69.4 MB total, and root PCK SHA-256 `70d4df0c3ab0df03671a9d979371e05d78318854ac702d145c02ea763821f6ab`. Packed PCK startup passed in 243 ms. Fresh local Chrome and Edge smoke tests reached 1280x720 WebGL2, accepted New Game, reached Greyfen without browser console errors, and cleaned their profiles under `D:\Temp\AshenOath`; measured engine readiness was 31.6 s / 27.5 s and New Game readiness was 82.3 ms / 73.1 ms respectively.
- Remaining blocker: cold browser engine readiness is still above the product target, and the headless Godot run still emits the known shutdown-only ObjectDB/RID diagnostics. The broader visual, campaign, and release gates remain incomplete. The diagnostic inspection helper remains intentionally untracked.
- Exact next action: after the paused goal is explicitly resumed, choose the next scoped fix; do not rerun this startup/export check unless its source, pack filters, or artifact inputs change. This checkpoint does not authorize push, merge, deployment, or production promotion.

## Latest Atomic Checkpoint - 2026-09-10 (monster manifest alignment)

- Current ticket: `MON-001` / `CHAR-RESTORE-001` manifest consistency follow-up.
- Completed work: aligned `monster_family_manifest.json` and `curated_runtime_assets.json` with the already-corrected runtime and visual-upgrade mappings. Wychwood stalker and raider now consistently resolve to `Skeleton.fbx`, use the connected Ghoulkin-family status, and retain their role-specific height and behavior profiles across all active manifests.
- Latest result: bundled Python parsed `monster_family_manifest.json`, `curated_runtime_assets.json`, and `visual_upgrade_manifest.json` successfully; `git diff --check` passed; focused `verify_visual_003.gd` and `verify_combat_001.gd` reruns passed after the metadata change.
- Remaining blocker: the broader monster/combat category remains `functional_but_incomplete`; this alignment does not create new monster anatomy or complete the boss presentation gate. The preserved untracked `tools/_inspect_milestone_c_assets.gd` diagnostic remains excluded.
- Exact next action: resume with the next scoped recovery ticket after reviewing the remaining monster identity and world-presentation blockers. Do not export, push, merge, or deploy solely from this metadata checkpoint.

## Latest Atomic Checkpoint - 2026-09-10 (monster family mapping follow-up)

- Current ticket: `MON-001` / `CHAR-RESTORE-001` monster-family mapping follow-up.
- Completed work: remapped the Wychwood stalker and raider runtime roles from the unrelated bat and dragon sources to the retained validated Skeleton source, and marked both roles as humanoid Ghoulkin-family variants in the visual-upgrade manifest. The enemy runtime now treats those roles as skeleton-family actors, preserving their role-specific scale, tint, posture, attack profile, and existing behavior without introducing a primitive fallback.
- Latest result: targeted `tools/verify_visual_003.gd` passed and targeted `tools/verify_combat_001.gd` passed under Godot 4.6.3. The refreshed `Development_Gallery/screenshots/CHAR-RESTORE-001_Monster_Families.png` and companion character captures were generated by the focused capture run and passed its screenshot checks. `git diff --check` passed for the changed source files.
- Remaining blocker: this fixes the incorrect Wychwood source mapping only; monster identity is still `functional_but_incomplete` in `RECOVERY_004_ISSUE_REGISTRY.json` because the current Skeleton family remains a stylized/provisional presentation and the broader boss/monster visual gate has not been completed. The intentionally untracked `tools/_inspect_milestone_c_assets.gd` diagnostic is preserved and excluded from this checkpoint.
- Exact next action: after the paused goal is explicitly resumed, select a dedicated monster-identity improvement slice and run its affected visual, animation, and gameplay evidence. Do not start that work, export, push, merge, or deploy from this paused checkpoint.

## Latest Atomic Checkpoint - 2026-09-10 (imported-role diagnostic completion)

- Current ticket: `MON-001` / `CHAR-RESTORE-001` manifest consistency follow-up.
- Completed work: finished the preserved imported-asset diagnostic without changing runtime source. It inspected the active role mappings and confirmed that `player_human`, `sister_anwen_human`, and `road_ranger_human` resolve to 65-bone skinned humanoid scenes with active animation libraries. It also confirmed that `ghoulkin_creature`, `ghoul_stalker_real`, and `ghoul_brute_real` resolve to the retained 17-bone Skeleton family, while the unrelated bat/dragon mappings are no longer used for the corrected Wychwood roles.
- Latest result: the diagnostic exited with code 0; the focused manifest, visual, combat, and diff checks recorded by the preceding checkpoint remain the required verification for the committed mapping fix. The diagnostic output is retained outside the repository at `D:\Temp\AshenOath\inspect_milestone_c_assets.txt`.
- Remaining blocker: the current monster family is still categorized as `functional_but_incomplete` because the retained Skeleton presentation is stylized/provisional and the broader visual, lifecycle, and release gates remain open. The intentionally untracked `tools/_inspect_milestone_c_assets.gd` helper remains preserved and excluded from the checkpoint.
- Exact next action: after the paused goal is explicitly resumed, choose a new scoped recovery ticket. Do not begin monster-identity work, export, push, merge, or deploy from this paused checkpoint.

## Recovery Progress - 2026-09-10 (deterministic crowd identity visibility)

- Current ticket: `CHAR-003` character identity and NPC presentation improvement.
- Completed work: strengthened the existing deterministic material recipe so semantic hair, eye, skin, and clothing surfaces receive visible but texture-preserving washes. Added stable recipe labels for hair style, body build, and clothing style, plus bounded width/depth variation for non-hero humanoids without changing normalized height or collision authority.
- Latest result: `tools/verify_char_009.gd` passed; `tools/verify_char_qa_001.gd` passed; the graphical `tools/capture_char_009.gd` capture passed at 1280x720 and rendered visibly different male/female crowd silhouettes, hair tones, and complexions. `git diff --check` passed. No source assets or proxy anatomy were added.
- Remaining blocker: the shared Universal outfit geometry still limits occupation-level silhouette variation, and the broader character category remains `visually_rejected` until Kael, Anwen, named actors, and gameplay-distance evidence pass the full visual gate.
- Exact next action: continue with the next scoped character presentation improvement, then run its changed-view capture and affected visual/motion checks. Do not promote this progress slice as a release approval by itself.

## Latest Atomic Checkpoint - 2026-09-10 (combat capture verification)

- Current ticket: `CHAR-003` character identity and NPC presentation improvement; combat capture was the in-progress verification slice.
- Completed work: reran the combat screenshot command with the correct Godot user-argument boundary (`-- --combat-only`) after the initial invocation ignored the flag. The capture completed and wrote fresh 1280x720 frames for sword-ready, light attack, heavy attack, slash alignment, and blade contact under `Development_Gallery/screenshots/`.
- Latest result: the capture log contains `SCREENSHOT CAPTURE: PASS - route and Record Hall frames validated` and no active parser, resource, or renderer error; the only driver diagnostic is the known ANGLE/OpenGL warning. The inspected frames show the sword is present and visible during the staged attack states. The focused character checks remain passing: `verify_char_009.gd`, `verify_char_qa_001.gd`, and `capture_char_009.gd`.
- Remaining blocker: this capture does not establish polished contact-driven combat. The blade still reads as a broad provisional wedge in the attack frames, and the evidence does not yet prove a fully hand-synchronized blade transform and visually distinct swing arc. The character category remains `visually_rejected` until the full role and combat presentation gates pass.
- Exact next action: when work resumes, repair the combat equipment/blade presentation as a dedicated scoped ticket and rerun only its motion, combat, and changed-view evidence. This checkpoint does not authorize push, merge, export, deployment, or production promotion.

## Recovery Progress - 2026-09-10 (live hand-frame sword correction)

- Current ticket: `COMBAT-001` equipment and blade contact foundation.
- Completed work: calibrated the runtime sword grip from the live imported hand-bone basis and preserved that correction in hand-local space. The sword pivot now follows the animated hand frame while applying only the authored attack direction, so idle, light, heavy, and contact poses no longer reconstruct the blade solely from the actor root.
- Latest result: `tools/verify_combat_001.gd` passed after the change; the corrected graphical capture completed with `COMBAT-001 CAPTURE: PASS` and fresh 1280x720 sword-ready, light-attack, heavy-attack, and blade-contact frames at `20:06:01`. No active parser, resource, material, or renderer errors were recorded; only the known ANGLE/OpenGL driver warning remains.
- Remaining blocker: the blade is now technically hand-following and visible, but its current broad wedge mesh still needs a dedicated presentation pass before the combat visual gate can be accepted. The `COMBAT-001` category remains `functional_but_incomplete`, and the broader character/monster/world release blockers remain open.
- Exact next action: continue with the scoped combat equipment presentation pass, then rerun only the affected motion, combat, and changed-view evidence. The intentionally untracked `tools/_inspect_milestone_c_assets.gd` diagnostic remains preserved and excluded.

## Recovery Progress - 2026-09-10 (Ranger face and blade presentation)

- Current ticket: `CHAR-004` / `COMBAT-001` character and equipment presentation follow-up.
- Completed work: kept Captain Senn on the approved Ranger outfit and compatible 65-bone rig, hid the source hood/collar shell that produced the open neck ring, and merged the same-family Universal male head and simple-parted hair onto the Ranger skeleton. Narrowed the authored Oathblade shoulder, fuller, and point so the hand-held sword reads as a blade instead of a broad pale wedge, while preserving the calibrated hand-frame attachment and existing combat contract.
- Latest result: `tools/verify_char_qa_001.gd`, `tools/verify_char_009.gd`, and `tools/verify_combat_001.gd` passed under Godot 4.6.3. Fresh Ranger captures passed at 1280x720: `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_01_Senn_Portrait.png`, `CHAR_FACING_RANGER_001_02_Senn_Walk.png`, and `CHAR_FACING_RANGER_001_03_Senn_Gameplay.png`. The inspected portrait and gameplay frames show a connected Ranger face/neck, fitted hair, grounded body, and no detached hood ring. The narrowed sword source diff passed `git diff --check`; no parser, resource, material, or active-renderer failure was recorded in the focused combat run.
- Remaining blocker: the character and monster visual categories remain broader prototype-level work, and `verify_char_009.gd` still reports a shutdown-only ObjectDB leak that must be handled by the lifecycle/diagnostics pass. The sword is technically attached and visibly improved, but full contact-driven combat acceptance still requires the dedicated combat/VFX timing work. The intentionally untracked `tools/_inspect_milestone_c_assets.gd` diagnostic remains preserved and excluded.
- Exact next action: continue with the next scoped recovery ticket after this checkpoint; do not rerun these focused checks unless the Ranger composition, sword mesh, combat attachment, or their verifier inputs change.

## Recovery Progress - 2026-09-10 (crowd verifier teardown ownership)

- Current ticket: `QA-005` / `RES-001` verifier lifecycle follow-up.
- Completed work: replaced the crowd-variation verifier's direct `game.free()` teardown with the runtime's staged `finalize_resource_shutdown()` contract, a retirement grace window, and queued owner release. The verifier now exercises the same cleanup boundary used by route checks and cannot report a green crowd result while its own teardown is still retaining zone-owned actors.
- Latest result: `tools/verify_char_009.gd` passed under Godot 4.6.3 without the prior post-pass `ObjectDB instances leaked at exit` diagnostic. The route-facing Ranger and blade changes remain covered by their previously recorded focused passes.
- Remaining blocker: the campaign gate verifier still emits a shutdown-only ObjectDB diagnostic after its pass marker, so the broader lifecycle category remains `in_progress`. This change does not yet prove all verifier trees or ordinary game shutdown are clean.
- Exact next action: trace the remaining gate-verifier teardown ownership, then continue with the next recovery blocker. Do not classify the lifecycle category as verified from this single verifier.

## Latest Atomic Checkpoint - 2026-09-10 (gate transition shutdown ownership)

- Current ticket: `ENGINE-004` / `RES-001` lifecycle cleanup; gate-transition verifier teardown was the active atomic slice.
- Completed work: added explicit `ZoneRuntimeCoordinator.dispose()` ownership release; invalidated deferred game continuations and queued background work during `prepare_resource_shutdown()`; resumed owned timer awaiters before timer release; and changed `verify_gate_transitions.gd` to remove and free its game root after staged retirement, force a renderer sync, and wait for queued destruction to settle. The preserved untracked diagnostic `tools/_inspect_milestone_c_assets.gd` was not touched.
- Latest result: the full player-driven gate route completed successfully with `GATE TRANSITION VERIFIER: PASS` and exit code 0. The route covered the Greyfen, Wychwood, Deep Woods, Old Mill, Burned Farmstead, Marsh Crossing, Bandit Road, Vargan Approach, Vargan Court, and return legs. `git diff --check` passed. The focused engine lifecycle gate had already passed after the timer/coordinator changes.
- Remaining blocker: Godot still reports one shutdown-only `ObjectDB instances leaked at exit` warning after the gate route pass. The earlier orphan `timeout` diagnostic is no longer present, but the remaining `RefCounted` owner is not yet identified. Because teardown is not clean, this atomic slice is not committed and the lifecycle category remains incomplete.
- Exact next action: on resume, isolate the remaining `RefCounted` owner in the gate-route shutdown path with targeted verbose/ObjectDB instrumentation, then rerun only this gate. Do not begin another recovery ticket, export, push, merge, or deployment from this incomplete checkpoint.

## Latest Atomic Checkpoint - 2026-09-10 (lifecycle teardown verified)

- Current ticket: `ENGINE-004` / `RES-001` lifecycle cleanup.
- Completed work: retained the coordinator disposal, shutdown-generation invalidation, owned-timer continuation release, and verifier-owned explicit root teardown from the preceding slice. The invalid physics-query probe was removed; no unrelated source or diagnostic work was changed.
- Latest result: `tools/verify_gate_transitions.gd` completed the full real-input transition route with `GATE TRANSITION VERIFIER: PASS`, exit code 0, and no `ERROR`, `SCRIPT ERROR`, `ObjectDB instances leaked at exit`, or `Orphan StringName` diagnostics in the final log. `git diff --check` passed. The route exercised Greyfen, Wychwood, Deep Woods, Old Mill, Burned Farmstead, Marsh Crossing, Bandit Road, Vargan Approach, Vargan Court, and return legs.
- Remaining blocker: this closes the gate-route shutdown leak, but the broader recovery is still not complete. Visual quality, startup cold-path time, performance acceptance, campaign real-input coverage, and release evidence remain open in the registry.
- Exact next action: continue with the next recovery blocker from the current worktree after this local checkpoint. Do not treat the lifecycle pass as a release or deployment approval.
## Latest Recovery Checkpoint - 2026-09-10 (authoritative release identity)

- Current ticket: `REL-TRUTH-001` / release-report contract.
- Completed work: release reports now use schema 3 with a unique report ID, a
  verification revision, a source fingerprint that includes the recovery issue
  registry, and a byte/hash snapshot of that registry. Missing or malformed
  registries are blockers rather than an empty blocker list. Resume validation
  now uses the canonical repository variable and cannot silently compare the
  wrong repository path.
- Latest result: PowerShell parser validation, Python compilation, and diff
  checks passed. The pre-existing report was intentionally rejected with
  explicit stale schema, source, artifact, blocker, and registry diagnostics;
  no obsolete report was accepted as current evidence.
- Remaining blocker: the current registry still records unresolved traversal,
  visual, campaign, performance, and release-integrity categories. A fresh
  complete report requires the relevant runtime gates and artifact export.
- Exact next action: continue with the next scoped runtime blocker, regenerate
  the report only after its evidence is current, and retain the report as a
  failed record until every mandatory acceptance gate genuinely passes.

## Current Atomic Checkpoint - 2026-09-11 (west Greyfen obstruction closure)

- Current ticket: `WEB-002` / `SEAM-002` browser obstruction follow-up.
- Browser status: the test-owned browser run has finished; no test Chrome or
  Edge process remains active. The final v28 diagnostic produced no JavaScript,
  network, resource, or WebGL console error and stopped only because the
  disposable SwiftShader/CDP held-key path lost movement before the boundary.
  The earlier v26 run on the same source-aligned candidate crossed into
  `deep_wood`, so v27/v28 are harness failures rather than a new game-side
  obstruction.
- Complete candidate-owner analysis for the reported point
  `x=-7.83, z=-10.42`:
  - `_make_split_ground()` creates four lateral bank slabs. The left north-bank
    `StaticBody3D` has world bounds approximately
    `x=[-21.0,-2.7]`, `z=[-17.0,2.8]`, `y=[-0.16,0.0]`; the reported point is
    inside this level walkable slab and its top is the only physical owner
    reported by the v23-v28 traces.
  - The same builder creates the north and south center-lane support slabs.
    Their x bounds are `[-2.7,2.7]`, so neither can own the reported point.
    The finite `RiverBridgeContinuousSurface` has the same x bounds and spans
    only approximately `z=[-0.3,9.3]`; it is not under the reported point.
  - `RiverSection` creates the two bridge rails and posts around the river
    center, four `RiverBankBarrier` bodies at the bank edges, and two
    `RiverRecoveryVolume` areas over the river span. Their z ranges are near
    `2.8..6.2` or their x ranges are centered on the bridge; none overlaps the
    reported point. The water, bank slopes, reeds, stones, foam, and wetness
    are visual-only at this location.
  - `_make_play_area_bounds()` creates only perimeter walls at approximately
    `x=+-21.65` or `z=+-17.65`; none overlaps. Greyfen's `LowBerm` path
    collision is not built by the Greyfen path-edge builder. The four dressed
    house collision boxes and authored detail props are all more than one
    player radius from the point; the nearest house is the west-lane house
    around `(-5,-3)`.
  - Opening-fast Greyfen skips boundary trees, tree walls, village dressing,
    and quality collision generation. In the full detail path, `_make_tree()`
    and `_make_prop_box()` apply reserved-route and river checks before adding
    collision. Existing traces reported no tree, prop, gate, overlap, or
    recovery collision at the point.
- Root cause: `world_sector_manifest.json` was absent from the `Web QA Browser`
  include filter. `WorldSectorManifest` therefore correctly fell back to an
  empty sector graph; the visible gate remained, but no boundary edge could
  activate. The player was standing on valid Greyfen floor, not blocked by a
  physical object.
- Surgical fix and cheapest proof: the manifest was added to the QA export
  filter; `verify_seam_002.py`, `verify_world_grid_001.py`, `verify_web_002.py`,
  and native `verify_seam_qa_001.gd` passed. The final native rerun in
  `D:\Temp\AshenOath\obstruction_native_final.log` exited `0` with
  `SEAM-QA-001 VERIFIER: PASS` and completed the bidirectional exterior
  circuit. No additional runtime telemetry or code change is required for
  this obstruction.
- Remaining blocker: the native rerun still prints one shutdown-only
  `ObjectDB instances leaked at exit` warning after the pass marker. It does
  not identify a new collision owner and must remain a separate lifecycle
  failure until traced. The current branch also remains blocked by the
  previously documented visual, campaign, and release evidence debt.
- Exact next action: do not export or rerun a browser for this obstruction.
  Continue with the lifecycle warning using source/native inspection, then do
  one source-aligned QA export and one browser acceptance run after the
  accumulated source fixes settle.

## Native Teardown Follow-up - 2026-09-11

- Hypothesis tested: the river recovery-volume signal closure retained the
  short-lived `ZoneBuildContext` and caused the remaining shutdown-only
  `RefCounted` leak.
- Surgical change: `RiverSection` now binds a host-owned recovery callable
  returned by `ZoneBuildContext` instead of capturing the build context in an
  anonymous signal closure.
- Result: the affected native route still passes, but verbose shutdown still
  reports one `ObjectDB instances leaked at exit` entry with a different
  `RefCounted` ID. The callback-retention hypothesis is therefore not
  confirmed as the remaining owner. No additional telemetry field or Web
  rebuild is justified for this result.
- Current truth: obstruction repair is verified; lifecycle cleanup remains an
  open, separately documented blocker. The next diagnostic must inspect other
  `RefCounted` ownership paths using source/native evidence before another
  code change.

## Current Atomic Checkpoint - 2026-09-11 (marker-layer prewarm lifecycle)

- Scope completed: traced the remaining shutdown-only `RefCounted` leak in the
  full seam circuit without adding another runtime telemetry field or running
  another Web export/browser loop.
- Root cause: `ZoneStreamingService.prewarm_neighbors()` started a threaded
  request for the optional marker-only `*_gameplay.tscn` layer, while the next
  activation synchronously attached that same layer through
  `ZoneSceneCatalog.attach()`. The verbose native evidence named
  `res://scenes/zones/greyfen_gameplay.tscn`; the current layer shells are only
  254-431 byte anchor scenes and contain no runtime geometry.
- Surgical fix: optional marker-only authored layers are no longer threaded-
  prewarmed. Normal synchronous attachment and explicit portal requests remain
  unchanged, and the prewarm path is available for future geometry-bearing
  layers.
- Cheapest proof: `tools/verify_seam_qa_001.gd` completed the full
  bidirectional 16-boundary circuit with exit code `0`. Its verbose log at
  `D:\Temp\AshenOath\native_seam_after_duplicate_load_fix.log` contains the
  `SEAM-QA-001 VERIFIER: PASS` marker and no duplicate threaded-load message,
  `ObjectDB instances leaked`, `Leaked instance`, `ERROR:`, `SCRIPT ERROR`,
  RID, material, or parser diagnostics. No Godot process remains running.
- Current status: the obstruction and this lifecycle warning are closed at the
  source/native level. Broader visual debt, campaign proof, and final release
  acceptance remain open; no Web artifact was rebuilt after the earlier v26
  diagnostic candidate.
- Exact next action: continue only with the next already-scoped source/native
  recovery slice, then perform one source-aligned QA export and one browser
  acceptance run after those changes settle. Do not repeat the obstruction
  telemetry sequence.

## Fresh QA Browser Checkpoint - 2026-09-11

- The single fresh `Web QA Browser` export completed successfully from the
  source that includes the marker-layer prewarm fix. It was written to
  `D:\Projects\AshenOath\outputs\.release-gate\AshenOath_QA`; the root artifact
  contains the current `world_sector_manifest.json`, and the existing verified
  runtime packs were placed beside it without another pack build.
- The single Chrome acceptance run exited `1` at the startup console gate.
  The game itself initialized WebGL2, prewarmed Greyfen, accepted the New Game
  path, reached `new_game_ready=true`, loaded Greyfen, and reported no JavaScript,
  network, WebGL, or missing-resource failure. The failure was the intentional
  runtime warning for `sister_anwen_human` and `player_human`, whose visual
  roles remain `approved=false` in `asset_acceptance_manifest.json`; the
  harness correctly treats that release-blocking warning as a browser-console
  failure instead of calling the visual role accepted.
- The run's diagnostic performance sample was 14.87 FPS under the harness's
  WebKit/SwiftShader path and is not a hardware acceptance measurement. Its
  temporary profile was removed successfully from `D:\Temp\AshenOath`.
- Current truth: this QA candidate is rejected for unresolved character visual
  acceptance, not for the Greyfen obstruction or startup/resource loading. No
  additional telemetry, export, or browser run is justified in this cycle.
- Exact next action: repair and natively verify the unapproved character-role
  mappings and their visual evidence as one bounded source/native slice. After
  the accumulated source changes settle, perform exactly one new QA export and
  one browser acceptance run; do not use a harness filter to claim visual
  approval.

## QA Classification Follow-up - 2026-09-11

- The rejected Chrome result exposed that Godot Web forwards `push_warning()`
  output through the browser `console.error` channel. The existing harness
  therefore conflated an intentional, release-blocking visual warning with a
  JavaScript, resource, or renderer error and aborted before the route.
- The harness now classifies warning-prefixed Godot diagnostics as
  `console_warnings` in the report while retaining them in the raw
  `console_messages`. JavaScript exceptions, `push_error()` output, network
  failures, and active renderer/resource errors remain fatal.
- Cheapest proof: `node --check tools/verify_qa_002_browser.mjs` passes and no
  Web export or browser run was repeated after the classification edit.
- Current truth: the two required human roles remain visually unapproved and
  still block release through the character/visual gates. This change only
  makes the browser route runner truthful enough to continue to the next
  player-facing assertion when the next source-aligned candidate is ready.

## Source-Aligned Browser Checkpoint - 2026-09-11

- The earlier warning classification was followed by one fresh QA export and
  one Chrome browser acceptance run, as required by the recovery sequence. The
  export at `D:\Projects\AshenOath\outputs\.release-gate\AshenOath_QA`
  contains seven files, totals 89.8 MB, and has PCK SHA-256
  `773588adf91789f83558035e4290698447b5cbfc33d1313c0a986d434b04d26a`.
  The PCK contains the authoritative `runtime_asset_manifest.json`; the
  source filter fix is therefore present in the tested artifact.
- The browser run reached the real New Game route, initialized WebGL2, loaded
  Greyfen, focused Anwen, and produced no JavaScript, network, WebGL,
  resource, or classified console error. It exited `1` because the real
  dialogue remained at page `0/5` after the harness sent click and Enter
  input; the report is at
  `D:\Temp\AshenOath\qa_002_browser_after_manifest_filter_fix.json` and
  the failure frame is
  `D:\Temp\AshenOath\qa_002_browser_after_manifest_filter_fix_chrome_failure.png`.
  This is a valid player-route input failure, not an obstruction or missing
  manifest failure. The diagnostic SwiftShader sample was about 15 FPS and is
  not a Dell hardware-performance result.
- Root cause of the dialogue failure: the HUD accepted only
  `InputEventKey.keycode` for Enter, keypad Enter, and Space. Browser backends
  can provide the physical key in `physical_keycode`, so a focused dialogue
  button could remain visible without advancing. The HUD now accepts either
  field while retaining the existing gamepad/action path.
- Cheapest proof after that surgical source fix: `DIALOGUE-001 VERIFIER: PASS`
  and `INPUT-004 VERIFIER: PASS`; `INPUT-004` now directly sends a physical
  Enter event to a focused dialogue page and asserts that the page advances.
  `git diff --check` is clean. No Web export or browser run was repeated after
  the dialogue fix.
- Current truth: obstruction ownership, marker-layer teardown race, Web role
  manifest inclusion, and native dialogue/input parsing are closed at this
  checkpoint. Browser acceptance remains open until the accumulated fix is
  tested once in a fresh source-aligned Web candidate. Broader visual debt,
  full-campaign proof, target-hardware performance, and production release
  remain blocked and are not being claimed as complete.
- Exact next action: after the next bounded source/native recovery slice is
  settled, perform exactly one fresh QA export and one Chrome/Edge acceptance
  run against that accumulated artifact. Do not add isolated telemetry or
  rebuild Web solely to inspect the current failure.
