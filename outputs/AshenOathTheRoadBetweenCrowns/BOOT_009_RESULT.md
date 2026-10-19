# BOOT-009 - Required Character Atlas Delivery

## Confirmed Defects

Static inspection of BOOT-008's actual shipped PCK directories found that the
prepared Kael, Anwen and male-villager scenes reference their atlas PNGs, but
neither those textures' import records nor their imported texture payloads exist
in the root, opening or character packs. Prepared-scene presence alone did not
establish a complete actor. The prior runtime source fallback requires the same
missing atlas, so it could not repair this packaging defect.

The first of the user's two authorized runs also found independent lazy-script
compilation errors in the navigation dial and interaction-focus service. They
prevented startup before the diagnostic could inspect a live Kael. That run was
stopped; it is counted as test 1, not a successful character check.

## Implementation

- Select every prepared actor's recorded external colour texture as a Godot
  export resource in its existing owning pack. Missing source textures fail with
  the role/resource identified. Regenerate selections after actor compilation.
- Exclude original GLTF source `.bin` buffers from delivery only. Their imported
  runtime scenes already contain that geometry/skin data; source files remain
  in the repository. No actor, texture quality, content or population is removed.
- Shared head textures remain owned by opening. Bandit atlases remain owned by
  characters, with monsters explicitly depending on characters; duplicate atlas
  copies are not shipped. The original over-budget draft was not published.
- Require Kael's actual textured body before announcing Greyfen ready. Missing
  body/atlas uses the existing visible Retry path, never invisible gameplay.
- Type the navigation invalidation boolean and interaction WeakRef explicitly so
  lazy runtime compilation succeeds with the project's compiler rules.
- Extend the existing opt-in read-only observation and existing browser verifier
  for this narrowly scoped character check. The local server mirrors the current
  content-addressed gzip transport and resolves the rendered New Game button.
- Preserve the A-set, 360-degree movement, equipment, camera, saves and settings.

## Verification And Delivery

Affected script compiler checks and production packaging passed. The first draft
exceeded the cap (108,682,086 artifact bytes). Only the changed character/monster
packs and root were rebuilt after shared-texture deduplication; unchanged packs
were reused. An isolated build profile initially lacked export templates; the
existing templates were copied to D: and root packaging resumed without a game
run. This is compiler/package work, not additional runtime testing.

Final candidate: `kael-visible-20261019-40df567`. Manifest-listed artifacts:
104,585,250 bytes. Complete Web folder: 104,593,302 bytes, strictly below
104,857,600. Root PCK SHA-256:
`dcb8c2b25587b52b46737512b7211f9850662f1335d170d3ff64fd871e0e379a`.

Test 2 used one isolated hardware-WebGL2 Chrome session on those exact exported
bytes. The game initialized and mounted opening, passed the new actual textured
body readiness requirement and completed Greyfen's gameplay-camera preparation.
It logged `opening_menu_render_ready` and 24,623 ms Greyfen prewarm. That is a
single diagnostic preparation time, not navigation timing or an FPS claim.
The captured event stream contains zero runtime exceptions, console errors or
network failures; expected audio-unlock warnings occurred before any gesture.

The browser verifier FAILED because it waited for the retired `#boot` element
instead of the current `#startup-loading`/canvas shell. It never reached the
mouse New Game or character screenshots. The obsolete selectors are corrected
statically, but not rerun: both authorized test allocations are consumed. This
is partial startup/body-loading evidence, NOT a passing gameplay visibility,
movement, first-person restoration or NPC-colour test. Those remain UNVERIFIED -
REQUIRES USER TESTING. No third game/browser run, campaign or benchmark occurred.

Evidence: `D:\Temp\AshenOath\kael-visible-20261019\native.log`, `browser.json`
and `browser_events.json`. Publication uses the existing BOOT-009 workflow and
its receipt; publication is not user acceptance.

## Manual Checks

1. Open the new release, choose New Game and confirm Kael's complete coloured
   A-set body appears; check Anwen and nearby villagers.
2. Zoom to first person, then back out: Kael's body should return.
3. Continue an existing save and confirm the same body/colours remain.
