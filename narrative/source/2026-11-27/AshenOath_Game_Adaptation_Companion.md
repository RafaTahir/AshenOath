# AshenOath: The Road Between Crowns
## Novel-to-game adaptation companion

### Scope and source boundary

This companion turns the completed novel into an implementation plan while preserving the game's alternate choices. The novel follows one continuous route through the expanded campaign: protected testimony, a working common kitchen and ferry, a prepared refuge, voluntary public witnesses, and Open Road. Its chosen romance is Mira. These selections establish the book's continuity; they do not invalidate other player journeys.

The implementation baseline is **RafaTahir/AshenOath, commit 724821915f0b4a02677a862c7472a7fe5af3dcc7**, reviewed on 27 November 2026. Current source has fourteen main quests, forty-seven side quests and six ending methods for expanded journeys. The older projection retains ten main quests and four endings. The chapter mapping below uses existing identifiers; it does not propose replacing fourteen quests with thirty-six compulsory quest entries. Several novel chapters deepen one existing objective, and some dramatize optional relationships or aftermath. [S1–S4]

Three kinds of material are distinguished throughout:

- **Existing:** an identifier, rule or content owner present in the pinned repository. Source wiring does not establish that its full presentation has been playtested.
- **Novel selection:** a particular existing choice, or a clearly identified closest equivalent, followed by the book.
- **Proposed adaptation:** new dialogue, staging, personal history, geography, injury, encounter behavior or persistence needed to reproduce the book. These additions have not been committed to the game.

The completed novel establishes its particular events. The repository remains the authority for what the current game implements. Where they differ, the difference is recorded rather than silently converting literary invention into an existing feature.

## 1. Chapter-to-quest mapping

The complete expanded main sequence is preserved in order. Side stories can still be declined, postponed or resolved differently. The prologue is proposed introductory dramatization of the missing travelers; it is not an existing playable quest or permission to reveal the entire mystery before Kael arrives. [S1–S3]

