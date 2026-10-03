# Fine details cycle 03: preparation and deliberate choices

Date: 2026-10-03. Starting published package: `c6c3ab5`; Vercel deployment `dpl_Bpu9dVkLn9H9VwMi6adEqcaJdNfY`.

This plan precedes implementation. The user has authorized continued planning, building, pushing and deployment until they stop the work. No further approval gates, tests, review passes or verification sessions are part of this cycle. Production content generation, compilation and export remain necessary release work.

## Intended experience and chosen approach

Preparation should help Kael keep the promise currently at hand. A player should understand an item's actual use, what they carry, what they would spend and what an action changes before using it. A story choice should state the immediate commitment and known stakes without predicting unknown consequences or treating a person's consent as a completion reward.

Extend the existing journal, services and dialogue transaction. Use shared read-only presentation models with explicit operation results, retaining current navigation memory and authoritative mutation owners. A cosmetic-only pass would retain misleading availability and costs; a new equipment economy or campaign branch would add unnecessary scope. The selected approach improves the existing actions and makes their state legible.

## A. Preparation models and service results

Owner: player-experience implementer. Own `inventory_manager.gd`, `crafting_manager.gd`, `vendor_service.gd`, `progression_manager.gd` (or its existing equivalent), a new `preparation_view_model.gd`, and an authored preparation catalog/item metadata where needed. Do not modify HUD, game, registry or player controller.

1. Provide item detail models with name, category, owned amount/capacity, actual implemented effect, active oil or selected arrow, same-purpose comparison, discovered story use and a precise action label. Compare arrow base damage/capacity; describe oil target/use without promising an unconditional damage bonus. Do not expose unknown encounter solutions.
2. Centralize resolved immediate item effects. Preserve current tonic restoration of 55 and current potion progression bonus; copy must match execution. A selected coating remains selected under the existing inventory rules.
3. Provide crafting quotes/results with owned/required ingredients, shortages, capacity, output amount and known mastery refunds. Empty recipes are unavailable. Commit rederives its quote before consumption; existing boolean wrappers remain compatible.
4. Provide vendor quotes/results with requested and actual quantity, unit/total price, coins afterward, stock/capacity and explicit availability reason, including existing emergency assistance. Preserve current economy and stock rules.
5. Provide practice status/results with exact immediate benefit, mark cost, learned state and prerequisite/shortage wording. Preserve existing progression budget and branches.
6. Keep authoritative mutations inside their services. Root receives result dictionaries for local feedback and persistence; the model never mutates inventory, consent or quest state.

## B. Focused preparation and choice presentation

Owner: presentation implementer. Own `hud.gd` and a small helper only if needed. Integrate A and C models through agreed APIs; retain previous cycles' section identities, focus/scroll/draft memory, History and prioritized notices.

1. Give Preparation a selected item detail area with stable item/action focus keys, compact owned/selected status, readable effect and current story use. Show precise Use remedy, Apply oil, Select arrow, Throw bomb or Set trap actions.
2. Show quotes before action: ingredient owned/required and refunds for crafting; quantity, total, coins afterward, stock/capacity and availability reason for purchases. Keep unavailable controls understandable and preserve the selected item after changes.
3. Show practice benefit and learning requirements in place. Return craft, use, purchase, selection and learning outcomes to a stable local feedback region; do not require leaving the current menu to learn the result.
4. Replace repeated long preview paragraphs with a focus/hover-driven choice detail area. Display immediate commitment, known evidence/cost and uncertainty only when supported by the authoritative model. Keep choices readable and usable with keyboard, controller and touch, without an extra confirmation modal.
5. Display recorded-decision feedback from the completed transaction; use stable choice identity for history/deduplication. Keep critical narrative labels and current page navigation clear during dialogue and History.

## C. Grounded decision models and transaction feedback

Owner: world/story implementer. Own `dialogue_manager.gd`, `story_decision_coordinator.gd`, a new decision presentation helper and narrowly relevant existing preview metadata. Do not modify HUD, game or registry.

1. Expose structured choice detail with immediate commitment, known facts, costs, uncertainty and availability. Preserve existing availability filters and authored action IDs.
2. Use canonical decision/option keys for recorded choice history and receipt deduplication. Reuse the current transaction and explicit decision reporting; generic objective completion remains insufficient to invent consent.
3. Produce a receipt after the accepted action transaction showing what was recorded and a current practical next step where available. No morality score, future ending spoiler or invented outcome.
4. Preserve predecision checkpoints, action availability checks, save migration behavior, story travel and peaceful covenant rituals. Root owns the final runtime hookup.

## D. Root integration and publication automation

Owner: root. Own `game.gd`, `runtime_service_registry.gd`, narrow `player_controller.gd`, `tools/build_source_catalog.py`, `tools/build_story_release.ps1`, plan and ledger.

