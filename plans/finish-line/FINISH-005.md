# FINISH-005 - Desktop And Phone Usability

Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-001, FINISH-003.
Implementation: existing responsive menus, touch controls and input guards present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

The game can be started, played, paused and resumed on desktop and the user's
actual phone without inaccessible controls, clipped actions or lost input.

## Existing Owners And Evidence

Use existing HUD/layout policies, menu/preparation/journey panels, mobile controls,
input router, settings and interaction-focus service.
[Mobile repair](../../outputs/AshenOathTheRoadBetweenCrowns/MOBILE_003_RESULT.md)
and [PLAYFIX input/UI](../../outputs/AshenOathTheRoadBetweenCrowns/PLAYTHROUGH_REPAIRS_STATUS.md)
remain scoped records. Desktop touch emulation never approves iPhone/WebKit.

## Remaining Conditions And Bounded Repair

- New Game, selected Continue, Resume, save recovery and dialogue choices remain
  reachable on short screens; safe areas and scrolling respect browser chrome.
- Touch targets remain at least 48 CSS pixels in the rendered layout. Simultaneous
  movement/look and Use/combat do not steal each other's touches.
- Use activates the displayed, freshly validated target; irrelevant nearby actors
  cannot hijack it. Keyboard/mouse presses are not swallowed by pointer capture.
- Text, bindings and notices wrap/read cleanly without doubled labels or overlap.
  Keyboard focus is visible and dialogue starts on Continue/first available choice.
- Pause, focus loss, browser restoration, resizing and orientation changes expose
  a recoverable state. An unsafe portrait layout explains how to resume in landscape.
- Remapping, subtitle size, reduced motion and volume survive reload/Continue.
- Check Chrome desktop plus Edge/Firefox startup/input/save compatibility using
  normal actions, not three complete campaigns. Record exact actual phone/browser.
  Unavailable physical controllers stay explicitly untested.

## User Manual Checklist

1. Desktop: use menu, inventory/settings, dialogue and save management by mouse
   and keyboard; remap an action and confirm its label and behavior after reload.
2. Short window: resize, scroll every menu, change subtitle size/reduced motion;
   confirm primary actions and visible focus remain usable.
3. Actual phone landscape: start, move/look together, Use Anwen, fight, pause/resume,
   show/hide browser chrome and rotate away/back; verify recovery and safe areas.
4. Save/restart/Continue on that phone; confirm exact journey and preferences.
5. Repeat opening/input/save smoke in desktop Edge and Firefox; reuse observations
   already gathered for FINISH-001/002 rather than replaying the campaign.

## Delivery Record

2026-10-20 allocation 1/1 completed on finish-line-20261020-repairs
(104,677,915 Web bytes; root transport SHA-256
e518e5e427a2be22e1569d587309812c3e2193fcc9a30feb04eec2da99bc28c8).
Hardware, headed Chrome/Edge/Firefox ran sequentially at 960x540. All three
entered complete Greyfen through mouse New Game, moved by keyboard, blocked
movement while paused and opened the next Settings page. No captured console
errors/warnings. Navigation-to-menu/control: Chrome 53,447/54,699 ms;
Edge 95,549/98,824 ms; Firefox 119,292/128,864 ms. These miss startup goals.

HARNESS failure: its page-publication predicate required every button label to
be unique, rejecting the existing scrollable Back plus pinned Back footer.
Screenshots and all three final UI snapshots confirm page 2 was actually open.
The driver now allows those legitimate duplicates and locates settings through
the current five-page UI rather than assuming obsolete page positions.
No runtime change or rerun followed this failure. Remapping, resize and durable
Continue were downstream of it and therefore NOT verified by this run.

Evidence: D:/Temp/AshenOath/finish-005-20261020/browser.json and its three
failure screenshots. Failed profiles/earned saves retained under D:/Temp/AshenOath;
the driver retired its owned browser processes. Actual phone model/OS/browser,
touch behavior and user verdict remain Pending. This is partial evidence,
not whole-ticket acceptance; no phone check is claimed from a desktop viewport.
Numerical phone performance is reported separately, not judged by desktop gates.

Targeted a17-save: real paused movement blocking, master-volume/subtitle/reduced-
motion changes, 1920x1080 to 1280x720 resize and F9 Interact remapping observed.
HARNESS then expected Resume one parent too early; corrected to remap -> Controls
-> Pause. The same failure image shows a GAME defect: Controls restored keyboard
focus below the visible scroll area. HUD now reveals focused menu descendants
after responsive/menu restoration, preserving reader and draft state.
Replacement candidate compilation in progress. No whole-ticket acceptance;
durability/F9 use, actual phone and remaining input coverage remain pending.

Targeted a23-save: volume/subtitle/reduced-motion/F9 survived durable Quick Save,
reload and normal Continue. a25-wychwood then used that persisted F9 for the real
required Mira conversation, completed her chapel-register briefing, and restored
the original 0.85 volume / 1.0 subtitle / reduced-motion-off / default bindings
through normal UI. Restored Controls keyboard focus remained visible. No captured
runtime/resource/network errors. Nominal orbit yaw had framed the neighboring
well; a real +0.35-radian shoulder-camera adjustment focused Mira. No focus
override, teleport, game export or replayed persistence check was used.
The run later stopped on HARNESS asking Supplies from the journal's On Return
section. Preparation must be opened first; corrected for existing oil/crafting
checks. Inventory follows its authored Tab focus chain; equivalent pinned/list
Close controls are accepted like Back/Resume, not arbitrary duplicate choices.
Actual phone and remaining input/compatibility cases still pending.

