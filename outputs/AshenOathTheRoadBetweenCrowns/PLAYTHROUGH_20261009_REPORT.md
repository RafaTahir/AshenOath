# Ashen Oath - One Playthrough Review, 2026-10-09

Status: MAIN COVENANT ENDING REACHED - WITNESS. This was one earned production
journey, not a clean uninterrupted pass, all-endings certification or replay suite.
Checkpoint retries and one browser reload were necessary. The return-home
epilogue was attempted but not completed. No game source fixes, exports, commits
or deployments are part of this review. Existing work and saved journeys remain.

## Verdict

The main story can reach a genuine ending through normal player interactions.
It has good human stakes and several meaningful choices. However, this journey
exposed a checkpoint softlock, a peaceful boss resolution that does not retire
the boss, inconsistent recovery UI, misleading route/objective presentation and
camera failures. Those take priority over additional features or art polish.

The story is substantially stronger than its on-screen staging. Preserve the
preferred character family and the working content; repair state continuity,
navigation and presentation around it rather than replacing everything again.

## Session

- Live build: `mobile-003-20261008-landscape`; package commit `9ac593a`.
- Root PCK identity: `6a4058e4373464075c31fc07d0016474889ee8f1e97d4cb2a5fca8937f14a488`.
- Production URL: `https://ashenoath.vercel.app/?v=mobile-003-9ac593a&observe=1`.
- Environment: Codex in-app Chromium, desktop viewport 1280x720, keyboard/mouse.
- One New Game click, several normal earned-checkpoint retries after death and
  one browser reload/recovery-copy load of that same journey. No teleport,
  progression mutation, prepared save, console gameplay commands or direct
  interaction-handler calls. Normal jumps were used where walking failed.
- Targeted source reads helped explain observed failures and locate ambiguous
  routes; the campaign was not completed blind. Every gameplay action still used
  ordinary keyboard/mouse input. Historical verifier results are not play evidence.
- Browser/cache already contained prior saved-journey information. This is not a
  certified cold-cache run, iPhone/WebKit test or physical-controller test.
- Package observed: 16 files, 92,419,781 bytes (88.14 MiB). This describes the
  deployed artifact, not a new export or performance certification.
- Screenshots and captured browser errors:
  `D:/Temp/AshenOath/Playthrough_20261009/`.

## Route Diary

1. Main menu -> Controls -> main menu -> New Game.
2. Walked across Greyfen's bridge to the village without jumping or recovery.
3. Took the waiting cup, spoke with Anwen, volunteered to help, read Unfinished
   Work, and placed the cup by the privacy screen through the normal E prompt.
4. Read the favor's complete reaction and returned to Anwen. Her main-quest
   dialogue acknowledges the water before mentioning the three missing people.
5. Completed Anwen's briefing; committed to bringing back evidence.
6. Rescued and invited Bracken. He followed into Wychwood across the ordinary road.
7. Inspected Bram's ledger, Sella's red-thread feathers, Vargan binding evidence
   and drag marks. Crossed the forest bridge without a jump or river recovery.
8. Confirmed sword hits (55 -> 27 -> death), heavy hits (48 damage), incoming
   damage, target lock and Oathfire casting/stamina consumption. One death occurred
   while the fight remained live during inspection; it is not a balancing verdict.
9. Loaded the earned checkpoint. Health and quest restored, but no pack member was
   activated on the restored route. Walked through the clearing without acquiring
   an active opponent. Source inspection identified the activation-state gap.
10. Reloaded the browser once: Continue remained disabled, Save Library displayed
    Save storage is preparing, and returning to the menu exposed two identically
    labelled recovery copies. The first recovery resumed this earned Wychwood journey.
11. Defeated the resumed five-enemy sequence: two Ghoulkin, Stalker, Raider, Brute.
    Objective advanced to return to Greyfen and choose how to report.
12. Returned to Greyfen and chose a public road report that protects witnesses.
13. Read Edric's proclamation; found Anwen at the cemetery; inspected disturbed
    graves, heard Widow Elna's account and killed the child-grave Ghoulkin.
14. Entered the chapel and fought Bell-Eater. At the Crow Shrine, chose to open
    memory and keep names intact. Teeth in the Rain unlocked, but Bell-Eater
    continued attacking and following Kael into Greyfen.
