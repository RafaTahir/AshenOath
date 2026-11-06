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
