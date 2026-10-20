# WORLD-SAGA-000 - The Unfinished Oath

Parent: none. Children: WORLD-SAGA-101 through WORLD-SAGA-106 and their 30 quest cards.
Date: 2026-10-19. Status: build-only implementation present; user acceptance pending.
Current delivery: [implementation record](IMPLEMENTATION.md). Runtime definitions
extend the retained 21 quests to 51 and the global level cap to 30. The oil-duration
mechanic was deferred at setup; the approved follow-up is tracked in
[FINISH-017](../finish-line/FINISH-017.md). The setup-only boundaries below describe
the original authoring pass; the subsequent user authorization permits this implementation.
Source baseline: `d0a735f9a38b640823ce2402282477d3c72a126e` on `codex/masterpiece-rebuild`.

## Campaign Promise

What do you owe the living when their safety depends on a lie about the dead?
Kael begins by accounting for Bram, Sella and Oren. He stays because the people
who need that account also need medicine, bread, shelter, friendship and a road home.
Edric's proposed renewal is the active threat: protection and grain are offered
on terms that repeat the coercion which hid the massacre. He is responsible for
his decisions, not the secret author of every wrong in every region.

The added campaign gives each place a practical present-day problem and a human
story beyond its evidence for the main mystery. Emotion alternates warmth,
curiosity, grief, humor, anger and relief. Do not make all 30 stories about a
dead relative or another recovered ledger. No copied plots, names, dialogue,
music or proprietary assets from the research games.

## Regional Dramatic Spine

| World | Emotional movement | Local pressure | Main-story contribution | Capstone |
| --- | --- | --- | --- | --- |
| Greyfen | Belonging challenged by fear | Winter grain and a failing warning bell | Protection cannot depend on a signature | Bell-Eater |
| Wychwood | Wonder becomes attentive responsibility | Work, traps and a threatened watercourse | Fragmented memory is not the forest's moral guilt | Bog Wretch |
| Deep Woods | Complicity becomes practical care | Food, labor and clean rebuilding | Keeping the account and feeding people are separate obligations | Ashwing; Rootbound retained additionally |
| Long Road | Obedience meets refusal | Tolls, identity and safe passage | Historical injury does not excuse present raids | Senn |
| Castle Vargan | Betrayal becomes accountability | Institutions acting through ordinary workers | A document proves acts; it cannot consent for a person | Halvern |
| Hartlands | Responsibility survives resolution | Memorial, habitat and unwanted promises | Kael chooses his responsibility, not everybody else's | White Hart |

Keep the existing ten-chapter spine, its actual order and unlocks, the Greyfen
Assembly and the Witness/Mercy/Duty/Ash endings. The new local arcs overlap it;
they do not require completing all five quests in one world before leaving.
Q05 in each world is new playable aftermath, available once that capstone is
resolved. It does not award completion for merely witnessing an old boss die.
No real-time campaign deadline; weather/winter are authored pressures, not hidden timers.

## Baseline To Preserve

The ten main IDs are `main_road_of_crows`, `main_bell_beneath_greyfen`,
`main_teeth_in_rain`, `main_names_they_burned`, `main_ash_at_the_mill`,
`main_soldier_without_banner`, `main_blood_under_stone`, `main_last_witness`,
`main_crowns_without_mercy`, `main_hart_remembers`.

The eleven side IDs are `side_widows_bell`, `side_iron_remembers`,
`side_bitter_roots`, `side_bracken_rescue`, `side_black_dog`, `side_empty_grave`,
`side_childs_charm`, `side_soldiers_debt`, `side_millers_measure`,
`side_rooks_map`, `side_three_candles`.

Existing cup/coat care, kitchen cart, road drain, household relief, wage-chest
rescue, worker escort, root name-board, friendships, romances, games and
homecoming are not new quest slots. Cards explicitly distinguish added actions
from these systems. Keep their existing progress and rewards unchanged.

## Ticket And Authoring Contract