15. Spoke with Mira, used healing potions, bought/applied Moon Oil, and finally
    crafted the required preparation. Found Oren's name and entered Deep Woods.
16. Used the dry-cloth/green-root clue, defeated Bog Wretch and preserved its
    memory for study. Names They Burned unlocked.
17. Retrieved register evidence in Greyfen, Deep Woods, the mill and farmstead.
    Rootbound attacked during transit; I did not defeat it in this journey.
18. Returned to Anwen, reconstructed the record, and published names/order while
    removing family addresses. Investigated the mill and defeated its Ghoulkin.
19. Used the mill sluice and protected the wage chest. Defeated Ashwing through
    guarded heavy attacks and earned phase checkpoints. Chose to close tainted
    channels while preserving the ledger and ration reserves.
20. Walked through farmstead and marsh. The marsh's north exit required a
    sprint/jump workaround after ordinary walking fell into route recovery.
21. Heard Senn's testimony, defeated two hostile bandits and accepted custody with
    free testimony. The signed north Castle approach was blocked; the actual east
    sector boundary worked. Entered Castle Vargan through ordinary controls.
22. Presented old-road testimony, collected the three Castle accounts, and entered
    Record Hall. Recovered the obstructed camera by zooming/tilting it. Copied the
    ledger while leaving the original available; defeated the haunting.
23. Confronted Edric and chose a public ledger, removal of his power and signatures.
24. Entered the undercroft. Presented the copied command to Halvern and preserved
    his refusal as testimony without binding him to another oath. This peaceful
    resolution worked without requiring his defeat.
25. Gathered the earned testimony at Greyfen's assembly, spoke Kael's admission,
    released grain and invited voluntary testimony. Walked the reopened road.
26. Met the White Hart, selected Witness, laid down the ledger, named Bram Kett,
    Sella Vey and Oren, and acknowledged Kael's retreat. The covenant completion
    screen confirmed the ending. Evidence: 14-witness-covenant-complete.png.
27. Selected Walk the road home. Greyfen again contained a hostile 260-HP
    Bell-Eater; Kael died at low health before the Anwen epilogue was completed.
28. The earned checkpoint restored the completed covenant and 18/125 health at
    Hart Glade. Its normal return led to the assembly, whose objective asks for
    Anwen but contextual guidance says Return beneath Castle Vargan. The epilogue
    remains incomplete; it is not counted as a successful aftermath route.

Some deaths happened while the live game continued between inspection/tool calls.
They establish that actors remain active, not that ordinary human reaction time
or boss difficulty is inherently unreasonable.

## Working Observations

- New Game works in this session. Existing logs report 173.8ms ready after the
  click, with Greyfen already prewarmed. Prior menu preparation was 18,392ms;
  these are separate phases, not proof of instant page-to-control loading.
- Mouse New Game, normal movement, bridge traversal, E interaction, journal,
  the water action and dialogue-history return have worked.
- The original autosave is shown as Unavailable with Continue disabled. Returning
  from Controls exposes two indistinguishable Recovery: Autosave buttons. Cause
  and recoverability have not been established; do not label the save lost.
- The photographic menu/journal art and the actual low-poly world set very
  different expectations. Keep the user's preferred A-set; improve consistency
  rather than silently replacing its asset family.
- Dialogue cameras can place Kael in the privacy screen and obscure/cut off his
  head/limbs, producing floating-looking hands/equipment. Screenshot
  `01-dialogue-character-occlusion.png` records one such view.
- Anwen frequently presents her back while addressing Kael. Close dialogue shots
  do not consistently establish eye contact or a clear speaker silhouette.
- The injured-water vignette is well-written but visually under-staged: the nearby
  man remains upright, and the narrated reaching/lifting/breathing gesture is not
  visibly matched by the actors.
- The cup is recorded/acknowledged correctly, but no clear carrying/placing hand
  animation was visible. The journal gives a useful precise tray instruction.
- The two large black scabbards and extremely bright bow/weapon surfaces dominate
  Kael's silhouette and intersect foreground scenery in close views.
- Several world-space labels and markers compete with the HUD; the Standard arrow
  binding is clipped to `[Left`. Some transient top guidance ends mid-sentence.
- Dialogue action text looks doubled/heavily offset relative to otherwise legible
  subtitles. Default keyboard focus starts at History, not Continue; three Tab
  steps through Close and the subtitle reader reach the main action.
