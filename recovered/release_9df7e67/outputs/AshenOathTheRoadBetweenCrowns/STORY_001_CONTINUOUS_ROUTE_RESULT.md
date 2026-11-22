# STORY-001 Continuous Route Checkpoint

2026-09-28. Partial native evidence only. Formal recovery remains 27/37.

## Current Source-Aligned Story Checks

`native_v13.log` has a clean owned exit 0 for uninterrupted graphical New Game
through ten main chapters and the Mercy ending. It predates the narrowly
scoped optional-clue correction below and remains characterization of the
exercised default route, not a current-source final campaign gate.

`tools/verify_story_clue_orders.gd` exits 0 over 120 clue orders after the
three-clue combat threshold plus one all-five-before-combat order. It found and
now rejects former post-fight drag-marks ghost credit. The all-evidence
safe-edge hint appears only while the pack remains undefeated.
`optional_clues_v3.log` is a clean owned graphical exit 0 from a byte-copy of
the genuine post-fight Wychwood save: normal Continue, movement, focus and E
inspect drag marks without crediting Oren, then physically cross and inspect
Oren for the five-clue reward. The first approach stopped where the post-fight
token won focus; the corrected west layby uses unchanged focus rules.
The later `optional_clues_v4.log` exits 0 on the same current game source and
original source save, then physically returns to Greyfen, reports to Anwen,
starts Bell Beneath Greyfen and manually saves the retained all-evidence flag.

`request_refuse_v1.log` exits 0 after physical Greyfen request-board focus,
E, Escape and normal Save retain Bitter Roots availability. A separate normal
Continue from that saved refusal, visible Bitter Roots selection and Save pass
in `request_accept_v2.log`. The first acceptance attempt drifted beyond the
board's range after transient focus; the driver now settles near its actual
position. Failed attempts remain evidence, not passes. All logs and original
save/hash guards are under `D:/Temp/AshenOath/story_continuous_20260928`.

STORY-001 stays pending for complete campaign/side/choice acceptance on final
current source, plus production-browser proof. Cold load and FPS targets remain
red. No Web export, commit, push, merge or deployment is claimed.

## Completed Evidence

- `native.log`: clean New Game, Anwen, clues and five-enemy fight; fails return
  because the input driver assumes a north bearing after combat lock-on.
- `return.log`: owned exit 0 from a byte-identical genuine post-fight autosave.
  Real camera turn, Continue, physical Wychwood/Greyfen bridge, Anwen report and
  keyboard Pause/Save pass. No gameplay/collision rule was changed.
- `native_v2.log`: fresh New Game passes that corrected return and continues
  through Anwen relocation, two graves, ambush, chapel and shrine cleansing.
  Its south exit stops against a legitimate bell-frame post, not bad physics.

Full logs, isolated saves and source identities are under
`D:\Temp\AshenOath\story_continuous_20260928`. Original saves are preserved.

## Source-Backed Next Connector

The bell post is centred at `(15.15,1.18,9.68)`, size `(0.18,2.36,0.18)`.
The chapel's split west facade provides the clear exit at `z=8.29`. The input
driver must leave west before moving south, preserving the scenery collision.
The Bell-Eater is still alive: shrine cleansing does not resolve it, and its
definition explicitly disallows a peaceful outcome. A scoped genuine-save
real-input fight/exit proof now passes before another continuous run.

The first focused run (`bell_v1.log`, exit1) exposed a genuine restoration bug:
after shrine choice completed the quest, normal Continue omitted an opened,
undefeated Bell-Eater. `game.gd` now checks the opened encounter independently
of quest-active state, retaining the existing resolved/dead guards. The fix
does not alter quest choices, health, population budgets or collision.

`bell_v2.log` exits0 cleanly: normal Continue restores the encounter, real
lock-on/Oathfire/melee reaches phase3 defeat, both reward flags and silent-bell
aftermath are granted, doorway exit and normal Save pass. `bell_reload.log`
exits0 after a second normal Continue/Save preserves defeated checkpoint3 and
all reward/aftermath flags without respawning the boss. Original genuine saves
and source-hash manifests are retained unchanged. Registry nine tests pass.

