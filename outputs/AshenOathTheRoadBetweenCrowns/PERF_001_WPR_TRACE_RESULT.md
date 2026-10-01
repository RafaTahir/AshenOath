# PERF-001 WPR Attribution Attempt, 2026-09-29

## Second bounded attempt: invalid, do not repeat

The Light-profile rerun at `D:/Temp/AshenOath/perf_wpr_20260929_013630/`
saved a 1,022,361,600-byte ETL but WPR reported **5,116,020 dropped
events**. The script reported a missing hydration marker, yet the saved Godot
stdout contains that marker followed by the complete targeted verifier result.
This was a marker-observation/redirect flush race during severe trace I/O,
not an absent game phase. The traced run failed its unchanged gates: hydration
5.119 FPS average / 0.319 FPS 1% low, 4,720-ms worst frame; settled Greyfen
26.698 / 16.698 FPS. These values are trace-contaminated diagnostics, not
comparable untraced performance evidence.

Two WPR configurations have now lost enough events to invalidate interval
attribution. No engine, driver, GPU, or disk root cause is inferred. Do not ask
for or run a third WPR capture of this workload. The next discriminant must use
existing frame/stage evidence and a lower-overhead, self-contained mechanism
that does not perturb the first-visible interval at system-wide ETW volume.

## Captured Result

- Elevated trace: `D:/Temp/AshenOath/perf_wpr_20260929_010112/greyfen_cpu_gpu_disk.etl`, 1,892,679,680 bytes.
- WPR reported 681,488 lost events. WPA refuses the trace by default;
  `-tle` produced partial process-level CPU and disk tables, but its profile
  export also reported an error and produced no usable GPU/wait timeline.
- The instrumented native run itself failed unchanged acceptance: Greyfen
  hydration 4.61 FPS average / 0.18 FPS 1% low, with a 5,464 ms worst frame;
  settled Greyfen 27.00 FPS average / 17.76 FPS 1% low. The verbose trace
  added substantial overhead, so these are diagnostic observations, not a
  comparable untraced benchmark or a gameplay regression claim.
- Partial WPA CPU table shows the actual Godot render process (PID 7644)
  received approximately 55.9 seconds of sampled CPU over its 132.4-second
  lifetime. Its disk summary records about 69.7 MB of I/O and 14.4 seconds
  aggregate disk service time across the trace. These whole-process totals
  cannot assign the first-visible stalls to engine publication, driver
  compilation, or storage.

## Decision

No root cause is accepted from this lossy trace and no game-performance
implementation is chosen. The saved ETL, native stdout/stderr, WPA output,
and failed tracerpt log remain under the same D: run directory.

`tools/collect_perf_001_trace.ps1` now uses WPR's Light CPU/GPU/DiskIO
profiles and stops collection at the Greyfen hydration marker. This removes
most of the two-minute settled-run recording that flooded the first trace.
The second attempt above demonstrated that this still floods the trace and
can race stdout flushing. That collection path is closed; the current next
action is the lower-overhead self-contained discriminant stated above. No
Web export, commit, push or deployment follows from either attempt.
