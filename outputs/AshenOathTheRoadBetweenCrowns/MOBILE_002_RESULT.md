# MOBILE-002 - Touch Controls and Mouse Capture Repair

Implementation, production packaging and publication complete. User acceptance pending.
UNVERIFIED - REQUIRES USER TESTING. No game/browser launch, tests, screenshots,
automated gameplay or performance measurements were run.

## Changes

- Use, Pause, Book and More use deferred semantic requests through InputRouter.
  Requests carry context/transient generations; Use carries the displayed target's
  instance ID. Changed focus, loading, transitions or targets cannot activate an
  obsolete interaction. Hardware interaction uses the same game handler.
- Touch combat presses/releases enter the router's frame queues directly, including
  brief taps. Context resets invalidate pending requests; cancelled fingers release
  their actions and toggles. Weapon changes cancel old combat contacts while keeping
  movement/look contacts. A fresh press survives the suppressed Resume frame.
- A genuine gameplay mouse click can capture the pointer and attack/fire. Touch
  emulation cannot capture the camera or become a combat/remapping mouse press.
  Fresh mouse/key presses rearm after a device switch; held menu controls remain guarded.
- Six 52/56 CSS-pixel combat buttons switch between sword and bow. Use has a
  separate contextual button and availability feedback. More exposes weapons,
  draw/sheath, selected supplies/counts, targeting, zoom and adopted Bracken.
- Movement has a small deadzone; button release tolerates thumb drift. Camera
  rotation uses accumulated display-pixel travel rather than a capped per-event
  velocity, preserving camera response across frame rates.
- Touch Aim is a new saved Toggle/Hold preference. It defaults to Toggle so two
  thumbs can move and aim/fire; mouse/controller aiming and existing guard/sprint
  preferences remain unchanged. Previously unwired accessibility options now reach
  their existing settings handler.
- HUD text shares the control layout's free regions. Notices, guidance and status
  occupy that region in priority order. Native GUI touch handling owns dialogue
  buttons and scrolling; mouse emulation for native GUI is explicit in project config.

## Files

`input_router.gd`, `mobile_touch_controls.gd`, `mobile_touch_layout.gd`,
`camera_controller.gd`, `game.gd`, `hud.gd`, `runtime_service_registry.gd`,
`settings_manager.gd`, `project.godot`, and the existing publisher's ticket filter.
The build also refreshed runtime pack manifests/ledgers, retained Bracken resource
serialization and `web/`. Those generated files are included in the package commit.
No gameplay assets or save format were replaced. Existing settings gain only the
new `touch_aim_mode` default; all older saved preferences and bindings remain.

## Delivery

One production build and one combined source/Web publication are authorized by the
approved plan. Compilation and export completed without compiler errors. Package:
`mobile-002-20261008-controls`, 15 Web files, 92,133,124 bytes. Headroom below the
104,857,600-byte limit: 12,724,476 bytes. Build directory:
`.release-gate/MOBILE-002-20261008-controls-build` under the repository.

Stored root PCK: 16,365,294 bytes, SHA-256
`354dcea8924dc24cd860d065e4b4d4ea1861d339bcd2a5ea5fb4490c63cc49bb`.
Decoded root: 19,569,024 bytes, SHA-256
`fbe39f36b3edd2c275b2d1fa6332ef2c09f697f1b0f5d9cf7c00f1cd4edad568`.
Build provenance remains `bf6737c64c7f7e5f3144745dcbcf9a3adb1fd873` plus the working
changes packaged here. Combined package commit:
`6b8de0915c832dfb0954e1a609e4fd6ad940c4ed`, pushed to development and main.
Vercel deployment `dpl_bW5VVx2wdNwwBydKJdVqKzgj8nD1` reports production READY.
Live: https://ashenoath.vercel.app/?v=mobile-002-6b8de09
Receipt: `.release-gate/living-road/MOBILE-002-20261008T055456Z/publication.json`.
The staged site was archived from that commit. No post-deployment runtime or browser
checks were performed; publication is not user acceptance.
All source, artifacts and deployment scratch remain on D:; unrelated untracked
evidence/startup-export directories remain excluded.

## Manual Test Checklist

1. On mobile in landscape, use Anwen, clues, a shop and a door; confirm one correct
   interaction per tap. Move away during a press and check it never uses another target.
2. Move/look/attack together; try short Strike/Dodge taps, Guard/Oath holds and
   cancellation by dragging off the button or switching apps.
3. Select Bow in More, tap Aim, move/look and Fire; switch Touch Aim to Hold and
   try it. Change arrows and switch back to both swords.
4. Try More's draw/sheath, selected supplies, target switching, zoom and Bracken;
   check empty supplies are unavailable and Back/Resume returns to play.
5. Scroll dialogue choices and journal entries, choose one action, rotate/resize,
   then resume. Confirm no clipped controls, duplicate choices or stuck input.
6. On desktop, left-click immediately after New Game, dialogue and Pause to attack;
   aim/fire the bow normally. Menu-closing clicks must not attack.
7. Save/Continue and confirm remaps, Touch Aim and existing preferences persist.

The user owns runtime acceptance, visual fit and tactile feel.
