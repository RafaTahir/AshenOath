# Ashen Oath Story Centered Overhaul Master Plan

**Date:** 3 October 2026  
**Status:** Proposed creative direction and delivery roadmap for review  
**Project:** Ashen Oath: The Road Between Crowns  
**Repository:** `D:\Projects\AshenOath`  
**Game root:** `outputs/AshenOathTheRoadBetweenCrowns/`

## 1 Recommendation

Rebuild Ashen Oath around a complete, emotionally compelling regional campaign. Preserve Kael, Greyfen, Anwen, the White Hart, the concealed massacre, and the idea that denied memory becomes monstrous. Allow substantial revisions to how the plot unfolds, how relationships develop, and how the player experiences consequences.

The strongest version is a third-person dark fantasy action RPG in which investigating a monster changes how you confront it, deciding what to do with the truth changes a community, and returning to that community makes your responsibility tangible.

The creative question is: **What do you owe the living when their safety depends on a lie told about the dead?** Kael's personal question is: **Will you stay when obeying an order would let you leave?**

Build for approximately **6–8 hours on the main path and 8–12 hours with substantial optional content**. These are proposed playtime targets to validate with players. Keep the existing browser-first Godot foundation. Concentrate craftsmanship in a small connected region, recognizable people, five distinctive set-piece encounters, and four developed endings.

The first production goal is a compelling 45–60 minute opening that proves the complete experience: human connection, discovery, preparation, combat or resolution, a consequential report, and a visibly changed return. Expand only after it succeeds with unfamiliar players.

## 2 Scope and assumptions

The user requested a comprehensive overhaul plan with the storyline governing every aspect of the game and explicitly chose to keep the core identity while allowing a major rewrite. That direction governs this proposal.

Other planning assumptions are single-player play, Godot 4.6 project compatibility, browser delivery through the current repository and Vercel setup, keyboard/mouse and controller support, and a small production team. No staffing level, budget, release date, commercial model, or new platform commitment has been supplied.

This is a source and documentation review. Narrative documents, quest and dialogue data, selected runtime code, and current release records informed it. A fresh complete playthrough, audiovisual review, controller session, or performance measurement was not conducted. Source-level concerns below require reproduction during implementation.

The proposal does not certify the current game, replace existing canon automatically, or authorize implementation. It is the planning deliverable; the game and deployment were not changed.

## 3 Why this approach

| Approach | Benefit | Cost and limitation | Recommendation |
| --- | --- | --- | --- |
| Polish the existing plot and systems | Fastest route to incremental improvement | Preserves structural repetition and inconsistencies between intended and actual consequences | Useful for urgent fixes, insufficient as the whole overhaul |
| Substantial story rewrite with selective system rebuilding | Preserves valuable work while giving everything one dramatic purpose | Requires narrative decisions before content production and careful save migration | **Recommended** |
| New world, new engine, and broad feature expansion | Maximum freedom | Repeats solved work, expands asset demand, and delays proof that the central experience is enjoyable | Reserve for a demonstrated technical impossibility |

The existing story bible already contains the game's most valuable differentiator. More lore, more map area, or more combat abilities cannot substitute for making that premise work in a player's hands.

## 4 What the evidence establishes

The current `PROJECT_STATE.md` opening records release V10 as deployed and 37 recovery items accepted under a limited functional profile. It also explicitly leaves numerical performance targets uncertified, audio mix listening unreviewed, physical controllers untested, and exhaustive browser campaign and ending coverage unpassed. These are recorded limitations, not newly measured failures.

The implementation already contains ten main quests, ten optional quest entries, five boss definitions, branching dialogue, explicit story flags, three bounded narrative values, inventory, crafting, a bow and ammunition, vendors, streaming services, and versioned saves. Reuse these foundations where they meet the revised design.

There are material inconsistencies to resolve before expansion:

| Observed source evidence | Why it matters | Required planning response |
| --- | --- | --- |
| The mill design concerns closing, cleansing, or operating a food supply; current quest and ending text emphasize burning, preserving, or exposing records | The dramatic dilemma can turn into a document-handling menu | Separate evidence disposition from the operational decision; implement the food consequence |
| The bible says dead people do not return as complete personalities, while some dead characters converse with considerable continuity | The supernatural rules lose authority | Specify limited memory fragments, with Halvern retaining a bounded oath-memory |
| Mercy's design allows selective privacy, while the current epilogue says every hidden name returns | The ending can contradict its promise | Define privacy precisely and derive ending scenes and text from the same outcome |
| Many optional quests have only two objective entries despite ambitious written scenarios | Quest declarations do not establish depth or visible consequences | Author six substantial optional stories and use the others as shorter interludes |
| A static trace of Bitter Roots suggests inspecting a clue can complete the moral-choice objective before its outcome is recorded | A player's inspection can be mistaken for consent | Separate evidence discovery, choice selection, and resolution; reproduce this case first |
| `game.gd` remains roughly 7,560 lines despite existing coordinator services | Narrative changes can disturb unrelated systems | Extract only the responsibilities needed for reliable story execution |
| Current state and older certification/context documents contain conflicting progress summaries | Planning from an old completion claim can misdirect work | Establish one dated status ledger with evidence scope attached |

The clearest design risk is that characters explain a strong story while the player performs comparatively generic actions. The overhaul must make the story change the actions themselves.

## 5 Creative principles

1. **Make Greyfen worth saving.** Establish work, affection, humor, food, and ordinary generosity before revealing the cost of its survival.
2. **Give history an active opponent.** Somebody alive must be making a consequential decision now; the campaign cannot rely entirely on discovering old records.
3. **Let attention change action.** Evidence changes routes, targets, preparation, negotiation, or a monster's behavior.
4. **Make consequence perceptible.** A decision produces an immediate reaction, a visible or playable return, and a later payoff.
5. **Keep people larger than their secrets.** Anwen is also a carer; Rook has pleasures and obligations; Mira treats patients; Tor makes useful things.
6. **Preserve difficult judgment.** Facts can become clear while the right action remains disputed.
7. **Make every ending playable and intelligible.** The player explicitly chooses an intention after understanding its known cost.
8. **Let technical quality protect emotional continuity.** A broken save, contradictory objective, stuttering confrontation, or missing witness damages the story directly.

Each proposed feature must answer three questions: Which dramatic beat does it serve? What does the player do differently? What existing work will it replace or justify? Features without convincing answers leave the initial scope.

## 6 Canon to retain and rules to clarify

Retain the War of Three Crowns, the promise of sanctuary, Greyfen closing its gate, shrine keepers hiding the road, Vargan soldiers carrying out the massacre, and the reuse of the victims' ash and iron. Responsibility belongs to distinct human decisions across institutions; it is not reduced to one secretly evil mastermind.

Retain the White Hart as the only complete supernatural witness. It cannot lie, but its memory does not automatically provide proportion, consent, or mercy. Ghoulkin carry fragments of denied memory in scavenged bodies. Kael's earlier abandonment of civilians informs his choices without making him the hidden cause of every event in Greyfen.

Clarify these rules before any final dialogue or cinematic work:

- A name helps stabilize a particular memory; saying a name is not a universal spell that solves every encounter.
- Oaths require freely given witness. Threatened signatures and coerced confessions cannot become legitimate magical consent.
- Documents can establish facts. They cannot consent on behalf of living people.
- Destroying a memory vessel disperses its influence. Ordinary defensive combat does not secretly corrupt the player or punish an undisclosed rule.
- The player is warned before a special irreversible act destroys irreplaceable testimony.
- Halvern retains memories around his refusal and execution. He cannot answer arbitrary questions as an omniscient resurrected person.
- The returned soldier is either a limited memory vessel under the same rules or a clearly established living survivor. Choose one in the revised bible; recommended: the memory vessel, preserving the existing premise.

Create a reveal ledger showing what actually happened, who knows each fact, what evidence supports it, when the player can learn it, and which action that knowledge enables. A mystery should be understandable when assembled, including its chronology and the ages of living characters.

## 7 Revised dramatic premise

**Proposed addition:** the road's failure now threatens the living. Supplies are interrupted, people are disappearing, and testimony is becoming dangerous to those who carry it. Edric prepares a renewal of the covenant as an emergency measure. Ration access, protection, and social pressure make its apparent agreement coercive, reproducing the original mistake and creating an unstable binding.

**Proposed cause of the present crisis:** recent road repairs expose a cache of name tokens. Bram, Sella and Oren bring recovered objects toward the shrine; restoring one of the names strains the concealment that kept its memory disordered. Ghoulkin gather around the recovered testimony, an attempted containment fails, and someone living removes evidence afterward. Edric's response is to close the road and reclaim the tokens for his renewal. This chain is discoverable through the damaged road, the cart, Oren's token, shrine records and current orders. The midpoint confirms the relationship among those clues rather than introducing an unrelated cause.

Edric believes public truth will fragment the community before winter. His fear has practical substance, but it does not excuse choosing concealment again. Show him protecting people as well as controlling evidence. Let the player meet or hear from him early, understand his proposal before rejecting it, and confront his actions repeatedly.

Kael begins with a limited contract concerning the missing travelers. By the opening's end, he promises to stay, safeguard testimony, and help witnesses face foreseeable danger. This is a concrete responsibility rather than a guarantee that nobody can be harmed. Staying is the defined protagonist's commitment; the player shapes his terms, motive and methods, and the story acknowledges failures. Rook becomes a living personal stake: someone whose family history matters, whose trust is earned through shared action, and who can reject Kael's methods.

The emotional progression is belonging, suspicion, responsibility, complicity, confrontation, and an earned decision. The campaign's repeated physical image is a road that can be closed to protect insiders or reopened at a cost. Greyfen's gate, Vargan's gate, and the final road should echo one another through play.

Advance the threatened renewal at explicit chapter milestones. Do not use an undisclosed real-time countdown that punishes exploration, accessibility settings, or taking a break.

## 8 Campaign treatment

Keep the ten recognizable quest titles and stable identifiers where migration permits. Change their internal scenes and objectives as required.

| Chapter | Dramatic development | Principal player action | Consequence and next question |
| --- | --- | --- | --- |
| Road of Crows | Greyfen needs help; the missing travelers were targeted through personal objects | Help a living person, investigate the cart, prepare for the clearing, recover testimony | Choose who receives the evidence; a named person reacts immediately; why are shrine thread and Vargan wire together? |
| Bell Beneath Greyfen | The shrine helped erase people rather than simply bury them | Compare grave testimony, confront Anwen, use bell and name evidence during the encounter | Anwen sacrifices trust, authority, or protection; what did hiding the road accomplish? |
| Teeth in the Rain | Restored memory can endanger the living as well as release the dead | Apply one understood supernatural rule; choose how to handle a dangerous memory vessel | The decision changes a later encounter or treatment; why is the binding failing now? |
| The Names They Burned | The victims become individual people; Rook's history becomes a present vulnerability | Reconstruct testimony through homes and relationships, then decide how and when it is shared | Public and protected disclosure each affect named people; the player learns of Edric's renewal |
| Ash at the Mill | Greyfen's food, medicine, and prosperity are materially implicated | Stabilize the mill, protect workers or evidence, confront an immediate supply problem | Close, continue under controls, or begin repair and restitution, with concrete food and labor costs |
| A Soldier Without a Banner | Someone uses historical injury to justify present violence | Investigate Senn's actions, negotiate, disarm, or fight, and arrange actual custody or protection | Testimony may be obtained without absolution; Kael must address what obeying orders has meant in his own life |
| Blood Under Stone | Edric knew and suppressed proof; he offers a plan that is dangerous because it is plausible | Reach Vargan through one of several earned approaches, compare ledgers, confront living authority | Cooperation, exposure, and compulsion change guards, resources, and voluntary participation |
| The Last Witness | Halvern proves that refusal was possible; obedience did not remove responsibility | Duel or withstand a bounded memory, establish its limits, choose what to preserve | Kael discloses his own failure before asking others to confess; the player gains unavoidable main-path proof |
| Crowns Without Mercy | Edric attempts the renewal at the assembly, exposing who receives protection and who is excluded | Prepare aid, protect speakers, present evidence and stop or transform the unstable coercive rite | Earlier cooperation lets Edric halt it; exposure or compulsion requires another intervention. The living are protected through practical action and freely offered help |
| The Hart Remembers | The Hart can reveal everything but cannot decide what the living owe | Walk the transformed original road, hear testimony, choose and enact the final covenant | Play the chosen resolution and a short return to Greyfen before individualized epilogues |

Use three broad acts plus the finale. Act I establishes the people and rules. Act II turns discovery into practical responsibility. Act III confronts living authority and Kael's own conduct. The assembly and Hart sequence pay off choices already rehearsed during the campaign.

Alternate investigation, travel with character interaction, contained combat, practical aid, argument, quiet aftermath, and public consequence. No two adjacent major quests should share the same dominant sequence of collecting several clues, fighting a wave, and selecting a report option.

Main-path pacing targets: opening 30–45 minutes; shrine and wood 60–90; village, mill and Senn 90–120; Vargan and Halvern 75–105; assembly and finale 75–105. These ranges overlap a roughly 6–8 hour experience and must be revised from actual playtime, not padded with walking.

## 9 The opening as the quality benchmark

The opening must earn curiosity before demanding an investment in lore.

| Approximate time | Proposed experience | What it proves |
| --- | --- | --- |
| 0–3 minutes | Play immediately on Greyfen's threshold: help recover a stalled cart or escort a shaken traveler through a short disturbance | Movement, interaction, vulnerability, and a town receiving someone |
| 3–8 minutes | See the person helped receive care; meet Rook and Anwen in useful activity | Greyfen has warmth; Kael has a concrete reason to care |
| 8–15 minutes | Inspect the road and identify people through belongings and contradictory testimony | Investigation asks for understanding; one clue visibly offers a tactical advantage |
| 15–25 minutes | Use a small preparation choice and confront a readable Ghoulkin encounter | Combat has weight, the camera works, and evidence matters |
| 25–35 minutes | Discover a living person's interference and decide who receives the testimony | The first substantial decision has a comprehensible trade-off |
| 35–45 minutes | Return to an altered conversation and place; the bell responds; Kael makes his pledge | The game remembers and the next objective has emotional urgency |
| 45–60 minutes | Begin the cemetery investigation and witness Anwen's first costly admission | The second quest deepens the question instead of repeating the tutorial |

Keep the existing missing-traveler mystery unless the creative review changes their fates. The person helped in the proposed opening can be a living villager; no existing victim needs to be resurrected for this scene.

Teach one mechanic at a time. Dialogue can be advanced and reviewed. Controls remain predictable during conversation and inspection. Avoid mandatory walks back to collect an item an NPC could reasonably have brought. Give returning players a concise account of whom they promised to help and why their next action matters.