| Chapter | Existing quest anchor | Adaptation purpose |
| --- | --- | --- |
| 1 — A Hunter's Price | `main_road_of_crows` | Establish ordinary paid work, Greyfen's routines and Kael's intended departure. Cart assistance makes his first relationship concrete. |
| 2 — The Broken Cart | `main_road_of_crows` | Recover bounded physical clues through Wychwood combat. Wire suggests intervention without establishing who caused the attack. |
| 3 — What We Brought Back | `main_road_of_crows` | Make the reporting choice, custody and Kael's decision to stay playable rather than automatic. |
| 4 — A Widow's Bell | `main_bell_beneath_greyfen`; `side_widows_bell` | Connect cemetery investigation to Elna's marriage and Harl's incomplete account. |
| 5 — The Rope | `main_bell_beneath_greyfen` | Prepared Bell-Eater encounter; Anwen's novice account; temporary chapel containment. |
| 6 — The One Who Returned | `side_escort_01`; `side_bracken_rescue` | Nera recognizes Kael during relief work. Bracken remains a dependent animal, without granting forgiveness. |
| 7 — Under Green Water | `main_teeth_in_rain`; `side_black_dog`; `side_bitter_roots` | Toma's protection secret, Pell's treatment and Mira's disclosure precede the bog. |
| 8 — The Name in the Reeds | `main_teeth_in_rain`; `side_childs_charm` | Oren's bounded fragment, private return and actual burial. Preserve the distinction between body, object and memory. |
| 9 — No Footsteps Back | `side_escort_02`; approach to `main_names_they_burned` | Nera's present survey challenges Kael's account. The novel's additional footbridge is proposed geography. |
| 10 — The Names They Burned | `main_names_they_burned` | Recover partial registers; earn passage through the Colossus encounter; establish Anwen's full present concealment chain. |
| 11 — The Widow's Version | `side_widows_bell`; `side_rooks_map`; `main_names_they_burned` aftermath | Separate institutional disclosure from Elna's private marriage memories and family addresses. |
| 12 — What We Carried | `side_escort_03` | Physically recover the medicine load after consulting Nera, Mira and Tor. |
| 13 — Ash at the Mill | `main_ash_at_the_mill`; `side_millers_measure` | Ashwing, worker rescue and attributed accounts connect inherited harm to present livelihoods. |
| 14 — Iron Remembers | `main_ash_at_the_mill`; `side_iron_remembers` | Supervised milling, replacement work and Tor's proposed lasting wrist injury. |
| 15 — Bread and Ash | `main_ash_at_the_mill` aftermath; existing Mira relationship scenes | Rest, intimacy and the renewal threat. No new compulsory romance quest. |
| 16 — The Empty Tables | `main_empty_tables` | Prepare the common kitchen. Rook's route-sharing betrayal is a proposed parallel scene. |
| 17 — A Place at the Table | `main_empty_tables` | Complete service and accounts; Rook admits the disclosure before the later interception. |
| 18 — A Road Kept Open | `main_road_kept_open` | Choose the ferry, prepare both banks, accompany and unload a real first load. |
| 19 — A Soldier Without a Banner | `main_soldier_without_banner` | Earn Senn's stand-down through a dangerous, spatially clear encounter. |
| 20 — The Officer's Hand | `main_soldier_without_banner`; `side_soldiers_debt` | Custody, restitution inventory and separately voluntary testimony. |
| 21 — Hold the Rear | `side_escort_04` | Protect the rear under Nera's direction. The patrol interception and Rook's injury expand the existing crossing. |
| 22 — The Man Who Keeps Keys | `main_blood_under_stone`; adaptation of `saga_var_q03` | Archive access, Merrow's choices and detained workers. Introduce the proposed Refusal Book. |
| 23 — Blood Under Stone | `main_blood_under_stone`; optional `saga_var_q01` comparison | Distinguish the old command from Edric's later suppression. Copy and preserve primary proof. |
| 24 — The Price of Bread | `main_blood_under_stone` | Expose current coercion; refuse a settlement preserving household assent. |
| 25 — The Last Witness | `main_last_witness` | Halvern's bounded hearing and release in the undercroft, after an earned defensive encounter. |
| 26 — The Word Retreat | `side_escort_05` | Kael corrects his separate report. The novel relocates the conversation and marks remembered wording as reconstruction. |
| 27 — The House That Was Empty | `main_house_many_names` | Survey Hearthward and establish only basic first-night shelter. |
| 28 — The House of Many Names | `main_house_many_names` | Complete beds, care space and dry records; welcome actual first arrivals. |
| 29 — What Remains Private | `main_house_many_names` aftermath; relationship continuation | Protect intimate material; confront Kael without treating love as acquittal. |
| 30 — What We Promise | `main_what_we_promise` | Test meals, alarm and handover; record individual answers; complete the first watch. |
| 31 — The Refusal Book | Proposed optional scene before `main_crowns_without_mercy` | Secure a current grain-refusal duplicate. It supplements guaranteed main proof. |
| 32 — Crowns Without Mercy | `main_crowns_without_mercy`; affinity with `saga_var_q04` | Remove the ration condition before witnesses speak. A supply-office side quest cannot substitute for Assembly completion. |
| 33 — The Hart Remembers | `main_hart_remembers` | Hear the complete old account; weigh actual alternatives; select a method without instantly completing it. |
| 34 — The Last Load | `main_hart_remembers`, `depart` enactment | Dismantle the territorial ward, lose Hart access and begin physical migration. |
| 35 — The Man Who Came Back | `main_hart_remembers`, `depart` delivery | Rescue and deliver both dependent households. Flood failure and calf injury are proposed additions. |
| 36 — The Relief Handover | `side_escort_06` after covenant completion | Reconcile actual goods and routes; offer company without claiming reconciliation. |

The six-month epilogue is proposed extended aftermath. It can enrich the existing epilogue resolver and world consequence scenes, but a seasonal time advance, rehabilitation state and Mira's coast journey require new authoring. They are not present merely because an epilogue system exists. [S5]

