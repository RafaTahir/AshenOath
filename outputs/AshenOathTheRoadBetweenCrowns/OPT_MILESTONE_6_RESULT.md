# Milestone 6 - HUD, Audio, Saves and Progression

OPT-041 through OPT-048 are implemented and compiled. No runtime, listening,
visual or performance acceptance is claimed.

- OPT-041: unchanged health/stamina/XP/target text and equipment presentations
  avoid redundant writes. Equipment keys include the actual input bindings;
  remapping/device changes still refresh them. XP remains isolated from health.
- OPT-042: journal sections, evidence/details, growth summaries, item details and
  vendor stock reuse bounded data models keyed by their real service change
  signals and context. Cached data is copied for callers. Journal buttons reuse
  keyed controls, update text/availability and discard old action callbacks.
  Reading/selection/focus restoration stays with the existing navigation owner.
- OPT-043: SVG bar textures, dialogue styles and bounded subtitle measurements
  are cached. Font/metrics/padding work skips unchanged values. Width, font,
  accessibility, safe-area and screen changes retain existing responsive reflow.
- OPT-044: recorded cue metadata no longer eagerly decodes the complete library.
  Menu/opening/region preparation primes required groups; late audio-pack mounts
  retry previously requested recordings. Authored overrides and fallbacks remain.
- OPT-045: approved dialogue lines and nearby performances reuse owned players.
  Stop/reuse resets stream, pause, pitch and actor references; cancellation keeps
  the existing short release fade. Retiring players cannot finish the next line.
  Queues, ducking, subtitles and production voice approval rules are unchanged.
- OPT-046: the existing prepared audio bank compiles losslessly into menu,
  opening/shared and campaign stream resources plus a small lazy index. PCM,
  formats and loop points are not re-encoded. The original bank is retained as
  source but excluded from Web packs; each generated stream has one pack owner.
- OPT-047: each save still builds/serializes its snapshot once. Exact-byte caches
  reuse parsing, migration, journey tokens and summary work. Every read still
  reads actual storage; atomic temporary readback/rename, recovery copies,
  specific Continue selection and browser durability flow are unchanged.
- OPT-048: resolved boss/quest/discovery claims skip repeat reward work; return
  rules are indexed by zone. Restoration batches change signals. Same-frame XP
  notices coalesce all earned amounts, labels, levels and Marks; claim IDs and
  save state remain authoritative, with no new grants or changed reward balance.

## User Checks

1. Check damage, stamina, XP/level/Mark gains, purchases and remapped quick counts.
2. Reopen journal/evidence/growth/shop pages after real state changes; inspect
   selection, reading position, updated prices/counts and short-screen focus.
3. Check opening and campaign music, footsteps, combat onset, voices/interruption,
   pause, mix persistence and subtitle-only fallback where voice is unapproved.
4. Save, reload and Continue the exact journey; inspect recovery copies, XP,
   supplies, settings, first arrivals and meaningful returns without repeat XP.

## Build / Publication

Production build: `opt-m6-20261018-600d7c5`.
Manifested artifacts: 104220981 bytes. Complete `web/`: 104228813 bytes, strictly
below 104857600 bytes. Root PCK: 6302792 bytes; SHA-256
`49c2c2ea0895734cadab039700e02aa701714da2329e320d4f4335dbd39187ce`.
Script compilation, all asset compiler steps and the existing production package
builder completed. The audio compiler preserved 50 cues, 20 music streams and
12 ambience streams. Publication uses OPT-048; its local receipt records the
resulting commit/deployment, with user acceptance explicitly pending.

No tests, game launches, browser QA, screenshots, benchmarks, post-deployment
smoke requests or listening review have been performed. All 40 remaining ticket
implementations (OPT-009 through OPT-048) are present; OPT-035/037/038 remain
opt-in comparisons, OFF by default until the user's retention decision. This
does not promote any of the 48 tickets to formal user acceptance.
