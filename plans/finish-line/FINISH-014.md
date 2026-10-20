# FINISH-014 - Strict Reference-PC Performance

Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-001 through FINISH-013
content stable for final acceptance. Focused bottleneck repairs may occur earlier.
Implementation: OPT-001 through OPT-056 present; measured gain not established.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only. Numerical misses block this ticket.

## Player Outcome

The complete game starts predictably and plays smoothly on the existing reference
PC without a lower visual preset, missing population or post-control assembly.

## Existing Owners And Evidence

Use existing startup reporting, performance monitor/comparison options, zone
budgets and targeted graphical tools. No replacement profiler or benchmark suite.
[OPT status](../../outputs/AshenOathTheRoadBetweenCrowns/PERFORMANCE_OPTIMIZATION_STATUS.md),
[earlier bounded comparison](../../outputs/AshenOathTheRoadBetweenCrowns/STARTUP_SMOOTH_001_RESULT.md)
and [strict native verifier source](../../outputs/AshenOathTheRoadBetweenCrowns/tools/verify_perf_001.gd)
are ownership/protocol references, not current passing measurements.
Historical functional-candidate waivers do not satisfy this ticket.

## Fixed Gates And Measurement Scope

Reference: existing Intel HD Graphics 620 laptop, graphical Compatibility renderer,
native 1280x720, Balanced, render scale 1.0, intended scenery/actors present.
Record actual CPU/GPU/driver, power mode, quality, rendering options and candidate.
Use the established graphical sampling configuration; do not alter saved defaults
or secretly lower image resolution to obtain a result.

| Measurement | Required result |
| --- | --- |
| Average FPS | At least 32 |
| 1% low FPS | At least 30 |
| Native owned-runtime peak private memory | Strictly below 471,859,200 bytes (450 MiB) |
| Warm transition | At most 350 ms |
| Cold transition | At most 900 ms |
| Web first visible paint | At most 0.75 seconds from navigation |
| Cold / warm navigation to usable menu | At most 12 / 6 seconds |
| Cold / warm navigation to first control | At most 15 / 7 seconds |
| New Game after complete preparation | At most 750 ms from activation |

Native FPS/memory/transition acceptance covers the six regions, representative
combat and required heavy interiors, including Greyfen, Wychwood, Deep Woods/mill,
Long Road, Castle/Record Hall and Hartlands. Use the existing per-zone sampling
protocol, including its eight-second frame samples, not a new repeated-run campaign.
Record first-playable/hydration and settled intervals separately; retain slow
frames in their actual interval and apply the FPS gates to playable intervals.

Web startup uses desktop Chrome on the reference PC and the existing controlled
cold/warm network profile (20 Mbps, 50 ms RTT). Cold means empty HTTP/game caches;
warm means the same release cached in the same profile. Record engine/driver cache
state separately; never label a warmed driver observation as cold-driver proof.
Activation occurs at the first usable menu; no hidden preparation wait before timing.
First control means complete required world/camera plus responsive ordinary input.

Measure the actual native GUI runtime's private bytes from start through relevant
transitions, not the console launcher, working set alone or static allocation
counter. Shared browser/GPU processes are a separate diagnostic scope and cannot
substitute for the native private-memory gate. Missing measurement is incomplete.

Transition time includes required destination construction, audio and readiness
before returned control. A late scenery/population stall is not an improvement.
Record worst frame and hitch count as well as FPS; no invented additional
worst-frame threshold, discarded slow gameplay frames or averaged-away failed zone.
Phone FPS/timings are reported separately; phone functionality belongs to FINISH-005.

## Bounded Repair And Retention

- The user runs runtime measurements. Agent work stays build-only: inspect supplied
  measurements/source, identify the measured owner, make a bounded repair and
  provide a minimum package when needed for the user's next affected comparison.
- Do not repeat rejected renderer/cache/prewarm mechanism families without new
  distinguishing evidence. No engine rebuild, elevated tracing campaign or broad
  architecture replacement is authorized by writing this ticket.
- State the bottleneck, source-backed hypothesis and predicted affected interval
  before an implementation experiment. After two failed hypotheses in a mechanism
  family, stop repeating it and record the unresolved dependency.
- Keep a candidate only when the user's affected comparison supports it without
  reducing content/quality or moving work to after control. Do not claim enabling
  OPT defaults itself proves improvement.
- Final acceptance requires every listed gate with matching candidate/configuration.
  A failed/absent measurement cannot become a disclosed nonblocking limitation here.

## User Manual Checklist

1. Record reference-PC configuration and current candidate; close competing heavy
   workloads and keep power conditions consistent for the affected comparisons.
2. Use existing opt-in performance display/reporting and graphical measurement
   tooling to capture cold/warm startup, initial playable frames and settled samples.
