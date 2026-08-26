# Milestone C Result

Date: 2026-08-26
Branch: `codex/masterpiece-rebuild`
Scope: shared humanoid foundation, named-character identity, equipment,
animation, bow aiming, ammunition, Greyfen vendors, and their gameplay gate.

## Status

Milestone C is implemented and locally release-accepted for the selected
runtime character/equipment slice. A browser-only startup-pack handoff issue
was found during the first live smoke test, fixed with signal-driven prewarm,
and revalidated locally before the corrected artifact was promoted. Milestone
E still owns final monster-family replacement and large-encounter presentation.

## Delivered tickets

- `CHAR-010` to `CHAR-013`: one selected Quaternius-centered human family,
  normalized roles, direct runtime mappings, and deterministic NPC variation.
- `EQUIP-001`: hand sword, diagonal back sword/scabbard, bow, and quiver
  sockets with exclusive visibility state.
- `ANIM-004`: imported clip maps, actual hand motion, grounded controller
  physics, and root-motion-disabled locomotion/action playback.
- `BOW-001` and `BOW-002`: aim/charge/release state, target-aware shots,
  obstruction and wall clipping, weak-point resolution, and feedback.
- `AMMO-001`: Standard (24), Bodkin (9), and Ashfire (6) saved ammunition.
- `SHOP-001`: Tor's Forge and Mira's Apothecary stock, prices, emergency
  refill, save state, HUD interaction, and Greyfen placement.
- `CHAR-GAMEPLAY-QA-001`: runtime body, face, socket, animation, controller
  plumbing, bow, shop, persistence, and browser acceptance.

## Artifact

The verified Web candidate contains the seven root runtime files plus five
external streamed packs, for 12 files and `98,607,441` bytes (`94.039 MB`).
The embedded root PCK is `1,773,728` bytes with SHA-256:

`5ca009899b4676bd2a6cd67cc48937d753e4c7bc97c702085b3a115018698dfa`

External candidate records currently verified:

| Pack | Bytes | SHA-256 |
|---|---:|---|
| base | 1,278,468 | `b1833dc82241553c8ba7ce6a6fed593ed79c9538b605229a920775cee2f34a04` |
| opening | 27,605,288 | `0df6abfe559c63484d9cfd4a053d6d78fc0da9241f679d1f94f7bcef98d3f0d5` |
| campaign | 885,576 | `485e76a52326ad7c323933ccbb273264bec818eac4f9bf1fc1d0720164e7d2e3` |
| characters | 26,140,176 | `47de600e2ab082d2993daa0900001bc6cf4dd9f9cfec45dc6385f966e26fe4ca` |
| monsters | 1,557,612 | `504f97e40cd7c233f7e60a051de5773709721df35ec29c11f7edd843485c33b9` |
| audio | 2,585,456 | `760f98c1baf039bf8627464960c51b992b7ccdf9e4ad384fdb2d7500fdb7d8d5` |

## Gate results

Passed:

- character/gameplay QA profile
- character, motion, face, NPC-life, and role-contract profile
- asset acceptance, `ASSET-005`, and `PIPE-003`
- runtime-pack metadata and external candidate validation
- strict Web export shape, payload, and PCK validation
- packed Web startup
- Chrome and Edge native-720p WebGL2 smoke with no console/resource errors

Fresh character evidence was inspected for connected anatomy, native face
surfaces, grounding, role variation, sword placement, and the absence of
synthetic face/proxy anatomy. See `CHAR-GAMEPLAY-QA-001_RESULT.md` for the
per-ticket evidence and exact commands.

## Browser proof

| Browser | Canvas | Engine ready | New Game | JS heap | Console |
|---|---|---:|---:|---:|---|
| Chrome | 1280x720 WebGL2 | 18.42 s | 7.53 s | 11.0 MB | none |
| Edge | 1280x720 WebGL2 | 11.46 s | 6.14 s | 11.7 MB | none |

The final packed startup log reaches the menu with exit code 0. The browser
run reaches Greyfen, shows the selected Kael body and sword/back scabbard, and
no longer reports the earlier primitive `sister_anwen` fallback. The final
handoff run also records `Greyfen prewarmed` and
`new_game_handoff prewarmed=true` in both browsers after the startup fix.

## Honest boundary

Milestone C does not claim final photoreal characters, final monsters, final
boss presentation, or physical-controller certification. The selected
Quaternius family is a meaningful connected and animated runtime foundation;
the pending monster roles and richer facial art remain explicitly scheduled
for later milestones.

## Running

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& .\Export_Web_Build.bat
node .\tools\verify_web_browser.mjs --export ..\AshenOath_Web --renderer hardware --timeout 120000
```

The Web output is at
`C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web`.
