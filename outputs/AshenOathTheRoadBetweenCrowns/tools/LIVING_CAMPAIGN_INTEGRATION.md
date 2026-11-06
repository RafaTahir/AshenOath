# Living campaign core: Stage 4 integration contract

This is dormant core work on `codex/living-campaign-expansion`. It is not a
complete playable release. `CampaignRevision.EXPANSION_ENABLED` remains `false`.
Enable it only after the complete four-chapter/two-region chain, both ending
alternatives, pack closure and gameplay acceptance have passed together.

## Journey identity and graph

`story_state.flags.campaign_revision` is numeric `1` (original) or `2` (expanded).
Missing markers always select `1`; names, active quests, imported slot labels and
replay status never infer expansion. New Game assigns the release's revision at
the accepted world handoff. Continue, import and chapter replay preserve it.
Migration leaves a missing legacy marker absent, preserving old Continue payload
identity rather than inserting a field solely because this release exists.
Unknown future revisions reject as newer-version saves. Malformed markers reject.
The save schema remains version 13 and existing save paths/backup/replay ownership
are unchanged. Raw input dictionaries are not mutated by migration.

`QuestManager.source_quest_defs` retains the full authored catalog;
`configure_campaign_revision(revision)` projects a journey-specific main graph
before `load_state` sanitizes quest IDs. Source definitions never mutate.
Revision 2 requires all four exact objective arrays below. Missing definitions
are rejected by journey preparation before claiming the destination. The Vargan
arrival recovery cannot skip the inserted chapters on revision 2.

Preserve all ten original IDs. Insert Empty Tables and Road Kept Open after
`main_ash_at_the_mill`, before `main_soldier_without_banner`. Insert House Many
Names and What We Promise after `main_last_witness`, before
`main_crowns_without_mercy`. Retain original chapter/ending data for revision 1.

| Quest ID | Exact objective IDs, in order | Completion flag |
|---|---|---|
| `main_empty_tables` | `reach_lantern_reach`, `hear_households`, `prepare_kitchen`, `settle_tables` | `campaign_empty_tables_completed` |
| `main_road_kept_open` | `survey_crossing`, `agree_route`, `secure_route`, `open_route` | `campaign_road_kept_open_completed` |
| `main_house_many_names` | `reach_hearthward`, `hear_households`, `prepare_refuge`, `settle_records` | `campaign_house_many_names_completed` |
| `main_what_we_promise` | `gather_cast`, `test_arrangements`, `choose_responsibilities`, `carry_promise` | `campaign_what_we_promise_completed` |

Author these four rows in `data/quests.json`, with real titles/text and `type:
main`. Mark deliberate choice objectives with `kind: choice`; otherwise generic
evidence history can satisfy an objective automatically. Root owns the authored
actions and progression. The existing quest-completion owner writes the four
completion flags; ending eligibility checks actual completed quest IDs.

Regions: `lantern_reach` and `hearthward`. Core save allowlists, displayed names
and regional quest tracking recognize them. Root must add world layout, safe
spawns and routes, gate eligibility for each journey revision, zone builders,
activity ownership, resource/pack maps and strict export validation.

## Choice and physical work flags

- `community_distribution`: `central` or `households`.
- `community_route`: `crossing` or `ferry`.
- `community_records`: `distributed` or `protected`.
- `community_kitchen_ready`, `community_route_ready`,
  `community_refuge_ready`: actual boolean completion from authored physical work.
- `community_keeper_consent`: dictionary of canonical participant IDs to actual
  booleans, written only by their own authored interactions.

Call `EndingCatalog.record_keeper_consent(state, canonical_actor, accepted)` from
the actual participant interaction. It accepts only Anwen/Mira, Nera/Nessa and
Vale/Merrow, allows withdrawal before ending lock, and rejects aliases/unknown
participants. Do not derive consent from documents, relationship scores or
quest completion. Do not write the whole dictionary through generic action
flags and accidentally overwrite other people's recorded answers.

## Six endings

The original IDs remain `expose/free/bind/kill` mapping to
`witness/mercy/duty/ash`. New `share` maps to `concord`; `depart` maps to
`open_road`. `EndingCatalog.normalize`, `covenant`, `title`, `is_peaceful` and
`available` are the common runtime API. Unknown endings reject; epilogues no
longer silently become Witness.

