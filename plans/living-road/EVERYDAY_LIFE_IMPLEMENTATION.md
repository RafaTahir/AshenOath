# Everyday Life, Lasting Consequences

## Delivery Contract

Continuation of the approved 24-feature RDR2 adaptation on
`codex/art-recovery-anwen`, from `6d14b36`. This record extends Living Road and
FINISH; it is not a new acceptance program. All six worlds, 57 quests, retained
character identities, choices, four endings and homecoming remain.

Source implementation and production packaging only. No agent game execution,
playthrough, browser QA, automated gameplay, screenshots or performance profiling.
User acceptance and performance compliance remain unverified. Publication is one
combined push to development and main; Vercel owns automatic deployment. No CLI
deployment and no waiting for Vercel are required by the current instruction.

## Implementation Ledger

The entries below describe source implementation, not observed gameplay.

| # | Addition | Existing owner and bounded behavior |
|---|---|---|
| 1 | Social intent | Existing dialogue offers greet, company, humor and work topics, with per-character replies and cooldowns. No repeatable relationship rewards. |
| 2 | Minor social repair | An apology clears recent crowding/weapon suspicion only after giving space and lowering weapons. Personal grievances remain authoritative. |
| 3 | Join exchanges | Capture the current finite exchange, invite Kael, resume remaining lines and record completion only after exposure. |
| 4 | Six relationships | Greyfen, Wychwood, Mill, Road, Castle and Ruins pair scenes follow retained earlier exchanges. Heard aftermath enables bounded afternoon shared work; absent participants are not manufactured. |
| 5 | Six reciprocal favors | Anwen, Mira, Tor, Nera, Nessa and Rook exchange an actual spare supply for a once-only keepsake and specific acknowledgement. No XP/Honor. |
| 6 | Source-bound rumors | Six region-specific accounts are recorded as testimony, with named sources. Existing completed investigations add findings without replacing the original claim. |
| 7 | Returning travelers | Rook, Nessa and Tor each have three finite encounters across their existing regional roles. Later lines require actual earlier exposure and applicable saved outcomes. |
| 8 | Three short outings | Mira's fallen stems, Rook's fastening and Nera's unloaded rope use existing navigation, safe separation, work poses and saved completed action. No teleport, leash or casualty timer. |
| 9 | Inspect possessions | Six permission-based, rotatable objects use a separate neutral object viewer. Closed/private contents remain closed; inspection does not transfer evidence or inventory. |
| 10 | Chosen reflections | Seven existing earned reflection entries permit a chosen personal note, uncertainty or leaving the page unwritten. No invented remorse or knowledge. |
| 11 | Three performances | Rook's short story, Tor's pin demonstration and a shared-table tune use the existing nonmodal scene owner. The tune reuses approved music, not fabricated speech. |
| 12 | Keepsake shelf | Six Greyfen slots display legitimately received gifts. Placement persists, prevents duplicate display and never consumes campaign evidence. |
| 13 | Weather routines | Existing day/night time derives clear/rain/clearing intervals. Actors use covered points from their own routes when available; no new clock or teleporting. |
| 14 | Visible travel wear | Private, removable overlays show wetness and lower-body dirt without modifying character texture bindings, combat effects or stats. Cleaning and active-time drying are cosmetic. |
| 15 | Ambient ecology | Existing ecology actors retain their population and animation owner, with near-player attentive behavior and bounded species-specific pose work. |
| 16 | Earned field observations | Viewing behavior for a short uninterrupted interval records an observation. Pressing Use alone does not grant a new field account; existing records remain. |
| 17 | Physical trails | Six three-mark trails are visible, inspectable in any order and recorded as optional observation. No detective overlay or sole-source campaign proof. |
| 18 | Safe time passing | Existing rest places support morning/evening waits. Movement/danger interrupts, time changes only at completion, and no free health/stamina refill is added. |
| 19 | Sound distraction | A single carried loose stone uses existing ballistics and perception. It does no damage; confirmed targets, bosses and committed attacks are not diverted. Saved active-time cooldown prevents reload spam. |
| 20 | Ordinary surrender | Whitelisted Wychwood ordinary bandits may offer surrender after a low-health stagger. Acceptance is separate from death, preserves once-only encounter XP and never resolves a boss or kill-required encounter. |
| 21 | Fishing | Three authored banks, a borrowed rod, two fish, float timing, line tension and cancellation. Combined fresh-fish capacity is six. No quest/Honor grant. |
| 22 | Resting meals | Three recipes consume real supplies at kitchens. Safe seated eating restores only listed missing health/stamina, once; no buffs, hunger, revival or combat eating. |
| 23 | Shop displays | Tor, Mira and Nessa's physical displays use existing unlocked stock definitions and existing shop transactions. Representative goods are not fictitious finite inventory. |
| 24 | Six regional meets | Three rounds of existing Three Marks, draughts, chess or physical archery. Increasing difficulty, saved board/range progress, two coin for first completion and two for first series victory. Ordinary prizes suppressed; rematches cannot duplicate rewards. |