The a45 Castle return image shows the concrete duplicate verb "Use Visit the
changed work at Castle". Interactable's existing prompt-prefix table omitted
Visit. It now recognizes that authored verb, preserving the displayed target,
input binding and interaction ownership. This small HUD-text repair is batched
with the required Ruins-road replacement package; no layout/art overhaul.

a54 Chrome completed the formerly driver-blocked 960x540 desktop cells on
finish-line-20261020-ruins-road: real New Game/keyboard movement, paused movement
blocking, settings changes, 1920x1080 -> 960x540 reflow, visible restored Controls
focus, F9 remapping, durable earned Quick Save/reload/normal Continue, remapped
Anwen interaction and original settings/default bindings restoration. No console
errors/warnings. Menu/control 36,548.8/39,290 ms; click-to-control 2,105 ms are
observations, not strict startup passes. Overall strict browser-memory FAIL
606 MiB. Report: D:/Temp/AshenOath/finish-targeted-20261020-a54-chrome-controls/browser.json.
a55 Edge rechecks the same original blocked desktop scope on identical bytes;
Firefox follows. Actual phone remains unverified; no desktop viewport substitutes.

a55 Edge completed the same short-screen movement/pause/settings/reflow/F9/
durable Save-reload-Continue/default-restoration cells, with no console errors/
warnings. Menu/control 34,262.7/36,411 ms; handoff 1,556 ms. Overall strict browser-
memory FAIL 553.7 MiB. a56 Firefox completed New Game, movement, pause, resize,
settings/F9 persistence and normal durable Save/reload/Continue without console
errors/warnings, then stopped before the remapped Anwen action on HARNESS camera
convergence. Its smoke scope intentionally has no live observation binding,
but that camera waiter still required one; one real camera pulse was observed.

a57 tried enabling the existing Firefox callback/probe path and introduced
realm-permission errors (Permission denied to access property length). That
instrumentation candidate is REJECTED; raw errors remain in the report. The
known-clean smoke transport is restored. Camera/dialogue/pointer waiters now use
the existing read-only polling fallback instead of assuming callbacks exist.
No game/engine patch, telemetry expansion, timeout increase or export was made.
a58 resumed the exact earned Firefox profile/origin57755, without New Game or
repeating proven Save/Continue. It ended after 73,921 ms without console errors,
but still failed HARNESS camera convergence (yaw 2.976585307 versus -PI; player
controllable at x=0,z=4.722781). All 36 input packets completed. The extra Anwen
F9/default-restoration cell is PARKED after two failed transport hypotheses;
required Firefox startup/input/save smoke remains observed from a56. The isolated
QA profile and changed preferences are retained, not falsely called restored.
Reports: D:/Temp/AshenOath/finish-targeted-20261020-a55-edge-controls/browser.json,
finish-targeted-20261020-a56-firefox-controls/browser.json and
finish-targeted-20261020-a57-firefox-interact/browser.json.

Existing a49/a53 gameplay captures also exposed clipped objective/route text.
One focused graphical tracker session reproduced the primary-objective defect:
2/4 visible lines at both 1280x720 and 1920x1080. The added caption assertions
passed, but the overall fixture FAILED. The repair sizes primary text using its
wrapped font metrics, retains all objective lines, budgets complete caption lines
and moves nearby-work/footer bounds below them. Relayout is queued only when
primary reading text changes. No styling, scenery, route or quality change.
The first tracker-fit package is INVALID: direct loading found a duplicate local
variable missed by import/export. Rename/direct HUD compilation corrected it.
The next component check showed 3/4 objective lines because glyph height excluded
theme spacing/style padding. The shared height helper now accounts for those
metrics, reserves complete caption/prompt lines, and separates status/prompt bounds.
The focused graphical check PASSED at 1280x720/1920x1080 with 1.0/1.5 text scales,
including visible objective/caption/prompt lines and non-overlap assertions.
Retained warning: existing menu non-equal anchors resized during responsive layout.
Corrected tracker-lines direct HUD compilation/code packs/production export and
lossless manifest checks passed (104,688,152 complete bytes); no whole-ticket/phone/performance
acceptance is implied. Evidence: D:/Temp/AshenOath/finish-caption-20261020-spacing.

a59's current gameplay capture confirms full objective/route lines. It exposed
"Use Sit..." at the bench; static review of the seven authored village-place
labels found omitted Sit at/Draw from/Buy prefixes, repaired together. The
prompt-verbs package compiled/exported below the cap. a62's existing capture
shows the corrected "Sit at the shrine bench" without a duplicate verb; no
additional gameplay run was performed just for these strings. Other appearance/
phone/listening conditions stay unverified. Reports/captures:
D:/Temp/AshenOath/finish-targeted-20261020-a59-growth and a62-quality.