Two mappings require explicit changes. Current `saga_var_q03` describes Toma's release and impounded tools; the novel instead has him petition for three detained seasonal workers. Reauthor the side quest if adopting that correction, including journal and dialogue references. Current `side_escort_06` begins at the changed glade and finishes through Greyfen's homecoming. The novel places its physical handover at Hearthward after Open Road's delivery. Support a route-specific handover location while retaining the other endings' homecoming, rather than moving every save to Hearthward. [S3]

## 2. The selected route and its valid alternatives

A selection table is useful for authoring and replay fixtures; it must not become a script that sets every flag at once. In the game, each result belongs to a validated interaction and its actual objectives. The following values exist in the current narrative catalog or runtime. Rows identified as a closest equivalent still need a deliberate adaptation decision. [S2, S4, S6]

| Subject | Novel selection / existing representation | Alternatives to retain |
| --- | --- | --- |
| First report | `evidence_report=private` | `public`, `retained`; preserve different risks and disclosure. |
| Chapel | `crow_shrine_state=bound` | `cleansed`, `disturbed`; temporary containment never becomes a cure. |
| Oren's fragment | `bog_core_fate=returned` | `preserved`, `destroyed`; ordinary treatment remains available. |
| Recovered register | `names_policy=withheld` | `published`, with addresses removed. Later public institutional facts do not publish every intimate record. |
| Mira's treatment | Closest: `mira_truth=confessed`; Pell's family chooses clean roots | Quiet continuation or closing the ash bed are separate choices. One patient's refusal need not close every treatment. |
| Toma's guardian | `guardian_plan=supervised` | `relocated`, `killed`; disclose continuing danger. |
| Mill | `mill_operation=supervised` with negotiated clean repair | `closed`, `restitution`. Supervised operation does not automatically complete all restitution. |
| Tor's iron | Closest: continued useful stock with disclosure/replacement; `iron_fate=tools` is the closest catalog value | `memorial`, `surrendered`. The novel's combined repair details do not establish three simultaneous outcomes. |
| Rook's family map | `rook_disclosure=protected` | `erased`, `public`. His later unauthorized relief schedule is a different proposed event. |
| Elna | `widow_truth=private` | `told`, `comforted`; grief and testimony remain hers. |
| Senn | `senn_fate=testimony` | `exile`, `punished`; written proof survives without a living oath. |
| Edric | `edric_stance=exposed` | `cooperate`, `compelled`; pressure can produce evidence, never voluntary covenant assent. |
| Halvern | `halvern_fate=released` after recording | `witness`, `destroyed`; all preserve the main command proof. |
| Assembly | `confession_method=witnesses` | `kael`, `edric`; all remove the coercive ration condition. |
| Kitchen / passage / records | `community_distribution=central`; `community_route=ferry`; `community_records=protected` | Household shares; repaired public crossing; distributed public copies with sealed private testimony. |
| Nera's middle route | `side_escort_03_outcome=medicine`; `side_escort_04_outcome=rear`; `side_escort_05_outcome=protected` | Tools; approach duty; public self-correction. Do not publish Nera's account as a side effect. |
| Nera's final answer | `side_escort_06_outcome=company` | `distance`; cooperation still works. |
| Romance | `lr_commitment_partner=mira`, through her authored prerequisites | Vale, neither partner, and ending a commitment. No romance with Nera is introduced. |
| Final method | Action `depart`; final outcome `open_road` | `expose/witness`, `free/mercy`, `bind/duty`, `kill/ash`, `share/concord`. |

The book makes Concord genuinely available before choosing Open Road. Mira accepts care, Nessa logistics and Vale records. Anwen refuses another standing promise; Nera offers bounded relief work rather than a permanent shift. The existing gate requires current explicit consent from at least one person in each pair: Anwen/Mira, Nera/Nessa and Vale/Merrow. Their answers belong in `community_keeper_consent`, not a relationship score, completed favor or Kael's declaration. [S4]

