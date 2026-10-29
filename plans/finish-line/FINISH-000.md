# FINISH-000 - Finished-Game Master

Date: 2026-10-19. Workspace: D:/Projects/AshenOath.
Branch: codex/masterpiece-rebuild.
Scope: finish and establish acceptance of the retained game, not replace it.

## Current Director Repair Roadmap - 2026-10-28

The approved ten-child roadmap supersedes the execution restrictions and
source-complete assumptions in the dated delivery record below. Mandatory user
acceptance remains **0/16**. Historical Recovery acceptance is a different contract.

**FINISH-014/SAFE-CONNECTOR-HANDOFF** is active following Rafa's Continue instruction.
Child 2 was pushed as `a587888` to development and main. Continue authorizes
the next child; it does not record user acceptance of earlier work.
PACK-CLOSURE was pushed as `8603d80` to development and main; deployment waiting
was explicitly withdrawn by Rafa. That instruction does not imply runtime acceptance.
Development was fast-forwarded from
`31a0906` to `2620ab869858a50b62a7829902fc99965b6fd72d`, preserving all seven cloud
commits, newer monster/character work and both pre-existing untracked directories.
Targeted isolated verification is authorized for each active child. Deliver via
development/main Git pushes and Vercel automatic deployment; confirm exact artifact
identity when requested; push completion is the delivery boundary under Rafa's latest
instruction. Label PUSHED / AWAITING RAFA, then stop before the next
child. No separate CLI deployment and no implied whole-game acceptance.

| Order | Child ticket | Current state |
| --- | --- | --- |
| 1 | FINISH-016/PACK-CLOSURE | Implemented, compiled, developer-verified, pushed 8603d80; awaiting Rafa |
| 2 | FINISH-001/RESPONSIVE-PREPARATION | Implemented/compiled, focused checks/partial browser coverage, pushed a587888; awaiting Rafa |
| 3 | FINISH-014/SAFE-CONNECTOR-HANDOFF | Implemented/compiled, targeted native and normal-input browser round trip pass; FINISH-014 push receipt owns delivery; awaiting Rafa |
| 4 | FINISH-003/ANIMATION-LIFECYCLE | Not started |
| 5 | FINISH-003/FACE-ARTIFACT | Not started; actor/geometry identification required |
| 6 | FINISH-007/SOLID-FURNITURE | Not started |
| 7 | FINISH-005/HONEST-TARGETING | Not started |
| 8 | FINISH-013/CONNECTOR-COMPOSITION | Not started; mesh identification required |
| 9 | FINISH-007/OPENING-PURPOSE | Not started |
| 10 | FINISH-008/WATER-AFTERMATH | Not started |

PACK-CLOSURE reproduces all ten reported missing environment textures from the
baseline `phase1-8c6264708df367f6` root/opening packs in an isolated scratch project.
OBJ material-library texture paths were included as source references without
their required texture import payloads. The new build-derived ledger selects the
32 required environment texture resources explicitly, with one pack owner, and
startup/Continue preflight validates their decoded leaves before parent materials.
Failure remains sticky until a new attempt and includes the resource in Retry.
No palette, lighting, character identity or source texture quality is changed.

Candidate `pack-closure-20261028-r2`: 32/32 isolated exported textures pass; focused
preflight/Retry, pack wait and integrity checks pass. Normal-input in-app Chromium
New Game (Balanced) and persisted-Quality reload/Continue pass without resource
errors. Complete package **162,869,651 bytes / 155.32 MiB**; Balanced opening
97,940,318 bytes, approximately **39.18 seconds transfer alone at 20 Mbps**.
Required restored assets increase download size; no startup improvement is claimed.
Final packaging restores three approved music resources byte-for-byte to HEAD after
the old split step overwrote them. Only their packs/root were re-exported; the first
candidate's checks are reused for unchanged texture, input and save dependencies.
See [bounded evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/pack_closure_20261028.json).

A separate existing paused-game Quality-switch overlay blockage was observed;
fresh persisted-Quality reload/Continue works. Its paused transition owner is
recorded for child 2. It is not passed, hidden, or repaired under child 1.

Child 2 source repair and package: `responsive-preparation-20261029-r2`,
**162,872,366 bytes / 155.33 MiB**. The paused Quality reload now completes back
to Settings and permits Resume without browser restart. The observed reload still
took about 48 seconds: the completion repair is not a speed/performance pass.
Prepared New Game paints acknowledgement before handoff; cancellation/repeated
input and interrupted UI preparation pass the focused fixture. The 100 ms budget,
controlled cold/warm timings and final reload/Continue remain unverified (browser
controller timed out). No full FINISH contract or user acceptance is closed.
See [child 2 evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/responsive_preparation_20261029.json).

Child 3 removes the assumed-height arrival success path. Destination support
must come from the destination root, and nearest-safe recovery is re-probed.
The source root/spatial owner survives until confirmation, including same-zone
replacement. Failed arrivals roll back without committing prepared story facts,
arrival objectives or unsupported saves; restored source support is checked too.
The two-second missing-support watchdog is failure containment, not a relaxation
of the retained 350/900 ms transition goals.

Focused native fixtures pass owned-floor rejection, delayed/re-probed support,
missing-destination rollback, same-zone rollback and save gating. All 14 physical
connector pairs pass isolated bidirectional strip support and gate contracts.
Eleven campaign destinations pass bounded construction/cancellation without
changing durable story. Six real native collision/build crossings around Greyfen
pass, including immediate returns. These fixtures are not an earned campaign or
normal-input browser proof. The construction fixture reports an ObjectDB shutdown
warning; sustained memory/performance and user acceptance remain open.

Candidate `safe-connector-20261029`: **162,875,328 bytes / 155.33 MiB** including
the release manifest. Base/root scripts were rebuilt; seven unchanged packs are
reused byte-for-byte. Package transport/decoded hashes and budget checks pass.
Normal mouse New Game and keyboard Greyfen -> Wychwood -> Greyfen pass in isolated
in-app Chromium, with no console warnings/errors. Browser log observations were
947.5 ms New Game handoff, 4,846.1 ms outward and 574.7 ms return: not controlled
reference-PC benchmarks, and not passing transition targets. All other pairs have
isolated geometry/gate evidence, not an earned browser traversal. Actual phone,
FPS, sustained memory and campaign acceptance remain open. No Vercel waiting.
See [child 3 evidence](../../outputs/AshenOathTheRoadBetweenCrowns/release_reports/safe_connector_20261029.json).

Existing strict startup/performance targets remain, including historical failures.
This child establishes resource closure, not performance acceptance. Unlocalized
faces/terrain, regional campaign coverage, actual-phone behavior and listening
remain open under their respective owners. Details and evidence are tracked in
the [cohesive-game record](../living-road/COHESIVE_GAME_IMPLEMENTATION.md).

## Historical Combined Execution - 2026-10-26

Approved plan: **Complete the Implementation and Publish Once**. Current candidate:
`finish-implementation-20261026`, preserved baseline `4b28d2d`. All project work
remains physically on D:; branch `codex/masterpiece-rebuild`.

All sixteen mandatory implementation contracts have been source-reconciled.
Concrete gaps are addressed in explicit zone construction, budgeted publication,
interaction registration, animation-clock restoration, dependency packaging and
production music. Previously implemented regional/gameplay work remains intact.
The broader facial source work already exists in eight assemblies plus Ranger;
it was retained rather than recreated. FINISH-017 finite oils remain implemented.

| Ticket | Owner | Current disposition |
| --- | --- | --- |
| FINISH-001 | Launch and menu | Source complete / runtime acceptance pending |
| FINISH-002 | Saves and recovery | Source complete / runtime acceptance pending |
| FINISH-003 | Movement, camera and character integrity | Source complete / runtime acceptance pending |
| FINISH-004 | Combat | Source complete / runtime acceptance pending |
| FINISH-005 | Desktop and phone usability | Source complete / runtime acceptance pending |
| FINISH-006 | Progression and economy | Source complete / runtime acceptance pending |
| FINISH-007 | Greyfen | Source complete / runtime acceptance pending |
| FINISH-008 | Wychwood | Source complete / runtime acceptance pending |
| FINISH-009 | Deep Woods | Source complete / runtime acceptance pending |
| FINISH-010 | Long Road | Source complete / runtime acceptance pending |
| FINISH-011 | Castle Vargan | Source complete / runtime acceptance pending |
| FINISH-012 | Hartlands | Source complete / runtime acceptance pending |
| FINISH-013 | Audiovisual | Source complete / runtime acceptance pending |
| FINISH-014 | Performance source pass | Source complete / runtime acceptance pending |
| FINISH-015 | Campaign | Source complete / runtime acceptance pending |
| FINISH-016 | Package and production | Source complete / runtime acceptance pending |

User acceptance remains **0/16** until the user supplies acceptance. This is not
a claim that implementation is absent. No agent game/browser run, automated test,
fixture, screenshot, benchmark or profiling is authorized or performed. Static
source/diff review, required asset/build compilation and package/HTTP delivery
safeguards are authorized. No further routine approval is required before delivery.

Keep strict HD620 1280x720 Balanced targets and historical red measurements. No
FPS, private-memory, startup or transition pass is claimed by compilation. The
production package ceiling is strictly below 268,435,456 bytes, warning at
209,715,200; individual Git files remain below 100 MiB.

