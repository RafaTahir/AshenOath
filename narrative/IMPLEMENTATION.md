# Narrative implementation ledger

Recover from this document, DIRECTIVE.md and the unchanged originals in source/2026-11-27. Integration worktree D:/AOStory, branch codex/novel-campaign; D:/Projects/AshenOath-Novel-Work holds the authored staging files during checkout, base 7ed0867 (accepted runtime 7248219). The original local baseline is retained below.

## First-control release

Rafa authorized publication of the complete novel after a cold Web test. Work continues on `codex/novel-first-control` in D:/AOStory. Commit c7f5159 hands movement to Kael during the village arrival, retains its optional cinematic framing and clears the reproduced Old Mill shutdown leak. Commit 88708cb integrates verified Web pack-buffer ownership. The stock-engine cut reached control in 97.8 seconds and moved Kael 1.98 metres. Its renderer peaked at 1,012.8 MiB. The next candidate changes Web shader-program lifetime. Measurements and shutdown evidence are in [first-control/measurements.json](evidence/web/first-control/measurements.json).

## Local review build

The full literary campaign is integrated in the local review build **novel-review-7b909c3-3df0808**. Open http://127.0.0.1:8734/ on this PC. The durable package is in D:/AshenOathReview/novel-review-7b909c3-3df0808/web. Start Review.cmd alongside that directory reopens it after a restart. Choose New Game to enter Sellaâ€™s prologue. Existing journeys retain their original edition.

| Deliverable | Final evidence |
|---|---|
| Narrative coverage | Four acts, prologue, 36 chapters, epilogue and six covenant aftermaths. SCENES.md maps all 114 manuscript divisions. CONTINUITY.md traces the named cast. |
| Source identity | Runtime 7b909c3 and export layout 3df0808. The layout moved the Community rules script into the Web startup bundle. The packaging source was merged back into codex/novel-campaign. The staging manifest records a dirty export workspace and both source revisions. |
| Web archive | 59 files including the manifest, 181,870,900 bytes (173.45 MiB), below the 256 MiB ceiling. The 50 content packs include three deferred field sets. The review copy was compared file by file with the verified archive. Manifest SHA-256 c27645e994dd9e1f4804378d8daf4822de94bf8bf1f0ec82cf94e8b9fae01467. |
| Game content and saves | All novel fixtures, the six modeled ending projections and five existing simulation suites passed. Native input and save/Continue evidence is indexed at the end of this ledger. |
| Web startup | Six mounted-resource checks made 657 assertions. The cold Edge run reached the menu, advanced all four prologue scenes through ordinary input and reached Kael with zero recorded browser errors. The opening requested none of the three field sets or the rescue Stalker pack. |
| Performance and signoff | The cold loopback run took 79.8 s to the menu and 148.7 s to first control, including the prologue. Peak sampled renderer private memory was 981.1 MiB. These observations exceed the existing startup and memory targets. Sustained frame rate, phone performance and the artistic experience of a complete player-led journey remain open. |
| Release state | Local creator review. The public game was not updated during this assignment. |

Package identity, the mounted-resource report and the complete cold browser record are in evidence/web. The dedicated source directory and local Git milestones remain available for subsequent sessions.

## Implementation history

All nine source files remain in source/2026-11-27. SCENES.md follows the 114 manuscript scenes in order. CONTINUITY.md follows Kael, the twelve supporting characters and all six endings. The chapter register identifies integrated content. A rendered sample covers only the actions named in the dated evidence below. The working branch and local candidate are separate from the public release.

QuestManager owns the existing campaign graph. StoryState holds evidence, choices and consent. A new journey opts into the novel edition. Older classic and expanded journeys retain their graphs. The art and packaging workstreams maintain separate local checkouts.

## Chapter register

