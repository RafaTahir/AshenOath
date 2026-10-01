# PERF-001 Mapped Wait Ownership And Async Cache Discriminant

Verdict: **diagnostic candidate rejected as a PERF-001 solution**. Formal
acceptance stays 27/37. No engine fork, settings change or cache-disable policy
has entered the project. Production and Web artifacts are unchanged.

## New Evidence

The bounded owned-process stack sampler, mapped against the diagnostic engine's
linker map, identifies three real blocking paths:

- ANGLE program-binary persistence through `EGLManager::_set_cache` and
  `FileAccessWindows::_close`.
- Godot program-binary persistence through `ShaderGLES3::_save_to_cache` and
  `FileAccessWindows::store_buffer`.
- Synchronous redirected log output through `WindowsTerminalLogger::logv` and
  Windows `WriteFile`.

Other snapshots identify ANGLE link-event waits. Phase CPU counters also show
both CPU-active compilation and long low-CPU waits. These are observed owners,
not proof that any one exclusively explains the gameplay stalls. The sampled
run was deliberately terminated after its bounded sampling window and produced
no acceptance report. No WPR rerun or user action was requested.

## Bounded Candidate

Only the isolated D: engine fixture was changed. One worker serializes cache
file I/O outside the render thread, with a 32 MiB queued-data bound, copied
payload ownership, pending in-memory reads, atomic same-directory publication
and explicit shutdown drain. Shader binaries, version-3 GLSC format, shader
variants and complete scene content remain unchanged. The feature is opt-in.

Both comparisons use the same executable, full Greyfen scene, native 1280x720
Balanced verifier and process-local D: profiles. Asynchronous stdout/stderr
pipes preserve complete logs in memory until exit, avoiding synchronous
per-line writes to the redirected D: log file. No errors are suppressed.

| Metric | Synchronous cache | Asynchronous cache |
| --- | ---: | ---: |
| Owned native exit | 1 | 1 |
| Cold preparation logged | 60,656 ms | 21,452 ms |
| Prewarmed New Game | 15.976 ms | 34.656 ms |
| Hydration average FPS | 32.238 | 30.133 |
| Hydration 1% low FPS | 1.065 | 1.036 |
| Worst hydration frame | 1,742.865 ms | 1,835.874 ms |
| Settled average / 1% low FPS | 46.443 / 35.726 | 42.625 / 33.296 |
| Peak working set | 556.86 MiB | 559.55 MiB |
| Sampled peak private allocation | 499.92 MiB | 502.91 MiB |

This is one sequential discriminant, not a controlled repeated improvement
claim. Global driver warming can affect the preparation difference. Both
experiences fail unchanged first-visible performance and startup requirements.
Neither buffered logging nor asynchronous cache persistence fixes the whole
contract. The diagnostic build's static-allocation counter is unavailable and
cannot establish memory acceptance; the real process measurements also exceed
450 MiB. Transition and Web performance proof remain missing.

The candidate drained 199 writes, with zero write failures or budget fallbacks.
An offline cache check found 147 final files: 22 complete version-3 GLSC files
and 125 opaque driver blobs, totaling 12,845,631 bytes; no pending file remained.
That validates serialization/persistence, not render equivalence or acceptance.

## Evidence And Decision

All scratch evidence is under
`D:/Temp/AshenOath/perf_lazy_shader_build_20260929/`:

- `runs/pristine_cold_104/`: phase CPU/I/O pairs and complete red report.
- `runs/blocking_stack_20260930/`: bounded mapped stacks; no completed gate.
- `runs/buffered_sync_20260930/`: synchronous control, complete logs/report.
- `runs/buffered_async_20260930/`: rejected candidate, complete logs/report.
- `async_cache_baseline_20260930/`: pre-candidate cache source backups.
- `async_cache_build_20260930.log`: successful diagnostic compilation.

Compared engine SHA-256:
`8c832b1aaca86aa0f23d7810e9e6e88af0b5e04ab3a21b9e32d69f34ff171684`.

PERF-001 remains implementation incomplete, cause unresolved. Its investigation
allowance was renewed; it is **not** parked because the old allowance expired.
It is parked after the cache/log-I/O mechanism failed to clear the contract,
alongside the already-rejected independent publication/compilation candidates.
Do not repeat this mechanism or promote single-run preparation differences.
Advance independent finite world cells during the remaining active block.
