# Living campaign: Stage 4 integration contract

This is isolated source work on `codex/living-campaign-expansion`. Runtime
implementation is now present; this is not an accepted playable release.
`CampaignRevision.EXPANSION_ENABLED` remains `false`.
Enable it only after the complete four-chapter/two-region chain, both ending
alternatives, pack closure and gameplay acceptance have passed together.

## Disposable acceptance inputs and exact pack preflight (2026-11-10)

`prepare_community_acceptance_seeds.py` prepares nine explicitly synthetic saves
under this isolated project's `.release-gate/community-runtime/boundary-seeds-*`.
The immutable manifest records every source hash, each save hash, all initially
completed chapter IDs, starting flags, authored decision sources and the next
unfinished chapter. No user profile is inspected. Existing identical seeds are
reused; changed inputs are preserved and require a new directory.

| Cases | Supplied completed main chapters | Actual input begins at |
| --- | ---: | --- |
| `lantern_crossing`, `lantern_ferry` | 5 expanded | Old Mill; Empty Tables unfinished |
| `hearth_distributed`, `hearth_protected` | 10 expanded | Undercroft; House of Many Names unfinished |
| `legacy_ash_missing`, `legacy_ash_v1` | 5 original | Old Mill; Soldier Without a Banner unfinished |
| `legacy_witness_missing`, `legacy_witness_v1` | 8 original | Undercroft; Crowns Without Mercy unfinished |
| `seeded_departure_ferry` | 13 expanded | Hart Glade; final chapter and ending entirely unfinished |

The two Hearth cases explicitly cover available and absent Senn/Edric/Nera.
Neither keeper consent nor named relocation consent is supplied. The ferry case
has a prepared route/refuge and a nonempty human record, but no ritual, loss,
relocation or ending credit. Inventory is the authoritative starting stock;
health/stamina use ordinary 100 maxima. No state is injected after Continue.
These are boundary tests, **never fourteen-chapter proof**. `full_six_endings`
continues to forbid any seed and must begin with actual New Game in an empty
disposable profile.

`verify_community_acceptance_seeds.gd` validates all nine through the existing
in-memory save/import and quest owners. It writes only `native_validation.json`
beside the explicit gate manifest. At source checkpoint
`e0056c5dc1dd83affec81c6cb400142ea6e1fb57`, the nine-seed memory fixture passed
**447 checks**, and both modified input entry scripts passed check-only parsing.
All four serial Godot 4.6.3 processes exited 0 without parser/runtime/leak errors.
The gate receipt is `.release-gate/community-runtime/native-boundary-r1/receipt.json`;
the accepted seed inventory is `boundary-seeds-ff769fea7151/manifest.json` in that
same community-runtime gate. Python seed/pack/acceptance tests passed **42 tests**.
No world, model or renderer was loaded. All actual world runs remain pending;
these results do not prove physical arrivals or the complete campaign.

Both world runners now require `--release-manifest` from the maintained builder's
final Web export. Native inputs must be lossless **decoded** copies of that final
`index.pck` and its declared external PCKs. Gzip input is rejected before launch.
The root, external packs and embedded runtime manifest must match the release
receipt's decoded hashes/lengths and build identity. The class cache must match
the exact root's `.godot/global_script_class_cache.cfg`. Raw builder
`runtime-packs` is an acceptable external source only when its declared files
match those hashes; its intermediate `base.pck` is ignored and never mounted.
The final root is not interchangeable with that intermediate base.

`community_acceptance_packs.py` uses the shared manifest/graph validator and
produces a dependency-ordered explicit mount list. The runtime entry rechecks
hashes and root manifest authority; it never enumerates a pack directory.
Unlisted files remain untouched and cannot affect the test. The receipt records
the actual mounted IDs and candidate build identity. This static PCK inventory
does not replace maintained export/resource-instantiation gates.

