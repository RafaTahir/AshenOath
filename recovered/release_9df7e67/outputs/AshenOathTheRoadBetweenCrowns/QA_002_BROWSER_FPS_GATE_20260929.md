# QA-002 Browser FPS Gate

Status: release-harness correction, not campaign acceptance. Recovery-004
remains 27/37 accepted and production is unchanged.

The release runner's hardware Chrome/Edge/Firefox campaign invocations did
not enable the browser driver's optional FPS check. The final QA-002 assessor
also checked route, artifact, audio and memory but not reported FPS. A browser
route could therefore pass below the required 32 FPS average / 30 FPS 1% low.

All three desktop release-runner paths and the ordinary ticket runner now
request the performance gate explicitly. The driver also defaults a hardware
desktop full-campaign route to enforced performance and rejects an explicit
attempt to turn it off. The final assessor separately requires at least 120
reported frames and both unchanged thresholds for every required desktop
main route. Mobile emulation is not misrepresented as target Dell hardware
performance. Native graphical Compatibility remains a separate mandatory gate.

Targeted tests passed 20/20, including a deliberately low-FPS report. The
affected PowerShell runners parse. This proves report/runner wiring only: no
source-aligned exported game, browser campaign, per-zone sample, or sustained
performance passed. The read-only observer's performance window is currently
rolling, so final certification must retain zone-specific native and browser
evidence rather than treating the ending's last window as whole-campaign FPS.

Both production read-only observation and the QA diagnostic observer now
calculate 1% low as the reciprocal of the average frame time of the slowest
1%, matching `verify_perf_001.gd`. Previously they reported the reciprocal
of the 99th-percentile frame, which could conceal one severe stall. The
isolated native frame-series verifier passes: 198 frames at 60 FPS plus 50 ms
and 100 ms frames yield 13.33 FPS 1% low, not 60 FPS. A direct CLI attempt to
disable hardware full-campaign enforcement exits 1 before launching a browser.

No Web export, commit, push, merge, or deployment occurred.

The route report now retains the lowest observed 600-frame average and 1% low
for each gameplay zone, using every periodic read-only observation. The
production observer resets its rolling frame window at New Game, pauses and
zone changes, and stamps the sample with its owning zone. A sample requires
120 frames, player control, and no pending transition. Hardware desktop
campaign results require Greyfen, Wychwood, Castle courtyard, Record Hall and
Hart Glade; an earlier red zone cannot be concealed by a fast finale. The
candidate assessor checks the same five-zone evidence independently.

The expanded focused JavaScript suite passed 24/24, and the native synthetic
Godot check passed the percentile, zone-reset and pause-reset cases. This is
still harness evidence, not a measured exported-game route. Deep Woods,
combat, startup and transition performance remain separate native gates.
