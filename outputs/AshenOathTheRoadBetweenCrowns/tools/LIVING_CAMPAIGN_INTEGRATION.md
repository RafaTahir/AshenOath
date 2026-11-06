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
