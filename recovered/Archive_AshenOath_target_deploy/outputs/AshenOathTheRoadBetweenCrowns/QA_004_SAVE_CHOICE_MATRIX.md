# QA-004 — Complete Save and Choice Matrix

## Coverage
- Exhaustively evaluates 17,496 combinations across report method, shrine state, names policy, Senn, ledger, Edric, Halvern, assembly method, and four endings.
- Resolves epilogue cards for every combination.
- Round-trips story flags and ending cards through the versioned story-state payload.
- Audits campaign and village story choices for explicit flags and quest objectives.
- Runs the targeted quest, dialogue, and save verifiers after the matrix.

## Running
1. Run the game normally with `scenes/main.tscn`.
2. For the automated matrix, run `tools/run_ticket_gate.ps1 -Profiles qa_004`.

## Result
The gate prints the exact permutation count and fails on any missing consequence, mutation, invalid dialogue action, or save regression.