Both new alternatives require revision 2 and all four new completed chapters.
Concord additionally requires boolean `true` for at least one participant from
each group: `[anwen,mira]`, `[nera,nessa]`, `[vale,merrow]`. Open Road additionally
requires boolean route and refuge readiness. The original four remain available
under both revisions. Normal finale testimony/active-quest requirements still
apply in the existing selection owner. Selection snapshots Concord's consent as
`final_keeper_consent` and locks further participation changes.

`DialogueManager` automatically filters ending/final_choice actions through
the catalog and also supports `conditions: {ending_available: share}` (or
`depart`). The commit path checks eligibility again. Root must author:

- Two new `white_hart` actions and corresponding `story_campaign.json` ending
  rows, preserving the original four; chapter summaries and decision records.
- Aftermath scenes `aftermath_names_concord`, `aftermath_work_concord`,
  `aftermath_road_concord`, `aftermath_names_open_road`,
  `aftermath_work_open_road`, `aftermath_road_open_road`.
- Authored meshes
  `res://assets_external/environment/forest/HartAftermath_concord_Authored.res`
  and `res://assets_external/environment/forest/HartAftermath_open_road_Authored.res`.
  The glade requires two surfaces and optional `obstacles` metadata containing
  `centre`/`size`, like the four existing memorial meshes. Missing meshes are a
  release failure, not a silent fallback.
- Full voice collection for the new chapter actions/dialogues/aftermath and the
  six new ritual lines in `covenant_resolution.gd`. Review the authored ritual
  and epilogue prose in this core commit with the final campaign writing.
- Dedicated `ending_concord` and `ending_open_road` score cues if desired. Their
  runtime identities exist; current explicit fallback beds are `assembly` and
  `hart_glade`, respectively.

Both new peaceful outcomes use the existing three-step persistent ritual owner.
Reload guidance is derived from those actual step labels, avoiding a second
hardcoded ritual list. Existing final-choice, aftermath and completion paths
remain authoritative. Village signs and routine lines recognize both outcomes.

## Release validation and remaining integration gates

The pure fixture is `tools/verify_campaign_revision.gd`. It extends the existing
memory-only replay import fixture, uses actual value owners and synthetic quest
definitions, and loads no model, actor, scene or world. Run pinned Godot 4.6.3
headless with the worktree project and an explicit disposable log path. Cached
global class paths may be copied from the existing import cache; do not launch
an editor import against this asset-free sparse checkout.

Logs from the core run are in `.release-gate/campaign-revision/` at the worktree
root. The fixture covers original replay isolation, numeric JSON markers,
malformed/future rejection preserving stored bytes, actual 10/14 successor
activation, load sanitization, six ending identities, explicit consent and
withdrawal, physical readiness, UI eligibility and restored ritual guidance.

This does not validate the absent authored regions/resources or full gameplay.
The separate compile-only review loaded ten changed runtime scripts successfully;
the finale section remains blocked in this sparse checkout by its four existing
authored resource preloads (UndercroftVault, AssemblyCourt, HartLandscape and
HartWitnessStones). No model/world was instantiated. Recheck that section in the
full asset checkout during integration; do not replace its preloads with stubs.
The aggregate campaign validator currently expects 57 quest definitions and
four endings for its legacy journey fixture. Preserve that legacy check and add
an expanded journey fixture with 61 total definitions/14 main chapters/six
eligible endings. Update validators' physical resource/pack/zone expectations
without weakening the legacy checks. Include new base helper ownership and
resource closure, per-file/total Web limits, desktop/touch real-input journeys,
old saves at each insertion/finale, both complete alternatives, cancellation,
save/reload/replay, exact committed export identity and publication gates before
turning on the expansion switch.


## Source checkpoint after authored community data (2026-11-07)

This checkpoint follows core commit `c0800b1dbf191512797b893bd75f7ee6332a1373`.
Find its own exact commit with `git log -1 -- tools/LIVING_CAMPAIGN_INTEGRATION.md`;
no publication is authorized from this incomplete branch. The expansion switch
remains **false**. No canonical checkout file, export, actor or Blender asset was
changed by this isolated checkpoint.

Included source work:

- Four authored quest definitions and 14-chapter/six-ending catalog; revision-2
  Hart dialogue with two eligible alternatives and six new aftermath scenes.
