# Opening cast source handoff

This is a source and authored-asset handoff for the combined assets, packaging and loading release requested by the user on 7 November 2026. It is not a published release or visual acceptance record. The previous source/release baseline is `6aa8fdf2ac24f00cbd72c0178d6485d0a548a6db`, retaining its startup fix above the planned `3c05bdf` baseline.

## Authored and integrated

- Anwen, Tor, Mira and Rook each have two native idle variations, occupation, speaking and listening clips: 20 clips in four compiled libraries. Editable Blender sources, reproducible authoring tools, rig/rest/source checks and review images are retained in `art_source/art_recovery_v2/models/living_cast_20261107` and the adjacent evidence/tools directories.
- Existing motion and routine owners handle native clip clocks, contact events, fitted hand/tool probes, interruption, resumption, prop cleanup and supported seated rest. Locomotion remains with the existing owner. Production actor GLBs, collision dimensions, attack clips, damage and timing are unchanged.
- Explicit automatic/actor/point/neutral/sleep attention, full dialogue and shared-scene attention restoration, expression aliases, closed sleeping eyelids and terminal/distance guards use the existing facial owners.
- Anwen has a fitted care table and retained-rig staff binding; Tor strikes the forge surface with the actual hammer head; Mira sorts over a raised drying rack with retained leaves; Rook handles a permanent satchel with attached strap and an event-driven knot. Work props use existing centralized activity updates.
- The asset coverage ledger records the wider live scope. The other eight named NPCs, remaining creature/equipment/scenery improvements and campaign expansion are not complete in this handoff.

## Exact asset set and generation

`stage1_asset_files.json` identifies 71 asset-authoring files by path, size and SHA-256; stage that manifest itself too. Its final verification found no byte/hash mismatches. Compiled runtime additions total **817,771 bytes**; the largest authored source file is **11,690,457 bytes**. These are resource additions, not an exported transport-size measurement.

All source assets and compiled life libraries/station props are present. The maintained builder must preserve this order:

1. `build_living_cast_station_props.gd` before `build_prepared_zone_geometry.gd`.
2. `build_living_cast_libraries.gd` before `build_prepared_actors.gd`.
3. Existing actor dependency generation and final `prepare_runtime_pack_layout.py` after prepared actors.

The four actor libraries are dynamic dependencies recorded by the prepared-actor builder. Greyfen station scene/meshes and `Fern_1.obj` belong to the opening pack. Final prepared scenes, registries, layout, ownership/closure, hashes and Web output must be regenerated/verified in the combined export. Preserve the optional `DevelopmentBranch` argument in builder/publisher; its existing default remains unchanged and `codex/art-recovery-anwen` is supported.

If generation changes asset bytes, run `art_source/art_recovery_v2/tools/update_living_cast_stage1_evidence.py` before final staging. Do not add unrelated historical untracked assets.

## Observed checks

All listed Godot fixtures ran serially, using isolated/disposable fixture storage where applicable:

| Fixture | Result | Scope |
|---|---:|---|
| `verify_living_cast_motion.gd` | PASS 546 | Actual four prepared rigs, native clocks and contact, interruption, eight Anwen story gestures, supported seating |
| `verify_face_attention.gd` | PASS 508 | Attention ownership/restoration, expression controls, sleep/terminal behavior and shared scene claims at both viewport sizes |
| Existing terminal-face regression | PASS | Dead/restored facial lifecycle |
| `verify_living_cast_stations.gd` | PASS 44 | Actual station triangles/support, clearances, bag/strap markers and idempotent construction |
| `verify_greyfen_routine_ownership.gd` | PASS 276 | Routine priorities, reservations and ownership |
| `verify_npc_attention_movement.gd` | PASS 67 | 809 steps and 603 movement/attention queries |
| `verify_living_cast_lifecycle.gd` | PASS 23 | Native restart phase, generated/borrowed props and owner teardown |
| Existing shared-animation playback regression | PASS | Shared animation behavior |
| `verify_living_cast_capture.gd` | PASS 19 | Capture geometry helper; native capture remains a separate requirement |

The final native rig test measured Anwen's staff upright dot product as 1.0, floor-tip error effectively zero and palm/grip distance 0.0433 m throughout eight gestures. Cloth contact error was 0.000108 m; the other actual contact probes were below 0.000001 m. These measurements do not establish natural-looking performance or user acceptance.

Python source/CLI and isolated capture configuration checks, sequence encoder encode/decode/hash/path-escape checks and PowerShell builder/publisher syntax checks passed. Final combined build gates must run against their merged source.

Local logs and intermediate diagnostic receipts are under `.release-gate/living-cast-20261107`, notably `motion/verify_living_cast_motion-r2.log` and `stations-r5.log`.

## Runtime evidence still required

The frozen baseline Web bytes were verified before capture, including all 51 transport files. Native Anwen day/work smoke `D:/Temp/AshenOath/living-cast-baseline-anwen-smoke-r4` completed with isolated data and no fixture failures, but produced only **3 frames in 4.4 seconds**, insufficient to judge motion. Its camera reveals the baseline horizontal staff. Earlier camera/anchor attempts were rejected. No baseline/candidate sequence or performance comparison is accepted from these runs.

`run_living_cast_capture.py` mounts explicit frozen packs and records input hashes, telemetry, contacts and actual sampling rates. `capture_living_cast.gd` and `living_cast_capture_geometry.gd` select a dedicated camera and validate decorative mesh occlusion. Repeated full-scene visibility queries are expensive on this 8 GB/Intel HD 620 host; do not treat the diagnostic sampling rate as gameplay frame time. `encode_living_cast_sequences.py` produces timestamped videos with frame hashes; its native sequences have not yet been generated.

The combined release owner must inspect actual idle/work/approach/dialogue/interruption/resumption at desktop 1280x720 and touch viewport 960x540, including day/night/rain where applicable, with real input flows and matched performance captures. Keep visual acceptance, observed functionality, export/closure verification, publication and deployed identity separate. This handoff has not been pushed or deployed and does not claim those gates passed.

## Future stages remain isolated

Stage 2 conversation drafts are local under `.release-gate/living-cast-20261107/stage2-content`; they are not runtime content. Stage 4 work is isolated in `D:/Temp/AO_LivingCampaign_20261107` on `codex/living-campaign-expansion`, with expansion disabled. Its compatibility core and content drafts do not constitute playable regions or a completed fourteen-chapter campaign. Do not merge that work into this opening-cast release.

The combined release chat owns the next export, test, push and deployment verification. All asset-chat Blender, graphical Godot and headless workers are stopped at handoff; canonical files are frozen after the source commit.