Opening acceptance includes five unfamiliar players: at least four can explain their immediate goal, name someone they care about, describe why one decision was difficult, and notice its consequence without prompting. This is a small directional playtest, not statistical proof. Repeat after substantive revisions.

## 10 Character overhaul

| Character | Want and contradiction | Required playable development | Presentation priority |
| --- | --- | --- | --- |
| Kael | Wants to complete a bounded job; fears the responsibility of staying | Freely accepts a promise, admits his retreat failure before the climax, and acts consistently or acknowledges inconsistency | Distinct face and silhouette, credible equipment, restrained voice, expressive pauses |
| Anwen | Wants to protect the village and those harmed by its rites; controls truth to avoid losing both | Performs care early, lies concretely, is challenged, risks something in disclosure, and may refuse coercion | Work and ritual gestures, self-correcting dialogue, readable eye contact |
| Rook | Wants safety and ownership of his family's story; jokes to avoid exposure | Helps the player in action, chooses what to share, becomes endangered, and can withhold voluntary support | A memorable entrance, shared quiet scene, humor that changes under pressure |
| Edric | Wants continuity and order; believes himself entitled to decide what others may know | Appears before his final confrontation, makes his renewal case, protects someone, suppresses evidence, faces a concrete surrender of power | Composure that fails into plain speech; distinct posture and environment |
| Mira | Wants to keep patients alive; her useful treatment is implicated in harm | Treats a named patient, explains scarcity, faces consent and supply decisions, adapts her practice | Clinical language, skilled hands, visible patients and supplies |
| Tor | Wants to keep making useful things; inherited material carries responsibility | Shows generosity, recognizes his iron, chooses a restitution process, makes something the player later sees used | Convincing forging actions, sockets and props, changes to his working space |
| Elna | Wants to preserve love without being forced into a public performance of grief | Offers memories independent of guilt, confronts evidence, chooses her own participation | Restraint, domestic detail, privacy that the player can respect |
| Toma | Wants family and livelihood safe; his private arrangement may endanger others | Demonstrates why he protects the creature and helps implement a chosen remedy | Domestic work and concern, not merely quest delivery |
| Senn | Wants acknowledgment; uses injury to rationalize current harm | Faces specific accusations, can surrender under believable terms, and cannot trade testimony for automatic forgiveness | Readable surrender and hostility states, consequences for his followers |
| Halvern | A bounded memory of refusal, fear, and execution | Reveals facts through a duel or ritual sequence; cannot solve the whole mystery through exposition | Broken repetitions, fragmentary recall, distinctive stance and armor |
| White Hart | Must bear complete memory; lacks a human sense of proportion | Foreshadowed through effects before arrival; poses a real danger even while truthful | Unmistakable silhouette, deliberate motion, limited elevated language |

Every principal living character receives an ordinary scene, a disagreement, an unprompted act, and a payoff. A character arc cannot consist entirely of the player selecting questions from a menu.

Use short dialogue turns and distinct vocabularies. Reserve poetic language for rare earned moments. Give each information-heavy scene an action, a contested goal, and a physical focus. Write interruption, refusal, departure, return, and repeated interaction responses alongside the preferred route.

## 11 Optional stories and daily life

Develop six substantial optional stories: **A Widow's Bell, Iron Remembers, Bitter Roots, The Black Dog Contract, The Road That Bends, and The Bannerless**. Use **The Man Who Walked Home, Oren's Red Thread, A Measure of Ash, and Three Candles Unlit** as shorter authored interludes connected to the main route. Preserve identifiers where possible and revise the old contracts to match the final design.

Each substantial story needs a personal introduction, evidence the player can interpret, at least two meaningful methods, a decision, an enacted consequence, and a later echo. Each interlude needs one memorable action and payoff; it does not need a miniature branching campaign.

Example: in **Iron Remembers**, the player recognizes Tor's iron in three useful village objects. Removing every object immediately harms people. Tor can begin gradual replacement and memorial work, preserve tools while publicly acknowledging their origin, or relinquish control of the stock. The result changes the forge, a household, Tor's work, and his contribution to the assembly. Different outcomes need viable preparation alternatives; the compassionate path must not become a disguised punishment through permanent loss of essential ammunition.

Example: **Bitter Roots** starts with a patient. The player learns why Mira uses the soil and what a replacement treatment would cost. The decision concerns disclosure, consent, and a practical treatment plan. Inspecting the garden must never choose the outcome. Implement the treatment or its shortage in a later encounter with that patient.

Include warmth without converting the village into a management simulator: sharing a meal, helping repair a latch, a small game with Rook, a joke that returns differently later, and work completing between visits. Reuse existing ambient systems where reliable. A minigame remains only if it reveals a person or gives the campaign necessary breathing space.

Optional quests change perspective, routes, support, and outcomes. Main-story comprehension and basic completion remain possible when they are skipped.

## 12 Choices and endings

For each major decision, author an explicit outcome record: what the player selected, what facts were known, which people consented, which resources or objects changed, what happens immediately, what changes on return, and how the ending can refer to it.

The three existing narrative values can influence tone and pressure. Explicit facts determine outcomes. Do not convert Witness, Mercy, Duty, and Ash into four XP bars or moral alignment meters.

Distinguish voluntary, protected voluntary, compelled, refused, and unavailable testimony. Protection can make free consent possible; a threat invalidates it. Records from an absent character can establish a fact but cannot silently count as that person's consent. Give the player an understandable explanation of why this matters before the finale.

Keep all four final intentions reachable through the main path. The revised canon must explicitly establish that the main-path evidence plus Kael's freely accepted responsibility provide the minimum means to attempt each resolution. Optional freely consenting witnesses distribute burden and improve specific outcomes. A low-support resolution remains viable but visibly costly; it does not secretly substitute another ending.

The proposed mechanism is precise: recovered records establish facts, and Kael can voluntarily accept responsibility for his own future actions. He cannot bind Greyfen's residents without their consent. The Hart accepts Witness when its account is acknowledged publicly and somebody freely undertakes to preserve it; with few allies, Kael must remain to do that work. It accepts Mercy when the binding is released and the recovered record is safeguarded through consented rites, without forcing every private memory into public circulation. Duty redirects the ongoing burden onto a willing keeper, with its limitations explained beforehand. Ash destroys the witness by force and requires no consensual new covenant. Foreshadow these possibilities through the shrine and Halvern sequences before offering the final decision.

| Ending | What the player commits to | Playable resolution | Benefit and cost |
| --- | --- | --- | --- |
| Witness | Make the record public and replace concealment with acknowledged responsibility | Protect or present testimony, establish names, and carry out a public release | The dead gain public recognition; restitution, lost privilege, division, and material repair fall on the living |
| Mercy | Release the bound witness while protecting the privacy of people who decline public exposure | Return names through consented rites and dismantle the binding without broadcasting every personal memory | Ends the Hart's captivity and protects vulnerable families; public accountability is partial and the human burden of preserving truth remains |
| Duty | Freely assume stewardship of the unresolved binding | A defensive ritual of containment and chosen responsibility, with support earned earlier | Immediate stability is preserved; Kael accepts an ongoing personal cost and unresolved injustice remains visible |
| Ash | Destroy the Hart and end its supernatural claim | A fully developed combat resolution followed by an irreversible aftermath | Immediate supernatural pressure ends; irreplaceable memory is lost and ecological and political consequences remain |

