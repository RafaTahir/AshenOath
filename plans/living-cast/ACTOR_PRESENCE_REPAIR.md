# Actor Presence Repair - 2026-10-23

## Scope And Cause

User reported absent Wychwood monsters and never seeing the White Hart, and
authorized one runtime verification allocation. Existing content, cast identities,
encounter progress, rewards and saves are preserved.

**Confirmed GAME failure:** `enemy_ai.gd` could not parse the inferred `target`
inside Bog Wretch's ambient behaviour because `home_position` is Variant-typed.
The shared EnemyAI script therefore could not instantiate any enemy, not merely
the Bog Wretch. Runtime evidence contains the parser failure at line 766 followed
by all five Wychwood spawn failures. The explicit Vector3 annotation corrects
that compiler failure; subsequent compiler-only invocation exited zero.

## Retained Changes

- Current uncompleted Wychwood wave becomes visible/active during construction.
  Future members remain dormant; no kills, rewards or completed encounters are
  invented. Tutorial polling is no longer the sole initial visibility trigger.
- Required Castle NPCs are constructed before their interaction is published,
  instead of leaving a delayed body marker while dialogue can already be used.
- White Hart witness placement uses a wrapper retaining the imported stag's
  normalized centering/grounding transform. Finale and legacy interaction paths
  share this body/idle recipe. A missing body cannot leave an invisible dialogue
  anchor. The Hart remains story-gated in the late Hart Glade; no early shortcut
  or replacement creature is introduced. Completed covenant aftermath is retained.
- The production build compiles demand-loaded EnemyAI with `--check-only` before
  packaging. This never starts gameplay and closes the import-only compiler gap.

## Verification Boundary

One graphical Compatibility/ANGLE invocation of
`tools/verify_actor_presence_repair.gd` was made. It recorded 38 actor assemblies,
including 31 named/regional interaction registrations, before enemy creation
was blocked by the confirmed GAME parser error. Raw logs:

- `D:/Temp/AshenOath/actor-presence-run.stdout.log`
- `D:/Temp/AshenOath/actor-presence-run.stderr.log`

Four visibility assertions incorrectly required intentionally hidden Ranger/
role-equipment meshes to be visible. The verifier was corrected statically to
require a visible complete skinned body, without exposing those optional meshes.
This correction was **not rerun**. The stalled owned process was stopped after
the parser failure; no second runtime verification was launched.

The run is **NOT PASS**. No monster/Hart visual pass, full quest dialogue pass,
all-story-state NPC pass, browser or phone pass is claimed. Post-fix runtime
behaviour remains UNVERIFIED - REQUIRES USER TESTING. Formal cast acceptance
remains 0/10. Compiler/package success and publication are separate records.

## Delivery

Candidate: `actor-presence-20261023`, based on `10396726` plus this repair.
Package/build result and publication identity are recorded in STATUS.md and
the existing CAST-010 publication receipt. No content or quality reduction.

## User Checks

1. Continue an unfinished Wychwood encounter; approach and defeat the current
   visible wave, then verify the next member appears. Reload without losing wave
   progress. A completed opening encounter must not respawn for duplicate rewards.
2. Speak to Iven/Edda and representative Greyfen/Castle people. Confirm their
   bodies are present immediately and Use opens the displayed person's dialogue.
3. On an earned late-story save, enter Hart Glade and check the actual stag,
   grounding and conversation. Preserve the selected covenant/aftermath.
