# RECOVERY-003 Instant Transitions and Campaign Playability

## Implemented

- Removed the blocking loading overlay from New Game and gate travel.
- Replaced reflective Deep Woods and Castle construction with `ZoneBuildContext`.
- Added validated campaign build results and source-zone recovery.
- Matched gate trigger size to its interaction range and prioritized travel focus.
- Reserved the Greyfen Long Road corridor.
- Cached visited campaign sections to prevent repeated cold construction and unsafe renderer teardown.
- Replaced direct-handler gate verification with physical trigger entry, focus, line-of-sight, and simulated `E`.
- Added full Long Road and Castle traversal plus a reflective-dispatch release gate.

## Acceptance

- Local Web New Game after menu prewarm: 276.5 ms.
- Graphical Balanced performance: 32.4 FPS average, 30.4 FPS minimum.
- Graphical travel: 351 ms cold, 260 ms warm.
- Exported payload: 64.0 MB.
- No blocking loading layer.
- Player-driven `E` traversal covers Deep Woods, the complete Long Road, Castle
  Approach, Courtyard, Record Hall, return travel, and the Wychwood loop.
- Packed startup and local Chrome startup pass without blocking console errors.

The presentation remains a stylized pre-alpha. RECOVERY-003 establishes reliable
playability and transition behavior; it does not claim final environment or
character fidelity.
