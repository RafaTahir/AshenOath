# Ashen Oath Expansion Context Brief

## Current World

- Browser-first Godot 4.6.3 vertical slice.
- Playable route: Greyfen -> Sister Anwen -> Wychwood clues -> first Ghoulkin -> Greyfen report.
- Greyfen Cemetery and Ruined Crow Chapel are the next expansion direction.
- Ruins and Castle Vargan remain partial/blocked and outside current work.

## Available Systems

Reuse the existing quest/objective, dialogue action, interactable, enemy AI/leash, combat, HUD guidance, audio event, world-state, save/load, material fallback, Potato Mode, and screenshot/verifier systems. Do not create broad replacements for them.

New section construction belongs in `scripts/zones/cemetery_section.gd`; `game.gd` remains the owner of managers, signals, global progression, saving, and transitions.

## Visual Rule

Every route-visible mesh must have an intentional non-white material. Preserve `tools/verify_visible_quality.gd`, route clearance, stable collision, bounded play space, and the slim Web asset budget.

## Deployment

Production path:

`Godot source -> AshenOath_Web_Slim -> web/ -> origin/main -> Vercel`

Implementation tickets use the repository deployment script and report `https://ashenoath.vercel.app/`. Planning-only tickets do not deploy.

## Credit-Saving Rule

Read only this brief, `PLAN_001_WORLD_EXPANSION_PROPOSAL.md`, and the active ticket. Inspect only likely implementation files. Never reread every phase document, scan all assets, or perform a broad audit. Build one ticket at a time with explicit acceptance criteria; run screenshots only for visible changes.
