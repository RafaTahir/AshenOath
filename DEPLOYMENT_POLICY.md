# Ashen Oath Deployment Policy

Current policy: `vercel-git-256mib-v1`, approved 2026-10-25.

The canonical numeric policy is
`outputs/AshenOathTheRoadBetweenCrowns/data/deployment_policy.json`.
Packaging tools, generated manifests and current release checks consume it.

- Complete deployed `web/`, including its release manifest: strictly below
  268,435,456 bytes (256 MiB); warning at 209,715,200 bytes (200 MiB).
- Each committed file: strictly below 104,857,600 bytes (100 MiB).
- The aggregate ceiling is an internal working budget, not a Vercel guarantee.
  Only successfully delivered candidate sizes are recorded as verified.
- Source uploads, encoded deployment bytes, decoded resources, initial-download
  dependencies, process memory and monthly transfer are separate quantities.
- Vercel Hobby remains unchanged. No paid services, migration or loss of content,
  population, visual quality or performance requirements is authorized.

## Publication

Use the existing `ashenoath` project, `web` output and Git integration. Work on
`codex/masterpiece-rebuild` in `D:\Projects\AshenOath`.

1. Package the production preset locally; validate the exact committed files.
2. Push development and verify the Git preview for that exact SHA over HTTP.
3. Fast-forward `main`; verify staged production before promotion.
4. Promote those staged bytes and verify public delivery on the existing origin.

Auto-assignment of production domains is disabled. Neither a Git push nor a
successful static build alone is publication approval. There is no CLI source
upload or remote Godot rebuild. Protected previews remain protected; automation
credentials never enter source, logs or URLs.

Missing assets, stale manifests, wrong hashes/encoding, failed deployments or
concurrent releases block promotion. Keep the immediately previous production
deployment available for Hobby rollback. No force push or history rewrite.

## Evidence and limits

Gameplay, browser QA, listening and performance acceptance remain user-owned.
Compilation, package checks, HTTP identity and user acceptance are separate.
HTTP inspection does not execute the game.

Hobby includes 100 GB fast data transfer per month, independently of this package
budget, and is restricted to personal/noncommercial use. Receipts do not invent
usage readings when account usage has not been measured.

Historical reports retain their original limits. This policy supersedes older
milestone-only instructions and universal 100 MiB assertions for new packages;
it does not retroactively change historical acceptance.

References: https://vercel.com/docs/limits,
https://vercel.com/docs/git,
https://vercel.com/docs/deployments/promoting-a-deployment,
https://vercel.com/docs/plans/hobby.
