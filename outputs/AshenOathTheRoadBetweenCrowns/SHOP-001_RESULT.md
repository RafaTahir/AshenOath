# SHOP-001 Result

Status: `functional_but_incomplete` on `codex/masterpiece-rebuild`.

Implemented a persistent `VendorService`, `data/vendors.json`, and two Greyfen
vendor interactables. Tor sells arrows, traps, and later-unlocked oil; Mira
sells potions, tonics, bombs, and later-unlocked oil. Purchases validate stock,
caps, quest/flag unlocks, and coin in one transaction. Tor also provides a
single free emergency refill when Kael returns with fewer than five standard
arrows, preventing an economy softlock.

The existing HUD, pause/mouse mode, gamepad focus, message/audio feedback, and
atomic save payload are reused. Static checks pass; rendered shop layout, real
input, save round trip, and packed-Web startup still need Godot verification.