1. Supply `set_preparation_context(snapshot)` with health/max health, stamina/max stamina, weapon mode, selected arrow and current zone before menus open or refresh. Add a public owned-ammo selection method that updates player and loadout together.
2. Route service results to local HUD feedback, refresh the existing selected detail, and schedule existing persistence for successful actions. Reuse authoritative item effect values. Preserve quick actions while preventing wasted health/stamina remedies when the corresponding resource is full.
3. Connect structured choice detail and recorded receipts using C's completed APIs. Keep source state, saves and journal authoritative and coalesce persistence with existing behavior.
4. Include new authored text in the English source catalog. Regenerate voice resources only if spoken dialogue changes.
5. Add an explicit `-Publish` option to the existing production builder. Its ordered flow is content generation/import/all seven packs/Web, allowlisted generated-file commit with hooks disabled, push to both already authorized branches, and production deployment to the linked Vercel project. Write local release logs/receipt. Packaging alone remains the default. Preserve previous artifacts, ignore unrelated staged files and do not add test, browser or post-deploy commands. A failed stage stops dependent stages and leaves logs for autonomous recovery.
6. Commit source, invoke a fresh production candidate with publication, handle actual compiler/tool failures, record CLI deployment results and continue to the next written refinement plan.

## Completion and limits

The implementation milestone is integrated source and completed production publication. It does not claim playtesting, visual perfection, performance measurement, accessibility certification or a reviewed campaign. The continuing goal remains active after this release.

## Execution record

- Published package `7634f08` to both authorized branches. Vercel returned `READY` for `dpl_rstRtgGDvV7FVwPyqqWpiM8z4coL`, aliased to `https://ashenoath.vercel.app`. Cycle 04 planning follows; the continuing goal remains active.

- Written after independent source-context planning for preparation, HUD and decisions, before implementation.
- Final integration contracts: `PreparationViewModel.item_detail(item_id, inventory, progression, context, state, quests)`; `resolved_effect(item_id, inventory, progression)`; `crafting.quote/craft_result`; `vendor_service.quote/buy` and existing reserve methods; `progression.upgrade_status/unlock_result`. Standard results carry `ok`, `operation`, `item_id`, `quantity`, `spent`, `remaining`, `message` and `reason`.
- HUD contracts are `set_preparation_context(snapshot)`, `set_preparation_services(crafting)`, `show_preparation_result(result) -> bool`, and `show_decision_result(receipt)`. Existing action signals are retained, including `item_use_requested` for selecting ammunition. The model snapshot has `health`, `max_health`, `stamina`, `max_stamina`, `weapon_mode`, `selected_arrow_id` and `zone_id`.
- Decision contracts: `StoryChoicePresenter.describe/receipt/decision_id/option_key`, resolved `action.decision_model`, and `StoryDecisionCoordinator.finish(game, action, applied)`. Root now reports actual action acceptance and presents only accepted consequential receipts. Covenant selection reports intention rather than completion.
- Root implemented current-resource snapshots, owned-ammunition selection, resolved remedy effects, full-resource remedy protection, local operation routing, deferred menu refresh and successful-action persistence. Service messages are suppressed only inside a preparation operation that will return its own local result.
- Root added explicit `-Publish` automation to the production builder. Default remains packaging only. Publication commits allowlisted generated artifacts, preserves unrelated staging, pushes both authorized branches, invokes the linked Vercel deployment and records a local phase receipt. No testing or post-deployment commands were added.
- Preparation and decision services are implemented, with `preparation_notes.json` and `decision_contexts.json` added to source-language generation. No spoken dialogue changed, so existing exact-text voice assets are retained. HUD integration is the remaining implementation package before production compilation.
- HUD implementation is now integrated: selected item/practice/vendor details, service-backed quotes, inspectable unavailable options, fixed action strip, local results, focus/scroll continuity, one focused choice reader, deliberate release activation and accepted-receipt History. Deferred operation refresh captures the current screen key and cannot reopen a surface the player left. Source publication and production compilation follow.
- Production import, all seven runtime packs and Web export completed on the first compilation from source `7912479abe20`, build `story-20261003T124352Z-7912479abe20`, candidate `.release-gate/fine-details-cycle03-01`. Publication reported an incorrect allowlist path for the generated music manifest (it lives at the project root). The path was corrected; the already completed package is retained for publication without rebuilding game artifacts.

## Release invocation

After committing the intended source changes, run from the repository root with a fresh candidate directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\outputs\AshenOathTheRoadBetweenCrowns\tools\build_story_release.ps1 -OutputDirectory .release-gate/fine-details-cycle03-01 -Publish
```

The command writes stage logs and `publication.json` under that candidate. It preserves prior generated web files under `previous-web`. Packaging, Git and Vercel errors stop later stages; the agent continues from the reported failure without discarding completed work. A completed CLI deployment ends this release command, not the continuing improvement goal.
