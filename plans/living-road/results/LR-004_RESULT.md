# LR-004 - Steel and Oathblade Combat

Status: published_awaiting_user. User acceptance pending.

## Implemented

- EquipmentLoadout defines the sole affinity mapping: Steel gains 1.15 against
  existing human/beast tags; Oathblade gains 1.15 against spirit/undead. All other
  combinations remain 1.0. Base damage, stamina, oils, enemy health and choices
  are unchanged. A supernatural history does not silently retag a physical body.
- Damage requires a ready, physically drawn blade and live blade markers. The
  resolver rejects old attacks, stale blade identity, protected surrender actors
  and repeat contacts against the same target in an attack. Reservation occurs
  before damage signals, preventing re-entrant duplicate hits.
- Existing measured base/tip sweeps, ribbons and contact feedback remain the
  geometry authority. Parry/block flashes use the actual blade segment. Sword
  hits now have one impact-audio path rather than the generic and spatial calls
  both firing; hitstop and existing camera/rumble response remain.
- Oathfire records the prior settled equipment intent, stows weapons, and restores
  Steel, Oathblade or Bow plus prior drawn/sheath state after release or cancel.
  Bow aim and parry windows end on cast; damage/context interruption settles safely.
  Saving during a cast records the pre-cast loadout, not an empty-handed frame.
- Existing StoryState evidence records witnessed creature encounters without
  changing quests or choices. Journal Preparation explains affinity only for a
  witnessed creature or an existing relevant clue/encounter gate, including old
  saves where that evidence is already known. Unknown creatures remain hidden.

## Files And Static Review

scripts/equipment_loadout.gd; combat_manager.gd; player_controller.gd; game.gd;
story_journal_model.gd; project/ticket records; generated Web/pack manifests.
Source review covered the existing contact caller, oil application, damage/death
signals, render-marker ownership, known-evidence gates, cast input and save paths.
No new combat framework, enemy substitution, immunity or automatic blade switch.

## Package

The minimum production build completed, with no runtime testing:
`.release-gate/LR-004-20261008-build/`. Build ID:
`lr-004-20261008-blade-affinity`; source `5ca2d5a` plus the recorded dirty
implementation. Complete Web directory including manifests: **91,925,605 bytes**,
strictly below 104,857,600 bytes. Stored root PCK SHA-256:
`18d6d2f8c64140e8e8446f391c6b6ee8b465f2bd58d01010c43b3011fcce45ba`.
Decoded root PCK SHA-256:
`b3ffba3fd563a4231e2e5efcabee1ce9e0db14203b46a3671ed32be46d0d348e`.
Published package commit: `8381f83978694972bd9f0e60be9afd36cea81bbd`, pushed to
development and main. Vercel `dpl_C7fSPpYAWUdNPReYMapGy7LWqZz7` reported READY.
URL: https://ashenoath.vercel.app/?v=lr-004-8381f83
Receipt: `.release-gate/living-road/LR-004-20261007T235203Z/publication.json`.
No post-deployment browser or gameplay check was performed.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: combat damage feel, light/heavy/parry contact,
sound synchronization, cast cancellation/restoration, journal discovery and
Save/Continue in either camera mode. No runtime, browser, listening or gameplay
test was run. User acceptance remains 0/28.

## Manual Test Checklist

1. Use both blades against a physical foe and an oathbound foe; check that both
   work and the affinity blade has only a modest advantage. Inspect Preparation.
2. Draw, light/heavy attack and parry; watch contact and listen for one impact cue.
3. Cast, release and cancel Oathfire from Steel/Oathblade/Bow, drawn and sheathed.
   Save/Continue and check the original selection, supplies and quests remain.
