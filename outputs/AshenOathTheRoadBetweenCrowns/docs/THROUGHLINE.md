# The Unfinished Oath: Campaign Throughline

## Kael's Driving Question

**Can I protect people without deciding what they must owe me, and can I answer
for leaving people behind without buying their forgiveness?**

The abandoned escort is Kael's personal failure, not an alternative explanation
for the concealed massacre. Maren owns her account and present relief work.
Learning more never entitles Kael to consent, romance, testimony or absolution.
Witness, Mercy, Duty and Ash are available in both campaign revisions. The
expanded journey adds Concord and Open Road with their own prerequisites.
Optional discoveries deepen decisions while remaining optional.

## Campaign Revisions

[CampaignRevision](../scripts/campaign_revision.gd) selects the expanded graph
when creating a new journey. A save without a revision marker keeps the
original graph. Continue, import and replay use the saved revision. Writers
should check both the base [quest definitions](../data/quests.json) and the
[community chapters](../data/community_campaign.json) before changing main
quest order or prerequisites.

## Regional Dramaturgy

| Region | Structural purpose | Dominant play | What carries forward |
| --- | --- | --- | --- |
| Greyfen and its cemetery | Plant the oath in people worth coming home to; expose its first cost. | Useful village work, personal reporting, the grave investigation and Bell-Eater survival before the shrine. | The report's privacy, shrine fate, protected names and remembered help. |
| Wychwood | Widen who was bound: the missing are people, and the forest is also someone's livelihood. | Tracking the travelers, speaking a recovered name, territorial confrontation and settling the core. | Names and behavior learned in the first investigation change the meaning of the binding. |
| Deep Woods / mill / farmstead | Turn knowledge into material responsibility: food and shelter can be useful and compromised. | Clear the workers' route; optionally open the sluice and escort them to air; face Ashwing; determine the mill's operation. | Rescued workers, preserved records, smoke damage and the actual flour policy. |
| Lantern Reach | Give the mill's decision a material follow-through in expanded journeys. | Prepare meals, agree on distribution, then repair the public crossing or rig an escorted ferry. | Food distribution, obligations for upkeep and the first load reaching the far landing. |
| Long Road and marsh | Test protection without ownership. | Read the crossing, negotiate a stand-down or fight Senn's guards, then settle accountability. | Senn's legitimate presence or absence, stores retained by the crew and a road no longer presented as his property. |
| Castle Vargan | Reckon with the institution, not another scavenger hunt. | Gain access, secure/copy the command, survive the archive and demand Edric's answer. Corroborating roadside traces are optional. | Guaranteed command proof and Halvern's bounded hearing, never invented knowledge of skipped clues. |
| Hearthward | Put shelter, protected testimony and voluntary work into practice in expanded journeys. | Prepare the refuge, settle record custody, test the meal round and alarm, and complete the first watch. | A staffed rota, recorded refusals and a refuge ready to receive households. |
| Hartlands | Choose the responsibility Kael will personally carry. | Hear the Hart and enact Witness, Mercy, Duty or Ash, rather than collect another set of keys. | A changed covenant, continued exploration and the full playable return home. |
| Greyfen Assembly and homecoming | Bring dispersed accounts into a public reckoning, then show what survives in ordinary life. | Prepare willing speakers or absent people's records; stop renewal; return names, work and a final road reflection. | Help is not conditional on testimony. Returning is an action, not merely ending text. |

## Shared Main-Quest Rhythm

1. `main_road_of_crows`: a named missing-person investigation; retain three of
   five clues, the existing encounter and an explicit private/public/retained report.
2. `main_bell_beneath_greyfen`: a contained grave investigation becomes survival,
   opening the chapel and Bell-Eater's required defeat before the shrine decision.
3. `main_teeth_in_rain`: optional preparation, a name spoken at the stones,
   territorial confrontation and a core resolution. Preparation is not compulsory.
4. `main_names_they_burned`: the deliberate exception: reconstruct three surviving
   fragments, then decide their disclosure. Preserve this investigation because
   restoring an account is its actual dramatic action.
5. `main_ash_at_the_mill`: combat, environmental counterplay and optional worker
   rescue, followed by Ashwing and a practical food decision. Millstone examination
   is useful context, not a prerequisite for helping anyone or advancing.
6. `main_soldier_without_banner`: earned stand-down or confrontation, then
   accountability. Peaceful resolution retains equivalent progression.
7. `main_blood_under_stone`: access, command recovery, survival and confrontation.
   The three-trace summary and all five corroborating traces are optional; the
   archive proof remains mandatory and reachable without them.
8. `main_last_witness`: a disciplined encounter or earned peaceful hearing, then
   a bounded account. Halvern does not supply omniscient testimony.
9. `main_crowns_without_mercy`: social convergence and public action, not another
   collection quota. Records can represent absent/refusing witnesses.
10. `main_hart_remembers`: testimony, commitment and enacted consequence. No
    compulsory sacrifice of somebody else and no new ending gate.

### Expanded Chapter Order and Follow-Through

The expanded journey inserts the following chapters into that sequence. The
objective IDs, completion flags and authored alternatives are defined in
`community_campaign.json`.

