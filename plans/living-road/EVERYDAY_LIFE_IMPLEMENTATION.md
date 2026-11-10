# Everyday Life, Lasting Consequences

## Delivery Contract

Continuation of the approved 24-feature RDR2 adaptation on
`codex/art-recovery-anwen`, from `6d14b36`. This record extends Living Road and
FINISH; it is not a new acceptance program. All six worlds, 57 quests, retained
character identities, choices, four endings and homecoming remain.

Source implementation and production packaging only. No agent game execution,
playthrough, browser QA, automated gameplay, screenshots or performance profiling.
User acceptance and performance compliance remain unverified. Publication is one
combined push to development and main; Vercel owns automatic deployment. No CLI
deployment and no waiting for Vercel are required by the current instruction.

## Implementation Ledger

The entries below describe source implementation, not observed gameplay.

| # | Addition | Existing owner and bounded behavior |
|---|---|---|
| 1 | Social intent | Existing dialogue offers greet, company, humor and work topics, with per-character replies and cooldowns. No repeatable relationship rewards. |
| 2 | Minor social repair | An apology clears recent crowding/weapon suspicion only after giving space and lowering weapons. Personal grievances remain authoritative. |
| 3 | Join exchanges | Capture the current finite exchange, invite Kael, resume remaining lines and record completion only after exposure. |
| 4 | Six relationships | Greyfen, Wychwood, Mill, Road, Castle and Ruins pair scenes follow retained earlier exchanges. Heard aftermath enables bounded afternoon shared work; absent participants are not manufactured. |
| 5 | Six reciprocal favors | Anwen, Mira, Tor, Nera, Nessa and Rook exchange an actual spare supply for a once-only keepsake and specific acknowledgement. No XP/Honor. |
| 6 | Source-bound rumors | Six region-specific accounts are recorded as testimony, with named sources. Existing completed investigations add findings without replacing the original claim. |
| 7 | Returning travelers | Rook, Nessa and Tor each have three finite encounters across their existing regional roles. Later lines require actual earlier exposure and applicable saved outcomes. |
| 8 | Three short outings | Mira's fallen stems, Rook's fastening and Nera's unloaded rope use existing navigation, safe separation, work poses and saved completed action. No teleport, leash or casualty timer. |
| 9 | Inspect possessions | Six permission-based, rotatable objects use a separate neutral object viewer. Closed/private contents remain closed; inspection does not transfer evidence or inventory. |
| 10 | Chosen reflections | Seven existing earned reflection entries permit a chosen personal note, uncertainty or leaving the page unwritten. No invented remorse or knowledge. |
| 11 | Three performances | Rook's short story, Tor's pin demonstration and a shared-table tune use the existing nonmodal scene owner. The tune reuses approved music, not fabricated speech. |
| 12 | Keepsake shelf | Six Greyfen slots display legitimately received gifts. Placement persists, prevents duplicate display and never consumes campaign evidence. |
| 13 | Weather routines | Existing day/night time derives clear/rain/clearing intervals. Actors use covered points from their own routes when available; no new clock or teleporting. |
| 14 | Visible travel wear | Private, removable overlays show wetness and lower-body dirt without modifying character texture bindings, combat effects or stats. Cleaning and active-time drying are cosmetic. |
| 15 | Ambient ecology | Existing ecology actors retain their population and animation owner, with near-player attentive behavior and bounded species-specific pose work. |
| 16 | Earned field observations | Viewing behavior for a short uninterrupted interval records an observation. Pressing Use alone does not grant a new field account; existing records remain. |
| 17 | Physical trails | Six three-mark trails are visible, inspectable in any order and recorded as optional observation. No detective overlay or sole-source campaign proof. |
| 18 | Safe time passing | Existing rest places support morning/evening waits. Movement/danger interrupts, time changes only at completion, and no free health/stamina refill is added. |
| 19 | Sound distraction | A single carried loose stone uses existing ballistics and perception. It does no damage; confirmed targets, bosses and committed attacks are not diverted. Saved active-time cooldown prevents reload spam. |
| 20 | Ordinary surrender | Whitelisted Wychwood ordinary bandits may offer surrender after a low-health stagger. Acceptance is separate from death, preserves once-only encounter XP and never resolves a boss or kill-required encounter. |
| 21 | Fishing | Three authored banks, a borrowed rod, two fish, float timing, line tension and cancellation. Combined fresh-fish capacity is six. No quest/Honor grant. |
| 22 | Resting meals | Three recipes consume real supplies at kitchens. Safe seated eating restores only listed missing health/stamina, once; no buffs, hunger, revival or combat eating. |
| 23 | Shop displays | Tor, Mira and Nessa's physical displays use existing unlocked stock definitions and existing shop transactions. Representative goods are not fictitious finite inventory. |
| 24 | Six regional meets | Three rounds of existing Three Marks, draughts, chess or physical archery. Increasing difficulty, saved board/range progress, two coin for first completion and two for first series victory. Ordinary prizes suppressed; rematches cannot duplicate rewards. |

## Ownership and Compatibility

- `StoryActivities/EverydayLife` coordinates optional presentation within the
  existing zone lifecycle. QuestManager, StoryState, Inventory, VendorService,
  DayNight, Presence, the animation driver and MinigameManager retain authority.
- New StoryState flags use `everyday_*`, `regional_meet:*`, `regional_range:*`
  and `ordinary_surrender:*` namespaces. Missing legacy fields start unearned.
- Fish buyback is one coin/common and two/uncommon, at most three combined per
  allowance. Refill requires both a later game day and 2,160 unpaused active-play
  seconds. Waiting, offline time, menus and loading do not replenish it.
- The global clock saves active-play time; vendor state saves its quota. Inventory
  transactions commit all consumption/recovery before emitting change signals.
- Optional scenes retain the existing finite scene-progress and knowledge rules.
  Rumor, trail, keepsake and ecology records are not new quest rewards.
- Ten original Blender props are separately exported into `leisure`; existing
  opening/campaign asset ownership is retained. No new full-resolution textures.
- Weather uses one nearby 40-instance rain batch and staggered roof probes.
  Wear updates one actor per half second and never replaces a foreign overlay.
  These are implementation budgets, not evidence of a measured performance gain.

## Build and Acceptance Record

- Blender source/export completed; an initial duplicate-fin-face warning was
  corrected in geometry and the build repeated without that warning.
- First Godot compilation found type/scope errors in new scripts. Corrected
  compiler-only retries passed. No game was launched to check the repairs.
- Production compilation/export: complete, build `everyday-life-20261106`.
  The two final script corrections were compiled and their base/root packs
  refreshed; unchanged actor/environment packs retain their checked identities.
- Isolated packed-resource inspection passed for 33 compiled actor scenes,
  with 32 intentionally omitted raw source scenes; no gameplay was executed.
- Exact local Web package integrity passed: 51 manifest-listed artifacts plus
  the release manifest, **205,967,595 bytes total (196.43 MiB)**. No budget warning;
  below 268,435,456 bytes. Largest deployed file: opening.pck, 69,633,840 bytes.
- Root transport SHA-256:
  `dad35df8f1f79d56f5c3d02f353ac42dcdf5c471d8ce0743f7f04e68ea1556ba`.
- Leisure pack: 268,126 transport bytes / 415,404 decoded bytes; optional,
  excluded from opening requirements. Total decoded artifacts: 254,018,407 bytes,
  **not process memory**.
- Balanced/Potato required download set: **122,114,174 bytes**, versus
  122,026,924 before: **+87,250 bytes (85.2 KiB)** of code/metadata/generated
  resource overhead. Initial-download neutrality was not achieved. The transfer
  floor at 20 Mbps is approximately 48.85 seconds before computation; this is
  arithmetic, not a measured startup result or performance pass.
- Local build helper metadata finalization initially failed after successful
  artifact generation; corrected the metadata/copy step without rebuilding again.
- Publication: candidate ready for the single combined development/main push.
  Do not infer successful Vercel deployment from this local build record.
- User observations: none for this candidate. No FINISH acceptance increment.
- Historical runtime failures and strict reference-PC targets remain unchanged.

## Startup Repair After Publication

The user reported repeated "Journey services could not be prepared" failures
after `cbef4e6` was pushed to development and main. A compiler-only invocation
reproduced a parse error in `combat_manager.gd`: the type of `previous`, obtained
through the dynamic zone-root property, could not be inferred. That prevented
the required combat service from loading. Retry alone could not repair code.
The earlier packaging pass did not explicitly compile every demand-loaded
service; its successful export was not proof that those services could load.

- Explicitly type the affected node. The compiler now accepts all 24 required
  registry services, without instantiating them or starting a journey.
- The existing release builder now runs registry-driven service compilation
  before exporting. This is a compiler gate, not a new gameplay test framework.
- Preserve valid services on Retry; replace only a failed script-cache entry.
  Report the affected service/resource in diagnostics and the loading error.
- Show the existing full-screen artwork/progress view during startup and quality
  re-preparation. Main-menu controls are not created until Greyfen, its gameplay
  camera render and the current save summaries are ready. Only explicit New Game
  or Continue starts play; readiness itself never starts a journey.
- Permit opening construction while this loading view owns the UI. Move the
  usable-menu timing event to actual readiness, retaining a separate loading-view
  timestamp. Percentages are phase-specific; unknown work is indeterminate.
