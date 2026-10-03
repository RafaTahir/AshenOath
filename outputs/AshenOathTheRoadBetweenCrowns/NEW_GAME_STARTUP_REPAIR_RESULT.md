# New Game Startup Repair

Source checkpoint: `fcf094cf9b80c8aa02e294bedd7eb3f1cfba9d2e`.

## Implementation

- Startup and saved-zone dependencies now include the Quality material pack when the selected preset needs normal/ORM textures. Balanced and Potato do not wait for that pack.
- New preparation attempts retain valid resources, clear stale failure/null-cache state, and report the failing resource. Resource polling completes before first-view rendering.
- Preparation generations prevent cancelled work from publishing an obsolete world. Menu preset changes restart preparation; Continue cancels unused New Game preparation.
- The opening pack starts downloading alongside engine startup. Godot joins that verified download instead of issuing a duplicate request. Corrupt cached payloads are removed; bounded download failure falls back to the existing pack manager.
- Essential Greyfen construction runs in 8 ms scheduling slices instead of forcing a render after each individual stage. The complete-scenery and final-camera readiness checks remain.
- Saves, presets, world content, camera orbit and first-person zoom are preserved.

## Acceptance Ownership

The user changed this task to BUILD-ONLY MODE during execution. No browser acceptance, timing measurement, screenshot review, or live gameplay verification was performed after that instruction. Production behavior and load-time improvement remain **UNVERIFIED - REQUIRES USER TESTING**.

Before that instruction, focused native checks had completed for material retry, role resources, pack readiness/retry, script parsing, and Balanced/Quality Greyfen detail and bridge traversal. Those checks are not browser or deployed-artifact acceptance. Four existing tooling files were extended before the build-only instruction; no further testing changes are planned.

## Changed Files

- `scripts/game.gd`
- `scripts/runtime_pack_manager.gd`
- `scripts/world_material_library.gd`
- `scripts/asset_spawn_helper.gd`
- `web_boot_shell.html`
- `runtime_pack_manifest.json`
- `tools/verify_opening_pack_readiness.gd`
- `tools/verify_material_prewarm_retirement.gd`
- `tools/verify_role_resource_prewarm.gd`
- `tools/verify_web_browser.mjs`
- This record and the generated production `web/` output.

## Manual Test Checklist

1. Open the deployed build and click New Game. Check that Greyfen is complete before movement unlocks.
2. Select Quality, reload, and click New Game again. Check that the authored-resource failure no longer appears.
3. Save, reload, and Continue. Confirm location and settings persist.
4. If a download fails, restore the connection and select New Game to retry.
5. Compare first-visit and repeat-visit wait times; walk across the bridge, speak to Anwen, and check camera orbit/first-person zoom.

No new browser performance figure or claim of complete release certification is made by this hotfix.
