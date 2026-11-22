# PERF-001 CPU / Wall-Time Discriminant - 2026-09-28

## Decision

PERF-001 remains pending. Formal recovery count remains 27/37. There is no
current-source Web performance acceptance, export, commit, push or deployment.
The production scene, native renderer settings and all acceptance limits remain
unchanged. Distributed first-visible work remains a leading hypothesis, not a
proven exclusive cause.

## Source-Bound Diagnostic

`D:/Temp/AshenOath/perf_cpu_wait_20260928/v2/` contains frame timestamps, OS
process/thread CPU samples, read counters, page faults, source hashes and the
thread-identity record. Godot's logical caller ID 1 is NOT a Windows thread ID;
the initial failed probe is preserved separately. The corrected probe uses the
uniquely oldest original executable thread and records every creation time.

| Frame boundary | Wall / OS bracket ms | Main / all-thread CPU ms | Read bytes / page faults |
| --- | --- | --- | --- |
| menu preparation | 13824 / 13862 | 859 / 15937 | 2.4 MB / 190396 |
| menu preparation | 7434 / 7442 | 297 / 5766 | 2.9 MB / 67752 |
| menu to first place | 2204 / 2259 | 203 / 1328 | 1.175 MB / 24584 |
| gate visual to route markers | 1593 / 1625 | 94 / 1969 | 0 / 16549 |
| place 2 to 3 | 624 / 662 | 15.625 / 15.625 | 0 / 1138 |
| place 3 to 4 | 535 / 570 | 46.875 / 46.875 | 0 / 547 |

Some long frames are predominantly waits rather than main-thread script work;
others involve substantial worker CPU. This does NOT uniquely identify GPU,
shader compiler, disk, or scheduler ownership. Write counters, GPU timers and
thread stacks were not collected and are not inferred. Observer queries average
0.283 ms and reached 63.94 ms themselves. This is diagnostic evidence, not an
uninstrumented benchmark or causal A/B comparison.

The observed run fails hydration at 29.001 / 1.090 FPS average / 1% low, worst
1592.537 ms, and settled play at 44.525 / 26.527. Its wrapper lost the child exit
code; completion and explicit Godot failure output are retained, but verified
exit ownership is NOT claimed. No active renderer/resource error was observed.

## Program-Binary Cache Hypothesis: Rejected As A Sufficient Fix

The isolated source-complete fixture at
`D:/Temp/AshenOath/perf_cache_io_20260928/project/` copies project settings,
export presets and root runtime JSON and links the canonical resource folders.
Only its `override.cfg` disables
`rendering/shader_compiler/shader_cache/enabled`. Canonical settings never change.

The initial missing-manifest run is invalid: it failed `base` dependency
resolution. `native_complete.log`, `native_complete.err` and the fixture's own
`.release-gate/perf_001_greyfen_report.json` are the corrected run; owned child
exit is 1. Hydration is 31.980 / 1.840 FPS with a 1166.296-ms worst frame;
settled play is 46.454 / 30.840. Greyfen preparation takes 20,940 ms, also over
the cold-start ceiling. No frames or content are excluded. No implementation is
retained and no causal speedup is inferred from sequential cache conditions.

Godot 4.6 GLES3 source implements synchronous program-binary load/save. Its
separate EGL manager still installs disk blob-cache callbacks regardless of this
renderer switch: the fixture contains EGL cache files. Therefore this test does
NOT prove that all ANGLE caching or driver waits are irrelevant. Disabling EGL
through an intentionally invalid cache path would emit an engine error and is
not a production solution.

Sources: Godot `drivers/gles3/shader_gles3.cpp`,
`drivers/gles3/rasterizer_gles3.cpp`, and `drivers/egl/egl_manager.cpp` at tag 4.6.

## Evidence Identity Correction

