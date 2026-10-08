# LR-007 - Greyfen Services

Status: implemented; packaging/publication pending. User acceptance pending.

## Implemented

- Tor offers Steel Tempering and Oathblade Inlay for 18 coin each. Each is a
  one-time fitting adding 3 strike damage to its own blade, after learned-practice
  scaling and before target response. Per-blade forge bonus is capped at 3.
  Oathblade Inlay requires the existing Teeth in the Rain account; neither fitting
  is required for progression. Bow and Oathfire are unaffected.
- Inventory saves unique fitting IDs, not repeatedly applied stats. Fresh/legacy
  saves start without fittings; loading validates/deduplicates IDs. Equipment
  comparison shows the actual bonus and fitted name. No consumable proxy item.
- Greyfen shops show locked offers with requirements, price, effect, affordability,
  capacity and already-fitted reasons. An unavailable exchange reports no charge,
  rather than implying its proposed quantity was received. Close without buying
  leaves state unchanged; only the explicit purchase action commits.
- Vendor transactions re-quote current stock and guard reentrant exchanges. Coin,
  stock history, emergency entitlement and received item/fitting are settled before
  inventory notification. Story-sensitive offer/price beats and purchase counts
  save additively; loading never restocks by granting items or replaying charges.
- Normal supply replenishment remains the existing on-demand policy, not new
  artificial scarcity. Story changes select the next offer/price beat. The existing
  one-time free refill to five Standard arrows and emergency medicine are unchanged.
  Neither is reset by a shop beat, journey reload or purchase.
- Crafting rederives the full recipe, then applies learned ingredient returns and
  output together before changed notification. No cancellation can consume half a
  recipe. Care, testimony, story choices and relationships remain separate owners.

## Files And Static Review

data/items.json; data/vendors.json; scripts/inventory_manager.gd; vendor_service.gd;
player_controller.gd; crafting_manager.gd; preparation_view_model.gd;
preparation_panel.gd; hud.gd; project/ticket records; generated Web/pack files.

SaveManager already passes inventory/vendor additive fields through; their owners
validate them. It was inspected but did not need modification. Static review
covers one damage application point, purchase re-quotation, legacy/reset behavior,
failed exchange messaging and retained recipe/quest completion ownership.

No runtime tests, browser QA, gameplay, screenshots or listening review executed.
Minimum production packaging succeeded on the first build. Build:
`lr-007-20261008-greyfen-services`, source `26f936f` plus the dirty implementation.
Full Web directory: **91,950,300 bytes**, below 104,857,600.
Stored root PCK: `b920ba0cef2553b68d010dc87dac70d390288648e2e279dcadc9a5b505a3b876`.
Decoded root PCK: `f3e85592bb64072f7885a53f8aed5a400727ab0b4940d872aa9efc20abb462d5`.
Output: `.release-gate/LR-007-20261008-build`. Publication receipt follows.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: shop focus/layout, purchase/decline, combat
bonus, emergency reserve eligibility, crafting returns and Save/Continue.

## Manual Test Checklist

1. Visit Tor and Mira. Inspect locked, unaffordable and full-capacity offers; close
   without buying and confirm no coin/items change.
2. Buy a blade fitting, compare Equipment, fight with each blade, then Save/Continue.
   Confirm the fitting remains once and cannot be bought again.
3. Buy/craft supplies and check exact quantities/coin/ingredients after reload.
   Return below five arrows before claiming the emergency reserve, claim it once,
   and confirm reloading does not grant another reserve.
