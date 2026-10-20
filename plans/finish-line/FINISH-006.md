# FINISH-006 - Progression And Economy

2026-10-20 shared agent observations: a26 actually crafted a Redroot Potion from
two redroot and one bitterleaf. a28 focused Mira's existing shop with normal
camera/input, bought two remedies for 12 earned coin (15 -> 3), and used one
through the normal quick action (health 24.8704 -> 69.8704, potions 3 -> 2).
These close the representative craft/purchase/consumption cells, not the entire
progression/economy ticket. Source-aligned technical progression/oil contracts
remain independently recorded; user verdict and unobserved conditions stay pending.
Reports: D:/Temp/AshenOath/finish-targeted-20261020-a26-wychwood/browser.json and
D:/Temp/AshenOath/finish-targeted-20261020-a28-wychwood/browser.json.

Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-002, FINISH-004.
Implementation: additive level-30 progression, practices and reward claims present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

Exploration, quests and legitimate resolutions produce understandable, durable
progression; choices and supplies matter without accidental grinding or XP exploits.

## Existing Owners And Evidence

Use existing progression/inventory managers, vendors, preparation/journal models,
quest completion and saga reward owners.
[Master progression/reward specification](../six-worlds/WORLD-SAGA-000.md)
defines exact skill effects, thresholds, XP and stacking.
[Runtime implementation](../six-worlds/IMPLEMENTATION.md) distinguishes the deferred
original oil deferral from the five initially effective regional fittings.
The approved FINISH-017 source now implements the sixth effect; verification is pending.

## Remaining Conditions And Bounded Repair

- Retain level 1-20 thresholds and existing purchases; cap at 30 with 17 total
  issued Marks and 20 available practices. Prerequisites and summaries agree.
- First arrival, real discoveries, quests, bosses and meaningful returns pay their
  canonical once-only claims; reloads, borders and alternate resolution do not farm XP.
- Q01-Q05 award 300/350/250/300/500 XP; secrets and settled returns award 100.
  Return requires the recorded post-work exit/revisit, not a reload in place.
- Bought/applied preparation, crafting, vendors, capacity limits and pending
  deliveries retain existing rules. A full quiver cannot lose unique rewards or repeat XP.
- Skill and fitting effects match descriptions, stack/clamp correctly and persist.
  Unlock/respec never heals/refills, refunds capstone entitlements or resets deeds.
- Peaceful capstones grant equivalent legitimate progression without fake kills.
  Legacy Bog credit grants only the recorded remaining promotion, not duplicate rewards.
- Review actual earned progression/resources at regional milestones. Change tuning
  only for a documented deadlock, forced grind, misleading effect or resource imbalance;
  record affected numbers and rationale, not a new XP/economy system.
- Check FINISH-017's approved 20% duration effect with normal oil applications;
  source presence alone does not establish that all six mechanical perks work.

## User Manual Checklist

1. During regional play, note level/XP, available Marks, costs and supplies at entry,
   capstone and return. Report any mandatory preparation you cannot reasonably obtain.
2. Learn a prerequisite chain, use its effects, respec and reload; check no healing,
   refill, entitlement loss or incorrect 17-versus-20 summary.
3. Claim a quest, secret and meaningful return; reload/revisit and check no second XP.
4. Fill the quiver before a reward, then make room and collect the remainder at its
   original giver/cache without repeating XP or other items.
5. Use genuine earned saves to check late levels/skills and capstone alternatives;
   absence of an earned late-level save is Pending, never a debug unlock.

## Delivery Record

a59-growth completed on finish-line-20261020-tracker-lines in 111,978 ms. Real
shrine-bench/journal controls learned Keen Edge then prerequisite-dependent
Measured Riposte (17 -> 16 -> 15 Marks). Each automatic save and matching Continue
pointer reached IndexedDB. Normal Continue restored both learned practices.
Ordinary respec then restored 17 Marks, followed by a second durable normal
Continue. XP 26,100, health 62.9904, supplies, claimed deeds, fitting entitlements
and the genuine pre-covenant Quick Save stayed unchanged. No console errors or
warnings. No XP/Marks, choice, inventory or position was injected. This closes the
earned prerequisite/respec UI/persistence cell, not all effect permutations or
user acceptance. Overall run FAIL remains strict browser-private memory 566.1 MB.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a59-growth/browser.json.

Targeted earned campaign observation - 2026-10-20: a49 reached level 30 at the
existing 26,100-XP cap, with 17 issued/unspent Marks. All 30 additive quests are
completed in the earned save. Later quest/secret/return ledger entries correctly
record zero credited XP at cap rather than issuing extra levels or Marks.
Hartlands' once-only return claim is durable in Autosave/checkpoint, not absent.
The browser's former fixed-100 assertion was HARNESS-only and is now cap-aware.
This supplements the existing unit contract, not an actual 20-practice UI/respec
or full economy/user-acceptance verdict.

a53 also observed a partial cap-boundary award: the genuine Greyfen settled return
credited 75, not 100, filling 26,025 -> 26,100. Its same-journey return ledger is
durable with kind return/region greyfen; no extra level or Mark was issued.

2026-10-20 joint FINISH-006/017 verification 1/1: isolated service contracts PASS
with owned process exit 0. Level cap 30, 20 practices, 17 milestone Marks,
unchanged level 1-20 thresholds, all 30 regional XP entries, once-only quest/secret
claims across serialization, permanent fitting retention and pending arrow
delivery were checked. The old verifier's 99-Mark assertion was corrected to the
approved cap; it is not a gameplay limit change. Log:
D:/Temp/AshenOath/finish-006-017-20261020/stdout.log.
Earned regional progression, purchases, all skill effects and balance still need
normal-play evidence; isolated synthetic service state is not an earned save.
Agent result: partial unit evidence, not full card acceptance. User verdict: Pending.