- Night remains navigable and the scene changes lighting/time. Clouds are large,
  repeated flat shapes; the distant terrain and scattered props look provisional.
- Two browser-control CDP timeouts occurred during dialogue mouse actions. The
  same session remained observable/responsive and error/warning capture was empty.
  Treat these as transport incidents, not confirmed game crashes/button defects.
- Audible mix/voice quality is not observable through these screenshot/log tools;
  do not invent a listening verdict from audio state messages.

## Additional Findings

- P0: Mid-encounter checkpoint restoration can leave every pack member inactive.
  `game.gd:6766` suspends newly spawned Wychwood enemies. First activation at
  `game.gd:4341` depends on the one-time clearing tutorial flag and zero kills;
  further waves rely on death callbacks. `load_world_state` restores the kill count
  but does not restore the active wave or reset that tutorial gate. Same-process
  restoration reproduced the empty encounter. A fresh-engine recovery worked around
  this particular zero-kill saved checkpoint; it does not fix the recovery contract.
- P0/P1: Save Library cannot reach its service. `hud.gd:4177` reads save_manager
  from its direct parent, but `runtime_service_registry.gd:72` parents the HUD under
  a registry whose service instances live in a dictionary/get_service API, not a
  save_manager property. The Preparing message is an unavailable service path,
  not evidence that browser storage is still synchronizing. Other parent-property
  lookups in HUD deserve the same ownership review.
- After page reload the normal Continue selection was unavailable, while genuine
  recovery copies were readable. Data is not proven lost. `continue_model` compares
  the remembered selection's state token with the rewritten slot: reconcile that
  pointer lifecycle with ordinary autosaves, and expose why Continue is unavailable.
- Bracken's rescue area trapped ordinary movement once. A normal jump and sidestep
  freed Kael. Fix the interaction/standing position and prop clearance; exact
  collision ownership was not proven by this single run.
- The camera repeatedly filled with pale/green geometry during targeting and
  movement, including after native display sizing was restored. Nearby foliage
  or self/actor geometry can obscure almost all of the gameplay view. The exact
  mesh owner remains unproven. Evidence: 04-camera-view-obscured.png and
  05-foliage-camera-obstruction.png; the latter filename is not owner attribution.
- At the native narrow browser size, quest text, combat target/health, prompts,
  notices, guard guidance and supplies overlap. Death recovery actions start below
  the visible area and need outer-menu scrolling. Long enemy names/distances clip.
- Light and heavy attacks demonstrably work; no blanket broken-left-click claim is
  supported. Short isolated attempts were inconclusive; close walk-and-strike and
  stationary locked heavy attacks produced actual damage and kills.
- Oathfire cast and spent stamina, but the observed casts did not establish damage
  or endpoint correctness. Target lock does not by itself prove the captured cast
  direction matches the enemy. Keep this separate from a confirmed Oathfire defect.
- The opening pack is paced as five sequential activations, not a simultaneous
  five-enemy fight. This run establishes the sequence, not five-at-once readability.
- Browser errors included WrongDocumentError for pointer lock and Chromium
  UnknownError. In-app browser input/viewport behavior complicated camera and mouse
  inspection. No parser/resource failure was identified; a zero-error run is not claimed.

## Final Coverage and Recommendations

### Fix First: Continuity and Recovery

1. **Opening wave recovery softlock - critical.** Restore the encounter's active
   wave from earned save state, independently of a one-time tutorial and fresh
   enemy death callback. Re-entering an unfinished encounter must always have a
   legitimate opponent or explicitly resolved outcome. This was the only problem
   that required restarting the browser to continue the main journey.
2. **Peaceful Bell-Eater outcome does not retire hostility - critical.** The
   shrine decision advances the chapter while the boss remains alive and harmful.
   It attacked during dialogue, followed into the village and reappeared on later
   Greyfen entries, including after Witness. Persist one encounter resolution and
   apply it to spawn, AI, damage, dialogue safety and aftermath. Do not merely
   hide the boss in one visit. Evidence: 08-boss-obscures-shrine-dialogue.png.
3. **Recovery UI and save service ownership - high.** Fix Save Library's registry
   lookup and reconcile normal Continue with the readable recovery copies. Show
   distinct saved location/time/source and a useful unavailable reason instead of
   two identical recovery labels or indefinite Preparing. Saves were recoverable
   in this run; there is no evidence that all save data was lost.
