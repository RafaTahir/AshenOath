# WORLD-SAGA Implementation Record

Date: 2026-10-19. Physical workspace: `D:\Projects\AshenOath`.
Branch: `codex/masterpiece-rebuild`. Source base: `d0a735f` plus the preserved worktree.

## Current Delivery

Follow-up 2026-10-19: the user approved finite oils and the fitting's 20% duration
effect. Source implementation now exists under [FINISH-017](../finish-line/FINISH-017.md);
its new compilation/verification are pending. The published world-saga baseline
below still represents the earlier deferred mechanic until a full finishing release.

The user authorized implementation after the story-package setup. The earlier
"documentation only" statements describe that setup, not this delivery.

- Runtime quest definitions merge the 21 retained JSON definitions with 30
  additional `saga_*` definitions from `scripts/saga_catalog.gd`: 51 in total.
- Every world has five optional regional stories, three separately claimed
  secrets, a capstone entitlement and a once-only changed-work return.
- QuestManager owns objectives/completion. StoryState owns branch outcomes,
  inspected parts, carried work and escort positions. InventoryManager owns
  pending item/ammo deliveries. ProgressionManager owns XP/Marks/entitlements.
- `StoryActivities/SixWorldStories` stages the live regional content. It is
  subordinate to the existing StoryActivityDirector, not another quest engine.
- Tracker, journal, saved-journey summaries and the equipment list include the
  new content. Explicit choices remain separate from inspection and work.
- New people use retained human families. Dain aliases mill worker 0; a posted
  authorized handover remains after rescue. Odran's departure removes his live
  presentation after his own acknowledgement while retaining authorized records.
- Existing main/side IDs, choices, saves, A-set identities, Ranger, actual Hart,
  camera/input behavior, game activities and homecoming are retained.

## Coverage By Ticket

| Ticket | Implementation | Runtime acceptance |
| --- | --- | --- |
| WORLD-SAGA-000 | Level 30; original thresholds/purchases retained; 17 total Marks; 20 practices; saved claims and overflow deliveries | User pending |
| WORLD-SAGA-101 / GRE-Q01-Q05 | Grain measures, bell repair, door work, wager/kettle, travelers' shelter; three secrets; clasp and changed return | User pending |
| WORLD-SAGA-102 / WYC-Q01-Q05 | Timber boundary, snares, private song, blind, watercourse; single migrated Bog encounter/core; secrets and bow grip | User pending |
| WORLD-SAGA-103 / DEP-Q01-Q05 | Freight, trial bed, cellar, graft, yard roof; retained Ashwing/Rootbound and mill work; secrets and fitting; timed-oil follow-up source present | Follow-up verification and gameplay user pending |
| WORLD-SAGA-104 / ROA-Q01-Q05 | Tolls, rescue account, returned identity, signal line, open road; nonlethal Senn duel/earned stand-down; secrets and baldric | User pending |
| WORLD-SAGA-105 / VAR-Q01-Q05 | Attributed orders, servant pass, Odran's garden, supply forms, memorial repository; retained Halvern; secrets and pommel | User pending |
| WORLD-SAGA-106 / HAR-Q01-Q05 | Memorial, Oris's finite promise, habitat, seed reserve, practical aftermath; late Glade/Ruins branch; actual Hart and equal inlay | User pending |

No ticket is described as user-accepted merely because its code is present.
The quest cards remain the detailed narrative/manual acceptance contract.

## Compatibility Details

- No retrospective XP overflow is invented. New quests grant 300/350/250/300/500
  XP; secrets grant 100 once; changed returns grant 100 after a real sector exit
  and a subsequent interaction with the changed work, not a reload in place.
- Bog's old generic 75-XP deed remains recorded, reattributed to Wychwood.
  The canonical 400-XP promotion grants only the remaining 325 if that deed
  exists, even when the old cap discarded its historical credit. Future deaths
  use the boss path, not the generic kill path. Existing resolved fights/core
  choices do not replay; saved boss phase/health data retain their owner.
- Legacy Deep Wood arrivals needing the relocated core receive a safe existing
  arrival and an explicit recorded direction to northern Wychwood. Supplies,
  health, choices and final objectives are not fabricated.
