# LR-005 - Readable Inventory

Status: published_awaiting_user. User acceptance pending.

## Implemented

- Preparation now separates Equipment, Supplies and Ingredients, with a direct
  Quest evidence link to the retained journal. Evidence remains read-only story
  state, not tradable inventory. Practice, recipes and preparation notes remain.
- Equipment shows the actual saved-intent loadout and selected blade/bow. Blade
  comparisons derive from EquipmentLoadout affinity constants; bow information
  derives from the selected arrow definition. No separate live stat state.
- Supplies retain effect descriptions, arrow/oil comparison, stack counts and
  crafting. Ingredients show quantities and their actual field-recipe uses.
  Depleted supplies remain selectable, preserving recipe access and focus after
  consumption. Unknown retained item IDs are displayed without invented actions.
- Name/type sorting and the active kit category persist in InventoryManager.
  Item IDs and the existing navigation memory keep selection stable across
  sorting, use, crafting and purchase refresh. Existing bounded readers, action
  scrolls, focus navigation and compact panes are reused.
- Remedy quick slot accepts Redroot or Bitterleaf; field tool accepts Ash Bomb
  or Iron Trap. Existing keyboard/controller/touch actions use the assignment.
  HUD names, motifs and quantities follow it. Arrow selection stays in the
  existing equipment owner. No supply is spent by assignment.
- Additive inventory save fields preserve assignments even at zero quantity.
  Missing/invalid legacy fields use Redroot/Bomb, type sorting and Supplies.
  No item, ingredient, quest evidence, coin or saved choice is removed.

## Files And Static Review

scripts/inventory_manager.gd; preparation_view_model.gd; preparation_panel.gd;
hud.gd; hud_emblem.gd; game.gd; runtime_service_registry.gd; input_router.gd;
project/ticket records; generated Web and pack manifests.

Inspected existing item definitions, save passthrough, action ownership, vendor
refresh and navigation/focus helpers. No runtime, browser or automated testing.
The minimum production build completed in `.release-gate/LR-005-20261008-build/`.
Build ID: `lr-005-20261008-readable-inventory`; source `b528232` plus the recorded
dirty implementation. Complete Web directory: **91,933,231 bytes**, including
manifests and strictly below 104,857,600 bytes. Stored root PCK SHA-256:
`804f9cd0505eb8a8b3b2cae1687067fcccf8fd84cbe084d126725a4161d5e74e`.
Decoded root PCK SHA-256:
`fb5726dee9ed29d2ed325e309ea4e80b7ce418f80ab2616751b1ed359587eb24`.
Package commit: `c13c67b57e8fe8b212823d67e15c58fef29f1c92`, pushed to development
and main. Vercel `dpl_5Zd4ASwPPDoRP9g6nd1xLXXjkaQB` reported READY.
URL: https://ashenoath.vercel.app/?v=lr-005-c13c67b
Receipt: `.release-gate/living-road/LR-005-20261008T000603Z/publication.json`.
No post-deployment browser or gameplay check was performed.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: rendered 720p layout, controller focus,
selection retention, quick-item effects and Save/Continue persistence. Published
status will not constitute user acceptance.

## Manual Test Checklist

1. Open Preparation; visit Equipment, Supplies, Ingredients and Quest evidence.
   Switch name/type order and read long descriptions at 720p without a mouse.
2. Assign Bitterleaf and Iron Trap, then use their normal quick controls. Check
   quantities, names and effects; craft/buy supplies and check selection remains.
3. Save/Continue and confirm sorting, assignments, equipment and old quests stay.