4. **Checkpoint safety - high.** Review checkpoints with 18/125 or 23/125 health
   beside an active boss, and make peaceful/conversation arrivals safe. Preserve
   earned choices and legitimate difficulty; avoid a repeated death loop caused
   by restored danger or stale encounter state. Ashwing's phase-health continuity
   worked and should be preserved.

### Navigation and Camera

5. **Marsh exit lies beyond its playable floor - high.** Walking north reached an
   edge/recovery instead of Bandit Road. Sprinting and jumping crossed it. The
   spatial contract lacks explicit extents for several wilderness zones and falls
   back to larger bounds, while their authored floor uses smaller bounds. Make
   sector threshold, floor, collision, recovery and road joins agree. Evidence:
   11-marsh-route-edge-recovery.png. This was a workaround, not a clean crossing.
6. **Castle route marker points at a blocked route - high.** The signed north
   approach led into a berm; the working transition was on the east boundary.
   Align physical road, signed destination and actual trigger. Entering Vargan
   eventually worked; do not report the whole Castle as unreachable. Evidence:
   12-castle-signed-road-blocked.png.
7. **Small prop/foundation traps - high.** Bracken's rescue spot, the farmstead
   fragment area and the mill record's raised foundation needed sidesteps or
   jumps. Clear a normal standing/approach lane around required interactions and
   preserve their existing story state. The mill record was reachable from its
   front; it was not permanently deadlocked.
8. **Camera obstruction - high.** Close views, targeting and zone arrival can put
   the camera in roofs, screens, foliage/actor geometry or above a ceiling. Record
   Hall first looked like a blank floor/black horizon until camera adjustment
   revealed the actual room. The final conversation placed the camera inside the
   Hart. Apply collision-safe placement to gameplay and dialogue cameras, keep
   both speakers framed, and use an appropriate initial indoor camera. Evidence:
   01, 04, 05 and 13. Individual obstructing mesh ownership was not always proven.
9. **Speaker-facing and equipment readability - high.** Anwen and other speakers
   address Kael with their backs turned; faces/head/limbs get cropped in close
   frames. Keep the preferred body family, but fit framing and bone-attached
   equipment so two black scabbards and brilliant weapon surfaces do not dominate
   every shot. Do not mistake occluded anatomy for proof that the body is missing.
10. **Exterior travel still reads as sector substitution - medium.** Some roads
    work normally, but hard boundaries, instant scenery changes and unexplained
    physical-door jumps remain. Undercroft-to-assembly is a destination transfer,
    not a continuous walk home. Improve the existing joins before adding more land.

### Quest, Dialogue and UI

11. **Preparation objective ignores equivalent preparation - high.** Buying and
    applying Moon Oil worked but did not satisfy the mandatory preparation beat.
    Crafting it did; the Craft action was below the visible vendor fold. If the
    objective means Prepare, accept the valid bought preparation; if it means
    Craft, say that explicitly and make the required action discoverable.
12. **Mill objective is ahead of the world - high.** The HUD asked for a choice
    about the mill records before Ashwing was defeated; the interactable record
    appears only after the boss dies. Present the current actionable beat first.
    Source sequence: mill encounter -> Ashwing -> death callback -> record spawn.
13. **Unready choices appear actionable - medium.** Senn's custody decision was
    offered before the hostile guards were dealt with, then returned a generic
    not-ready response. Explain the actual prerequisite at the choice. Repeating
    the same lengthy conversation should not be the way to discover it.
14. **Bracken repeatedly steals interaction focus - high.** E often opened his
    already-resolved home conversation instead of the intended shrine, NPC or
    ledger interaction. Prioritize the looked-at relevant target, retire completed
    one-time dialogue and keep companion chatter optional. Preserve his following
    behavior and trust vignette, which are good foundations.
15. **Conflicting navigation text - high.** The mini-map destination label can
    look like the current location. After the ending, the tracker asked for Anwen
    while contextual guidance directed Kael beneath Vargan. Earlier Greyfen signs
    still referred to renewal/witness requirements; the separate assembly did
    correctly show No renewal tonight. Synchronize each actual aftermath location
    instead of assuming one correct assembly sign proves the whole village state.
    Evidence: 15-road-home-contradictory-guidance.png.
