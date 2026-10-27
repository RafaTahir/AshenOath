# Ashen Oath Deployment Workflow

`D: source -> local production export -> committed web/ -> Git push -> Vercel automatic build/publication`

## Current configuration

- Repository: `RafaTahir/AshenOath`; development: `codex/masterpiece-rebuild`.
- Vercel project: `ashenoath`; production branch: `main`; output: `web`.
- Remote build: `echo "Static Godot build"`; no Godot compilation in Vercel.
- Production: `https://ashenoath.vercel.app/`; automatic domain assignment on.
- Budget and boundaries: [DEPLOYMENT_POLICY.md](DEPLOYMENT_POLICY.md).

## Build and publish

Use `outputs/AshenOathTheRoadBetweenCrowns/tools/build_story_release.ps1` for
necessary production compilation. It does not launch gameplay.
Use a fresh output directory under `.release-gate`; preserve previous artifacts.

Publish with `tools/publish_living_road.ps1 -Ticket ... -Message ... -CommitPaths ...`
from the canonical project. Supply explicit source/generated paths; unrelated
staged and untracked work is preserved. The publisher reads the Vercel CLI login
or `VERCEL_TOKEN`, without saving credentials in the repository.

The publisher enables automatic domain assignment, binds commit/package identity,
pushes development, rechecks main's ancestry, then pushes main. Vercel owns the
builds and automatic production publication. There is no CLI upload, polling,
preview/staged HTTP gate or manual promotion. A completed push is recorded as
`git_push_complete_awaiting_vercel`, not a fabricated verified/live result.

Receipts: `.release-gate/living-road/<ticket>-<UTC>/publication.json`.
They record the submitted commit, build ID, package sizes/hashes, previous live
deployment and separate user acceptance. Provider completion remains unverified
unless it is actually observed; historical HTTP evidence is preserved unchanged.

## Failure and resumption

Do not rebuild/recommit an unchanged candidate after a transport failure.
The normal path uses `tools/vercel_git_release.py setup-auto` and `bind` with
`--receipt <absolute receipt path>`. Do not recommit/rebuild a candidate to retry
a failed push. The older `setup`, `preview`, `production` and `promote` actions
remain for explicitly requested historical staged recovery, not normal publication.

Normal fast-forward protections and static package rejection remain. Vercel
reports provider failures; do not label them successful. Runtime testing stays
user-owned. Deployment protection is not disabled.

If public delivery fails, an explicitly requested rollback may use the recorded
previous production deployment, not a destructive Git reset. Retain automatic
assignment for the user's Git-driven workflow unless explicitly instructed otherwise.

## Cache and saves

Keep `vercel.json` headers/rewrites: gzip PCK/WASM/engine script delivery,
immutable content-addressed engine and pack URLs, and revalidated mutable roots.
Changing a pack regenerates its identity; policy changes do not clear saves or
preferences. Never upload QA exports, credentials, archives or import caches.

Larger packages require a successful Git-triggered deployment. Only an actually observed delivered size
is proven, not the entire 256 MiB ceiling. No padding is added to prove capacity.

Runtime acceptance remains user-owned: launch, Continue, transitions, input,
audio, visuals and phones. No game/browser tests are part of publication.