Known acceptance resource closure includes the main scene/remap, community
runtime/data/overlay, both new Hart aftermath meshes and all seven cemetery
preloads: `Cemetery_chapel`, `Cemetery_bell_frame`, `Cemetery_bell`,
`Cemetery_grave_rows`, `Cemetery_boundary`, `Cemetery_grave_earth`, and
`Cemetery_memory_window`, each at
`res://assets_external/environment/village/<name>_Authored.res`. The cemetery
dependency comes from the generated full-route adapter; it must be present in
the assembled candidate rather than replaced with a sparse-project stub.
All packs mount before these native routes, so these runs make **no deferred
download/cold-loading claim**. Browser pack readiness/ownership remains separate.

The generated legacy adapter now reads exact current authored outcome labels,
then selects their visible button by keyboard. It does not apply outcome flags.
Assembly checks only stage explicitly willing native witnesses and still read
the written public record when named witnesses are absent or refuse.

## Resumed ending correction (2026-11-10)

Open Road is now an unfinished covenant after its three glade acts. The first
reads authored signed requests from the water-carrier and sweeper households;
it snapshots only separately consenting, currently available canonical actors.
The second permanently dismantles territorial protection and ends access to the
Hart's complete account. Human evidence remains unchanged. The third begins the
actual passage, without completing the final chapter.

`community_ending.gd` contains pure transitions and belongs exclusively to the
community pack. Existing `CommunityActivity` owns all load/work timers, the two
household bodies, bridge following/ferry passage, far-bank delivery and refuge
arrival. Missing native bodies/drivers cannot earn passage. The last chapter
finishes only at Hearthward after the actual arrival. Reload restores exact
progress/costs; invalid completed departure records are rejected. No save-version
bump, legacy-revision inference, competing process or new reward owner is added.

All twelve named participants have separate `departure_offers` in
`community_campaign.json`, with explicit speaker_id/question_speaker_id and
question/yes/no/withdraw text. Keeper consent never doubles as relocation
consent. The household body pair reuses existing C06/C05 roles. Post-arrival
Hearthward uses two explicit six-person shifts covering all twelve, so two
households plus Kael/Bracken remain within ten visible skeletons. Earlier fate
and absence rules still filter attendance. Named volunteers leave their original
home presence; refusals and unavailable people are not moved.

Concord preserves `final_keeper_consent` as its immutable initial acceptance.
Continuing `community_keeper_consent` can be withdrawn or freely renewed through
the same in-person dialogue owner after the ending. A logistics vacancy places
physical bridge barriers and denies the ferry, retaining the service footway.
A released keeper stops that refuge responsibility, including during weather
schedule changes. Care, food and shelter eligibility remain separate.

Authoritative rituals/cards/aftermath text now states the actual costs. The
isolated deferred overlay and community locale were regenerated after resumption;
base English remains 1992 entries (288 deferred here; shared Stage2 source adds
its own entries on regeneration). Root owns final exact-text voice collection.

Acceptance source: the full earned New Game circuit checks relocation, consent,
unchanged human evidence, mid-passage reload, restored permanent costs and a
post-Concord withdrawal/real vacancy. `seeded_departure_ferry` is explicitly
separate boundary proof: thirteen preceding chapters are setup, then actual
input records the needed personal answers and enacts only Open Road using the
prepared ferry. It cannot be labelled full-campaign proof. Both viewports remain
required. Python receipt tests pass (12) and deferred payload tests pass (9).
The isolated, disposable-profile native memory round passed ending consequences
(255), campaign revision (435), community activity (44), and deferred overlay
(50); the full campaign entry script also passed check-only parsing. Exact logs
are under `.release-gate/community-runtime/native-resumed-r1/` with `r4` suffixes
for the first three fixtures and `r5` for overlay/full-entry parsing.

The generated full-game adapter did not pass parsing in the sparse fixture
project: its inherited cemetery helper requires authored resources absent from
that memory-only project. That adapter must be checked with integrated assets.
No actual world, native household contact/geometry, rendered input circuit,
performance, or six-ending gameplay acceptance is claimed by the memory tests.
The follow-up save validation rejects malformed household/consent/roster shapes,
unknown or duplicate people, refused roster entries, nonfinite passage progress
and inconsistent ordered departure consequences before deferred content mounts.
Its memory-only round passed 368 consequence assertions and 435 campaign
revision assertions. Both community/full input entry scripts passed check-only
parsing. See `native-resumed-r1/receipt-r6.json` and the matching `r6` logs.
The ward projection also removes the witness runes; the blocked-waypost hint
now directs the pending relocation along its actual route and refuge.