Each world has five new files under `quests/`. The stable ticket prefix maps to
runtime IDs `saga_gre_q01` through `saga_har_q05`; never reuse an original ID.
Q01-Q05 completion XP is respectively 300, 350, 250, 300, 500. All are optional
regional stories; a card marked connected means it affects the main story's
context, not that it replaces or secretly gates the old mandatory chapter.
Use the existing `side` quest type for all 30 additions: the planned roster is
10 retained main quests and 41 side quests, including main-connected local arcs.

Each card specifies a personal hook, motivations, location, start condition,
ordered objective IDs with real verbs, bounded choices, failure/recovery,
exact rewards and durable state. Small sample exchanges establish voice;
implementation must write the short remaining exchanges against those beats,
not substitute generic fetch text. Branch alternatives converge at an explicit
resolved endpoint. Taking a private or nonviolent route earns equal quest XP.

Use existing QuestManager, StoryState, ObjectiveViewModel/presentation,
StoryActivityDirector, story/encounter coordinators, InventoryManager,
ProgressionManager, VendorService and save migration. Do not add another
quest engine, objective authority, reward wallet or global coordinator.
Positions are semantic staging anchors in the named existing district;
implementation fits them through the current spatial contract, never through
arbitrary global coordinates or new collision bypasses.

The implementation read set is the active card/world/master, current
`PROJECT_STATE.md` and directly affected owners under
`outputs/AshenOathTheRoadBetweenCrowns/`: `data/quests.json`, `data/dialogue.json`,
`data/progression.json`, `data/upgrades.json`, `scripts/progression_manager.gd`,
`scripts/inventory_manager.gd`, `scripts/player_controller.gd` and the active
zone/activity/encounter builder. These paths are ownership pointers, not a
requirement to reread or rewrite every file for every quest.

## World And Actor Ownership

| Region ID | Owned sectors/districts | Binding decision |
| --- | --- | --- |
| greyfen | greyfen, assembly, embedded cemetery/Crow Chapel | Correct cemetery regional credit without a second arrival award |
| wychwood | wychwood including its new northern Bog Wretch arena | Migrate the existing Deep Wood encounter; one outcome authority |
| deep_wood | deep_wood, old_mill, burned_farmstead | Rootbound and all existing mill systems retained |
| long_road | marsh_crossing, bandit_road | Senn retains Ranger body and current fate IDs |
| vargan | vargan_approach, vargan_court, record_hall, undercroft | No duplicate combat/dialogue Halvern |
| hartlands | ruins, hart_glade | Add a discoverable late connecting route, not an unrelated new world |

New people use the retained licensed Universal family and deterministic unique
recipes, native anatomy and existing animation/socket contracts. Dain is the
first retained mill worker's named presentation, not an extra replacement worker.
Ressa is a displaced resident, not a duplicate of the second escort. Existing
NPCs are authoritative when relocated; letters/accounts are attributed records,
not invisible speakers. Keep Kael/Anwen, Senn and Hart visual identities.

Each area's mundane life must persist outside the quest: work/rest position,
one pre-quest line and an outcome-specific return line. No new NPC forces
romance, replaces Mira/Vale, or knows facts they could not have learned.
Only the Hart is a complete supernatural witness; other echoes are bounded.

New people use stable interaction IDs `saga_nessa`, `saga_jory`, `saga_iven`,
`saga_edda`, `saga_ressa`, `saga_nera`, `saga_tavin`, `saga_lysa`, `saga_odran`,
`saga_maelin`, `saga_oris`. `saga_dain` is a dialogue alias of retained worker
index 0, not a new escort or a renamed saved worker. Unresolved personal-choice
speakers remain reachable at their safe work/rest fallback anchor; no timer
kills them or schedules them off-map before the player can answer. If a completed
story legitimately removes them, only their previously authorized notes speak
for their decisions. Optional work may wait for a clearly directed conversation,
but the main campaign never waits for that optional answer.