3. Traverse the required regions/interiors and representative fights; record
   average, 1% low, worst frame, hitches and actual runtime peak private bytes.
4. Record first/repeat destination transitions through readiness, keeping their
   loading and gameplay intervals visible rather than timing only the last stage.
5. Supply the results for source-backed repairs; accept only after every gate on
   the final content passes. No agent benchmark or gameplay run is performed.

## Delivery Record

Superseding 2026-10-20 build-only scope: no further agent benchmark/profiling run.
The user owns measurements. Source-backed corrections in user-candidate complete
required navigation/arrival work before control, avoid the duplicate focused
render audit, mark the already-complete opening as complete before handoff and
drop retargeted animation cache variants only after their source ownership ends.
Active/cached AnimationPlayers keep their resources; no body, actor, material,
scenery, visual preset or collider is removed or reduced. The failed dispatcher-
only lazy-loading mechanism is not repeated. Numerical improvement is UNVERIFIED;
the strict red baseline and unresolved sustained CPU/GPU/private-memory attribution
remain. No responsible source-only claim can establish 32/30 FPS or <450 MiB.
Compilation/package completion is not performance acceptance. Next measurement is
the user's existing reference-PC procedure on the delivered frozen content.

2026-10-20 renewed authorization: the user approved focused source/evidence
analysis, repairs and ONE follow-up native measurement, without engine rebuilds
or administrator tracing. This supersedes the historical pending-approval notes
below; strict targets and user acceptance remain unchanged.

Bounded candidate: campaign_section.gd eagerly preloaded all four campaign
sections (including Castle and finale meshes). ZoneStreamingService prefetches
that dispatcher for individual neighboring destinations, so unrelated asset
graphs entered the same preparation/residency path. Section selection now uses
path-only membership and lazy script access; the router requests the selected
section alongside the lightweight dispatcher. Every existing builder and its
content remains intact. Prediction: less unrelated resource work/residency during
neighbor preparation and first campaign transitions, not a guaranteed cure for
settled FPS or all private-memory usage. Both changed scripts passed Godot 4.6.3
check-only compilation. Native recheck pending; no Web export/publication yet.

Follow-up result: D:/Temp/AshenOath/finish-014-recheck-20261020/native.json,
owned_process.json, stdout.log and stderr.log. GUI PID 12168 exited 1 without
timeout. Peak private commit 799,395,840 bytes (762.36 MiB), 227 successful memory
samples, no memory-query errors. The run also emitted 32 GAME script errors from
the new resource_paths return: a conditional array expression returned untyped
Array where Array[String] is required. This interrupts neighbor preparation;
therefore the apparently improved FPS/memory/startup results are INVALID as an
optimization comparison or acceptance evidence. Strict failures remain; no
performance gain is claimed. The historical valid red baseline remains in force.

Post-run corrections: build a typed Array[String] explicitly before appending
the selected destination, and move path selection into the already-resident
router so prefetch never opens an unmounted campaign script to discover paths.
The dispatcher delegates to that same path map. Check-only compilation and static
diff review pass; these corrections have NOT been runtime-rechecked. No further
native allocation was silently used. Retain the bounded repair as an unverified
working candidate, not a formally approved performance improvement.

Precise next action: obtain one replacement native recheck for the corrected
destination-scoped dependency change, without another experiment or new probe.
Do not export/publish, replay unaffected browser/story checks, or weaken limits.
No Godot process remains from the completed run. Final user acceptance remains
pending, with no ticket promoted from these partial/invalid measurements.

Replacement authorization received: the user explicitly allowed ONE replacement
native recheck. It is running on the corrected source with the same graphical
1280x720 Balanced strict verifier, actual owned-process private-memory sampling,
isolated D: scratch and a finite 20-minute watchdog. Evidence directory:
D:/Temp/AshenOath/finish-014-replacement-20261020/. No new probe, profiling,
benchmark configuration, content reduction or acceptance change is introduced.
Result pending; the earlier invalid comparison remains rejected.

Replacement completed: GUI PID 16840 exited 1, no timeout; owned memory sampling
had 358 successful samples and zero query errors. Peak private commit was
815,480,832 bytes (777.70 MiB), still above 450 MiB. No SCRIPT ERROR remained.
The existing anchor-layout warning and ObjectDB shutdown leak warning remain
recorded and unwaived. The native verifier also reported destination-not-playable
failures, not merely numerical target misses. Evidence is diagnostic FAILED,
not accepted functional, performance or release evidence.