## Ownership and Compatibility

- `StoryActivities/EverydayLife` coordinates optional presentation within the
  existing zone lifecycle. QuestManager, StoryState, Inventory, VendorService,
  DayNight, Presence, the animation driver and MinigameManager retain authority.
- New StoryState flags use `everyday_*`, `regional_meet:*`, `regional_range:*`
  and `ordinary_surrender:*` namespaces. Missing legacy fields start unearned.
- Fish buyback is one coin/common and two/uncommon, at most three combined per
  allowance. Refill requires both a later game day and 2,160 unpaused active-play
  seconds. Waiting, offline time, menus and loading do not replenish it.
- The global clock saves active-play time; vendor state saves its quota. Inventory
  transactions commit all consumption/recovery before emitting change signals.
- Optional scenes retain the existing finite scene-progress and knowledge rules.
  Rumor, trail, keepsake and ecology records are not new quest rewards.
- Ten original Blender props are separately exported into `leisure`; existing
  opening/campaign asset ownership is retained. No new full-resolution textures.
- Weather uses one nearby 40-instance rain batch and staggered roof probes.
  Wear updates one actor per half second and never replaces a foreign overlay.
  These are implementation budgets, not evidence of a measured performance gain.

## Build and Acceptance Record

- Blender source/export completed; an initial duplicate-fin-face warning was
  corrected in geometry and the build repeated without that warning.
- First Godot compilation found type/scope errors in new scripts. Corrected
  compiler-only retries passed. No game was launched to check the repairs.
- Production compilation/export: complete, build `everyday-life-20261106`.
  The two final script corrections were compiled and their base/root packs
  refreshed; unchanged actor/environment packs retain their checked identities.
- Isolated packed-resource inspection passed for 33 compiled actor scenes,
  with 32 intentionally omitted raw source scenes; no gameplay was executed.
- Exact local Web package integrity passed: 51 manifest-listed artifacts plus
  the release manifest, **205,967,595 bytes total (196.43 MiB)**. No budget warning;
  below 268,435,456 bytes. Largest deployed file: opening.pck, 69,633,840 bytes.
- Root transport SHA-256:
  `dad35df8f1f79d56f5c3d02f353ac42dcdf5c471d8ce0743f7f04e68ea1556ba`.
- Leisure pack: 268,126 transport bytes / 415,404 decoded bytes; optional,
  excluded from opening requirements. Total decoded artifacts: 254,018,407 bytes,
  **not process memory**.
- Balanced/Potato required download set: **122,114,174 bytes**, versus
  122,026,924 before: **+87,250 bytes (85.2 KiB)** of code/metadata/generated
  resource overhead. Initial-download neutrality was not achieved. The transfer
  floor at 20 Mbps is approximately 48.85 seconds before computation; this is
  arithmetic, not a measured startup result or performance pass.
- Local build helper metadata finalization initially failed after successful
  artifact generation; corrected the metadata/copy step without rebuilding again.
- Publication: candidate ready for the single combined development/main push.
  Do not infer successful Vercel deployment from this local build record.
- User observations: none for this candidate. No FINISH acceptance increment.
- Historical runtime failures and strict reference-PC targets remain unchanged.

## Startup Repair After Publication

