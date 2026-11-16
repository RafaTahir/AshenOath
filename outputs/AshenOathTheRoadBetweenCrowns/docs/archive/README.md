# Historical Verifier Archive

Phase 5 moved 222 unreferenced one-off verifier files here without altering their
bytes. They are historical evidence, not supported entry points or runtime code.
Godot ignores this directory. Archived scripts may depend on their original
working directories, old source contracts or retired evidence; do not run them as
current acceptance gates.

The narrow archive rule in `.gitattributes` disables line-ending conversion for
these snapshots, so their recorded byte hashes survive Windows/Linux checkouts.

`phase5-index.json` records every original path, new path and SHA-256, plus all
183 candidate verifiers retained because a script, workflow or delivery policy
references them. This reverse lookup preserves old report links without rewriting
their evidence. Git history also retains every original file.

The brief's old inventory is not the current tree: no loose project-root
`*_REPORT.json`, `*_MATRIX.md` or `*_CHECKLIST.md` files exist in this baseline.
Current FINISH, Living Cast/Road and WORLD-SAGA plans and their linked results
remain at their existing paths, as do all runtime assets. Referenced legacy
release checks have not been silently replaced by the new simulation suite.

Current source contracts run through `tools/run_checks.py --require-godot`.
They do not establish browser-GPU appearance, audible mix, actual-phone behavior
or reference-PC gameplay performance acceptance.
