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

`Godot source -> AshenOath_Web -> web/ -> origin/main -> Vercel`

Ordinary implementation tickets run targeted gates and push a
`codex/roadmap-*` checkpoint. Production remains unchanged until the roadmap
milestone runs the complete release workflow.

## Credit-Saving Rule

Read only this brief, the active roadmap document, and the active ticket.
Inspect only directly relevant implementation files. Never reread every phase
document or scan all assets. Use `tools/run_ticket_gate.ps1`; rerun a gate only
when its inputs change. Capture only changed views. Full verification, complete
screenshots, export, `web/` sync, and deployment occur once at the roadmap
milestone.

## Roadmap Checkpoint

`MOBILE-001` completes the original roadmap. Keyboard/mouse, Xbox-style
gamepads, and landscape touch controls now share one semantic router. The
64.0 MB candidate passed desktop and mobile-emulated Chrome/Edge startup with
device-aware prompts and no console errors. Native mobile packaging and
physical-device thermal acceptance remain later work. The approved milestone
now proceeds through the complete production release workflow.