Background acceptance now uses the shared `background_native_capture.py`
launcher imported byte-for-byte from motion checkpoint `c96be105`, with startup
no-focus settings, the real compatibility renderer, and ordinary in-process
input events. It creates an owned non-input Windows desktop and never switches
desktops or requests foreground. The two entry scripts reject a missing desktop
marker/no-focus flag, and the receipt checks the desktop, actual viewport size,
renderer and owned-process/desktop cleanup. The helper is included in frozen
input hashes. The shared owner observed its separate two-size GPU smoke; this
does not establish campaign gameplay. Receipt/adapter Python tests pass (23),
including rejected foreground/cursor shortcuts and mocked timeout cleanup.
The bridge acceptance endpoint allows the actual followers' lead gap plus the
input walker's stopping tolerance. All world acceptance listed above is pending.

## Current source checkpoint: playable runtime wiring (2026-11-07)

Based on merge `0304f5c` (stable combined source `02d0341`, core `c0800b1`,
authored checkpoint `e0c0c51`). Find the exact checkpoint with
`git log -1 -- tools/LIVING_CAMPAIGN_INTEGRATION.md`. The historical sections
below describe earlier gates; this section supersedes their implementation TODOs.
No canonical checkout, export or deployment was changed by this worktree.

### Deferred story payload (source complete; runtime fixtures unrun)

The maintained `prepare_runtime_dialogue.py` compiler now creates an exclusively
community-owned `data/community_story_overlay.json`. It contains the complete
revision-2 Hart projection, six new aftermath scenes, full new chapter/ending
catalog prose, and the two new ritual/card text sets. Existing per-scene shards
retain only base content; explicit `source_tag: campaign_revision_2` controls
separation, never names or a broad text heuristic. Original untagged scenes are
unchanged. `data/runtime_story_campaign.json` is the base catalog and retains
only IDs/titles/revision markers for the new rows. Pack integration must exclude
the authoring `data/story_campaign.json` from every runtime preset. Raw authoring
catalogs remain available to exact-text voice collection.

The four new quest definitions already consist of compact titles, objective
labels/kinds, completion identity and unlock edges. Those remain base-owned so
new-journey revision selection and saved graph validation work before the first
insertion. No quest state is reloaded or rewritten when story prose appears.
The compiler runs before layout validation in `build_story_release.ps1`.

`campaign_story_overlay.gd` is a small base helper. Its cache stores immutable
deferred data, never a journey's projected dialogue. `DialogueManager` and
`StoryJournal` project per current journey on each request; loading legacy after
expanded immediately restores original scene/action/catalog visibility. Missing
data is not cached, and incomplete payloads fail readiness. New ritual text now
lives in `community_campaign.json` as `ending_rituals[share|depart]`, each with
three `[label, narrator text]` pairs; `ending_cards` contains the exact two card
strings. Runtime consumers use those generated overlay values. Both are captions,
not invented actor speech, for the voice inventory.

`_zone_encounter_packs` adds `community` only for revision 2 in a new region or
earned post-Ash community context. Initial expanded Greyfen adds nothing and
does not decode the overlay. Direct saved arrivals use the recorded journey's
flags/completed chapter set, so old-region scenes prepare their own dependency
before save ownership is claimed. The existing campaign/opening wait owners
retain the same extra dependency list through request, progress, retry and
readiness. Missing/invalid deferred prose fails before destination activation.
The pack manifest should declare `community` for the two new regions; legacy
Hart/Greyfen/Assembly must use these state-aware extras, not an unconditional
community dependency.

Source-only `test_community_story_payload.py`: **6 tests PASS**, including exact
reconstruction, no substantial new prose in base, preserved legacy rows,
compiler idempotence and incomplete-input rejection. The newly authored
`verify_community_story_overlay.gd` is **UNRUN**: it exercises no-read startup,
recorded arrival requirements, malformed payload rejection, same-manager
six/four/six journey switching and unchanged quest state. Full native/parser and
combined PCK resource checks remain required before acceptance.

