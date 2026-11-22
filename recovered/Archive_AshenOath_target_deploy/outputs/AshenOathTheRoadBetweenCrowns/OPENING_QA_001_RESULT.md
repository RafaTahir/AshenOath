# OPENING-QA-001 Result

## Outcome

The cumulative Soul Rebuild opening milestone is accepted for this abbreviated production push. Chrome completed the player-driven opening route from New Game through Sister Anwen, three Wychwood clues, the five-enemy encounter, the bridge return, and the report to Anwen.

## Evidence

- Browser: Chrome, WebGL2, 1280x720 Balanced.
- Route checkpoints: 17.
- Average FPS: 33.0.
- Browser console errors: 0.
- Final zone: Greyfen.
- Web candidate: seven files, 88.73 MB.
- Evidence report: `.release-gate/opening_qa_001_browser_chrome.json`.
- Final frame: `.release-gate/opening_qa_001_browser_chrome_chrome_final.png`.

## Included Fixes

- Real mouse activation and Web pointer-lock recovery for launch, menu, dialogue, gates, and gameplay.
- Real-input route traversal through both Wychwood bridge directions.
- Order-independent first-route clue placement and progression.
- Five-enemy encounter completion and return/report flow.
- Fresh New Game inventory loadout and lower first-pack damage.
- Export inclusion for the approved opening monster and animation resources.

## Deferred

- The measured Chrome 1% low was 13.6 FPS. This abbreviated ticket uses the user-selected average-only 30 FPS gate.
- Browser transition samples exceeded the long-term warm/cold targets.
- Edge, Firefox, full verifier suites, and screenshot regeneration were explicitly skipped for this push.
- These items remain performance and compatibility work for later tickets; they are not represented as passing.

## Running

1. Open `https://ashenoath.vercel.app/?v=opening-qa-001`.
2. Click the launch prompt, then click **New Game**.
3. Speak to Sister Anwen, take the Wychwood Oath Gate, inspect the three route clues, defeat the pack, and return to report.

Local Web build:

```powershell
cd outputs\AshenOath_Web
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Then open `http://127.0.0.1:8787/`.
