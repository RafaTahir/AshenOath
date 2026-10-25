# FINISH-004 - Complete Combat Toolkit

## Current Implementation Delivery - 2026-10-26

Candidate: `finish-implementation-20261026`, continued from published r14
(`4b28d2d`) on the canonical D: development branch.

Retained existing sword/guard/parry/bow/Oathfire contact and balance. Cancelled arena/surrender strikes release the externally driven animation schedule and attack reservation; damage and phase rules are unchanged.

Source implementation/reconciliation: complete for this build-only delivery.
Compilation/package/publication: recorded centrally in
[FINISH-000](FINISH-000.md) and the current FINISH-016 publication receipt.
Agent runtime verification: NOT RUN; user acceptance: PENDING.
No historical failure or unplayed case is promoted to passed. The approved
build-and-publish boundary supersedes old intermediate approval/publication holds
below; original runtime/performance contracts remain for the user's acceptance.

## Preserved Contract And Historical Evidence


Latest repair - 2026-10-20: a31 consumed 15 real arrows without damaging
Rootbound. Its visual bounds centre is displaced behind the existing damage
capsule; the old locked-aim ray misses that capsule from the observed east-side
position. The player now aims at the existing capsule centre and recomputes the
direction from the post-turn arrow origin. Camera framing, collision dimensions,
damage, ammunition and other controls are preserved. Targeted native proof
reproduced the old miss and passed three new directions with exactly 84 total
damage (three 28-damage arrows), clean exit. Log:
D:/Temp/AshenOath/finish-004-locked-bow-20261020/native.log.
Replacement bow-lock production package compiled below the cap. a32 passed actual
locked bow/Oathfire combat and defeated Rootbound in 19,015 ms after protecting
the name-board and redirecting two roots. No damage/ammo supply was fabricated.
The later unaffordable shop-quota failure is HARNESS, not renewed combat failure.
The driver uses the authored arena/root interactions and real
ability/sword options; this does not supply ammunition or waive a game defect.

Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-002, FINISH-003.
Implementation: existing sword/bow/Oathfire/encounter systems present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

Every existing combat tool can be understood, performed and recovered from using
normal input, with readable contact and no broken encounter lifecycle.

## Existing Owners And Evidence

Use the existing player, combat/feedback/VFX, equipment, enemy AI and boss encounter
owners. [PLAYFIX toolkit scope](../../outputs/AshenOathTheRoadBetweenCrowns/PLAYTHROUGH_REPAIRS_STATUS.md),
[combat contract](../../outputs/AshenOathTheRoadBetweenCrowns/COMBAT_001_RESULT.md)
and [Oathfire contract](../../outputs/AshenOathTheRoadBetweenCrowns/OATH_001_RESULT.md)
provide retained implementation, not acceptance of this whole candidate.

## Remaining Conditions And Bounded Repair

- Real attack clicks, draw/sheath and interruption leave equipment at its retained
  sockets with no duplicate blade, stuck guard or unusable weapon.
- Light/heavy contact, reach, damage, guard break, parry, stagger and recovery
  align with readable poses, impact and existing stamina rules.
- Bow aim/draw/release/cancel consume and recover ammunition according to existing
  rules. A prompt describes the actual requirement; do not invent retrieval bugs.
- Oathfire charge/release/cancellation preserves initial-facing lock, clipped
  endpoint, correct damage/audio timing and redraw/cleanup.
- Enemy windups/counterplay remain readable; dialogue and pause suspend relevant
  combat. Defeated encounters retire attack/summon owners and do not attack on return.
- Death/checkpoint behavior uses FINISH-002. Individual boss phases, peaceful
  resolutions and rewards are checked in their regional tickets.
- Repair a demonstrated functional defect before tuning. No wholesale rebalance,
  new combat system or removed enemies to make testing easier.

## User Manual Checklist

1. Use real mouse attacks in a normal encounter; draw/sheath, light/heavy,
   guard/parry and dodge, checking contact, costs and recovery.
2. Aim, partially/fully draw, cancel and fire the bow; inspect ammunition and hits.
3. Charge/release Oathfire toward an enemy and obstruction, then cancel a charge;
   check facing, damage, sound and weapon restoration.
4. Pause/resume during combat, open legitimate blocking dialogue where available,
   die/Continue and revisit a defeated encounter.
5. Credit boss-specific observations from FINISH-007 through FINISH-012 here.

## Delivery Record

2026-10-20 verification 1/1: native graphical real-input weapon-context session.
Keyboard bow selection, aim and one actual arrow request/ammunition consumption
were observed. Failed assertions: arrow selection also zoomed the camera; two
weapon-cycle assertions sampled immediately at release and expected the retired
two-weapon cycle. No fabricated enemies/quest progress supplied route acceptance.
Log: D:/Temp/AshenOath/finish-004-20261020/stdout.log.
GAME correction: arrow selection retains priority over shared zoom independently
of last-reported device; analog action strength respects the existing suppressed
handoff frame, matching the discrete action snapshot. HARNESS correction: wait for
authored equipment transfers and expect Steel -> Oathblade -> Bow. No equipment
timing, damage or stamina rebalance. The session is not rerun. Full encounter
contact/parry/Oathfire/death coverage remains Pending; synthetic pad input does
not certify physical hardware. A teardown ObjectDB warning was recorded, not waived.
Agent result: failures repaired, affected runtime corrections unverified.
User acceptance: Pending.