Follow-up ownership audit also split source localization: `build_source_catalog.py`
keeps stable untagged keys in base `data/localization/en.json` and emits tagged
expansion entries into exclusively community-owned
`data/localization/community_en.json`. `SourceText` only reads the latter after
the story owner has decoded a needed valid overlay. The two new ending ambient
lines now live in `community_campaign.json.ending_ambient` and the overlay, with
their actual `speaker_ids` (`shrine_pilgrim`, `quality_mourner`). They are delivered
through nearby speech plus subtitles; voice inventory must resolve those actual
actors or record its caption fallback, never invent a canonical-cast speaker.
Source tests now pass **7 overlay/localization tests** and **10 full-campaign
contract tests**, including rejection of inherited stat boosts, camera/player
teleports, direct save loads and dynamic gameplay calls. The current Assembly
choice uses actual interactions and the maintained return topology. No unearned
replay/checkpoint is introduced. Newly extended runtime fixtures remain unrun
on this isolated checkpoint; root's separately reported integration fixture
results belong to its exact tested merged bytes.

### Actual-input acceptance harness (authored; native execution pending)

The complete journey entry is `tools/run_full_campaign_acceptance.py`. Its
`full_six_endings` case rejects every seed, starts through visible **New Game**,
records the actual completion signals for all fourteen chapters in order, and
then uses the earned **Return to before the covenant** option for the remaining
alternatives. All six alternatives must enact, reload their completed memorial,
walk home and present the actual epilogue. Peaceful endings also reload after
the first of their three physical ritual interactions. The source receipt gate
rejects missing/reordered chapters, extra progression and incomplete ending
circuits. The runtime must select revision 2 through its normal New Game
handoff; a candidate with `EXPANSION_ENABLED=false` correctly fails this case.
The harness never overrides that switch or the journey's revision.

Four separately labelled boundary cases cover `legacy_ash_missing`,
`legacy_ash_v1`, `legacy_witness_missing` and `legacy_witness_v1`. Their raw saves
must contain exactly the first five or eight original chapters and the proper
next original chapter, at Old Mill or Undercroft respectively. The missing
marker must really be absent; the explicit marker must be 1. They verify hidden
expansion topology, actual save/reload, the remaining original chain and the
four-choice ending UI, then enact Witness through return home. Their seeded
prefix is always reported separately and never counts as full-journey proof.

`community_acceptance_legacy.py` derives its combat input helpers from the
maintained `verify_opening_real_input_native.gd`; both original and generated
bytes are frozen in the run receipt. Explicit current-route overrides use
normal E at the Wychwood Bog, Rootbound and Senn invitations, the current world
graph and current save/choice labels. No source helper is allowed to acquire
direct quest/flag/position mutation. These are authored checks, **not evidence
that the complete route has run successfully**. Source-only full-run contract
checks pass **9 tests**, and the region runner checks below pass **8 tests**.
Full GDScript parsing, combat, movement and all rendered ending circuits remain
**unrun** pending built resources and the shared serial engine slot.

```powershell
python tools/run_full_campaign_acceptance.py --case full_six_endings `
  --root-pack <root.pck> --packs <runtime-packs> `
  --class-cache <global_script_class_cache.cfg> --viewport desktop --prepare-only
python tools/run_full_campaign_acceptance.py --case legacy_ash_missing `
  --seed-save <legacy-boundary-save.json> --root-pack <root.pck> `
  --packs <runtime-packs> --class-cache <global_script_class_cache.cfg> `
  --viewport touch --prepare-only