16. **Small-screen layout - high.** At approximately 564x572, HUD regions overlap,
    enemy names/bindings truncate and death actions begin below the visible fold.
    Native 1280x720 is substantially more readable, but still has cut-off guidance,
    world labels and offset/doubled dialogue action text. Make required controls
    visible, prioritize one objective and let settings/submenus scroll predictably.
    This is narrow desktop evidence, not an iPhone touch certification.
17. **Dialogue does not consistently belong to visible people - medium.** Mira
    participates in the mill account without being visibly there; Rook is quoted
    at assembly although his place is visibly left open. Narration can quote an
    absent person, but identify it as a recorded account. Live spoken turns need
    an actual speaker, reaction and reliable framing.
18. **Narrated actions lack performance - medium.** The injured man stays upright;
    reaching, lifting, carrying the cup and several emotional gestures are mostly
    text. Use a few meaningful authored poses/actions rather than making every
    exchange another static back-facing conversation. The writing itself is good.
19. **Clue delivery - medium.** Some Castle accounts advanced via tiny generic
    props/toasts rather than a readable piece of evidence. Decorative signs look
    more interactable than the required clue. Make evidence visible, identifiable
    and inspectable; preserve its current progression IDs.
20. **Minor textual duplication - low.** The recovery screen says World time:
    World time. Several prompts repeat a verb, such as Speak Hear testimony or
    Travel Return. Remove only the redundant presentation, not the actual action.

### Combat, Identity and Art

21. **Melee clarity - medium.** Light/heavy hits, guard, target lock, stagger and
    kills worked. Close guarded heavy attacks were considerably more dependable
    than many other attempted actions. Improve the visible reach, contact, guard
    break and recovery cues before changing balance. Hits outside reach should
    read as misses rather than apparently unresponsive mouse input.
22. **Ability teaching - medium.** The opening establishes that Oathfire consumes
    stamina and renders a beam, but this run did not confirm its damage endpoint.
    Bow clicks without aiming did nothing by design; source requires aim first.
    Teach these state requirements at the point of use. Neither observation alone
    establishes that the whole bow or Oathfire system is broken.
23. **Boss/choice staging - high.** Rootbound attacked during the travel route
    before a clear encounter briefing; Bell-Eater continued combat over choice
    dialogue. Separate a deliberate arena entry, readable threat and safe decision
    window. Halvern's copied-command peaceful resolution is the model to preserve.
24. **Named character identity - medium.** Senn's Ranger is distinct from villagers
    when first encountered, but Edric uses a closely matching green Ranger body.
    Halvern's combat presentation and peaceful dialogue appearance switch between
    Ranger-like and tan peasant-like bodies. Use consistent per-person assemblies
    and silhouettes, without abandoning the preferred A-set.
25. **Monster visual language - medium.** Skeleton-family Ghoulkin, blue assembled
    Bell-Eater, orange-eyed green slime Bog Wretch and cartoon drake Ashwing do not
    consistently support the grave, human tragedy in their stories. Tie material,
    silhouette, movement and arena evidence to each cause. The actual final Hart
    is a recognizable white deer: historical wolf-placeholder claims do not
    describe what I saw on this build.
26. **World composition - medium.** Repeated small houses/trees, flat terrain,
    blank Castle facades, dark/empty horizons, large floating state labels,
    capsule-like ritual props and bright rectangular arena edges remain visible.
    Improve the composition of the played route, not every incidental prop.
    Record Hall has usable lighting and an authored room once its camera is fixed;
    distinguish that from places that are genuinely sparse.
27. **Menu-to-game visual promise - medium.** The photographic village backdrop
    promises a much denser world than the stylized gameplay. Use cohesive art
    direction across menu, journal and game. Do not silently replace preferred
    characters with another rejected family to match the photograph.

### Working Features Worth Preserving

- This New Game reached a complete Greyfen rather than the previously reported
  empty landscape. That does not establish startup reliability across devices.
- Greyfen and Wychwood bridges crossed in ordinary directions without jumping or
  wrong-bank recovery in this journey.
- The water favor is acknowledged by Anwen; Bracken can be rescued and follow.
- Clues, public reporting/privacy decisions, chapter advances, register assembly,
  grain/testimony choices and the Witness ritual all produced visible progress.
- The five opening enemies activated sequentially after recovery; normal attacks
  killed them. This is not proof of five simultaneous enemies working together.
- Moon Oil purchase/application, crafting, coin deduction and healing potions
  worked. The preparation-objective mismatch is separate from transaction failure.