`D:/Temp/AshenOath/pres001_foundations_perf_20260927.report.json` is an older
2026-09-24 full-run report copied under a misleading later filename. Do not use
it for the September 27 foundation pass. That pass's actual log records settled
45.730 / 29.147 and hydration 37.816 / 2.958, worst 895.447 ms. Preserve both
files; the stale copied report is not acceptance evidence. The canonical target
report was subsequently overwritten by the CPU diagnostic, as explicitly
recorded here. New isolated reports stay with their own run.

## Immutable Geometry Ownership Candidate: Rejected

The corrected read-only headless census at
`D:/Temp/AshenOath/perf_geometry_ownership_20260928/` exits 0 cleanly: 156
distinct geometry resources, 64 redundant base-array resources and
50,166/198,961 redundant vertices. Invalid primitive-method and inferred-type
attempts are retained separately and are not evidence. Base-array equality alone
does not approve LOD, skin, material or mutation ownership.

The offline candidate at `D:/Temp/AshenOath/perf_shared_humanoids_20260928/`
serializes the six original A-set assemblies into packed scenes referencing
three immutable complete geometry resources. It preserves compressed surface
data, topology, LODs, shadow geometry, texture pixels, material properties, skin
bindings, skeleton rest/pose, node transforms and exact affected actor paths.
Six serialization parity checks and complete-scene ownership of all 13 affected
actor meshes pass with owned exit 0 and clean shutdown. Candidate dependencies
refer only to shared geometry and original PNGs, not the six original GLTFs.
The initially invalid external relative-path serialization is preserved, including
its owned timeout; the corrected absolute-path fixture is the passing unit.

One graphical candidate then fails with owned exit 1: prewarm 31,602 ms,
hydration 11.188/0.597 FPS, worst 2583.845 ms; settled 24.659/18.084 FPS.
No active resource/renderer or shutdown error occurs. Counts are 1,095 nodes,
253 final draws and 83,892,107 static bytes. This is NOT a paired source-frozen
benchmark, so it does not prove a causal regression. It is sufficient to reject
the candidate as an end-to-end solution. No runtime resolver, packed candidate
asset, material-ownership change, image approval or performance claim is retained
in the canonical project. Full graphical parity was not evaluated after the red
performance result. Do not repeatedly warm this candidate until a lucky pass.

## Completed Worker Discriminant

The existing frame/process CPU trace cannot distinguish resource decoding from
driver/compiler worker work. One batched passive diagnostic records all native
thread names, creation times, CPU counters, start/module identities, wait states,
process read/write counters, page faults, working/private memory, sampler cost,
frame/stage timestamps and pending threaded resource statuses. It neither
suspends threads nor modifies scene/renderer settings. GPU timers are not exposed
by the public GDScript API and are not invented. Unknown thread ownership must
remain unknown. Diagnostic FPS includes instrumentation and is never acceptance.
The one run at `D:/Temp/AshenOath/perf_worker_owner_20260928/` completed with
owned exit 1. The observer itself is costly: mean query 30.414 ms, maximum
680.059 ms. Its 9.245/0.511 hydration and 24.034/18.353 settled FPS are NOT
comparable uninstrumented performance samples. All 30 thread start addresses
returned zero, so module ranges do not establish unnamed thread ownership.

The 28,115-ms menu interval has 30,031 ms total CPU and 20,003,357 written
bytes. All eight pending resource requests were already THREAD_LOAD_LOADED.
The 11,939-ms menu interval has no pending requests, 12,781 ms CPU and
14,775,417 written bytes. The 3,293-ms gate interval has no pending requests,
3,844 ms CPU and 1,872,517 written bytes. The dominant CPU owners are unnamed;
Godot's explicitly named WorkerThread0-3 are not the dominant owners. Official
4.6 `core/io/resource_loader.cpp` submits asynchronous resource tasks to that
worker pool. Thus unfinished resource decoding is not supported as the dominant
owner of these specific intervals. Driver/compiler work is supported but remains
an inference, not a captured stack or GPU timing. Very long low-CPU intervals
remain unclassified; stage labels alone do not prove cleanup ownership.

