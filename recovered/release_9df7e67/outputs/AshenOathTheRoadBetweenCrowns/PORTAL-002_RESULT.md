# PORTAL-002 Result

## Changes

- All released zone gates created through `ZoneBuildContext.make_zone_gate` now receive the same `OathGatePortal` component: Greyfen exits, Wychwood return/deeper gate, cemetery/campaign links, Deep Woods, Long Road, Castle sections, Undercroft, Assembly, and Hart Glade.
- Legacy marker meshes remain hidden inside the transition interactable; the transition trigger, destination, arrival position, river-safe route, and save ownership remain unchanged.
- Portal state and preload feedback are now shared across every gate instead of being a Greyfen-only presentation.

## Verification

- `tools/verify_gate_transitions.gd`: PASS for the existing player-driven gate checks.
- `tools/verify_portal_001.gd`: PASS for portal visuals and state transitions.
- `tools/verify_stream_001.gd`: PASS for adjacent topology and retirement.
- Full production export was intentionally not synchronized; this is a development checkpoint before Milestone B acceptance.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles portal -NoCache
```

## Limitations

The gate shell is now consistent across released routes, but final authored architecture, destination silhouettes, and bespoke portal audio remain part of the world/audio milestones.