| Section | Pages | Existing anchor | Essential playable beats and continuity | State |
|---|---|---|---|---|
| Prologue Â· The Painted Crow | 4â€“8 | Literary frame | Play Sella at the gate; bind the red cord and wrap the crow in grey. Keep her knowledge private from Kael. | Integrated |
| Chapter 1 Â· A Hunter's Price | 9â€“15 | main_road_of_crows | Unload the gate cart; release Torâ€™s hub; Nessaâ€™s burnt boot story. Keep Anwenâ€™s contract in the existing reward ledger. | Integrated |
| Chapter 2 Â· The Broken Cart | 16â€“20 | main_road_of_crows | Follow separated tracks through the four hunts; lower the weapon for the boards. The two flat loops identify a method only. | Integrated |
| Chapter 3 Â· What We Brought Back | 21â€“26 | main_road_of_crows | Help Mira at the basin, return the brush to Anwen, show Tor the wire; let the player bound the report. | Integrated |
| Chapter 4 Â· A Widow's Bell | 27â€“32 | main_bell_beneath_greyfen, side_widows_bell | Use two doors for two bodies; Elna lends Harlâ€™s clapperless bell. Witness Lenâ€™s interrupted lantern; trace RECEIVED / AVEL. | Integrated |
| Chapter 5 Â· The Rope | 33â€“38 | main_bell_beneath_greyfen | Wedge the chain, draw the Bell-Eater away from Tor, lower Evin; separate Anwenâ€™s recent loss from the old killings. | Integrated |
| Chapter 6 Â· The One Who Returned | 39â€“44 | side_escort_01, side_bracken_rescue | Free Brackenâ€™s trapped foot, find his basket a carer; correct promised blankets against the actual load with Nera. | Integrated |
| Chapter 7 Â· Under Green Water | 45â€“50 | main_teeth_in_rain, side_black_dog, side_bitter_roots | Read Pellâ€™s six-armed guardian drawing; inspect the fence and test the ground. The guardian can be dangerous and also have saved him. | Integrated |
| Chapter 8 Â· The Name in the Reeds | 51â€“56 | main_teeth_in_rain, side_childs_charm | Set Miraâ€™s safety line, recover Orenâ€™s second shoe and bear the frame in turns. Check the three names before burial. | Integrated |
| Chapter 9 Â· No Footsteps Back | 57â€“62 | side_escort_02, main_names_they_burned | Load stones and test the crossing separately from the cargo. Let Nera own the memory of tied sleeves; sign a warning with its reason. | Integrated |
| Chapter 10 Â· The Names They Burned | 63â€“69 | main_names_they_burned | Lever the tally record from the broken chimney, keep Bracken clear; compare the old receipt and Anwenâ€™s later addition. | Integrated |
| Chapter 11 Â· The Widow's Version | 70â€“75 | side_widows_bell, side_rooks_map, main_names_they_burned | Elna closes the door on her own account; she can release one paragraph without releasing private letters. Redact bakery addresses. | Integrated |
| Chapter 12 Â· What We Carried | 76â€“81 | side_escort_03 | Work two lashings then choose the surviving load, medicine or tools. Log the material loss. Hear Neraâ€™s Jem account on her terms. | Integrated |
| Chapter 13 Â· Ash at the Mill | 82â€“87 | main_ash_at_the_mill, side_millers_measure | Vent the mill, count all seven out, save wage sheets before copying mill measures; Ashwingâ€™s defeat alone cannot do these jobs. | Integrated |
| Chapter 14 Â· Iron Remembers | 88â€“93 | main_ash_at_the_mill, side_iron_remembers | Tor breaks the left wrist saving the wheelkeeper; Mira fits cratewood and Nera takes the hammer. Handle marked iron restitution. | Integrated |
| Chapter 15 Â· Bread and Ash | 94â€“100 | main_ash_at_the_mill | Return Elnaâ€™s bell, retain only its rubbing. Share the burned loaf; optional closeness with Mira never overrides care for Pell. | Integrated |
| Chapter 16 Â· The Empty Tables | 101â€“106 | main_empty_tables | Build the receiving hearth, fix smoke and divide fuel. Rook sends the relief schedule for grain without sending names. | Integrated |
| Chapter 17 Â· A Place at the Table | 107â€“112 | main_empty_tables | Serve actual portions, let the accuser measure. Rook briefs the crew before interception; keep unsigned forms separate from headcounts. | Integrated |
| Chapter 18 Â· A Road Kept Open | 113â€“119 | main_road_kept_open | Test two ferry banks with cargo separately from passengers. Retain an actual first crossing before the repair. | Integrated |
| Chapter 19 Â· A Soldier Without a Banner | 120â€“126 | main_soldier_without_banner | Recognize three guards, offer Senn stand-down, preserve the combat alternative. | Integrated |
| Chapter 20 Â· The Officer's Hand | 127â€“134 | main_soldier_without_banner, side_soldiers_debt | Disarm, inventory restitution, distinguish voluntary testimony from guarded work; retain death/exile branches. | Integrated |
| Chapter 21 Â· Hold the Rear | 135â€“143 | side_escort_04 | Nera directs the convoy between front and rear; Rookâ€™s ribs and schedule restrictions persist, food remains available. | Integrated |
| Chapter 22 Â· The Man Who Keeps Keys | 144â€“151 | main_blood_under_stone, saga_var_q03 | Bring Tomaâ€™s petition for the three detained seasonal workers; place Pell with a named carer. | Integrated |
| Chapter 23 Â· Blood Under Stone | 152â€“158 | main_blood_under_stone, saga_var_q01 | Compare witnessed old command and Edricâ€™s six-years-later suppression. Preserve original seal and dated copies. | Integrated |
| Chapter 24 Â· The Price of Bread | 159â€“166 | main_blood_under_stone | Challenge grain signatures; admit the playerâ€™s agency in cooperation, exposure or compulsion. | Integrated |
| Chapter 25 Â· The Last Witness | 167â€“174 | main_last_witness | Halvernâ€™s evidence ends at the old sanctuary refusal and execution; he cannot speak to Kaelâ€™s later escort. | Integrated |
| Chapter 26 Â· The Word Retreat | 175â€“182 | side_escort_05 | Reconstruct Kaelâ€™s own words and failure to return; Nera owns her response. Protect private or public correction. | Integrated |
| Chapter 27 Â· The House That Was Empty | 183â€“190 | main_house_many_names | Survey Hearthward for first-night shelter; an outline on the ground cannot house anyone. | Integrated |
| Chapter 28 Â· The House of Many Names | 191â€“198 | main_house_many_names | Fit real beds, care and dry record storage, then receive the first arrivals. | Integrated |
| Chapter 29 Â· What Remains Private | 199â€“206 | main_house_many_names | Keep letters private, stage voluntary closeness/decline; Mira retains the coast as a life outside Kael. | Integrated |
| Chapter 30 Â· What We Promise | 207â€“213 | main_what_we_promise | Test meals, alarm and watch; explicit keeper consent and workable alternatives for each occupied role. | Integrated |
| Chapter 31 Â· The Refusal Book | 214â€“221 | main_crowns_without_mercy | Two independent locks in the disused kitchen protect optional duplicate refusal evidence; no critical path through them. | Integrated |
| Chapter 32 Â· Crowns Without Mercy | 222â€“228 | main_crowns_without_mercy, saga_var_q04 | Separate grain from signatures before recording volunteered testimony; retain the three methods. | Integrated |
| Chapter 33 Â· The Hart Remembers | 229â€“236 | main_hart_remembers | Hear the White Hartâ€™s complete witness or form a case from partial human evidence, and choose among all six methods. | Integrated |
| Chapter 34 Â· The Last Load | 237â€“243 | main_hart_remembers | Separate choosing departure from irreversible dismantling, crew consent and voluntary shelter. | Integrated |
| Chapter 35 Â· The Man Who Came Back | 244â€“251 | main_hart_remembers | Two ferry trips for seven dependents, six places including crew. Lose the guide line, save the hauling line; record injury and losses. | Integrated |
| Chapter 36 Â· The Relief Handover | 252â€“258 | side_escort_06 | Deliver residents to actual care and account for the boat; retain non-departure routes. Choose evening company freely. | Integrated |
| Epilogue Â· The Road Between Crowns | 259â€“265 | Literary frame | Project six months into spring, retain Torâ€™s wrist, Miraâ€™s coast, Neraâ€™s freight enterprise and Kaelâ€™s calf across appropriate routes. | Integrated |

