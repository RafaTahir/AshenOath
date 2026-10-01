# World Surface Mipmap Correction

Retained visual correction; no ticket acceptance. Recovery remains 27/37.

The shared world library requested mipmapped anisotropic filtering, while all
21 world PBR image imports disabled mipmap generation. Enabled mipmaps for the
seven albedo/normal/ORM sets without changing original images, dimensions,
compression, material colors, geometry, population or lighting. Existing
512-pixel normal/ORM import limits are preserved. The import policies are now
eligible for Git tracking so a clean checkout can reproduce this behavior.

The four 1280x720 captures in each of these directories completed with exit 0:

- `.release-gate/world_mipmaps_before_20260930/`
- `.release-gate/world_mipmaps_after_20260930/`

Spawn and close architecture review shows reduced distant ground, road and
timber speckling with retained close surface detail. Actor/cloud animation and
camera settling differ slightly between runs, so these are same configured
camera comparisons, not pixel-identical image experiments. Horizon, character,
world composition and full PRES-001 acceptance remain unresolved.

`verify_mat_003.gd` now checks actual imported mip chains and image dimensions
against each existing import policy. It passes after correcting the fixture's
Vector2/Vector2i comparison and accounting for the existing normal/ORM limits.
Logs: `D:/Temp/AshenOath/world_mipmaps_contract_20260930.log` and
`world_mipmaps_import_20260930.log` (21 texture reimports, exit 0).

The targeted graphical native Balanced 1280x720 run remains red:

| Window | Average FPS | 1% low FPS |
|---|---:|---:|
| Hydration | 35.66 | 7.64 |
| Settled Greyfen | 26.96 | 22.58 |

Hydration worst frame: 155.379 ms. Settled draw count: 252; static allocation:
84,280,249 bytes (not total process memory). New Game handoff: 42.677 ms.
Owned verifier exit: 1, three failed FPS assertions. This single warm-profile
run supplies no causal performance comparison or cold-start acceptance.
Report/log: `D:/Temp/AshenOath/world_mipmaps_perf_20260930.json` and `.log`.

The restricted host emitted `Failed to read the root certificate store` during
Godot initialization; it is retained in the logs, not silently suppressed or
called a clean release run. The first capture attempt failed opening the
default user log, before rendering. Subsequent commands used a process-local
APPDATA under `D:/Temp/AshenOath/world_mipmaps_20260930/AppData`, with TEMP/TMP
under D: and no global environment change.

No Web export, commit, push, merge or deployment. Next PERF-001 action: use
the existing engine source/timing evidence to distinguish GPU execution cost
from ANGLE submission time before another runtime candidate. Do not treat
mipmaps as the solution to cold shader linking or repeat per-object prewarm.

The existing Godot source's `drivers/gles3/storage/utilities.cpp` only issues
GPU timestamp queries inside `RasterizerGLES3::is_gles_over_gl()`. This run uses
ANGLE/OpenGL ES, so the built-in profiler cannot establish GPU duration here.
Next discriminating step: establish ANGLE timer-query support and collect
asynchronous GPU duration alongside CPU submission in one isolated native
diagnostic. Do not interpret unset built-in GPU values as zero GPU cost.