- Reuse the Greyfen image and four chapter illustrations, changing roughly every
  eight seconds during resource/world preparation. Reduced motion removes fades.
  Move the existing atlas from campaign to the root pack, with no duplicate pack
  owner. Engine download still begins with the immediate Greyfen artwork.
- Retry remains the only loading-failure action. Long errors scroll independently
  so the Retry control stays reachable; repeated activation is guarded.

Candidate identity: `startup-loading-repair-20261106`. Export and package integrity
completed: **203,567,658 bytes total (194.14 MiB)**, no budget warnings. Root
transport SHA-256: `c8cf2d06e39ac109ebdf240ec163666b67559608be235cbb34250d1caac0c7d4`.
The Balanced initial dependency set is 122,117,577 bytes, +3,403 bytes versus the
preceding candidate. Exact identities belong to `web/release_manifest.json`.
Artwork is now explicitly available at boot; this repair makes no loading-speed
or performance-improvement claim. Character,
audio, material and leisure assets are unchanged. Saves and preferences are not
reset or migrated. No game/browser execution, screenshots or benchmarks were run.

User checks after Vercel receives the new push: reload; confirm artwork/progress
without menu buttons; wait for the menu; start New Game and selected Continue;
check quality re-preparation, short-screen Retry and reduced-motion behavior.
Runtime acceptance remains pending. A successful Git push is not a live browser
verification, and Vercel is not manually deployed or awaited.

## Authorized Startup Verification, 2026-11-06

The user authorized runtime testing after the loading report. Isolated profiles
and local HTTP origins preserve the user's production saves. This is a startup
repair, not acceptance of the entire Everyday Life backlog or performance gates.

- Published `9733c4c` was observed through the artwork screen. Browser control
  timed out while Greyfen was preparing; that observation alone did not prove a
  permanent hang. The tab was closed without starting or overwriting a journey.
- Existing native `verify_runtime_smoke` reached the menu and Greyfen, but the
  wrapper FAILED on an ObjectDB shutdown leak. Do not relabel that run a pass.
- The exact published package then completed Chrome New Game, ordinary movement,
  durable Quick Save, reload/Continue and replay-isolation checks. Its old harness
  reported PASS despite repeated missing `everyday_wear.gdshader` errors. That
  shader omission is a real packaging defect; the old aggregate pass is not a
  clean resource/runtime result.
- Explicitly export the shader and preload its shared binding. Strengthen the
  existing browser checker to reject engine `ERROR:` output. The corrected
  `startup-verified-20261106` package passed desktop and 960x540 touch-emulated
  loading/menu/New Game/movement/Save/reload/Continue with zero such errors.
  The observed menu times were about 67/72 seconds (desktop cold/reload) and
  76/72 seconds (touch cold/reload). These are functional-run observations, not
  controlled benchmarks; building overlapped part of this diagnostic session.
- The first graphics render accounts for much of the wait. Keep the complete
  world and final camera gate; do not claim the startup targets were met.
- The loading slideshow used accumulated frame delta, which loses elapsed time
  during long construction/render frames. Use monotonic elapsed time instead.
  This does not make a synchronous graphics stall disappear.

Evidence directory: `D:/Temp/AshenOath/startup-live-repair-20261106`.
`browser-baseline.json` retains the old errors; `browser-candidate.json` records
the clean desktop/touch checks. Final candidate: `startup-verified-r2-20261106`.

- `browser-final.json`: PASS, zero unexpected engine/browser errors. Real mouse
  New Game, optional introduction Skip, ordinary movement, durable Quick Save,
  page reload and normal Continue restored the earned journey/position. Loading
  actions stayed withheld; captured artwork changed from Greyfen to the village
  illustration and mill illustration while real download progress advanced.
  The first navigation deliberately delayed the opening response by 30 seconds
  to inspect the loading screen; its 132-second menu time is not an ordinary
  cold-load measurement. The subsequent reload took approximately 98 seconds,
  including 64 seconds in first-view preparation. No startup-performance pass.
- `browser-retry.json`: the touch-sized outage/recovery CASE passed. Two opening
  HTTP requests deliberately returned 503; Retry fetched again after restoration
  and real touch New Game reached playable Greyfen. The old aggregate filter
  incorrectly classified those exact injected errors as unexpected and returned
  FAIL. Preserve that report. Static review of its captured request/error/event
  records found exactly those two injected messages and no unexpected errors.
  The checker now exempts only that exact 503 message while that controlled fault
  is active, preserving rejection of all other runtime/resource errors. No game
  mutation, reload or fabricated save was used to rescue Retry.
- Compilation/export and exact package-integrity checks passed. Complete Web
  directory: **205,971,899 bytes (196.43 MiB)**, below 256 MiB and its 200 MiB
  warning. Largest file: opening pack, 69,633,850 bytes, below Git's 100 MiB cap.
  Root transport SHA-256:
  `7bd204d9db73ed5e52b9c7f1f4d394297678b84cad8910d65cfef7333183ed9d`.
- Static diff review passed with CR-at-EOL recognized; byte-preserved Web files
  intentionally retain their generated CRLF, not whitespace-normalized artifacts.

Scope limitations: native shutdown leak remains recorded; strict loading/FPS/
memory targets, actual iPhone/WebKit behavior and user acceptance are not passed
by these checks. No content/quality was removed. Publication is a Git push for
automatic Vercel deployment; no CLI deployment or live-verification claim.

## Startup Cost and Native Shutdown Repair, 2026-11-07

Scope: the user's authorized loading-time/shutdown repair, preserving all content,
materials, lights, presets, saves and complete-world readiness. This is not a new
campaign acceptance or a passing startup/performance certification.

### Retained Changes

- The Web shell narrowly rewrites Godot 4.6's generated fixed-capacity omni/spot
  light loops to `i < min(MAX_FORWARD_LIGHTS, light_count)`. The same lights are
  evaluated in the same order; no lighting feature, capacity, precision, material,
  texture, geometry or actor is removed. Unknown shader patterns stay untouched.
  This reduces observed ANGLE/D3D11 shader-program compilation/query time on the
  Intel HD 620. It is not a claim that all driver internals were inspected.
- Native Quit and the window-close handler now cancel preparation, allow its
  awaiting functions to resume, drain the existing renderer-safe zone retirement,
  finalize owned services/resources, then quit. A five-second retirement watchdog
  reports failure instead of silently declaring a clean shutdown. Shutdown is
  idempotent and cannot start another opening preparation.
- Existing browser/headless tools record the actual graphics device, optional
  startup WebGL timings, injected-versus-exported shader changes, first-control
  observations and production Quit behavior. No parallel gameplay framework.

### Checks and Their Limits

Evidence: `D:/Temp/AshenOath/startup-speed-20261106`.

| Local Chrome run, Intel HD 620 / ANGLE D3D11 | Cold menu | Reload menu | Cold first-view wait |
|---|---:|---:|---:|
| Published r2 baseline, profiled | 141.1 s | 115.5 s | 82.7 s |
| Same r2 bytes with candidate shader adapter injected | 58.7 s | 60.1 s | 33.2 s |
| Final exported candidate, profiled | 161.2 s | 71.0 s | 64.6 s |
| Final exported candidate, unprofiled | 145.3 s | 94.3 s | 61.2 s |
| Back-to-back unprofiled baseline | 131.3 s | 112.0 s | 87.7 s |
| Back-to-back unprofiled final candidate | 113.9 s | 108.3 s | 63.0 s |

All six runs passed New Game, normal movement, durable Quick Save, browser
reload and Continue with the exact earned journey/position. Final exported runs
used the packaged adapter, not injection; both reported 169 adapted shaders /
338 equivalent loops and zero unexpected runtime/resource errors. Loading kept
unready menu actions unavailable. Actual gameplay captures retain Greyfen's
houses, bridge, river, vegetation and characters. These are not pixel-identical
captures or actual-phone coverage.

The baseline spent 78.9 s in program-status queries; the injected candidate spent
31.1 s, and the final cold profiled run spent 59.6 s. The mechanism improves that
component, but overall cold-start improvement was not consistent across runs. Final cold
pack preparation took 54.1-67.9 s versus 13.6 s in the baseline. Host memory
pressure was observed, but it was not isolated as the sole cause. No builds or
other agent graphical workloads overlapped these browser comparisons. The final
unprofiled run reached observed first control at 195.1 s, including screenshots,
UI-driver waits and optional introduction Skip; this is not a handoff benchmark.
Its first 55 gameplay samples reported 14.92 average FPS / 10.70 FPS 1% low:
neither sustained-play evidence nor compliance with the retained performance gates.

To avoid relying on the best diagnostic result, the final old/new pair ran
sequentially without profiling, builds or other agent work. Cold menu improved
131.3 -> 113.9 s (13.3%); reload improved 112.0 -> 108.3 s (3.3%). Observed first
control improved 165.5 -> 125.3 s, including the same screenshot/input/Skip flow.
The short post-movement samples were 14.95/10.24 FPS average/1% low before and
15.01/11.06 after, with only 33/18 samples respectively; no sustained FPS claim.
This is a measured incremental improvement, **not a satisfactory loading-time
resolution**. Keep the original complaint open rather than claim 67-98 s is fixed.

- `quit-before.log` reproduced two leaked `GDScriptFunctionState` instances from
  `prepare_gameplay_services` / `_prepare_opening_services` when native Quit ran
  during preparation. Historical failure is retained.