Observed average/1% low FPS: Greyfen 26.27/15.87, Wychwood 36.58/13.58,
Wychwood combat 41.30/23.80, Deep Woods 40.24/27.93, mill 52.59/32.22,
Bandit Road 28.74/4.36, marsh 52.52/26.53, Castle court 60.00/36.32,
Record Hall 30.08/26.16, undercroft 60.00/37.10, Hart 46.43/26.28,
Ruins 60.01/42.41. Complete-menu preparation 26,985 ms; prepared New Game
684.05 ms; post-control hydration worst frame 252.355 ms. These cumulative-source
observations are not an isolated causal comparison with the older baseline.

Retention decision: REJECT destination-scoped dispatcher/prefetch candidate.
It does not improve the full experience: warm return 4,225.02 ms versus the valid
historical baseline 330.95 ms; Bandit Road cold 24,155.35 versus 9,371.85 ms;
mill cold 3,348.47 versus 206.83 ms; multiple readiness failures. Removed ONLY
the agent's changes to zone_composition_router.gd and zones/campaign_section.gd
with a scoped manual patch. Static Git comparison confirms both files match
their pre-experiment state. No other cumulative changes or candidate bytes were
discarded. No runtime recheck was silently added after restoration.

Current checkpoint: FINISH-014 remains IMPLEMENTATION INCOMPLETE / STRICT RED.
The approved replacement allocation is consumed; no further experiment, native
run, Web export or deployment has been started. No Godot process remains.
Exact next action for renewed performance work: analyze the retained readiness/
transition and Greyfen frame evidence at the shared resource-ownership level;
do not repeat this dispatcher-only lazy-loading mechanism or treat faster settled
samples as proof when transitions/readiness fail. Any further runtime allocation
must be explicit. All unrelated green evidence remains frozen; user acceptance
is unchanged. Latest valid packaged candidate remains prompt-verbs, unmodified.

2026-10-20 targeted-browser continuation: the native allocation remains consumed
and its failed measurements remain blocking. A focused source/evidence analysis,
repair and one follow-up native measurement was requested asynchronously; no
answer/renewed native authorization is recorded yet. No new performance probe,
renderer experiment, engine rebuild or administrator trace has been launched.

2026-10-20 allocation 1/1 completed: native 1280x720 Balanced, graphical
Compatibility/ANGLE, Intel HD 620; owned Godot GUI PID 16232 exited 1 (no timeout).
Reports: D:/Temp/AshenOath/finish-014-20261020/native.json,
owned_process.json, stdout.log and stderr.log. Strict thresholds were unchanged.
Complete menu preparation 38,794 ms; prepared New Game 704.18 ms; warm return
330.95 ms. Peak private commit was 868,786,176 bytes (828.54 MiB), measured from
the actual GUI process with GetProcessMemoryInfo/PeakPagefileUsage, not the console
launcher or Godot's static allocation counter. The <450 MiB requirement FAILED.

Average / 1% low FPS: Greyfen 15.71/11.27; Wychwood 22.94/13.47;
Wychwood combat 21.89/6.30; Deep Woods 29.68/16.40; mill 31.75/19.12;
Bandit Road 22.95/10.68; marsh 34.08/22.13; Castle court 24.27/13.43;
Record Hall 38.41/25.90; undercroft 41.25/20.97; Hart Glade 34.61/19.02;
Ruins 46.74/28.44. Greyfen post-control hydration 1% low was 2.1 FPS.
Several cold transitions exceeded 900 ms. These are release-blocking numerical
failures under this ticket, not waived functional-candidate limitations.

GAME defects additionally exposed by this run: Deep Woods/mill arrivals still
referenced the removed CampaignWildernessSection property; the Hartlands-to-Ruins
road had no compiled prepared mesh. The fixes restore a demand-loaded property
and add the exact retained road specification to offline geometry compilation.
They do not reduce content, quality or population. A replacement production
package is required for these real source/resource changes. No second benchmark
is authorized by the consumed 1/1 allocation; no performance improvement is claimed.
ObjectDB shutdown warning remains recorded, not silently waived.

User acceptance and complete prescribed native/controlled-network measurements:
Pending. The authorized final Chrome attempt on finish-line-20261019-oils supplied
partial current observations, not strict acceptance: navigation-to-menu 45,714.5 ms,
navigation-to-control 47,478 ms and click-to-control 1,226 ms. Hardware renderer was
ANGLE / Intel HD Graphics 620 / D3D11 at 1280x720 Balanced. Reported rolling-window
minima were Greyfen 15.80 average / 10.81 1% low FPS and Wychwood 16.29 / 10.93.
These minima are not whole-zone aggregate averages. No controlled cold/warm network
pair or native private-memory measurement was produced. The route stopped at a
driver dialogue activation failure; no performance redesign or benchmark rerun
followed. Report: D:/Temp/AshenOath/finish-line-20261019-replacement-run/browser.json.
The retained strict targets remain unchanged; this evidence does not close the ticket.

