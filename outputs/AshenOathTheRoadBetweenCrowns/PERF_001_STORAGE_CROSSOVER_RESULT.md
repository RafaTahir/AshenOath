# PERF-001 Cache-Location Crossover - 2026-09-28

## Governing Metrics At This Checkpoint

These are current-source native 1280x720 Balanced Compatibility diagnostics,
not an accepted performance gate. D1 and D2 used the same final scene with
253 settled draws; they were sequential, not a causal cold/warm A/B test.

| Required window | D1 cold-profile observation | D2 warm-profile observation | Release status |
| --- | ---: | ---: | --- |
| Greyfen preparation | 34,342 ms | 1,768 ms | Cold exceeds 15,000 ms |
| New Game request to ready | 36.0 ms | 15.9 ms | This handoff alone passes |
| First-visible hydration average | 26.18 FPS | 38.73 FPS | D1 below 32 |
| First-visible hydration 1% low | 1.04 FPS | 20.95 FPS | Both below 30 |
| Settled Greyfen average | 31.49 FPS | 35.95 FPS | D1 below 32 |
| Settled Greyfen 1% low | 20.79 FPS | 21.60 FPS | Both below 30 |
| Worst observed hydration frame | 1,527.0 ms | 49.8 ms | D1 catastrophic |
| Static scene memory | 83.86 MB | 83.82 MB | Not total runtime memory |
| Total runtime memory | Not measured by these runs | Not measured | Unknown, not passed |
| Warm/cold transition | Not measured by these runs | Not measured | Prior current-source campaign arrivals exceed 350/900 ms |

The governing failure is cold first-visible work, followed by the sustained
hydration and settled low. Existing factored static-scene tests show that a
new mesh reference can add about 200 ms at first draw while a resident one
does not, but they do not prove that all 1,527 ms full-game stalls are mesh
uploads. CPU/wall traces leave some waits unowned; shader/driver compilation
remains the strongest alternative. Simple yielding, whole-scene pre-draw,
shader-family adaptation, light-array tuning, cache relocation/toggling and
VSync toggling have each failed the combined target. No production rendering
setting is changed or threshold relaxed by this table.

## Decision

Moving only the isolated Godot shader cache and QA profile from the D: USB
drive to the C: SSD is **not a sufficient performance fix**. PERF-001 remains
pending, and the formal recovery count remains 27/37. No renderer setting,
gameplay source, verifier threshold, Web artifact or production build changed.

## Controlled Native Scope

Two isolated projects under
`D:/Temp/AshenOath/perf_storage_crossover_20260928_v1/` use the same junctioned
source/imported resources on D: and byte-matched root configuration. Both
started with 114 shader-cache files / 9,459,956 bytes. The D fixture used a
D: shader cache and profile; the C fixture used only
`C:/Temp/AshenOath/perf_storage_crossover_20260928_v1/cache_C` and `profile_C`
on the SSD. Both used D: for TEMP/TMP and reports. The user explicitly
authorized this one temporary C: cache/profile comparison.

Current source hashes: `project.godot`
`DFDD02E4BF7F67E43947539B7296272BF614ADBE7D3321FF84CF65BE22170529`,
`runtime_pack_manifest.json`
`F758DDDFBF305239D7717CB12330F0BC0651E6E685ABA1257C2895D3A4FEC673`,
`scripts/game.gd`
`C666D99643F6D389B55953E7875DBEAF6B1AD1220EDC8591D3AA13FE18322C65`,
and `tools/verify_perf_001.gd`
`60585B7F49B76EF682C909A372457C85CC82989DEA5DD4815BF9E2FDC9D913EF`.

| Run | Cache/profile | Greyfen prewarm | Hydration avg / 1% low | Settled avg / 1% low |
| --- | --- | ---: | ---: | ---: |
| D1 | D: fresh | 34,342 ms | 26.18 / 1.04 FPS | 31.49 / 20.79 FPS |
| C1 | C: fresh | 20,742 ms | 25.74 / 0.92 FPS | 29.37 / 20.17 FPS |
| D2 | D: warm | 1,768 ms | 38.73 / 20.95 FPS | 35.95 / 21.60 FPS |
| C2 | C: warm | 1,764 ms | 35.41 / 17.94 FPS | 34.60 / 20.92 FPS |

All four runs retained 253 settled draws, completed with owned exit 1 on the
unchanged FPS assertions, and emitted no unrelated parser, renderer, resource
or shutdown errors. Cold D1/C1 are sequential and cannot establish a causal
13.6-second SSD improvement because driver-global cache and warm-up were not
controlled. Warm D2/C2 have almost identical prewarm times and both remain
well below the required 30 FPS 1% low. This rejects cache placement as the
release intervention; it does not identify the exact GPU/driver wait owner.

The separate fully hydrated static-frame A/B/A diagnostic at
`D:/Temp/AshenOath/greyfen_static_frame_20260928.json` held 253 draws and
temporarily disabled script updates on 1,094 nodes. Average FPS increased,
but the 1% low remained 26.12 / 27.23 / 27.26 across live/frozen/restored
phases. Ordinary script polling is not a sufficient explanation either.

## Evidence And Cleanup

The four complete logs (`D1.log`, `C1.log`, `D2.log`, `C2.log`) and per-fixture
reports remain on D:. The C: fixture contains only temporary cache/profile
data. Cleanup was attempted after confirming the exact junction target and
that the C: subtree had no reparse points. The command execution policy
rejected both the verified recursive cleanup and a separate link-only
`Remove-Item`; no alternative deletion mechanism was used. The D: fixture's
`project_C/.godot/shader_cache` junction and the exact C: directory named
above therefore remain for manual cleanup. They are **not** a second source
repository and do not touch the rollback copy.

Next PERF-001 action: use the retained native render-stage/worker evidence to
choose one systemic renderer/first-visible intervention distinct from the
already rejected residency, exact-material batching, shader-family toggles,
light-capacity and cache-location classes. Prove it natively against the
unchanged 32/30 FPS, 750-ms New Game, 350/900-ms transition and 15-second
cold-start limits before any Web export. No commit, push or deployment.