- `quit-preparation/headless-results.json`: PASS, 7.2 s; actual cancellation/Quit
  path, verbose engine output, no ObjectDB leak warnings.
- `quit-playable-r2/headless-results.json`: PASS, 13.7 s; Quit after New Game,
  services released and retirement drained, no leak warnings. The preceding
  `quit-playable` run failed because the fixture awaited a non-awaiting forwarding
  wrapper; that HARNESS failure remains recorded. The corrected fixture awaits
  the actual session handler. OS window-close routes there but was not separately
  exercised by a graphical close gesture; browser unload is a different lifecycle.
- `tools/test_web_light_loops.mjs`: PASS for equivalent ordered light indices,
  unknown-shader preservation, receiver forwarding and idempotent installation.
- Required service/script compilation, Web export and exact package integrity:
  PASS. Asset packs without changed inputs retain their exact bytes. Examination
  of material and pack-buffer ownership did not justify unrelated asset changes.

### Delivery and Remaining Loading Work

Candidate: `startup-speed-20261107`. Complete deployment: **205,973,540 bytes
(196.43 MiB)**, below 256 MiB and its 200 MiB warning. Root transport SHA-256:
`98f5e4be64d1094cf3145270d122d6f8aaacb270a888079ab4e9ac61b7402355`.
Balanced opening dependencies: 124,523,465 compressed bytes; Quality: 131,748,020.
At 20 Mbps, Balanced transfer alone has an approximately 49.8-second theoretical
floor, before processing. This change does not reduce that download requirement.

Native shutdown repair is verified in the two stated cases. Loading is improved
at the shader-compilation component, **not fully resolved**: large opening
dependencies and remaining first-view compilation need further source-backed
work. No content deletion, covert quality reduction, longer timeout or premature
control was used to turn those requirements green. User acceptance, strict
loading/FPS/memory targets and actual-phone/WebKit behavior remain unverified or
unmet as described above. Publication is development/main Git push only; Vercel
deploys automatically and is not awaited or represented as live-verified.

## Startup Halving Follow-up, 2026-11-07

Scope: continue the 113.9-second complaint toward approximately 57 seconds,
without reducing content, materials, lighting, population or quality settings.
Evidence directory: `D:/Temp/AshenOath/startup-half`. Implementation and focused
verification are complete for the retained candidate; **the approximately
57-second cold-load objective is NOT consistently met**. Do not mark it accepted.

### Implementation

- The existing Web shader adapter now exposes the same std140 light/shadow UBO
  bytes through packed `uvec4` views. Block identities, sizes, strides, field
  precision, integer bits and matrix columns are preserved. Accessors recover
  float bits without changing light calculations. Only exact known schemas and
  simple known reads are adapted; unknown fields/precision/accesses retain the
  original block and all its reads. This avoids costly ANGLE compilation of
  dynamically indexed mixed-field struct arrays; no engine binary is replaced.
- Sole, empty definitions of a bounded list of unused generated stage flags are
  removed. A referenced flag, value-bearing definition or unknown shader remains
  intact. Captured sources had 149 distinct stages, 135 after unused instancing
  removal, and 118 after the retained bounded stage-flag cleanup. That is source
  deduplication evidence, not a prediction of seconds saved.
- Verified opening/actor packs can enter the engine filesystem when its shared
  `init()` promise completes, before `startGame()` finishes the root/project load.
  The separately downloaded opening pack no longer occupies a second prefetch
  queue slot. Two other consumers bound decoded buffers before initialization.
  Request sharing, hash checks, cancellation, Retry and complete first-camera
  readiness remain mandatory. Failed initialization cannot publish a pack.
- No native/GDScript or asset inputs changed. All existing runtime packs retain
  their bytes. The previous native shutdown implementation and its two passed
  Quit checks remain valid at unchanged dependency scope; they were not rerun.

### Checks and Attribution

- Source-shell metadata/shader checks: **24 tests passed**, covering early
  filesystem handoff, failed initialization, shared requests, metadata deadlines,
  cancellation, late callbacks, Retry, identity/hash rejection, unchanged ordered
  light evaluation and conservative shader fallbacks.
- `stage-flags.json`: Intel HD 620 / ANGLE D3D11 GPU comparison passed all
  **8,192 output words**, including five UBO families and all shadow-matrix
  columns. Four captured actual program pairs compiled successfully. Component
  compile times improved in this diagnostic, but these are not startup timings.
- A `vec4` rather than `uvec4` storage experiment passed layout checks but did
  not show a worthwhile compile advantage; it was reverted before packaging.
  A subsequent whole-struct accessor experiment also passed data equality but
  compiled slower in all four captured pairs (`struct-accessor.json`); it was
  reverted to the exact tested r4 shell, without exporting it.
- The browser startup harness now records visibility/focus and uses its existing
  focus-emulation approach for desktop as well as touch. An intervening diagnostic
  browser was actually hidden and suspended preparation. Its aborted 363.9-second
  run remains recorded as HARNESS-invalid, not deleted or used as a benchmark.
- Final comparisons use fresh isolated Chrome profiles, foreground emulation,
  no loading screenshots/profiling and one graphical workload, with no build or
  heavy repository operation during measurement. Menu and gameplay captures,
  actual input, movement, durable Save/reload/Continue and unexpected-error checks
  remain. These are local HTTP results, not throttled-internet or phone timings.

Earlier candidates were not treated as the final answer: injected shadow views
reached 47.6/45.6 seconds cold/reload, but actual r1 exports varied (115.1/79.9,
then foreground 80.4/48.8). R2 foreground was 81.3/56.5; its controlled pair was
**72.7/56.2 published baseline -> 61.9/56.1 r2**. R3's earlier filesystem handoff
passed New Game/movement/durable Continue but measured **62.3/65.6** and did not
establish the target. These results remain preserved; the best injected time is
not substituted for exported evidence. The original 113.9-second report predates
the foreground-harness correction, so that full difference cannot be attributed
solely to source changes.

### Final Exported Results

All three runs used the same `startup-half-r4-20261107` bytes, without injection:

| Report | Cold ready menu | Reload ready menu | Observed first control |
|---|---:|---:|---:|
| `browser-final-r4.json` | 73.4 s | 56.7 s | 94.6 s |
| `browser-final-r4-repeat.json` | 59.9 s | 61.1 s | 80.0 s |
| `browser-final-r4-confirm.json` | 68.6 s | 64.4 s | 99.4 s |

Median cold/reload: **68.6/61.1 seconds**. Cold is about 40% below the earlier
reported 113.9 seconds, but not a reliable halving, and the foreground harness
change prevents attributing that entire difference to game code. Against the
same-harness published baseline of 72.7 seconds, the final median is only about
5.7% lower; this is not a statistical confidence claim. The remaining first-view
wait was 33.0-35.6 seconds, while cold pack preparation varied 4.2-10.5 seconds.
Host free physical memory was about 680 MiB during one run; that observation
does not prove it is the sole cause. Further loading work remains necessary.

Each run passed withheld loading actions, real mouse New Game, complete opening
readiness, normal movement, durable Quick Save, reload and normal Continue of
the exact earned journey/position. No unexpected runtime/resource errors were
recorded. Inspected New Game capture shows Kael, village buildings, the bridge,
river, vegetation and required nearby characters. This is not pixel-identical
visual certification. First-control times above include menu screenshots,
normal input, optional introduction Skip and driver waits, not just the handoff.
Short post-movement samples remained about 14.9-15.0 FPS; neither sustained
performance nor the retained FPS targets are passed.

Compilation/export and exact package integrity passed. Complete deployment:
**205,979,994 bytes (196.44 MiB)**, including the release manifest. All **46**
pack/engine artifacts have identical sizes and hashes to the prior published
package. Root transport SHA-256:
`9e434a9550d880b138daf23591a23e8a6655f32910959a6454bfdaf70b5c35f0`.
Release-manifest SHA-256:
`c31563af2b597a4f188879c2a68cc21c3961116f499d0f6c33bf97fe1f7439a1`.
Source records truthfully retain generating commit `3c05bdf` plus dirty source;
the publication commit carries the shell changes and these exact artifacts.
Publication uses development/main Git push only; Vercel is not manually deployed,
awaited or claimed live-verified. No running test browser remains.

Initial required asset bytes were not reduced. Balanced's previous 124,523,465
compressed bytes imply approximately 49.8 seconds of transfer alone at 20 Mbps;
small HTML/metadata changes do not materially change that floor. The retained
15-second cold-control target is not passed by this repair. Actual-phone/WebKit,
sustained FPS, owned-process memory and user visual acceptance remain separate.

## Isolated Loading Follow-up: Verified Pack Ownership (2026-11-07)

Continuation is isolated at `D:/Temp/AshenOath/loading-resume-r4`, branch
`codex/loading-overlap-r5`, based on published `6aa8fdf`. The active
`D:/Projects/AshenOath` asset worktree has not been modified. Publication belongs
to the coordinated asset/package/loading integration, not this isolated branch.

### Retained Implementation

- The existing pack fetch path already owns a private, hash-verified ArrayBuffer.
  Stock Godot's exported JavaScript copied it again into MEMFS. The packaging
  adapter adds explicit, opt-in `takeOwnership` to `copyToFS`; verified pack
  callers use it only when the engine advertises the capability. Other callers
  still copy. The WASM engine, PCK bytes, scenes, materials and quality are unchanged.
