# ASHEN OATH MASTER STUDIO REVIEW

## 1. Executive Summary

Ashen Oath is a promising pre-alpha prototype, not a commercial Alpha. It has unusual breadth for a small project: browser delivery, a complete controller/combat skeleton, quest and choice data, saving, day/night, multiple zones, a first encounter, and a persistent deployment pipeline. Its strongest idea is not its amount of content; it is the moral-investigation loop around Greyfen's buried crime.

The project became weaker whenever breadth was treated as completion. Later campaign zones are mostly procedural blockouts, character presentation is assembled from inconsistent low-poly sources and primitive overlays, audio is largely synthesized, and several tests accepted node presence instead of player-visible quality. The correct move is consolidation: build a polished 90-minute Web Act One, then expand to a 4-6 hour campaign only after its production method is proven.

## 2. Overall Score /100

- Current game quality: **31/100**.
- Commercial readiness: **12/100**.
- Potential after disciplined recovery: **68/100**.

The gap is production execution, not lack of ideas.

## 3. Biggest Strengths

- A clear dark-fantasy mystery about denied witnesses and inherited guilt.
- A useful hub-and-bounded-zone structure for a small team.
- Existing movement, combat, Oathfire, quests, dialogue, saving, interaction, and Web export foundations.
- A playable opening route with a real beginning, confrontation, and return loop.
- Story flags and bounded values that can support consequences without exponential branching.
- Browser delivery lowers friction for public playtesting.
- The project already contains enough legal assets to audition a coherent first slice.

## 4. Biggest Weaknesses

- One oversized runtime controller owns too many systems and most world construction.
- Visual breadth is mostly blockout breadth; later zones do not meet opening-slice standards.
- Characters and monsters lack a coherent, readable identity at gameplay distance.
- Quest data, dialogue actions, and world interactions have drifted apart.
- Release checks have accepted false positives and suppressed renderer diagnostics.
- Audio, dialogue performance, navigation, and combat contact remain prototype-grade.
- The project has no validated controller or mobile input layer.
- Production deployment occurred more frequently than genuine milestone acceptance.

## 5. Top 25 Improvements

Effort: S under 3 days, M 1-2 weeks, L 3-6 weeks, XL 2-4 months.

| # | Ticket | Player gain | Difficulty | Effort | Depends on | Priority |
|---|---|---|---:|---|---|---|
| 1 | PROD-001 Scope and release lock | Honest expectations and stable public builds | 3 | S | None | P0 |
| 2 | QA-001 Authoritative release gate | Broken builds stop shipping | 7 | M | PROD-001 | P0 |
| 3 | DATA-001 Content integrity | No dead dialogue choices or impossible objectives | 5 | M | QA-001 | P0 |
| 4 | ENGINE-001 Runtime composition boundary | Safer iteration and diagnosis | 8 | L | QA-001 | P0 |
| 5 | ART-001 Visual bible and asset audition | One recognizable visual language | 6 | M | PROD-001 | P0 |
| 6 | ASSET-001 Curated runtime library | Smaller payload and fewer broken imports | 6 | M | ART-001 | P0 |
| 7 | NAV-001 Navigation foundation | NPCs and enemies obey roads, bridges, and gates | 8 | L | ENGINE-001 | P0 |
| 8 | CHAR-001 Kael and Anwen identity | Immediate emotional and visual credibility | 8 | L | ART-001, ASSET-001 | P0 |
| 9 | ANIM-001 Shared animation contract | No sliding, T-poses, or detached equipment | 8 | L | CHAR-001 | P0 |
| 10 | WORLD-001 Authored Greyfen | A believable hub instead of box dressing | 9 | XL | ART-001, NAV-001 | P0 |
| 11 | WORLD-002 Authored Wychwood | Readable investigation and combat route | 8 | L | WORLD-001 | P0 |
| 12 | QUEST-001 Act One rewrite | A complete 90-minute story arc | 7 | L | DATA-001, WORLD-001 | P0 |
| 13 | COMBAT-001 Blade-contact combat | Sword, hit, parry, audio, and VFX agree | 8 | L | ANIM-001 | P0 |
| 14 | AI-001 Enemy navigation and roles | Threatening encounters without pileups | 8 | L | NAV-001, ANIM-001 | P0 |
| 15 | OATH-001 Oathfire reconstruction | Signature power feels authored and reliable | 7 | M | COMBAT-001 | P1 |
| 16 | UI-001 HUD and dialogue hierarchy | Clear objectives and less screen obstruction | 6 | M | QUEST-001 | P1 |
| 17 | AUDIO-001 Real first-slice audio | Place, combat, and dialogue gain weight | 6 | M | WORLD-002, COMBAT-001 | P1 |
| 18 | LIGHT-001 Authored lighting states | Readable day/night composition | 7 | M | WORLD-001 | P1 |
| 19 | SAVE-001 Migration and backups | Existing players do not lose progress | 7 | M | DATA-001 | P1 |
| 20 | PROG-001 Nine-upgrade progression | Compact build identity without grind | 6 | M | COMBAT-001 | P1 |
| 21 | WORLD-003 Cemetery and chapel | Strong Act One escalation and endpoint | 8 | L | WORLD-001, QUEST-001 | P1 |
| 22 | PERF-001 Enforced budgets | Stable browser play rather than launch-only success | 8 | L | ENGINE-001 | P0 |
| 23 | WEB-001 Public Act One | A release worth sharing | 7 | M | All Act One P0s | P0 |
| 24 | INPUT-001 Input abstraction | Keyboard, gamepad, and future touch coexist | 7 | M | ENGINE-001 | P2 |
| 25 | MOBILE-001 Mobile feasibility gate | Evidence before store fees and port scope | 8 | L | WEB-001, INPUT-001 | P2 |

