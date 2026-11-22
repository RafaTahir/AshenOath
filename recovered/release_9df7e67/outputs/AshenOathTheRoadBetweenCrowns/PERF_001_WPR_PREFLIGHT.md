# PERF-001 WPR Attribution Preflight

Date: 2026-09-28

## Purpose

Discriminate the remaining cold first-visible failure between scene publication,
driver/compiler work, and external scheduling or storage without another
high-overhead in-game polling probe.

## Result

- `wpr.exe` is available at `C:\Windows\System32\wpr.exe`.
- The built-in CPU, GPU, and Disk I/O profiles are available.
- The current Codex Desktop process is not elevated.
- The bounded preflight command
  `wpr.exe -start CPU -start GPU -start DiskIO -filemode` failed before a
  recording began with Windows error `0xc5585011`: the process could not
  enable the system-performance profiling policy.
- No ETL was created and WPR was not left recording.

## Decision

This is an external tracing prerequisite, not evidence that any PERF-001
hypothesis is correct. Existing rejected prewarm, cache-toggle, batching,
shader-normalization, packed-section, and publication-scheduler experiments
remain rejected. No new performance implementation will be selected until an
elevated bounded trace can attribute CPU/wait/GPU/I/O ownership, or equivalent
low-overhead attribution becomes available.

PERF-001 remains pending with the recorded 1.04 FPS hydration 1% low and 1,527
ms worst frame. Independent finite visual and QA-002 static work may proceed;
no Web export or browser acceptance is permitted while native performance is
red.

## Exact Resume Action

From an elevated Windows session, record one bounded CPU/GPU/Disk I/O trace
covering cold opening hydration and correlate it with the existing frame
timestamps. Analyze that trace before making a structural performance change.