- The adapter recognizes the actual exported glue boundaries, is idempotent,
  and rejects unknown or partially patched glue rather than advertising an
  ineffective capability. Existing engine content addressing gives the changed
  JavaScript a new immutable URL on the combined build.
- The opening pack is 73,978,140 decoded bytes. The actual-engine check proves
  its MEMFS view shares that verified buffer instead of allocating another full
  copy. This is an allocation result, not a measured reduction in peak process
  memory or a claim that the complete loading target passes.
- Candidate engine script transport is 78,425 bytes versus 78,364 previously
  (+61 bytes); decoded SHA-256 is
  `ec0a6458c912d4fc5f144b2d337b38e47161cf79a7bdd56cd9277837a7db4b94`.
  No final combined package or replacement Web manifest is produced here.

### Checks and Rejected Work

- `node --test tools/test_web_metadata.mjs tools/test_web_light_loops.mjs`:
  **26 passed**, including capability fallback, Retry, cancellation, metadata
  identity, unchanged shader-adapter behavior and late-callback isolation.
- `python -m unittest test_web_engine_owned_buffers -v`: **5 passed**. Actual
  engine syntax, explicit versus default copy semantics, unknown/partial glue
  rejection, lossless packaging and repeated-build identity are covered.
- `tools/test_web_pack_buffers.mjs` initializes the actual exported engine in an
  isolated headless Chrome profile with graphics disabled. It does not start the
  game. Test-only filesystem readback is injected in memory, never into packaged
  glue. It checks the complete opening pack, ordinary-copy isolation, owned-buffer
  identity and real Cache Storage round trips. Reports remain under
  `D:/Temp/AshenOath/loading-resume-evidence/`.
- Final retained-path report `owned-pack-buffers-final.json`: **PASS**, Chrome
  156.0.8078.80, no runtime/console errors. The complete 73,978,140-byte pack
  retained decoded SHA-256
  `80c1e03a6545cfaf0861b77af461be6639d0f17e157dd66532c83256270e291f`
  through both MEMFS and Cache Storage. Isolated copy/ownership operations took
  96.4/0.8 ms; the unchanged cache write took 7.39 seconds. These are component
  checks on a busy shared machine, not startup or performance acceptance.
- An initial browser check timed out (`owned-pack-buffers.json`); it is retained,
  not called a pass. Phase-level recheck passed the full byte-integrity boundary.
- A proposed bounded-stream cache write preserved bytes but was rejected:
  `owned-pack-buffers-cache-comparison.json` measured the existing Response write
  at 5.46 seconds versus 19.60 seconds for the stream on the same run. The original
  `new Response(payload)` cache path is retained. No stream optimization ships.
  The isolated filesystem operation in that run was 70.9 ms copying versus
  0.3 ms owned; these are not navigation-to-menu/control measurements.

### Integration and Remaining Requirement

1. Reconcile this commit with Game Assets and Package it better. The expected
   overlap is `tools/build_web_runtime_manifest.py`: retain both packaging work
   and its call to `enable_owned_pack_buffers` before engine hashing/compression.
2. Produce one source-aligned combined package through the existing build path.
   No asset or WASM replacement is needed specifically for this JavaScript change.
3. Verify cold/warm startup and normal New Game/Save/reload/Continue on those exact
   integrated bytes, with no competing build or graphical workload. No user save
   has been touched by this follow-up. Preserve the prior shutdown evidence at its
   unchanged dependency scope.
4. The last full-game median remains **68.6 seconds cold**, not the approximately
   57-second goal. First-view preparation was still 33.0-35.6 seconds. This small
   allocation repair does not resolve that renderer wait or establish the loading,
   FPS or memory targets. Do not publish a claim that loading is finished from
   the focused checks above. No independent push or deployment is performed.

## Combined Assets, Packaging and Loading, 2026-11-07 (In Progress)

The user now requests loading as close as practicable to 32 seconds, preserving
content and quality, combined testing, and one Git push for automatic Vercel
publication. This does not establish a new performance pass. The subsequent
Game Assets instruction also authorizes its remaining stages 2-4; those remain
isolated until complete and will be coordinated before final publication.

- Canonical D: integration `02d0341` includes opening-cast handoff `a17a484`,
  packaging `2d92060`, verified pack-buffer ownership `b898745`, and the harness
  timestamp correction `e11c776`. The four-person handoff is not the completed
  roster/campaign expansion; see its committed `STAGE1_HANDOFF.md`.
- `a185332` attempted to remove decoded Cache Storage writes. Immutable,
  content-addressed packs are eligible for browser HTTP caching. Existing
  Cache Storage entries remain readable and hash-validated; corrupt entries
  are removed and Retry uses HTTP `reload`. No saves/preferences are changed,
  and the 90-second pack watchdog is unchanged. All 29 shell metadata/cache
  cases pass, including legacy cache, failed storage, corrupt data and Retry.
  Browser cache behavior follows the documented Fetch cache modes:
  https://developer.mozilla.org/en-US/docs/Web/API/Request/cache
- The combined check below rejects this HTTP-only change: warm retention regressed.
  Verified persistent Cache Storage writes are restored without awaiting optional
  I/O; owned MEMFS buffer transfer remains. All 30 shell metadata/cache tests pass,
  including quota failure and verification-before-write. Chromium's
  Simple cache limits one ordinary entry to one eighth of its configured cache
  (minimum limit 5 MiB), so HTTP freshness headers alone do not guarantee that
  the roughly 70 MiB opening pack is retained. Source-only follow-up is tracing
  prepared tree dependencies and lossless smaller environment-pack ownership;
  no resource may be omitted while a mounted import still references it.
  https://raw.githubusercontent.com/chromium/chromium/main/net/disk_cache/simple/simple_backend_impl.cc
- The new unmodified published-baseline run failed its opening-pack deadline
  before preparation/control. Its recorded state is `opening_failed`, not a
  90.8-second menu pass. The driver then waited for New Game readiness and
  timed out. Preserve `D:/Temp/AshenOath/combined-release-20261107/baseline.json`;
  it cannot establish a startup gain or an asset failure. No user save was used.
- The first combined build compiled services and generated audio, geometry,
  work props, native life clips and prepared actors, then exposed an existing
  animation-loop variable overwriting the export preset path. Fix `dfb1975`
  names the destination `presets_path`. Failure logs remain under
  `.release-gate/combined-loading-cast-20261107`. The retry uses the existing
  `CharacterAssetsOnly` route to reuse successful audio/world generation.
- Combined build `.release-gate/combined-loading-cast-r2-20261107`, source
  `dfb1975`, compiled/exported successfully; prepared-actor package check passed
  (33 compiled scenes, 32 omitted source scenes). Generated source changes remain
  recorded, not falsely attributed solely to the clean commit.
- The combined desktop browser run passed withheld loading actions, real-mouse
  New Game, ordinary movement, Save, reload and selected Continue. It did NOT pass
  the loading goal: cold menu/control 121.982/132.667 seconds, warm menu 100.270
  seconds. First-view preparation alone was 60.538/57.340 seconds, with 169 shaders.
  Report: `D:/Temp/AshenOath/combined-release-20261107/candidate-r2.json`.
- A quiet matched check of the unchanged published build passed the same flow:
  cold menu/control 101.257/114.996 seconds, warm menu 104.055 seconds; first-view
  57.813/57.613 seconds and the same 169 shaders. This does not establish a Stage 1
  shader regression or an overall improvement. Report: `baseline-quiet-r2.json`
  in the same evidence directory. Previous faster measurements remain historical.
- The HTTP-only candidate transferred 114,835,210 bytes on warm navigation versus
  the published baseline's 16,970,942 bytes. The opening pack and most actor packs
  were redownloaded. This is the measured reason for restoring persistent caching;
  headers and component-copy timing alone were insufficient evidence.
- The combined native Quit check FAILED despite its functional smoke PASS: 14
  plain RefCounted instances remained at shutdown. No GDScriptFunctionState leak
  was reported. Evidence: `quit-playable-r2/headless/verify_runtime_smoke.*.log` in
  the same evidence directory. Game Assets owns focused teardown attribution;
  isolated 14-driver checks have not reproduced the full-game leak. Do not claim
  the old shutdown pass covers the changed actor lifecycle.
- Exact prepared-tree compiler `f7da212` passed for CommonTree_5, TwistedTree_2
  and TwistedTree_4: original geometry/UVs/normals/bounds and effective runtime
  bark/leaf materials retained. Three standalone resources and their dependency
  catalog are generated locally. Obsolete source import materials no longer
  have to decode before being replaced by the existing runtime materials.
- Follow-up `63432e6`/`d89fce9` retires four unused house-kit export roots while
  retaining all authoring files and the four baked Greyfen houses. Six focused
  packaging assertions passed in the packaging chat. The combined environment
  catalog and actual transport savings still require regeneration/export.
- A direct SceneData vertex-UBO accessor experiment was rejected: four captured
  shader programs compiled, but timings were 855/913/966/811 ms baseline versus
  885/870/967/830 ms candidate. No meaningful improvement; the experimental
  shader change was removed. Report: `scene-ubo-direct.json` in the combined
  evidence directory. No lower-quality material substitution was retained.
- Full-game ID tracing initially exposed a diagnostic freed-object type-check
  error (`quit-ids-r3`). Corrected tracing completed cleanly (`quit-ids-r4`,
  49.9 seconds), but invoked lazy Script-valued getters and changed timing.
  This is not a shutdown fix or a clean uninstrumented result. The probe now
  skips Script-valued properties; no speculative animation cleanup was applied.
