# Opening Presence 001 - Local Improvement Pass

Date: 2026-10-03. Branch: codex/masterpiece-rebuild. Base HEAD: 59ca3893976976069390bf79c4f7a02dbd41d198.

This is a bounded post-release opening pass, not another Recovery-004 ticket or a new production certification. Recovery-004's 37/37 V10 acceptance and disclosed performance/listening limitations remain unchanged.

## Changes

- game.gd: returning players no longer build an unused New Game world behind Continue. Their menu still draws before releasing the HTML boot cover; the initial missing handoff was caught in Chrome and repaired. Explicit New Game still queues and prewarms normally. Sword-hit audio originates at resolved blade contact. Personal clue observations replace the old messages in the actual interaction path, not an earlier overwritten handler.
- dialogue.json: Anwen, Mira and Rook connect Bram, Sella and Oren to everyday village memories. Changed Anwen lines use subtitle-only fallback, with no mismatched scratch recording.
- dialogue_runtime_coordinator.gd: skeletal speakers suspend work during conversation and release facing/pose afterward.
- greyfen_life_controller.gd: occupation-specific memories and saved report consequences affect existing lines and work pauses. Public reports quiet the forge; private reports change shrine attention. Nearby helpers stop hammering when addressing Kael. Paths, population and models remain intact.
- hud.gd: the five personal clue observations receive 5.5 seconds; normal short notices keep their existing duration. Wrapped text fits beside, rather than over, the bottom interaction prompt.
- zones/greyfen_section.gd and wychwood_terrain_presentation.gd: mixed retained tree silhouettes and warmer worn-earth paths. No new assets, collision changes or population cuts.
- Targeted tools: verify_continue_intent.gd, verify_opening_presence.gd, verify_dialogue_runtime_coordinator.gd, verify_wychwood_combat_native.gd, verify_hud_005.gd and the scoped screenshot capture. The old HUD assertion was corrected to inspect the authored 1080p menu transform while preserving the shared native-720p render target.
- Generated runtime_pack_manifest.json and runtime_pack_candidates.json bind the local export. Tracked web/ remains V10.

## Verification

Native graphical Compatibility / ANGLE on Intel HD 620 at 1280x720:

| Check | Result |
| --- | --- |
| Real mouse New Game, movement, Pause/Save | PASS; genuine isolated manual save |
| Fresh-process Continue | PASS; exact story, full inventory and saved location; no unused prewarm |
| Explicit New Game with save present | PASS; fresh Road of Crows |
| Forward/backward/sprint footsteps | PASS; physical movement and recorded cue in signal frame |
| Light/heavy/Oathfire and pause/resume | PASS; expected cue timeline and input recovery |
| New Game -> Anwen -> Wychwood clues -> five enemies -> bridge return -> report -> Save | PASS; actual inputs, no flags or teleportation |
| Spatial sword impacts | PASS; 19 real contacts at resolved positions |
| Enemy cues | PASS; five deaths, 19 hits, windup and actual attacks |
| Personal clue text | PASS; actual E interaction and inspected screenshots |
| Saved report reactions and unchanged routine paths | PASS; unit fixtures, not three newly played report branches |
| HUD/menu layout | PASS; wrapping, bounds, prompt separation and correct menu transform |
| Local Web export/pack identity | PASS; 15 files / 86.3 MiB |
| Browser opening route on first local candidate | Completed through fight, return report, settings and durable Save; overall run FAILED on reload's hidden Continue menu |
| Replacement-candidate browser persistence | PASS in Chrome and Edge; real New Game/movement/Save, durable IndexedDB, reload, visible Continue, exact earned state/settings/location and restored input |
| Browser audio, console and network | AudioContext running after input; no console errors/warnings or network failures in either replacement smoke |

Retained dependency-valid tests from the preceding part of this pass: all 120 clue orders, dialogue coordinator, Greyfen horizon, authored-audio and structural contact checks. Staged art images do not prove traversal; the native input route above supplies that evidence.

Observed native click-to-control: Continue 2,643 ms; New Game with existing save 2,089 ms. These are single local observations, not production speed claims or strict performance certification. The final route recorded Wychwood transition 624.3 ms and Greyfen return 382.8 ms; no sustained FPS acceptance is inferred.

After the handoff fix, native Continue passed again at 4,281 ms. Replacement browser observations (single local runs, not controlled improvement comparisons):

| Browser | Cold navigation to control | New Game click to control | Warm Continue navigation / click to control | Renderer private memory |
| --- | --- | --- | --- | --- |
| Chrome | 25,918 ms | 858 ms | 12,444 / 6,420 ms | 526.8 MB |
| Edge | 12,044 ms | 465 ms | 26,715 / 19,789 ms | 561.3 MB |

