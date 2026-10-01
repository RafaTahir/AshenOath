# WORLD-002 Hart Covenant Aftermath

Scope: replace the completed ending's generic cylinder/ring with a consequential
memorial garden. **Retained native improvement; not complete WORLD-002 or Hart
scene acceptance.** Formal count remains 27/37 and production is unchanged.

## Player-Facing Change

The completed covenant now owns five weathered name-stones: Witness retains
upright stones, Mercy releases them with new growth, Duty binds them with iron
links, and Ash leaves scorched fallen stones. Each has a distinct inscription.
Existing covenant flags, final-choice completion, quest IDs, quiet aftermath,
return gate, pre-choice stag, combat and rewards remain unchanged.

Geometry is authored in `tools/build_hart_aftermath.gd`, then baked into four
two-surface resources. It is loaded only for the completed covenant by
`scripts/zones/campaign_finale_section.gd`. Five collision boxes use the exact
authored transformed bounds. The existing aftermath light is admitted by the
Balanced allowlist; no extra population or light slots are added. Materials use
existing terrain/masonry textures and authored vertex colors.

| Covenant | Bytes | Triangles | SHA-256 |
| --- | ---: | ---: | --- |
| Witness | 3617 | 108 | 0ad8ca711a831fe3dbab622b733473e6ad1149cde8fd2030b4546d6ccf6354d1 |
| Mercy | 5941 | 180 | af91f589c7479abce053ea10d48449c3854186d8506dcd9bf075658dac946546 |
| Duty | 18333 | 2412 | 8585e0782d721a72f57e9d7b9a0cadf9c1ec035fb33de393e233ce22f0a8672d |
| Ash | 4182 | 108 | 6faabbf4bef316ad7efc7f477c78322a08ad36bd09ab9c3bbdf57c81f2c5971c |

Total: 32,073 bytes; each below the scoped 20 KB cap. Original project geometry,
retained licensed materials, campaign export ownership and hashes are registered
in the runtime manifest/export filter. No Web export was performed.

## Evidence

Logs: `D:/Temp/AshenOath/hart_aftermath_20260930/`.

- `bake_verified_stdout.log`: clean exit 0. Earlier parser/null-index-array bakes
  remain rejected, even where an earlier process exited 0.
- `contract_stdout.log`: clean exit 0, four resource/hash/export/material states,
  finite vertices, five fitted physical obstacles per state, actual CharacterBody
  approach and bidirectional lane sweeps. This isolated contract does not earn
  endings or certify full-world traversal, visuals or performance.
- `{witness,mercy,duty,ash}_stdout.log`: four clean graphical exits 0 and eight
  fresh 1280x720 day/night images. Normal keyboard Continue uses unchanged earned
  ending checkpoints copied byte-for-byte into isolated D: profiles. Time/player
  staging is visual-only, not route proof. Established camera transforms match.
- `.release-gate/world002_hart_aftermath_<covenant>_20260930/`: each report includes
  dimensions, exposure, camera and actual source/resource hashes. Codex reviewed
  all eight frames: standing versus released/fallen states, relative palette,
  inscription, clear arrival lane and player remain visible. Broad flat clearing,
  synthetic horizon and shallow finale composition remain red. Fine Duty chain
  detail is not approved from the distant arrival camera alone.

Earned ending checkpoint SHA-256 values (originals remain unchanged):

- Witness: `18b78f42da9b56660a880d0d5311fd8d17f252317a9cc8b1e4c7591ef2fdbadc`.
- Mercy: `5ce845b0398dc8b8e60c54b5a2916894e55aca7d92f64efb033fe1579d12957c`.
- Duty: `92d2e5970c0e5fe197a1a102c859645d3a6cc893d8051a6d091cf6eefe24ddf3`.
- Ash: `6b145f559eef6e3b60d2621d7e390660bdd93cbb2370efb58ff16ca7f98ae0c2`.

The first real-input Mercy approach reaches the memorial and captures an actual
gameplay frame, but its unproven lateral return shortcut hits an existing tree
collider at x=-9.84, z=-9.09. The run fails and is not return acceptance. Only the
driver is corrected to use the preserved central aisle and south gate frontage;
no tree/collision/gameplay workaround or weakened deadline is introduced.
`mercy_route_v2_stdout.log` and `duty_route_v2_stdout.log` both exit 0 cleanly:
normal earned-state Continue, real northward approach, actual gameplay-camera
capture, central-aisle backpedal, south frontage, focused assembly interaction
and pause-menu manual save retaining the exact completed covenant. Neither run
sets flags, teleports, invokes gameplay handlers, jumps or changes collision.
Original earned checkpoints remain unchanged. The close actual gameplay images
were inspected: Mercy's fallen stones/new growth and Duty's supported upright
stones/binding chain and inscriptions are readable. These changed state/return
cells are frozen. The wider flat clearing/horizon/depth is still rejected, so
no complete finale scene or WORLD-002 acceptance is claimed.

## Limits And Running Steps

Native cold readiness remains red: captured Hart readiness 3,182.8 / 3,796.6 /
32,954.7 / 2,699.2 ms. Greyfen preparation is also over budget. These observations
are not controlled performance samples, a causal regression attribution or an
FPS/memory pass. PERF-001 stays parked; no profiling or renderer work occurred.

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, run stock Godot
4.6.3 at `D:/Temp/AshenOath/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe`:

1. `--headless --path . --script res://tools/verify_finale_composition.gd -- --hart-aftermath-only`.
2. Copy the appropriate genuine completed ending checkpoint to a fresh isolated
   D: profile's manual save slot, unchanged. Set APPDATA/LOCALAPPDATA/TEMP/TMP only
   for that process. Run
   `--path . --script res://tools/capture_pres_001.gd -- --continue-fixture --views=Hart_Day,Hart_Night --output-dir=res://.release-gate/<unique-folder> --reference-report=res://.release-gate/pres001_missing_interior_finale_20260930/capture_report.json`.
3. Affected physical aftermath check:
   `--path . --script res://tools/verify_opening_real_input_native.gd -- --continue-hart-mercy --hart-aftermath-only`
   (or `--continue-hart-duty` with the matching earned save).

No whole ending matrix is replayed. Prior earned ending evidence is preserved.
No commit, push, merge, deployment, source discard or rollback access occurs.