- Source review found a separate real ownership omission: failed threaded
  requests were erased without consuming their engine token, and loading-art
  requests had no pending-exit cleanup. Failed requests now collect their result
  once; loading artwork uses the existing shared request registry and releases
  its claim on exit. Focused native failure/retry and final uninstrumented Quit
  checks are pending, so the earlier 14-object leak remains unattributed.
  Engine contract inspected:
  https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_loader.cpp
- Cache tests: all 30 passed again after making the cache-hit no-rewrite
  assertion explicit outside the optional-cache error handler.
- The failed-request ownership check passed: a deliberately invalid resource's
  failed engine token was consumed, repeated polling stayed stable, and a
  corrected resource at the same path loaded on Retry. Intentional parser
  errors are bracketed in `failed-request.log`; no shutdown leak was emitted.
  The normal role-prewarm fixture also passed (4.2 seconds).
- Uninstrumented full-game Quit `quit-untraced-r5` still FAILED shutdown
  ownership after functional PASS (37.4 seconds): one plain RefCounted instance
  remained with reference count zero. The failure/retry fix is real but does
  not establish the cause or resolution of this error-free startup/quit leak.
  A narrow shared-request claim trace, without actor property traversal, is
  the next diagnostic; no unsafe forced ObjectDB cleanup is authorized.
- Narrow request tracing `quit-claims-r6` completed functional PASS in 43.6
  seconds, but shutdown FAILED with seven plain RefCounted instances at count
  zero. All 31 observed production request paths were consumed (raw engine
  status INVALID) after Quit. This excludes an outstanding shared-registry
  user claim in that run; it does not identify the anonymous objects. Preserve
  the failure rather than treating added diagnostic delay as a fix.
- The combined environment catalog regenerated successfully (31 textures).
  The three prepared trees and four retired source house roots are represented
  by 45 export presets. No final transport savings have been measured yet.
- Existing startup browser runs used an isolated incognito context. Chromium
  does not give off-the-record contexts its persistent GPU shader-cache handle.
  Keep those results intact; an opt-in fresh temporary normal-profile startup
  comparison is added to the existing driver, with its context recorded.
  It must not use the user's browser profile or reinterpret incognito results
  as normal-profile warm-cache evidence. Syntax check passed; this mode has not
  yet been exercised. Engine cache behavior source:
  https://chromium.googlesource.com/chromium/src/+/b9cf8b6a08a7aa1c8c82d69e076a4f4fd4a99c34%5E%21/
- Fresh normal-profile published-baseline check `baseline-normal-profile-r7`
  PASSED real New Game, movement, Save, reload and exact selected Continue.
  Cold menu/control: 111.988/121.696 seconds; warm menu: 101.527 seconds.
  First-view time remained 59.993/56.742 seconds, despite warm transfer falling
  from 124,486,990 to 7,588,360 bytes. Therefore normal-profile cache behavior
  did not resolve the shader/render preparation stall. Preserve the original
  incognito comparison; neither result establishes the 32-second aim.
- Source-only engine review confirms a possible token-deletion race in pinned
  Godot 4.6.3: a loaded result can be collected before the worker's final
  unchecked unreference. The public loader API exposes no task-join handle.
  This matches count-zero leaked objects but does not prove their identities.
  No arbitrary timing delay, forced object deletion, engine replacement or
  warning suppression has been retained as a supposed repair.
- Packaging follow-up `f01daa8` retires the unused CommonTree_1 export root,
  keeping its authoring file and all currently required texture selections.
  Five focused policy tests passed in the packaging chat; final regenerated
  dependency closure must still confirm no retained asset references it.
- Final stages 2-4, first-view loading reduction, final combined inspection and
  publication remain in progress. No push has occurred here. Game Assets owns
  the serial bake workload; no overlapping graphical/build work is launched.

The corrected startup driver omits pre-control screenshots when requested and
records the authoritative first-control timestamp separately from observer lag,
driver click delay and the optional introduction. This changes measurement, not
the game. Package savings and theoretical transfer floors must be reported
separately from actual loading. Do not silently relabel prior 68.6-second evidence
as satisfying the current 32-second aim.

## Atomic Pause Checkpoint: 2026-11-07 08:51 MYT

State: PAUSED by Rafa through Liz. No automatic continuation, build, test,
export, push or deployment. Resume only when Rafa explicitly tells Liz to
continue. The earlier continue-to-completion instruction is superseded.

- Canonical checkout: `D:/Projects/AshenOath`, branch
  `codex/art-recovery-anwen`, HEAD `70094e2` (17 commits ahead of the last fetched
  remote tracking ref; no new remote comparison was performed for this pause).
  Nothing from this combined release has been pushed. Existing live Web bytes
  remain unchanged.
- Completed local source checkpoints: `b9079c8` failed-resource/artwork claim
  ownership, focused failure/retry coverage and optional teardown/profile
  diagnostics; `70094e2` merges `f01daa8` CommonTree_1 export retirement.
  Earlier exact prepared-tree and four house-root cleanup commits remain.
- Latest completed browser run is the unchanged published baseline, not a new
  candidate: `D:/Temp/AshenOath/combined-release-20261107/baseline-normal-profile-r7.json`.
  Functional PASS including earned Save/reload/selected Continue. Cold control
  121.696 seconds, cold/warm menu 111.988/101.527 seconds. First view
  59.993/56.742 seconds. The 32-second objective remains unachieved.
- Latest combined exported candidate remains
  `.release-gate/combined-loading-cast-r2-20261107`; it predates the retained
  cache restoration, environment cleanup and pending asset stages 2-4.
  Do not publish or relabel it as the final combined build. Its functional
  browser run passed, but cold control was 132.667 seconds.
- Shutdown remains unresolved: `quit-untraced-r5` failed with one anonymous
  count-zero RefCounted; `quit-claims-r6` failed with seven despite all 31
  shared-request paths being consumed. Focused failed-resource Retry and normal
  role-prewarm passed. Do not repeat the rejected shader-UBO experiment, call
  diagnostic-delay passes a fix, or suppress engine warnings.
- Preserved generated modifications: 13 prepared character SCNs, prepared Rook
  satchel and compile receipt, prepared-actor/environment catalogs, export
  presets, runtime pack manifests, stage-1 coverage/file receipts. Preserved
  untracked additions: three exact forest-tree RES files and
  `data/prepared_forest_trees.json`. This record has uncommitted evidence and
  pause updates. Unrelated historical untracked art/build files remain intact.
- CommonTree_1 source retirement is merged, but its final environment catalog
  regeneration and closure check have NOT run. The current generated catalog
  has 31 textures from the previous cleanup. No new byte-saving claim is made.
- Game Assets chat `01a1952c-b1b6-7562-a1fc-93da37e94a08` owns the unfinished
  stage-2/3/4 handoff in `D:/Temp/AO_LivingCast_Stages234` and
  `D:/Temp/AO_LivingCampaign_20261107`. Latest reported root source checkpoint
  was `f104f03`; it is not the final handoff. It has ordered all three workers
  to pause at safe write boundaries. Consult its final pause checkpoint before
  merging. Keep its final acceptance gates, including prepared-companion
  equivalence and expansion outcome behavior, visible.
  Pause acknowledgement: all three workers are stopped and changes preserved.
  Nessa's latest source animation is newer than its compiled library; inspect
  that recorded mismatch and rebuild it before any release after resumption.
  Final asset checkpoint:
  `D:/Temp/AO_LivingCast_Stages234/.release-gate/stages234/PAUSED_2026-11-07.md`.
  Shared HEAD `f104f03227f7d893861ce3af13e027397df4d44b`, index empty;
  campaign HEAD `a0231ddf39ca695fa1b4fa1368161381cb806250`, preserving 21
  modified and two new files, untested/uncommitted. C11 source is newer than
  `life_C11.res`; C05 still has a known clearance defect; generated campaign
  overlay/localization are stale. No publishable asset candidate exists yet.
  The asset owner confirms no engine, inference, browser/server or worker
  session remains; its last Blender operation completed normally (exit 0).
- Packaging handoff worktree: `D:/Temp/AO_TreePackage_20261107`. Its source
  changes are merged; it is instructed to remain paused. Bundle retained at
  `.release-gate/common-tree-1-retirement.bundle` in that worktree, SHA-256
  `67686ffa264a0bb33eb003993b78f4bab5e61f7f2fd9b1c56d8897a3bb17777e`.
  Packaging confirms paused with no owned running process or unsaved source
  work requiring attention.
  Liz's subsequent coordination update confirms the AshenOath tasks have been
  notified of the pause. Packaging integration remains pending: the source
  handoff is merged, but regenerated dependency closure and final combined
  artifact integration/build are unfinished. Preserve the handoff; do not
  restart packaging or integration until Rafa explicitly tells Liz to continue.
- Owned process state: browser r7 and its local HTTP server exited; native r6
  exited; no owned build/export/engine remains. The outstanding compact chat
  wait was interrupted. Filtered process inventory found only the inventory
  command itself, not a matching game/browser/build worker. Other chats own
  their final worker acknowledgements; no unrelated app was terminated.

Precise resumption order, only after explicit continuation:

1. Read Game Assets' final paused checkpoint, preserve its uncommitted state,
   and agree the next single heavy-work slot. Do not restart passed checks or
   assume its intermediate root checkpoint is the complete asset delivery.
