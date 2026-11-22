# Opening Presence - Local Completion Checkpoint

Date: 2026-10-03. State: **LOCAL IMPLEMENTATION AND SCOPED VERIFICATION COMPLETE; NOT PUBLISHED**.

## Current Resume Checkpoint

Recovery-004 remains 37/37 for shipped V10 under its functional-candidate scope. The post-release opening pass remains separate and uncommitted. No publication is claimed.

The missing earned-save fixture is resolved: real mouse New Game, keyboard movement and Pause/Save created a manual slot under D:/Temp/AshenOath/opening_presence/route_profile. A new process restored exact story, full inventory and location through Continue with no unused New Game prewarm (2,643 ms observed); explicit New Game with a save passed (2,089 ms). Initial equality failures were HARNESS: JSON float counters versus restored integer counters, corrected by comparing both full values in the same JSON domain. No save data or gameplay was changed to pass.

Current native source also passes physical footstep/attack/Oathfire/pause audio synchronization; real opening input through Anwen, three clues, both bridges, all five enemies, 19 spatial contact sounds, return report and manual save; consequence/routine tests; wrapped clue text and menu layout tests. Final current route log: D:/Temp/AshenOath/opening_presence/story_contact_final.log. Two real-input clue screenshots from 2026-10-03_040632 and 040634 were inspected: readable text, no prompt overlap, retained characters/routes. The historical failures below remain evidence, not the current blocker.

Local export: D:/Temp/AshenOath/opening_presence/web_20261003; 15 files, 86.3 MiB; root PCK 5e9110e0b1678e9abec0d41e40809174daec15e8b92938e7d77f44e2a1acbc80. Export and pack integrity checks pass. Generated runtime manifests describe the dirty source candidate, not V10 production.

Chrome completed real New Game, the opening route/five-enemy fight, report, settings changes, pause/resize and durable manual Save, then failed on reload: Continue was not visible. Report: D:/Temp/AshenOath/opening_presence/chrome_20261003.json. This is a GAME regression in this local pass, not the initially suspected driver readiness predicate: new_game_ready was true, but the new skip-prewarm path never uncovered the Godot menu or signaled HTML readiness. The failure screenshot shows the loading shell still covering the menu. No browser driver change was made.

The surgical fix retains skipped world construction but restores the existing drawn-menu handoff before publishing Web readiness. Targeted native Continue passes with visible button and exact saved state (continue_handoff.log, 4,281 ms observed). Replacement production-preset export: D:/Temp/AshenOath/opening_presence/web_handoff_20261003; 15 files, 90,538,219 bytes; root PCK 7566f68a43dad7fd4da9fb7520d5ef7fd746772cb20dee9a5ae0e069c528cb09. Export and pack integrity pass. Previous bytes and failed report remain preserved.

Chrome and Edge both PASS the existing production-read-only compatibility smoke on those exact replacement bytes: actual mouse New Game, keyboard movement, pause-menu Save, durable IndexedDB content, page reload, visible Continue, restored story/quests/inventory/settings/location, audio unlock and keyboard control. Reports: chrome_handoff_20261003.json and edge_handoff_20261003.json under D:/Temp/AshenOath/opening_presence. No console warnings/errors or network failures. Both final 1280x720 gameplay screenshots were inspected: no loading cover, complete visible hero and intact road/bridge scene. Test profiles were cleaned and their absence verified. No test process remains in flight.

Scope boundary: replacement smokes used startup-earned saves; the earlier completed opening route is dependency-valid partial evidence, not a newly passed whole-route report on replacement bytes. The earlier run changed settings and verified durable storage before its failed reload; replacement smokes compare saved settings after reload without repeating remapping changes. Firefox was not rerun for this local pass. No full campaign, new performance certification or listening approval is claimed.

Disclosed observations: Chrome cold navigation/control 25,918 ms, New Game click/control 858 ms, warm Continue navigation/control 12,444 ms (click/control 6,420 ms), renderer private memory 526.8 MB. Edge corresponding values: 12,044 ms, 465 ms, 26,715 ms (19,789 ms), 561.3 MB. These single local measurements still miss original targets; no browser speed improvement is claimed.

Exact next action: no implementation or verification remains within this bounded local pass. Retain the uncommitted work and these results for the next user-directed step. No commit, push, merge or deployment was performed; tracked web/ and production remain V10. Broader monster/campaign/voice recommendations were not silently treated as completed work.

## Historical Pause Record

## Ownership and Count

- Active work: `OPENING-PRESENCE-001`, a working label for the requested post-release first-20-minutes improvement pass, not a new recovery ticket or accepted release.
- Recovery-004 remains 37/37 under functional_candidate / lean_functional_smoke. No new acceptance is claimed for this pass.
- Canonical repository: D:/Projects/AshenOath; branch codex/masterpiece-rebuild. Last checked HEAD: 59ca3893976976069390bf79c4f7a02dbd41d198.
- Production remains the previously verified V10. Current working changes have not been exported, committed, pushed, merged or deployed.