## Production checkpoint

Acts Iâ€“III now have first-pass interaction data for chapters 1â€“27. The sector-owned scene director, use/dialogue callbacks, cancellable work and its new-journey edition marker have source implementations. The save conversion now uses the canonical world atlas and recognizes the legacy coordinates for three sectors. None of these have gameplay evidence yet. Pending: prologue, Act IV and six aftermaths, branching quest integration, character/material custody, performance wiring, source pass and integrated checks. Full checkout is slow on this disk; a sparse worktree keeps production and unrelated art changes safe.

## Integrated source and first gameplay evidence

- Local milestones 8e86d9d (all supplied originals), 08c5368 (world-coordinate repair), 8687817 (four heirloom/utility prop families), 977bc87 (new campaign edition, prologue, all four act files, expanded main objectives and six spring branches), f7b08aa / 5a61305 (deterministic pack ownership).
- The isolated rendered New Game used 38 normal input events. Sella reached the gate, Kael received no field evidence from her viewpoint, and walking/Use advanced both Greyfen hub jobs. The earlier run timed out before New Game became available. The successful cold source run logged 217,413 ms to the menu on this machine; the shutdown reported an ObjectDB leak. These are open technical observations. Individual inputs, duration and images are in evidence/opening.
- The first Godot model pass exercised 579 assertions, 56 scene sequences, 139 beats and 41 explicit options, including the six enacted-ending gates, older graph selection and save coordinates. Chapters with authored source remain awaiting integrated or representative play until separately evidenced.
- Remaining: finish authored social/physical consequences and knowledge gates, integrate Tor/Rook performance and Open Road evacuation, inspect late-game play and branch/save continuity, package safeguards, and perform the final source/production review. No release has been made. The production worktree is D:/AOStory; staging edits and the source sandbox are D:/Projects/AshenOath-Novel-Work and D:/AOPlay respectively.