Mercy does not erase the historical record or cure every social wound. Duty must feel voluntary and distinguish defending a ritual from choosing destruction. Witness must carry real repair costs rather than becoming an obviously superior reward package. Ash needs credible relief as well as a cost; people who wanted survival should be able to argue for it without becoming caricatures.

Mercy's privacy applies to intimate victim memories, vulnerable witnesses and family identities. Institutional wrongdoing and proven perpetrators remain on the record. Edric cannot buy concealment with someone else's consent. Ash destroys the complete supernatural account, not human records already recovered; the player may still pursue restitution afterward. The difference among endings concerns how memory and responsibility continue, not whether the menu automatically makes Kael honest or dishonest.

Before commitment, summarize known stakes in character and allow one final question or withdrawal. Use a clearly identified pre-finale save. After resolution, allow a 5–10 minute authored return or aftermath sequence appropriate to that ending, followed by individualized epilogues written as lives continuing rather than raw flag values.

## 13 Investigation and evidence

Give the player three reliable activities: observe a material detail, compare an account, and test an interpretation through action. Use existing clue and dialogue systems with targeted extensions.

The journal separates **observed facts**, **someone's testimony**, and **Kael's inference**. It records provenance and contradictions in plain language. The player can review why a lead matters. Avoid a sprawling detective-board interface unless testing demonstrates a need.

Every main quest has redundant ways to obtain indispensable information. Optional evidence changes an approach, a cost, or confidence; it never silently blocks the campaign. An unsupported interpretation may cause a local setback and remain correctable. Major irreversible accusations must be presented as decisions with known uncertainty.

Examples of evidence changing action: the bell's rhythm reveals a safe interval; a true name interrupts a specific repeated memory; a ledger establishes authority to enter a service passage; knowledge of Senn's abandoned followers makes surrender negotiable; recognizing a mill channel allows workers to escape before the confrontation.

Retire visible clue quotas where they flatten investigation. Internally retain robust progression requirements, but express the objective as the question being answered. The player should not be told the conclusion before examining the evidence.

## 14 Combat and encounter design

Keep a focused kit: sword, guard and parry, dodge, bow, limited preparation tools, and Oathfire. First make movement, camera, targeting, attack commitment, hit feedback, and interruption coherent. Each addition must support a named encounter or character fantasy.

Use a consistent sequence of anticipation, threat, contact, recovery, and response. Telegraphs must remain readable against foliage, rain, darkness, particles, and low graphics settings. Verify contact with moving blades and projectiles, including low-frame-rate operation. Hit reactions, sound, and camera response must agree with actual damage.

Investigation should change an enemy behavior or available route before it merely grants bonus damage. Human enemies need clear surrender rules. A surrendering actor is protected from accidental follow-up attacks during dialogue transitions. Death and checkpoints preserve discoveries made before the encounter while restoring its unresolved combat state coherently.

Oathfire can briefly expose or interrupt a memory binding, linking its existing combat identity to the world. Prototype this extension inside the opening before expanding it. Ordinary use has a clear resource cost; only a deliberately signposted special action can destroy testimony. Avoid hidden narrative penalties for using the game's advertised combat kit.

Build difficulty settings around timing, incoming damage, targeting assistance, and encounter pressure. Preserve the complete narrative on accessible settings. Allow a story-focused combat profile without disguising missing content as difficulty selection.

## 15 Monsters and bosses

Every family needs a material source, a fragment of behavior it repeats, a silhouette, a sound identity, a combat function, a counterplay opportunity, and an aftermath. Retain the existing Ghoulkin, Bog Wretch, Gravebound, bandit, and Hart foundations. Consolidate overlapping ordinary enemy roles where necessary; add variants only when the player responds differently.

| Encounter | Story function | Distinct mechanic to prototype | Aftermath |
| --- | --- | --- | --- |
| Ghoulkin clearing | Establish that monsters gather identity-bearing objects | Interrupt collection, read a patrol or wave cue, use a prepared choke point | Objects remain inspectable; the living interference is discoverable |
| Bell-Eater | Embody public mourning converted into enforced silence | Bell shockwaves with rhythmic shelter; targeted restraint or name interaction changes a phase | The soundscape and cemetery usage change |
| Rootbound Colossus | Show life sustained by an exploited covenant | Redirect roots and protect a source of testimony; expose a heart through environment rather than only damage | A route and living landscape change |
| Ashwing | Make destruction of records and livelihood immediately physical | Ground a perch, read a swoop, protect workers or an escape route | Mill damage reflects what the player actually saved |
| Halvern | Turn refusal and obedience into action | A readable duel or defensive sequence interrupted by bounded memory; earned peaceful resolution | Testimony and the knight's remaining presence agree with the decision |
| White Hart | Resolve the central conflict | Distinct final procedures for testimony, release, stewardship, and destruction | Ending-specific road, sky, community, and character states |

The target is five major set pieces using the existing named bosses, with the opening clearing as the combat teaching encounter. If a boss cannot express a distinct narrative and mechanical purpose in prototype, merge or simplify it before commissioning final assets. A title, three health thresholds, and reused attacks do not establish a finished boss.

## 16 World and exploration

Use Greyfen as the recurring emotional hub. Organize the existing locations into a comprehensible region: Greyfen and cemetery; Wychwood and deep wood; mill, farmstead and marsh; bandit road; Vargan and undercroft; the Hart road and glade. These are geographical groupings, not a requirement to merge existing technical sectors.

Give each area a clear entrance, a distant landmark, a principal question, a route choice, a confrontation space, and a return route that changes meaning after discovery. Preserve continuous exterior travel where its cost is justified. A short authored transition is preferable to an unstable seam; review the actual route before changing the existing continuity commitment.

Every mandatory return should offer a changed person, changed place, new route, or purposeful conversation. Introduce discovered shortcuts and restrained late-game fast travel. Do not stretch the campaign by making the player repeat empty travel.

Author three broad village presentation states: ordinary life, strained preparation, and public reckoning. Add a limited set of local changes for key decisions. Combine them through explicit precedence rules so a later global state does not undo a memorial, revive an absent NPC, or restore a closed workshop.

Reserve environmental storytelling for readable evidence: reused iron where hands polish it, a repaired gate whose hinge resembles a found weapon, censored names with recognizable tool marks, an abandoned meal, the physical route refugees could not take. Decorative clutter that obscures navigation or consumes performance without meaning is reduced.

## 17 Progression and economy

Keep progression shallow enough that attention and skill remain valuable. Convert some current percentage-only upgrades into new options: a safer recovery after a successful parry, a prepared shot that pins a binding, an Oathfire interruption with a readable trade-off. Prototype balance before committing the final tree.

Retain roughly the current nine-upgrade scale as an initial budget. Award advancement at chapter milestones and significant discoveries, with limited optional enhancements. Every main-path build can finish; essential capabilities cannot depend on grinding enemies or repeatedly collecting plants.

Give named equipment a provenance and a restrained mechanical identity. Kael's sword can visibly change through Tor's work. A witness token or repaired tool can matter more than a shower of randomized loot. Avoid equipment rarity tiers, random affixes, and disposable weapon replacement in the initial overhaul.

The economy reflects shortages and choices through bounded changes in supply, prices, favors, and labor. Preserve emergency ammunition and healing access. Closing a harmful operation creates an alternate supply or assistance route; it does not make the campaign unwinnable. Essential evidence is not saleable or consumed accidentally.

