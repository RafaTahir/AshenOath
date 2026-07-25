# QA-002 - Real-Route Browser Automation

## Files Changed

- `scripts/qa_browser_telemetry.gd`
- `project.godot`
- `export_presets.cfg`
- `tools/verify_qa_002.gd`
- `tools/verify_qa_002_browser.mjs`
- `tools/gate_profiles.json`
- `tools/run_ticket_gate.ps1`

## Implementation

- Added Web-only, `?qa=1`-gated, read-only telemetry exposed as
  `window.__ASHEN_OATH_QA__`.
- Telemetry reports zone, transition state, player/camera state, current
  interaction focus, and available zone gates. It does not move actors or
  mutate quests, saves, or progression.
- Added a CDP browser harness using real keyboard and mouse events.
- Added route coverage for:
  - Greyfen -> Wychwood -> Greyfen
  - Greyfen -> Deep Woods -> Wychwood -> Greyfen
  - Greyfen -> Castle Approach -> Courtyard -> Record Hall -> Courtyard ->
    Castle Approach
- The harness records checkpoints, transition timings, console errors,
  diagnostics, and success/failure screenshots.
- Added the `qa` WORKFLOW-002 gate profile.

## Verification

- `node --check tools/verify_qa_002_browser.mjs`: PASS
- `node --check tools/verify_web_browser.mjs`: PASS
- `tools/verify_qa_002.gd`: PASS
- `git diff --check`: PASS, with existing line-ending warnings
- Local Web export: PASS, 64.1 MB total and 27.8 MB PCK
- Export PCK SHA-256:
  `522d02ac1b4b21bc29f0ee5578f39487bf5da2ca88983f6ef32189752507fae1`
- Shared-build browser startup: BLOCKED by the concurrent ENGINE-002
  integration described below.

Artifacts:

- `.release-gate/qa_002/browser_report.json`
- `.release-gate/qa_002/browser_report_chrome_failure.png`

## Current Integration Blocker

The shared build currently fails before gameplay because ENGINE-002 changed
zone builders to accept `ZoneBuildContext`, while its owned integration still
calls `GreyfenSection.new().build(self)` in `scripts/game.gd:669`.

Browser console error:

`Invalid argument for "build()" function: argument 1 should be
"ZoneBuildContext" but is "res://scripts/game.gd".`

QA-002 did not edit `scripts/game.gd` or any `scripts/zones/*.gd`. The
ENGINE-002 owner must complete that integration, after which the browser route
gate can run without further runtime integration changes from QA-002.

## Route Limitations

- Castle Approach has no direct Greyfen return gate, so the automated return
  path ends after Record Hall -> Courtyard -> Castle Approach.
- Deep Woods' authored return gate targets Wychwood, so its return path is
  Deep Woods -> Wychwood -> Greyfen.
- Full browser traversal remains unproven until the ENGINE-002 parser blocker
  is resolved.

## Local Command

After the shared build is parser-clean:

```powershell
node tools\verify_qa_002_browser.mjs --export ..\AshenOath_Web --browser chrome --report .release-gate\qa_002\browser_report.json
```

No tracked `web/` output, deployment script, gameplay outcome, quest data,
visual asset, or zone construction was changed. No commit or push was made.
