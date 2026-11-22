# QUEST-001 — Act One Consolidation

## Files Changed
- `data/quests.json`
- `data/dialogue.json`
- `data/campaign_dialogue.json`
- `scripts/game.gd`
- `tools/verify_runtime.gd`
- `tools/verify_quest_001.gd`
- `tools/run_release_gate.ps1`

## Consolidated Flow
- Sister Anwen names Bram, Sella, and Oren before Kael enters Wychwood.
- Five distinct, order-independent clues feed a three-clue evidence threshold.
- Missing clues remain optional and can still be found after the first encounter.
- Once an evidence threshold is met, unresolved optional clues no longer hide the next required objective in the HUD.
- Private, public, and retained-evidence reports persist different consequences.
- Reporting relocates Anwen to the cemetery without skipping the gate meeting.
- Two of three graves reveal the truth and trigger a real cemetery Ghoulkin ambush.
- The chapel remains sealed until that enemy is defeated.
- Opening the chapel reveals a three-way Crow Shrine choice that completes the quest.
- Moon Oil is useful preparation rather than a progression requirement.
- The Bog Wretch leaves a memory core with three consequence choices before Act Two.

## Verification
`tools/verify_quest_001.gd` covers unexpected clue order, threshold progression, reporting, Anwen relocation, cemetery investigation, ambush gating, chapel access, shrine consequences, optional Moon Oil, memory-core consequences, and the Act Two handoff.

The authoritative release gate passed on 2026-07-23:
- 33.2 FPS average and 31.9 FPS minimum at native 1280x720 Balanced.
- 283 ms measured warm transition.
- Fresh route, animation, Greyfen, Wychwood, and cemetery screenshots passed.
- Web export and packed startup passed at 63.9 MB.

Commit and deployment identity are recorded in Git and the live production build.
