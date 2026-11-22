# Fine details cycle 07: keep the story within reach

Date: 2026-10-04. Starting production package `62692a9`, deployment `dpl_C5sh21nAQzAEiwoz1xJ2NRqoDCK8`.

This plan precedes implementation. Continue autonomous development and publication. No tests, previews, screenshots, verification, review passes or approval gates. Production generation/import/export and responding to actual command diagnostics remain build work.

## Intended experience

Keep reading, choices and navigation reachable when the game appears in a smaller browser window, on a touch display, or after an input-device change. Preserve Ashen Oath's fixed 1280 by 720 render canvas and current rendering configuration. The UI must use the actual displayed game area to choose readable layouts instead of treating logical canvas size as physical space. Reflow live controls without replaying pages, replacing the current selection, or turning a touch used for a menu into a combat action.

## A. Shared layout policy

The layout owner creates only `scripts/hud_layout_policy.gd`. Pure APIs: `resolve(canvas_size: Vector2, display: Dictionary, text_scale: float = 1.0, input_device: String = "keyboard") -> Dictionary`, and `dialogue_layout(metrics: Dictionary, has_stakes: bool, action_count: int) -> Dictionary`.

Display input uses width/height, inset_left/top/right/bottom, coarse_pointer and revision, all lengths in display units (CSS pixels on Web). Compute one uniform fit into the canvas and intersect safe bounds with the fitted game area. Return valid/mode/compact/safe_rect/unit_scale/display_size/display_usable_size/text_scale/padding/gap/button_min_height/fonts plus per-surface budgets. unit_scale converts display lengths into canvas lengths. No second render/stretch transform.

Wide requires usable display at least 1040 by 600 and room for a 480-times-text-scale reader plus 280-times-text-scale sidebar. Otherwise use compact. Body/button floor 18 display units, caption 16, subtitle 22; default body/button 20 and subtitle 24, respecting existing text scale 0.9 to 1.5. Minimum control height 44, or 48 for touch/coarse input, with wrapping growth. Outer margins 24 wide and 12 compact; panel minima never exceed available width. Remove decorative art before shrinking reading controls.

Journal budgets: frame/compact/reader_height/sidebar_width/footer_height/art_height/notice_height/action_height. Menus: frame/compact/panel_width/panel_height/content_width/footer_height/outer_scroll. Dialogue: frame/header_height/reader_height/stakes_height/choices_height/outer_scroll; reserve three subtitle lines, two stakes lines when present and one full action where possible, otherwise scroll the body beneath a fixed header. Loading: frame/content_width/footer_height. These are layout rules, not claims of measured accessibility or perfect fit on every device.

## B. HUD integration

The presentation owner edits only `scripts/hud.gd`. Add `set_display_metrics(metrics: Dictionary)` and coalesce deferred reflow on display/device/text-scale changes. Keep references to existing containers, mutate geometry/fonts in place, and remove the separate native 1920 by 1080 menu scale. Do not invoke show_* content reconstruction just because the viewport or device changed.

Wide journal keeps reader and entries together. Compact journal uses one live reader/list pane with reachable Read/Entries/Close navigation. The evidence Back trail retains priority; selecting an item or evidence enters the reader. Preparation actions wrap or stack and remain scrollable within the budget. Preserve current selected entries and model ownership.

Dialogue and optional topics keep speaker/page/History/Back in a fixed header. Size reader, stakes and choices through the shared policy; use an outer body scroll when their minimum budgets cannot fit. Preserve release activation and cancel any pending dialogue press before geometry moves beneath it. No page/history/receipt signals during reflow.

Main/pause/death/nested/save/History menus use constrained cards and compact scrolling with reachable existing Back/Resume controls. Loading messages wrap within the safe frame; Cancel availability still follows the prepared/applying boundary. Retain current contrast and reduced-motion behavior.

Before reflow, retain active focus key, scroll positions, editable caret/selection and compact pane. Restore after layout with a generation guard. Keep live page/topic/evidence/preparation/slot IDs and current drafts, not copies of story content. Handle native fallback display metrics until the root bridge supplies current information.

## C. Touch geometry and ownership

The world/input owner edits `mobile_touch_controls.gd`, creates `mobile_touch_layout.gd`, and makes narrow `input_router.gd` changes. Add mobile `set_display_metrics(metrics)` and public `cancel_active_touches(reason)`. The pure touch builder consumes shared layout scale/safe bounds and returns canvas-coordinate actions, movement/look regions, reserved rectangles, playable/reason and bottom_reserved_display.

Combat fit requires landscape display and at least 560 by 300 usable display units. Use the existing nine gameplay actions in an ordered three by three group with 60-unit pitch, radius 24 (Strike 28), movement radius 56/travel 44/knob 22. Keep separate 48-unit Pause and Journal targets with 12-unit separation. Below the fit budget or in portrait, retain navigation and a truthful rotation/space instruction; release combat instead of shrinking targets indefinitely. Preserve gameplay balance and existing actions.

Cancel touches synchronously before geometry/surface/settings/focus/device changes. Retain cancelled finger IDs until release or a genuine new down; never accept a drag without an owned down. One owner per finger; duplicate touches on one action use first-down/last-up semantics. Dragging outside an owned button cancels rather than transferring ownership. Interact/Pause/Journal commit on release inside the original target. Combat holds/toggles retain existing semantics.