Compilation and packaging completed for `finish-implementation-20261026`: all
eight runtime pack exports and the production Web export report no compiler or
parser error. Core game/construction/animation scripts also passed syntax-only
compilation without executing gameplay. Asset compilation produced the three
authorized arrangements and recorded prepared-scene animation dependencies.
Static diff review completed; no game/browser test, fixture or benchmark ran.

Complete deployment: **17 files / 107,723,136 bytes** (below 268,435,456).
Root transport SHA-256:
`4b665aa89688463c27925dd336dec2da522c211dc26209a7dd04f86446b68d33`.
Decoded artifact total: 146,942,222 bytes, not a runtime-memory measurement.
Balanced/Potato opening dependencies: 48,078,977 transport bytes; Quality:
55,297,878. At 20 Mbps, Balanced transfer alone still has a theoretical floor
of approximately 19.23 seconds; no 15-second cold-control or FPS/memory pass
is claimed. New arrangements stream as Vorbis; their original PCM masters remain
in source, and the forest tracks are adjacent-pack owned.

Package integrity/ownership/size/hash inspection passes. The final FINISH-016
publication receipt for this build owns actual commit, preview, staged production,
promotion and live identity; publication is not runtime or user acceptance.
One consolidated final user checklist: [USER_TESTING.md](USER_TESTING.md).

### Historical Execution Records

## Current Execution - 2026-10-25

The approved **From Accumulated Features to a Cohesive Game** plan now owns the
dependency order. Current source/evidence checkpoint:
[cohesive-game implementation](../living-road/COHESIVE_GAME_IMPLEMENTATION.md).
The direct zero-test/verification allocation remains in force for game QA: no
game/browser runs, fixtures, screenshots, benchmarks or profiling. The latest
direct instruction explicitly requires push/deployment without another user-run
step. Publish the accumulated r14 build through the existing Git-staged workflow,
retaining its package and HTTP delivery safeguards. Earlier holds on publication
are superseded by that direct instruction, not converted into accepted tickets.
Preserve all actual earlier results without repeating their gameplay checks.
Implementation, compilation, agent verification, publication and user acceptance
are separate. No new FINISH ticket is accepted by source edits or packaging.

Foundation work includes objective-history truth, scoped prepared-destination
invalidation, resumable campaign construction, route/Use visibility corrections,
deferred gameplay UI and browser save-durability acknowledgement. Directly affected
checks and outstanding browser acceptance are recorded in the linked checkpoint.
Strict numerical requirements remain open and currently red; the authorized
build-only delivery does not certify them. Rigid poses and remaining campaign,
phone, listening and subjective acceptance also remain unresolved/unverified.
The FINISH-016 publication receipt records delivery separately. The current package
policy is strictly below 256 MiB, warning at 200 MiB, individual Git files below
100 MiB; the old limits below describe their historical candidates only.

### Historical Execution and Candidate Records

2026-10-24 content amendment: [A Campaign Worth Remembering](../living-road/CAMPAIGN_WORTH_REMEMBERING.md)
adds six optional personal quests to the preserved 51, for 57 total. FINISH-002,
006-012 and 015 include the affected saved progress, rewards, regional scenes and
homecoming in their existing user checklists. No ticket is accepted merely by
this implementation; current build-only operation does not renew older agent
playthrough/benchmark allowances. Existing strict requirements remain unchanged.

Execution update - 2026-10-19: the user approved finite oils under FINISH-017 and
requested completion of the remaining finishing work, then one final agent
verification run and necessary corrections. No interim runtime tests. Publication
is explicitly held for the full release, not the oil change alone. The remaining
mandatory tickets are not already implemented/accepted merely because their cards
exist. Strict performance and actual-device requirements are unchanged; missing
proof cannot be converted to a pass by this testing authorization.

## Current Startup Candidate - 2026-10-21

The approved Faster Menu and Shorter Time to Play repair is implemented in the
preserved D: worktree. Current local candidate: startup-menu-20261021 at
D:/Projects/AshenOath/.release-gate/startup-menu-20261021/export. Menu handlers and
save summaries become usable before Greyfen preparation; the full world and real
camera draw still gate control. Selected Continue cancels unused Greyfen work.
See [FINISH-001](FINISH-001.md) for the focused implementation and user checklist.

Import/compilation, eight runtime-pack exports and the production Web export
completed. Complete directory including release_manifest.json: 104,691,963 bytes,
165,637 below 104,857,600. Root transport: 4,175,575 bytes (previously 6,579,567);
SHA-256 f8a2e1b5fc32b897a9cf11a946408f9b0c12dae01f4e21831cba063a9732ac41.
Source state: dirty worktree based on 9d4609b. Content/population/quality remain;
optional chapter artwork is retained in the campaign pack. No game/browser run,
benchmark, profiling or screenshots. Timing gains and runtime acceptance remain
unverified. No ticket is newly accepted; user acceptance remains 0/16.

User-only static preview: http://127.0.0.1:5466/ (Python PID 6644), serving this
candidate with its declared gzip headers. Logs:
D:/Temp/AshenOath/startup-menu-20261021/preview.*.log. No browser was launched or
HTTP/gameplay request made. This local origin has separate storage from production.
Publication is now explicitly authorized by the user's 2026-10-21 "push and
deploy" instruction. Publish these existing bytes through publish_living_road.ps1
under FINISH-001, without another build or runtime test. The publication receipt
under .release-gate/living-road records the resulting commit and deployment.
Runtime/user acceptance remains pending. Older authorization and delivery notes
below are history; they do not describe this new candidate's runtime acceptance.

## Active Execution Authorization - 2026-10-20

Latest delivery instruction: "push and deploy. now." Publication of the frozen
user-candidate is explicitly authorized despite pending user acceptance. No new
build or runtime test; do not reclassify strict performance or other unverified
conditions as accepted. Preserve the existing candidate and publication receipt.

### Superseding Build-Only Delivery Instruction

The user approved "Finish the Implementation, Then Publish Once": no more agent
gameplay, browser QA, benchmarks, profiling, screenshots or new test fixtures.
Source inspection/static diff review and minimum production compilation/package
generation are allowed. All runtime acceptance now belongs to the user. This
supersedes the historical per-run allocations below; do not ask for another run
or execute one. Strict performance, complete content, actual phone functionality,
save integrity and below-100-MiB packaging remain mandatory. No per-ticket push
or deployment. Publish once only after the user's required results/approval.

Current implementation candidate: finish-line-20261020-user-candidate,
under .release-gate/finish-line-20261020-user-candidate/export. Production compilation
and packaging completed successfully. Complete Web directory: 104,689,261 bytes,
168,339 bytes below the strict 104,857,600-byte cap. Root transport SHA-256:
1c020eebb38d27f48cc5eafe8f394c61bc2817a938f1f5dcc7087a1246d77385.
Decoded root SHA-256:
a10b7be5e8536043745604ea41161a69a189e93c5a1fdf1c00ab06c2bd44407f.
The manifest truthfully records dirty source at 2b1be253eb493991e5dc7d208d46694e6eb319d2;
this is not a new commit or deployment. Build logs remain in the candidate's logs/.
Startup changes cancel stale deferred callbacks, discard partial
worlds before Retry and complete navigation/render validation under cover.
Arrival finalization now happens before control, with one focused resource audit,
not a duplicate post-control pass. Retargeted-animation variants release only
unowned helper cache references. SaveManager's additive Continue record contains
the selected payload and its identity token in one atomic JSON write; missing or
older separate slot data can use that exact state without another journey being
substituted. Existing pointer-only records, slots, schema 13 and recovery remain.
Browser save messages disclose pending storage synchronization rather than
claiming force_fs_sync is a durable acknowledgement.

No performance gain or runtime pass is claimed for these changes. The rejected
dispatcher-lazy-loading experiment remains removed. FINISH-014's last valid red
baseline is not cleared by source edits; strict performance cause is unresolved.
Other existing systems are retained and their remaining runtime cells move to
the user's consolidated checklist, not to "accepted". User acceptance: 0/16.
See [user testing and release handoff](USER_TESTING.md). This current section
supersedes old next-action/authorization instructions retained below as history.
User-only local preview is available at http://127.0.0.1:9081/; the static file
server was started without launching a browser/game or making a QA request.
Helper/logs: D:/Temp/AshenOath/finish-line-20261020-user-preview/ (Python PID 13152).
This localhost origin does not contain production saves or prove phone support.

### Historical Run Authorization And Results (Superseded)

The user now authorizes one test/verification run for each remaining finish-line
ticket, repairs for observed failures, and one push/deployment when the full
release is ready. This supersedes the previous single-run allocation and the
setup-only ban on agent runtime checks. Existing content, strict numerical gates,
actual-device requirements and once-only final publication remain unchanged.
Agent verification and explicit user acceptance remain separate records.

Earlier packaged candidate: finish-line-20261020-prompt-verbs (104,688,170 complete
Web bytes; root transport SHA-256
162406d07f20f8af365762bd37b6220d6cbfa78ce4f20cc082fbd0540d206c35).
It includes the Anwen briefing, saved-encounter dependency, cemetery,
support-pickup clearance, menu focus and global-preference repairs. Targeted rechecks extend the
initial allocations; partial observations do not approve unobserved conditions.
No per-ticket publication.

