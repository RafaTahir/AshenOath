# LR-006 - Knowledge and Preparation

Status: implemented; packaging/publication pending. User acceptance pending.

## Implemented

- Known Creatures uses existing encounter evidence, actual clue history and
  explicit outcomes. Unseen identities stay absent instead of appearing as a
  checklist of future encounters. Legacy recorded discoveries use the same gates.
- Known creature entries cross-link to recovered Evidence records and back through
  the existing journal navigation. Observation, testimony, inference and unknown
  causes are named separately; reading never records discovery or completes work.
- Blade affinity is derived from EquipmentLoadout; field advice references existing
  oils, traps, bomb interruptions, Oathfire openings and encounter staging. No
  damage, enemy, quest or required-purchase rule changed.
- Creature accounts carry explicit resolved/peaceful outcomes from saved decisions.
  A chosen Hart intention is not called resolved before its completion flag. The
  preparation summary stops recommending a repeat fight for a resolved encounter.
- Preparation notes show carried quick supplies, optional useful items, current
  craftability, actual unlocked shop prices and unavailable/affordability reasons.
  Read-only Forge/Apothecary pages link to their Greyfen counters without enabling
  remote purchases, revealing map destinations or switching a tracked quest.
- Current purpose comes from QuestPresentationState's ObjectiveViewModel, not a
  new tracker. The existing On Return entry remains linked. Inventory and vendor
  changes refresh through the retained preparation operation flow.

## Files And Static Review

data/preparation_notes.json; scripts/story_journal_model.gd; story_journal.gd;
preparation_view_model.gd; hud.gd; game.gd; project/ticket records; Web/pack output.

Reviewed enemy tags, actual item effects, encounter preparation, outcome flags,
campaign evidence provenance, vendor quotation and journal return navigation.
No new state service, fabricated legacy history or runtime/automated testing.
Minimum production packaging succeeded on the first build, without runtime tests.
Build: `lr-006-20261008-known-creatures`; source `19c573a` plus the recorded dirty
LR-006 implementation. Full Web directory: **91,945,620 bytes**, below 104,857,600.
Stored root PCK: `5b794cfa00017b04cbacc1f2703cb10d8c1e9a6620f6ff25e1b67c957717cfaa`.
Decoded root PCK: `2d12bf9a1cb787b65f03825b9bf21df9b3ee81b2f195800dc5b695262e4325b1`.
Build output: `.release-gate/LR-006-20261008-build`. Publication receipt follows.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: discovery timing, evidence links/back focus,
720p reading, vendor availability, peaceful-outcome advice and Save/Continue.

## Manual Test Checklist

1. Open Known Creatures before discovery, then investigate or meet a creature.
   Read its account and follow the source links in both directions.
2. Read Preparation notes; compare the objective, carried supplies and shop
   prices with gameplay. Check unavailable items and a peaceful outcome.
3. Save/Continue after discovery. Confirm no future secrets, changed choices or
   stale supply advice appears merely from opening the journal.
