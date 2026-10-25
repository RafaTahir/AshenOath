# Ashen Oath Deployment Workflow

`D: source -> local production export -> committed web/ -> Git preview -> staged production -> promotion`

## Current configuration

- Repository: `RafaTahir/AshenOath`; development: `codex/masterpiece-rebuild`.
- Vercel project: `ashenoath`; production branch: `main`; output: `web`.
- Remote build: `echo "Static Godot build"`; no Godot compilation in Vercel.
- Production: `https://ashenoath.vercel.app/`; automatic domain assignment off.
- Budget and boundaries: [DEPLOYMENT_POLICY.md](DEPLOYMENT_POLICY.md).

## Build and publish

Use `outputs/AshenOathTheRoadBetweenCrowns/tools/build_story_release.ps1` for
necessary production compilation. It does not launch gameplay.
Use a fresh output directory under `.release-gate`; preserve previous artifacts.

Publish with `tools/publish_living_road.ps1 -Ticket ... -Message ... -CommitPaths ...`
from the canonical project. Supply explicit source/generated paths; unrelated
staged and untracked work is preserved. The publisher reads the Vercel CLI login
or `VERCEL_TOKEN`, without saving credentials in the repository.

The publisher configures staging, binds a commit and package identity, pushes
development, and waits for that exact Git preview. After HTTP files match,
it checks main has not diverged, fast-forwards main, verifies staged production,
and promotes that deployment. There is no duplicate CLI upload.

Receipts: `.release-gate/living-road/<ticket>-<UTC>/publication.json`.
They record deployments, commit, build ID, encoded/decoded sizes, hashes,
headers, prior production ID, limitations and separate user acceptance.

## Failure and resumption

Do not rebuild/recommit an unchanged candidate after a transport failure.
`tools/vercel_git_release.py` supports `setup`, `bind`, `preview`, `production`
and `promote`, each with `--receipt <absolute receipt path>`. Resume only the
failed step after resolving its recorded error. `bind` is for the original new
candidate, never to disguise changed bytes after preview verification.

If preview failed, do not push main. If production verification failed, do not
promote. Normal fast-forward protections remain. HTTP checks reject missing or
stale files, unexpected redirects, wrong MIME/encoding, decoded pack mismatches
and incorrect cache policy. Deployment protection is not disabled.

If public delivery fails after promotion, roll back to the recorded immediately
previous production deployment, not a destructive Git reset. Hobby permits that
previous deployment. Rollback leaves automatic domain assignment disabled.

## Cache and saves

Keep `vercel.json` headers/rewrites: gzip PCK/WASM/engine script delivery,
immutable content-addressed engine and pack URLs, and revalidated mutable roots.
Changing a pack regenerates its identity; policy changes do not clear saves or
preferences. Never upload QA exports, credentials, archives or import caches.

Larger packages require successful Git staging. Only the actual delivered size
is proven, not the entire 256 MiB ceiling. No padding is added to prove capacity.

Runtime acceptance remains user-owned: launch, Continue, transitions, input,
audio, visuals and phones. No game/browser tests are part of publication.