## Additive State And Reward Bindings

This section specifies future data changes; it does not introduce new runtime files now.
Retain current definition shapes. Add `saga_*` entries to quest/dialogue/item data
and new rows to existing progression rules. Link journal entries through the
existing evidence/work model and use the authoritative objective presentation.

| Owner | Durable addition | Rule |
| --- | --- | --- |
| QuestManager | Each card's objective booleans and completion | Completing a physical step or explicit dialogue choice advances it, never proximity alone |
| StoryState | `saga_<prefix>_qNN_outcome`, card-specific flags/items, sector dressing | Commit branch outcome and quest resolution in one existing save transaction |
| ProgressionManager | `quest:saga_<prefix>_qNN`, `secret:<PREFIX>-SNN`, `return:saga_<prefix>_settled` | Canonical one-time claim per action, preserved across reload/upgrade |
| Inventory/progression | `reward:saga_<prefix>_capstone`, owned signature item and passive entitlement | One recoverable grant, not tradeable, sellable, consumable or Mark-purchased |
| Encounter owner | Existing boss ID/outcome/checkpoint plus optional new staging discriminator | Moving or developing an encounter never creates a second boss claim |

Quest items are lightweight journal/held-work records, not arbitrary consumables.
Do not spend ordinary supplies unless a card explicitly names an optional purchase.
Lore artifacts have no combat stats. Essential evidence is never destroyed by a
secret, missed conversation, alternate resolution or rejection of optional work.
Secret contents are inspectable after claiming; no respawnable loot or XP farm.
If an ammo/item grant exceeds its existing capacity, record the remainder as a
pending delivery under that quest/secret in InventoryManager's additive saved
reward data. It can be collected at the giver or original cache after making
room. XP and partial items do not repeat while collecting the remainder; no new
stash currency, lost unique item or secret disabled by a full quiver.
Reading new secrets does not also trigger generic discovery XP: the canonical
100-XP secret claim owns their reward. Existing unrelated discovery rules remain.

Every incomplete quest can be resumed after death, reload, sector retirement,
weather change or ending. Carried work remains recorded, not a stale Node reference.
Use persistent partial progress and conditional stage presence to reconstruct it.
No escort teleports to success, no softlock behind an absent/dead named actor:
cards provide written/drop-off alternatives. A declined hook remains politely
available without repeated prompts; only an explicit final outcome resolves it.

## Global XP And Skills

Extend cap 20 to 30 with the existing curve, unchanged below level 21:
`XP(level) = 200*(level-1) + 25*(level-1)*(level-2)`.
Level 20 remains 12,350 XP; level 30 requires 26,100 XP. Levels do not heal,
resupply, change saved difficulty or automatically scale enemies.
Append Mark levels 22, 24, 26, 28, 30 to the existing twelve: maximum 17 issued
Marks, 20 available practices, one Mark each. Retain free, non-healing shrine respec.

Add two choices after tier 3 in each existing branch. Tier 4 requires that
branch's tier 3; tier 5 requires tier 4. These initial tuning values are design,
not measured balance acceptance. No new active ability or input binding is required.

| New skill ID / name | Tier / prerequisite | Exact additional effect |
| --- | --- | --- |
| `saga_economical_heavy` / Economical Heavy | blade 4 / fell_weight | Heavy stamina cost -2; retain minimum cost 1 |
| `saga_follow_through` / Follow Through | blade 5 / saga_economical_heavy | Light attack recovery cooldown x0.92; preserve contact/animation synchronization |
| `saga_deep_reserve` / Deep Reserve | survival 4 / redroot_lore | Maximum stamina +10, current stamina unchanged on unlock/respec |
| `saga_staying_power` / Staying Power | survival 5 / saga_deep_reserve | Maximum health +10 in addition to existing health effects; no healing on purchase |
| `saga_clean_release` / Clean Release | hunter 4 / fletchers_care | Fully drawn hostile-target arrow damage x1.05; no extra stamina charge, ammo or retrieval change |
| `saga_ready_string` / Ready String | hunter 5 / saga_clean_release | Bow recovery -0.03 seconds after existing multiplier; minimum 0.10 seconds |
| `saga_banked_embers` / Banked Embers | oathfire 4 / ashen_flow | Oathfire stamina cost -5 in addition to existing reduction; minimum 1 |
| `saga_steady_channel` / Steady Channel | oathfire 5 / saga_banked_embers | Oathfire charge time x0.95; preserve initial-facing lock and damage timing |

