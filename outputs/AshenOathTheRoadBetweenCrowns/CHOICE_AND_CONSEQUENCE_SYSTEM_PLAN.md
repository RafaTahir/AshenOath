# Choice And Consequence System Plan

## Design

Use explicit flags for authored outcomes plus three bounded integers. Do not build a branching graph or generalized reputation framework.

- `anwen_trust`: -3 to 3. Controls candor, shrine access, and finale participation.
- `greyfen_fear`: 0 to 6. Controls ambient dialogue, crowd stability, lights/doors, and encounter pressure.
- `hart_debt`: -3 to 6. Measures how much memory has been redirected, exploited, or restored.

Values modify presentation and available methods; they never silently determine an ending. Final endings remain explicit player choices whose costs depend on prior state.

## Ten Major Choices

| Flag | Options | Immediate Result | Later Echo |
| --- | --- | --- | --- |
| `evidence_report` | private / public / retained | Anwen or board reaction | Shrine access, public fear, token leverage |
| `crow_shrine_state` | cleansed / disturbed / bound | Shrine appearance and blessing | Hart debt, chapel memories, enemy staging |
| `bog_core_fate` | destroyed / studied / buried | Mira reaction | Medicine supply, Wretch variant, debt |
| `names_policy` | publish / withhold_until_safe | Public notices or hidden register | Crowd stability and finale testimony |
| `mill_fate` | closed / cleansed / warned_open | Mill props and food dialogue | Rations, prices, civilian support |
| `senn_fate` | witness / imprisoned / killed | Camp aftermath | Castle route and testimony strength |
| `edric_stance` | cooperate / expose / compel | Guard and castle state | Edric finale participation |
| `halvern_fate` | freed / questioned / bound / destroyed | Knight aftermath | Ledger credibility and debt |
| `confession_method` | voluntary / immediate / coerced | Assembly tone | Final witness composition |
| `final_covenant` | witness / mercy / duty / ash | Ending transformation | Epilogue |

## Twenty Minor Choices

1. Accept the Road contract from the board or directly from Anwen.
2. Pay Rook for a rumor or earn it through a clue.
3. Return Bram's tool to his family or keep it as evidence.
4. Speak Oren's scratched name aloud or preserve uncertainty.
5. Use Iron Trap preparation or enter the clearing immediately.
6. Tell Elna the full truth, a merciful account, or let Harl's token speak.
7. Light the first memorial candle or leave it dark.
8. Give Mira the Bog core or retain it.
9. Disclose Mira's garden or permit regulated use.
10. Ask Tor to make memorial nails or practical tools.
11. Melt a named iron object or preserve it.
12. Kill, relocate, or tolerate Toma's Stalker.
13. Give Oren's charm to Rook, shrine, or family.
14. Copy Rook's map for Anwen or keep it private.
15. Heal the wounded levy or interrogate him untreated.
16. Enter Senn's camp by trap, challenge, or hidden route.
17. Return Halvern's sword to the crypt or carry it publicly.
18. Protect Anwen during the assembly or force her to stand alone.
19. Offer Edric a protected confession or demand immediate surrender.
20. Place Kael's old oath badge among the memorial names or keep it.

## Storage Shape

Later implementation adds this optional save block:

```json
{
  "story_state": {
    "version": 1,
    "flags": {"evidence_report": "private"},
    "values": {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
  }
}
```

Quest completion and clue discovery remain in existing quest state. Only consequential decisions belong in `story_state`. Cosmetic motion is not saved.

## Dialogue Conditions

Dialogue variants support simple all-of predicates only: required flags, excluded flags, objective done, quest active/completed, item present, and minimum/maximum value. Resolution chooses the most specific valid variant, then falls back to the base text. No nested boolean expression language.

## Visible Consequences

- Public fear closes shutters, reduces night foot traffic, and adds guard/fire props.
- Shrine state changes candles, smoke, color, and Anwen staging.
- Published names appear on notice board and memorial markers.
- Mill and forge choices replace working/broken/restitution dressing.
- Enemy choices leave corpses, cleared residue, or altered future spawn sets.
- NPCs relocate to cemetery, assembly, castle, or glade based on explicit flags.

## Explosion Control

- Each quest owns at most one major flag and two minor reactions.
- Later dialogue reacts to categories, not every historical combination.
- Three values select tone and pressure; explicit flags select facts.
- Optional witnesses contribute interchangeable testimony strength while retaining unique epilogues.
- Every unavailable NPC has a document/token fallback.

## Save Compatibility

Missing `story_state` creates version 1 with neutral values. Existing completed objectives seed only facts that are unambiguous: completed first encounter sets `road_pack_defeated`; it does not guess an evidence choice. Old saves receive a one-time report choice when next speaking to Anwen.
