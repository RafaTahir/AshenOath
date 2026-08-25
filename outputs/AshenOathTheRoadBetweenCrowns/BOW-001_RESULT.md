# BOW-001 Result

Status: `functional_but_incomplete` on `codex/masterpiece-rebuild`.

Implemented:

- `1`/`2` sword and bow mode switching through `InputRouter`.
- Hold right mouse/LT to aim, left mouse/RT to release, and `Z`/D-pad Up to cycle arrow types.
- Hybrid release direction: camera flat-forward by default, existing target-lock target when active.
- Draw ratio, selected arrow, bounded range, corridor width, and origin are emitted as one shot request.
- A visible bow/quiver dressing is created once per player; the sword remains sheathed while bow mode is active.
- Arrow release uses the existing combat and camera systems, so the player remains physics-authoritative.
- Wall clipping is resolved before the hit corridor, and the arrow flight/impact feedback is transient and budgeted.

Targeted checks:

- `tools/verify_bow_shop_001.py .` passed.
- JSON parse for `data/items.json` and `data/vendors.json` passed.
- `tools/verify_content_integrity.py .` passed.
- `tools/verify_load_qa_001.py .` passed.
- `git diff --check` passed.

Known limitation: Godot is not installed in this workspace, so real animation, controller input, rendered aim framing, collision behavior, screenshots, export, and packed startup remain unverified. No production Web files or deployment were changed.

Running steps once Godot is available:

1. Start the project in Compatibility mode at native `1280x720`.
2. Start New Game and press `2`; hold right mouse, rotate the camera, and fire with left mouse.
3. Confirm an active target bends the release toward that target, while an unblocked shot stops at the first wall.
4. Press `Z` at Tor's Forge after buying Bodkin or Ashfire arrows and repeat the shot.