The next uninterrupted run (`native_v3.log`, exit1) completes the Bell-Eater,
Mira briefing and chapel names, then meets its surviving called Ghoulkin on the
return lane. The owner is the phase3 `ghoulkin_call` spawn, not scenery. The
input driver now finishes that summoned enemy through actual combat; it does
not erase or disable it. `bell_v3.log` exits0 with one summon defeated, boss
phase3 rewards/aftermath intact, doorway exit and normal Save. Another fresh
uninterrupted run is `native_v4`, with the prior failures preserved.

`native_v4.log` (exit1) finishes the boss and summoned enemy but stops at a
west gate cap because the previous exit only bounded maximum x; combat left
Kael at x10.3. The driver now settles bidirectionally at the source-cleared
`x13.2,z8.29` aisle before turning south. `exit_sweep.log` exits0 from four
physically reached starting positions (x8.9/10.3/13.3/15.7), including inside
the chapel. It uses real keys, no jumping or teleporting, preserves all world
collision, and retains defeated checkpoint3/rewards through normal Save.
The next uninterrupted source-frozen run is `native_v5`.

`native_v5.log` fails in the five-enemy fight before a kill. The driver selected
an array-first actor while real lock-on could select another visible actor.
`combat_v1.log` shows actual-lock selection alone is insufficient. Source then
identifies camera-heading chase lag plus the driver holding W on every attack
edge: normal movement-facing intentionally overrides stationary lock-facing.
The next focused candidate uses real WASD vector steering toward the actual
lock, then neutral-input strikes. Progress checks use total remaining pack
health, so switching targets cannot conceal a stall. Original 150s encounter
and 25s no-damage limits, damage, collision and population remain unchanged.
`combat_v2` still fails because six-frame movement pulses release keys each
iteration, applying braking before chase velocity converges. A single batched
read-only probe tested the structural alternative: retain movement between
approach updates, release it before neutral lock-facing attacks.
`combat_hold_observe.log` exits0 after actual New Game, five kills, bridge
return, report and normal Save. Its132 samples/42 blade samples record20 attack
IDs and14 geometrically eligible contacts. No population, collision, damage or
deadline change. The answered temporary probe was removed; raw evidence and
source identity remain. This is scoped route proof, not a performance benchmark.

The uninstrumented continuation now uses deadline-latched12s crossing predicates;
cleanup frames cannot upgrade a late success. Rootbound potion checks compare
actual requests with carried inventory rather than assuming three unused
potions, and explicitly report an unexercised heal when none is requested.
Parser validation of the complete continuous hierarchy exits0 cleanly.
Exact next run is fresh source-frozen `native_v6`, without diagnostic sampling.

`native_v6` exits1 cleanly before a kill: the driver stops at1.38m and repeatedly
strikes without damage. The scoped probe pass did not establish repeatability.
Offline replay of its42 actual measured blade sweeps at controlled target
separations distinguishes the remaining approach-radius assumption:0/42 contacts
eligible at1.5m,1/42 at1.38m,20/42 at1.1m,21/42 at0.95m. This is mathematical
diagnostic evidence, not a new gameplay pass. The driver now approaches to1.1m,
leaving actual contact geometry/damage unchanged. Exact next action: focused
uninstrumented `combat_contact_v3` first chapter; no full rerun until green.

`combat_contact_v3` exits0 cleanly and source-frozen without diagnostic sampling:
actual New Game, all five kills, physical bridge return, Anwen report and normal
Save. Kael retains112HP; actors, damage and all original deadlines are unchanged.
The approach-distance driver fix is retained. Exact next action fresh native_v7
with new-game-v7, uninterrupted through the remaining chapters/ending.

`native_v7` passes the corrected first chapter, cemetery, Bell-Eater/summon,
Mira and ritual-name interaction, then its straight east leg contacts the actual
RitualStoneCollision at(8.5,0.8,-11.6), size(0.6,1.6,0.35). The pillar is valid
world geometry; the driver must depart south toz>-10.5 before turning east.
The same shared chapter connector is now used by full and scoped tests.
`ritual_v1` exits0 after normal Continue from the byte-identical v7 Wychwood
arrival autosave, physical bridge, ritual E, clear south/east departure, Deep
Wood travel, Ash Bomb weakness, actual Bog Wretch defeat, memory-core choice
and manual Save. Its source hashes and immutable original-save hash pass.
No pillar/route/gameplay removal, jump, teleport or deadline change. Exact next
action fresh source-frozen native_v8/new-game-v8 uninterrupted campaign.

