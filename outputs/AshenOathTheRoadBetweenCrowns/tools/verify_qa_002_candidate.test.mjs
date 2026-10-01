import assert from 'node:assert/strict';
import test from 'node:test';
import { assessQaCandidate, QA_002_REQUIRED_SCOPES } from './verify_qa_002_candidate.mjs';
import { REQUIRED_BROWSER_ZONES } from './qa_002_zone_performance.mjs';

const identity = {
  fingerprint: 'source-aligned-candidate',
  total_bytes: 87_000_000,
  files: [{ path: 'index.pck', bytes: 32, sha256: 'fixture' }],
};
const mainEvents = [
  'scenario_start', 'opening_complete', 'cemetery_ambush_defeated', 'cemetery_choice_complete',
  'bell_eater_defeated', 'bell_eater_aftermath_complete', 'teeth_complete',
  'register_reconstructed', 'rootbound_defeated', 'names_published', 'ashwing_defeated',
  'ash_mill_completed', 'senn_guard_defeat', 'soldier_completed', 'record_hall_entered',
  'record_haunting_cleared', 'blood_under_stone_completed', 'halvern_guard_parried',
  'last_witness_completed', 'assembly_completed', 'witness_ending_completed',
];
const branchChoices = {
  shrine_matrix_partial: ['shrine_choice_completed', ['cleansed', 'disturbed', 'bound'], 'shrine_checkpoint_restored'],
  report_matrix_partial: ['road_report_choice_completed', ['private', 'public', 'retained'], 'opening_continue_restored'],
  ledger_matrix_partial: ['ledger_choice_completed', ['vargan_ledger_taken_openly', 'vargan_ledger_hidden', 'vargan_ledger_left_copied'], 'ledger_checkpoint_restored'],
  edric_matrix_partial: ['edric_choice_completed', ['cooperate', 'exposed', 'compelled'], 'edric_checkpoint_restored'],
  mill_matrix_partial: ['miller_choice_completed', ['preserved', 'burned', 'exposed'], 'miller_checkpoint_restored'],
  senn_matrix_partial: ['senn_choice_completed', ['testimony', 'exile', 'punished'], 'senn_checkpoint_restored'],
  widow_matrix_partial: ['widow_choice_completed', ['told', 'comforted'], 'opening_continue_restored'],
  iron_matrix_partial: ['greyfen_side_choice_completed', ['memorial', 'weapon'], 'opening_continue_restored', 'side_iron_remembers'],
  returned_soldier_matrix_partial: ['greyfen_side_choice_completed', ['named', 'anonymous'], 'opening_continue_restored', 'side_empty_grave'],
  bitter_roots_matrix_partial: ['bitter_roots_choice_completed', ['confessed', 'kept'], 'opening_continue_restored'],
  black_dog_matrix_partial: ['black_dog_choice_completed', ['spared', 'hidden'], 'opening_continue_restored'],
  rooks_map_matrix_partial: ['rooks_map_choice_completed', ['preserved', 'destroyed'], 'opening_continue_restored'],
  millers_measure_matrix_partial: ['millers_measure_choice_completed', ['farmer', 'healer'], 'assembly_side_outcome_restored', 'side_millers_measure'],
  bannerless_matrix_partial: ['bannerless_choice_completed', ['testimony', 'shielded'], 'assembly_side_outcome_restored', 'side_soldiers_debt'],
};

function checkpointsForScope(scope) {
  if (scope === 'campaign_main_player_driven') {
    return mainEvents.map(event => event === 'witness_ending_completed'
      ? { event, ending: 'expose', cards: 4 } : { event });
  }
  if (scope === 'opening_save_continue_partial') {
    return ['opening_complete', 'browser_pause_input_blocked', 'browser_settings_changed',
      'manual_save_created', 'opening_continue_restored', 'browser_settings_persisted',
      'browser_remapped_interaction', 'browser_defaults_restored'].map(event => ({ event }))
      .concat({ event: 'browser_menu_resize', width: 1280, height: 720 },
        { event: 'browser_menu_resize', width: 1920, height: 1080 });
  }
  if (scope === 'named_dead_route_partial') {
    return ['bram', 'sella', 'oren'].map(victim => ({ event: 'named_candle_lit', victim }))
      .concat({ event: 'named_dead_side_quests_restored' });
  }
  if (branchChoices[scope]) {
    const [event, choices, restored, quest] = branchChoices[scope];
    return [{ event: restored, quest }, ...choices.map(outcome => ({ event, outcome, quest }))];
  }
  if (scope === 'ending_matrix_partial') {
    return [
      { event: 'hart_checkpoint_restored' },
      { event: 'hart_ending_completed', covenant: 'witness', ending: 'expose' },
      { event: 'hart_ending_completed', covenant: 'mercy', ending: 'free' },
      { event: 'hart_ending_completed', covenant: 'duty', ending: 'bind' },
      { event: 'hart_ending_completed', covenant: 'ash', ending: 'kill' },
    ];
  }
  throw new Error(`No fixture for ${scope}`);
}

