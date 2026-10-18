# OPT Milestone 9 - OPT-055 through OPT-056

## Implementation

- Immutable boxes, spheres and cylinders share resources keyed by exact type,
  dimensions and margin, without quantization. Bodies, CollisionShape nodes,
  transforms, layers/masks and interaction identities remain independent.
  Weak references leave resource lifetime with the live bodies. Character
  capsules, query/camera probes and runtime-resized shapes remain private.
- Campaign music and ambience caches retire inactive references at ownership
  changes and crossfade completion. Both active/fading players retain streams;
  shared opening/menu cues, active voices and required destination/encounter
  streams stay available. No recording was removed or re-encoded.
- Destination audio prepares within the existing locked transition, inside its
  measured duration, before playback. Failed transitions restore the previous
  destination's audio preparation. Existing mix, ducking, subtitle/voice fallback,
  settings, pause and cue semantics remain unchanged.
- Completes fixed OPT-051/052 compiler coverage for authored roads, Wychwood
  path-edge/rock meshes and canopy/understory/floor buffers at every existing
  quality count. Original formulas, UVs, normals, transforms, materials, collision
  and grouping are preserved. Random/state-dependent overlays remain live-owned;
  no broad scene bake or staged-prewarm experiment was introduced.

## Compilation / Deployment / User Acceptance

The source build compiled successfully, but the first package was 104917323
artifact bytes and was rejected by the unchanged 100 MiB gate. It was not
published. The packager now transports engine JavaScript losslessly with gzip,
matching Vercel headers, a codec-specific immutable engine identity and decoded
size/hash records. No engine code, mesh data or game content is removed or
quantized. Only minimum production export/package retry is required; unchanged
asset builds and runtime packs are reused.

Final production package: `opt-m9-20261019-a85b82e`, selected export at
`D:\Projects\AshenOath\.release-gate\opt-m9-20261019-transport\export`.
Manifest artifacts: 104679928 bytes; complete Web directory: 104687954 bytes,
strictly below 104857600 (169646 bytes headroom).
Root PCK: 6316592 bytes; SHA-256
`f41b0128896fd4acfff1ea29db647889f1122616648463825f4a54a65e05c45d`.
Engine JS: 315759 decoded bytes -> 78364 transport bytes; its decoded SHA-256
matches the prior stock engine script. The complete previous Web directory is
preserved at `.release-gate/opt-m9-20261019-transport/previous-web-complete`.
OPT-056's existing publication receipt records commit, push and Vercel outcome.
Build-only scope:
no agent runtime testing, browser QA, gameplay, screenshots or benchmarks.
No measured gain or user acceptance is claimed by enabling options.

## Manual Checks

1. New Game and Continue; complete Greyfen, bridge and collision clearance.
2. Movement, sword/bow/Oathfire and moving NPC/prop Use on desktop and phone.
3. Wychwood and Castle returns, terrain/foliage and every quality preset.
4. Quest/dial updates, short-screen layout, saved preferences and journey reload.
5. Music/ambience transitions, rapid returns, pause/resume and dialogue audio.
6. Compare `?perf=1` with individual `opt_alpha=0`, `opt_bounds=0` overrides;
   stock Web must report occlusion unsupported even with `opt_occlusion=1`.