- Old Senn confrontations already complete skip the new duel. Fresh combat
  yields on a clean parry or broken guard without automatically deciding death.
  Existing evidence-earned stand-down and testimony/exile/punished outcomes remain.
- Bell-Eater defeat remains required for fresh shrine choices. Explicit legacy
  shrine retirement is respected without manufactured kill credit.
- New quests do not gate existing endings or replace their homecoming. Q05
  always contains work after the regional capstone, not a second kill reward.
- Permanent fittings survive Mark redistribution and are not consumables or
  vendor stock. The published baseline recorded Ash-Tempered ownership only.
  The approved follow-up adds the active-play duration effect without a substitute
  damage effect; see FINISH-017 for exact migration/pause/consumption rules.

## Build / Publication

Final build: `world-saga-20261019-final`, under
`D:\Projects\AshenOath\.release-gate\world-saga-20261019-final\export`.
Godot production compilation/export completed without compiler diagnostics.
Publication is authorized on 2026-10-19. The final candidate is synchronized to
`web/` for the existing atomic Git-push and Vercel publication workflow. Its
publication receipt under `.release-gate/living-road/WORLD-SAGA-000-*/publication.json`
records the resulting package commit and actual deployment outcome separately.

- Manifest aggregate: **104,665,612 bytes**, 16 listed artifacts.
- Entire export directory, including the release manifest: **104,673,660 bytes**.
- Strict cap: 104,857,600 bytes; complete-directory headroom: **183,940 bytes**.
- Transport root PCK SHA-256:
  `2ee5e7e496f0d8601b26a00d3f46684bad0b7a8273c970e34e7a4bd92895a195`.
- Source base is `d0a735f9a38b640823ce2402282477d3c72a126e`; the build explicitly
  records dirty source. It is not presented as a committed or user-approved revision.
- The first compilation reported two new script errors; both were corrected.
  Static review then found the new opening written requests depended on a late
  campaign record mesh. Its complete, self-contained mesh now has opening-only
  ownership. Final packaging rebuilt only the affected packs/root and reused the
  existing compiled actors, geometry, audio and unchanged packs.
- Final package generation, hashes, byte counts and lossless transport are build
  results, not gameplay acceptance. A final PowerShell receipt-property error was
  corrected by adding the missing receipt field; no application rerun was needed.

No game launch, gameplay, browser QA, benchmark or screenshot review is authorized
or performed for this implementation. Publication does not establish user acceptance.

## Changed Owners

- Added `scripts/saga_catalog.gd`, `saga_activities.gd`, `saga_encounters.gd` and
  `saga_work_presentation.gd` for authored content and subordinate live staging.
- Extended existing quest/progression/inventory/player owners, activity and
  dialogue routing, journal/preparation/HUD models and service summary wiring.
- Updated enemy/boss data, Senn's retained body contract, wilderness/Bandit Road/
  Glade/Ruins builders and the existing sector manifest/service.
- Extended `data/progression.json`/`upgrades.json` and the existing pack-layout
  compiler. Original `data/quests.json` definitions are retained verbatim and
  merged with the saga catalog at runtime, rather than duplicated in two files.
- Retained normal build-generated actor/animation/audio/localization metadata,
  compiled asset outputs, export selections and runtime-pack ledgers.
- Updated this package's ticket headers/index and `PROJECT_STATE.md`. Unrelated
  pre-existing untracked opening diagnostics/export folders remain untouched.

## User Manual Checklist

1. Start fresh and continue an old journey; check original quests and settings.
2. In each world, accept/decline the five requests, resolve both branches and
   interrupt/reload carried work, multi-part inspections and an escort.
3. Check each capstone and its once-only reward; exercise old Bog/core and Senn
   saves, peaceful resolutions, all four endings and the original homecoming.
4. Find secrets and return after Q05; reload repeatedly and check XP cannot farm.
5. Learn/respec the new practices without healing/refilling; check the six fitting
   effects, including FINISH-017's timed-oil benefit in the follow-up candidate.
6. Fill the quiver before an arrow reward, then make room and collect the
   remainder at the original request/secret without repeating XP or other items.

Runtime behavior, appearance, placement, balance and compatibility remain
UNVERIFIED - REQUIRES USER TESTING.
