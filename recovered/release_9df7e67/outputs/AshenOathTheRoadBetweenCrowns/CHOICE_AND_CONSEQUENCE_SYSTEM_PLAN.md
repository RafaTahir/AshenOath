# Authored choice and consequence — version two

## Storage and meaning

Keep explicit flags and the bounded `anwen_trust`, `greyfen_fear`, and `hart_debt` values. Values influence presentation and pressure, never silently choose a final ending. Quest completion and evidence discovery remain separate from irreversible decisions. Inspecting a clue cannot consent to its treatment.

Playable actions use existing `story_choice`, `start_quest`, `complete_objective`, ingredient, and `ending` types. Major decisions have `preview`, `cost`, and `result`. The intended action must be understandable before it commits. Dialogue variants use existing all-of conditions and authored priorities; no generalized branching graph is required.

## Main choices and ownership

| Decision | Canonical flags | Facts that must survive |
| --- | --- | --- |
| Opening report | `evidence_report=private/public/retained`; `kael_pledge=protect/account/stay`; `cemetery_bell_rung=true`; `legacy_report_choice_required=false` | Explicit `return_village` action, not auto-commit on touching an NPC or board |
| Shrine | `crow_shrine_state=cleansed/disturbed/bound`; `covenant_rules_known=true` | Each method redirects, releases, or temporarily contains; none erases debt |
| Bog fragment | `bog_core_fate=destroyed/preserved/returned`; `crisis_cause_known=true`; `mira_truth_known=true` | Formula access survives every choice; destroyed fragments disperse memory |
| Names | `names_policy=published/withheld`; `renewal_announced=true`; `crisis_cause_known=true`; `protected_family_addresses=true` | Recovered names are distinct from family addresses and consent |
| Mill | `mill_operation=closed/supervised/restitution`; legacy `mill_fate=preserved/burned/exposed`; `mill_records_preserved=true` | `burned` refers to replacing a contaminated working sheet after copying; command and signed evidence survive |
| Senn | `senn_fate=testimony/exile/punished`; `senn_account_recovered=true`; `witness_consent_senn=voluntary/refused` | Testimony means custody with freely given account; punished remains execution, not renamed imprisonment |
| Edric | `edric_stance=cooperate/exposed/compelled`; `witness_consent_edric=voluntary/refused/compelled`; `renewal_announced=true` | Compelled admissions establish facts only; protection cannot retain immunity for the title |
| Ledger | Existing open/hidden/left-copied flags plus `command_ledger_copied=true`; `command_proof_recovered=true` | A credible command copy is guaranteed |
| Halvern | `halvern_fate=witness/released/destroyed`; `halvern_is_fragment=true`; `kael_confessed=true`; `command_proof_recovered=true` | Preserved fragments are not voluntary living ritual support |
| Assembly | `confession_method=witnesses/kael/edric`; `renewal_stopped=true`; `assembly_relief_ready=true`; `kael_confessed=true` | Remove ration condition first. Compelling Edric sets his consent to compelled. Other routes retain explicit prior consent |
| Finale | Existing ending IDs `expose/free/bind/kill`; `final_covenant=witness/mercy/duty/ash` | Each is an explicit resolution with no optional-witness gate or hidden substitution |

## Optional lives

| Story | Explicit outcomes | Consent and concrete result |
| --- | --- | --- |
| Bitter Roots | `mira_truth=kept/confessed/destroyed`; `mira_treatment=private/consented/replacement`; `mira_truth_known=true` | Families can refuse and still receive care. Mira separately chooses her own assembly account. `bitter_roots_collected` gates the collection hand-in; `study_roots` is optional inspection |
| Iron Remembers | `iron_fate=memorial/tools/surrendered` | Tor voluntarily speaks while gradual replacement or ordinary scrap keeps essential preparation available |
| The Road That Bends | `rook_map_fate=preserved/destroyed`; `rook_disclosure=protected/public/erased` | Protected route copies set consent voluntary; public family marks or destroyed map set consent refused |
| A Widow's Bell | `widow_truth=told/comforted/private` | Elna chooses voluntary public account or refusal. Her husband's act remains documented in all routes |
| Black Dog | `black_dog_fate=spared/killed`; `guardian_plan=relocated/supervised/killed` | Boundary, disclosed watch, or settled protection fragment; legacy hidden saves remain concealment, never automatically supervised |
| The Bannerless | Existing `bannerless_fate=testimony/shielded/assembly` | Refusal record corroborates the order; protected homes are not evidence withheld from accountability |

Four interludes keep existing IDs: the returned soldier, Oren's thread, the ash measure, and three candles. `returned_soldier_is_fragment=true` prevents presenting his record as a living promise.

## Practical work

`cart_helped`, `road_repaired`, and `assembly_relief_ready` record explicit help. `mill_distribution` is read-only after the main mill choice; it cannot overwrite a committed operation. Public proclamation may set `renewal_announced`; reading the renewal record supplies an explanation, never a signature.

## Consent contract

`witness_consent_*` records voluntary, compelled, or refused; absent flags remain unknown. Rook's protected voluntary participation is represented as `witness_consent_rook=voluntary` plus `rook_disclosure=protected`. Confession, disclosure, ancestry, a collected object, and an NPC's physical presence are not interchangeable with consent.

The guaranteed records plus Kael's willingness support every finale method. Optional volunteers share its work and specific costs. Coerced or absent people can contribute known documentary facts but never a borrowed oath. Mercy protects private victim memories and families, not perpetrator immunity. Ash destroys the complete supernatural witness, not already recovered human records.

## Migration

Existing quest/objective IDs remain anchors. Keep unknown decisions unknown. Do not infer consent from completed objectives or old labels. Older `mill_fate` alone cannot reconstruct `mill_operation`. The one-time explicit report records the actual present choice. Old `iron_fate=weapon`, `black_dog_fate=hidden`, and historic values retain their old meaning until an authored recap permits a new decision.

`data/story_campaign.json` supplies the journal's chapter questions, evidence with source/kind/gate, decisions, and ending costs. Evidence gate is either `{quest, objective}` or `{flag, value}`; unknown evidence is withheld rather than described as discovered.