function fixture() {
  return QA_002_REQUIRED_SCOPES.map(key => {
    const split = key.indexOf(':');
    const name = key.slice(0, split);
    const scope = key.slice(split + 1);
    const checkpoints = checkpointsForScope(scope);
    return {
      status: 'pass', observation_mode: 'production_read_only', route_scope: scope,
      artifact: structuredClone(identity),
      browsers: [{
        browser: name, status: 'pass', observation_mode: 'production_read_only',
        route_scope: scope, checkpoints, console_errors: [], network_failures: [],
        renderer_mode: 'hardware', renderer: { unmasked_renderer: 'Intel UHD Graphics' },
        js_heap_mb: name === 'Firefox' ? null : 200,
        runtime_memory_mb: 200,
        memory_method: name === 'Firefox' ? 'isolated_content_process_private_upper_bound' : 'isolated_renderer_process_private_upper_bound',
        final_screenshot: 'fixture.png', audio_unlock: 'observed_running',
        final_telemetry: {
          quests: { completed: ['main_hart_remembers'] },
          performance: { samples: 600, average_fps: 45, one_percent_low_fps: 34 },
        },
        performance_by_zone: Object.fromEntries(REQUIRED_BROWSER_ZONES.map(zone => [zone, {
          samples: 600, min_average_fps: 45, min_one_percent_low_fps: 34,
        }])),
      }],
    };
  });
}

const screenshotStat = () => ({ size: 20_000 });

test('opening certification rejects absent browser remapping, persistence and resize checks', () => {
  for (const event of ['browser_settings_persisted', 'browser_remapped_interaction', 'browser_menu_resize']) {
    const reports = fixture();
    const opening = reports.find(report => report.route_scope === 'opening_save_continue_partial');
    opening.browsers[0].checkpoints = opening.browsers[0].checkpoints.filter(checkpoint => checkpoint.event !== event);
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks/);
  }
});

function functionalFixture() {
  const reports = fixture().filter(report => report.browsers[0].browser === 'Chrome'
    && report.route_scope === 'opening_save_continue_partial');
  const opening = reports.find(report => report.route_scope === 'opening_save_continue_partial');
  opening.browsers[0].checkpoints.unshift({ event: 'interaction_used', id: 'sister_anwen' },
    { event: 'zone_arrival', zone: 'wychwood' }, { event: 'zone_arrival', zone: 'greyfen' });
  for (const name of ['Edge', 'Firefox']) {
    const smoke = structuredClone(opening);
    const browser = smoke.browsers[0];
    browser.browser = name;
    smoke.route_scope = browser.route_scope = 'browser_compatibility_smoke';
    browser.memory_method = name === 'Firefox' ? 'isolated_content_process_private_upper_bound' : 'isolated_renderer_process_private_upper_bound';
    browser.checkpoints = ['scenario_start', 'browser_keyboard_movement', 'manual_save_created',
      'opening_continue_restored', 'browser_save_durable', 'browser_continue_input'].map(event => ({ event }));
    reports.push(smoke);
  }
  for (const report of reports) {
    report.acceptance_profile = 'functional_candidate';
    const browser = report.browsers[0];
    browser.acceptance_profile = 'functional_candidate';
    browser.startup_runs = [{ navigation_to_control_ms: 22000, click_to_control_ms: 900 }];
    browser.runtime_memory_mb = 600;
    browser.final_telemetry.performance.average_fps = 27;
    browser.final_telemetry.performance.one_percent_low_fps = 16;
    browser.performance_by_zone.greyfen.min_average_fps = 27;
  }
  return reports;
}

