# NAV-002 Result

## Outcome

Connected the sector route rules to the existing spatial/navigation services.
Boundary lanes, safe arrivals, river exclusions, and recovery behavior are
resolved from the same manifest used by player transitions and zone streaming.
Legacy `long_road` requests canonicalize to `bandit_road`, so NPC/enemy and
save callers do not receive a second incompatible route graph.

## Verification

- `tools/verify_nav_002.py`: PASS
- Existing `verify_navigation_001` gate: PASS
- Existing `verify_save_003` recovery gate: PASS
- `verify_seam_qa_001.gd`: PASS through the complete circuit in both directions.

## Limitation

This milestone establishes deterministic cross-sector route contracts. Final
per-family tactical navigation and authored later-zone avoidance remain future
AI/world tickets.