`native_v8` completes all five kills and shrine choice, then the chasing
Bell-Eater physically occupies the fixed doorway waypoint. Its actual body
is the collision owner at(12.54113,1.799482,8.386395), with Kael atx13.71846.
The driver now finds the living target before approaching and treats reachable
1.7m engagement range as arrival instead of requiring passage through its body.
Original5s route/90s fight/25s progress bounds remain. Exact next proof is
bell_occupied_v4 from the untouched genuine v8 shrine autosave, not a fabricated
actor layout. Full New Game campaign remains unaccepted.

`bell_occupied_v4` exits0 source-frozen from that exact genuine v8 shrine save:
normal Continue, bounded combat approach, three-phase fight, called-Ghoulkin
defeat, rewards/aftermath, doorway/aisle exit and manual Save. The original save
hash is unchanged and shutdown is clean. This is scoped connector evidence,
not a claim that the previous uninterrupted run passed. Next fresh native_v9
uses both proven connectors, with new-game-v9 and the original route deadlines.

`native_v9` passes the boss/summon but the fixed-axis settling controller
oscillates after combat ends atx7.44414. One complete frame trajectory from
that untouched actual save distinguishes this from frame stalls/collision:
exit_timing_v2 records292 samples/149 physics ticks in4976ms, maximum frame
gap44ms, correct held input/control and floor-only contacts. It reachesx13.167
at3.4m/s, brakes too late, overshoots to13.542, reverses and repeats. Initial
exit_timing_v1 exercised only Continue/Save, not departure; it is not evidence
for this question. V2's additional save failures cascade from the timed-out
departure; no actual save was lost.

One shared velocity-aware braking controller replaces bang-bang alignment on
both axes. Position tolerance0.08m, velocity<0.2m/s, three settled ticks and4s
deadline remain exact. Logic-only verification settles15 start/velocity cases,
including one input-boundary delay. Uninstrumented exit_braking_v3 exits0 from
the exact genuine failed-position save: Continue, entrance, aisle, south exit
and manual Save preserving phase3/rewards. Source/original hashes unchanged,
shutdown clean. Answered observer removed; raw trajectory retained. Next fresh
source-frozen native_v10/new-game-v10, not a Web rebuild or acceptance claim.

The continuous orchestration uses existing physical chapter legs and actual
carried inventory. Tor's supply checks retain the exact emergency/purchase
rules while respecting carried arrows rather than inventing an empty quiver.
No campaign flags, damage, positions or interaction handlers are mutated.

## Remaining

`native_v13/new-game-v13` is the first clean owned graphical native exit0 for
one uninterrupted New Game through all ten main chapters to Mercy. The real
input path traverses Wychwood, cemetery, Deep Woods, register/mill/farmstead,
Rootbound, Ashwing, Senn, Castle, Record Hall, Halvern, assembly and Hart Glade.
It retains eleven actual choices, five-enemy victory, boss outcomes, vendor
arrows, manual/autosave checkpoints and five ending cards. Source hashes stayed
fixed. Native stderr has zero active errors/leaks and two declared diagnostic
bandit-role fallback warnings. This proves the native default main route only;
no cold/FPS/browser, complete clue/refusal matrix, side-quest combination or
visual approval follows. Formal STORY ticket remains pending.

`native_v12` physically plays New Game through all ten main chapters to the
Mercy ending, with eleven carried choices preserved, visible ending cards and
normal final checkpoint. It exits1 only after those assertions: the additional
top-level route verifier reads nonexistent `hart_covenant`. The actual final
dialogue contract uses `final_covenant`; native_v12's genuine checkpoint shows
Hart quest completed, final_covenant=mercy, final_choice_completed=true and
ending=free. The top-level assertion now checks all four authored conditions,
without relaxing the original test. V12 remains failed evidence, not a pass.
Next: fresh source-frozen native_v13/new-game-v13 for one owned clean result.
Diagnostic bandit-role warnings remain separate asset/release blockers.

