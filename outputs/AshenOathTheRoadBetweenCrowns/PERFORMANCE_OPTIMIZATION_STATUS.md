# Performance Optimization Status

## Current Work

- Branch: `codex/masterpiece-rebuild`, physical source on D:.
- Milestone 1: OPT-001 through OPT-008 implemented and compiled; user acceptance
  and actual loading/frame-rate comparisons remain pending.
- Source changes: explicit root/opening/adjacent/campaign ownership; deferred zone
  script/scenery dependencies; immutable engine paths; content-addressed caches;
  shared browser pack transport; independent fetch/ordered mount; foreground
  priority, bounded touch/desktop concurrency and cancellation/retry handling.
- Milestone 2: OPT-009 through OPT-016 implemented and compiled. User acceptance
  remains pending. See `OPT_MILESTONE_2_RESULT.md` for exact scope and package.
- Milestone 3: OPT-017 through OPT-024 implemented and compiled. User acceptance
  remains pending. See `OPT_MILESTONE_3_RESULT.md` for retained ownership.
- Milestone 4: OPT-025 through OPT-032 implemented and compiled. See
  `OPT_MILESTONE_4_RESULT.md`; user acceptance remains pending.
- Milestone 5: OPT-033 through OPT-040 implemented and compiled.
  OPT-035/037/038 are comparison-only and OFF by default, pending
  user retention approval. See `OPT_MILESTONE_5_RESULT.md`.
- Milestone 6: OPT-041 through OPT-048 implemented and compiled. See
  `OPT_MILESTONE_6_RESULT.md`. User acceptance remains pending.
- Formal user acceptance: 0/48. No performance improvement is claimed measured.
- Runtime tests, browser QA, benchmarks and screenshots: not run; user-owned.

## Packaging Boundary

Current build: `opt-m6-20261018-600d7c5`, output
`D:\Projects\AshenOath\.release-gate\opt-m6-20261018\export`.
Manifested Web artifacts: 104220981 bytes. Complete `web/`: 104228813 bytes,
strictly below 104857600 bytes.
Root PCK: 6302792 bytes; SHA-256
`49c2c2ea0895734cadab039700e02aa701714da2329e320d4f4335dbd39187ce`.
Compilation and the existing package builder's static identity checks succeeded.
No game execution or performance measurement was performed.

Publication uses the existing explicit-path OPT-016 release operation. Its local
receipt records commit/deployment outcome. Milestone 2 published as `4bd9df5`;
Vercel reported READY and the production alias was assigned. No runtime smoke
was performed. Milestone 3 published as `2b1a54a`; Vercel reported READY and alias
assignment. Milestone 4 published as `43e3e8c`; Vercel reported READY and assigned
the production alias. Milestone 5 published as `600d7c5`; Vercel reported READY
and assigned the production alias. OPT-048 owns final commit/push/deployment;
the existing `.release-gate/living-road/OPT-048-*/publication.json` receipt records
its exact outcome. No over-budget milestone may be published. No runtime
performance claims are made.
Conditional rendering tickets remain gated on the user's comparison.
User checks startup, traversal, retained visuals and Retry; there is no agent
runtime-acceptance claim. All remaining 40 ticket implementations are present
and compiled. Conditional retention and user testing remain pending and are not
equated with ticket acceptance. There is no further implementation milestone.
