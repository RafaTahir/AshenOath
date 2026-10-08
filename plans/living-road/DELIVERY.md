# Living Road Delivery

Canonical root: `D:\Projects\AshenOath`. Game root:
`outputs/AshenOathTheRoadBetweenCrowns`. Development branch:
`codex/masterpiece-rebuild`. Runtime testing belongs to the user.

## Ordinary Ticket

Current user amendment (2026-10-08): keep LR-009 onward local, with one combined
push/main integration/Vercel deployment after LR-028. This overrides the original
per-ticket cadence. The LR-009 build already in flight may finish locally; no
further intermediate export is required. The publication commands below are for
the final combined release only, unless the user explicitly requests otherwise.

1. Implement only the active ticket and directly required callers/data.
2. Review the source diff, save compatibility, interruptions and actual ownership.
3. At the final combined delivery, build once with the pinned production exporter below.
   Compiler/dependency errors may be repaired and the build retried. Do not launch
   the game/browser or run QA after compilation. Voice generation is opt-in only.
4. Write the result: changes, saved-state migration, exact limitations and the
   ticket's short manual checklist. Enumerate authored commit paths explicitly.
5. After LR-028, publish source and aligned Web output with the publisher below. It checks static
   hashes/pack identity and the complete 100 MiB budget, commits explicit paths,
   pushes development/main without force, and deploys only the committed static
   site. It does not update the historical story branch or execute the game.
6. Before final publication mark completed tickets `implemented_local_awaiting_user`.
   At final publication, record the returned commit/deployment receipt and live URL. Mark
   `published_awaiting_user`; only a user verdict changes acceptance. Continue the
   next sequential ticket under the renewed active-goal authorization, preserving
   all pending manual checks. Fix a reported defect before proceeding.

Build, when runtime changes require it:

```powershell
Set-Location 'D:\Projects\AshenOath'
& '.\outputs\AshenOathTheRoadBetweenCrowns\tools\build_story_release.ps1' `
  -OutputDirectory '.release-gate/LR-NNN-unique-build' -BuildId 'lr-NNN-unique-build'
```

Replace the placeholders with the actual ticket and a fresh build name. The
builder preserves prior output and copies the new complete package into `web/`.
It also refreshes the runtime-pack candidate ledger with the selected export.
All generated files changed by this build must be included in the ticket commit.

Publish the prepared artifact and explicitly selected source:

```powershell
$ticketPaths = @('web', 'plans/living-road', '<exact changed source paths>')
& '.\outputs\AshenOathTheRoadBetweenCrowns\tools\publish_living_road.ps1' `
  -Ticket 'LR-NNN' -Message 'LR-NNN: concrete completed change' -CommitPaths $ticketPaths
```

Do not use the literal placeholder path. `build_story_release.ps1 -Publish` may
also invoke this publisher when supplied `-Ticket`, `-PublishMessage` and
`-PublishPaths`; it includes generated build paths automatically. This is the
same operation, not an additional deployment.

## Boundaries And Recovery

- Keep all project/scratch output on D:. Installed tools and Codex global data may
  remain on C:. Do not touch the original C: worktree or rollback copy.
- `publish_living_road.ps1` requires this D: branch to contain remote development
  and main. Divergence requires normal source integration, never force-push.
- The publisher uses explicit paths and `commit --only`; unrelated staging and
  ignored raw assets stay out. Preserve the two pre-existing untracked evidence
  and startup-export directories unless separately authorized.
- Upload staging is an archive of committed `web/` and `vercel.json`, with the
  existing local Vercel project link. Source art/raw files never enter deployment.
- The whole Web directory, including `release_manifest.json`, must be strictly
  below 104,857,600 bytes. Keep roughly 4 MiB contingency where feasible. Exceeding
  the hard limit stops publication before commit; do not reduce content/quality.
- A docs/tooling-only ticket may retain the current artifact and original source
  metadata. It must explicitly say that no new game export was created.
- A local package is not proof of browser decoding, playability or user approval.
- The publisher stores stage/commit/build/source and the Vercel log in
  `.release-gate/living-road/LR-NNN-<UTC>/`. If push/deploy fails, preserve that
  receipt. Resume only the failed stage using its committed site; do not rebuild,
  force-push or claim that deployment succeeded.
- If main is checked out in the existing D: release worktree, fast-forward it
  only while that worktree is clean. A remote main fast-forward never authorizes
  overwriting another worktree's local changes.

LR-001 uses the reconciled lossless GitHub-content package. The new tracked import
settings affect future builds; no runtime input is changed inside that baseline.
Its historical `dirty: true` provenance is deliberately retained.
