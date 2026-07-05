# Main Questline: The Road Between Crowns

## Quest Design Rules

- Required evidence may be discovered in any order.
- Each investigation has a threshold fallback: enough evidence advances the route while missed clues remain optional.
- Combat preparation changes staging or weakness, never blocks completion.
- Every quest ends with aftermath and reporting.
- Rewards include a relationship, route, preparation, or world change, never coins alone.

## 1. `main_road_of_crows` — Road of Crows

- **Hook:** Three people vanished; the returned cart contains objects that do not belong to them.
- **Location/NPCs:** Greyfen, old road, Anwen, Rook, Mira, Tor.
- **Investigation:** Identify carter Bram by axle marks, pilgrim Sella by shrine thread, and child Oren by a scratched token. Any three of five clues unlock the clearing.
- **Combat:** Five enemies arrive in two waves. Finding drag marks delays the Brute; making an Iron Trap creates a prepared choke point.
- **Dialogue:** Anwen asks for facts, then recognizes the token before denying it.
- **Choice:** Private report, public notice-board report, or retained token.
- **Consequence:** `evidence_report`; Anwen trust +/-1; public report raises fear by 1.
- **Fail-safe:** Tracks appear after the pack dies even if earlier clues were skipped. Report points remain available at Anwen and the board.
- **Reward:** Redroot Potion, Greyfen access state, cemetery bell trigger.
- **Assets/complexity:** Existing assets plus token and Vargan-wire props. Medium.
- **Ticket:** `QUEST-001`.

## 2. `main_bell_beneath_greyfen` — Bell Beneath Greyfen

- **Hook:** The cemetery bell rings though its rope has been cut.
- **Location/NPCs:** Cemetery, Crow Chapel, Anwen, Elna.
- **Investigation:** Three disturbed graves, chapel threshold, cut rope. Order independent.
- **Combat:** Ghoulkin emerge only after the evidence threshold; their spawn side reflects the first grave opened.
- **Dialogue:** Elna identifies one grave as Harl's and Anwen recognizes obsolete burial words.
- **Choice:** Cleanse, disturb, or leave the Crow Shrine.
- **Consequence:** `crow_shrine_state`; Hart debt -1/+2/0; chapel appearance and blessing state.
- **Fail-safe:** Bell mechanism becomes inspectable after any two graves; combat victory always yields the chapel seal.
- **Reward:** Shrine blessing or memory fragment; chapel records unlocked.
- **Assets/complexity:** Existing cemetery, chapel shell, bell motion. Medium.
- **Ticket:** `WORLD-002` + `NARR-003`.

## 3. `main_teeth_in_rain` — Teeth in the Rain

- **Hook:** The dead turn toward a name Mira speaks by accident.
- **Location/NPCs:** Shallow/deeper Wychwood, Mira, Anwen.
- **Investigation:** Compare monster residue, ritual stones, and erased names in chapel records.
- **Combat:** Crafting Moon Oil is optional but exposes the Bog Wretch's memory core after stagger.
- **Dialogue:** Mira admits she has tested names on plants grown in grave soil.
- **Choice:** Destroy the core, preserve it for study, or return it to the grave.
- **Consequence:** Mira trust; Hart debt; later clue quality.
- **Fail-safe:** If Moon Oil is not crafted, Ash Bombs or repeated stagger reveal the core.
- **Reward:** Permanent Moon Oil recipe discount and Wychwood passage.
- **Assets/complexity:** Existing Bog Wretch, stones, oils, forest. Medium.
- **Ticket:** `QUEST-002`.

## 4. `main_names_they_burned` — The Names They Burned

- **Hook:** The chapel register has been divided among families who deny owning it.
- **Location/NPCs:** Greyfen homes/exteriors, Rook, Tor, Toma, Elna.
- **Investigation:** Recover four fragments through trust, exchange, theft, or side-quest leverage.
- **Combat:** Optional Stalker attacks if a fragment is carried through Wychwood at night state.
- **Dialogue:** Each holder explains why their family kept or hid a fragment.
- **Choice:** Publish names now or preserve secrecy until the binding is weakened.
- **Consequence:** `names_policy`; fear +2 or Hart debt -1; vendor and villager reactions.
- **Fail-safe:** Three fragments plus Rook's oral list reconstruct required names; the fourth remains optional.
- **Reward:** Named-dead invocation that interrupts certain enemy windups.
- **Assets/complexity:** Existing village, four paper props. Medium.
- **Ticket:** `QUEST-003`.

## 5. `main_ash_at_the_mill` — Ash at the Mill