Actual touch chooses touch prompts in UI too. Activate virtual-input device before storing finger ownership so device-reset signals cannot erase the new owner. Ignore emulated mouse events for gameplay caching/device selection while allowing ordinary GUI delivery. Touch gameplay snapshots use virtual/accepted touch edges, not globally emulated mouse presses. Real keyboard/controller activity still selects its source through existing release barriers; sub-deadzone stick noise does not steal the device. Virtual cancellation preserves barriers that still correspond to held physical bindings. Auto overlay follows intentional active device; On/Off retain their meanings. Never claim non-gameplay UI fingers.

If the touch combat layout becomes unusable during gameplay, pause through the existing menu so the world does not continue attacking while controls are unavailable. Mobile exposes `gameplay_layout_reason()`, emits `gameplay_layout_unavailable(reason)` on each actual entry into unusable visible gameplay, and emits `gameplay_layout_reason_changed(reason)` when the reason changes or clears, including while paused. Root pauses once, keeps an explanatory line in Pause, and guards touch-only Resume until space or input device is suitable. A blocked Resume from another reading surface opens Pause rather than leaving a hidden paused screen. Restoring geometry does not resume automatically. HUD updates this reason in place through `set_touch_layout_reason(reason)`; no new modal or approval prompt.

## D. Browser/native display bridge and release

Root owns `web_boot_shell.html`, new `scripts/display_metrics_bridge.gd`, registry integration, ledger and build publication. Publish `window.__ashenOathDisplay` with CSS canvas dimensions, safe/visible insets, coarse_pointer and a revision. Coalesce real geometry/viewport/media changes and dispatch `ashen-oath-display` only when values change. Keep CSS dynamic viewport sizing and safe-area measurement separate from game content. Retain boot progress, optional Crow Flight, loading recovery and its input-release handoff. No synthetic gameplay input or external telemetry.

A small always-processing Node listens for that browser event using a retained JavaScript callback and forwards the current dictionary to HUD/mobile APIs. Use actual native window geometry as fallback; retain/disconnect listener ownership on shutdown. Do not poll the bridge every frame or rebuild world services on resize. Initial delivery occurs after HUD and touch setup. Root will coordinate any extra narrow handoff needed by actual integration.

Commit integrated source, build fresh cycle07 production candidate with `-Publish`, resolve actual compiler/publishing diagnostics, and record returned outcomes. No new spoken content or voice generation. The user's final direction sets this release as the endpoint: finish the current written scope, push and deploy, list all delivered changes, and stop. No further improvement cycle follows.

## Execution record

- Resumed after an interruption; authoritative worktree remained at `62692a9` with only release-ledger changes and a prior generated candidate manifest. All three packages were still at planning stage. This combined plan was written before Cycle07 source changes.
- Root implemented `display_metrics_bridge.gd`, registry setup and explicit shutdown. It forwards normalized changed geometry to touch first and HUD second, uses a retained browser callback with native-window fallback, and performs no frame polling. The browser shell publishes canvas/safe/visual-viewport metrics, adopts dynamic viewport sizing, wraps loading stages and increases coarse-pointer target heights.
- The shared layout policy has landed. Before further implementation, the HUD owner split live reading-state retention into a new `hud_reflow_state.gd` helper owned by the layout implementer: `capture(root)` and `restore(snapshot, root)` retain weak control references and numeric focus/scroll/edit positions only. HUD keeps deferred generation guards and fallback focus. This parallel split preserves the agreed scope and stores no story/text snapshots.
- The reflow-state helper is implemented. Root also connected current touch-layout reasons to Pause and guarded Resume against unusable touch geometry, leaving geometry/device recovery under explicit player Resume. HUD and touch packages are completing their corresponding layout/input work.
- Touch/input implementation has landed: shared safe geometry, original-display portrait handling, explicit finger ownership and cancellation, release-inside navigation, emulated-mouse isolation, actual-deadzone device selection, transient look consumption, loading/surface exclusions and layout-reason signaling. HUD integration remains before source commit and production packaging.
- HUD implementation is integrated: one deferred policy reflow, compact journal reader/entry panes with persistent navigation, stacked preparation actions, fixed dialogue navigation with short-layout body scrolling, constrained menus and loading surfaces, live focus/scroll/edit retention, and touch-aware placement of critical vitals and prompts. Pause displays the current touch-layout reason and prevents unsuitable Resume without resuming automatically after recovery.
- All seven refinement cycles now have their planned source implementation. Final production packaging and publication remain before delivery. A consolidated final changelog records the delivered story package and refinements; no further cycle will start.
- Final production completed: source `0297582170b5`, build `story-20261003T185007Z-0297582170b5`, candidate `.release-gate/fine-details-cycle07-01`, package `5a27c7c`. Import, seven packs and Web export completed; both GitHub branches were pushed. The initial Vercel command returned `Not authorized`; the existing signed-in CLI succeeded on direct retry with no repeated export. Deployment `dpl_Ag4e31kFjbxMhyZLJcPbnPSpGvBi` returned `READY` and production alias `https://ashenoath.vercel.app` (87.9 MB uploaded). No tests, previews or post-deployment checks were run. `FINAL_DELIVERY_CHANGELOG.md` records the consolidated changes. The requested endpoint is reached; no further cycle follows.