Departure has separate answers in `community_departure_consent`. Rook staying in Greyfen does not invalidate his help. Edric staying to answer at the Keep does not make the records unavailable. Senn's decision to travel does not erase his custody. Nera can lead the migration and depart again without choosing Hearthward as her permanent home. These distinctions prevent a technically convenient party roster from quietly deciding everyone's future. [S7]

## 3. Six endings as dramatic scenes

The final discussion should emerge from what the player has actually built and whom they know. Anwen can fear another indefinite binding; Nessa can calculate an empty shift; Vale can distinguish a copy from the experience it records. Avoid assigning each character one permanent ideological position or presenting six consecutive speeches. Short interruptions, practical objections and physical preparation make the choice legible without flattening it.

The catalog makes the original four methods available independently of the new community gates. Actual enactment still belongs to the final quest, its confession state and its ritual or encounter. Concord and Open Road require the expanded revision and completion of all four community chapters. [S4, S8]

### Witness — `expose` to `witness`

Stage a public act of acknowledgment, with Kael responsible for preserving and answering to the account. Named volunteers participate only within their agreed scope; an empty place remains empty. Let the practical cost appear immediately: records must be kept accessible, restitution discussed and trade protected when old privilege no longer provides cover. A reduced-support run places more work on Kael, without inventing a missing person to fill the table.

This route's defining action is public recognition and continued responsibility. Publicly exposing Edric earlier does not already complete Witness. The Assembly resolves coercive authority; the final covenant resolves the Hart's situation and the future keeping of the account.

### Mercy — `free` to `mercy`

Make the release a witnessed, completed action. A small willing circle safeguards the recovered account and vulnerable identities. The player can hear the last accessible fragment end while a living keeper closes the protected packet. Institutional wrongdoing remains documented; a household's private grief need not become a public performance.

Its risk is future neglect and incomplete public acknowledgment. Do not describe safeguarded copies as containing every sensation or missing name the complete supernatural witness held. Mercy differs from Witness in disclosure and continuing public obligations, not in whether the writer approves of the player's compassion.

### Duty — `bind` to `duty`

Give Kael a clear opportunity to stop before accepting his own burden. Helpers can defend the rite and share food or repair work; none can be signed into his bond. After immediate stability arrives, show a specific limitation on his freedom or rest. A familiar road may be visible while he must remain with the keeping.

Preserve unfinished restitution and personal relationships. Duty should not supply moral superiority, cure the old escort failure or make Mira/Vale obliged to remain beside him. Its strong scene is a freely accepted cost whose weight the player can perceive.

### Ash — `kill` to `ash`

Use the existing Hart Avatar combat path, with advance clarity that destroying this witness will lose something copies cannot replace. Defensive violence elsewhere need not be retroactively condemned. Afterward, human evidence still supports responsibility and care, while dispersed memory harms land and future harvests.

Give the player active aftermath: damaged ground to inspect, a household to assist, surviving copies to protect. Avoid a triumphant reset or a closing voice that restores all lost information. Nera's eventual handover still occurs after the enacted result and does not summon the Hart back.

### Concord — `share` to `concord`

Show three actual responsibilities passing between willing people: care, passage and records. A keeper names the shift they accept; the next person checks the handover. Kael takes his own turn. The Hart can rest because the arrangement has owners, not because the community has acquired a collective voice that consents for everyone.

The acceptance snapshot and current willingness are different. Existing rules permit continuing withdrawal after enactment. A vacancy can close a staffed route temporarily or require reorganization; food, shelter and safe alternatives must remain available. Write a later scene where a tired keeper leaves and the community respects the answer before finding another volunteer. [S4]

### Open Road — `depart` to `open_road`

Preserve the book's three separate thresholds: choosing departure, dismantling the protection, and delivering people. Read the households' actual requests; keep named companions' answers separate. The boundary goes dark only after the route and refuge are prepared. The Hart withdraws with complete knowledge that human copies cannot reproduce.

