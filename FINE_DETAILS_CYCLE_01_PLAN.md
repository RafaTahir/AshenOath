# Fine details cycle 01: keep the player's place

Date: 2026-10-03. Starting published package: `f0cdc09`, production deployment `dpl_2VrkF1PdFeBzJUphz6UQoU8jYzuw`.

The continuing authorization is to plan and build improvements autonomously, then push and deploy completed packages, until the user stops the work. This plan is the next implementation cycle after the expanded story release. The user explicitly excludes testing, verification and approval pauses. Production compilation and export will create the deliverable; compiler diagnostics will be handled as build work. No runtime, browser, screenshot, listening, lint, QA or review pass is planned.

## Experience direction

The story remains the center of the game. Menus should let someone consult a name, a promise, a previous conversation or a saved journey, then return to precisely where they left off. Input and notifications should respect the active activity. Startup should explain its progress calmly and hand control to the game cleanly.

Use the existing dark parchment, muted brass and illustrated journal vocabulary. Concentrate on spacing, focus, reading comfort and state continuity. Avoid adding another gameplay progression layer in this cycle. The concrete work below is informed by source code and design judgment; it is not a claim about observed playthrough behavior.

## A. Menu continuity and reading comfort

Owner: player-experience implementer. Files: `scripts/hud.gd`, new `scripts/hud_navigation_state.gd`, new `scripts/hud_notice_queue.gd`, and narrow extensions to `scripts/dialogue_history.gd` and `scripts/save_manager.gd`.

1. Add a bounded record per logical screen containing its parent, selected stable action key, scroll offset, current section and relevant field drafts. Back buttons and Escape follow the same parent. Rebuilding a screen after changing a setting or completing an action restores that screen's place.
2. Extend menu buttons with optional stable focus keys. Retain existing call sites through defaults, and explicitly identify repeated/dynamic actions such as settings, save slots and journal entries. Clamp restoration to visible, enabled controls; choose the nearest sensible row if the old action has disappeared.
3. Preserve dialogue page, subtitle scroll, choice scroll and selected action while reading History. Returning must not emit a second page-change event or append duplicate history. Include History in keyboard/controller focus navigation. Signal `dialogue_review_changed(open: bool)` so the audio layer pauses the current recording and resumes its position.
4. Use consistently padded, wrapped menu rows, a clearly visible focus outline and readable left-aligned prose. Size the subtitle region from available height and chosen subtitle scale; keep choices independently scrollable. Keep useful journal reading space with the chapter atlas present. Honor contrast and motion settings.
5. Replace overwrite-and-discard toast behavior with a bounded notice queue. API: `post_notice(text, category, duration, dedupe_key)`. Retain `toast(text, seconds)` as a compatibility wrapper. Prioritize failed or unavailable actions, retain story updates during dialogue, coalesce routine saves and expire stale combat hints. Place feedback inside an open menu when that menu owns the action.
6. Retain an edited save name and pasted import draft across related screens. Extend save service with `operation_finished(slot_id, operation, success, text)` where needed. Present the operation result with its slot and refresh once while preserving focus. Keep existing save format, backups and copied-state replay semantics.

Sequence: navigation state, dialogue continuity, layout adjustments, notices, then local save feedback. No broad save-serialization rewrite.

## B. Interaction and input continuity

Owner: world/input implementer. Primary files: `scripts/input_router.gd`, `scripts/interaction_focus_service.gd`, `scripts/interactable.gd`; narrow `scripts/mobile_touch_controls.gd`, `scripts/player_controller.gd`, `scripts/camera_controller.gd` and `scripts/story_activity_director.gd` changes when required. Root retains `scripts/game.gd`.

1. Retain a valid interaction target through small camera/player changes, using a short stable-selection window and a clear score advantage before switching. Release immediately when the target is invalid, hidden, unavailable or outside the permitted interaction range. Re-evaluate eligibility on activation; stability must never grant interaction with an unavailable object.
2. Suppress stale gameplay input across menu, dialogue, history, death and zone handoffs. Clear toggled combat states when leaving gameplay. Require release of held attack/interact/confirm inputs before those actions can be accepted again after returning. Keep deliberate movement and configured hold/toggle semantics predictable.
3. Treat focus loss and device changes as explicit input boundaries. Clear pending transient input and touches when appropriate, retain player bindings, and update prompt wording from current device and configured bindings rather than hard-coded default labels.
4. Keep interaction eligibility and world distance authoritative. This pass changes focus continuity and feedback; it does not enlarge reach or auto-select narrative choices.

Concrete APIs: focus retains `choose(...)` and adds `reset()`, `forget(area)`, `target_is_valid(area, player, camera)`, `needs_refresh()`; interactables expose `set_interaction_enabled`, `is_interaction_enabled` and `get_prompt_model`. Input adds `begin_context`, `accept_event`, `suspend_gameplay`, `reset_transient_input` and `describe_action`, preserving existing context wrappers. Player adds `cancel_buffered_input(reason)`. Focus dwell is approximately 150 ms with modest, comparable scoring priorities. Action edges are snapshotted once per physics frame rather than destructively consumed by getters. Toggle guard grants a parry window only when switched on.

