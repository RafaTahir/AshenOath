# World Connections

The runtime manifest is the graph authority. This is a route diagram, not a
claim that current local coordinates form a physically stitched continent.

```mermaid
flowchart TD
  GRE[Greyfen] <--> WYC[Wychwood]
  WYC <--> DEP[Deep Woods]
  DEP <--> MIL[Old Mill]
  MIL <--> FAR[Burned Farmstead]
  FAR <--> MAR[Marsh Crossing]
  MAR <--> BAN[Bandit Road]
  BAN <--> APP[Castle Approach]
  APP <--> CRT[Castle Courtyard]
  CRT <--> REC[Record Hall]
  REC <--> UND[Undercroft]
  GRE --- CEM[Cemetery: Greyfen district]
  GRE <--> DEP
  GRE <--> APP
  GRE --- ASM[Greyfen Assembly: explicit civic phase]
  GRE <--> HAR[Hart Glade]
  HAR <--> RUI[Old Ruins]
  RUI -. early legacy return journey .-> GRE
```

## Physical Connection Requirements

- Greyfen/Wychwood is the first adjacent-context pair. It needs an owned next
  root, spatial service, enemy set, interaction registry and state signature;
  a downloaded builder script is not a prepared scene. Keep at most one neighbor.
- Publish static geometry and required population before crossing; controllers
  may not borrow whichever `game.zone_root` happens to be active during staging.
- Place the next root using matched exit/entry transforms, not the historical
  map-grid save coordinates. Preserve local-coordinate saves and camera heading.
- Greyfen's west shortcut needs a forest-spur connector; its eastern shortcut
  needs the old military road. Do not draw those existing jumps as walkable seams.
- Castle rooms need separate local contexts and authored doorway joins. A room
  return must not activate another room's encounters, interactions or rewards.
- Return from the Undercroft through Record Hall, Court and Approach; Greyfen's
  Assembly belongs to its civic phase. Preserve legacy Assembly saves explicitly.
- Use a visible, cancellable preparation fallback if required bytes or geometry
  are not ready. Never let Kael cross into missing collision or frozen scenery.

Current atlas distinguishes roads from retained journey transfers. This record
does not mark the physical adjacency/residency implementation complete.

## Owned-Context Progress (2026-10-25)

All fourteen passage pairs now have explicit local entrance frames, connecting
ground/collision, covered sightline bends and readiness gates. Preparation/reuse
extends through the retained core/campaign builders under ZoneBuildContext and
ZoneResidencyService. The hierarchy changes World3D ownership without tree exit;
movement/camera and local saves survive the frame rebase. Only occluded inactive
branches are culled, not the active region's population. The diagram represents
compressed connected spaces, not a geographically scaled continent or an
all-regions-at-once simulation. Cold missing work retains cancellable progress.

The Undercroft now returns through the Castle rooms. Greyfen owns entry/exit for
the retained Assembly civic scene; its legacy saves remain valid. The earned
Greyfen/Hart path and Hart/Ruins path supply actual regional travel. The optional
early legacy-Ruins return journey is deliberately still a journey, not mislabeled
as a walkable seam. Delivery 7 in `COHESIVE_GAME_IMPLEMENTATION.md` records exact
implementation, packaging/publication and outstanding user acceptance separately.