Then require the migration. The current implementation tracks carrying, crossing, delivery and arrival before completion. The novel's flood and two rescue trips can deepen that work, but cannot turn it into a choice whose result is merely a text card. Once the ward is dismantled, interrupted play or reload must not restore it. Once the dependent households arrive, give room for relief, anger over losses, ordinary work and Nera's separate handover. [S7]

## 4. Twelve supporting arcs and their implementation needs

Kael's throughline is the difference between obeying an initial retreat and choosing never to return afterward. The novel makes him admit both, then return for people during the final evacuation without pretending that one rescue repairs eight years. His future consists of accountable work, affection and limitations. The supporting cast must remain larger than that lesson.

| Character | Novel arc | Adaptation requirement |
| --- | --- | --- |
| Anwen | Present concealment is exposed; she continues care while accepting anger. She refuses another indefinite promise and chooses where to work. | Preserve the distinction between last winter's novice death, the travelers' recent visit and the old massacre. Give her useful care scenes after confession, without immediate restoration of trust. |
| Rook | Protects family privacy, then trades an address-free relief schedule without permission. Admission precedes interception; injured ribs and restricted access follow. He chooses Greyfen. | New betrayal state must be separate from `rook_disclosure`. Preserve humor and trade competence after lost trust. Food and treatment continue while route-book access changes. |
| Mira | Discloses treatment origin, offers an alternative, loves Kael and remains angry. Her own practice and planned coast visit continue. | Use independent interest/commitment answers. Healing cannot purchase romance; romance cannot replace treatment disclosure. Later dialogue must remember whether love has already been declared. |
| Tor | Admits filed iron marks, helps negotiate replacement and loses ordinary use of his left wrist. He learns to delegate without becoming passive. | Proposed persistent brace and work limitations affect staging. Keep his measurements, awkward tenderness and authority as a craftsperson when another person does the lifting. |
| Elna | Corrects Harl's kinder family account while keeping intimate memories private. She supports others and declines public testimony. | Do not treat private grief as hidden evidence the player must extract. Return her physical bell; a rubbing can remain with Kael. |
| Toma | Protects his daughter imperfectly, discloses the guardian and becomes an active worker and petitioner. | Reconcile the current prisoner-garden wording if adopting the novel. Pell is his daughter; care arrangements must exist whenever he leaves her. |
| Senn | Gives up command, admits the old closure and current killings, speaks voluntarily while guarded, and does practical work without acquittal. | Track custody separately from testimony and residence. Other game routes may exile or execute him, so later scenes require surviving-actor checks. |
| Edric | Competent provisioning coexists with deliberate coercion and six-year suppression. Exposure removes unilateral ration power; inquiry continues. | He was a child during the massacre. Never rewrite him as its commander. Refusal to swear does not make documentary proof insufficient. |
| Vale | Preserves sources and private testimony while choosing a life beyond archive custody. She is curious, fallible and capable of amusement. | Keep observation, copy and inference distinct. The book selects friendship; her existing romance remains valid. A record keeper cannot consent for the people in a file. |
| Merrow | Procedure conceals fear and limited generosity. He owns the inspection order, risks securing his refusal duplicate and loses unchecked authority. | Keep the proposed Refusal Book narrow and optional. Supervised copying after his fall is not the same as immediate restoration of office. |
| Nessa | Builds meals and teaches others, resists being assigned endless maternal labor, and accepts a bounded logistics role. | Show fuel, portions, relief cover and a real refusal option. A kitchen must remain usable when its founding cook rests or leaves. |
| Nera | Directs six relief beats, controls her account, names Kael's omission and retains her future. The final company is an evening's offer. | Never convert cooperation into forgiveness or romance. Preserve the post-covenant timing and actual work of `side_escort_06`, with ending-specific destinations. |

These arcs draw on the current unified twelve-person cast. Legacy aliases in Saga and other data are routing/history concerns, not additional contemporary characters to reintroduce. Small recurring people—Siv, Bera and the novel's named dependents—need their own identity and custody notes if adopted, but should not expand into redundant replacements for established roles. [S3, S9]

