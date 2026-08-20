# QA-012 Result

## Changes

- Added a complete released-zone lifecycle smoke gate covering New Game, Greyfen, Wychwood, wilderness, Castle, undercroft, assembly, Hart Glade, control restoration, grounded reload position, world state, and boss-state serialization.
- The gate uses the normal main scene and zone builder path rather than a node-presence-only fixture.
- Save and settings verifiers now report read-only sandbox limitations explicitly while retaining their assertions in writable profiles.

## Verification

- verify_qa_012.gd: PASS
- verify_runtime_regressions.gd: PASS
- verify_save_001.gd: PASS
- Product ticket gate: PASS

## Known limitation

This is a local lifecycle gate, not the final Chrome/Edge/Firefox real-input campaign run. That remains QA-012 release evidence and must be completed before RELEASE-003.

## Running steps

    .\tools\run_ticket_gate.ps1 -Profiles product -NoCache