### Historical Checkpoints (Superseded)

- Current objective/result: FINISH-014 replacement native recheck completed with
  explicit authorization. Corrected array error no longer occurs, but strict
  performance/readiness FAILED. Greyfen 26.27/15.87 FPS; peak private memory
  777.70 MiB; warm return 4,225.02 ms versus prior 330.95 ms. Dispatcher-only lazy
  loading candidate REJECTED; only the agent's two-file experiment was removed,
  restoring their exact pre-experiment source. Existing cumulative work and
  prompt-verbs package are intact. Full logs:
  D:/Temp/AshenOath/finish-014-replacement-20261020/. Replacement allocation used.
  Exact next action for further authorized work: shared resource-ownership/
  readiness analysis from existing evidence, not another dispatcher-only lazy
  experiment or an unchanged replay. No further run/export/publication started;
  strict red gates are not waived and no process remains. FINISH-001's persisted-
  Quality dependency cell passed in a62; the
  already-passed UI/growth/regional cells stay frozen. All four endings,
  Witness/Ash homecoming and the 30 added quests/18 secrets are now observed.
  FINISH-011's independent Castle route/regional cells are now observed. Independent
  Wychwood/Deep Woods/Long Road functional cells are frozen. The main earned
  profile now contains Ash's completed homecoming; genuine pre-choice saves remain.
- User acceptance remains 0/16. No whole ticket is promoted from partial evidence.
- Current Castle attempt is a45 on unchanged senn-entry bytes. a43/a44 retained
  the actual mile-marker/supply-cart objectives, then stopped on HARNESS written-
  record closing (two visible Close controls). The driver now selects only the
  focused single non-branching Close action; earned evidence is not replayed.
- a45 completed ledger/haunting/Edric, two Q parry attempts and peaceful Halvern,
  VAR-Q01-05, all three secrets, one Pommel and durable 100-XP settled return.
  No captured console errors/warnings. Overall FAIL: strict browser-private memory
  648.3 MiB. Freeze these functional cells; no whole-ticket/numerical acceptance.
  Next: normal earned Last Witness Continue, Assembly, Witness/homecoming,
  Hartlands work and existing genuine pre-choice ending branches on identical bytes.
- a46 reached Assembly then stopped on HARNESS requiring three non-consenting
  witnesses. Source correctly omits them and retains their written record. a47
  continues with consent/presence-aware ordinary interactions, unchanged bytes.
- a47 completed Assembly, Witness, all three covenant actions and the complete
  Anwen/workbench/road homecoming (nine epilogue cards). Its later Castle route
  query failed before movement. a48 walks the manifest's existing central bridge/
  east-road approach, resuming after the earned ending instead of replaying it.
  Hartlands work and alternate endings remain pending; no runtime/export change.
- a48 passed the authored Castle road, post-ending return, HAR-Q03/Q05 and HAR-S03,
  then entered Ruins. It exposed a real missing late-road mesh; the exact existing
  recipe is added and roads-only compilation passed. Replacement ruins-road package
  is building. A stale driver crossing list is replaced by the actual manifest's
  edges; continuation resumes in Ruins, not the completed ending/homecoming.
  The observed duplicate "Use Visit" prefix is repaired in the same package.
- ruins-road import/code packs/production export and lossless manifests completed
  successfully under the cap. Exact missing mesh generated (1,014 bytes, SHA-256
  f14dabf20f4555a632500c88708d7ba5239c786f56b9e2624a337bd137d25cd5).
  a49 is the current continuation from the earned Ruins save on those bytes.
- a49 completed HAR-Q01/Q02/Q04 and HAR-S01/S02, both Ruins/Glade directions and
  the return interaction, without captured console errors. All 30 new quests are
  earned; 16/18 secrets are recorded (Greyfen S02/S03 remain). At level 30/26,100 XP,
  the durable return ledger correctly credits zero; HARNESS wrongly demanded 100.
  Its cap-aware assertion preserves exact reward/delta/journey checks. Current
  a50-endings restores these green cells and uses the genuine pre-covenant save
  for Mercy/Duty/Ash, on unchanged ruins-road bytes. No numerical waiver/acceptance.
- a50 confirmed the cap-aware durable return. Its branch reload showed an
  interrupted auto-pointer/payload pair (09:43:50 vs 09:41:09), so Continue was
  unavailable with visible Recovery/Saved Journeys. FINISH-002 retains that
  unresolved boundary. The branch driver now uses the actual save-library flow,
  not an unrelated Continue prerequisite. Current a51 uses explicit same-journey
  recovery if needed and the genuine pre-choice Quick Save for the three endings.
- a51 completed Mercy and Duty with their actual three-step rituals/epilogues.
  Ash stopped before selection on an offscreen fourth choice. Current a52-ash
  checks only that branch; the driver uses real choice focus/scroll, requires
  on-screen geometry and then mouse activation. Same ruins-road bytes. Do not
  replay the two completed endings or treat focus handling as a game rebuild.
- a52 completed the actual three-phase Ash Hart fight, one Inlay and nine-card
  epilogue with no console errors/warnings; strict browser-memory FAIL 516.3 MiB.
  Current a53-greyfen follows Ash's actual homeward gate/homecoming, then GRE-S02/
  S03 and the settled return. GRE's five completed quests/GRE-S01 are skipped.
- a53 completed Ash homecoming, GRE-S02/S03 and the real Wychwood leave/return,
  with a durable 75-XP partial-cap award. No console errors/warnings; strict
  browser-memory FAIL 578.9 MiB. All new regional quest/secret cells are observed
  across earned checkpoints, not every alternative/legacy branch. Current a54
  is a fresh isolated 960x540 Chrome controls/camera/Save-Continue recheck of the
  original driver-blocked desktop cells. It does not replace actual-phone proof.
- a54 completed Chrome's 960x540 movement/pause/settings/reflow/F9/durable Save/
  reload/normal Continue/default-restoration cells, plus 11.37312-radian orbit,
  actual first person and visible textured-body return. No console errors/warnings;
  strict browser-memory FAIL 606 MiB. Current a55 Edge covers the same original
  driver-blocked compatibility scope on identical bytes; Firefox follows.
- a55 Edge completed its functional scope, no console errors/warnings; strict
  browser-memory FAIL 553.7 MiB. a56 Firefox passed start/movement/pause/resize/
  settings/F9 persistence and normal durable Continue, then hit a callback-only
  camera waiter in its polling transport. a57's enabled callback/probe experiment
  introduced realm-permission errors and is rejected. Current a58 uses the known-
  clean polling path consistently. a58 completed after 73,921 ms, with no captured
  console errors, but the camera driver again failed its angular-convergence gate:
  yaw 2.976585307 versus target -PI, player (0, 0.032743, 4.722781), controllable.
  All 36 input packets completed. The extra F9 Anwen/default-restoration cell is
  PARKED / HARNESS after two failed transport hypotheses. No game impossibility is
  inferred; the required Firefox startup/input/save smoke from a56 stays valid.
  Firefox's isolated QA preferences remain changed; its earned profile is retained.
- Review of existing a49/a53 captures exposed clipped primary objectives and route
  hints. The focused graphical tracker fixture reproduced the objective defect:
  2/4 visible lines at 1280x720 and 1920x1080. Caption-specific assertions passed;
  the overall fixture FAILED on the primary objective. The repair uses font/wrapped-
  line metrics and only schedules layout when primary reading text changes. It
  retains the full objective and separates route/work/footer regions. The first
  tracker-fit package is INVALID: its later direct script load caught a duplicate
  local variable; export/import alone had not diagnosed that lazy-loaded script.
  The name is corrected and an explicit HUD compilation step precedes packaging.
  A subsequent component check exposed omitted line-spacing/style-padding budget
  (3/4 objective lines visible despite sufficient bare glyph height). The shared
  text-height calculation now includes those metrics for objectives, captions,
  interaction prompts and status/hint spacing. Focused graphical recheck PASSED
  at 1280x720/1920x1080 and text scales 1.0/1.5. Retained warning: the existing
  non-equal menu anchors are resized by responsive layout; no parser/runtime error
  occurred in the passing run. Evidence:
  D:/Temp/AshenOath/finish-caption-20261020-spacing (compile.log/stdout.log/stderr.log).
  Corrected tracker-lines direct HUD compilation/code packs/production export and
  lossless manifest checks passed below the cap. No FPS improvement is claimed.
- a59-growth completed on tracker-lines using the main earned Greyfen
  profile/origin38495. It uses real journal/practice/shrine controls, verifies each
  changed autosave and matching pointer in IndexedDB, normal Continue without a
  recovery substitute, then earned respec/durable Continue. The pre-covenant Quick
  Save must retain unchanged parsed contents. No New Game, free XP/Marks,
  invented save or replayed quest is permitted. Driver-only scope uses existing
  route/menu/persistence helpers; no runtime observer or game API was added.
  All functional assertions passed: Keen Edge/Measured Riposte (17 -> 16 -> 15
  Marks), durable matching autosave/pointer and normal Continue, respec back to 17,
  second durable normal Continue. XP 26,100, health 62.9904, supplies, entitlements
  and genuine Quick Save stayed unchanged. No console errors/warnings. Overall
  FAIL remains the strict browser-private memory gate (566.1 MB); no waiver.
  This proves the controlled paired-durability boundary, not arbitrary forced-
  shutdown safety or the exact cause of a50's interrupted snapshot.