## Castle, Hearthward and Open Road integration

- ca5c852 preserves the first actual-input opening evidence, workers' petition and physical aftermaths. The following Godot pass counted 622 checks, 64 sequences, 149 steps and 47 choices in 38 sections.
- 46211e0 integrates Tor's and Rook's ongoing injuries. c52419c adds the warrant counterpart, two-lock weekly count, drain, private correction and changed relief destination. The tracker and field dialogue now distinguish who accepted a role and what Kael actually learned. More scenes have been authored since the last numeric pass.
- 07e6671 adds the four prologue sets. The art workstream reports 41 isolated checks per viewport, including input and restore. e601b4a integrates the two physical ferry trips, empty return, seven dependents, guide line, injury, losses and refuge handover. Its two focused native tests passed in the originating checkout. OPEN_ROAD.md and CAST_PERFORMANCE.md contain the contracts.
- New independent boundary runs entered the Record Hall and Hearthward, earned the first physical action, saved, and continued. Both stopped on the walk to the second site. The Old Mill run exceeded its original arrival wait. These runs are diagnostic, not passed playthroughs. Hearthward exposed an obsolete transition-property access during the community loop. A corrective change is in progress.
- D:/AOStory is now sufficiently hydrated for independent local Godot tools with its own ordinary import cache. The editable branch is authoritative. Do not copy prior staging scripts over newer source in this worktree. The packaging chat owns a local Web review candidate; Game Assets owns three dramatic field performances. No live release or push.

## Manuscript and continuity milestone

- Integrated all four movements with the prologue and six spring aftermaths. The source catalog has 92 sequences, 203 action/dialogue beats and 65 offered choices. Some native scenes and existing quests cover several source intervals. SCENES.md records the compression and alternate routes individually.
- A new Godot replay drove all mandatory additions through the real quest graph and story receipt owner for six projected endings. It performed 18 JSON/codec restores and 954 assertions. Its existing-world and ending inputs are simulated receipts. The separate catalog and save suite passed 825 assertions across the 38 sections. Neither result constitutes a six-ending gameplay playthrough.
- Rendered native input completed Torâ€™s mill accident, including saving and reopening the scene after the first action, and the four-piece Hearthward shelter sequence after resuming the earlier checkpoint. Capture and report pairs are in evidence/tor_wrist and evidence/dry_floor. A subsequent Record Hall attempt reached the last receipt but stalled during its approach. The old epilogue fixture failed the released departure consistency checks and never offered Continue. A corrected, separately labelled boundary journey supplies the required evacuation facts. Real save validation remains strict.
- Open Road preserves Rookâ€™s Greyfen trade. Mira and Vale can each refuse or accept closeness. The old gate memory requires the Hart's hearing before the covenant. The story now distinguishes Kaelâ€™s escort from that witness and the use of ration, public and private records. The player can help bring the last bedding indoors after any spring visit.
- Remaining integration work includes the live field performances, the architecture ratchet, remaining rendered boundaries and source-aligned Web package. Native runs continue to report an ObjectDB warning on exit. Artistic acceptance remains open.

## Integrated native milestone, 28 November local time

72cab3f adds the scene-level register, high-road and ordinary spring work, Rook's retained home and the six-route story/save harness. Record Hall and Open Road spring subsequently passed in the real-input harness. The two additional reports and rendered views are in evidence/seals and evidence/spring_open_road. The calendar advanced once by 180 days. The architecture work separated the story/action and field presentation layers, kept the same APIs for community consent and ferry motion, removed a recursive visual-parent search and retained the existing navigation and collision behavior in the ruins.

