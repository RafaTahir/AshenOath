# RECOVERY-003 Issue Registry

## Release Blockers

| ID | Defect | Status | Proof |
|---|---|---|---|
| R003-01 | Campaign builders used reflective private calls in Web | Fixed | Static builder verifier and packed startup |
| R003-02 | Deep Woods did not load through normal play | Fixed | Player-triggered Greyfen to Deep Woods and return |
| R003-03 | Castle Vargan did not load through normal play | Fixed | Player-triggered approach, court, record hall, and return |
| R003-04 | Loading overlay blocked otherwise fast travel | Fixed | Overlay is hidden; cached New Game measures 276.5 ms |
| R003-05 | Gate verifier bypassed focus and input | Fixed | Physical trigger entry, focus, line of sight, and simulated `E` |
| R003-06 | Campaign failures could strand player | Fixed | Transactional build result and source-zone recovery |
| R003-07 | Long Road gate corridor was not reserved | Fixed | Reserved spatial corridor and physical traversal |
| R003-08 | Release report predates current source | Release gate | Final report regenerated before commit |
| R003-09 | Screenshot acceptance was skipped | Release gate | Final 1280x720 captures regenerated before commit |
| R003-10 | Null material and renderer warnings are accepted | Fixed in active rendering | Imported weapon removed; retired roots prevent active teardown. Godot shutdown-only RID warnings remain documented. |

## Regression Gates

- New Game, Continue, pause, dialogue cursor, save/load, and invalid-position recovery.
- Greyfen, Wychwood, Long Road, all campaign sections, Castle Vargan, and Hart Glade.
- Sword, parry, Oathfire, five-enemy progression, NPC navigation, and river safety.
- Balanced 720p performance, Web payload, packed startup, browser console, and live PCK identity.
