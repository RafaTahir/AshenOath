# LR-021 - Greyfen Archery Range

Source-implemented locally on 2026-10-08. Not published or user-accepted.

An optional southern Greyfen range offers eight-shot untimed/45-second practice.
Physical ring targets and a backstop use a shot-only layer, leaving player routes
unchanged. The existing bow aim/draw/release input produces visible training arrows
with swept segment collision and impact-location scoring. Range reticle aim includes
elevation; the campaign's existing combat-shot resolution is not replaced.

Training arrows never enter/consume inventory, create pickups or deal combat damage.
Cancelled/retired requests cannot fall through into real combat. Only completed best
scores persist. Pause, focus loss, departure, save, damage, switching weapons or
walking outside the firing strip cancels and restores equipment/camera. The existing
range interaction offers retry; no practice supplies or economy rewards.

Files: new `scripts/greyfen_archery_range.gd`; existing player, camera, game,
StoryActivityDirector, SaveManager and ZoneRuntimeCoordinator; ticket/status docs.
No schema migration or new downloadable asset. Static source/diff review only.

UNVERIFIED - REQUIRES USER TESTING: range clearance/target presentation, input/aim,
ring scoring, inventory isolation and interruption/restoration. No tests, launch,
captures or export. Final compilation/package follows LR-028.

## Manual Test Checklist

1. Near the southern noticeboard, enter the range with empty/full real ammunition.
2. Aim, draw and fire at rings with mouse/controller; try timed/untimed practice.
3. Cancel, pause, change weapon, leave or save; check equipment/camera and ammo counts.
