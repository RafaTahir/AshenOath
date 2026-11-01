// Stage 2 production-UI combat cases. Importing this module launches nothing.
// The caller owns Chromium, serving, evidence paths and the read-only bridge.
import assert from 'node:assert/strict';

const TARGET = 'wychwood_raider';
const BUDGET = 20000;
const gameTime = state => Number(state?.timestamp ?? state?.timestamp_ms);
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const playable = state => state?.read_only === true && state.ready && !state.paused
  && state.player?.can_control && !state.player.dead && !state.transition_pending
  && !state.zone_load_request_pending && !state.ui?.loading_visible && !state.dialogue?.visible;
const target = state => state?.enemies?.find(enemy => enemy.id === TARGET);

export function makeCombatSeed(source, device, phase) {
  const seed = structuredClone(source || {});
  Object.assign(seed, {
    version: 13, game_id: 'ashen-oath', replay_session: true,
    journey_id: `hardening-combat-${device}-${phase}`,
    slot_name: `Hardening Combat ${device} ${phase}`,
    zone: 'wychwood', world_sector: 'wychwood',
    // M19 spawns at (4.6,-5.3) in wave 3. Bow staging is
    // 8.9 m away: outside its 8 m sensing range, within the 12 m lock range,
    // and on the clear north bank beyond the river's 3.15 m spawn margin.
    player_position: phase === 'bow' ? [3.0, 1, 6.2]
      : phase === 'heavy' ? [4.6, 1, -4.0] : [3.0, 1, -5.3],
    player_health: { health: 125, max_health: 125, dead: false },
    player_stamina: { stamina: 100, max_stamina: 100 },
    equipment: { schema_version: 3, active_weapon: 'sword', selected_blade_id: 'steel',
      sword_drawn: true, bow_drawn: false, bow_aiming: false, selected_arrow_id: 'standard_arrow' },
    inventory: { items: { standard_arrow: 12 }, ingredients: {}, coin: 0,
      active_oil: '', oil_remaining_seconds: 0, oil_version: 1 },
    quests: { active: { main_road_of_crows: { objectives: [{ id: 'speak_anwen', done: true }] } },
      completed: {}, completed_objectives: {}, unlocked: { main_road_of_crows: true },
      world_flags: {}, evidence_history: {}, tracked_quest_id: 'main_road_of_crows' },
    story_state: { flags: { wychwood_pack_cleared: false, all_road_evidence: false }, values: {}, evidence: {} },
    progression: {}, quest_presentation: {}, quest_beats: {},
    world_state: { removed_interactions: {}, boss_states: {}, ghoulkin_kills: 3, wychwood_pack_kills: 3,
      pending_ending: '', day_night: { world_time_minutes: 1020, day_count: 0 } },
    seamless_world: { current_sector: 'wychwood', discovered_sectors: { greyfen: true, wychwood: true } },
    text_history: [],
  });
  // Let ordinary save migration derive this position from the new local seed.
  delete seed.world_position;
  return seed;
}

export function combatTouchPoint(action, viewport) {
  assert.equal(viewport.width, 960, 'Touch combat coordinates require the authored 960×540 viewport');
  assert.equal(viewport.height, 540);
  // MobileTouchLayout.build(), noncompact display, zero browser safe insets.
  const points = {
    more: [viewport.width - 164, 36],
    light: [viewport.width - 100, viewport.height - 44],
    heavy: [viewport.width - 100, viewport.height - 108],
    aim: [viewport.width - 164, viewport.height - 44],
    fire: [viewport.width - 100, viewport.height - 44],
    lock: [viewport.width - 100, viewport.height - 108],
  };
  assert(points[action], `Unknown touch combat control ${action}`);
  return { x: points[action][0], y: points[action][1] };
}