test('functional profile discloses numerical failures without certifying the original contract', () => {
  const result = assessQaCandidate(identity, functionalFixture(), screenshotStat, 'functional_candidate');
  assert.equal(result.status, 'accepted');
  assert.equal(result.performance_certified, false);
  assert.equal(result.listening_reviewed, false);
  assert.ok(result.target_misses.some(message => message.includes('600 MB')));
  assert.equal(result.browser_certification_scope, 'lean_functional_smoke');
  assert.equal(result.exhaustive_browser_campaign_certified, false);
  assert.throws(() => assessQaCandidate(identity, functionalFixture(), screenshotStat), /different acceptance profile/);
});

test('functional profile still rejects missing measurements, stale artifacts, mutations, errors and failed runs', () => {
  for (const mutate of [
    reports => { reports[0].browsers[0].runtime_memory_mb = null; },
    reports => { reports[1].browsers[0].checkpoints = reports[1].browsers[0].checkpoints.filter(event => event.event !== 'browser_save_durable'); },
    reports => { reports[0].browsers[0].startup_runs = []; },
    reports => { reports[0].artifact.fingerprint = 'stale'; },
    reports => { reports[0].browsers[0].checkpoints.push({ event: 'teleport' }); },
    reports => { reports[0].browsers[0].console_errors.push('renderer error'); },
    reports => { reports[0].browsers[0].status = 'fail'; },
  ]) {
    const reports = functionalFixture();
    mutate(reports);
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat, 'functional_candidate'));
  }
  assert.throws(() => assessQaCandidate(identity, functionalFixture().slice(0, -1), screenshotStat, 'functional_candidate'), /Missing QA-002 scopes/);
});

test('only a complete same-artifact player-driven browser matrix is accepted', () => {
  const result = assessQaCandidate(identity, fixture(), screenshotStat);
  assert.equal(result.complete_qa_002_acceptance, true);
  assert.equal(result.browser_scopes.length, QA_002_REQUIRED_SCOPES.length);
});

test('missing route scope cannot become QA-002 acceptance', () => {
  const reports = fixture().filter(report => report.route_scope !== 'bannerless_matrix_partial');
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /Missing QA-002 scopes: Chrome:bannerless_matrix_partial/);
});

test('same-HEAD reports with changed pack bytes are rejected', () => {
  const reports = fixture();
  reports[0].artifact.fingerprint = 'older-pack';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /different or stale Web artifact bytes/);
});

test('diagnostic preparation and direct route mutation are rejected', () => {
  const reports = fixture();
  reports[0].observation_mode = 'qa_diagnostic';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /not a passing production read-only run/);
  reports[0].observation_mode = 'production_read_only';
  reports[0].browsers[0].checkpoints.push({ event: 'route_to' });
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /diagnostic state mutation/);
});

test('all four actual Hart results must be present', () => {
  const reports = fixture();
  const endings = reports.find(report => report.route_scope === 'ending_matrix_partial');
  endings.browsers[0].checkpoints.pop();
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /Hart ending matrix lacks ash:kill/);
});

test('an ending alone cannot masquerade as an uninterrupted campaign', () => {
  const reports = fixture();
  const main = reports.find(report => report.route_scope === 'campaign_main_player_driven');
  main.browsers[0].checkpoints = [{ event: 'witness_ending_completed', ending: 'expose', cards: 4 }];
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks ordered scenario_start proof/);
  main.browsers[0].checkpoints = checkpointsForScope('campaign_main_player_driven');
  main.browsers[0].checkpoints.push({ event: 'opening_continue_restored' });
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /not uninterrupted/);
});

test('branch reports require every actual outcome and earned-save proof', () => {
  for (const scope of Object.keys(branchChoices)) {
    const reports = fixture();
    const branch = reports.find(report => report.route_scope === scope);
    branch.browsers[0].checkpoints = [{ event: 'real_interaction' }];
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks one/);
    branch.browsers[0].checkpoints = checkpointsForScope(scope).slice(1);
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks earned-save/);
  }
});