Keep crafting compact and legible. The existing oils, trap, bomb, potions, and ammunition provide enough initial variety. The player should know what an item solves before being asked to gather its ingredients.

## 18 Visual direction and animation

Choose coherent stylized realism with strong silhouettes, grounded materials, controlled contrast, and selective detail. Test it on the actual browser target before replacing the asset library. The important faces, hands, equipment, and story props receive detail before distant decoration.

Create an art bible covering body proportions, faces, costume construction, material roughness, palette, vegetation density, building structure, lighting, and supernatural effects. Use a small approved reference set and a representative in-engine scene. Label placeholders by role so temporary art cannot be mistaken for final approval.

Greyfen should initially feel inhabited and warm enough to matter. Wychwood's threat comes from interruption of familiar order. Vargan expresses administrative power and neglect, not only grand ruins. The Hart sequence reuses motifs the player has learned throughout the campaign.

Prioritize Kael, Anwen, Rook, Edric, then the remaining principal cast. Require distinct silhouettes and readable expressions. Fix foot contact, equipment attachment, sword draw and sheath, bow grip, interaction reach, conversation orientation, and hit reactions. Small convincing actions carry more story than elaborate camera moves around static people.

Use weather and time of day to support authored scenes while keeping navigation and combat readable. Preserve key visual cues on low settings. Maintain one licensed asset manifest with source, permissions, modifications, skeleton, material and performance requirements; evaluate assets in context before importing a large pack.

## 19 Audio, voice and cinematics

Build sound identities for daily work, the bell, the road, the shrine, Vargan's authority, and the Hart. Reuse motifs with changed instrumentation or rhythm so the player hears consequence. Place environmental audio to explain space and activity; silence after a confrontation should make room for the aftermath.

Create a dialogue priority and interruption system so barks, narration, music and combat cues do not compete. Provide subtitle size, speaker names, background opacity, independent audio buses, and a readable text log. Do not require hearing a musical interval to solve a mandatory encounter.

Voice the opening, turning points, confrontations and finale first. Record or generate final performance only after the scene works in text and staging. Human review covers pronunciation, emotional intent, timing, consistency, and the complete mix. Current synthetic scratch speech is not assumed to be approved performance.

Use a small set of in-engine scene patterns: walking exchanges, work interrupted by conversation, a two-person confrontation, an object-focused revelation, and the assembly. Avoid a fully cinematic production pipeline unless resources justify it. Scenes support pause and subtitle review; skipping preserves the decision and correct game state. Repeat attempts skip previously watched setup by default.

## 20 Interface, accessibility and onboarding

The HUD answers what needs attention now, where the next lead is, and what resources matter. Keep objective text consistent across tracker, journal, dialogue, map and world prompts. Every objective includes a clear action and reason; journal detail holds the longer context.

Dialogue options state Kael's intended action accurately. Separate asking a question from committing to an outcome. Mark a conversation's exit and irreversible choice clearly without labeling moral correctness. A report scene shows which evidence is being handed over and what remains available.

Provide remapping, controller glyph switching, adjustable sensitivity, optional targeting assistance, hold/toggle options, readable text scaling, motion and shake controls, flash reduction, and cues that do not rely on color alone. Check every menu, vendor, journal, conversation and ending with keyboard-only navigation and a physical controller.

Make pause behavior explicit. Single-player menus and dialogue should pause threats where the scene does not intentionally require real-time action. Return-from-tab, lost focus and controller disconnect must not kill the player or confirm a choice. Support a clear manual save, autosave indicator, multiple slots, pre-decision saves where appropriate, and save export/import for browser users.

The loading screen shows honest progress, retry and useful controls. Crow Flight is optional, immediately skippable when the game is ready, and cannot obscure error recovery. A restrained return recap shows the active promise, last major decision, and next lead.

Prepare text for localization through stable string IDs, a terminology and pronunciation glossary, expandable layouts, subtitle timing and font coverage. Finish and test the source-language story first; choose additional languages from audience and budget rather than promising them prematurely. Important text must remain readable without being baked into an image.

Support replay through separate save slots, a clearly labeled pre-finale checkpoint, and an optional completed-campaign chapter replay that uses a copied state. The original campaign outcome remains intact. Let players discover different relationships and approaches; defer New Game Plus stat escalation until ordinary replay demonstrates a need.

## 21 Technical architecture and save continuity

Retain the current engine line and proven components. A major engine upgrade is a separate benchmarked decision, not a prerequisite for the story overhaul. Keep current feature IDs where possible and isolate changed rules behind existing service boundaries.

Assign clear ownership:

- `QuestManager` owns progression and objective eligibility.
- `StoryState` owns consequential facts, recorded decisions, and bounded narrative values.
- Dialogue selects available statements and requests an action; it does not independently mutate several unrelated stores.
- A small story-action coordinator validates a consequential decision, applies its state changes once, and emits the result.
- Presentation services derive actors, props, objectives, sound and epilogues from committed state.
- `SaveManager` serializes a coherent snapshot and migrates supported prior versions.

This is an incremental extraction from existing code. It does not require a generalized branching engine, event-sourcing framework, or a rewrite of every coordinator.

Apply all effects of a consequential action before publishing quest-completion notifications or creating a checkpoint. The inspected code mutates several stores sequentially while completion listeners can save synchronously; this is a source-level ordering risk to reproduce. An unreachable autosave call and inconsistent pending-finale identifiers also warrant targeted regression checks. Keep choice committed, final encounter pending, and ending resolved as distinct states. Normalize ending identifiers through one explicit mapping rather than assuming `kill` and `ash`, or `bind` and `duty`, are interchangeable everywhere.

The key invariant is: **inspect evidence, choose an outcome, and complete a quest are distinct actions.** A clue cannot finalize a moral decision. Repeated interaction, reopening dialogue, loading a save, or receiving the same event twice cannot grant duplicate rewards or reverse the outcome.

Use a small versioned content schema for each choice: stable ID, allowed outcomes, eligibility conditions, effects, consent status, unavailable-actor fallback, presentation references, and verification cases. Validate references and reachable fallback routes before runtime. Keep authored decisions explicit and bounded.

Store evidence history separately where it matters. The existing completed-quest behavior can report all objectives done, which is useful for broad progression guards but cannot prove which optional clue a player actually inspected. Finale arguments and journal claims must use recorded evidence rather than infer knowledge from chapter completion.

Preserve unknown legacy decisions as unknown. Never invent consent or a moral choice from a completed objective. When reconstruction is ambiguous, present a contextual recap or one-time resolution, with the original save backed up. Define how an old save enters rewritten chapters; support an explicit chapter-boundary conversion where seamless conversion is not truthful. Establish this policy before removing old objectives.

Validate the converted story state, required resources and safe destination before replacing a save slot. Keep the original recoverable until that validation and the new write succeed. If chapter mapping or a necessary pack fails, leave the original intact and offer retry or recovery. Valid JSON alone is not a successful migration.

Distinguish the release label V10 from the save schema number. Choose the next schema version from the code at implementation time. Test previous supported schemas, interrupted writes, corrupt files, missing fields, duplicate callbacks, unavailable NPCs, completed endings, and old evidence references.

## 22 Browser delivery and provisional performance budgets

Keep Web delivery as the primary planning assumption. Confirm the actual supported browsers and hardware during the first tranche. Godot's Web documentation describes renderer, browser persistence and audio constraints; measure the exact pinned engine/export combination rather than assuming native behavior carries over.

