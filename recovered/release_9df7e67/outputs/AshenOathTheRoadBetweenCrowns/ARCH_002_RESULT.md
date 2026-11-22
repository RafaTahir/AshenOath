# ARCH-002 Event-Driven Runtime Updates

Status: accepted 2026-09-27 for measured redundant script-work removal and affected behavior preservation. Overall recovery/release remains NO-GO.

## Changes

- Touch controls no longer rebuild eleven-action layout dictionaries and redraw every idle frame. Settings and resize update geometry; menu, dialogue, inventory and input-context signals coalesce visibility updates. Paused minigames release held movement and restore controls when closed. Portrait rotation releases held input.
- Greyfen routine actors read report/bell story state only after StoryState.changed, coalescing updates and retaining invalidation while paused. Reconfiguration disconnects the old subscription. The existing 8/15 Hz routine simulation, population, routes, animations and quality behavior are unchanged.
- The earlier movement-gated recovery occupancy checkpoint remains retained at its recorded scope. No controller or authored actor was removed or slowed to obtain performance.
- Focused portable fixtures compare the actual retained old polling bodies with the new signal-based behavior. Tests are registered in targeted and authoritative runners.

## Measured Evidence

All logs are under D:/Temp/AshenOath.

- arch002_touch_unit_context_v1.log: original 6000 idle callbacks cost 65711, 66031 and 57673 microseconds. New controls perform zero process callbacks and zero layout rebuilds across 40 actual idle frames. Identical layout positions/radii, menu/dialogue/inventory, minigame pause/release, settings and rotation pass.
- arch002_life_unit_final_v2.log: original 1000 unchanged story ticks perform 2000 flag reads and cost 18968 microseconds; new ticks perform zero reads and cost 5004 microseconds. Coalesced changes, pause/resume and one subscription after reconfiguration pass. These are isolated script-work measurements, not graphical FPS claims.
- arch002_life_logic_v1.log: current actual-main-scene routine population, nearby visibility, minigames, story persistence and Potato rebuild pass with clean shutdown. Headless proof is limited to logic.
- arch002_mobile_context_v2.log and stderr: graphical 720p current-main touch layout, actions, prompts, settings, menus and actual minigame open/close pass; exit 0 with ANGLE advisory only.
- arch002_opening_final_v1.log: actual keyboard New Game, bridge, Anwen dialogue, Wychwood clues/fight/return/report and cemetery interactions pass up to chapel opening. The complete run FAILS the subsequent shrine approach at CrowChapelFacadeSouthCollision/BellPostCollision. It is retained as partial affected-behavior evidence, not a complete passing route.

## Unresolved Boundaries

The graphical Greyfen-life fixture fails its unchanged 30-second hydration limit (arch002_life_graphical_v1.log). The mobile fixture takes 27560.5 ms to start. PERF-001 remains red; neither latency nor FPS acceptance is claimed. The shrine driver needs a source-safe approach around the chapel pier, not relaxed collision or a larger timeout. Full campaign, current browser parity, world visuals and final certification remain separate pending contracts.

No new screenshot style or actor appearance is claimed: touch geometry is unchanged and checked against the original layout; no world/character composition changed. No Web export, commit, push, merge or deployment was performed.

## Running Steps

From D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns, run Godot 4.6.3 --headless --path . --script res://tools/verify_event_driven_touch.gd or res://tools/verify_event_driven_life.gd. Graphical integration uses --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/verify_mobile_001.gd. Use child-only APPDATA/LOCALAPPDATA under D:/Temp/AshenOath, leaving player saves and global environment unchanged.

Checkpoint: cumulative uncommitted codex/masterpiece-rebuild at HEAD 5b530361a5aae8612626532287b5bd27d7b244b8. Production unchanged.