The inherited full-suite rerun passed JSON/references, archive, Godot resource preparation and all five simulation suites, including both 600-tick budgets. Two module-size failures remained at that snapshot and are being rechecked after moving their stages. A new rendered boundary initially exposed a missing GDScript type on the optional Greyfen shrine interaction. The type was corrected and the complete game script compiled. The final Web candidate will use the integrated field performance code after the asset workstream returns its architecture changes.

## River and Hart integration

The integrated field performances and three demand-loaded scene families are on the local branch. A firsthand hearing with the living Hart now opens the old road while all six covenants remain undecided. The native route began with arrival and the confession history only, earned the invitation, performed the first memory, saved, resumed and asked about Kaelâ€™s eight-year escort. Its 120 input events and the final playable view are retained in evidence/hart_testimony. evidence/neras_account preserves a separate refusal at Hearthward. The public/private choices, manuscript equivalents and chapter order are in SCENES.md.

The first real return of the rescue ferry exposed a missing station refresh after the Stalker fell. It also exposed source-only neighbor pack requests for field scenes already present in the native editor project. The integration now distinguishes directly available native scenes from the manifest-owned packs in Web. The mill staging passed 49 normal input events with an interrupted save, but its retired activity view logged invalid zone references. That ownership repair is being checked separately. The previous packaging checkpoint is intermediate; the local review package must include the final river and spring performances.

## Completed scene work and the local review cut

The campaign runtime is at 7b909c3 on codex/novel-campaign. The final four-act catalog contains 95 sequences, 206 beats and 65 choices, in addition to Sellaâ€™s playable prologue, the original campaign and the physical Open Road crossing. The new-edition quest graph uses the same fourteen main chapters. The six-route rehearsal performed 1,068 assertions and 18 save-codec restores. The catalog/save fixture performed 837 assertions across 38 literary sections. The prior public edition and its save projections are retained.

| Playable milestone | Evidence and boundaries |
|---|---|
| Sella and the first Greyfen job | New Game through the prologue and the cart hub with ordinary controls. See evidence/opening. |
| Torâ€™s left wrist at the mill | A boundary save enters Old Mill. A 49-event rendered run performs the work, saves, reopens the mill and finishes the accident. The final run emitted zero script or engine errors. See evidence/mill_field. |
| Record Hall and the dry refuge | Sealed records and the four shelter tasks were completed from separate chapter saves. See evidence/seals and evidence/dry_floor. |
| Neraâ€™s correction | A rendered Hearthward run chooses refusal after restoring the partly completed scene. See evidence/neras_account. |
| Testimony before the covenant | A 120-event run walks to the living Hart, chooses its invitation and asks about the escort after saving during the walk. The final covenant is still open. See evidence/hart_testimony. |
| Refugees at the ferry | A 95-event run begins before boarding. Beraâ€™s four cross, Continue restores the east bank, the ferry returns empty, Kael diverts the live Stalker and Sivâ€™s three cross. The driver counts seven, verifies the empty bow slot and retrieves the ferrymanâ€™s spare. See evidence/river. The sceneâ€™s incidental market greeting was subsequently revised. |
| Six months later | A rendered Open Road spring advances the calendar by 180 days and finishes the chair work. In focused cast checks Tor steadies the joint and Rook walks normally with a brief rib gesture on laughter. See evidence/spring_open_road and evidence/spring_cast. |

The river, mill and Hart captures came from ordinary player input in isolated profiles. The handoff seed supplies earned history up to each chapter boundary. Prior diagnostic attempts and timing differences remain in their original folders. The native process still logs an ObjectDB shutdown warning. The full six ending projections cover quest and save consistency; representative rendered scenes cover a smaller span. The manuscriptâ€™s private interiority, several travel days and some secondary conversations share playable scenes as detailed in SCENES.md. Final artistic acceptance belongs to the creator.

All twelve unified checks passed on 7b909c3. They include the architecture ratchet on 394 files, static script/scene references, archive checks, imports and five game simulation suites. evidence/integration/unified-checks.json records the individual results. Evidence for the 95-event complete evacuation and the corrected mill restore is retained under evidence/river and evidence/mill_field. The cast workstreamâ€™s original pose fixtures and new spring evidence are under evidence/performances and evidence/spring_cast. The intermediate browser export exposed an early dependency on the community rules script. The packaging workstream is correcting startup ownership before handover.

On the final dialogue cut a normal Continue from the earned empty-return checkpoint repeated the west-bank encounter, the seven-person landing and the replacement bow in 52 input events. The corrected capture and report sit beside the earlier complete crossing. Tomaâ€™s unrelated market greeting is absent in the corrected capture.