Retained evidence gives a useful starting point: hardware Chrome on Intel HD Graphics 620 recorded 18.616 seconds from cold navigation to control, 1.606 seconds from New Game click to control, and 23.566 seconds for warm Continue navigation to control, including 11.919 seconds after the Continue click. Its isolated renderer-process private upper bound was 594.1 MB. Separate native diagnostic samples recorded a 140.268 ms worst hydration frame and 10.1 FPS 1% low during Greyfen hydration. These were not rerun for this plan, and the native record does not establish a complete hardware certification. Warm resumption and construction stalls deserve priority before additional visual density.

The following are **proposed acceptance budgets**, not current measurements or promises:

| Area | Initial target | Measurement conditions |
| --- | --- | --- |
| Boot feedback | Visible UI and meaningful progress within 1 second | New browser session; loading UI independent of engine initialization |
| Cold playable opening | 15 seconds or less at the 95th percentile | 20 Mbps, 50 ms RTT, empty HTTP and game caches, nominated reference machine; at least twenty trials for the release candidate |
| Critical initial download | Approximately 20 MiB compressed or less as an investigation target | Include engine, shell, mandatory opening data and immediately required audio; verify feasibility before locking |
| Warm playable opening | 7 seconds or less at the 95th percentile | Same reference machine, populated valid caches, engine restarted; include Continue with a representative late-game save |
| New Game after menu prewarm | 750 ms or less | Player control and scene readiness, not button acknowledgment |
| Baseline gameplay | Stable 30 fps floor at 720p on the minimum reference target; 60 fps target on the recommended target | Record frame-time percentiles, not only averages; separate loading and sustained play |
| Traversal | No routine main-thread stall above 100 ms; no black transition frames | Repeat the complete mandatory route with worst relevant world states |
| Memory | Retain the existing renderer-private target below 450 MB, plus no monotonic growth across ten hub-and-region cycles | Reproduce the original measurement scope; browser process, engine heap and native private memory are different metrics |
| Narrative continuity | No missing witness, duplicate reward, contradictory objective or lost committed choice | Save/reload at every major narrative boundary |

The initial-download and cold-start budgets are linked: 20 MiB alone takes about 8.4 seconds at an ideal 20 Mbps before startup overhead. If the pinned engine payload makes that budget infeasible, record the measured floor and revise payload strategy or the user-approved platform target. Do not claim success by timing only the menu or ignoring engine bytes.

Preserve the existing 104,857,600-byte total deployment cap until an explicit platform decision changes it. Current V10 contains 96,042,769 bytes, leaving 8,814,831 bytes within that contract. New voice and art therefore require replacement, compression or revised delivery, rather than assuming unlimited additive headroom. Retain the original performance goals in the ledger; any revised acceptance threshold must be an explicit decision, never silently relabeled as the old target passing.

Prioritize removing unused runtime content, deferring later regions, reducing texture and animation memory, avoiding duplicate pack residency, warming only needed resources, and limiting synchronous scene construction. Streaming cancellation, corrupt cache, retry, offline return, tab suspension and version updates need explicit tests.

Reuse `ZoneRuntimeCoordinator` for activation and rollback. Resource download readiness does not prove that scene construction or render uploads are complete. Current pack retirement retains mounted packs, so do not assume cancellation frees their memory. Narrow zone invalidation to the story dependencies each area actually displays, with regression proof that this optimization never leaves stale consequences.