- a59's existing screenshot confirms full objective/route lines. It also exposed
  "Use Sit..." at the shrine. Static review of all seven authored village-place
  labels found omitted Sit at/Draw from/Buy prefixes. Those three are repaired
  together, preserving IDs/targeting/actions. Prompt-verbs compilation/packaging
  and lossless integrity checks passed below the cap; no new gameplay run solely
  for those strings. a60-quality used that artifact and the same earned
  profile/origin38495 for real preset selection, durable Quality reload/Continue,
  required material-pack/hero binding checks and restoration of the original preset.
- a60 failed before navigation: Chrome selected DevTools port 4045, which Node
  Fetch rejects as "bad port". Source inspection also confirmed the native
  WebSocket uses the same Fetch restriction. Existing loopback discovery now
  uses node:http; CDP uses already-installed ws 8.22.0, declared/pinned directly
  without upgrading the locked package. No browser security/game setting changed.
  a61 then really selected Quality, but its five-second UI acknowledgement wait
  expired during pack loading. The actual saved Quality state was preserved;
  the click was not replayed and no timeout was increased.
- a62 resumed that persisted Quality on unchanged prompt-verbs bytes and PASSED
  the functional scope: ready quality_materials, complete Kael/bindings, normal
  Continue, original Balanced restored durably, unrelated preferences and genuine
  pre-covenant Quick Save unchanged. No console errors/warnings; 39,706 ms total.
  Overall FAIL remains strict browser-private memory 515.5 MB. Capture confirms
  full objective/route text and "Sit at" without the redundant Use prefix.
  This does not claim Retry/cancellation, phone, all appearance/time permutations,
  strict timings/FPS/memory, listening or full ticket/user acceptance.
- Precise next action, once the pending performance authorization is answered:
  use existing native FPS/memory/frame evidence and source to select one bounded
  performance repair, then only the approved follow-up native measurement. Do not
  replay campaign/quality/growth smoke, rebuild unchanged bytes, lower strict
  targets, reduce content/quality or publish while red. Remaining recovery/legacy,
  preparation-cancellation/Retry and actual-device/listening cells stay explicit.
  No process is left running from these completed operations; earned profiles,
  raw failures, candidate bytes and cumulative worktree are preserved. No commit,
  push, merge or deployment occurred.
- Native FINISH-014 remains red/1 allocation consumed. Focused performance
  analysis/repair and one follow-up measurement was requested asynchronously;
  no approval or new native experiment has occurred. Actual phone still pending.
- Passed cells now frozen: exact durable Quick Save/reload/normal Continue and
  settings (a23); actual F9/Mira and original-preference restoration (a25);
  real crafting (a26), remedy purchases/price/consumption/healing (a28).
- a29 stopped on HARNESS routing across a retained rock toward WYC-Q02. The
  existing spatial route intentionally excludes live scenery. The read-only
  observer now refines blocked legs with actual capsule sweeps and bounded Godot
  A* detours; game movement, scenery, NPC navigation and story state are unchanged.
  The driver honors the physical route's corner tolerance instead of cutting
  corners or adding legacy prop-specific detours.
- Affected native proof passed: WestLane house/well, Wychwood rock, authored
  bridge, blocked sealed path, independent segment sweeps and unchanged player
  transform. Evidence: D:/Temp/AshenOath/finish-live-route-native-20261020.
- a30 passed WYC-Q02-05/all secrets. a31 proved the genuine Greyfen leave/return
  and durable 100-XP Wychwood return claim, earned last-bottle Moon Oil application,
  paused timer, countdown, durable reload/normal Continue (298.7773 seconds left),
  all register pages and Deep Woods/mill/farmstead traversal. These cells freeze.
- a31 stopped at Rootbound: 15 arrows consumed without damage. GAME defect:
  locked bow aim used visual bounds whose centre lies outside Rootbound's hurt
  capsule from that firing angle. Aim now uses the existing capsule centre and
  recomputes from the post-turn arrow origin. Damage, camera framing and balance
  are unchanged. Native old-miss/new-hit proof passed from three sides.
- The driver also now uses the actual arena invitation/name-board/root channels,
  with ordinary Oathfire and a real sword fallback instead of demanding free
  replacement arrows. Resume skips the already-earned reconstructed register.
- The bow-lock package compiled/packaged under the cap with matching manifests.
  a32 passed the actual name-board, arena invitation, two root channels, bow/
  Oathfire combat (Rootbound defeated in 19,015 ms) and Names publication. It then
  stopped on HARNESS demand for 20 arrows despite 15 carried and only 3 coin.
  Purchases now stay within actual funds; no game economy/ammunition changes.
- a33 passed affordable Tor purchases (18 arrows, 3 coin spent), physical mill
  arrival/inspection and one Ghoulkin kill. It stopped on HARNESS repeatedly
  requesting lock before approaching the remaining foe. The existing free-aim/
  approach attack helper now owns that leg instead of the outer lock-only loop.
- a34 passed the mill fight. Ashwing's acquisition then stopped outside the
  game's 12-metre lock range (13.5 metres away): HARNESS had no pre-lock approach.
  The driver now approaches/frames first; the same lock-only mistake is removed
  from remaining guard/haunting routines without changing game targeting rules.
- a35 passed the hauling-rope/perch action, then requested bow during Oathfire's
  equipment-restoration lock. HARNESS correction: reuse Rootbound's already-passed
  bow/Oathfire proof; equip bow directly for Ashwing instead of repeating that
  optional spell. No timing extensions, game input buffer or new export.
- a36 defeated Ashwing in 23,178 ms, secured the wage chest, opened the sluice and
  started the workers. It durably saved the active escort at progress 0.24127 and
  reloaded to Old Mill/control, but the opening-only HARNESS helper wrongly waited
  for Greyfen. Its restored live escort advanced normally while that wait expired.
- a37 then compared the restored state against a fresh post-load autosave rather
  than the selection that Continue loaded. HARNESS now freezes the actual selected
  save/pointer before the click, with timestamp/journey/progress checks; it does
  not relax time bounds or alter storage. Ongoing escorts do not trigger another
  unnecessary Save/reload test. The Continue helper accepts its expected zone.
- a38 completed the independent Deep Woods functional cells: selected-save escort
  Continue (saved 0.27953 / observed 0.62927 within elapsed active progress), both
  workers rescued, preserved mill choice, DEP-Q01-05, three secrets, retained
  Ash-Tempered fitting and durable 100-XP return claim. No captured console errors.
  Its final result is still FAIL: the existing strict browser memory check measured
  renderer-private memory 517.1 MiB against 450. This does not waive native strict
  failures or turn a partial route into full acceptance. Do not replay green work.
- a39 exposed a GAME route defect: Marsh arrivals at z=+/-13 were one metre from
  the opposite exit triggers (z=+/-14, radius 1.35). After 0.25 seconds the game
  automatically returned to the previous sector. Both authored arrivals now use
  +/-11; older saves inside an exit are latched until the player leaves that
  trigger, then deliberate returns work. No timeouts, routes or quest gates were
  weakened. Native exact-service checks passed all 19 arrivals, both old bounce
  cases, stationary arrivals and deliberate return re-entry; no full-world run.
- The marsh-arrivals package compiled below the cap. a40 ended after passing
  Farmstead -> Marsh -> Bandit Road, with Marsh arrival at
  z=11 and no bounce. It retained a genuine pre-duel save and reached the displayed
  challenge. GAME defect: Saga's ordinary no-combat guard rejected this encounter
  activation while Senn's two guards were alive; killing them would retire it.
- Only saga_senn_challenge now permits explicit activation during combat. Ordinary
  work remains blocked; reach, enabled/visible, loading/transition and quest checks
  remain. The filtered native availability check passed all those guard cases.
- a41 passed Senn's actual guard-break duel (7,109 ms, yielded alive at 22 health),
  explicit testimony and ROA-Q02. It stopped on HARNESS requiring focus at a retired
  Q02 clue used only as a signal-walk departure landmark; the game had already
  recorded left_work_area. Movement-only legs now stop on the actual game-owned
  condition, not focus. Normal Use still requires its displayed/validated target.
  Signal return also waits for its automatic proximity outcome; manual Hartland
  reinspection remains an ordinary focused Use.
- a42 completed ROA-Q01-05, three secrets, actual first-traveler handover and
  durable 100-XP return; exactly one Roadwarden's Baldric remained. It reused
  a41's duel/fate/Q02 and did not replay them. The final overall result remains
  FAIL on the strict browser memory gate (532.6 MiB); no console errors captured.
  Alternate Senn fates/stand-down and explicit user acceptance are not inferred.
- a43-castle is in flight on identical senn-entry bytes/profile/origin using
  --resume-earned soldier --through-last-witness --regional-saga var. It skips
  passed ROA work. Next: finish that authorized Castle/Halvern/VAR continuation,
  classify its actual result and continue only uncompleted conditions.
  Do not replay Wychwood or the consumed earned-oil check. Record only observed
  Rootbound/Names/Ash/Deep Woods results and continue their uncompleted conditions.
- Strict native FPS/memory/startup failures, actual-phone and remaining campaign/
  ending/legacy acceptance are unresolved. Publication remains held.

