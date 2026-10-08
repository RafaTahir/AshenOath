# LR-022 - Archery Challenges

Source-implemented locally, 2026-10-08. Publication and user acceptance pending.

The existing LR-021 range now offers Rook's fixed-ring mark, Tor's predictable
pendulum target and Elna's three-distance sequence. Rules, deadlines, scores,
decline/rematch, distinct posted remarks and later personal acknowledgement are
authored. Every point comes from a training arrow's physical collision; distance
changes wait until the in-flight arrow resolves. Player controls stay live.

Each first successful tier grants one modest existing supply: bread, redroot potion,
or bitterleaf tonic. Saved best/completion/reward flags are independent; rewards
commit in one synchronous StoryState/inventory operation before the atomic save.
Cancel does not award completion, and campaign arrows remain untouched.

Files: `scripts/greyfen_archery_range.gd`, `scripts/dialogue_manager.gd`, records.
Opponent marks/remarks are posted invitations, not newly spawned performers.
No altered quest gates, betting debt, tests, captures, export or runtime launch.

UNVERIFIED - REQUIRES USER TESTING: all contest timing/aiming, score/readout behavior,
rewards across reload, moving-target readability and retained clear routes.

## Manual Test Checklist

1. Try/win/lose each posted contest; decline, cancel and rematch.
2. Compare score to ring impacts and inspect the first-win supply.
3. Save/Continue, rematch and confirm rewards do not duplicate or consume campaign arrows.
