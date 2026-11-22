# PERF-001 Native Phase Attribution

Status: diagnostic only. Recovery remains **27/37 accepted**. No game source,
renderer setting, export, or production artifact changed.

An isolated Godot 4.6.3 demand-compilation build under
`D:/Temp/AshenOath/perf_lazy_shader_build_20260929/` recorded the time spent
in scene processing, render synchronization, drawing, and shader
compilation/linking. Its one cold graphical Greyfen run used native 1280x720
Balanced Compatibility/ANGLE and the unchanged targeted verifier. The owned
Godot process exited 1 on the existing FPS assertions. The wrapper exited 0
only because it successfully captured that result.

Evidence: `runs/demand_cold_99/stdout.log`, `stderr.log`, `report.json`,
`summary.json`, and `phase_build.log` under that isolated directory.
Instrumented engine executable SHA-256:
`f7f00e72666f9a379b8419604361562173d843499357de308c3e9acf6053da51`.

| Window | Slow frames sampled | Scene time | Draw time | Measured shader time |
| --- | ---: | ---: | ---: | ---: |
| Boot, before menu ready | 3 | 0.41 s | 23.83 s | 11.86 s across 49 links |
| Post-menu hydration | 14 | 2.26 s | 4.10 s | 0.88 s across 3 links |
| Settled/shutdown tail | 3 | 1.01 s | 0.07 s | none above 20 ms |

Only frames exceeding 100 ms and shader calls exceeding 20 ms are printed;
the totals are not whole-window CPU totals. Shader calls nest within draw
time and **must not be added to it**. Of the 12.74 seconds of recorded shader
work, 12.09 seconds occurred in program linking rather than vertex/fragment
source compilation. The largest boot frame spent 17.51 of 17.71 seconds in
`RenderingServer::draw`; shader calls in that interval account for only
part of it. A 789 ms hydration draw includes two measured shader links, while
several other slow draws have no recorded shader call. Other hydration frames
spend over 200 ms in scene processing even though their named detail builders
report single-digit milliseconds.

Godot's `Performance.TIME_PROCESS` is a per-second maximum covering main-loop
processing **and render sync/draw** in this engine build. The old
`process_ms` field cannot attribute a slow frame to gameplay script or the
adjacent named detail stage. This source-level correction explains why the
prior stage-by-stage prewarm experiments displaced rather than removed spikes.

The diagnostic run itself failed hydration at **12.78 average / 0.98 FPS 1%
low**, worst frame **1,045.5 ms**. Settled Greyfen also failed its low at
**37.34 average / 7.77 FPS 1% low**. These instrumented numbers are not release
benchmarks, but the result plainly does not justify adopting the demand-only
engine variant.

Decision: shader linking is a major contributor to cold boot; it is not the
exclusive cause of hydration or settled slow frames. The next PERF-001
implementation must address shared first-visible draw/resource ownership
without reducing final scene content, moving the stall into a hidden phase,
or relying on the rejected demand-only patch. Freeze the current diagnostic
artifact. Finish independent world-art cells before any new final-content
performance acceptance. No Web export while native PERF-001 remains red.