- `data/community_campaign.json`: four chapter outlines, 15 physical work tasks,
  concrete choice results and six participant offers/refusals/withdrawals.
- QuestManager now treats `kind: activity` as explicit completion: stored evidence,
  incidental observations and reload cannot perform physical work. Choice kinds
  still require `complete_choice` rather than generic objective completion.
- `community_campaign.gd` is a dormant pure rule helper, **not yet wired to any
  runtime interaction**. It validates chapter/order/region/work selection,
  distinct crossing/ferry tasks, both survey stations, preparation readiness,
  choice then enacted aftermath, first-load carry/delivery, posted vacancies,
  participant availability and explicit consent/withdrawal. The existing activity
  director must supply physical elapsed time, proximity, interruption and source
  participant validation before calling these methods. Calling this helper alone
  does not prove gameplay occurred.
- Missing/explicit revision-1 markers in either new region now reject as
  `campaign_region_revision_mismatch`; region names never upgrade a journey.
  Future revision diagnostics retain precedence. StoryJournal receives a projected
  10/4 or 14/6 catalog without mutating the authored source.

Validation status is intentionally separated:

- Previously recorded core: **435 checks PASS**; root-authored physical objective
  ownership fixture: **132 checks PASS** before this checkpoint's later edits.
- New `verify_community_campaign.gd`: **NOT RUN**. It covers both route branches,
  physical ordering, duplicate work, refusal/withdrawal, carried load save/reload,
  aftermath, unavailable Senn outcomes, legacy new-region rejection and 10/4 vs
  14/6 catalog projection. It uses real QuestManager/StoryState in memory only.
- No Godot engine, model/world, Blender, Web export, gameplay or deployment run
  was started for the new checkpoint; the shared host was reserved for the
  orchestrator's published-baseline browser acceptance.

Remaining implementation before a playable claim:

1. Build `scripts/zones/community_section.gd` with two compact retained-kit regions.
   Keep the entry/return corridors and 15 task positions reachable. Add the actual
   meals, refuge, inspected landings, chosen route and enacted-aftermath visuals.
2. Wire the pure helper through **StoryActivityDirector's existing tick/lifecycle**
   and the current dialogue/quest owners. Do not add a second per-prop controller.
   Bind source instance + current menu generation; revalidate participant, region,
   quest order and distance at commit. Use existing work cancellation for movement,
   combat, pause, death, focus loss, travel and restore. Preserve only completed
   durable work; interrupted timers must not grant credit. The route load needs
   a visible carried presentation and real movement to its far-landing delivery.
3. Show all available canonical participants. Never spawn exiled/punished Senn;
   cooperative Edric and Nera's existing personal-introduction/escort availability
   remain gates. Missing participants leave written public accounts or vacancies,
   never inferred testimony/consent. A refused shift must not block food/shelter or
   the original endings. Consent requires the actual authored participant's answer;
   keep withdrawal accessible until the final ending lock.
4. Add gated two-way sector connections, arrival completion and safe spawns,
   registration/preparation builders, state-aware legacy topology/atlas filtering,
   regional routines and actor requirements. The premature new-zone registration
   hooks were deliberately removed from this checkpoint: no missing builder is
   currently registered. `zone_available` is ready for those entry guards.
5. Dynamically load the community builder only after its dedicated pack is ready;
   update authoritative pack selection/manifest sources, all old destinations that
   need expansion-owned scenes (including saved expanded glade outcomes), and exact
   resource closure. No full asset checkout exists here, so closure is deferred.
6. Add objective route hints/journal work entries and test direct raw catalog
   consumers. `StoryJournal.active_chapter` already asks only projected active
   quests; public raw `campaign()` remains an authoring catalog, not a journey UI.
7. Review the title collision: `main_road_kept_open` and existing `side_escort_06`
   both currently display **A Road Kept Open**. Their work differs (public route
   construction vs Nera's existing relief handover); give the new chapter a distinct
   displayed title while retaining its ID, before voice/text collection.
8. Collect/render exact new spoken lines and ritual/aftermath lines; add both
   authored Hart memorial resources at the paths specified above. Run the new
   fixture, original core/ownership fixtures, parser/resource checks, complete
   save/import/replay/legacy matrix, six-ending runtime acceptance, pack/Web gates,
   and desktop/touch real-input gameplay. Enable revision 2 only when the coherent
   complete expansion passes together; never publish an incomplete required chain.