Use new effect keys for the added practices and signature perks. Current
`effect_value` returns the first matching learned effect, so do not silently
reuse a key and lose stacking. Compose explicit additive reductions, then
multipliers where specified, then apply the existing minimum/clamp. Update
ordering (currently tiers 1-3), Mark limits, save bounds and UI descriptions
together. Preserve all 12 existing practices and learned IDs.
Separate the 17-issued-Mark limit from the 20-practice UI denominator; the
current shared constant must not make the summary imply 17 total practices.
Bow shots currently have no stamina charge: Clean Release must not introduce one.
Fully drawn means normalized draw ratio >=0.99 using the effective grip-adjusted
duration. Training shots do not receive combat damage or ammunition rewards.
Capstone passives are earned entitlements outside the Mark-purchase dictionary;
they do not count toward learned practices or refund Marks on respec.

## Regional Budget And Signature Rewards

Each region adds 1,700 quest XP + 300 secret XP + 100 meaningful-return XP:
2,100 XP, or 12,600 total, excluding retained arrival/discovery/boss awards.
Q05 resolves its own physical work. A return grant requires leaving after Q05
and returning to its changed anchor; a reload in place is not a new return.
First visits retain their existing 100-XP claim. Rootbound retains its 450 XP;
existing bosses keep 400/450/500 awards. Add Senn's single 450-XP
`boss:captain_senn` resolved-encounter grant; an existing identical claim blocks
it, but ordinary guard-kill XP is not equivalent and is not taken away.
Peaceful resolutions receive the same relevant capstone XP, never kill credit.
Bog/Senn promotions add up to 850 XP beyond the 12,600 regional-work budget;
the old Bog generic claim reduces its new promotion credit as described below.
No level gate or requirement to hit 30 before the finale; optional completion
may hit the cap. Display excess deeds at cap without fabricating extra levels.

| Reward ID | Entitlement | Trigger / exact effect |
| --- | --- | --- |
| `saga_bellkeeper_clasp` | Greyfen | Bell-Eater defeated, or explicit grandfathered shrine-retired legacy state: successful guarded-hit stamina cost x0.90; does not extend parry window |
| `saga_wayfarer_grip` | Wychwood | Existing Bog Wretch fight resolved: time to full bow draw x0.90; damage, aim settings, ammo unchanged |
| `saga_ash_tempered_fitting` | Deep Woods | Ashwing resolved: applied oil duration x1.20 (300 to 360 active-play seconds); follow-up verification pending |
| `saga_roadwarden_baldric` | Long Road | Any settled existing Senn fate: sprint drain x0.90, including the retained 10 stamina/second base |
| `saga_witnessguard_pommel` | Castle Vargan | Any final Halvern resolution: +5 stamina on successful parry, added to Measured Riposte if learned; clamp at max |
| `saga_oathbearer_inlay` | Hartlands | `final_choice_completed`: cooldown -0.5 seconds after existing reductions, minimum 0.5; covenant-specific description/appearance, same effect |

Rewards are permanent earned fittings/keepsakes using current inventory and
progression ownership, not six new equipment slots. Do not replace either sword,
the bow, back sockets or required relics. Visual variants reuse approved assets.
All legal narrative resolutions earn equivalent mechanical power; coercion,
romance and public disclosure are never prerequisites for the best stats.

### Oil Dependency And Approved Follow-Up