## 6. Complete Ticket Backlog

Every ticket must include goal, player-facing problem, implementation scope, acceptance criteria, dependencies, risk, likely files, verification, screenshots when visible, and deployment disposition.

### Production and QA

- PROD-001 Scope and release lock.
- PROD-002 Issue registry and milestone dashboard.
- QA-001 Authoritative release gate.
- QA-002 Real-route browser automation and console capture.
- QA-003 Screenshot comparison and manual visual approval.
- QA-004 Save/choice permutation matrix.

### Engine and Data

- DATA-001 Quest/dialogue/runtime reference integrity.
- ENGINE-001 Runtime composition boundary.
- ENGINE-002 Zone-builder extraction.
- ENGINE-003 Resource lifecycle and cache policy.
- SAVE-001 Versioned migration, backups, and invalid-position recovery.
- NAV-001 NavigationServer routes and spatial reservations.

### Gameplay

- GAMEPLAY-001 First-hour loop and pacing.
- COMBAT-001 Blade-contact combat.
- COMBAT-002 Damage, stamina, difficulty, and low-FPS balance.
- OATH-001 Oathfire casting and impact.
- AI-001 Navigation, spacing, and attack roles.
- AI-002 Per-family behavior and perception.
- BOSS-001 White Hart encounter and noncombat resolution.
- PROG-001 Nine-upgrade progression.
- INV-001 Focused preparation and crafting.

### World and Art

- ART-001 Grounded-stylized visual bible.
- ASSET-001 Legal curated runtime library.
- MAT-001 Surface and material library.
- CHAR-001 Kael and Anwen.
- CHAR-002 Villagers, guards, and travelers.
- ANIM-001 Shared animation contract.
- MON-001 Ghoulkin and monster families.
- VFX-001 Combat, interaction, weather, and consequence effects.
- LIGHT-001 Authored time and interior lighting.
- WATER-001 River, banks, bridges, and spatial audio.
- WORLD-001 Greyfen.
- WORLD-002 Wychwood.
- WORLD-003 Cemetery and Crow Chapel.
- WORLD-004 Deep wood, marsh, mill, and farmstead.
- WORLD-005 Bandit road and Castle Vargan.
- WORLD-006 Undercroft and Hart Glade.

### Narrative

- QUEST-001 Act One consolidation.
- QUEST-002 Names in the Rain.
- QUEST-003 Ash and Banner.
- QUEST-004 Blood Under Stone.
- QUEST-005 The Hart Remembers.
- QUEST-006 Consequence and epilogue pass.
- SIDE-001 Five authored side quests.
- DIALOGUE-001 Conditional conversational rewrite.
- NARR-001 Environmental evidence and aftermath.

### Audio and UX

- AUDIO-001 First-slice ambience and combat.
- AUDIO-002 Campaign music and transitions.
- VOICE-001 Key-scene and bark production.
- UI-001 HUD, interaction, tracker, and dialogue.
- UI-002 Menus, journal, settings, and loading.
- ACCESS-001 Subtitles, focus, contrast, remapping, and reduced motion.

### Platform and Release

- PERF-001 Web budgets and profiling.
- PERF-002 Zone lifecycle and memory.
- PERF-003 Mobile budgets and thermal test.
- INPUT-001 Keyboard/mouse and gamepad abstraction.
- WEB-001 Act One candidate.
- WEB-002 Full campaign candidate.
- MOBILE-001 Android feasibility build.
- MOBILE-002 Android production package.
- MOBILE-003 iOS production package.
- STORE-001 Listing, privacy, ratings, screenshots, and compliance.
- RELEASE-001 Version 1.0 candidate.

## 7. Technical Debt

The highest debt is ownership concentration in `game.gd`, runtime-generated world art, direct manager construction, literal cross-file IDs, duplicate historical documentation, unbounded procedural helpers, and tests coupled to implementation names. The repair order is data contracts, composition boundaries, zone ownership, navigation, resource lifecycle, then performance budgets. A wholesale rewrite is not approved.

## 8. Performance