## 5. Clue, reveal and custody provenance

The mystery works because different sources answer different questions. A clue should update what the player may infer, not manufacture certainty. The existing campaign evidence catalog and journal can hold these distinctions, but each proposed detail needs its own disclosure gates and source text. [S2, S10]

| Source or object | What the novel establishes | Boundary to preserve |
| --- | --- | --- |
| Oren's painted brass token; restored AVEL; red cord and burial thread | Travelers' human connection, prior shrine contact and a particular unstable fragment | AVEL is a proposed name. A true name is not a universal command or resurrection mechanism. |
| Manufactured binding wire, tracks and later patrol receipt | Recovery intervention after the attack, corroborated through different source types | Wire alone cannot timestamp the attack or prove Edric ordered it. The receipt and Anwen's note of a patrol claim are distinct. |
| Deep Wood tally, shrine pages and Rook's inherited household book | Promised sanctuary, inconsistent returns and families still missing people | They are partial records. Rook did not witness events thirty-two years earlier. |
| Mill ledger, wages, marks and copied totals | Material links between displaced people, ash and present production | A wheelkeeper interprets milling practice, not the whole massacre. Signed copies precede disposal of a ruined working sheet. |
| Harl's bell and private written account | His gate action alongside Elna's marriage memories | Tenderness does not erase participation; private memories need not be read to the square. |
| Senn's account | His orders, obedience, current raids and limits of recollection | Custody does not constitute voluntary testimony. His account cannot establish every other person's intention. |
| Old command and false-return ledger | Institutional orders and the old concealment | The original returns under witnessed seal to Vargan; checked copies travel. Do not silently substitute a later suppression order. |
| Edric's six-year suppression instruction | A separate, later decision to conceal | He did not command the old massacre. Vale retains its original; copies are additional protection. |
| Merrow's inspection warrant and proposed Refusal Book | Current seizures and specific grain denials | These do not supply complete old supernatural truth. The optional duplicate must not become the only way to challenge coercion. |
| Halvern | Sanctuary, refusal and execution within his fragment | No later Edric knowledge; no omniscient account of Kael's escort. Recording precedes release. |
| Kael's correction and Nera's offered account | An unrelated escort eight years ago; retreat and subsequent failure to return | In the novel Kael reconstructs remembered report wording. The original has not conveniently appeared at Vargan. Preserve challengeable provenance. |
| White Hart | The sole complete supernatural account of the old atrocity | Truthfulness is not omniscience. Human notes remain partial after complete access is lost. |

Keep physical custody visible when it changes. A protected copy is already at Hearthward before the final landing fails; Oren's token remains wrapped with Kael; Harl's bell has returned to Elna. Losing a bow or a chair is consequential without requiring the destruction of guaranteed proof. Distinguish “the player has heard this,” “a copy exists,” “a particular actor may read it,” and “publication was permitted.” A single global discovered boolean cannot safely express all four.

The game's guaranteed main-path proof should remain sufficient for every original ending. Optional accounts deepen attribution, emotional weight and available help. They must not create an unseen perfect-evidence score that blocks the finale or rewards exposing every family's history. [S2, S4, S8]

## 6. Proposed additions to adopt deliberately

**Personal particulars.** Evin, Pell, Leth, Jem and AVEL; Bram's thirty-seven left gloves; Mira's coast ambition; Kael's former chest-making work; Nera's freight-store dream; the dependent households' composition are novel details. Keep their timing consistent if adopted. Evin died last winter; Kael's escort was eight years ago; Edric's suppression was six years ago; the massacre was thirty-two years ago. Ages should not drift to make these events coincide.

**The betrayal and Refusal Book.** Rook's address-free schedule, Merrow's inspection authorization and the later interception create a present human thriller alongside the older mystery. Their causes must be seeded before the ambush, and Rook's admission must remain early. The Refusal Book is a mundane private duplicate in a two-lock strongbox beneath the disused north kitchen's chopping bench. Its retrieval is a new optional scene, not a recovered deleted quest. Adopt it only with alternate access/failure handling that leaves the main evidence path intact.

