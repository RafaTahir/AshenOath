# ENGINE-001 Runtime Composition Boundary

## Scope

ENGINE-001 establishes explicit runtime ownership without rewriting working gameplay systems.

## Changes

- `RuntimeServiceRegistry` now owns, configures, and connects all fourteen runtime services.
- `RuntimeActorFactory` owns player and third-person camera construction.
- `ZoneCompositionRouter` owns zone validation, classification, and campaign section construction. Core builder calls remain compile-visible in `game.gd` because indirect private-method dispatch is unreliable in Godot Web exports.
- `game.gd` remains the gameplay orchestrator for transitions, quest reactions, combat hooks, saving, and authored helper calls.
- `verify_engine_001.gd` checks service identity and ownership, actor composition, source-level delegation, and released-zone registration.
- The authoritative release runner now includes the ENGINE-001 verifier.

## Boundary Contract

- Runtime services are created and configured once beneath `RuntimeServices`.
- The game root references the exact registered service instances; duplicate manager nodes are invalid.
- Player and camera are created as one connected pair by the actor factory.
- Unknown zone IDs are rejected by the zone router.
- Core zones use explicit compiler-visible dispatch; the router reports the canonical composition kind.
- Zone builders own environment construction; `game.gd` owns lifecycle and gameplay state.

## Verification

- Runtime, campaign, quest, character, animation, navigation, combat, Oathfire, UI, world, visual, audio, and master verifiers passed.
- Fresh route, animation, Greyfen, Wychwood, cemetery, chapel, and Castle proof captures passed.
- Native 720p Compatibility performance passed at 33.4 FPS average, 30.5 FPS minimum, and 181 ms warm transition.
- The single Web export passed at 63.9 MB.
- Packed startup passed after the new composition scripts were added to the explicit export allowlist.
- Legacy display-case zone IDs are normalized at the composition boundary.
- A real local Web New Game smoke test confirmed Greyfen renders with 1,330 nodes, 566 meshes, and 243 collision shapes. This gate caught and replaced Web-incompatible indirect builder dispatch.

## Remaining Architecture Work

Large helper methods still remain in `game.gd`. Future extraction should be ticketed by stable responsibility and must preserve the composition interfaces introduced here.
