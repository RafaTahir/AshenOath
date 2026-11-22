# Ashen Oath — version-two implementation context

## Active direction

Preserve Greyfen, Kael, Anwen, the White Hart, inherited institutional guilt, and monsters as denied testimony. The revised campaign puts a present ration-backed renewal in conflict with freely witnessed responsibility. Core subtitle/dialogue data is version two. Main-route target is 6–8 hours and full route 8–12, not measured duration.

## Present cause

Road repairs expose tokens; Oren restores an older name; Anwen's containment fails; Ghoulkin gather the testimony; Vargan recovery patrols reclaim it. Edric proposes renewed concealment with grain conditional on assent. The assembly removes that condition before voluntary speech.

## Character and canon anchors

Kael's unrelated escort failure was eight years ago. He freely stays after returning with the missing travelers' account. Halvern and returned Len are limited fragments. The Hart remains the only complete supernatural witness. Documents establish facts, never somebody else's consent. Mercy protects vulnerable private memories, not institutional wrongdoing. Duty is willing stewardship. Ash destroys the Hart, not recovered human evidence.

## Authoring sources

- `data/dialogue.json`, `data/campaign_dialogue.json`: playable turns, conditions, previews, costs, actions.
- `data/quests.json`: stable IDs, revised objectives, six deep optional stories and four interludes.
- `data/story_campaign.json`: chapter questions, evidence provenance/gates, decision outcomes, four ending costs.
- `STORY_BIBLE_ASHEN_OATH.md`, `STORY_ARC_FULL_GAME.md`, `CHARACTER_ARCS.md`, `CHOICE_AND_CONSEQUENCE_SYSTEM_PLAN.md`: revised authority.

## Integration flags

`report_decision` explicitly commits `return_village`. Preserve existing legacy report values and record `kael_pledge` and `cemetery_bell_rung`. `mill_operation=closed/supervised/restitution` is separate from ledger `mill_fate`. `witness_consent_*` supplies voluntary/refused/compelled facts; protected Rook is voluntary with `rook_disclosure=protected`. `kael_confessed`, `command_proof_recovered`, `renewal_announced`, and `renewal_stopped` establish main-path progress. Unknown historic choices stay unknown.

## Scope

Reuse existing authored regions, objectives, actors, enemies, crafting, world flags, and save system. Read the active brief and directly relevant source, not all historical reports or asset manifests. Rewritten speech must not silently use old recordings with different content. Current user instruction is implementation without tests, verification, or review; exports, push, and deployment are handled by the root task.