Original loading/memory targets are not met. Chrome's observed minimum window average was 41.39 FPS, but its minimum 1% low was 11.75 FPS; this is not 32/30 FPS certification. These limitations remain disclosed under the functional-candidate scope, not relabeled as performance success.

## Evidence

Logs and isolated profiles: D:/Temp/AshenOath/opening_presence/. Relevant logs: earn_save.log, continue_earned_normalized.log, new_game_with_save.log, audio_input.log, presence_final.log, story_contact_final.log, hud_final_layout.log and export_20261003.log.

Screenshots in Development_Gallery/screenshots/:
- Capture_01_greyfen_spawn_2026-10-03_033337.png
- Capture_opening_wychwood_approach_2026-10-03_033337.png
- Capture_10_combat_clearing_2026-10-03_033337.png
- OPENING_PRESENCE_black_feathers_2026-10-03_040632.png
- OPENING_PRESENCE_claw_marks_2026-10-03_040634.png

Replacement local production-preset artifact: D:/Temp/AshenOath/opening_presence/web_handoff_20261003; 15 files / 90,538,219 bytes. Root PCK SHA-256: 7566f68a43dad7fd4da9fb7520d5ef7fd746772cb20dee9a5ae0e069c528cb09. Export/pack integrity and Chrome/Edge compatibility smokes pass. The first candidate remains preserved at web_20261003 (PCK 5e9110e0b1678e9abec0d41e40809174daec15e8b92938e7d77f44e2a1acbc80) with its failed overall Chrome report; its completed route is partial evidence only. Between candidates, the only gameplay change is the saved-menu Web handoff, not story, combat, visuals or persistence serialization.

Replacement reports and inspected final gameplay images in D:/Temp/AshenOath/opening_presence/: chrome_handoff_20261003.json, edge_handoff_20261003.json, chrome_handoff_20261003_chrome_final.png, edge_handoff_20261003_edge_final.png. Additional log: continue_handoff.log. The successful Chrome and Edge profiles under D:/Temp/AshenOath were removed by their owned test cleanup; the first failed profile remains for diagnostic evidence. No QA process remains active.

## Limitations

- This does not claim all eight longer-term creative recommendations are finished. New monster behaviors, campaign-wide scene redesign, new voices and human listening approval are not part of this bounded pass.
- No character family was replaced; all existing quests, equipment, population and save-compatible role IDs remain.
- No current-source browser speed claim, complete campaign rerun, new device certification or production deployment yet.
- Replacement smokes earn a fresh startup save, not the earlier post-report save. The first browser opening/fight/report and settings-storage evidence remains partial and dependency-scoped. Remapping changes followed by reload were not repeated on replacement bytes; saved settings equality was checked. Firefox was not rerun in this local pass.
- Historical failed capture readiness, route-driver timeout, absent-save fixture, numeric-type comparison and obsolete HUD assertion are preserved in the scratch logs. They are not silently converted into successful runs.

## Running Steps

From D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns, set process-local APPDATA to D:/Temp/AshenOath/opening_presence/route_profile, LOCALAPPDATA to D:/Temp/AshenOath/opening_presence/Local and TEMP/TMP to D:/Temp/AshenOath. Do not change global environment settings or real player saves.

```powershell
& 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --resolution 1280x720
```

Use New Game or Continue normally. Speak with Anwen, inspect the Wychwood evidence, defeat the five enemies and return. Pause -> Save persists the earned state. Focused test: add --script res://tools/verify_continue_intent.gd; its -- --earn-save mode earns a fixture through input, and -- --new-game-from-save checks deliberate New Game with that fixture.

The passing browser invocation (substitute edge and a distinct report path for Edge) was:

```powershell
& 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' .\tools\verify_qa_002_browser.mjs --export 'D:\Temp\AshenOath\opening_presence\web_handoff_20261003' --report 'D:\Temp\AshenOath\opening_presence\chrome_handoff_20261003.json' --browser chrome --renderer hardware --headed --production-observer --browser-smoke --acceptance-profile functional_candidate --route-timeout 240000
```

Scoped local work is complete. Do not rerun passing checks merely to repeat this record; no browser-driver code was changed for the handoff repair.

Publication authorized by the user on 2026-10-03. The verified 15-file artifact has been synchronized byte-for-byte into tracked web/. Commit, branch/main push and live verification are in progress; no live success is claimed until their receipts pass.