test('named-dead route requires three distinct candles and restored side quests', () => {
  const reports = fixture();
  const branch = reports.find(report => report.route_scope === 'named_dead_route_partial');
  branch.browsers[0].checkpoints = branch.browsers[0].checkpoints.filter(checkpoint => checkpoint.victim !== 'sella');
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks sella candle proof/);
});

test('browser errors, absent audio unlock, and stale images fail', () => {
  const reports = fixture();
  const main = reports.find(report => report.route_scope === 'campaign_main_player_driven' && report.browsers[0].browser === 'Chrome');
  main.browsers[0].console_errors.push('resource failed');
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /console or network failures/);
  main.browsers[0].console_errors = [];
  main.browsers[0].audio_unlock = 'not_observed';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /user-unlocked/);
  main.browsers[0].audio_unlock = 'observed_running';
  assert.throws(() => assessQaCandidate(identity, reports, () => ({ size: 1 })), /captured gameplay screenshot/);
});

test('software WebGL and missing hardware identity cannot certify the browser matrix', () => {
  const reports = fixture();
  const chrome = reports.find(report => report.route_scope === 'campaign_main_player_driven'
    && report.browsers[0].browser === 'Chrome').browsers[0];
  chrome.renderer_mode = 'software';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks hardware renderer proof/);
  chrome.renderer_mode = 'hardware';
  chrome.renderer.unmasked_renderer = 'Google SwiftShader';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks hardware renderer proof/);
});

test('Firefox main route cannot pass without observed audio unlock', () => {
  const reports = fixture();
  const firefox = reports.find(report => report.route_scope === 'campaign_main_player_driven'
    && report.browsers[0].browser === 'Firefox');
  firefox.browsers[0].audio_unlock = 'unobserved_firefox_bidi';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /Firefox:campaign_main_player_driven did not prove a user-unlocked/);
});

test('Firefox requires an isolated content-memory upper bound below 450 MB', () => {
  const reports = fixture();
  const firefox = reports.find(report => report.route_scope === 'campaign_main_player_driven'
    && report.browsers[0].browser === 'Firefox');
  firefox.browsers[0].runtime_memory_mb = null;
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /runtime memory measurement/);
  firefox.browsers[0].runtime_memory_mb = 450;
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /runtime memory measurement/);
  firefox.browsers[0].runtime_memory_mb = 200;
  firefox.browsers[0].memory_method = 'unmeasured';
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /runtime memory measurement/);
});

test('Chrome and Edge cannot certify runtime memory from V8 heap alone', () => {
  for (const name of ['Chrome', 'Edge']) {
    const reports = fixture();
    const browser = reports.find(report => report.route_scope === 'campaign_main_player_driven'
      && report.browsers[0].browser === name).browsers[0];
    browser.memory_method = 'cdp_js_heap_used';
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /runtime memory measurement/);
    browser.memory_method = 'isolated_renderer_process_private_upper_bound';
    browser.runtime_memory_mb = 451;
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /runtime memory measurement/);
  }
});

test('hardware campaign reports cannot hide low or missing browser FPS evidence', () => {
  for (const [field, value] of [
    ['samples', 119], ['average_fps', 31.9], ['one_percent_low_fps', 29.9],
  ]) {
    const reports = fixture();
    const chrome = reports.find(report => report.route_scope === 'campaign_main_player_driven'
      && report.browsers[0].browser === 'Chrome').browsers[0];
    chrome.final_telemetry.performance[field] = value;
    assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /browser performance evidence/);
  }
});

test('a slow earlier zone cannot be hidden by a passing finale window', () => {
  const reports = fixture();
  const chrome = reports.find(report => report.route_scope === 'campaign_main_player_driven'
    && report.browsers[0].browser === 'Chrome').browsers[0];
  chrome.performance_by_zone.greyfen.min_one_percent_low_fps = 29.9;
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /Browser greyfen performance/);
  chrome.performance_by_zone.greyfen.min_one_percent_low_fps = 34;
  delete chrome.performance_by_zone.record_hall;
  assert.throws(() => assessQaCandidate(identity, reports, screenshotStat), /lacks complete record_hall performance evidence/);
});

test('oversized artifact cannot pass even with all route reports', () => {
  assert.throws(() => assessQaCandidate({ ...identity, total_bytes: 100_000_000 }, fixture(), screenshotStat), /below 100 MB/);
});