export async function runCombatCase({ page, viewport, touch, helpers, source, phase = 'all' }) {
  assert(['all', 'light', 'heavy', 'bow'].includes(phase), 'Invalid combat phase');
  const { observe, waitFor, stableGameplay, clickButton, tap, startFinger, pause,
    importFixture, screenshot, event, sleep } = helpers;
  for (const name of ['observe', 'waitFor', 'stableGameplay', 'clickButton', 'tap', 'startFinger',
    'pause', 'importFixture', 'screenshot', 'event', 'sleep']) {
    assert.equal(typeof helpers[name], 'function', `Missing combat helper ${name}`);
  }
  assert.equal(viewport.width, touch ? 960 : 1280);
  assert.equal(viewport.height, touch ? 540 : 720);
  const device = touch ? 'touch' : 'desktop';
  const evidence = { device, phase, target: TARGET, melee: {}, bow: {}, interruption: { status: 'not_sampled' } };
  const inputEvent = (action, extra = {}) => event({ event: 'combat_input', action,
    input: touch ? 'trusted touch controls' : 'keyboard_mouse', at: Date.now(), ...extra });

  async function keyAcrossGameplayFrame(key) {
    const before = await observe(page);
    await page.bringToFront();
    const focus = await page.evaluate(() => ({ focused: document.hasFocus(),
      active: document.activeElement?.id || document.activeElement?.tagName }));
    assert(focus.focused && focus.active === 'canvas', `Real keyboard input needs focused canvas: ${JSON.stringify(focus)}`);
    await page.keyboard.down(key);
    let after;
    try {
      after = await waitFor(async () => {
        const state = await observe(page);
        return playable(state) && gameTime(state) > gameTime(before) ? state : null;
      }, `Held ${key} reaches a fresh gameplay observation`, BUDGET);
      await sleep(80);
    } finally { await page.keyboard.up(key); }
    inputEvent('keyboard_pulse', { key, before_engine_timestamp: gameTime(before),
      after_engine_timestamp: gameTime(after), focus });
  }

  async function stateWithTarget(description, predicate = () => true, budget = BUDGET) {
    return waitFor(async () => {
      const state = await observe(page);
      if (!playable(state) || state.zone !== 'wychwood') return null;
      assert(Array.isArray(state.enemies), 'Harness must retain the existing read-only enemies snapshot');
      assert(state.inventory?.items, 'Harness must retain the existing read-only inventory snapshot');
      const enemy = target(state);
      return enemy && predicate(state, enemy) ? state : null;
    }, description, budget);
  }

  async function primeDesktopPointer() {
    if (touch || await page.evaluate(() => document.pointerLockElement?.id === 'canvas')) return;
    const before = await stateWithTarget('Ordinary control before pointer-capture gesture');
    // A genuine camera key captures without moving into the target or spending
    // a sword strike. Park the unlocked cursor away from native HUD buttons.
    await page.mouse.move(viewport.width * 0.5, viewport.height * 0.55);
    await keyAcrossGameplayFrame('ArrowLeft');
    await waitFor(() => page.evaluate(() => document.pointerLockElement?.id === 'canvas'),
      'Ordinary movement captures the pointer', BUDGET);
    const after = await stateWithTarget('Pointer-capture gesture settles before the measured attack', state =>
      gameTime(state) >= gameTime(before) + 1200 && state.player.attack_cooldown <= 0.01);
    event({ event: 'combat_pointer_capture_gesture', input: 'ordinary ArrowLeft camera press/release',
      before_engine_timestamp: gameTime(before), after_engine_timestamp: gameTime(after),
      enemy_health_before: target(before).health, enemy_health_after: target(after).health,
      note: 'Non-attacking capture gesture; wait for stable ordinary control before measuring a strike' });
  }

  async function loadFixture(phase) {
    const current = await observe(page);
    if (!current?.ready) {
      await waitFor(async () => (await observe(page))?.new_game_ready,
        'Prepared main menu before isolated combat import');
    }
    if (current?.ready && !current.paused) await pause(page, viewport, touch);
    const seed = makeCombatSeed(source, device, phase);
    await importFixture(page, seed, viewport, touch);
    await clickButton(page, 'Load This Journey', viewport, touch);
    await stableGameplay(page);
    const state = await stateWithTarget('Imported native M19 encounter is ready', (_state, enemy) =>
      enemy.active && !enemy.dead && enemy.health === 75);
    assert.equal(state.player.weapon_mode, 'sword');
    assert.equal(state.inventory.items.standard_arrow, 12);
    if (state.player.visual) assert(state.player.visual.bindings_valid, 'Player authored material bindings were lost');
    event({ event: 'combat_fixture_loaded', journey_id: seed.journey_id, replay: true,
      zone: state.zone, wave_progress: 3, asset_id: 'M19', player: state.player.position, enemy: target(state),
      note: 'Disposable imported test progression; not earned campaign progress' });
    if (phase === 'bow') await primeDesktopPointer();
    return state;
  }

  async function pulse(action) {
    inputEvent(action, touch ? { point: combatTouchPoint(action, viewport) } : {});
    if (touch) return tap(page, combatTouchPoint(action, viewport), true);
    const button = action === 'heavy' ? 'right' : 'left';
    if (!await page.evaluate(() => document.pointerLockElement?.id === 'canvas')) {
      await page.mouse.click(viewport.width * 0.5, viewport.height * 0.55, { button, delay: 100 });
      return;
    }
    await page.mouse.down({ button });
    try { await sleep(80); } finally { await page.mouse.up({ button }); }
  }

  async function lockTarget(bow = false) {
    for (let attempt = 1; attempt <= 4; attempt++) {
      if ((await observe(page))?.camera?.locked_target_id === TARGET) return;
      if (touch && !bow) {
        await tap(page, combatTouchPoint('more', viewport), true);
        await clickButton(page, 'Lock / Release Target', viewport, true);
      } else if (touch) await tap(page, combatTouchPoint('lock', viewport), true);
      else await keyAcrossGameplayFrame('t');
      inputEvent('target_lock', { attempt });
      try {
        await stateWithTarget('Real target-lock input selects native M19', state =>
          state.camera?.locked_target_id === TARGET, 2500);
        return;
      } catch (error) {
        if (attempt === 4) throw error;
        event({ event: 'combat_target_lock_retry', attempt, observed_lock: (await observe(page))?.camera?.locked_target_id,
          note: 'Bounded ordinary input retry; never toggle an observed acquired lock off' });
      }
    }
  }

  async function approachMelee() {
    // Short off-centre touch presses steer directly. No held-drag dependency.
    const deadline = Date.now() + BUDGET;
    while (Date.now() < deadline) {
      const state = await stateWithTarget('Melee approach remains playable');
      const enemy = target(state);
      const separation = distance(enemy.position, state.player.position);
      if (separation <= 1.55) return state;
      const dx = enemy.position.x - state.player.position.x;
      const dz = enemy.position.z - state.player.position.z;
      const yaw = state.camera.yaw;
      const forward = (-Math.sin(yaw) * dx - Math.cos(yaw) * dz) / separation;
      const right = (Math.cos(yaw) * dx - Math.sin(yaw) * dz) / separation;
      if (touch) {
        const finger = await startFinger(page, 72 + right * 30, viewport.height - 76 - forward * 30);
        try { await sleep(160); } finally { await finger.end(); }
      } else {
        const keys = [...(forward > 0.25 ? ['w'] : forward < -0.25 ? ['s'] : []),
          ...(right > 0.25 ? ['d'] : right < -0.25 ? ['a'] : [])];
        for (const key of keys) await page.keyboard.down(key);
        try { await sleep(160); } finally { for (const key of keys) await page.keyboard.up(key); }
      }
      await waitFor(async () => gameTime(await observe(page)) > gameTime(state), 'Fresh actual-input approach frame', 10000);
    }
    assert.fail('Actual movement could not reach native M19 melee range');
  }

  async function capturePaused(name) {
    await pause(page, viewport, touch);
    await screenshot(page, name);
  }

  function finish() {
    event({ event: 'combat_functional_pass', phase, evidence,
      limits: ['Imported replay fixture, not earned campaign progression',
        'This phase verifies only its recorded actual inputs; no locked-melee claim',
        'Finite-cylinder, contact-window and buffer boundaries remain covered by permanent native fixtures',
        'No FPS or device certification; interruption sampling remains explicit'] });
    return evidence;
  }

  if (phase === 'all' || phase === 'light') {
  await loadFixture('melee');
  await stateWithTarget('Authored melee standoff remains stable', (state, enemy) =>
    distance(enemy.position, state.player.position) >= 1.2 && distance(enemy.position, state.player.position) <= 2.1);
  const beforeLight = await stateWithTarget('Native M19 is within real light-strike reach', (state, enemy) =>
    distance(enemy.position, state.player.position) <= 2.2 && state.player.attack_cooldown <= 0.01);
  event({ event: 'combat_light_baseline', engine_timestamp: gameTime(beforeLight),
    enemy_health: target(beforeLight).health, player_stamina: beforeLight.player.stamina });
  if (target(beforeLight).pending_attack_time > 0.30)
    inputEvent('native_windup_observed', { engine_timestamp: gameTime(beforeLight), enemy: target(beforeLight) });
  await pulse('light');
  let observedLightCooldown = 0;
  const lightHit = await stateWithTarget('Real light attack damages native M19', (state, enemy) => {
    if (state.player.attack_cooldown > observedLightCooldown)
      event({ event: 'combat_light_recovery_observed', cooldown: state.player.attack_cooldown,
        engine_timestamp: gameTime(state), enemy_health: enemy.health });
    observedLightCooldown = Math.max(observedLightCooldown, state.player.attack_cooldown);
    return gameTime(state) > gameTime(beforeLight) && enemy.health < target(beforeLight).health;
  });
  assert(target(lightHit).health > 0, 'Initial light strike must leave a live interruption target');
  evidence.melee.light = { before: target(beforeLight).health, after: target(lightHit).health,
    observed_cooldown: observedLightCooldown, player_health: lightHit.player.health,
    separation: distance(target(lightHit).position, lightHit.player.position) };
  const elapsed = (gameTime(lightHit) - gameTime(beforeLight)) / 1000;
  const remaining = target(beforeLight).pending_attack_time;
  if (remaining > 0.30 && target(lightHit).pending_attack_time === 0 && elapsed < remaining - 0.01
      && lightHit.player.health === beforeLight.player.health) {
    evidence.interruption = { status: 'observed_before_contact', original_windup_remaining: remaining,
      observed_engine_elapsed: elapsed, player_health_unchanged: true };
  } else {
    evidence.interruption = { status: 'inconclusive', original_windup_remaining: remaining,
      observed_engine_elapsed: elapsed, note: 'Snapshot cadence cannot prove interruption before the original contact; no success inferred from pending=0 alone.' };
  }
  event({ event: 'combat_light_damage', ...evidence.melee.light, interruption: evidence.interruption });
  await lockTarget();

  evidence.melee.followup = { status: 'not_sampled',
    note: 'Native M19 has authored 75 HP; exact follow-up windows are covered by the permanent real-input fixture.' };
  if (phase === 'light') {
    await capturePaused('combat-native-light-result');
    return finish();
  }
  }
  // Use another ordinary authored 75-HP encounter for heavy. Light+heavy would
  // kill the same actor; do not invent extra health to preserve a test target.
  if (phase === 'all' || phase === 'heavy') {
  await loadFixture('heavy');
  await stateWithTarget('Fresh heavy standoff remains stable', (state, enemy) =>
    distance(enemy.position, state.player.position) >= 1.2 && distance(enemy.position, state.player.position) <= 2.1);
  const beforeHeavy = await stateWithTarget('A fresh native encounter permits a deliberate heavy strike', (state, enemy) =>
    distance(enemy.position, state.player.position) <= 2.2 && state.player.attack_cooldown <= 0.01 && enemy.health > 0);
  await pulse('heavy');
  let observedHeavyCooldown = 0;
  let minimumStamina = beforeHeavy.player.stamina;
  const heavyHit = await stateWithTarget('Real heavy attack damages native M19', (state, enemy) => {
    if (state.player.attack_cooldown > observedHeavyCooldown || state.player.stamina < minimumStamina)
      event({ event: 'combat_heavy_recovery_observed', cooldown: state.player.attack_cooldown,
        stamina: state.player.stamina, engine_timestamp: gameTime(state), enemy_health: enemy.health });
    observedHeavyCooldown = Math.max(observedHeavyCooldown, state.player.attack_cooldown);
    minimumStamina = Math.min(minimumStamina, state.player.stamina);
    return gameTime(state) > gameTime(beforeHeavy) && enemy.health < target(beforeHeavy).health;
  });
  assert(minimumStamina < beforeHeavy.player.stamina, 'Heavy attack must spend real player stamina');
  assert(observedHeavyCooldown > 0, 'Heavy attack must expose its real recovery clock');
  evidence.melee.heavy = { before: target(beforeHeavy).health, after: target(heavyHit).health,
    observed_cooldown: observedHeavyCooldown, stamina_before: beforeHeavy.player.stamina, minimum_stamina: minimumStamina };
  event({ event: 'combat_heavy_damage', ...evidence.melee.heavy });
  await capturePaused('combat-native-melee-result');
  if (phase === 'heavy') return finish();
  }

  const bowStaging = await loadFixture('bow');
  const bowStagingDistance = distance(bowStaging.player.position, target(bowStaging).position);
  assert(bowStagingDistance > 9.25 && bowStagingDistance < 11.95,
    `Bow fixture must start outside M19 perception and inside target-lock range; observed ${bowStagingDistance.toFixed(2)} m`);
  if (touch) {
    await tap(page, combatTouchPoint('more', viewport), true);
    await clickButton(page, 'Bow', viewport, true);
  } else await keyAcrossGameplayFrame('2');
  inputEvent('switch_to_bow');
  await stateWithTarget('Real equipment input switches to bow', state => state.player.weapon_mode === 'bow');
  await lockTarget(true);
  let aimHeld = false;
  let fireFinger = null;
  try {
    if (touch) await tap(page, combatTouchPoint('aim', viewport), true);
    else { await page.mouse.down({ button: 'right' }); aimHeld = true; }
    const aimed = await stateWithTarget('Real aim input presents the bow', state => state.player.bow_aiming
      && state.camera.locked_target_id === TARGET);
    const drawStartDistance = distance(aimed.player.position, target(aimed).position);
    assert(drawStartDistance > 9.25 && drawStartDistance < 11.95,
      `Bow fixture lost its safe staging distance before draw; observed ${drawStartDistance.toFixed(2)} m`);
    const arrowsBefore = aimed.inventory.items.standard_arrow;
    const healthBefore = target(aimed).health;
    inputEvent('bow_draw_start', { arrows_before: arrowsBefore, target_health: healthBefore,
      fixture_distance: bowStagingDistance, draw_start_distance: drawStartDistance });
    if (touch) {
      const point = combatTouchPoint('fire', viewport);
      fireFinger = await startFinger(page, point.x, point.y);
    } else await page.mouse.down({ button: 'left' });
    await waitFor(async () => {
      const state = await observe(page);
      return playable(state) && state.player.bow_aiming && gameTime(state) >= gameTime(aimed) + 1200 ? state : null;
    }, 'Hold the real bow draw through fresh gameplay frames', 10000);
    if (fireFinger) { await fireFinger.end(); fireFinger = null; }
    else await page.mouse.up({ button: 'left' });
    inputEvent('bow_release');
    const arrowHit = await stateWithTarget('Released projectile consumes one arrow and hits native M19', (state, enemy) =>
      state.inventory.items.standard_arrow === arrowsBefore - 1 && enemy.health < healthBefore);
    assert.equal(arrowHit.inventory.items.standard_arrow, arrowsBefore - 1);
    evidence.bow = { weapon: arrowHit.player.weapon_mode, locked_target: arrowHit.camera.locked_target_id,
      fixture_distance: bowStagingDistance, draw_start_distance: drawStartDistance,
      arrows_before: arrowsBefore, arrows_after: arrowHit.inventory.items.standard_arrow,
      target_health_before: healthBefore, target_health_after: target(arrowHit).health,
      player_position: arrowHit.player.position, enemy_position: target(arrowHit).position };
    event({ event: 'combat_locked_bow_projectile_hit', ...evidence.bow });
  } finally {
    if (fireFinger) await fireFinger.end().catch(() => {});
    if (!touch) {
      await page.mouse.up({ button: 'left' }).catch(() => {});
      if (aimHeld) await page.mouse.up({ button: 'right' }).catch(() => {});
    }
  }
  await capturePaused('combat-locked-bow-result');
  return finish();
}
