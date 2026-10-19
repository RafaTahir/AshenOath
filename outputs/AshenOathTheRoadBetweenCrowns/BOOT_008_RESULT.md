# BOOT-008 - Restore Kael's Authored Model Loading

## Reported Regression

The user reported Kael missing after BOOT-007. That release introduced a runtime
material-metadata rejection which freed the complete prepared actor and returned
null; the player then retained only its invisible controller/collision shell.
The earlier single browser run had already exposed that rejection for a villager.
No new browser/game test is authorized or performed for this repair.

## Implementation

- Preserve currently valid textured surfaces instead of overwriting them from
  serialized recovery metadata.
- Refresh stale mesh-path descriptors only when every current authored surface
  still satisfies the material/atlas contract.
- If a prepared actor cannot be repaired, instantiate its exact approved source
  path with the existing composition, normalization, skeleton and animation
  preparation. Never replace Kael with another character or primitive anatomy.
- Keep asset-compilation failures fatal. Runtime recovery reports the affected
  role and cause; failure of both prepared and approved source remains explicit.
- Preserve BOOT-007's movement/camera/arm-pose changes, colours, saves and settings.

## Delivery

Source/static review and production compilation/package generation completed.
Candidate: `kael-restore-20261019-400e061`. Manifest-listed artifacts: 104,712,028
bytes. Complete Web folder: 104,720,060 bytes, strictly below 104,857,600 bytes.
Root PCK SHA-256:
`b3fd42b472e934cdd5faf00d0d613d4b9ea6688164c6f733edaa5d95bf9a2dd0`.

The existing BOOT-008 publication receipt records the commit/deployment result.
Runtime appearance is UNVERIFIED - REQUIRES USER TESTING. The prior one-test
allowance was consumed on BOOT-007, not renewed here. No game launch, browser,
gameplay, screenshot or benchmark was run for this repair.

## Manual Checks

1. New Game: Kael's full body, head, hair and equipment appear in third person.
2. Continue and return from first-person zoom: the body reappears normally.
3. Confirm NPC bodies/colours and turn-to-travel movement remain intact.
