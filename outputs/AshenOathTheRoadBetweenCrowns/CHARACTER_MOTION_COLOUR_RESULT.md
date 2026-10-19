# BOOT-007 - 360-Degree Movement and Character Colour Repair

## Implementation

- Normal movement in every direction turns Kael toward travel and selects forward
  walking/running rather than backpedal/strafe clips. Other actors keep their gaits.
- Reverse movement brakes through sharp changes, with collision, acceleration
  constants, stamina costs and achieved-motion footstep cadence retained.
- Bow aim and first person turn body and view together. The continuous movement
  frame follows only real manual look deltas, never its own automatic camera turn.
- Existing committed attacks/casts keep facing; conflicting walking does not play
  backward. Camera orbit, zoom, first-person mode and collision remain available.
- Inactive arm-pose solvers release their influence. Real guard, casting, draw and
  bow poses remain action-owned.
- Prepared actor scenes retain immutable authored material resources in metadata;
  their existing catalog now also records each expected surface/texture binding.
- Effective surface materials take precedence over generic fallback heuristics.
  Prebaked identity requires bound textures. Missing required materials block the
  asset compilation instead of silently producing a grey/white body.
- A private temporary hurt overlay restores each actor's original overlay rather
  than changing a shared albedo. Existing A-set, Ranger and NPC recipes remain.
- Menu PNG repacking changes compression only, preserving original PNG metadata,
  format and exact pixel bytes. No textures/content are removed or downsampled.

## Delivery State

Implementation/static review and production compilation/package generation are
complete. Final candidate: `movement-colour-final-20261019-4863e01`.
Its manifest lists 104,711,461 artifact bytes; the complete Web folder is
104,719,502 bytes, strictly below the 104,857,600-byte limit. Root PCK SHA-256:
`0b85c07dc3c27296d1290faf2c4be4ac174b85cd4a6922ae9bdcbeaca494c60f`.

The single authorized local-browser test is complete. The asset-binding correction
identified during that test was included in this replacement build, without a
second runtime test. Publication uses the existing BOOT-007 workflow; its local
receipt records the commit and Vercel result. User acceptance remains pending.

## One Authorized Test

One in-app Chromium session used candidate `movement-colour-20261019-4863e01`.
The menu appeared, a real mouse New Game started complete-looking Greyfen, and
forward/reverse keyboard actions moved the player. The owned console reported
Greyfen prewarm at 19,712 ms and the prepared New Game handoff at 170.4 ms. These
are single-run diagnostic messages, not navigation timing or a performance claim.

The run exposed a required-material restore error on `villager_human`, with no
resource-specific reason in its old empty diagnostic array. The retained repair
stores the authored atlas path alongside its material, can restore that exact
atlas when its serialized binding is absent, and reports missing mesh/material
paths explicitly. It does not install a generic material or suppress failures.

The narrow browser view and overlaid HUD did not provide sufficient evidence to
approve body colours, relaxed arm motion, all eight directions, bow aim or
first-person turning. Scroll/held-input actions do not establish those checks.
The replacement build is NOT runtime-retested: the one-test allowance is exhausted.
No other gameplay test, campaign run or benchmark was performed.

Local evidence: `D:\Temp\AshenOath\movement-colour-20261019\console.json` and
`D:\Temp\AshenOath\movement-colour-20261019\single-test.png`.

## Remaining User Checks

Actual phones/controllers, all NPCs/zones and day/night presets, repeated Continue
and zone returns, combat/Oathfire and save persistence remain user-owned unless
explicitly observed during the one authorized test.