At setup the user explicitly deferred the perk because oils did not expire.
The subsequent 2026-10-19 approval resolves that decision: one bottle applies
five minutes of active-play coating, six with the fitting; reapplication refreshes,
another oil replaces, and menus/dialogue/loading/death/offline time do not spend it.
Remaining duration is saved. Legacy selected oils get one full duration without
charging another bottle; new invalid/expired timers never refill. Existing blade
tags/damage and optional preparation objectives are preserved. Implementation and
pending single-run acceptance are tracked in [FINISH-017](../finish-line/FINISH-017.md),
not inferred from this story specification or the earlier published package.

## Save And Encounter Migration

Keep existing quest completions, choices, supplies, learned skills, total XP,
issued Marks and claimed reward IDs. Extend the current schema additively only
when implementing; an old missing saga block means not started, not completed.
Do not recompute XP lost to a historical level cap: the source cannot establish
unrecorded overflow. Reconcile only verified earned entitlements, quietly and once.

Bog Wretch: retain its ID and old `fight_bog_wretch`/core-choice outcomes. Preserve
any checkpoint health/phase/defeat data; select one new Wychwood arena owner.
A legacy save inside the old arena gets a safe arrival and explicit journal
direction, not a forced replay. Keep Oren's naming prerequisite and the subsequent
Deep Wood/Rootbound route. The current Bog Wretch is not in `data/bosses.json`
or the progression boss table; it can earn generic 75-XP encounter credit.
Promote it with canonical `boss:bog_wretch` at 400 XP. For the recorded old claim
`encounter:deep_wood:bog_wretch:0.00:-8.00`, preserve/reassign its regional record
and grant only the new 325-XP difference after a verified resolved fight.
If that old claim was capped to zero, do not reconstruct its lost historical
75 XP. Never subtract credited XP. Existing canonical claims block a second
promotion; future boss deaths skip the old generic-kill award. Preserve the
650-XP Teeth in the Rain quest reward as a distinct completed quest.

Bell-Eater: fresh journeys still defeat it before shrine choice. Existing accepted
legacy shrine-retired states remain retired, with no fabricated kill/boss XP.
Halvern/Senn: records remain sufficient if a living speaker is absent.
An old Senn save with `senn_confrontation` already completed goes directly to
the pending existing fate dialogue; do not force a newly introduced duel.
Hart: Witness/Mercy/Duty never spawn the Ash combat avatar; Ash does not replay the
final encounter after completion. Old Ruins must not duplicate Edric/Hart actors
or replay historical shortcut objectives. Its new optional route opens with the
existing reopened-road/finale access, and supports return in every covenant.

## Delivery And Acceptance

Work stays physically on D:, development branch, scratch under `D:\Temp\AshenOath`.
No source, asset, runtime data, Web artifact or remote branch changes during setup.
Later implementation is build-only, user-tested, unless explicitly amended.
No new paid service, cloning, synthetic voice approval, art-family replacement,
quality reduction or content deletion. Subtitles remain sufficient for every quest.
Preserve startup/readiness, camera/input, population, scenes, existing side stories
and licenses. Later complete Web package must be strictly <104,857,600 bytes.

Track for every ticket: documentation authored; implementation pending/done;
compilation not run/result; publication not performed/receipt; user acceptance
pending/accepted/rejected. Never promote authored cards into implemented quests.
Secrets/boss/reward/return have independent checkboxes in each world ticket.

Static authoring review: 30 unique additive IDs; all 21 originals retained;
all local dependencies acyclic; no optional collection gates an ending; no
double reward ownership; honest legacy migration; references/links complete.
Manual scenarios after implementation: each branch and decline, interrupted
physical work, death/reload, absent speakers, day/night, alternate objective
order, legal capstone resolutions, once-only rewards and changed return.
Check all four endings plus the existing Anwen/workbench/road homecoming.
These scenarios are not executed or claimed passed by this documentation delivery.
