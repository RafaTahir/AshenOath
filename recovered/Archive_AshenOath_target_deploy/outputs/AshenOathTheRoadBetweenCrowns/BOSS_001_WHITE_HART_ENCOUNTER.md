# BOSS-001 — White Hart Encounter

## Result
- Witness and Mercy remain valid noncombat endings.
- Duty and Ash now create a centered, locally leashed White Hart encounter.
- The Hart has three health phases with readable pacing, audio, status, and impact feedback.
- The chosen covenant is applied only after combat victory and pending state is cleaned up.

## Running
1. Run `scenes/main.tscn` in Godot 4.6.3.
2. Reach the Hart Glade after Greyfen's assembly.
3. Choose Duty or Ash for combat, or Witness or Mercy for a peaceful resolution.

## Verification
Run `tools/run_ticket_gate.ps1 -Profiles boss_001 -ChangedViews boss_001`.
