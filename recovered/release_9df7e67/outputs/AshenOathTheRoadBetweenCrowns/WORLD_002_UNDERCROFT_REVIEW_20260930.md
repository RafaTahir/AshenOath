# WORLD-002 Undercroft Architecture And Scoped Presentation Review

Formal recovery remains **27/37 accepted**. This is native visual/physical
subcell evidence, not complete WORLD-002, PRES-001, campaign or performance
acceptance. Production, tracked Web output and accepted gameplay are unchanged.

## Retained Work

- Ten grounded stone piers now visually support the existing vault ribs.
- Both existing door openings have coursed jambs and lintels, instead of
  unframed rectangular holes. No opening, interaction or collision was moved.
- Four tombs and the original roof/collision surface are preserved. All new
  decoration shares the existing second surface; no node, draw surface, light,
  actor or active gameplay population was added or removed.
- `tools/build_undercroft_vault.gd` generates the original project geometry.
  `tools/verify_undercroft_vault.gd` now checks grounded-pier/frame metadata,
  separate tomb and wall-dressing envelopes and both door clearances. The
  original 100,000-byte, two-surface and capsule/standing-clearance requirements
  are retained. Taller wall decoration does not waive the tomb height limit.
- `runtime_asset_manifest.json` records 40,392 bytes, 2 surfaces and 2,896
  triangles; SHA-256
  `a981bf65c6270499567f62bc9f6a7b9e3ed9c76642fc05674b9dda1193cfb5d6`.
  Growth from the pre-pass derivative is 12,520 bytes and 936 triangles.

## Rejected Work

The first scene pass also tried a carved broken-oath wall relief. In the
gameplay-distance frame it read as a dark framed panel, not clear story art.
That candidate's generator code, geometry and acceptance assertion were removed.
Its images remain at `.release-gate/world002_undercroft_architecture_20260930/`
as rejected focal-point evidence, not final scene approval.

The first bake failed a type annotation before writing a resource. The first
geometry check rejected a crossguard extending beyond the declared wall band.
Those failed logs are retained; only `bake_retained.log`,
`contract_retained.log` and the retained-source capture may supply passing proof.

## Evidence Scope

`D:/Temp/AshenOath/undercroft_scene_completion_20260930/` preserves the pre-pass
builder, manifest and derivative, all logs and isolated D: profiles.
`contract_retained.log` exits 0 with floor-not-roof save grounding, twelve
bidirectional/off-centre capsule passages, overhead clearance, material,
resource budget, current hash/bytes and existing campaign-export inclusion.
Export inclusion is a source check: no Web export was performed.

The capture fixture is explicitly staged. It loads zones and positions its
camera for art review, and cannot certify travel, quest progression, fight,
save/load, browser behavior or FPS. The day/night camera reference is the
preserved pre-pass report; numerical transform rounding is not pixel-identity.

The first retained-source capture failed Greyfen's unchanged 45-second
readiness check before taking an Undercroft frame. It is explicitly failed
evidence at `capture_retained_stdout.log`/`capture_retained_stderr.log`; its
empty directory supplies no approval. No timeout or performance threshold was
raised. The art fixture gained `--continue-fixture`: keyboard focus/Enter
activates normal Continue from a copied save, avoiding another complete Greyfen
New Game/hydration pass for an interior-only review. It never edits save flags.

Current final 1280x720 images are in
`.release-gate/world002_undercroft_earned_20260930/`. The pre-duel save was
earned on the preserved native campaign route; the original remains unchanged
at SHA-256 `98d0376e5c7b5232478b55c53a1206e68bd6b1f85992cccf4711b7a6b7ba8f1c`.
`capture_earned_stdout.log`/`capture_earned_stderr.log` finish with exit 0 and no
parser, resource, renderer or cleanup error. Camera components match the
pre-pass reference within 0.00000002; actor poses, quest HUD and saved state are
not pixel-identical to the earlier unoccupied baseline.

Review accepts supported rib architecture, framed openings, day/night route
readability and local pre-duel Halvern visibility only. Mean luminance is
0.217733 day / 0.198229 night; current occupied views draw 83 / 81 calls and
15,892 / 16,414 primitives. State differences prohibit attributing those counts
to architecture alone. The staged frames do not prove moving duel, testimony,
aftermath or performance. Cold interior readiness was 9,231.4 ms, **failing**
the 900 ms transition criterion; earlier preparation was 23,751 ms. These are
observations, not a formal performance benchmark or a claimed improvement.

The missing peaceful-witness aftermath was reviewed on the same source bytes
from a copied genuine `undercroft_return_v1_fixture` save, then staged back into
the room. Original SHA-256 remains
`b2c6a36785533488afbef006c2c1aab1f078efa4621e0f9a2c5294fb7de65843`.
`capture_witness_stdout.log`/`capture_witness_stderr.log` exit 0 cleanly;
images are `.release-gate/world002_undercroft_witness_20260930/`.
The boss is gone and the assembly exit is available, consistent with the saved
witness outcome, but the room's visual aftermath remains **rejected**: the
empty dais and simple door panel do not communicate a meaningful consequential
funerary scene. No further approval is added for this capture. Staged return
readiness was 15,021.8 ms, also red; normal Continue-to-Assembly was 5,558.6 ms.

## Unchanged Hart Review

`.release-gate/pres001_missing_interior_finale_20260930/` also contains current
Hart day/night frames. The native stag and approach remain visible at night;
day/night sun/moon exclusivity passes the captured state. The scene's broad
flat clearing, synthetic horizon and sparse finale composition remain rejected.
These are not new ending, aftermath or creature acceptance claims. No Hart
runtime source changed during this pass.

## Remaining Blocker And Next Action

Freeze these scoped architectural/readability cells. WORLD-002 still needs
moving Halvern duel evidence, a clear story focal/aftermath composition based
on the now-reviewed peaceful state, and unresolved wilds/Record Hall/finale cells. Do not
repeat the rejected dark relief, archive-density, quarry, berm or torch families.
PERF-001 remains parked after the documented async-cache failure; cold zone
arrival and final browser/campaign/performance proof remain unaccepted.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use the
existing Godot 4.6.3 installation:

```powershell
& 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_undercroft_vault.gd
```

For the graphical art-only view, use an isolated QA profile under
`D:/Temp/AshenOath` and the `capture_pres_001.gd` fixture with
`--views=Undercroft_Day,Undercroft_Night`, a fresh
`--output-dir=res://.release-gate/<unique-run>` and the preserved reference report.
Do not overwrite this evidence or mistake the staged fixture for player input.

No commit, push, merge, deployment or production update was made.