The user reported repeated "Journey services could not be prepared" failures
after `cbef4e6` was pushed to development and main. A compiler-only invocation
reproduced a parse error in `combat_manager.gd`: the type of `previous`, obtained
through the dynamic zone-root property, could not be inferred. That prevented
the required combat service from loading. Retry alone could not repair code.
The earlier packaging pass did not explicitly compile every demand-loaded
service; its successful export was not proof that those services could load.

- Explicitly type the affected node. The compiler now accepts all 24 required
  registry services, without instantiating them or starting a journey.
- The existing release builder now runs registry-driven service compilation
  before exporting. This is a compiler gate, not a new gameplay test framework.
- Preserve valid services on Retry; replace only a failed script-cache entry.
  Report the affected service/resource in diagnostics and the loading error.
- Show the existing full-screen artwork/progress view during startup and quality
  re-preparation. Main-menu controls are not created until Greyfen, its gameplay
  camera render and the current save summaries are ready. Only explicit New Game
  or Continue starts play; readiness itself never starts a journey.
- Permit opening construction while this loading view owns the UI. Move the
  usable-menu timing event to actual readiness, retaining a separate loading-view
  timestamp. Percentages are phase-specific; unknown work is indeterminate.
- Reuse the Greyfen image and four chapter illustrations, changing roughly every
  eight seconds during resource/world preparation. Reduced motion removes fades.
  Move the existing atlas from campaign to the root pack, with no duplicate pack
  owner. Engine download still begins with the immediate Greyfen artwork.
- Retry remains the only loading-failure action. Long errors scroll independently
  so the Retry control stays reachable; repeated activation is guarded.

Candidate identity: `startup-loading-repair-20261106`. Export and package integrity
completed: **203,567,658 bytes total (194.14 MiB)**, no budget warnings. Root
transport SHA-256: `c8cf2d06e39ac109ebdf240ec163666b67559608be235cbb34250d1caac0c7d4`.
The Balanced initial dependency set is 122,117,577 bytes, +3,403 bytes versus the
preceding candidate. Exact identities belong to `web/release_manifest.json`.
Artwork is now explicitly available at boot; this repair makes no loading-speed
or performance-improvement claim. Character,
audio, material and leisure assets are unchanged. Saves and preferences are not
reset or migrated. No game/browser execution, screenshots or benchmarks were run.

User checks after Vercel receives the new push: reload; confirm artwork/progress
without menu buttons; wait for the menu; start New Game and selected Continue;
check quality re-preparation, short-screen Retry and reduced-motion behavior.
Runtime acceptance remains pending. A successful Git push is not a live browser
verification, and Vercel is not manually deployed or awaited.

## Consolidated User Checklist

1. New Game/selected Continue, quality changes and regional returns: existing
   people, quests, materials and controls remain intact; optional downloads Retry.
2. Greet, apologize, join an exchange and follow an outing; interrupt by walking
   away, talking, danger, pause and reload. No repeated rewards or lost quest Use.
3. Discover the pair/traveler scenes in different orders; absent or departed
   participants must not speak. Check later shared work and private grievances.
4. Trade a favor, inspect an object, arrange all six shelf slots and Continue.
   Closed letters stay closed, gifts persist and evidence is not consumed.
5. Watch creatures, follow trails out of order, wait morning/evening and shelter
   during rain. Check observations, cosmetic wear and cleaning without stat changes.
6. Throw a stone near an idle ordinary enemy and during real pursuit; try accepting
   and declining surrender. Check kill facts, encounter XP, return and Continue.
7. Fish at each bank, miss a bite, ease/reel, cancel, fill the six-fish capacity and
   reload. Cook/eat all three meals; interrupt before completion and verify supplies.
8. Sell three fish to Nessa; repeated waiting/reload must not replenish quota.
   Confirm later-day plus active-play refill and unchanged ordinary shop transactions.
9. Complete/rematch each three-round meet; interrupt boards and archery. Check
   opponent availability, equipment/ammo restoration and strictly once-only prizes.
10. Check actual-phone layout/input, audio/focus recovery, all existing campaign
    outcomes and retained reference-PC performance separately. No FPS claim is made.