**Physical setpieces.** The Deep Wood bridge collapse, exact mill rescue, three bound camp guards, archive escape, storm-damaged ferry attachment, two rescue loads and bodily injuries need scene, navigation and animation work. They are not supplied by longer dialogue. The final ferry's guide and hauling lines are different systems; the former fails while the latter survives. Six people total traveling light is the established novel limit, including crew. Seven dependents therefore require two trips.

**Location and time.** The novel relocates the protected escort correction to the journey toward Hearthward and adapts the final handover to the refuge. Current anchors should be revised consciously, preserving route guidance and saves. The six-month spring epilogue is a new time layer. Do not put its healed or partly healed poses into immediate post-finale scenes.

**Creature ecology.** Bracken is a small four-footed plated Hearthscale with heat-seeking behavior. He is carried, handed to a named adult and kept out of the final rescue. Ambient species can enrich work, landscape and sound without turning every sighting into a boss, proof dispenser or mandatory combat reward. Named historical fragments remain bounded memories rather than resurrected companions. [S9]

## 7. Runtime, revision and production implications

### Preserve the revision boundary

`CampaignRevision` distinguishes original and expanded journeys. New games use the expanded graph; an unmarked legacy save retains the original. Save schema version 14, story schema version 2 and campaign revision 1/2 are separate contracts. A thirty-six-chapter prose expansion does not itself justify changing any of them. Decide whether a scene is compatible enrichment, an optional addition, or a newly required progression step before choosing migration behavior. [S1, S11]

Never inject unfinished required community objectives into a save that already passed their position. For an additional mandatory scene, define insertion rules, completed-journey behavior and absent-data defaults explicitly. Future or inconsistent revisions should continue to be rejected meaningfully rather than guessed into a workable-looking state.

### Give each fact an authoritative owner

Current runtime loads quest, dialogue and campaign data through established services; indexed dialogue scenes and the community overlay have separate compilation ownership. Add decisions through validated actions, with durable flags/evidence/objectives and then projected journal, dialogue and world consequences. Optional conversation topics are for observation and discussion; they are not a substitute for a state-changing action owner. [S8, S12]

Do not overload `rook_disclosure` with the proposed schedule betrayal, or `senn_fate` with custody location, or a commitment flag with whether Mira is available to work today. New injury and custody facts need explicit names and lifecycle definitions before implementation. This companion deliberately supplies no invented “already existing” IDs for them.

### Save unfinished work and irreversible losses

Open Road already distinguishes ward dismantling, human records, route crossing and completed relocation. Preserve `territorial_protection_active=false` and `hart_complete_account_access=false` once enacted, while retaining `human_records_preserved=true`. Do not set `final_choice_completed` simply when the player selects `depart`; the existing route requires delivered households and refuge arrival. A proposed interruption during the second rescue needs durable load/occupant progress and a safe resume point. [S7]

Before building more consequential work in these sectors, address the audited coordinate discrepancy: the save-field map disagrees with the world manifest for Assembly and omits Lantern Reach and Hearthward. The current safety fallback validates or relocates a computed position; it does not reconstruct the original local position. This is a static inconsistency, not an observed claim of save corruption. Test actual reload position alongside story state in all three sectors. [S11]

### Carry injury and relationship consequences into performance

Tor's left brace, Rook's ribs and Kael's calf injury are proposed durable consequences. Show limitations in labor allocation, poses, greetings and the recovery timeline. Do not make a permanent mandatory limp an unexamined penalty to traversal or accessibility. A scar, adapted animation and optional assistance can convey cost while retaining movement settings; any mechanical limitation needs a deliberate player-facing design.

Romance requires the current independent interest and commitment conditions, not successful healing, enough favors or a completed main quest. Existing `lr_commitment_partner` accepts Mira or Vale. The novel selects Mira, but later greetings must handle friendship, another partner and an ended commitment. Repeated declarations should acknowledge earlier conversations; anger and love can coexist without resetting relationship history. [S6]