The latest measured 37.2 FPS average is encouraging but provisional because other release gates failed. Web Act One targets locked 30 FPS, 1% low at least 24, payload below 100 MB, browser memory below 450 MB, and transitions below 750 ms or hidden by a proper loading presentation. Mobile targets stable 30 FPS, package below 300 MB, memory below 700 MB, and a 20-minute thermal test on representative midrange 2020+ hardware.

## 9. Gameplay

Preserve the basic controller and combat foundation, but make investigation and consequence the core identity. Combat should be deliberate and readable: real blade traces, one shared contact event for damage/VFX/audio, clear parry timing, navigable enemy spacing, and a reconstructed Oathfire state machine. Progression uses three short branches rather than rarity tiers. Preparation changes encounters rather than adding inventory clutter.

## 10. World

Use Greyfen as a reactive hub and authored bounded zones for production control. Every zone needs a landmark, safe arrival, route silhouette, interaction composition, encounter pocket, return path, consequence state, and budget. No content marker may stand in for a quest sequence. River crossings use bridges and NavigationServer paths, not straight-line schedules.

## 11. Art Direction

The target is grounded stylized dark fantasy: believable scale and materials, restrained color, readable silhouettes, weathered surfaces, and authored lighting. Photorealism is not a practical target with the current asset and hardware constraints. Kael, Anwen, one villager, and one Ghoulkin form the visual quality gate before a full population pass. Primitive anatomy and overlay faces are temporary development fallbacks and cannot ship.

## 12. Audio

Procedural tones remain development diagnostics only. Production needs short, legal, compressed recordings for footsteps, weapon contact, monsters, river, forge, shrine, village, forest, and Castle interiors. Music must transition by authored state. Key scenes and barks may be voiced after human review; subtitles must always carry the scene.

## 13. UX

One tracked objective drives tracker, compass, prompt, and world focus. Dialogue should preserve the scene instead of covering it. Menus require reliable keyboard, mouse, and gamepad focus. Accessibility includes scalable subtitles, contrast, remapping, reduced motion, and unambiguous quality presets. Browser mouse/audio unlock behavior requires automated testing.

## 14. Risk

- **Scope risk:** greatest risk; controlled by the six-main/five-side lock.
- **Art cohesion risk:** free assets can clash; controlled by an audition gate and material bible.
- **Architecture risk:** extracting too much at once can break the game; use bounded migrations.
- **Performance risk:** WebGL and integrated graphics require measured budgets per zone.
- **Mobile risk:** no input, packaging, thermal, or device proof exists yet.
- **iOS risk:** Godot iOS export requires macOS and Xcode; Apple work waits for the required hardware and account.
- **Store risk:** fees, signing, privacy, content ratings, and current API requirements are not yet funded or configured.
- **IP risk:** inspiration may not become copying; original names, characters, dialogue, story expression, audio, and visual identity are mandatory.

## 15. Version 1.0 Roadmap

| Milestone | Outcome | Estimate |
|---|---|---:|
| Recovery / Preproduction | Scope, truthful QA, content integrity, visual audition | 4-6 weeks |
| Foundation Alpha | Architecture, navigation, characters, combat, budgets | 8-12 weeks |
| Act One Alpha | Authored Greyfen/Wychwood/cemetery and complete 90-minute route | 10-14 weeks |
| Public Web Act One | Browser hardening, accessibility, audio, release review | 4-6 weeks |
| Full Campaign Beta | Six main quests, five side quests, all authored zones | 6-9 months |
| Mobile Feasibility | Gamepad/touch, Android build, device and thermal proof | 4-8 weeks |
| Release Candidate | Full QA, store materials, compliance, final optimization | 8-12 weeks |
| Version 1.0 | Web plus approved mobile stores | Conditional |

Honest focused full-time-equivalent estimate: **14-20 months**. Part-time work will take longer. There is no paid Early Access plan; the free Web Act One is the proving ground.

## 16. Immediate Next 10 Exact Order

1. **PROD-001:** store the scope lock, label live as Prototype, and enforce milestone deployment.
2. **QA-001:** make one release runner emit a machine-readable pass/fail report and reject real errors.
3. **DATA-001:** validate every quest, objective, dialogue action, unlock, and literal runtime reference.
4. **ENGINE-001:** establish a runtime service boundary, then extract zone ownership incrementally.
5. **ART-001:** create one identical-camera Greyfen street, Kael, Anwen, and Ghoulkin visual audition.
6. **ASSET-001:** retain only legal assets that pass the audition; remove low-confidence mappings from runtime.
7. **CHAR-001:** replace Kael, Anwen, one villager, and one Ghoulkin as the character gate.
8. **NAV-001:** replace straight-line schedules with navigation routes, bridge anchors, and validated recovery.
9. **COMBAT-001:** unify blade traces, damage, parry, VFX, audio, and Oathfire contact events.
10. **WORLD-001:** rebuild Greyfen as the first authored production zone.

The current implementation tranche completes items 1-3 and begins item 4. Items 5-10 are sequential production tickets, not claims about the current prototype.