## Preserved Implementation

- scripts/game.gd: skip automatic unused New Game prewarm when a Continue slot exists; explicit queued New Game still prewarms. Personal observations for the five existing opening clues. Sword-hit sound now uses the actual spatial contact point.
- data/dialogue.json: personal details linking Bram, Sella and Oren to Anwen, Mira and Rook. Updated Anwen lines use subtitles without mismatched old scratch-voice IDs. No new voice recording or listening approval.
- scripts/greyfen_life_controller.gd: occupation-specific victim recollections; report-specific nearby lines; longer saved-consequence work pauses, quiet forge/shrine reactions; respect dialogue-facing locks. Existing paths, actor population and models preserved.
- scripts/dialogue_runtime_coordinator.gd: stage all skeletal speakers, not just Anwen, and suspend work pose during conversation.
- scripts/zones/greyfen_section.gd: two retained tree species and varied silhouettes at the same grounded non-colliding horizon positions and population.
- scripts/wychwood_terrain_presentation.gd: warmer worn-earth route/clearing against cooler forest floor; no collision change.
- Tooling: focused opening-presence test; extended dialogue regression assertions; three-view capture option; Continue/New Game-from-save test using actual menu mouse input and read-only state checks.
- All these are retained working changes, not blanket acceptance of every proposed creative improvement.

## Evidence

Passed:
- verify_quest_008.gd: all 120 evidence orders.
- verify_opening_presence.gd: victim lines, public/private/retained outcomes, story save round trip, noncompounding routine durations, unchanged paths, pose release and dialogue lock.
- verify_dialogue_runtime_coordinator.gd: original conversation checks plus non-Anwen worker pose/lock/release.
- verify_greyfen_horizon.gd: adjoining ground, grounding, population and collision separation (structural evidence only).
- verify_audio_001_authored.gd: authored audio and existing footstep/pause contracts. Not subjective listening approval.
- verify_combat_005.gd: existing contact contract (structural evidence, not complete real-input combat).
- git diff --check: no whitespace errors; line-ending conversion warnings only.

Graphical Compatibility/ANGLE, Intel HD 620:
- First capture attempt exited 1 on the existing 10-second complete-dressing wait. Retain this failed attempt as a cold-preparation limitation.
- The scoped art capture subsequently waited for complete Greyfen dressing with a finite 60-second art-readiness watchdog, without changing gameplay/performance gates. Capture exited 0. Images were inspected for the changed horizon and ground treatment; this is staged composition evidence, not route completion or a whole-world artistic upgrade.
- Fresh 1280x720 images in Development_Gallery/screenshots/:
  - Capture_01_greyfen_spawn_2026-10-03_033337.png
  - Capture_opening_wychwood_approach_2026-10-03_033337.png
  - Capture_10_combat_clearing_2026-10-03_033337.png
- verify_wychwood_combat_native.gd passed New Game, both Greyfen bridge banks, Anwen approach/dialogue/close and the Wychwood transition, then exited 1 on movement timeout at the first Wychwood layby, around (0.03, 0.37, 12.93). Input was forward, no reported collision/renderer/resource error. Owner is not proven; do not describe the complete route/combat/report as passed or launch a new collision investigation from this result alone. Log: D:/Temp/AshenOath/opening_presence/route.log.

## Last Atomic Operation

verify_continue_intent.gd finished with exit 1:

> This check needs a save earned by a previous player-input run.

Classification: **HARNESS / missing earned-save fixture**, not demonstrated save corruption or a Continue game defect. The prior incomplete route did not leave the required valid save. Continue was not clicked and no click-to-control improvement is measured yet. Log: D:/Temp/AshenOath/opening_presence/continue.log.

The test process exited and its game shutdown completed. Other native sessions started in this pass also finished. No temporary process requires termination; profiles, logs and images are preserved.

## Precise Next Action After Explicit Resume

Earn a manual save through real New Game, movement, Pause and Save inputs in the existing isolated profile at D:/Temp/AshenOath/opening_presence/route_profile. Verify that slot exists and parses, without manufacturing quest/inventory flags. Restart using that same profile and run verify_continue_intent.gd to prove that the menu skips unused prewarm and actual Continue restores the earned story/inventory/location. Then use its --new-game-from-save case to verify explicit New Game still starts with a save present.

Use the retained Godot 4.6.3 executable at D:/Temp/AshenOath/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe, project path D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns, graphical gl_compatibility / opengl3_angle, 1280x720. Set process-local APPDATA to the route_profile above, LOCALAPPDATA to D:/Temp/AshenOath/opening_presence/Local and TEMP/TMP to D:/Temp/AshenOath. Do not change global environment variables or touch actual user saves.

After that focused proof, complete only directly affected input/combat/audio and presentation checks. Browser timing, current-source Web verification, mix listening, and final acceptance remain unproven. Do not claim a faster production Continue from the source edit alone. Preserve V10 production and its original release records until a separately verified replacement is authorized for publication.

The pause recorded above was explicitly superseded by the user's subsequent Continue instruction.