`castle_remainder_v3` renders the actual Edric decision, undercroft/Halvern,
assembly testimony and Mercy ending, with all eleven carried choices retained
and clean native stderr. Its wrapper exits1 after child completion: PowerShell
case-insensitive `$entry` collides with the validated `$Entry` parameter during
postflight. Fixed to `$sourceEntry`; offline23source/original-save hashes match.
The native child exit was not recorded, so this remains wrapper-failed partial
route evidence, not an owned exit0 acceptance. Do not invent a child exit code
or rerun every older scoped leg. The next fresh uninterrupted native_v12 run
uses the corrected source hierarchy and original unchanged route deadlines.

`remainder_v1` failed alignment because its selected save was already at the
bridge; that fixture did not match the chapel-departure entry contract. It is
preserved as failed harness evidence, not a gameplay regression. The wrapper
now checks the actual saved entry position without modifying it.
`remainder_v2` starts at the genuine v11 chapel autosave and passes Teeth/Bog,
register/Rootbound/names, Tor supply, mill/Ashwing, Senn, Castle ledger and
haunting/manual Save. It fails Edric focus: the transient approach predicate
ends atx3.552,z-10.886; sprint cleanup drifts toz-11.097 and selects the gate.
Source places Edric at(0,0,-10.5), undercroft gate at(6,0,-13). The test now
walks the unobstructed north aisle tox<1.5 inside the original6s limit before
ordinary focus/E; no interaction range or priority change.
`castle_remainder_v3` starts through Continue from that actual haunting manual
save, then uses the same shared Castle legs through Mercy. In progress. No
New Game/full STORY/FPS/browser acceptance. V2 also reports two explicit
diagnostic bandit-role fallback warnings; those remain asset/release blockers,
not render failures or accepted final-role evidence.

`native_v11` passes opening/Bell/summon but its post-exit horizontal lane
contacts actual batched rubble at(11.41024,0.16,10.8937), size
(0.896232,0.402484,0.489276). Source confirms a west gate gap centred onz8.29;
the inner south lane contains graves/rubble and is not the exit. Shared driver
now crosses west tox<9.4 before turning south, retaining all scene collisions.
`exit_west_gate_v4` passes normal Continue from the actual v11 resolved save,
the complete departure/bridge-centreline/Save, with clean exit0 and original
save/source hashes unchanged. Individual deadlines unchanged.

The shared campaign leg runner now supports a clearly labelled resumed native
remainder starting at that actual normal save. `remainder_v1` is in progress;
it cannot emit New Game acceptance. Validate the remaining chain here before
replaying the untouched opening in the required fresh uninterrupted run.

`native_v10` reaches Bell phase3 but its summoned Ghoulkin stalls at1.46m.
This is the already measured attack-range/approach driver error, not a new
world collider. The shared contact driver uses camera-basis held approach,
neutral strike input, and actual capsule radii plus0.06m clearance. Bell,
summons, mill, Senn guards, haunting, Black Dog and Bog/ambush helpers now use
that contract. Original fight/progress bounds, population and damage remain.
Logic-only reach4cases and continuous parser pass. Uninstrumented
`bell_shared_v5` exits0 from the genuine unchanged v8 shrine autosave through
boss phase3/rewards, actual summon defeat, doorway/aisle exit and manual Save;
source hashes stable and shutdown clean. This is scoped native evidence only.

The continuous leg list no longer duplicates mill clearing or Senn's choice:
`_inspect_ash_millstones` and `_fight_senn_guard` already execute and validate
those nested real-input steps. No interaction or acceptance assertion removed.
Next run is fresh source-frozen `native_v11/new-game-v11`.

Uninterrupted New Game through an ending, remaining route permutations,
browser proof, final visuals and strict performance remain unaccepted. No
export, commit, push or deployment. Historical scoped passes are not promoted
to complete campaign acceptance.

## Running

Scoped Bell proof (isolated D: profile; never overwrites existing evidence):

```powershell
pwsh -NoProfile -File D:\Temp\AshenOath\story_continuous_20260928\bell.ps1
```

After the scoped connector passes, use the source-aligned continuous wrapper
with a new evidence stem/profile, never reusing the prior failed runs:

```powershell
pwsh -NoProfile -File D:\Temp\AshenOath\story_continuous_20260928\run.ps1 `
  -EvidenceStem native_v13 -ProfileLeaf new-game-v13
```

The warm render cache does not prove cold startup, FPS or browser acceptance.