- **Hook:** Greyfen flour contains pale grit matching the massacre ground.
- **Location/NPCs:** Old mill, Mira, Tor.
- **Investigation:** Millstone residue, old fuel ledger, hidden bone-ash chute.
- **Combat:** Bog Wretch formed from runoff; hazards reuse mist and unstable-board interactions.
- **Dialogue:** Tor admits old Greyfen iron was recovered from the road; Mira explains why the fields never failed.
- **Choice:** Close the mill, cleanse its soil, or keep it operating under public warning.
- **Consequence:** Food supply, village fear, potion cost, final civilian support.
- **Fail-safe:** Ledger or chute independently proves provenance; missing evidence changes certainty, not progression.
- **Reward:** Ash Bomb capacity or village ration support.
- **Assets/complexity:** Modular mill props and existing effects. Medium-high.
- **Ticket:** `WORLD-003`.

## 6. `main_soldier_without_banner` — A Soldier Without a Banner

- **Hook:** Bandits possess Vargan drill orders and know a verse missing from the chapel register.
- **Location/NPCs:** Bandit road/camp, Rook, Captain Senn.
- **Investigation:** Patrol routes, old insignia, captive testimony.
- **Combat:** Trap the camp, challenge Senn, or enter after finding Rook's route. Senn can surrender below a health threshold.
- **Dialogue:** Senn admits his grandfather guarded the killing road and preserved names as penance.
- **Choice:** Spare for testimony, imprison in Greyfen, or execute.
- **Consequence:** Witness availability, bandit hostility, Edric leverage.
- **Fail-safe:** If Senn dies, his written deposition survives with less credibility.
- **Reward:** Vargan approach route and Iron Trap upgrade.
- **Assets/complexity:** Existing bandit and camp dressing. Medium.
- **Ticket:** `ENEMY-003`.

## 7. `main_blood_under_stone` — Blood Under Stone

- **Hook:** Edric's signet opens a record hall he claims never to have entered.
- **Location/NPCs:** Castle approach, outer court, Edric.
- **Investigation:** Command seals, altered ledger, execution inscription.
- **Combat:** Gravebound guards and environmental collapse; Rot Oil provides advantage.
- **Dialogue:** Edric moves from denial to the narrower truth: he concealed inherited proof.
- **Choice:** Cooperate, threaten exposure, or present public witnesses.
- **Consequence:** `edric_stance`; access and defense state.
- **Fail-safe:** Signet, Senn testimony, or Rook's route each permit entry.
- **Reward:** Record-hall access and Vargan armory preparation.
- **Assets/complexity:** Existing ruins plus modular record hall. High.
- **Ticket:** `WORLD-004`.

## 8. `main_last_witness` — The Last Witness

- **Hook:** Captain Ors Halvern repeats the names he died refusing to erase.
- **Location/NPCs:** Castle undercroft, Gravebound Knight, Anwen.
- **Investigation:** Execution order, broken sword, burial omission.
- **Combat:** The fight pauses at health thresholds when names are spoken. The player may continue, listen, or bind him.
- **Choice:** Free, question then release, bind, or destroy Halvern.
- **Consequence:** Testimony strength, Hart debt, final ally/encounter.
- **Fail-safe:** Defeating him still yields memory through the sword; listening avoids final phase.
- **Reward:** Rot Oil improvement and full command ledger.
- **Assets/complexity:** Existing knight and undercroft. Medium-high.
- **Ticket:** `ENEMY-004`.

## 9. `main_crowns_without_mercy` — Crowns Without Mercy

- **Hook:** Evidence is complete, but truth requires living mouths willing to speak it.
- **Location/NPCs:** Greyfen assembly, all surviving principals.
- **Investigation:** Resolve contradictions and select testimony order.
- **Combat:** No required fight; unrest may create a contained bandit/villager defense encounter if fear is high.
- **Dialogue:** Kael can protect witnesses, expose all guilt, or negotiate staged confession.
- **Choice:** Voluntary testimony, immediate exposure, or coerced confession.
- **Consequence:** Final witnesses, village stability, Edric/Anwen state.
- **Fail-safe:** Kael can testify from gathered documents if all NPC witnesses are unavailable.
- **Reward:** Final route opens with support based on prior choices.
- **Assets/complexity:** Existing Greyfen staging and dialogue variants. High narrative, low asset.
- **Ticket:** `NARR-006`.

## 10. `main_hart_remembers` — The Hart Remembers

- **Hook:** The old road reappears beneath Greyfen and every named witness hears it.
- **Location/NPCs:** White Hart Glade, Hart, available witnesses.
- **Investigation:** Place names/tokens along the road to stabilize memory.
- **Combat:** Optional Hart fight for Ash ending; consequence-dependent creatures guard missing testimony.
- **Dialogue:** Hart offers memory, Anwen confession, Edric order, Kael witness.
- **Choice:** Witness, Mercy, Duty, or Ash.
- **Consequence:** Ending and epilogues.
- **Fail-safe:** Each ending remains reachable; stronger evidence changes cost and epilogue, not basic access.
- **Reward:** Narrative resolution.
- **Assets/complexity:** Existing Hart, glade dressing, memorial road. High.
- **Ticket:** `FINALE-001`.