### Preserved Targeted History

Earlier next-action statements below are historical and superseded by the live
checkpoint above; the original observations and failed reports remain intact.

Current closure objective: FINISH-008 Wychwood, sharing the remaining FINISH-005
persisted-F9 execution and original-settings restoration. FINISH-002's exact
Quick Save/durable reload/normal Continue cell passed in a23. User acceptance
remains 0/16; agent
observations do not change that count. GRE-Q01 through GRE-Q05 and GRE-S01 have
completed through real input. The moved support pickup/carry/door checks passed
in a14; the wager and actual traveler escort/shelter handover also completed.
Parked regional red cell: HARNESS direct route from the bell to GRE-S02 intersects the
solid village well. The source-backed public-road detour retraces the bell's
already-crossed ingress; the known adjacent shop is also kept clear. Earned
secrets are now restored/skipped, not replayed. GRE-S02/03 and changed return
remain unobserved. Main campaign is at Teeth in the Rain; Bell/shrine complete.
FINISH-007's GRE-S02 proof is parked after two source-backed detour/convergence
corrections failed; a16 ended off the wall but unable to settle its clearance
point. No Game impossibility is inferred. Its unproven driver-only detour and
precision experiment are removed; passed quest/movement fixes remain. GRE-S03/
return remain pending, not approved or bypassed. Precise next action: existing
opening-save-continue scope with normal earned Continue (no New Game), durable
Quick Save/IndexedDB/reload/selected-source and actual restored-state checks,
then the independent Wychwood chapter/region.
Targeted a17-save resumed the earned journey and observed blocked pause movement,
real volume/subtitle/reduced-motion changes, resize and an F9 Interact remap.
It stopped on a HARNESS parent-navigation error: remap returns to Controls, not
directly to Pause. The driver now follows both Back actions. Its failure image
also exposed a GAME focus-visibility defect: reflow restored old scroll after
focus and left Customize Controls below the visible area. The HUD now reveals
the focused menu descendant after both restoration paths. Candidate
finish-line-20261020-menu-focus compiled/packaged successfully; no other game
content changed. All code-bearing packs align; unchanged asset packs reused.
Targeted a18-save stopped before modifying anything: ordinary Continue restored
the old journey snapshot's settings, replacing a17's newer global preferences.
Source confirms unconditional settings.restore_settings(data.settings) in the
journey loader. GAME repair: apply that embedded snapshot only without current
user preferences, and mark post-initialization preference edits as authoritative.
The normal first-launch platform defaults/legacy snapshot fallback remain.
Replacement finish-line-20261020-preferences compiled/packaged with matching
code-bearing packs and unchanged hash-checked asset packs. The temporary settings-
baseline resumption option is removed because a18 proves those changes were
actually overwritten; the next existing settings/save flow must reproduce the
changes to check the repaired owner. No settings or save files are injected.
Evidence: D:/Temp/AshenOath/finish-targeted-20261020-a17-save/browser.json and
D:/Temp/AshenOath/finish-targeted-20261020-a18-save/browser.json. Next: one targeted
earned Continue -> settings/F9 -> Quick Save -> durable IndexedDB -> reload ->
Continue -> exact earned state/preferences -> actual F9 -> restore preferences.
Targeted a19-save passed restored Controls focus visibility. It then stopped on
HARNESS rejection of the two identical Resume actions in Pause (list + pinned
footer); selector now permits those equivalent commands, retaining ambiguity
failures for unrelated actions. a20-save reused the same bytes and proved newer
volume/subtitle/reduced-motion persisted, but the final F9 remap did not. GAME
settings writer lacked the explicit Web filesystem sync used by SaveManager.
It now queues a coalesced deferred JavaScriptBridge.force_fs_sync after closing
the settings file. Candidate finish-line-20261020-settings-sync compiled/packaged.
The next run redoes only the missing remap, observes its durable IndexedDB record
before any save/reload, then continues the exact-save check. Passed scalar settings
changes/resize and earned quests are not replayed. Original a16 preferences remain
the restore baseline. The existing subtitle restore loop now covers its actual
five values, not an obsolete three-value bound. No per-ticket publication.
a21/a22 did not enter gameplay: Continue was disabled with Recovery visible.
a22 captured all durable save/settings/pointer records in one read-only batch.
The auto pointer records 05:37:18 UTC; the same-journey autosave is durably 05:35:26.
All five Greyfen quest completions and health remain in that autosave. Source
review of Godot's Web sync loop rejects the hypothesized lost dirty-flag race:
it clears the request before starting sync, not on callback. No engine patch.
The actual harness cleanup always force-killed Chrome, including runs stopped
immediately after a load/background write. It now requests normal Browser.close
and waits before scoped forced cleanup. a23 explicitly chooses the visible
same-journey primary Autosave recovery (recorded as recovery, not Continue proof),
then checks a fresh durable Quick Save/reload/normal Continue on unchanged
settings-sync bytes. No older/different journey is silently substituted.
F9's earlier loss is not established as a separate engine bug; the added explicit
settings sync is defensive, while the durable IndexedDB assertion is decisive.
No further diagnostic fields or engine redesign are needed for this boundary.
a23-save PASSED the exact durable Quick Save/reload/normal Continue cell:
journey 1792429317-53995, quick/primary, health 24.8704, exact position/objectives,
inventory/story, and changed volume/subtitle/reduced-motion/F9 preferences.
F9 reached IndexedDB before Quick Save. Warm reload-to-control 14,292 ms and
click-to-control 1,852 ms remain strict startup misses, not waived. No captured
runtime/resource/network errors. The run then failed HARNESS navigation to Anwen
near (-6.54,-4.85); no completed persistence check is repeated for that failure.
F9 remains active and original scalar preferences are not yet restored.
Current closure objective is FINISH-008 plus shared FINISH-005 F9 execution and
restoration during its required Mira conversation. a24-wychwood runs on identical
settings-sync bytes from normal earned Continue, no New Game/Greyfen quest replay.
It uses the existing original-settings baseline, source-aligned current supplies/
vendor UI and genuine crafting/purchases before Bog combat. Inventory traversal
uses its authored Tab chain instead of scrolling the reader with ArrowDown.
The direct `wyc` region selector now includes its five quests/secrets after Bog,
as the existing broader region selectors already did. No runtime source changed.
Remaining FINISH-002 legacy/death/corrupt cases and full ticket/user verdict
are still pending. Regional/ending/performance/phone prerequisites remain red.
a25-wychwood focused Mira with ordinary +0.35-radian camera framing, used the
persisted F9, completed her main briefing, and restored the exact original scalar
preferences/default bindings through normal UI. Both the remapped action and
Controls focus now have direct runtime observations. a26 restored that objective,
crafted one real Redroot Potion (2 redroot + 1 bitterleaf consumed), then stopped
on HARNESS Close lookup: the existing read-only list caps at 48 buttons and omitted
the long Preparation screen's Close controls. Source confirms Close is present.
No game/observer change or export: existing Escape/Back now closes inventory
through its normal reader/entries flow. a27-wychwood continues identical bytes,
restores the earned partial work, buys remaining healing normally and proceeds
to the chapter/region. Durable save/F9/default-restore evidence is frozen.
The existing UI driver follows real Control focus across sliders and handles
the two identical Back commands without accepting unrelated ambiguity. Report a14:
D:/Temp/AshenOath/finish-targeted-20261020-a14/browser.json. No New Game, no
completed-quest replay, no publication. Original strict performance failures
and actual-phone/user acceptance remain unresolved release requirements.

## Current Baseline

- Package commit: 2b1be253eb493991e5dc7d208d46694e6eb319d2.
- Build: world-saga-20261019-final. Publication receipt reports published_awaiting_user.
- [Committed release manifest](../../web/release_manifest.json) lists 16 artifacts,
  totaling 104,665,612 bytes. The recorded complete Web directory is 104,673,660
  bytes, including its release manifest; the strict cap is 104,857,600 bytes.
- Root transport PCK SHA-256:
  2ee5e7e496f0d8601b26a00d3f46684bad0b7a8273c970e34e7a4bd92895a195.
- The build manifest truthfully records source base d0a735f plus dirty changes.
  The package commit captures those changes; do not rewrite embedded provenance.
- [Publication receipt](../../.release-gate/living-road/WORLD-SAGA-000-20261019T121352Z/publication.json)
  records the actual package commit and Vercel outcome. This local ignored receipt
  may be absent in another checkout; committed bytes and manifest remain available.
- The original 21 quests plus 30 regional additions, six regions, 18 secrets,
  level 30, 17 Marks and 20 practices are implemented, not fully user-accepted.
- The [six-world implementation record](../six-worlds/IMPLEMENTATION.md) owns
  current expansion coverage. Old setup-only language in linked cards is historical.

## Completion And Ownership

The user performs all runtime testing and gives explicit ticket acceptance.
The agent authors and repairs within the active ticket, reviews source/diffs,
and runs only minimum builds/packages when later authorized implementation needs
them. Creating this package authorizes no repairs, builds, tests or publication.

Mandatory accepted count at setup: **0/16**. This is a new finishing acceptance
count, not a reset or replacement of any historical program's accepted count.
The master closes only after FINISH-001 through FINISH-016 are user-accepted.
FINISH-017 was deferred at setup; its design/implementation are now authorized,
but its runtime effect is not yet verified or accepted.
Master closure does not claim every originally proposed mechanic was delivered.

