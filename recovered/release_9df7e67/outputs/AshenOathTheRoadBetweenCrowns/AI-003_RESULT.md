# AI-003 Result

## Changes
- Enemy movement now validates the final proposed step after crowd separation and
  after any forced navigation refresh. If both the direct step and reroute are
  blocked, the actor stops instead of falling back to an unsafe direct move.
- Moving enemies face the route they are actually taking, while stationary
  attackers continue to face the player. This makes flanks and retreats read as
  deliberate movement instead of sideways sliding.
- Added `EnemyAI.get_tactical_state()` with profile, engagement lane, leash,
  route-safety, attack-token, perception, windup, and recovery telemetry.
- The runtime gate now exercises the five-member Wychwood pack, staged reveal,
  distinct engagement lanes, river-safe pursuit, spacing, one-attacker
  reservation, and ally-blocked attack lanes.

## Verification
- `verify_ai_003.gd`: PASS with real Wychwood runtime actors.
- Targeted combat ticket gate: PASS (`content_integrity`, `runtime_smoke`,
  `verify_motion_quality`, `verify_combat_001`, `verify_ai_001`, `verify_oath_001`,
  `verify_oath_002`, and changed combat captures).
- Low-FPS/browser profiling remains part of the later performance gate; the
  runtime contract itself no longer relies on a source-string-only check.
