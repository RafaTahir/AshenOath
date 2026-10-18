# Milestone 2 - Resource, Data and World Preparation

OPT-009 through OPT-016 are implemented. Build compilation/package outcome is
recorded below after the milestone build. Runtime behaviour and performance are
UNVERIFIED - REQUIRES USER TESTING. No formal user acceptance is recorded.

## Implementation

- OPT-009: native file-backed pack transport and metadata-only browser promises
  from Milestone 1 are retained; completed filesystem waits release their abort
  listeners, including cancellation before the listener was installed.
- OPT-010: assets, textures and zone preparation share one threaded resource
  request per path with separate consumer claims. Completion is consumed once;
  cancellation does not discard another consumer's resource. Shutdown drains
  outstanding engine-owned requests before releasing the final owner.
- OPT-011: packaging compiles the existing dialogue sources losslessly into
  per-scene JSON and a small source-order index. Opening/shared overrides retain
  their precedence; campaign pages are decoded on first use, not at menu setup.
- OPT-012: settings changes affect only their owning domains. Audio adjustment
  does not rebuild input bindings or cancel touch controls; new player/camera/
  lighting instances receive settings even when values did not change.
- OPT-013: Greyfen's merged ground, integrated banks and three road meshes are
  compiled from the existing authored core and unchanged geometry routines.
  Runtime retains all existing collision and presentation/material ownership.
- OPT-014: mill paths, distant bank, approach ramps, Record Hall vault/ribs/floor
  and undercroft roof collision are compiled ahead of packaging. Existing baked
  architecture, dynamic encounters and aftermath layers remain unchanged.
- OPT-015: world builders record the story-flag and quest records they read.
  Cache signatures use those zone dependencies; direct dictionary access and
  unobserved first builds conservatively include the full bucket. Other story
  values/evidence and shared quest flags remain conservative dependencies.
- OPT-016: neighbor preparation loads real scene layers and/or builder resources
  after required packs mount. Empty paths no longer produce a ready/null result.
  Scene activation shares the same request owner. Cancellation retires claims;
  inactive polling sleeps, and pack failure is explicit rather than false-ready.

No claim is made that the entire world is a single baked scene, that PCKs can be
unmounted, or that measured FPS/loading time has improved. These are bounded
implementation changes, not a new world/streaming engine.

## User Checks

1. Launch, Retry, New Game and Continue at each existing quality preset.
2. Change volume while moving/touch-dragging; controls should not reset.
3. Compare Greyfen's ground/banks/roads and campaign vault/mill surfaces.
4. Visit and return across neighboring sectors, including cancelled transitions.
5. Check opening reports, shrine decisions, campaign dialogue and consequence
   changes after save/reload. Compare actual load time and process memory.

## Build / Publication

Build-only production package: `opt-m2-20261018-ec924ab`, final directory
`D:\Projects\AshenOath\.release-gate\opt-m2-20261018\final-export`.
Compilation succeeded. Manifested artifacts: 90431468 bytes, below 104857600.
Root PCK: 9008910 bytes; SHA-256
`14d9000274c4713c6c9bb8a7fa2981ab5e1a07517a78cd66884a4b8859bc78f1`.
Static review corrected a missing targeting-assist invalidation key; the root
was repackaged with unchanged asset packs. A Windows rename collision during
packaging was fixed with atomic replacement of the identical addressed engine.
No game, browser, benchmark, test fixture, automated gameplay or screenshot
capture was run by the agent. Publication uses the OPT-016 release receipt.