## Authoritative Acceptance Table

| Ticket | Outcome | Dependencies | User acceptance |
| --- | --- | --- | --- |
| [FINISH-001](FINISH-001.md) | Reliable launch and menu | Baseline | Pending |
| [FINISH-002](FINISH-002.md) | Durable saves and recovery | 001 | Pending |
| [FINISH-003](FINISH-003.md) | Movement, camera and character integrity | 001, 002 | Pending |
| [FINISH-004](FINISH-004.md) | Complete combat toolkit | 002, 003 | Pending |
| [FINISH-005](FINISH-005.md) | Desktop and phone usability | 001, 003 | Pending |
| [FINISH-006](FINISH-006.md) | Progression and economy | 002, 004 | Pending |
| [FINISH-007](FINISH-007.md) | Greyfen completion | 001-006 | Pending |
| [FINISH-008](FINISH-008.md) | Wychwood completion | 001-006 | Pending |
| [FINISH-009](FINISH-009.md) | Deep Woods completion | 001-006 | Pending |
| [FINISH-010](FINISH-010.md) | Long Road completion | 001-006 | Pending |
| [FINISH-011](FINISH-011.md) | Castle Vargan completion | 001-006 | Pending |
| [FINISH-012](FINISH-012.md) | Hartlands completion | 001-006 | Pending |
| [FINISH-013](FINISH-013.md) | Audiovisual finish | 003-005; shared regional observations | Pending |
| [FINISH-014](FINISH-014.md) | Strict reference-PC performance | 001-013 content stable | Pending |
| [FINISH-015](FINISH-015.md) | Complete campaign acceptance | 001-013; reuse earned regional journey | Pending |
| [FINISH-016](FINISH-016.md) | Exact-byte final package and production | 001-015 | Pending |
| [FINISH-017](FINISH-017.md) | Approved finite oils and fitting | 001, 002, 006; final verification | Implemented source; unverified; additional to 16 |

Regional ticket dependencies establish shared contracts, not a new player route
or a requirement to finish every optional task before changing region. Checks can
be gathered during the normal campaign and credited once to multiple tickets.
FINISH-015 and performance acceptance can aggregate in either order once their
own dependencies are satisfied; neither justifies replaying unchanged green cells.

## Retained Work And Repair Boundaries

- Keep all 51 quest IDs, existing actor/boss/save IDs, four endings, homecoming,
  A-set humans, Ranger Senn, actual White Hart, relationships and activities.
- Extend existing owners only for a demonstrated defect. Do not add another
  quest engine, save format, QA framework, coordinator or optimization program.
- Reuse [WORLD-SAGA](../six-worlds/README.md), [Living Road](../living-road/STATUS.md),
  [PLAYFIX](../../outputs/AshenOathTheRoadBetweenCrowns/PLAYTHROUGH_REPAIRS_STATUS.md)
  and [OPT](../../outputs/AshenOathTheRoadBetweenCrowns/PERFORMANCE_OPTIMIZATION_STATUS.md)
  at their actual proven dependency scope. Compilation and old screenshots do
  not approve current runtime behavior. Do not reopen unchanged accepted cells.
- Classify a reported failure as GAME, ARTIFACT, HARNESS, PERFORMANCE or EXTERNAL.
  Fix its owner only. A driver problem does not by itself justify game changes.
- No teleportation, manufactured flags, automatic healing or diagnostic bypass
  may supply required route, reward, save or ending acceptance.
- Project work stays on D:, scratch under D:/Temp/AshenOath; preserve unrelated
  work and rollback. No global TEMP/TMP or Codex history changes.

## Shared Acceptance And Evidence

Each ticket's status separates implementation, compilation, user acceptance and
publication. A missing observation is Pending, a demonstrated failure is Failed,
and an exact named prerequisite may be Blocked. None means Accepted.

Record in the ticket's existing delivery section: candidate/build and package
commit, platform/browser/device, quality and viewport, numbered checks performed,
expected versus observed behavior, relevant save/checkpoint and user's verdict.
Attach screenshots, timing output or logs only when they answer an acceptance
condition. Never place personal browser profiles or private save copies in Git.
An explicit user verdict is required to mark Accepted and update this table.

Runtime-content changes require a replacement candidate and affected rechecks.
Documentation or driver-only changes do not require new game bytes. Retain
unaffected approvals with their original scope. No new permutations for confidence.
One earned journey can cover regional, campaign, control, save and audio cells.

## Strict Performance And Release Rules

The prior functional-candidate numerical waiver is superseded for these finishing
tickets only. Historical functional-candidate reports stay truthful and unchanged.
[FINISH-014](FINISH-014.md) defines the restored reference-PC gates; absent current
measurements or numerical misses block its acceptance.

Keep intended visuals, population, routes and all quality choices. No forced
Potato preset, concealed late assembly or content deletion to meet FPS or payload.
Actual phones require functional acceptance; their numerical performance is
reported separately, not certified against desktop numbers. Unavailable physical
controllers remain explicitly untested, never implicitly supported by emulation.

FINISH-016 promotes the exact candidate accepted under this program after the
user approves final delivery. No per-ticket production publication is prescribed.
The entire deployable package must be strictly below 104,857,600 bytes; preserve
complete pack ownership, hashes and decoded/transport identities.

## Current Execution - 2026-10-20

The initial renewed authorization granted one verification allocation per ticket.
The user has now explicitly approved targeted rechecks from the preserved earned
save after driver repairs, without restarting the campaign or repeating passed
checks. This extends the exhausted allocation for affected checks only; it does
not waive strict performance or actual-device conditions. Production and tracked
web remain unchanged. No ticket is promoted from partial evidence to acceptance.

Completed standalone attempts: 001-015, the additional 017 unit contract, and
016's read-only package inspection. No graphical/browser operation remains in
flight. A replacement production package compiled for the Anwen repair; it is not
another runtime test. The isolated 006/017 progression/oil assertions and 013 native
PCM/state checks passed at their explicitly limited scope. 003 passed eight-way
locomotion/retained texture/orbit checks but hit a fixture interpolation-reset
defect. 004 exposed shared arrow/camera input ownership, now repaired; its stale
weapon-cycle expectations are corrected. 001 failed browser bootstrap before
navigation; that driver was repaired and boot worked in subsequent ticket runs.
002 decisively proved durable quick-save/settings storage but an invalid selected
Continue checkpoint; selection/sync ownership is repaired in source/package.
005 reached New Game/movement/pause in Chrome, Edge and Firefox, then stopped on
an obsolete settings-driver uniqueness/page-layout rule. Those corrections do not
constitute another run or a passing persistence/remapping/phone verdict.

014 is FAILED: 15.71/11.27 FPS in Greyfen, 21.89/6.30 in Wychwood combat,
828.54 MiB owned-process peak private commit, multiple cold transition misses.
Prepared handoff (704.18 ms) and warm return (330.95 ms) met those two limits only.
Keep the unchanged strict requirements; no general performance pass is claimed.
Its native session also found two real game faults: a missing lazy campaign
script property and an omitted compiled Hartlands/Ruins road. Both are repaired.
Source inspection additionally found ordinary post-ending Hart Glade resumes
wrongly triggering homecoming; the transfer is now ending-screen-owned only.

Candidate used by the completed final-browser allocations:
finish-line-20261020-final, production compilation complete,
104,678,748 complete Web bytes; root transport PCK SHA-256
15ae5520316202eaf40d36095d83572394617952c6a37ee4ab8b7e940f028dff.
Artifact directory: .release-gate/finish-line-20261020-final/export.
015 ended at the opening combat driver's deadline after four genuine enemy
deaths; no ending or optional regional acceptance was reached. Its report is
D:/Temp/AshenOath/finish-015-20261020/browser.json. Driver corrections confirm
Anwen's actual briefing and reacquire an approach-lost combat lock. No new export
is needed for these driver-only changes, and no second 015/New Game run starts.
Regional 008 and 007 attempts both stopped before Continue, with no played regional
content. Their new resume helper lacked the existing New Game foreground/focus
setup; failure capture unblocked rendering after each deadline. That HARNESS
precondition is corrected; do not label those invalid fixtures normal warm-start
measurements or successful regional checks. Previous failed attempts remain recorded.
009 then reached normal Continue on those bytes: menu 18,560 ms, control50,314 ms.
It stopped on a bad corpse-count assertion, although the one remaining brute
correctly proves the four prior waves stayed defeated. The builder intentionally
does not respawn dead waves. That assertion is corrected; no game change/export.
010 continued the unfinished wave normally, defeated the remaining brute in
9,874 ms and physically returned to Greyfen. The private report completed Road
of Crows and opened Bell Beneath Greyfen. It then hit a HARNESS follow-on-dialogue
assumption: a legitimate friendship conversation was treated as a failed click.
011 stopped on a HARNESS attempt to keyboard-focus dialogue's separate Close
control. Both are corrected in the driver, without changing game bytes.
Reports: D:/Temp/AshenOath/finish-010-20261020/browser.json and
D:/Temp/AshenOath/finish-011-20261020/browser.json.

