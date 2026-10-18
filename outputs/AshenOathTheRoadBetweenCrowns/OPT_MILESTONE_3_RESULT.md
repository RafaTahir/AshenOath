# Milestone 3 - Character and NPC Loading

OPT-017 through OPT-024 implementation is present; build/package outcome follows
the milestone production build. User visual/gameplay acceptance remains pending.

- OPT-017/021: the asset compiler serializes the retained human and monster body
  assemblies selected by the current manifests, including fitted layers,
  normalization, material repair and shared animation attachment. The runtime
  selects the exact role/source entry. Native A-set, Ranger and monster sources
  are unchanged. Per-actor palettes, gestures, combat effects, boss attachments,
  phases and encounter state remain runtime-owned, not shared live actors.
- OPT-018: retargeted libraries are serialized once per source/relative-path/
  skeleton-name/parent signature. AnimationPlayers retain independent clocks.
  Clip-name resolution is cached by the actual clip list and requested mapping.
- OPT-019: prepared assemblies retain relative mesh/player/skeleton paths,
  normalized bounds and role metadata. Runtime resolves paths against each new
  instance and retains instance-specific skeleton/visual/role validation.
- OPT-020: identical immutable human palette recipes share materials; mutable
  monster/boss phase and flash materials remain private. Identity/variation
  selection is unchanged. Palette ownership clears with the asset helper.
- OPT-022: all fitted equipment remains alive across draw/sheath changes;
  scabbards reuse one weakly owned immutable mesh, and identical visibility
  writes are skipped using the actual node property (not a stale visibility cache).
- OPT-023: crowd pacing queries a local XZ registration index. Registration order,
  exact ahead/lateral checks, movement validation and the full population remain.
- OPT-024: identical eye/brow/bone property writes are skipped. Blink, speech,
  attention and additive post-animation head evaluation keep their cadence.

## User Checks

1. Compare Kael, Anwen, Senn, the crowd and retained monsters before/after.
2. Check walking backward, footsteps, attacks, dialogue and death animation.
3. Draw/sheath both swords, use bow/Oathfire and switch first-person views.
4. Confirm actor identities remain distinct and one actor's hit cannot tint others.
5. Check crowd approaches, saved encounters and arrival/return body grounding.

## Build / Publication

Production compilation and packaging succeeded. No game/app execution, runtime
test, browser, benchmark or screenshot capture has been performed.

The first package was rejected by the unchanged 100 MiB gate at 122256904 bytes.
It was not synchronized or published. Assembly storage is now deduplicated by
source/composition/pack owner instead of role alias; each actor still applies its
own exact role normalization and identity metadata using the saved source bounds
and transform. No source body, texture, animation, role or quality was removed.

Selected build: `opt-m3-20261018-4bd9df5` at
`D:\Projects\AshenOath\.release-gate\opt-m3-20261018-dedup\export`.
Manifested artifacts: 104175232 bytes, strictly below 104857600.
Root PCK: 9018234 bytes; SHA-256
`30bccf4080925de43afe53a082600a6ab27c10b45b23af48d7102a66747e5889`.
Publication uses the existing OPT-024 release receipt; acceptance remains yours.