No new observer, static merging, shader-family adaptation, object warmup,
global material normalization, late interning or publication retry follows.

## Shader Light-Array Capacity: Two Rejected Candidates

Official 4.6 GLES3 source compiles MAX_LIGHT_DATA_STRUCTS into omni/spot and
shadow uniform arrays. Default capacity is 32, per-object capacity 8. The scene
budget is eight local lights; the actual source has one local-light factory and
Balanced caps it at two, or four in Record Hall. An isolated override tests
total capacity eight while retaining per-object capacity eight and every light,
energy, range, shadow, material, mesh, actor and interaction. A current complete
zone census must first prove sufficient capacity; it is not graphical approval.
The corrected headless complete 14-zone ownership contract exits 0 cleanly:
Greyfen/Wychwood/undercroft have two local lights, Record Hall four, mill/Hart
one, other zones zero. Failed fixture waits are preserved separately: the
rebuilt full Greyfen does not use the initial deferred-hydration marker. This
test does not approve graphical appearance, route completion or FPS.

One uninstrumented graphical candidate with total capacity eight and unchanged
per-object eight exits 1: prewarm 19,396 ms, hydration 11.474/1.014 FPS,
worst 1302.543 ms, settled 44.086/29.546. A second candidate keeps total eight
and per-object four (still sufficient for every actual current Balanced light)
and exits 1: hydration 19.784/0.827, worst 1771.300 ms, settled 47.701/29.888.
Neither discards a light or actor. No active renderer/resource/shutdown errors
occur. Both fail the unchanged frame floor. No paired improvement claim or
graphical quality approval follows a rejection; no settings are integrated.

These two capacity hypotheses exhaust this candidate class. Do not try another
capacity, warm-until-pass repetition, or Web export. Driver/compiler work is
still an inferred owner, not a proven stack. The remaining blocker is actual
first-visible stalls despite fast headless construction and acceptable settled
averages; source capacity tuning does not solve it. Canonical renderer settings
remain unchanged. The next intervention must change abstraction level or close
an independent release-critical dependency, not tune another object/capacity.

Sources: https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html
and tag-4.6 `drivers/gles3/rasterizer_scene_gles3.cpp` / `shaders/scene.glsl`.

## ANGLE Blob-Cache Discriminator: Rejected

The shipped ANGLE revision aaebda1c5a40 exposes process-local
disableProgramCaching/cacheCompiledShader feature overrides. Godot's EGL blob
callbacks are separate from its shader-cache project setting. An isolated
1280x720 lit-mesh fixture draws correctly and exits 0 with both controls applied:
baseline writes 24 EGL files (194982 bytes), disabled writes zero. The initial
wrapper's wrong cache-path regex is preserved; baseline was counted offline,
not rerun. This establishes the cheap control, not gameplay or performance.

The one source-frozen full Greyfen diagnostic at
D:/Temp/AshenOath/perf_blob_cache_20260928 exits 1. Hydration measures
40.421 average / 2.061 FPS 1% low, worst 1166.552 ms; settled measures
46.614 / 28.331. Final population remains 1096 nodes, 253 draws, 127334
primitives and 83741203 static bytes. The full profile still contains two EGL
files (12286 bytes) and two Intel driver files (517628 bytes). Therefore this
does NOT prove all game/driver disk-cache work was disabled. No unclassified
renderer/resource/shutdown error occurs; the two unchanged FPS assertions fail.
No causal speedup claim follows an uncontrolled sequential comparison.

Reject this as an adequate solution and retain no canonical setting override.
Together with the prior Godot-only cache-off failure, stop this cache-toggle
experiment class. Distributed first-visible publication remains a leading
hypothesis, not a proven exclusive cause; driver compilation/storage remains
unresolved. Native-only SSD comparison awaits the requested permission. Kernel
CPU/disk stack tracing needs an elevated owned recording; this process is not
administrator, and no system trace was started. Close an independent visual or
story dependency instead of another object/cache/prewarm iteration. No Web
export while native acceptance is red.
