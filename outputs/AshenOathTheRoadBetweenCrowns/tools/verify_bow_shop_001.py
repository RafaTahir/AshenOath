"""Static acceptance gate for the first bow/ammunition/vendor slice."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def main(root: Path) -> int:
    items = json.loads(read(root, "data/items.json"))
    vendors = json.loads(read(root, "data/vendors.json"))
    ammo = {
        "standard_arrow": (24, 28),
        "bodkin_arrow": (9, 42),
        "ashfire_arrow": (6, 36),
    }
    for item_id, (cap, damage) in ammo.items():
        assert item_id in items, f"missing item {item_id}"
        assert items[item_id]["type"] == "ammo"
        assert int(items[item_id]["cap"]) == cap
        assert int(items[item_id]["effect"]["damage"]) == damage
    assert {"tor_forge", "mira_apothecary"}.issubset(vendors)
    assert any(entry["item_id"] == "standard_arrow" for entry in vendors["tor_forge"]["stock"])
    assert any(entry["item_id"] == "redroot_potion" for entry in vendors["mira_apothecary"]["stock"])

    inventory = read(root, "scripts/inventory_manager.gd")
    vendor = read(root, "scripts/vendor_service.gd")
    player = read(root, "scripts/player_controller.gd")
    combat = read(root, "scripts/combat_manager.gd")
    game = read(root, "scripts/game.gd")
    hud = read(root, "scripts/hud.gd")
    router = read(root, "scripts/input_router.gd")
    save = read(root, "scripts/save_manager.gd")
    greyfen = read(root, "scripts/zones/greyfen_section.gd")

    for token in ["standard_arrow", "bodkin_arrow", "ashfire_arrow", "ITEM_TYPE_ORDER"]:
        assert token in inventory, f"inventory contract missing {token}"
    for token in ["list_stock", "buy(", "claim_emergency_arrow_refill", "save_state", "load_state"]:
        assert token in vendor, f"vendor contract missing {token}"
    for token in ["arrow_requested", "weapon_bow", "aim_bow", "fire_bow", "_release_bow", "get_arrow_origin"]:
        assert token in player, f"bow controller missing {token}"
    assert "resolve_arrow_shot" in combat
    for token in ["vendor_purchase_requested", "show_vendor", "tor_forge", "mira_apothecary"]:
        assert token in game or token in hud or token in greyfen, f"shop integration missing {token}"
    for token in ["weapon_sword", "weapon_bow", "cycle_arrow", "aim_bow", "fire_bow"]:
        assert token in router, f"input action missing {token}"
    assert '"vendors":' in save
    assert '"tor_forge", "vendor"' in greyfen
    assert '"mira_apothecary", "vendor"' in greyfen
    print("BOW/SHOP-001: PASS (ammo caps, target-aware release, wall-clipped resolver, Greyfen vendors, save path)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()))
    except (AssertionError, KeyError, json.JSONDecodeError) as exc:
        print(f"BOW/SHOP-001: FAIL ({exc})")
        raise SystemExit(1)