```

`tools/run_community_acceptance.py` freezes the committed project settings,
generated class cache, harness, seed and complete PCK inputs. It configures a new
custom user directory and redirected APPDATA/LOCALAPPDATA **before** starting the
pinned Godot 4.6.3 process. It mounts root and secondary packs from the script,
never `--main-pack`; timeout cleanup targets only its owned process tree. Input
hashes, output images, engine errors and the exact expected task coverage are
checked by the runner. `--prepare-only` freezes the fixture without starting an
engine. Source-only Python checks pass **8 tests**; GDScript parser and native
execution are explicitly **unrun** until the shared engine slot and built assets
are available. No touch-input or physical-phone acceptance is claimed.

`tools/verify_community_world_input.gd` uses real keyboard/mouse events after
Continue, visible menu focus, actual E interactions and walking. Its live physics
queries and AStar path planning are read-only. It never sets flags, completes an
objective, invokes an action callback, moves the player directly, freezes an
actor, changes the clock or patches input ownership. It covers two-way physical
arrival/return, interrupted trestle work, real work duration, choices followed by
enacted aftermath, the carried first load, interrupted ferry, Quick Save / Main
Menu / Continue, actual consent answers and withdrawal, morning/evening waits,
and all available actors with eight-NPC/ten-total visible-skeleton assertions.

Run these four cases separately at each requested viewport; each case earns six
tasks and their union is the exact fifteen authored work tasks:

| Case | Explicit boundary seed | Branch and availability coverage |
| --- | --- | --- |
| `lantern_crossing` | Old Mill west approach, `main_empty_tables` active before arrival | Central kitchen, public crossing |
| `lantern_ferry` | Same boundary in a fresh profile | Household parcels, ferry and interruption |
| `hearth_distributed` | Undercroft north approach, `main_house_many_names` active before arrival | Distributed records; Senn testimony, cooperative Edric, introduced Nera with no active escort: all twelve across two shifts |
| `hearth_protected` | Same boundary in a fresh profile | Protected records; Senn, Edric and Nera unavailable according to saved outcomes |

Seeds are explicit test setup before startup, not progression earned by this
harness. Supply a raw disposable version-13 campaign save with revision 2, the
proper completed preceding chain, no completed starting-chapter objectives and
no tested work/choices already awarded. The runner rejects a legacy/missing marker,
wrong region, replay seed, pre-awarded work or an incorrect cast matrix. It never
reads or modifies the real user profile. Root must prepare these boundary fixtures
and full PCKs before native execution; this source checkpoint does not fabricate
a passing save or claim native coverage.

Example from the game directory (paths refer to isolated release artifacts):

```powershell
python tools/run_community_acceptance.py --case lantern_crossing `
  --seed-save <boundary-save.json> --root-pack <root.pck> --packs <runtime-packs> `
  --class-cache <global_script_class_cache.cfg> --viewport desktop --prepare-only