012's final continuation reached normal Continue, bridge travel and Anwen on
the same bytes, profile and origin. Menu/control were 39,909/43,915 ms from
navigation; click-to-control was 3,798 ms. No console errors/warnings or failed
network responses were recorded. It stopped before the cemetery fight because
the driver assumed one Anwen use must complete meet_anwen_gate. Further source
inspection refined the initial HARNESS-only classification: an actual GAME fault
also exists. tutorial_flags.anwen_talked is not persisted and its first-talk branch
took precedence over the saved, completed Road quest after every browser restart.
The game now skips that obsolete tutorial branch once Road is completed, allowing
the active cemetery meeting to advance on the ordinary interaction. It neither
invents new quest credit nor changes the save format. The driver additionally
permits at most three genuine conversations for care/briefing/meeting checkpoints,
checking the actual objective after each; no mutation or larger timeout is used.
The game correction requires the new anwen candidate; the driver was syntax-
checked, not rerun. Original reports are preserved, not reclassified as passes.
Report: D:/Temp/AshenOath/finish-012-20261020/browser.json.

No regional new quest, regional secret, Bell-Eater, later boss, ending, homecoming
or earned-oil browser reload check was reached by these continuations. Do not
infer completion of 007-012/015/017 from their precondition attempts.
016's existing --check-existing inspection passed all recorded transport/decoded
hashes, sizes, release/pack identities and complete-directory budget. Evidence:
D:/Temp/AshenOath/finish-016-20261020/package_integrity.log. Publisher ticket-ID
validation now permits FINISH through the existing workflow; syntax parsing
passed without executing publication. This is package preparation, not production
acceptance, and no Web bytes were rebuilt for driver/publisher changes.
The intermediate routes export failed its transport-generation process (exit120)
and is NOT a candidate for testing or release. Unchanged asset packs are hash-
checked/reused; code-bearing packs and root are regenerated from frozen source.

Current source-aligned replacement: finish-line-20261020-anwen. Production
import/compilation/export and lossless transport packaging completed successfully.
Complete Web directory: 104,679,032 bytes (178,568 below the cap). Root transport
PCK SHA-256: adb4c801f909ed28974905c3cb96669b35201bf11f12dbe089b30acb2c8cc162.
Artifact directory: .release-gate/finish-line-20261020-anwen/export. The existing
manifest builder's integrity check passed on those bytes; logs are under its
logs directory. All four code-bearing packs were rebuilt; unchanged asset packs
were hash-checked and reused. No application/browser runtime test used this
replacement. Retain prior evidence only at unchanged dependency scope, not as a
passing recheck of the new Anwen condition or strict performance.

Formal user acceptance remains 0/16. Actual-phone operation, full regional and
ending coverage, listening/gameplay synchronization and all failed strict gates
are still open. References and precise outcomes belong to each card's Delivery
Record. No commit, push or deployment has occurred in this execution.

Targeted recheck a1 ended on the Anwen-fixed candidate. The repaired interaction
completed meet_anwen_gate; genuine grave inspections, cemetery ambush defeat
(10,034 ms) and chapel unlock passed. Navigation-to-menu/control: 34,082/38,396 ms,
click-to-control 4,128 ms; no recorded console errors/warnings or failed HTTP.
It then stopped on the driver's northward alignment from (16.54,10.25), directly
against the authored chapel south wall, not on a missing doorway. Source geometry
and the existing native west-aisle route identify this as HARNESS path selection.
The driver now clears the southwest corner/grave rows before using the west aisle,
and skips already-earned cemetery objectives on Continue. A related static review
corrected regional selection of retired offer/inspection points still exposed by
the read-only catalog. No game bytes or thresholds changed.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a1/browser.json.

Targeted a2 stopped on the cemetery approach again, now from a checkpoint beside
a headstone rather than the original post-unlock approach. More importantly, its
captured runtime errors exposed a GAME saved-encounter dependency failure:
BellEater_Playfix.glb was requested before the monster/character dependency packs
mounted during Greyfen Continue. A fresh journey had already downloaded those
packs on the Wychwood route, concealing this on the first encounter.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a2/browser.json.
Repair: the existing zone-pack APIs accept an optional encounter dependency list;
Game requests monsters for an unresolved saved Greyfen Bell chapter and carries
that same list through readiness/failure/generation-guarded waiting. Fresh Greyfen
menu/New Game does not acquire this extra dependency. Existing monster dependencies
also mount characters. No enemy fallback, save mutation or resource suppression.

After the two approach failures, waypoint experimentation is stopped. The existing
read-only observer's diag=1 mode now supplies one complete collision batch: actual
player shapes/margin, contacted bodies/normals/shape indices and nearby physical
shape transforms/extents. It is off during normal play; its observations cannot
approve performance. The next affected run can identify the exact owner instead
of guessing another coordinate. Candidate finish-line-20261020-encounter compiled
successfully for the saved-encounter fix plus this bounded diagnostic support.
Complete Web bytes: 104,682,227; root transport SHA-256
c8a7c3cbf61eca3bd895814622de607c934526dd6fc18dd1a42d2f7b16866ba6.
Four code-bearing packs/root rebuilt; unchanged asset packs hash-checked/reused.
One compiler correction selected the shape-index API rather than the shape-object
API; subsequent import/export/package succeeded. No runtime pass is inferred
from compilation. Prior candidates remain preserved.