| Placement | Chapter | Required action and consequence |
| --- | --- | --- |
| After Ash at the Mill | The Empty Tables (`main_empty_tables`) | Reach Lantern Reach, hear the households, prepare the kitchen and serve the first meal. Choose a common kitchen or distributed household shares. Access to food is unconditional. |
| After The Empty Tables | A Road Kept Open (`main_road_kept_open`) | Survey both landings, choose the public crossing or ferry, perform the corresponding repairs, and accompany the first load across. Each route carries its own maintenance work. |
| After The Last Witness | The House of Many Names (`main_house_many_names`) | Prepare shelter at Hearthward, welcome arrivals and decide how to distribute the public account while protecting private testimony. |
| After The House of Many Names | What We Promise (`main_what_we_promise`) | Hear available speakers or written answers, practice the meal round, alarm and records handover, then post a voluntary rota and finish the first watch. |

A Soldier Without a Banner follows A Road Kept Open. Crowns Without Mercy
follows What We Promise. The [story campaign catalog](../data/story_campaign.json)
sets out the costs and enactment for each ending. Concord needs the four
community chapters and willing keepers for care, logistics and records. Open
Road needs the four chapters, a working route and a prepared refuge. It gives
up territorial protection and access to the Hart's complete account, while
preserving the human records and giving the households a place to go.

## Objective and Save Contract

- Existing quest/objective IDs remain. The mill adds only two optional objectives:
  `open_mill_sluice` and `escort_mill_workers`.
- Their `story_flag` bindings credit the existing action owners' committed
  `mill_ventilation_open` and `mill_workers_rescued` facts. Rescue is not credited
  merely for starting the escort, defeating Ashwing or choosing the mill's fate.
- Published arrival/choice projection synchronizes that work, including genuine
  older saves and actions performed before quest activation. Destination prebuilds
  cannot mutate the live journal. No extra XP or reward is attached.
- QuestManager rebuilds unfinished saved objectives from current definitions while
  preserving each recorded `done` value. Completed quests do not reopen. Unknown
  optional history remains unknown; no skipped inspection is inferred as done.
- Optional Castle group summaries can record genuine corroboration but cannot
  block access, a choice, required progression or the primary tracker. Required
  objectives take tracker priority; optional work remains in the journal.

## Physical Connections

`world_sector_manifest.json` owns both road links and their `road_landmarks`.
The atlas names those same landmarks. ConnectedRoadGeometry constructs paired
landmark halves from each link's crossing frame, not the atlas's not-to-scale
coordinates. Each half lies on its own side of the seam and outside the walkable
lane; existing ground, bends, gates, collision and story locks are unchanged.

| Connection | Shared sightline |
| --- | --- |
| Greyfen / Wychwood | Twin warning frames |
| Wychwood / Deep Wood | Broken forest aqueduct |
| Deep Wood / mill | Hauling gantries |
| Mill / farmstead | Scorched supply arches |
| Farmstead / marsh | High-water signal frames |
| Marsh / checkpoint; checkpoint / Vargan | Paired watchtowers |
| Vargan approach / courtyard | Gate bastions |
| Greyfen west / Deep Wood | Old western aqueduct |
| Greyfen crown road / Vargan | Crown-road watchtowers |
| Greyfen / Hart; Hart / ruins | Split oath arch and broken sanctuary arch |

These are physical roadside silhouettes, not duplicate functional bells, new
quest locations or distant replicas of entire worlds. Interior passages retain
their actual entrances. Static box components share one MultiMesh per landmark;
no extra lights, new downloads, landmark collisions or continuous update loop.
Gameplay-camera visibility and appearance still need user review.

## Visible Consequences, One Authority

Dialogue `sets_flags` continues to commit through StoryState and the existing
decision transaction. World decoration and cast schedules project those flags;
neither can write a choice, award a reward or invent consent.

| Committed fact | Tangible projection |
| --- | --- |
| `iron_fate=tools/memorial` | Tor works on the selected tools/fittings; tools move his work to the retained timber area. Existing iron presentation remains authoritative. |
| `senn_fate=testimony/exile/punished` | Tavin shifts to crossing stores; Nera checks the crossing; stored toll rails and a folded pennant replace the command's presentation. Existing presence rules retain/remove Senn appropriately. |
| `renewal_stopped=true` | Vargan banners are folded, Assembly cloth is lowered, order captions state withdrawal, and Lysa works on retained originals and corrections. Essential records and speakers stay reachable. |
| Existing report, shrine, mill and covenant flags | Retain their existing kitchen, cemetery, mill, witness and Hart projections; do not duplicate them. |

`cast_life.json` contains ordered `consequences` overrides matched by exact flag
and value. They alter intent/locations/line, not population. The life controller
uses its existing safe-point routine change, path validation and interruption
ownership. A moved workstation does not retain an obsolete hand-contact anchor.
Schedules, sleep, dialogue, danger and quest access keep their existing rules.

## Delivery and User Review

The [first-route evidence](../../../plans/living-road/COHESIVE_GAME_IMPLEMENTATION.md)
records the native Road of Crows playthrough and its fresh-process save reload.
The remaining routes, branch consequences and performance gates need their own
evidence. The 256 MiB package ceiling applies to delivery.

User checks:

1. Follow the mill without inspecting stones; optionally complete/interupt/resume
   the sluice and worker escort, then Continue. Check actual journal credit only.
2. Reach the archive without three roadside clues; preserve the command and
   continue through Edric, Halvern and Assembly. Discover corroboration later.
3. Compare the named landmarks with the atlas from both sides of each connector;
   check uninterrupted passage, camera clearance, returns and appearance.
4. Resolve iron/Senn/renewal differently on genuine checkpoints; observe work,
   banners, absent actors and signs immediately and after Continue/zone return.
5. Confirm optional omissions preserve Witness, Mercy, Duty, Ash and homecoming.
   In an expanded journey check Concord and Open Road against their recorded
   prerequisites and follow-through.