```

The `touch` viewport is 960×540 and `desktop` is 1280×720. This harness still
drives keyboard/mouse input at either size; genuine touch-control QA is separate.

Source review correction `bbab27c`: PlayerController's root is at its feet. The
public crossing now accepts the actual .185 m deck height; ferry feet rest at
.25 m over its .24 m deck rather than floating .95 m above it. Safe bank recovery
uses .02 m. Added synthetic tests cover low-foot entry, far-bank appearance,
side-footway and channel detours, complete traversal, and ferry support height;
these additions are unrun pending the serialized small-engine slot. The public
crossing summary no longer attributes work to an unavailable Nera (caption-only).

Implemented source:

- `community_section.gd` constructs Lantern Reach and Hearthward from retained
  houses, trees, cart, crate, barrel, torch and reusable timber/linen/iron joinery.
  There are fifteen physical work assemblies, two landing surveys, a usable
  crossing or ferry, meal/refuge/record arrangements, a public board, shelter
  waits, and two-way connection corridors. Roof collision is explicitly excluded
  from walkable floor support.
- `community_activity.gd` is a RefCounted adapter owned and ticked by the existing
  StoryActivityDirector. Current source instance, menu generation, HUD generation,
  zone owner, proximity, health, threat and eligibility are checked before writes.
  Progress requires actual uninterrupted duration. Movement, weapon draw,
  pause/focus loss, damage, travel and saving discard unfinished work. The ferry
  returns the player to its safe bank before SaveManager captures a snapshot;
  carried supplies persist but an unfinished passage does not. Crossing credit
  requires the selected physical passage before far-bank delivery.
- Participant answers use the actual canonical actor instance; a separate fresh
  menu presents and records the authored answer. Caller-supplied identity/effects
  cannot replace the owner's immutable action. Withdrawal remains available before
  ending lock. Senn's fate, cooperative Edric, Nera's introduction and active
  escort preserve existing availability. Public accounts never infer private
  testimony, trust or consent.
- Hearthward publishes at most eight NPCs per morning/evening shift, leaving room
  for Kael and Bracken under ten visible skeletons. Both shifts together cover all
  twelve eligible canonical actors. Hidden people are noninteractive with disabled
  inherited processing; arrivals enroll in the existing RegionalLifeController.
  The existing rest owner can wait until 07:00 or 18:00. All twelve actor pack
  requirements remain necessary even though their visible presence is sequential.
- `community_cast_life.json` supplies seventeen real workstation bindings plus
  Senn's contact-free watch. WorkStand/Contact/Left/Right and GripLeft/Right markers
  are on actual assemblies. Existing routine, motion and hand-contact owners
  remain authoritative; native contact geometry still needs visual acceptance.
- State-filtered topology, atlas, seamless preparation, arrival objectives,
  safe spawns, actor requirements and per-objective navigation cover both regions.
  Missing/explicit legacy markers cannot enter either new region. Existing regions
  dynamically resolve their old builder; they do not preload the community module.
- Main chapter title remains **A Road Kept Open**. The existing Nera sidequest
  `side_escort_06` is now **The Relief Handover**, avoiding the title collision.

Deferred pack contract (root release owner must integrate):

| Resource owner | Exact resource paths / requirements |
| --- | --- |
| Community runtime | `scripts/community_campaign.gd`, `scripts/community_activity.gd`, `scripts/community_presentation.gd`, `scripts/zones/community_section.gd` |
| Community data | `data/community_campaign.json`, `data/community_cast_life.json` |
| Lantern Reach actors | Existing P01/M13 shared requirements; C02, C04, C05, C06, C11, C12 |
| Hearthward actors | Existing P01/M13 shared requirements; C01 through C12 |
| Retained scenery | Houses, trees, cart, barrel, crate, torch and their existing material closure |
| New aftermath meshes | `assets_external/environment/forest/HartAftermath_concord_Authored.res`, `HartAftermath_open_road_Authored.res` (two surfaces and existing obstacle metadata contract) |

The new destinations must request these dependencies before construction. Saved
expanded Hart Glade outcomes also need the new aftermath resources. Base quest
and revision helpers remain available to unlock destinations before downloading
their content; new region/audio resources must stay outside opening preparation.

Exact text / voice inventory:

- `community_campaign.json`: `participant_lines.*.{lantern_reach,hearthward}` uses
  the row's explicit `speaker_id`; `consent_offers.*.{yes,no,withdraw}` uses the
  offer's explicit `speaker_id`; `.question` uses `question_speaker_id: player`.
- `chapters.*.{summary,stakes}` and `public_accounts.*` are consumed directly as
  separate exact `speaker_id: narrator` pages. They are caption-only. Live work,
  shift and consent rosters are `speaker_id: system`, also caption-only.
- `covenant_resolution.gd` JSON-shaped `STEPS.share[*][1]` and
  `STEPS.depart[*][1]` are the six exact new narrator ritual pages (caption-only).
  `STEPS.*[*][0]` is the runtime prompt; do not invent spoken performance for it.
- `campaign_dialogue.json` White Hart's revision-2 variant and its two new ending
  actions carry `source_tag: campaign_revision_2`. The six
  `interaction_scenes.json` roots `aftermath_{names,work,road}_{concord,open_road}`
  carry the same source tag. Use canonical actor + exact runtime text for audio.
- Work results, survey/delivery guidance and public roster status are HUD captions,
  not additional NPC speech. No duplicate list of drifting subtitle text exists.

Verification recorded before the latest source refinements:

- In-memory `verify_community_activity.gd`: **PASS 12**; pure graph/routes:
  **PASS 75**; actual quest/rules/save value fixture: **PASS 214**;
  objective ownership: **PASS 132**; campaign/replay revision fixture: **PASS 435**.
- Each ran parser-first on pinned Godot 4.6.3, with APPDATA/LOCALAPPDATA redirected
  before engine startup. `community_section.gd --check-only` also passed. Exact
  logs are under worktree `.release-gate/community-runtime/tests/`.
- **Rerun required for this checkpoint:** subsequent ferry-save, actual participant
  answer/withdrawal, strict speaker, shift-budget and roof refinements extended
  the fixtures after those runs. They are explicitly unverified at this checkpoint;
  the shared host is reserved for combined-release browser acceptance. No new
  engine was started during that quiet window.
- No full world, native model/contact, real input, browser, Web export, physical
  phone, performance or deployment acceptance is claimed. Required follow-up is
  parser/pure tests, resource closure and old-save/replay matrix, then both route
  branches and all six endings at desktop/touch viewports using isolated profiles.
  Check shift changes, waiting, return travel, save during ferry, interruption,
  actual held-work geometry and all declared availability cases in that session.

### Review corrections after `ad782d0` (source only; tests pending)

- A deferred reading-history save can occur after the next consent answer page
  opens. Save cleanup now cancels physical activity with `cancel(false)`, preserving
  the current owned menu generation. The synthetic activity fixture covers a save
  between hearing the willing answer and recording it.
- The six expanded aftermath scenes declare `required_actors` and `primary_actor`.
  Actual visible, nearby, living registered actors are required for spoken scenes.
  When somebody is absent, `unattended_pages` supplies two authored narrator-only
  public-work captions. These pages are consumed directly by runtime and tagged
  `campaign_revision_2`; include all twelve in the caption inventory. An absent
  person's words are never relabelled as a purported recording. Canonical source
  instance IDs bind present speakers; the correct primary actor owns the scene.
- Concord's work scene no longer attributes the weather allowance to Nera when
  she may never have joined this journey. Its Rook line now begins "The rota
  leaves a gap for weather." Regenerate that exact spoken line during integration.
- `verify_community_aftermath.gd` covers full/partial/absent cast projection and
  immutable source data. It is explicitly unrun during the shared quiet window.

### Measured regional work geometry (following `e7388e2`)

The original guessed community palm targets are superseded. Regional native work
now reuses `living_cast_stations.gd`'s measured props and furniture after region
publication, before enrollment: seven `station_<identity>.scn` props with geometry
GripLeft/Right markers, Anwen's care table/cloth/staff, Mira's actual retained
apothecary/rack/leaves, Rook's supported .93 m table/satchel and Tor's supported
.92 m repair beam plus held hammer. Native stand directions and relative contact
distances are retained. The actual construction tasks remain separate player work
assemblies; their generic unfinished parts no longer masquerade as native palm
contacts. Data names the real `LifeWork_<identity>_community` nodes and actor feet.

This requires the Stage2 shared helper's explicit-station duplicate guard,
WorkStand-to-WorkContact facing, and `held_tool`/repair hammer-head support. The
seven task prop scenes, `GreyfenSocial_mira_apothecary.res`,
`GreyfenSocial_barrel_board.res`, `rook_station_satchel.scn`, and `Fern_1.obj` must
be in the destination closure. Anwen keeps its cloth; surface-prop workers suppress
duplicate held props; Tor explicitly retains his hammer. The synthetic activity
fixture passes `build_stations=false` so pure tests never instantiate model assets.
No native contact, floor-clearance or camera acceptance has run for this geometry.

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


## Historical checkpoint after authored community data (2026-11-07)

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
7. The title collision noted at that checkpoint is resolved above: the main title
   remains **A Road Kept Open**; the older sidequest is **The Relief Handover**.
8. Collect/render exact new spoken lines and ritual/aftermath lines; add both
   authored Hart memorial resources at the paths specified above. Run the new
   fixture, original core/ownership fixtures, parser/resource checks, complete
   save/import/replay/legacy matrix, six-ending runtime acceptance, pack/Web gates,
   and desktop/touch real-input gameplay. Enable revision 2 only when the coherent
   complete expansion passes together; never publish an incomplete required chain.
