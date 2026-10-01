# PERF-001 Viewport 3D Discriminant, 2026-09-29

Status: diagnostic only. No source/renderer change is accepted and PERF-001
remains open. The temporary verifier switch was removed after the run.

An isolated native graphical 1280x720 Balanced Compatibility run used the
ordinary game scene and lifecycle, but disabled only 3D drawing on its viewport.
Its owned process exited 0. Report and logs:
`D:/Temp/AshenOath/perf_no3d_discriminant_20260929/`.

| Window | Prior rendered Greyfen | 3D-disabled diagnostic |
| --- | ---: | ---: |
| Menu-covered preparation | 22,926 ms | 705 ms |
| New Game handoff | 27.72 ms | 21.64 ms |
| Post-control hydration | 34.01 average / 1.45 FPS 1% low | 60.11 average / 31.03 FPS 1% low |
| Largest hydration frame | 1,342 ms | 32.45 ms |

The 3D-disabled run still constructed the real Greyfen scene, populated its
actors and interactions, and completed all deferred detail stages. Their
reported build times remained small. Removing the 3D draw path eliminated the
large wall-frame stalls. This is strong evidence that scene construction alone
is not the dominant cause; the 3D render/driver path is implicated. It cannot
yet distinguish shader linking from texture/mesh upload, GL synchronization or
driver scheduling. The comparison used separate process/cache states, so its
exact time ratio is not a controlled production speedup.

The diagnostic has no pixels and cannot satisfy rendered FPS, startup, visual,
browser or release acceptance. Next PERF-001 action: use this attribution and
the retained stage/frame evidence to identify a shared 3D render-state or
resource-submission owner, then test one structural candidate on the unchanged
rendered native gate. Do not retry per-object prewarm, cache toggles, material
normalization, separate render thread or invalid WPR tracing.

A later read-only inventory of these same preserved profiles found 15 Godot
`SceneShaderGLES3` cache files and 125 ANGLE/EGL cache files created during
the rendered run, spanning roughly 32 seconds. The no-3D profile created
zero such files. This strengthens first-use shader/driver work as a hypothesis,
but drawing also triggers mesh and texture uploads, so the cache count is not
a causal attribution of the individual slow frames. No new run or probe was
needed for this inventory.

A follow-up graphical run requested Godot's `opengl3` driver, but the Intel
driver rejected native OpenGL 3.3 and Godot fell back to the same ANGLE/D3D11
Compatibility renderer. The owned targeted Greyfen verifier passed with a
2,220 ms reported prewarm, 53.66/30.39 FPS hydration and 46.46/36.67 FPS
settled. Evidence: `D:/Temp/AshenOath/perf_opengl3_discriminant_20260929/`.
This was a warm-cache same-backend observation, **not** a native-OpenGL A/B or
a cold-start fix. It cannot replace the red cold-rendered evidence. Do not
repeat an `opengl3` comparison on this driver.