Targeted a3 finished: saved Bell-Eater and its monster/character packs restored
without console/resource/network errors. The route stopped on a GAME clearance
pinch, not another waypoint-only failure. Actual shapes show the chapel south
wall ending at z=9.90 and the southeast headstone starting at z=10.45: a 0.55 m
gap for Kael's 0.64 m capsule. The complete nearby-shape snapshot is untruncated.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a3/browser.json.
The southeast decorative grave moves 1.2 m east, keeping its marker, collision
and authored soil together, retaining all graves/clues and the cemetery boundary.
Offline geometry from that actual snapshot reproduces the old blocker and finds
no capsule intersections on the repaired westward departure. This is source
proof, not browser acceptance. Only grave_earth was rebuilt (96 triangles,
4,645 bytes); its derivative hash/size is updated. The answered temporary
collision probe is removed before packaging. Precise next action: compile this
GAME repair once, then targeted Continue from the same earned profile/origin
through Bell-Eater and the still-unplayed regional/campaign conditions. No New
Game or replay of completed objectives. Mandatory user acceptance remains 0/16.
Candidate finish-line-20261020-cemetery compiled and packaged successfully:
104,678,963 complete Web bytes, root transport SHA-256
ec07f3fa55ec2725b09e8d23eda6757d2bb48bcb50f8d6be5cf8ad4454fb3f32.
Targeted a4 finished on this replacement. The repaired passage passed; Bell-Eater
was defeated through normal input in 27,575 ms with all four existing reward/
aftermath flags, no living summons, and no console warnings/errors or HTTP failures.
Menu/control were observed at 21,327/41,949 ms, not startup acceptance. The run
stopped on HARNESS shrine focus: its valid clear endpoint (14.16,7.87) stayed
outside the chapel's north pier. The existing native route aligns z=8.29 and
walks east through the doorway; the driver now performs that same physical
alignment and requires ordinary focus. Game bytes are unchanged and no export
is needed. Normal Continue preserves Bell's earned defeat; do not replay it.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a4/browser.json.
Precise next action: targeted remaining shrine/regional/campaign work on the
same finish-line-20261020-cemetery candidate and earned profile/origin.
Targeted a5 confirmed that doorway approach and ordinary shrine focus (1.13 m).
It stopped on HARNESS choice text: the route requested the pre-overhaul label
while the current authored Commit buttons were enabled. No runtime/HTTP errors.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a5/browser.json.
One static batch compared retained action types/quests/objectives/outcomes with
the pre-overhaul source, mapping 33 unambiguous renamed choices to their current
visible labels without changing expected outcomes or selecting button indices.
The same source reconciliation found peaceful endings now require three physical
covenant actions; the driver enacts those actual interactions and no longer asks
Duty to spawn an Ash-only combat avatar. No story/game bytes or guarantees change.
The next targeted recheck reuses the cemetery candidate and skips earned Bell.
Targeted a6 passed the normal shrine choice and saved the cleansed outcome,
advancing to Teeth in the Rain. Its first regional offer then reached correct
focus but the driver redundantly turned the camera before Use and opened Rook
instead; no regional quest was started. Classification: HARNESS input ownership,
not evidence of a broken regional action. The driver removes that post-focus
turn and requires the displayed target in two fresh, stopped observations before
pressing the actual Use key. Game bytes remain unchanged. Report:
D:/Temp/AshenOath/finish-targeted-20261020-a6/browser.json.
Targeted a7 confirms the corrected Use handoff: GRE-Q01 was accepted and
hear_shortfall completed via its own authored action. It stopped focusing the
first measure inspection, 0.34 m from its origin beside lr_gathering (0.61 m).
The existing close-prop physical-standing adjustment covered clues/herbs but
excluded story_activity and covenant targets; those types now use the same
ordinary step-back approach. No game focus rules, priorities or bytes change.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a7/browser.json.
Targeted a8 finished on the unchanged candidate. Its physical standing adjustment
recorded the decisive fact: inspection 1 was already the ordinary displayed
required target, but the driver walked away to force inspection 0 first and
reached the common table instead. No runtime errors. After the two navigation
approaches, the correction changes abstraction level: regional inspection groups
are unordered in the authored quest. The driver may use a displayed unfinished
sibling in the same active quest/objective, then still requires both saved seen
flags before advancing. It cannot accept another quest, completed inspection or
arbitrary target, and ordinary Use remains mandatory. No game bytes change.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a8/browser.json. Current closure
objective remains FINISH-007's required regional interaction/quest conditions;
shared campaign/system observations are credited only when actually reached.
Targeted a9 passed both measure inspections and both grain/ration inspections;
all four seen flags and both completed objectives are saved. It stopped at
settle_supply on a HARNESS Runtime read timeout, while the game observation
binding continued publishing; no console/runtime/resource errors were recorded.
The generic telemetry helper discarded a fresh queued binding on direct-read
failure, unlike freshTelemetry's existing fallback. It now accepts only that new
publication, without replaying inputs, increasing deadlines or using retained
state. Same candidate bytes; next recheck resumes settlement, not inspections.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a9/browser.json.
Targeted a10 preserved those earned inspection flags on Continue. No console/
resource errors; the generic fresh-publication fallback did not produce another
Runtime failure. The settlement approach instead overshot its route toward the
well (5.71 m from the target), with observed publication gaps up to 5.95 s. Source
inspection also found a failed physical standing adjustment was committed as a
new route endpoint without checking arrival. The driver now uses the already-
proven chapel braking/replanning mover for interaction legs and rejects an
unreached standing point unless its required ordinary focus was actually gained.
Regional local approaches have a finite 60-second driver watchdog, not a relaxed
game/startup/performance gate. No game bytes change. Report:
D:/Temp/AshenOath/finish-targeted-20261020-a10/browser.json.
Targeted a11 next resumes the same settlement on the cemetery candidate; if this
bounded navigation correction cannot reach it, park that exact HARNESS cell and
advance independent system/main-route checks rather than repeat waypoint guesses.
Targeted a11 exited before DevTools/game startup (Chrome code 0, empty stderr).
The owned profile process was then confirmed retired; a12 reused the same bytes.
a12 completed GRE-Q01 (public correction/receipt) and GRE-Q02 (posted warning/
working bell), plus GRE-Q03's two frame inspections and renewed-sill decision.
It stopped approaching the support pickup. The braking mover is retained on its
demonstrated quest completions. The regional extension of the older neighbor-
based 2.2 m standing offset is rejected: its only a12 use put the household letter
between Kael and the support. Clue/herb behavior stays unchanged. Small regional/
covenant approaches now stop 1.5 m from the work on the existing collision-safe
ingress segment, rather than standing on it or inventing an offset past another
activity. Ordinary focus/Use and all quest outcome assertions remain mandatory.
No Game changes/export. Report:
D:/Temp/AshenOath/finish-targeted-20261020-a12/browser.json.
Targeted a13 reached the revised standing point but still focused the Draughts
table, not the support pickup. No runtime errors. Its image/source identifies a
GAME staging conflict: timber site (6.2,10.5) is 0.82 m from barrel_board and
0.92 m from Edric's proclamation, among a letter and minigame furniture. The
work site now moves to (6.2,12.5), 2.34 m from the board and 2.01 m from the
proclamation, preserving all existing props and the same pickup/quest state.
The existing site's physical occupancy/same-bank fitter still applies. Only
GRE-Q03 uses this timber site. The a13 standoff policy is rejected/removed;
the proven braking mover and unordered-inspection handling are retained.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a13/browser.json.
The source-aligned work-clearance replacement compiled/packaged successfully:
104,679,074 complete Web bytes; root transport SHA-256
5acf339767cf41e624788373f7a3614fb4448ea77b2652c87dd07b6316a524c9.
Unchanged asset packs are hash-checked/reused. Targeted a14 is in flight; this
is not another export for a driver-only change. Compilation is not acceptance.
Targeted a14 completed GRE-Q03 (renewed), GRE-Q04 (voided wager/kettle returned)
and GRE-Q05 (store shelter, two actual travelers escorted, admission/supply work),
and earned GRE-S01. The support-site GAME fix is retained on its observed pickup,
carry and door/latch results. No runtime/resource/network errors were recorded.
It stopped at GRE-S02 on a HARNESS diagonal through village_well; Kael was alive,
grounded/on_wall, 5.28 m from the secret. Existing well/shop source bounds explain
the intersection. The driver retraces the already-proven public road, not another
game geometry change. The two remaining secrets/changed return are still pending.
Targeted a15 stopped at GRE-S02 again. Its recorded detour and final pose expose
the HARNESS corner-consumption cause: the follower treated a clearance waypoint
as reached at 0.72 m (and stopped driving within 0.38 m). It turned east before
the north-of-well/shop clearance was attained. Offline route math reproduces
that early acceptance from the actual report. Only this authored corner now
requires 0.10 m for movement, acceptance and no passed-plane shortcut. Other
already-proven open-route tolerances are unchanged. Candidate bytes unchanged.
Static review also makes the replanner's speaker callback read the actual final
route point after route creation, not its earlier empty-route snapshot.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a15/browser.json. Next: targeted
a16, completing only the two secrets/return before continuing unplayed work.
Targeted a16 failed to settle the 0.10 m corner (actual error 0.19 m, off-wall,
alive/controllable). This is unresolved HARNESS navigation proof, not another
demonstrated game collision. Parked and unproven detour/precision code removed;
all earned progress and reports remain. No further GRE-S02 iteration now.
The independent Save/Continue scope reuses its existing route and this genuine
reported journey. It now validates the actual reloaded Quick source/journey,
items/settings/flags/objectives/health/position against durable IndexedDB, not
just a successful button press. Static UI reconciliation found actual settings
sliders were omitted from the keyboard driver's focus model; it now follows the
existing read-only Control focus owner across them. No observer/API/export change.
Strict
performance still requires real implementation improvement and an authorized
affected measurement; no source change in this checkpoint is claimed to solve it.
Actual phone input/layout/persistence remain an external device observation.
Owned browser processes were retired; the earned profile and all evidence remain
on D:. No cleanup removed saves or unrelated work.

## Historical Checkpoint - Before 2026-10-20 Renewal

FINISH-017 source and production compilation/package are complete. The user
authorized one final run, then one replacement on exactly the same bytes after
the first attempt failed before engine startup. Both attempts are finished.

- Candidate: finish-line-20261019-oils, 104,677,679 complete Web bytes.
- Unchanged artifact fingerprint across attempts:
  74df2982e7471397321e8b60d3b80b9cfa4ec8294f577b2ee8b27f0d564d46cd.
- First attempt: HARNESS failure, local server omitted gzip encoding for the
  compressed engine script. Server fixed; production headers were already correct.
  Report: D:/Temp/AshenOath/finish-line-20261019-one-run/browser.json.
- Replacement: FAIL after 270,663 ms and 22 recorded route checkpoints. Real
  mouse New Game, keyboard travel, initial Anwen interaction, Wychwood clues,
  the five-enemy fight and return to Greyfen were observed. Kael's retained atlas
  was visible with valid bindings. No game-console errors/warnings or failed
  network responses were recorded in this observed portion.
- Stop: HARNESS-classified dialogue activation failure at Anwen's return report,
  with enabled Commit choices visible and no outcome applied. Deferred layout
  geometry and Commit-prefix matching are source-backed driver risks, not proof
  the game's choice handler is broken. The driver now waits for stable published
  geometry, normalizes the prefix and confirms each clicked page's outcome.
  This correction passed syntax compilation/static diff review; it was NOT rerun.
- Navigation-to-menu: 45,714.5 ms; navigation-to-control: 47,478 ms;
  click-to-control: 1,226 ms. These are local hardware Chrome observations, not
  controlled-network cold/warm acceptance. Minimum reported rolling averages:
  Greyfen 15.80 FPS / 10.81 FPS 1% low; Wychwood 16.29 / 10.93. Strict performance
  is not satisfied by these observations, nor is native private memory measured.
- Replacement report:
  D:/Temp/AshenOath/finish-line-20261019-replacement-run/browser.json.
  Failed-run earned saves/profile retained under
  D:/Temp/AshenOath/ashen-oath-web002-chrome-1792422191300. Owned run processes
  were retired by the driver's cleanup. No further run or re-export followed.

The timed-oil application/durable Continue check lies later in the route and
was NOT reached. It, all endings/homecoming, remaining regional branches,
actual-phone functionality and native strict performance/memory remain Pending.
Mandatory user acceptance stays 0/16. Production/tracked Web remain the baseline;
no commit, push or deployment occurred. Source and evidence are preserved on D:.

Precise next action: obtain renewed runtime verification authorization or the
user's observations for the corrected Anwen report activation, then the earned
oil/Save/Continue check and remaining finish-line conditions. Do not rerun now:
the explicitly approved replacement allocation is consumed. Driver-only changes
reuse the same candidate; they do not justify another export. Full publication
remains held until the mandatory finishing boundary is genuinely met.

## User Master Checklist

1. Follow the launch/shared-system checks, reporting concrete failures by ticket.
2. Gather regional and campaign observations in one earned journey where possible.
3. Approve actual reference-PC measurements and actual phone functional checks.
4. Review the completed table, oil limitation and final candidate before publication.