- Bog Wretch and Ashwing were defeated through actual combat. Ashwing phase
  checkpoints retained earned damage; two bandit guards and the haunting died.
- Halvern accepts the copied order as a peaceful route and retains refusal as
  testimony. Avoid requiring a fight where the story already supports a solution.
- The Hart's Witness choice requires enacted promises rather than only a menu
  selection; all three actions worked and the covenant completion screen appeared.
- Day/night changes, several ordinary sector crossings, physical Castle doors,
  dialogue continuation and normal earned-save recovery demonstrably function.

### Story and Emotion

The best material connects personal grief with institutions: Elna's shoes, Bram's
ledger, Sella's thread, Oren's erased identity, grain used to compel consent,
Halvern's refusal and Kael's admission that his report omitted his retreat. Privacy
versus public accountability is a real decision rather than a cosmetic good/evil
button. The water favor and Bracken build affection on a smaller scale.

I would deepen these existing relationships through consistent faces, short
reaction performances and specific persistent village responses. I would not add
more quest systems before the current consequences survive travel and recovery.
Repeated explanatory conversations and invisible/off-screen speakers undermine
otherwise effective writing. The witness ending needs an equally credible lived
aftermath, not renewed hostility from an already-resolved cemetery event.

### Coverage Limits

- Only Witness was chosen. Mercy, Duty and Ash were visible alternatives, not
  completed routes. Ash was below the dialogue fold; it was not proven unavailable.
- Rootbound was encountered, not defeated. Not every side quest, optional worker
  rescue, optional clue or full NPC schedule was completed. The Anwen return-home
  epilogue remains incomplete after the post-ending Bell-Eater death.
- No fresh repeat playthrough, alternate-save matrix, browser suite, benchmark,
  iPhone/Safari/touch test or physical-controller certification was run.
- I cannot assess how the mix/voices actually sound from screenshot and console
  tools. Footstep listening/synchronization and voice quality remain unreviewed.
- Bow release with the proper sustained aim sequence, arrow retrieval, all ammo
  types and Oathfire hit damage were not established. No invented pass/fail.
- Escape/pointer-lock behavior was unreliable in the in-app browser. Captured
  errors include WrongDocumentError and repeated Chromium UnknownError messages.
  They require separation from game input before claiming a universal pause or
  mouse failure. No zero-error-browser claim is made.
- Preparation logs show 18,392ms prewarm and 173.8ms click-to-ready afterward.
  Neither is a measured cold page-load-to-control result; no new FPS, memory or
  loading-budget compliance claim is made.
- Source diagnosis supports several observed bugs, but code presence never
  substitutes for having played an unvisited choice or proving a proposed fix.

## Evidence Index

All paths below are under `D:/Temp/AshenOath/Playthrough_20261009/`.

- 01-dialogue-character-occlusion.png: privacy-screen speaker/equipment occlusion.
- 02-wychwood-night-arrival.png: actual forest arrival and nighttime presentation.
- 03-first-encounter.png: opening combat state.
- 04-camera-view-obscured.png: obstructed gameplay camera.
- 05-foliage-camera-obstruction.png: another obstruction; filename is not proof
  that foliage alone owns the defect.
- 06-death-menu-actions-below-fold.png: recovery actions at narrow viewport.
- 07-restored-route-no-active-pack.png: earned checkpoint with dormant encounter.
- 08-boss-obscures-shrine-dialogue.png: hostile boss over peaceful-choice dialogue.
- 09-kael-clear-dialogue-face.png: the preferred character can be readable when framed.
- 10-ashwing-defeated-mill-aftermath.png: earned drake defeat and mill state.
- 11-marsh-route-edge-recovery.png: ordinary marsh exit failure/recovery.
- 12-castle-signed-road-blocked.png: misleading signed Castle approach.
- 13-finale-dialogue-inside-hart.png: final camera inside actor geometry.
- 14-witness-covenant-complete.png: genuine main covenant completion.
- 15-road-home-contradictory-guidance.png: tracker/contextual route disagreement.
- browser-warnings-errors.json: captured late-session browser error entries.

## Recommended Order

Repair earned-state recovery and peaceful boss retirement first; then required
route joins and camera framing; then objective/focus/mobile layout; then character
continuity and scene composition. Finish with matched story performances and an
actual listening review. This is a prioritized report, not a new recovery program
or authorization to make those changes.