Root uses one focused-target snapshot for dispatch and explicit Pause/Back ownership. HUD adds `set_interaction_prompt(model)` with legacy-text fallback. Binding, device and story changes invalidate that model. Keep context APIs compatible with menus and touch controls. No new world polling framework or per-frame world scan.

## C. Browser entry and loading

Owner: presentation implementer. File: `web_boot_shell.html`. Deployment output is regenerated by export; do not manually edit `web/index.html`.

1. Make loading the primary purpose with restrained parchment/charcoal presentation, readable controls, safe-area padding and short-screen scrolling. Put build and low-level diagnostics inside collapsed Technical details.
2. Make Crow Flight optional, with separate play/stop controls and its own score/status. Default to a quiet road scene. Its messages must not replace loading or recovery information. Respect reduced-motion preferences.
3. Present truthful stages: file download with real transfer percent/bytes when known; Preparing Greyfen with indeterminate progress; Ready. Use accessible progress semantics and announce phase changes without repeating every byte update. Do not invent a completion percentage for scene preparation.
4. Scope minigame input listeners to an active visible shell. Cancel decorative animation/gamepad loops at handoff. Release held flap inputs before control can pass to the game. Focus the game canvas only when the document has focus; after background completion offer an explicit Enter Ashen Oath action on return.
5. Preserve startup retry and the Godot opening-recovery menu. Present a primary recovery action with optional reload and copyable technical details. Keep saves and unrelated caches. Connection notices explain interruption while the existing loader remains authoritative.
6. Suspend decorative work while hidden and guard retry UI against stale callbacks. Keep downloads and the existing pack/cache lifecycle unchanged.

Preserve Godot template placeholders, `SHELL_BUILD_ID`, `RUNTIME_PACK_CONTRACT`, hash/cache rules, preloaded pack storage, mount callbacks and the engine/opening readiness contract.

## D. Root integration and release

Owner: root. Files: `scripts/game.gd`, `scripts/runtime_service_registry.gd`, `scripts/audio_manager.gd`, pipeline/export files as needed, this plan and the execution ledger.

1. Move new-journey identity creation and text-history clearing from a New Game request into the accepted, ready world handoff. A queued request, duplicate click or unavailable transition must not reset journey metadata or reading history before a new world starts.
2. Connect History's review state to pause/resume of the existing dialogue audio stream. Clear review pause at dialogue end and page replacement. Keep music ducking and subtitle authority.
3. Route save, quest and inventory signals into appropriate notice categories without duplicating existing messages. Apply the input implementer's explicit host hooks at menu/dialogue/focus/travel boundaries. Preserve existing pause ownership and narrative decisions.
4. Build the English source catalog and production artifacts using the established packaging script. Handle only actual compiler/export failures; do not add verification commands.
5. Commit source changes, build the Web package with a fresh candidate directory, commit generated release files, push both authorized branches and deploy to the existing Vercel project. Record the command result and publication identity. Do not perform post-deployment requests.
6. Keep the continuing goal active. After this package is published, select and write the next justified refinement cycle before implementing it.

## Implementation completion criteria

The scoped code and content changes are implemented, their interfaces are integrated, production import/export completes, and GitHub/Vercel publication commands complete. This is deliberately not a claim that gameplay, accessibility, performance or visual perfection has been verified. The user has excluded those activities for this session.

## Execution record

- Plan written before implementation of this cycle. Independent source-context planning was assigned for HUD, input/interactions and browser entry.
- Root integration implemented: accepted new-journey handoff, History audio pause/resume, categorized notices, explicit Pause/Back ownership, fresh-press interaction dispatch, input boundary callbacks, focus invalidation, structured prompts and binding-aware combat guidance.
- Browser shell implementation completed in source; export remains pending alongside HUD/input completion.
- HUD/menu and input/focus implementation completed. HUD owns bounded screen memory, save drafts/results, reading position, wrapped controls and notice priority; input owns frame snapshots, release barriers, explicit availability and stable focus. All planned root interfaces are integrated.
- Production packaging and publication are next. No tests, verification or review pass has been performed.
- Production import initially reported an uninferred boolean in `input_router.gd`; an explicit `bool` declaration was committed as `a600e3a`. Import then completed and the full pack/Web export proceeded from that revision.
- Production package completed: `story-20261003T112909Z-a600e3a0d5d9`, candidate `.release-gate/fine-details-02`. Push and deployment follow.
- Published as package commit `5cc787f` to GitHub `main` and `codex/story-centered-overhaul`. Vercel deployment `dpl_6Xz2GWt1oXjDxkDyxpPoTAofTyeC` returned `READY`, URL `https://ashenoath-125sso8sn-rafaeitahir-5792s-projects.vercel.app`, alias `https://ashenoath.vercel.app`. No post-deployment checks were performed. This implementation cycle is published; the continuing goal remains active.