2. At the next assigned slot, complete CommonTree_1 closure with the existing
   layout generator (`--defer-environment --require-prepared-forest`),
   `tools/build_environment_dependencies.gd`, then the layout generator with
   `--require-prepared-forest`. Keep all retained dependency failures fatal.
3. Continue the bounded loading/shutdown work from the evidence above; no
   proven first-view improvement or complete leak fix exists yet. Asset-stage
   completion proceeds with its current owners, not a duplicate implementation.
4. Merge the final asset/campaign handoff, generate one source-aligned combined
   candidate and run affected combined startup/flow/shutdown checks. Retain
   content, quality, exact saves, complete pre-control scenery and truthful
   cold/warm timing. Package below 256 MiB, warning at 200 MiB; Git files below
   100 MiB. No engine replacement or hidden quality/population downgrade.
5. Only after the combined work is ready, synchronize exact Web artifacts,
   fetch/reconcile remote changes without discarding work, commit intended files
   explicitly, push development and main. Let Vercel deploy; do not wait for it
   or launch a separate manual deployment. This step is not authorized while
   paused.

## Resumed Combined Work: 2026-11-09

Rafa explicitly unpaused Local AshenOath and Game Assets through Liz. The
November 7 pause remains historical; only these two tasks resume. Package it
better and the cloud coordinator remain paused. No duplicate top-level writer
or change to models/settings. Existing content, quality and publication gates
remain in force.

- Canonical tracked status matches the preserved checkpoint at `70094e2`;
  pending generated assets and this record are retained, not reset or stashed.
  Read the asset checkpoint before any merge. C11/C05 and campaign stale-output
  issues remain owned by Game Assets, not silently treated as complete.
- In the agreed first serial slot, regenerated layout, environment dependency
  catalog and layout again. PASS: 28 required textures (previously 31), 45
  presets, no retained dependency on CommonTree_1. Engine exited normally;
  slot returned to Game Assets. Evidence:
  `D:/Temp/AshenOath/combined-release-20261109/environment-closure.log`.
- The ten retired texture dependencies occupied 24,427,166 decoded entry bytes
  in the old r2 opening PCK (parsed with the existing digest-checking PCK reader).
  This is an old-payload accounting result, not final compressed savings or a
  loading-time result. Original authoring textures remain on disk; retained
  geometry/material closure passed as above.
- Added and ran a focused engine-only texture request teardown fixture to
  distinguish raw ResourceLoader ownership from game/actor cleanup. Both modes
  loaded the same 27 opening textures and released their retained references.
  Threaded mode consumed every user claim but still leaked one plain RefCounted
  at exit; synchronous mode exited without the leak warning. Functional PASS
  is not shutdown PASS. Evidence:
  `D:/Temp/AshenOath/combined-release-20261109/engine-token-isolation/`.
  No production-loader workaround or engine change has been made. A narrowly
  scoped engine-fix decision was requested; other source/asset work continues.
- Added a production build gate before prepared-actor generation for the
  combined stages 2-4 source. When `scripts/campaign_revision.gd` is present,
  the matching asset delivery verifier must validate all eight stage-2 human
  libraries and P01 against authored sources and native compiler receipts.
  The verifier arrives with the pending complete asset handoff; an absent
  verifier is a build failure, not permission to accept stale output.
  PowerShell syntax and static diff whitespace checks passed; the combined
  build has not run and these checks do not establish asset acceptance.
- Inspected shell startup prefetch scheduling: two workers intentionally hold
  only two additional decoded pack buffers before filesystem readiness. Their
  wait explains later initial-actor requests, but removing the bound would
  trade startup overlap for additional retained memory. No unmeasured increase
  in pre-init retention was applied, and no loading-time improvement is claimed.
- On 2026-11-10, extended the combined-source production build gate to require
  `build_living_world_blender.gd` followed by `verify_living_world_split.gd`
  before final dependency collection and pack hashes. This follows the asset
  handoff's maintained scenery integration contract: rebuilt static surroundings
  and all fourteen moving parts must be compiled and checked together. Missing
  helpers stop packaging; the build does not launch Blender or reauthor assets.
  PowerShell syntax and diff whitespace checks passed. The combined pipeline
  remains unexecuted pending the complete handoff; no runtime acceptance follows.

## Official-Engine Loader Investigation: 2026-11-10

Rafa approved a bounded investigation through Liz: retain official Godot, test
project-side ownership first, and use an isolated engine-patch comparison only
if needed. This supersedes the pending investigation decision above, not the
production engine pin. Custom-engine adoption remains unauthorized and would
require an explicit **Decision needed from Rafa** with options and recommendation.

- Extended only `tools/verify_resource_token_teardown.gd` with a dedicated
  `Thread` batch, explicit join, elapsed/poll reporting, prepared-actor selection
  and an opt-in immediate-join negative case. The game registry is unchanged.
  A worker-pool wrapper was rejected during source review because Godot 4.6.3
  redirects synchronous loads from pool workers into another engine task.
- In the first exclusive slot, all five fixture processes exited normally.
  The same 27 textures loaded successfully in both dedicated-thread runs,
  both engine-threaded controls and the synchronous control. Dedicated-thread
  and synchronous exits were clean. One engine-threaded control leaked two
  plain RefCounted instances; the other exited cleanly. The leak is intermittent.
  Evidence: `D:/Temp/AshenOath/combined-release-20261110/owned-thread-diagnostic/`.
- Dedicated-thread texture loading took 2,961.905 and 1,486.808 ms; engine
  threaded controls took 1,813.166 and 1,413.169 ms; synchronous control took
  1,615.743 ms. Dedicated-thread maximum observed main-loop polling intervals
  were 7.929 and 7.143 ms. These ordered, headless component runs do not establish
  cold-start, frame-rate, process-memory or game-loading improvement.
- The second exclusive slot used the existing prepared Anwen scene. Polled
  dedicated-thread and stock-threaded loads passed and exited cleanly (1,289.125
  and 163.368 ms load components, respectively; not a cache-controlled timing
  comparison). Immediate main-thread join hung at its join marker and the
  owned 15-second watchdog stopped that process: exit 124, no functional PASS.
  A killed process is not a clean-shutdown result. All owned processes ended
  before returning the slot. Evidence:
  `D:/Temp/AshenOath/combined-release-20261110/owned-thread-actor-join/`.
- Therefore a direct dedicated-thread replacement is rejected: existing
  blocking `take`, cache-clear and teardown contracts can deadlock while the
  worker awaits main-thread resource-change binding. A broader asynchronous
  loader migration is not silently substituted for this bounded repair.