Godot 4.6 Web exports use WebAssembly/WebGL 2 and Compatibility rendering; enabling threads brings additional cross-origin isolation requirements. Browser saves depend on available persistent storage, and audio activation requires user interaction. Plan an explicit unavailable-storage state and save export/import, and test actual persistence after restart. See [Godot 4.6 Web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html). Background resource loading still requires separate management of loading completion and activation work; see [Godot background loading documentation](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

Pin a minimum and recommended test machine by model, CPU, GPU, RAM, OS, browser, graphics preset and resolution. Test integrated graphics and a real controller. If the desired art cannot meet the baseline, adjust density, shading and staging before sacrificing readable faces or core consequences.

## 23 Verification and player research

Keep four kinds of evidence distinct: source validation, deterministic runtime checks, real-input route testing, and human evaluation. Passing one does not stand in for the others.

Automated coverage checks objective and dialogue references, allowed choice values, unavailable-actor fallbacks, one-time rewards, save migration, committed-state consistency, scene resource existence, and mutually exclusive outcomes. Test relevant pairs of major choices and all explicitly conflicting combinations; do not claim exhaustive coverage of every possible campaign permutation.

Mandatory played routes include each of the four endings, a main-path-only run, a run with low trust and minimal optional support, a run with substantial aid and voluntary testimony, and the principal violent and peaceful resolution variants. These profiles can overlap where the actual evidence proves the overlap. Test resumption from a saved chapter and browser storage interruption.

Because Web is the primary release, the mandatory campaign and all four endings require real-input proof in the nominated primary browser, initially Chrome. Use native runs for fast deterministic coverage and diagnosis. Edge and Firefox receive explicit opening, resumption, representative late-chapter, each ending-resolution, audio and storage checks; expand that matrix if discrepancies appear or equal platform certification is promised. Report the exact platform and route each record proves.

For each major choice, verify: availability is accurate; the selected action matches its text; the immediate result occurs once; the next return shows the result; save/reload retains it; the finale and epilogue describe the same facts. Capture before and after from comparable views where appearance changed.

Human review evaluates whether players care about someone, understand the mystery, feel ownership of decisions, notice preparation benefits, read combat, enjoy movement, and believe the performances. Use observed behavior before leading questions. Ask players to explain a choice before revealing the intended meaning.

Campaign completion criteria: no known progression blockers or save-loss defects; every main beat has played evidence; every ending has a coherent playable resolution; every principal character has an enacted payoff; all consequential outcomes have persistence proof; performance targets are measured or explicitly renegotiated; complete mix and accessibility passes are recorded. Minor known issues are documented with their actual effect.

## 24 Delivery sequence

| Stage | Deliverable | Dependencies | Exit condition |
| --- | --- | --- | --- |
| 0 Establish the baseline | Current source/release map, protected legacy saves, short capture of the existing opening, dated issue ledger | Existing build and access to target machine | Everybody can distinguish implemented, documented, measured and proposed behavior |
| 1 Lock the narrative | Revised bible, timeline, character arcs, reveal ledger, choice rules, ten quest treatments and four endings | Stage 0 and creative direction | No unresolved contradictions in memory, consent, chronology or endings; each major reveal changes action |
| 2 Prove the opening | 45–60 minute integrated slice including one optional story and persistent consequence | Stage 1 opening decisions; targeted state/save work | Unfamiliar-player acceptance, readable combat, story continuity and pinned-machine performance budgets; any exception requires an explicit scope decision and correction plan before expansion |
| 3 Build campaign breadth | Complete campaign in coherent placeholder presentation; all four endings reachable | Stage 2 validated patterns | Main-path-only and adverse-choice routes finish; every chapter has aftermath and save support |
| 4 Deepen the people and world | Six substantial optional stories, four interludes, character arcs and village changes | Stable main-path states | Optional work changes the campaign; every major outcome has an enacted echo |
| 5 Finish presentation | Final priority characters, boss identities, environments, animation, key voice and adaptive audio | Stable scenes and approved slice art direction | Human visual and listening review on target hardware; no important story action hidden by presentation |
| 6 Certify the whole experience | Final balance, pacing, accessibility, route matrix, persistence, performance and release candidate | Feature and content freeze | Required evidence passes with scoped claims and documented residual issues |
| 7 Release and observe | Approved release milestone, exact deployed artifact verification, save checks, focused feedback round | Stage 6 | Public build matches the accepted candidate and real users can start, play, save and return |

Performance, accessibility, saves and story coherence begin in Stage 2 and continue throughout. They are not work deferred entirely to Stage 6. Later presentation stages finish quality already proven in representative scenes.

The critical path is narrative rules → choice/state integrity → opening slice → complete playable campaign → integrated endings → final presentation and certification. Parallel art, audio and tools work is useful only after the relevant scenes and interfaces stabilize.

## 25 Work packages and source map

All existing paths below are relative to the game root unless a repository prefix is stated. Proposed documentation paths are new. Exact implementation signatures and test commands are finalized per tranche after its scene design is accepted; inventing them for the entire campaign now would conceal unresolved creative decisions.

| Package | Work | Primary files or area | Acceptance evidence |
| --- | --- | --- | --- |
| PLAN 01 | Reconcile current release truth and legacy source drift | `PROJECT_STATE.md`, `CERT_001_RESULT.md`, `release_reports/functional_candidate_v10.json` | Dated evidence ledger without inherited false completion claims |
| STORY 01 | Revise canon and chronology | `STORY_BIBLE_ASHEN_OATH.md`, proposed `docs/narrative/canon.md` | Rules and ages consistent across the full plot |
| STORY 02 | Write full campaign and reveal ledger | `STORY_ARC_FULL_GAME.md`, proposed `docs/narrative/reveals.md` | Every reveal has source, timing and playable consequence |
| STORY 03 | Write character and dialogue direction | `data/dialogue.json`, `data/campaign_dialogue.json` | Ordinary life, conflict and payoff for each principal character |
| STORY 04 | Define choice and ending contracts | `CHOICE_AND_CONSEQUENCE_SYSTEM_PLAN.md`, `epilogue_contract.json`, `hart_remembers_contract.json` | Explicit ending costs and consent semantics |
| STATE 01 | Separate evidence, decision and completion | `scripts/quest_manager.gd`, `scripts/story_state.gd`, `scripts/game.gd` | Bitter Roots regression plus rejected premature decisions |
| STATE 02 | Apply consequential actions exactly once | `scripts/dialogue_manager.gd`, `scripts/dialogue_runtime_coordinator.gd`, targeted action extraction | Duplicate input/reload cannot repeat effects |
| SAVE 01 | Define and implement legacy migration | `scripts/save_manager.gd`, old-save fixtures | No invented choices, consent or lost originals |
| GUIDE 01 | Unify objectives and journal state | `scripts/quest_beat_director.gd`, `scripts/quest_presentation_state.gd`, `scripts/quest_hud_coordinator.gd`, `scripts/hud.gd` | All guidance agrees before and after a decision |
| OPEN 01 | Author opening and teaching route | `FIRST_HOUR_INTERACTIVE_SCRIPT.md`, `first_hour_flow_contract.json`, `data/quests.json`, opening zone scripts | Complete opening with optional preparation and visible report consequence |
| FEEL 01 | Movement, camera and combat readability | `scripts/player_controller.gd`, `scripts/camera_controller.gd`, `scripts/combat_manager.gd`, `combat_tuning.json` | Target-hardware playtest including low frame rate and controller |
| INVEST 01 | Evidence provenance and tactical effects | Existing clue handling, `data/quests.json`, `scripts/hud.gd` | Multiple valid clue orders and a visible changed approach |
| ACT 01 | Shrine and forest chapter | Cemetery/Wychwood sections, `data/campaign_dialogue.json`, `data/bosses.json` | Supernatural rule learned through action; Anwen's admission persists |
| ACT 02 | Names, mill and Senn chapter | Campaign wilderness and bandit-road sections, quest/dialogue data | Food decision and testimony change named people and later access |
| ACT 03 | Vargan and Halvern chapter | Castle/ruins sections, `scripts/boss_encounter.gd`, campaign data | Multiple approaches; bounded memory; coherent political response |
| FINAL 01 | Assembly and voluntary witnesses | `scripts/game.gd`, `scripts/story_actor_presence.gd`, campaign dialogue | Absent/compelled actors cannot supply false consent |
| FINAL 02 | Four playable resolutions | `white_hart_encounter_contract.json`, `scripts/boss_encounter.gd`, finale section | Each ending playable through main-path support; distinct procedure and cost |
| FINAL 03 | Return scenes and epilogues | `scripts/epilogue_resolver.gd`, `narrative_aftermath_contract.json`, finale/world presentation | Scenes, cards and actual state agree |
| SIDE 01 | Six substantial optional stories | `side_quest_contract.json`, `data/quests.json`, dialogue and relevant zones | Each decision enacted, revisited and saved |
| SIDE 02 | Four interludes and warm village moments | Optional quest entries and Greyfen/cemetery/road staging | Concise individual payoffs without filler travel |
| WORLD 01 | Legible connected region and shortcuts | `world_sector_manifest.json`, `zone_streaming_topology.json`, `scripts/zones/` | Complete route navigation without repeated empty returns |
| WORLD 02 | Persistent village and local aftermath | `scripts/world_prop_controller.gd`, `scripts/story_actor_presence.gd`, zone presentation | Correct composition of global chapter state and local decisions |
| PROG 01 | Skill and equipment identity | `data/upgrades.json`, `scripts/progression_manager.gd`, inventory/player code | Meaningful options; all main-path builds viable |
| ECON 01 | Vendors, preparation and restitution | `data/items.json`, `data/vendors.json`, `scripts/inventory_manager.gd`, `scripts/vendor_service.gd` | Essential supply recovery and consequence-sensitive economy |
| ART 01 | Art bible and representative target scene | `character_role_manifest.json`, `curated_runtime_assets.json`, representative scene | Coherent style and measured cost before bulk production |
| ART 02 | Principal characters and animation | Character scenes/assets, player and NPC setup | Distinct identity, sound attachments, feet/hands and dialogue staging |
| ART 03 | Monster and boss identities | `monster_family_manifest.json`, `data/enemies.json`, `data/bosses.json` | Silhouette, behavior, counterplay and aftermath for each |
| ART 04 | Priority environments and effects | Zone scenes, `scripts/world_material_library.gd`, `scripts/world_vfx_controller.gd` | Clues and combat readable across weather and settings |
| AUDIO 01 | Mix, ambience, motifs and interruptions | `scripts/audio_manager.gd`, `scripts/prepared_audio_bank.gd` | Full-scene listening review with speech intelligibility |
| VOICE 01 | Main scenes and payoff performance | `voice_production_manifest.json`, dialogue assets | Approved performance after script and staging lock |
| UX 01 | Dialogue, journal, inventory and saves | `scripts/hud.gd`, input/settings/dialogue/save services | Complete mouse, keyboard-only and controller flows |
| ACCESS 01 | Accessible action and information | `scripts/input_router.gd`, `scripts/settings_manager.gd`, camera/HUD/audio | Text, motion, input and non-audio clue coverage |
| PERF 01 | Startup and residency | `runtime_pack_manifest.json`, `scripts/runtime_pack_manager.gd`, `scripts/zone_runtime_coordinator.gd`, `scripts/zone_scene_catalog.gd`, streaming/residency services, opening hydration in `scripts/game.gd`, `export_presets.cfg`, `web_boot_shell.html` | Separate download, construction, renderer readiness and residency budgets; cold/warm trials and route-cycle stability |
| QA 01 | Story and state coverage | Existing `tools/` plus targeted new cases | Choices, absent actors, interrupted events and migrations verified |
| QA 02 | Human campaign, visual and audio review | Played route records and scoped captures | Complete main story, four endings and approved presentation |
| REL 01 | Candidate promotion and monitoring | Repository `scripts/deploy_web_update.ps1`, `DEPLOYMENT_POLICY.md`, `web/` | Approved milestone, artifact parity, save and live route smoke checks |

## 26 First implementation tranche

The first tranche should complete a reviewable opening, rather than begin dozens of parallel upgrades.

- [ ] Preserve the current candidate, record source identity and save schemas, and establish the reference machine. Use read-only capture and isolated development work when implementation starts.
- [ ] Resolve the present-day renewal premise, Kael's pledge, supernatural rules, ending costs, and legacy-save policy in the narrative documents.
- [ ] Reproduce the premature-choice concern in Bitter Roots and establish tests that separate inspection, selection and completion.
- [ ] Implement the smallest state/action changes needed for a reliable opening choice and save/reload cycle.
- [ ] Build the opening in simple coherent staging, including Rook, Anwen, a living person helped, the cart investigation, preparation and the Ghoulkin encounter.
- [ ] Implement all three opening report outcomes, each with a distinct immediate response and return-state change.
- [ ] Integrate one optional story, preferably Iron Remembers or Bitter Roots, to prove that side content can change practical help and later testimony.
- [ ] Add the representative character, environmental and audio treatment; benchmark before multiplying that treatment across the campaign.
- [ ] Run the defined new-player session and technical checks; record confusion, boredom, missed consequences and frame-time problems.
- [ ] Revise until the slice establishes both emotional interest and technical viability; then estimate the remaining campaign from measured work.

Adapt the existing regression harnesses before creating duplicates: `tools/verify_save_001.gd`, `tools/verify_save_version_boundary.gd`, `tools/verify_hart_pending_reload.gd`, `tools/verify_story_choice_save_evidence.gd`, `tools/verify_quest_completion_checkpoint.gd`, `tools/verify_story_clue_orders.gd`, `tools/verify_story_continuous_native.gd`, `tools/verify_story_combined_native.gd`, `tools/verify_720p_performance.gd`, and `tools/verify_qa_002_browser.mjs`. For the source concerns above, first demonstrate the current behavior, then establish the intended invariant and verify the corrected behavior.

## 27 Capacity, scope control and production discipline

A credible calendar depends on the opening slice: record time spent per completed scene, encounter, character, zone and consequence set. Forecast the remaining content with those actual rates and a visible integration allowance. Do not treat AI-generated drafts or asset imports as finished production throughput.

For initial capacity planning, reserve roughly one quarter of total effort for integration, playtesting, correction and release work. Narrative design and implementation remain active throughout the other work; they are not a short pre-production ceremony. Re-estimate after the opening, after the complete rough campaign, and after presentation lock.

The essential roles are narrative/game direction, gameplay and tools engineering, environment and character art/animation, audio/performance direction, and QA/player research. A person can hold several roles, but the acceptance work still has to happen. Use specialist help where a weak face, animation or performance undermines a central relationship.

If scope must shrink, cut distant area expansion, extra weapon classes, decorative asset variety, full voice coverage, and optional quest count before cutting save reliability, character payoff, consequence visibility or ending quality. Keep a complete shorter campaign.

Defer multiplayer, procedural quest generation, live-service progression, large-scale faction simulation, survival meters, base building, mounts, elaborate crafting, procedural loot, and mobile parity. Native distribution or additional platforms become separate evidence-based decisions after the browser campaign is proven.

Use one active work package with scoped adjacent work. A package closes with the changed behavior demonstrated, relevant checks passed, human review where needed, and documentation of what remains. Existing historical acceptance is reused only within its actual scope and only if affected inputs still match. Production changes follow the repository's explicit milestone policy.

Ship with an accessible credits and controls page, accurate content descriptions, a short report-a-problem flow, and a known-good rollback candidate. QA tools and diagnostic shortcuts stay outside the production player flow. Collect identifiable player information only if the product later has a clear need and an explicit consent design; initial feedback can use volunteered reports and local diagnostic exports. Check public descriptions against the finished experience, including its measured playtime and supported devices.

## 28 Highest risks and responses

| Risk | Early warning | Response |
| --- | --- | --- |
| The player understands lore but cares about nobody | Testers recount history but cannot name a person they want to help | Rewrite the opening around action and relationships before more exposition |
| Every quest repeats the same moral lesson | Players predict guilt, clue quota, fight and confession | Vary objectives and let truthful, decent people disagree about practical remedies |
| Witness becomes the obvious correct ending | Other choices lack credible relief or developed scenes | Give each ending a sincere beneficiary, irreversible cost and equal presentation care |
| Consequences become combinatorial | Scenes require unique content for many unrelated flag combinations | Limit major outcomes, react to authored categories, and verify named high-risk interactions |
| Art expansion defeats browser performance | The representative slice already misses memory or frame-time targets | Reduce density/material cost and staging complexity before producing all zones |
| Old saves imply choices never made | Migration derives consent from objective completion | Preserve unknowns, back up, and offer a contextual resolution |
| Production feels complete only in documents | Gates check fields and screenshots without a playable route | Require real input, return consequences, saved state and human comprehension |
| Repeated overhaul cycles consume the project | New systems are added before a convincing chapter exists | Freeze breadth until the opening meets its exit criteria |

## 29 Review decisions and recommended defaults

The confirmed creative direction is to preserve the core identity with substantial story revisions. The recommended design choices are: use a present-day coerced renewal as the active conflict; target 6–8 hours main and 8–12 total; keep browser-first Godot delivery; develop six deep optional stories plus four interludes; prioritize an integrated opening before the rest; and keep four explicit endings with visible, different costs.

The best next development investment is the narrative lock and opening tranche. A stranger should leave that hour wanting to protect someone in Greyfen, doubting someone they also understand, and needing to know what the road remembers. That response is the foundation on which the full overhaul should be built.

## 30 Source record

Primary project sources reviewed include `STORY_IMPLEMENTATION_CONTEXT_BRIEF.md`, `STORY_BIBLE_ASHEN_OATH.md`, `STORY_ARC_FULL_GAME.md`, `FIRST_HOUR_INTERACTIVE_SCRIPT.md`, `CHOICE_AND_CONSEQUENCE_SYSTEM_PLAN.md`, `SIDE_QUESTS_AND_VILLAGE_STORIES.md`, `PROJECT_STATE.md`, `CERT_001_RESULT.md`, `release_reports/functional_candidate_v10.json`, the current quest/dialogue/boss/item/upgrade/vendor data, the first-hour/side-quest/ending contracts, and selected quest, story, save, dialogue, world, encounter and epilogue scripts. Repository workflow and deployment policy were consulted for delivery boundaries.

All new plot developments, content allocations, performance budgets, production stages, and acceptance thresholds in this document are recommendations. Existing document claims retain their original scope. The most recent project-state entry takes precedence over older milestone descriptions when they conflict.