### Keep text, voice and assets aligned

Revise source dialogue and scene ownership before regenerating indexed runtime payloads. Then update speaker identities, line hashes, captions and voice direction together. Preserve subtitle authority when audio is unavailable or unreviewed. A novel paragraph usually needs to become a brief interaction, physical action or optional conversation, rather than a long voiced monologue. Separate narrator knowledge from what the visible speaker knows.

Use the twelve canonical identities through current alias resolution. New minor voices require explicit casting decisions; old aliases must not create accidental additional people. The novel does not deliver meshes, rigs, ferry simulation or recorded performances. Stage the dramatic changes within the project's existing browser and weak-hardware budgets, with measured performance evidence before adding continuous crowds, physics ropes or persistent companion simulation. [S9, S12]

### Focus acceptance on the new risks

The next implementation should prove a small set of consequential journeys: missing-marker legacy load; expanded new game; optional Nera route skipped; Mira/Vale/no romance; Senn absent; a keeper refusal and later withdrawal; both kitchen and passage choices; all six endings; Open Road reload before and after dismantling, crossing and arrival; and the post-ending handover at its correct destination.

Current pinned-HEAD CI failed its architecture ratchet while the recorded deterministic suites passed 367 checks. Those results do not constitute a complete rendered campaign. Resolve the existing gate and add focused evidence for changed conditions, physical delivery, save recovery, subtitles and actor placement. Label seeded boundary tests as seeded; accompany the chosen literary route with a real-input playthrough. The aim is a game where the player's different choices remain possible and the consequences are visible in the room, the road and the people who continue living there. [S13]

## Sources

All repository links below are pinned to the reviewed commit. The novel’s numbered chapters are the sources for literary selections and proposed particulars.

- **S1 — Campaign graph and revision:** [campaign_revision.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/campaign_revision.gd); [quest_manager.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/quest_manager.gd).
- **S2 — Main/side definitions, evidence and choices:** [quests.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/quests.json); [story_campaign.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/story_campaign.json); [campaign_dialogue.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/campaign_dialogue.json).
- **S3 — Regional and escort sequences:** [saga_catalog.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/saga_catalog.gd).
- **S4 — Six ending IDs, revision and consent gates:** [ending_catalog.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/ending_catalog.gd).
- **S5 — Current epilogue projection:** [epilogue_resolver.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/epilogue_resolver.gd).
- **S6 — Story and relationship state:** [story_state.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/story_state.gd); [dialogue.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/dialogue.json).
- **S7 — Community work, offers and enacted departure:** [community_campaign.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/community_campaign.json); [community_ending.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/community_ending.gd).
- **S8 — Validated story choices and ending execution:** [dialogue_service.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/systems/dialogue_service.gd); [quest_service.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/systems/quest_service.gd).
- **S9 — Cast and ecology:** [design_pack_cast.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/design_pack_cast.json); [design_pack_ecology.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/design_pack_ecology.json).
- **S10 — Evidence disclosure:** [journal_evidence_details.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/data/journal_evidence_details.json).
- **S11 — Save serialization and coordinate owners:** [save_payload_codec.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/models/save_payload_codec.gd); [save_payload_fields.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/models/save_payload_fields.gd); [world_sector_manifest.json](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/world_sector_manifest.json).
- **S12 — Runtime source and overlay ownership:** [runtime_service_registry.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/scripts/runtime_service_registry.gd); [community_story_payload.py](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/tools/community_story_payload.py).
- **S13 — Recorded checks and available campaign harness:** [CI run 45849849528](https://github.com/RafaTahir/AshenOath/actions/runs/45849849528); [verify_full_campaign_input.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/tools/verify_full_campaign_input.gd); [verify_community_acceptance_seeds.gd](https://github.com/RafaTahir/AshenOath/blob/724821915f0b4a02677a862c7472a7fe5af3dcc7/outputs/AshenOathTheRoadBetweenCrowns/tools/verify_community_acceptance_seeds.gd).