- Source references: pinned [ResourceLoader](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_loader.cpp),
  [thread safety](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html),
  and the still-unmerged [upstream LoadToken proposal](https://github.com/godotengine/godot/pull/121025).
  That proposal targets newer loader code and is not an approved drop-in fix
  for this engine version. Any isolated backport must preserve task joining,
  nested-load lifetime and shutdown, not merely hide leaked-object warnings.
- No C++ compiler or SCons was found in the current tool/runtime discovery.
  Downloaded the official portable LLVM-MinGW archive to the D: diagnostic
  directory, with its release-published SHA-256 verified:
  `552191b5754c49a5a20723276a6fc56541ea1922c4c50b7b669022333fc1b40f`.
  The SCons 4.11.1 wheel also matches its PyPI-published SHA-256:
  `454cef364348053422696e3d2ecb4fa593c96a624f955842eaaea64f95c8d11d`.
  No system compiler installation, engine build, game configuration change or
  custom-engine adoption has occurred. Extraction/build waits for a coordinated
  heavy-work window; production and the final combined release remain untouched.
- Binary provenance checked independently: the retained official Windows ZIP
  matches the GitHub release digest
  `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`;
  its console and engine executable entries match both installed executables.
  The engine reports `4.6.3.stable.official.7d41c59c4`, but the currently exposed
  source tag resolves to `35e80b3a8822a9df9be390814b62f44c0a9c69e8` and the
  public commit lookup for `7d41c59c4` returned no commit. The separately published
  release source archive must be reconciled before claiming an exact-source
  patched-engine comparison; the tag alone is not that proof. No binary was
  replaced. Its first source-archive download stalled and was terminated by its
  verified owned PID, preserving the partial file; a bounded download is pending.

### Resumed Isolated Comparison: 2026-11-10

- Rafa directly approved **"Authorize the narrow engine fix"** in this thread.
  The loader-only custom build is authorized; this does not waive comparison,
  shutdown/resource correctness or combined-game testing. It does not establish
  a loading-speed improvement or authorize unrelated engine/renderer changes.
- Rafa approved a resumable source transfer and completion of the isolated
  comparison, then clarified that necessary validated changes may proceed.
  The earlier blanket custom-build approval hold is superseded by that direction;
  untested patches and warning suppression still cannot establish a repair.
  No engine adoption, game configuration change or publication has occurred.
- The 120-second transfer failed with 23,443,921 bytes retained. Resuming those
  bytes with a 600-second allowance completed the official release source:
  44,471,880 bytes, SHA-256
  `2261028c0dfc10e0cf4800a5b2e5a57ea241f72965162327f5764d536a69a46a`.
  This matches the release-published digest. Compiler and SCons archives remain
  intact. The source archive identifies 4.6.3 but does not contain the generated
  version hash, so the previously reported binary/tag discrepancy is not claimed
  resolved. Use an unmodified local build as a same-toolchain control as well as
  the official executable when comparing the narrow patch.
- Added `--blocking-get` to the existing isolated fixture. This exercises the
  engine's own blocking request/get contract, not the rejected dedicated-thread
  immediate join. Added bounded repeated rounds and per-round object/static-memory
  observations; no sleeps are inserted between rounds. Execution and comparative
  results remain pending.
- The official release archive's `core/io/resource_loader.cpp` exactly matches
  the separately downloaded public source tag file (SHA-256
  `08e5a8a5b77d4e9e430a0da90bcbab4677f8b540b07cb2b3e8b7abcf5bb6a6bf`).
  This identifies the comparison source, not the unresolved executable version
  banner. Keep the official binary as a separate control.
- Official source extraction completed. Portable compiler extraction exceeded
  the shared window; only its verified owned process tree was stopped and the
  slot returned. Partial files remain recoverable. The D: diagnostic helper now
  resumes required x86_64 entries using ZIP size/CRC, atomically replacing only
  incomplete diagnostic files and leaving other owners untouched.
- A one-file candidate is staged separately from the unmodified build source:
  release the worker's final token reference after its last task/TLS access,
  hold a completion reference while borrowed task data is used, and reap a task
  through the main queue if its final token was released on that same worker.
  It introduces no sleep, warning suppression or production engine change.
  Compilation and execution are pending; it is not a proven universal loader
  repair. Early shutdown with unclaimed work remains a distinct compatibility
  case, not implied by the all-claims-consumed diagnostic.
- Static review tightened the draft's final worker release and task removal
  under the existing loader mutex, so a new request cannot observe the zero-ref
  token between those operations and wait on its still-cleaning worker. The
  previous draft is retained separately; neither draft has been compiled or
  adopted. The unmodified control source remains byte-identical.
- Comparison tooling preserves separate evidence directories, fixture/binary
  hashes, functional results, exit diagnostics and 20-ms sampled private bytes.
  These samples are component observations, not certification of OS peak memory,
  gameplay performance, first-control time or the approximately 32-second goal.
- Portable compiler extraction now preserves 5,200 of 5,666 selected entries.
  The configuration-only window ended on a checkpoint replacement sharing error:
  an owned `Get-Content -Tail` reader held the single-line receipt open. That
  reader was terminated; the extractor exited without starting a build. The
  pending receipt is intact. The scratch extractor now recovers both receipts,
  emits progress directly and preserves a pending checkpoint if replacement is
  temporarily busy. No production files or user processes were removed.
- Configuration/build/comparison PowerShell scripts pass syntax parsing. SCons
  configuration, both source builds and the new comparative runs are still
  pending; setup progress is not a shutdown repair or a loading improvement.
- The next exclusive setup window completed all 5,666 compiler entries (466
  remaining files extracted in 24.328 seconds) and installed verified SCons
  locally. SCons successfully read the configuration and began enumerating the
  Windows x86_64 debug-template target graph. Its dry run exceeded the 60-second
  budget and the owned watchdog stopped it; no C++ compiler or game was run.
  Preserve that timeout as incomplete enumeration, not a compilation pass.
  The next reserved window is for the unmodified-source baseline build, rather
  than another dry-run enumeration. The official engine remains untouched.
- `baseline-01` ran the unmodified source with two compiler workers for
  751.988 seconds, then deliberately checkpointed its two owned compiler leaves
  before the hard deadline so SCons could save its index normally. It exited 2;
  this is an incomplete build, not a successful compilation. The source archive
  also emitted a nonfatal Git-metadata lookup diagnostic. Both messages remain
  in the raw logs. No other process was stopped.
- The checkpoint retained 613 object files (29,640,225 bytes) and a 2,723,292-byte
  `.sconsign5.dblite`; the pinned SCons parser found 613 object entries with 613
  action signatures. Reuse is to be confirmed by the next same-configuration
  build, not inferred as a completed executable. All owned processes exited
  before returning the exclusive machine slot. Future runs request SCons'
  graceful interrupt before the hard watchdog, preserving incremental metadata.
- `baseline-02` confirmed reuse of all 613 earlier objects and retained 1,078
  completed objects (45,765,954 bytes), with a 5,843,904-byte saved SCons index.
  It remains an incomplete control build. At 859.557 seconds its two verified
  owned compiler leaves were stopped so SCons could save normally; the hard
  watchdog did not fire and all owned children exited before returning the slot.
  The failed OpenXR compilation entries are deliberate checkpoint interruptions,
  not diagnosed source compilation defects.
- The scheduled Python interrupt was emitted but Windows deferred its SCons
  handler until active workers ended. The scratch wrapper now calls the pinned
  SCons cooperative stop handler directly from its timer and starts that timer
  before importing SCons. The next control resume must establish that behavior;
  no game shutdown result is inferred from this build-tool change.
- The resource comparison runner now exits unsuccessfully if any case times out,
  fails its functional checks or reports a shutdown error/leak. PowerShell syntax
  parsing passes; the new matrix remains unexecuted. Draft loader v2 SHA-256 is
  `f068c6d4108f7693c72db87ba5da2c537358d142c5b2c33e1cc0d30346d21a72`;
  the control loader source still matches the verified release source.
- `baseline-03` retained 1,616 objects (76,751,981 bytes) and an 8,256,847-byte
  signature index. All prior 1,078 objects were reused. The corrected cooperative
  checkpoint stopped SCons normally at 726.150 seconds, without killing compiler
  jobs or reaching the hard watchdog; exit 2 records an intentional incomplete
  build, not a compiler-source failure. Only the retained source-archive Git
  metadata warning and deliberate interruption appeared on stderr. All owned
  processes exited before returning the shared worker. The loader source is still
  unmodified, no executable is complete, and no shutdown comparison has run.
  Python tooling bytecode is cached privately on D: for subsequent build windows;
  the compiler configuration and game files are unchanged.

Further unmodified-control checkpoints (not completed engine builds):

| Resume | Elapsed | Retained objects | Object bytes | Outcome |
|---|---:|---:|---:|---|
| `baseline-04` | 759.987 s | 1,798 | 118,891,817 | All prior 1,616 reused; cooperative stop, exit 2, no forced termination or watchdog; index 9,297,879 bytes. |
| `baseline-05` | 735.291 s | 1,985 | 168,404,885 | All prior 1,798 reused; scene library linked; cooperative stop, exit 2, no forced termination or watchdog; index 10,385,380 bytes. |
| `baseline-06` | 787.328 s | 2,238 | 210,785,422 | All prior 1,985 reused; unmodified loader compiled; cooperative stop, exit 2, no forced termination or watchdog; index 11,614,363 bytes. |

Each resumed build retains its raw logs and receipt in the existing D: engine
diagnostic directory. The loader source remains unchanged; all owned children
exited before returning the worker. No shutdown or loading-speed pass follows
from these compilation checkpoints.

`baseline-07` completed the unchanged control build in 203.176 seconds, exit 0,
without reaching either deadline. All owned compiler children exited. The
preserved control executable is 81,204,224 bytes, SHA-256
`b5475f5af3fdad75855fb5d7c30a4e6b7e545f210052e4a330e5f7444879a8c5`,
under the diagnostic directory's `control/`. Its loader source still has the
verified release-source hash above. This establishes compilation only; the
patched build and official/control/patched lifecycle comparisons remain pending.

The first control launch (`control-resources-01`) failed before executing any
fixture: export templates disable `--path` and `--script` by default. Preserve
this runner failure; it is not a loader result. The existing comparison wrapper
now launches the same inherited fixture as an isolated project's configured main
loop, with a placeholder scene, private user-data directory and read-through
source/import links. The engine configuration and fixture logic are unchanged.
`control-resources-02` prepared that project but mishandled a GUI executable's
exit status; its outputs remain. Explicit owned-process setup corrected that
runner failure and retains its stdout/stderr and timeout cleanup.

`control-resources-03` then completed all five resource cases, ten rounds each,
with functional success and no observed exit leaks. The unchanged control's
asynchronous texture case retained 1,382 objects at each observation. This is a
bounded observation, not proof of universal leak freedom. The build target is
`template_debug`: SConstruct enables `DEBUG_ENABLED`, ObjectDB cleanup contains
zero-reference/verbose reporting, and the exact leak-warning string is present
in the preserved executable. Diagnostics were not disabled or filtered.

`official-resources-01` used the same isolated bootstrap and exact fixture. Its
ten asynchronous texture rounds succeeded functionally but reported **22
zero-reference RefCounted leaks** on exit. Ten blocking Anwen rounds exited
cleanly. The overall shared-worker deadline interrupted the blocking-texture
case; two remaining cases never started. That matrix is **incomplete/failed**,
not a passing comparison. Resume only its unfinished cases; preserve the
completed observations and the native binary/source-banner distinction above.

The one-file loader draft v2 is now applied only to the diagnostic source tree,
SHA-256 `f068c6d4108f7693c72db87ba5da2c537358d142c5b2c33e1cc0d30346d21a72`.
The unmodified executable is preserved. Incremental patch compilation, repeated
patched resource checks and actual preparation/playable Quit checks remain
pending. All owned children exited before the 21:41:30 UTC slot handoff; no
patched engine, game release or Web artifact has been adopted or published.

The verified source also distinguishes the current non-threaded Web target:
`main/main.cpp:2098` initializes a zero-worker pool without `THREADS_ENABLED`,
and `core/object/worker_thread_pool.cpp:222` executes ordinary tasks on the
calling thread when that pool is empty. This source path does not expose the
same worker-versus-caller final-reference race. It is not a new Web shutdown
observation or proof that every loader cleanup path is correct. Do not claim
the native loader patch improves browser startup or replace the current Web
engine merely to carry the race repair reproduced here. A future threaded Web
target would require its own lifecycle checks.

### Patched Loader Resource Comparison: 2026-11-10

`patched-01` compiled only the changed loader and relinked its library/executable
with unchanged control flags: exit 0, 105.142 seconds. Preserved candidate:
`D:/Temp/AshenOath/engine-loader-diagnostic-20261110/patched/godot.windows.template_debug.x86_64.llvm.exe`,
81,205,760 bytes, SHA-256
`c5088a1c7074cbdc069fadbed45335f0b57c3426ebefad8634847977471e4a4d`.
The original control remains separate and unchanged.

The remaining official cases completed in `official-resources-02`: blocking
textures loaded successfully but leaked 58 zero-reference RefCounted instances;
asynchronous Anwen and synchronous textures passed with clean exits. Together
with the earlier completed cases, both official texture-threading paths reproduce
the leak. The deadline-interrupted earlier case remains recorded, not overwritten.

`patched-resources-01` completed three repetitions of all five cases, ten rounds
per case: **150 functional rounds and 15 clean process exits**, no timeouts or
reported errors/leaks. Fixture SHA-256:
`bb04475fabb0b71399411369511a6d88abef125254869e3ea8f0e55e62b7c587`.
Receipts retain source/executed executable hashes, bootstrap identity, input
catalog hashes and unfiltered output. The unchanged same-compiler control also
exited cleanly in its bounded resource matrix, so this is not a statistical
proof that the patch alone explains every difference from the separately built
official engine. Actual game Quit cases are in progress. No Web speed, final
combined-candidate, performance-limit or publication claim follows from these
native resource checks.

### Game Quit Checkpoint: 2026-11-11

- `patched-game-01`: both cases invalidated by missing shader preloads in the
  isolated comparison project, despite exit 0 and functional markers. This was
  a runner defect; it is not a passing game check or evidence of a loader leak.
- The runner now links the canonical `shaders` directory in its isolated
  project. The game, engine binary, and fixture were unchanged.
- `patched-game-02`: preparation-time Quit passed cleanly (174.433 s elapsed).
  The playable case hit the watchdog at 243.149 s and was terminated. Its
  retained log shows a 30-second environment texture timeout, a retry, and
  ongoing cemetery geometry loads, not a hang in the Quit code. It never
  established playable shutdown. The host was also slow for unrelated shell
  reads, so these are not comparable startup timings.
- No matching new official/control game runs started. The serial slot was
  returned with every owned engine child exited. Preserve the successful
  preparation-time result; the next game comparison should target playable
  startup and Quit without repeating the successful resource matrix.
- `patched-game-03` stopped before gameplay: the isolated-project bootstrap
  hit its 20-second setup watchdog. `patched-game-04` reused the hash-checked
  `patched-game-02` project and copied engine, with the same fixture and a new
  private profile. The playable Quit case **passed**, exit 0 with no error or
  leak diagnostics, 122.263 s elapsed. The preparation case and 150 successful
  resource rounds were not repeated. The native cases now have clean observed
  exits on the preserved candidate. Earlier failures remain evidence.
- This is bounded validation of a diagnostic Windows template. It does not
  certify the reference memory budget, every engine shutdown path, or the
  combined art candidate. The separately built official executable still
  differs in provenance from the same-compiler control. No native executable
  has replaced the non-threaded Web engine or been published.
- The exact one-file candidate is retained in
  [godot-4.6.3-load-token.patch](engine-patches/godot-4.6.3-load-token.patch).
  The baseline was extracted from the retained public tag archive and checked
  against its original loader SHA-256. The patch reverse-check passed against
  the compiled source. This carries no engine binary into the Web package.

### Combined Companion Build Ownership: 2026-11-10

Static review confirmed the maintained release builder did not transitively
compile the staged Bracken derivative. Under the existing living-campaign
condition, it now requires `build_prepared_companion.gd` and
`verify_prepared_companion.gd`, compiles after prepared actors and performs the
resource/pose comparison with `--visual-only` before dependency layout and pack
hashes. This retains the raw M13 root, 0.62 runtime scale, PI yaw and companion
contract rather than applying enemy-role normalization. Missing handoff helpers
block packaging. Source-change attack calibration remains an independent gate;
the builder does not recalibrate it automatically. PowerShell parsing passed.
The complete asset handoff and combined production execution remain pending.

### Fresh-Start Pack Ownership and Handoff: 2026-11-11

- The in-memory actor partition using the current catalog and presets removes
  only `actor_m05` from fresh startup. The original Greyfen and cemetery zone
  requirements, the boss pack preset, and every other startup pack are retained.
  Road of Crows requires the Wychwood clearing and village report before it
  unlocks Bell Beneath Greyfen. Fresh New Game uses the covered Greyfen world;
  returning to Greyfen and Continue still use the full destination pack gate.
  The retained r2 M05 transport is 1,178,217 bytes; no combined timing gain or
  return-path runtime pass is claimed.
- The r2 opening PCK has no byte-identical nonempty payload duplicates. Its
  largest resources are imported textures. A bounded scratch probe for stronger
  lossless WebP encoding timed out before reporting a verified sample. No
  repacking change or savings estimate was adopted.
- The Game Assets layout compiler branch adds
  `partition_living_campaign_packs` but does not have the canonical prepared
  forest switch. At the ordered handoff keep both imports, the canonical
  `compile_layout(defer_environment=False, require_prepared_forest=False)` and
  CLI argument, and call the community partition after actor partitioning and
  before reapplying forest ownership and environment-root retirement. Preserve
  the canonical release builder's cast, scenery, companion and closure gates.
  The first layout runs before the companion compiler, so allow its derivative
  to be unbuilt in the provisional pass only; the final layout requires the
  exact prepared file and retains its declared owner. Use the Game Assets
  archive ownership verifier at commit `76bacd0` after generating the final
  Web manifest, before copying or publishing. No overlapping checker or partial
  branch/generated presets were merged at this checkpoint.

### Retained First-View Evidence Review: 2026-11-10

- Read the existing `startup-half/browser-final-profiled_evidence/desktop-smoke-webgl-0.json`,
  not a new run: 36,160.3 ms accumulated in program-status queries and 3,462.4 ms
  in shader-status queries; texture upload calls accumulated 749.1 ms. These are
  historical diagnostic observations, not current combined-candidate timings.
- The verified 4.6.3 source's `_compile_specialization` immediately queries each
  stage's compile status and then program link status. This supports focusing
  the remaining first-view work on shader compilation/publication, rather than
  assuming all of it is resource download or texture upload.
- Khronos documents nonblocking completion polling and batched compile/link
  submission, but explicitly does not promise shorter total wall time:
  https://registry.khronos.org/webgl/extensions/KHR_parallel_shader_compile/.
  No renderer patch, new experiment or speedup claim was made in this review.
  Preserve prior rejected shader/UBO experiments instead of repeating them.
- The current `tools/verify_hardening_browser.mjs` still matches the retained
  `combined-release-20261107/baseline-normal-profile-r7.json` harness SHA-256
  `23d16ebd487eaa25bfe4723f7af1ee1ee16a3039c8bcde5d6a430edb56cb129d`.
  Its reference uses the startup scenario, desktop 1280x720, a fresh temporary
  normal profile, foreground emulation and no loading/precontrol captures.
  Retain `--profile-context --no-precontrol-captures`, exact exported bytes and
  source-aligned shader behavior for the final combined observation; do not
  substitute the generic Web smoke or inject a different shader candidate.
  This was a read-only evidence/settings check, not a new browser run or proof
  that host conditions and elapsed timings will be identical.

## Consolidated User Checklist

1. New Game/selected Continue, quality changes and regional returns: existing
   people, quests, materials and controls remain intact; optional downloads Retry.
2. Greet, apologize, join an exchange and follow an outing; interrupt by walking
   away, talking, danger, pause and reload. No repeated rewards or lost quest Use.
3. Discover the pair/traveler scenes in different orders; absent or departed
   participants must not speak. Check later shared work and private grievances.
4. Trade a favor, inspect an object, arrange all six shelf slots and Continue.
   Closed letters stay closed, gifts persist and evidence is not consumed.
5. Watch creatures, follow trails out of order, wait morning/evening and shelter
   during rain. Check observations, cosmetic wear and cleaning without stat changes.
6. Throw a stone near an idle ordinary enemy and during real pursuit; try accepting
   and declining surrender. Check kill facts, encounter XP, return and Continue.
7. Fish at each bank, miss a bite, ease/reel, cancel, fill the six-fish capacity and
   reload. Cook/eat all three meals; interrupt before completion and verify supplies.
8. Sell three fish to Nessa; repeated waiting/reload must not replenish quota.
   Confirm later-day plus active-play refill and unchanged ordinary shop transactions.
9. Complete/rematch each three-round meet; interrupt boards and archery. Check
   opponent availability, equipment/ammo restoration and strictly once-only prizes.
10. Check actual-phone layout/input, audio/focus recovery, all existing campaign
    outcomes and retained reference-PC performance separately. No FPS claim is made.
