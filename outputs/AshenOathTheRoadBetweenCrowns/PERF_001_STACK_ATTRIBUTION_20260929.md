# PERF-001 Native Stack Attribution

Status: diagnostic evidence, not performance acceptance. Recovery remains
27/37 accepted. All gameplay, rendering quality and timing thresholds remain
unchanged.

## Observed Ownership

One owned graphical Greyfen process was sampled at 200 ms intervals using
Windows thread contexts and DbgHelp stack unwinding. The sampler selects the
original main thread and the two threads with the largest CPU deltas. Handles
are retained; no system-wide trace, administrator access or symbol download is
used. Every temporary thread suspension is paired with ResumeThread in finally.

Evidence directory: `D:/Temp/AshenOath/perf_stack_owner_20260929/`.
It contains the source hashes, frame/stage timestamps, raw stack addresses,
module map, compiler-cache inventory, logs and owned exit record.

- 556 stacks over 53.503 seconds; total suspended time 2,904.314 ms, maximum
  individual suspension 168.001 ms. These overheads prohibit FPS acceptance.
- Four active worker threads repeatedly contain `d3dcompiler_47.dll` frames:
  85 captured stacks in total. Several full stacks return from that compiler
  into the statically linked ANGLE portion of the Godot executable.
- The 2,153 ms gate-visual frame includes three distinct sampled compiler
  stacks. Long menu frames (14,537 and 7,500 ms) show repeated waits, compiler
  work and Intel driver activity. This establishes compilation during the
  observed stalls; it does not assign every millisecond to the compiler.
- The verifier exits 1 and retains all failed limits. No timing from this
  instrumented run replaces existing uninstrumented evidence.

The two failed WPR attempts remain closed. The new evidence changes the next
action from general publication scheduling to a specific compilation policy.

## Source-Backed Mechanism

Godot's GLES3 `ShaderGLES3::_initialize_version` eagerly compiles all four
scene modes at their default specialization before the requested specialization
is bound. `_version_bind_shader` already has a synchronous compile-on-miss path.
The saved SceneShaderGLES3 caches contain 98 programs across 15 material shader
versions: 60 have default key 5243152 (four per version), and 38 have requested
specialization keys. The observed final scene does not request that default key.

Sources:

- https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/shader_gles3.cpp
- https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/shader_gles3.h
- https://github.com/google/angle/blob/aaebda1c5a40/src/libANGLE/renderer/d3d/ProgramD3D.cpp

An additional cheap inspection of the preserved static scene found seven mesh
format records, largely the same position/normal/tangent/UV layout with optional
vertex colors and compression. No geometry-format rewrite follows: the eager
default-program cost has stronger direct source and cache evidence.

## Bounded Candidate

Build pristine and modified native engines from the same official 4.6.3 source
commit, `35e80b3a8822a9df9be390814b62f44c0a9c69e8`. The existing executable
reports `7d41c59c4`, which the upstream commit API did not resolve. Therefore the
new baseline cannot silently be treated as the identical old executable.

The only proposed engine change is to initialize empty variant maps and compile
the requested specialization through the existing bind path. Keep shader source,
variant definitions, shader errors, material semantics, mesh inputs, scene content
and cache identity intact. An old cache remains readable; a newly created cache
may contain only requested variants. Source build and compiler remain isolated
under `D:/Temp/AshenOath/perf_lazy_shader_build_20260929/`.

Next: inspect exact 4.6.3 source, prepare the smallest eager-versus-demand patch,
build both engines with identical options, then run one isolated native comparison.
Reject any missing shader, changed image or displaced stall. Only an improvement
across startup, first control and settled play justifies further acceptance work.
No engine replacement or Web export is accepted by this diagnostic record.
