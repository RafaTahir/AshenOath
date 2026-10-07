# LR-002 - Two Blades, One Loadout

Status: implemented and packaged; publication pending. User acceptance pending.

## Implemented

- Kael carries Steel and Oathblade using the retained approved sword asset, with
  distinct cross-sections, finishes and paired spine-attached physical scabbards.
  Each housed blade hides independently when drawn; its scabbard stays present.
- Both hand variants share the validated hand socket and contact-marker frame.
  Only the selected blade is visible in hand. Reach and damage are unchanged.
- EquipmentLoadout owns active weapon, blade selection and drawn visibility.
  Keyboard 1 selects Steel, 2 Bow, 3 Oathblade; controller cycle visits all three.
  Selection is inhibited during attacks, dodge, hit reaction and Oathfire.
- Existing remapping exposes Oathblade. Old saved remaps take precedence if they
  already occupy the new default key. HUD reads the selected weapon and arrows.
- Additive equipment schema 2 stores selected_blade_id while retaining sword/bow
  active_weapon. Missing/unknown blade IDs normalize to Steel. Saves retain
  arrows, oil, inventory, quests and world state through their existing owners.

## Scope And Static Review

Changed runtime owners: scripts/equipment_loadout.gd, player_controller.gd,
input_router.gd, hud.gd and the equipment-readout connection in game.gd.
No new asset downloads, character replacements, combat balance, save deletion,
animation rewrite or runtime QA. Physical draw/sheath choreography is LR-003.
Source/diff review covered ownership, saved-state defaults, interrupt gating,
bone binding, first-person body visibility and preservation of bow input.

## Build And Delivery

Production build: lr-002-20261008-two-blades, from 31b080f plus this ticket's
dirty implementation and generated manifests. This provenance is explicit.
The production build completed with no reported compiler errors. Static packaging
checks confirm 14 artifacts plus the release manifest total **91,914,525 bytes**
(87.66 MiB), below 104,857,600 bytes. Artifact-only total: 91,907,854 bytes.
Stored root PCK SHA-256:
`400b98e5cb867195d767606c69c2c15e24592713c0c7743abd25cef51b4df5b2`.
Decoded root PCK SHA-256:
`a52e4d8534ae8ee45c8b1cabaf25db9435f0462ca662d12472e700bf9032d45f`.
Build logs: `.release-gate/LR-002-20261008-build/logs/` at the repository root.
Commit and deployment will be recorded after publication.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: rendered attachments, clipping in motion,
keyboard/controller selection, existing remaps, Save/Continue, first-person
visibility, browser delivery and runtime performance. No manual checks below
have been executed by the agent. User-accepted count remains 0/28.

## Manual Test Checklist

1. New Game or Continue: select 1 Steel, 3 Oathblade and 2 Bow; cycle on controller.
   Attack with both swords and aim/fire the retained bow. Check the HUD selection.
2. Rotate and zoom into first person. Inspect both back scabbards and confirm only
   one selected blade appears in hand; inspect during walking and attacks.
3. Save/Continue each selection, retain an existing remap, remap Oathblade, and
   Continue a pre-ticket save. Check supplies, oil and quest progress remain.

Run from the published Ashen Oath URL; no local setup change is required.
