import { existsSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { artifactIdentity } from './qa_002_artifact_identity.mjs';
import { requireZonePerformance } from './qa_002_zone_performance.mjs';

const MAIN_SCOPE = 'campaign_main_player_driven';
const BRANCH_SCOPES = [
  'opening_save_continue_partial',
  'ending_matrix_partial',
  'shrine_matrix_partial',
  'report_matrix_partial',
  'ledger_matrix_partial',
  'edric_matrix_partial',
  'mill_matrix_partial',
  'senn_matrix_partial',
  'widow_matrix_partial',
  'iron_matrix_partial',
  'returned_soldier_matrix_partial',
  'bitter_roots_matrix_partial',
  'black_dog_matrix_partial',
  'named_dead_route_partial',
  'rooks_map_matrix_partial',
  'millers_measure_matrix_partial',
  'bannerless_matrix_partial',
];
const REQUIRED = new Set([
  ...['Chrome', 'Edge', 'Firefox'].map(browser => `${browser}:${MAIN_SCOPE}`),
  ...BRANCH_SCOPES.map(scope => `Chrome:${scope}`),
]);
export const QA_002_REQUIRED_SCOPES = Object.freeze([...REQUIRED]);
const MUTATION_EVENTS = new Set(['route_to', 'stage_gate', 'prepare_route', 'teleport', 'gate_approach_recovery']);
const MAIN_EVENTS = [
  'scenario_start', 'opening_complete', 'cemetery_ambush_defeated',
  'cemetery_choice_complete', 'bell_eater_defeated', 'bell_eater_aftermath_complete',
  'teeth_complete', 'register_reconstructed', 'rootbound_defeated',
  'names_published', 'ashwing_defeated', 'ash_mill_completed',
  'senn_guard_defeat', 'soldier_completed', 'record_hall_entered',
  'record_haunting_cleared', 'blood_under_stone_completed',
  'halvern_guard_parried', 'last_witness_completed', 'assembly_completed',
  'witness_ending_completed',
];
const BRANCH_OUTCOMES = Object.freeze({
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
});

function requireOrderedEvents(checkpoints, events, label) {
  let cursor = 0;
  for (const event of events) {
    const index = checkpoints.findIndex((checkpoint, i) => i >= cursor && checkpoint.event === event);
    if (index < 0) throw new Error(`${label} lacks ordered ${event} proof`);
    cursor = index + 1;
  }
}

function requireBranchOutcomes(checkpoints, scope) {
  const [event, expected, restored, quest] = BRANCH_OUTCOMES[scope];
  const actual = checkpoints.filter(checkpoint => checkpoint.event === event && (!quest || checkpoint.quest === quest));
  for (const outcome of expected) {
    if (actual.filter(checkpoint => checkpoint.outcome === outcome).length !== 1) {
      throw new Error(`${scope} lacks one ${event}:${outcome} result`);
    }
  }
  if (!checkpoints.some(checkpoint => checkpoint.event === restored && (!quest || restored !== 'assembly_side_outcome_restored' || checkpoint.quest === quest))) {
    throw new Error(`${scope} lacks earned-save ${restored} proof`);
  }
}

function requireRouteOutcome(browser, scope) {
  const checkpoints = browser.checkpoints || [];
  if (!checkpoints.length) throw new Error(`${browser.browser}:${scope} has no real-input checkpoints`);
  for (const checkpoint of checkpoints) {
    if (MUTATION_EVENTS.has(checkpoint.event)) {
      throw new Error(`${browser.browser}:${scope} used diagnostic state mutation: ${checkpoint.event}`);
    }
  }
  if (scope === MAIN_SCOPE) {
    requireOrderedEvents(checkpoints, MAIN_EVENTS, `${browser.browser} main route`);
    if (checkpoints.some(checkpoint => checkpoint.event === 'opening_continue_restored')) {
      throw new Error(`${browser.browser} main route is not uninterrupted`);
    }
    const ending = checkpoints.find(checkpoint => checkpoint.event === 'witness_ending_completed');
    if (ending?.ending !== 'expose' || !Number.isInteger(ending.cards) || ending.cards < 1
      || !browser.final_telemetry?.quests?.completed?.includes('main_hart_remembers')) {
      throw new Error(`${browser.browser} main route did not prove the completed Witness ending`);
    }
  }
  if (scope === 'ending_matrix_partial') {
    const endings = checkpoints.filter(checkpoint => checkpoint.event === 'hart_ending_completed');
    const outcomes = new Set(endings.map(checkpoint => `${checkpoint.covenant}:${checkpoint.ending}`));
    for (const outcome of ['witness:expose', 'mercy:free', 'duty:bind', 'ash:kill']) {
      if (!outcomes.has(outcome)) throw new Error(`Hart ending matrix lacks ${outcome}`);
    }
    if (!checkpoints.some(checkpoint => checkpoint.event === 'hart_checkpoint_restored')) {
      throw new Error('Hart ending matrix did not restore an earned save');
    }
  } else if (scope === 'opening_save_continue_partial') {
    requireOrderedEvents(checkpoints, ['opening_complete', 'browser_pause_input_blocked',
      'browser_settings_changed', 'manual_save_created', 'opening_continue_restored',
      'browser_settings_persisted', 'browser_remapped_interaction', 'browser_defaults_restored'], scope);
    for (const [width, height] of [[1280, 720], [1920, 1080]]) {
      if (!checkpoints.some(event => event.event === 'browser_menu_resize' && event.width === width && event.height === height)) {
        throw new Error(`${scope} lacks ${width}x${height} focused-menu resize proof`);
      }
    }
  } else if (scope === 'browser_compatibility_smoke') {
    requireOrderedEvents(checkpoints, ['scenario_start', 'browser_keyboard_movement',
      'manual_save_created', 'opening_continue_restored', 'browser_save_durable',
      'browser_continue_input'], scope);
  } else if (scope === 'named_dead_route_partial') {
    for (const victim of ['bram', 'sella', 'oren']) {
      if (!checkpoints.some(checkpoint => checkpoint.event === 'named_candle_lit' && checkpoint.victim === victim)) {
        throw new Error(`${scope} lacks ${victim} candle proof`);
      }
    }
    if (!checkpoints.some(checkpoint => checkpoint.event === 'named_dead_side_quests_restored')) {
      throw new Error(`${scope} lacks earned-save named-dead restoration`);
    }
  } else if (Object.hasOwn(BRANCH_OUTCOMES, scope)) {
    requireBranchOutcomes(checkpoints, scope);
  }
}

export function assessQaCandidate(identity, reports, screenshotStat = statSync, acceptanceProfile = 'strict') {
  if (!['strict', 'functional_candidate'].includes(acceptanceProfile)) throw new Error('Unknown acceptance profile');
  const functionalCandidate = acceptanceProfile === 'functional_candidate';
  const required = functionalCandidate ? new Set([
    'Chrome:opening_save_continue_partial',
    ...['Edge', 'Firefox'].map(browser => `${browser}:browser_compatibility_smoke`),
  ]) : REQUIRED;
  const targetMisses = [];
  if (identity.total_bytes >= 100_000_000) throw new Error('Web candidate is not below 100 MB');
  const observed = new Set();
  for (const [index, report] of reports.entries()) {
    const label = `report ${index + 1}`;
    if ((report.acceptance_profile || 'strict') !== acceptanceProfile) throw new Error(`${label} has a different acceptance profile`);
    if (report.status !== 'pass' || report.observation_mode !== 'production_read_only') {
      throw new Error(`${label} is not a passing production read-only run`);
    }
    if (report.artifact?.fingerprint !== identity.fingerprint
      || JSON.stringify(report.artifact?.files) !== JSON.stringify(identity.files)) {
      throw new Error(`${label} used different or stale Web artifact bytes`);
    }
    if (!Array.isArray(report.browsers) || !report.browsers.length) {
      throw new Error(`${label} has no browser results`);
    }
    for (const browser of report.browsers) {
      const key = `${browser.browser}:${report.route_scope}`;
      if (browser.status !== 'pass' || browser.observation_mode !== 'production_read_only'
        || browser.route_scope !== report.route_scope) {
        throw new Error(`${key} is diagnostic, failed or mismatched`);
      }
      if (observed.has(key)) throw new Error(`Duplicate QA scope ${key}`);
      if (!required.has(key)) throw new Error(`Unexpected QA scope ${key}`);
      if ((browser.acceptance_profile || 'strict') !== acceptanceProfile) throw new Error(`${key} has a different acceptance profile`);
      if (browser.renderer_mode !== 'hardware' || !browser.renderer?.unmasked_renderer
        || /swiftshader|llvmpipe|software|basic render/i.test(browser.renderer.unmasked_renderer)) {
        throw new Error(`${key} lacks hardware renderer proof`);
      }
      if (!Array.isArray(browser.console_errors) || !Array.isArray(browser.network_failures)
        || browser.console_errors.length || browser.network_failures.length) {
        throw new Error(`${key} has browser console or network failures`);
      }
      const expectedMemoryMethod = browser.browser === 'Firefox'
        ? 'isolated_content_process_private_upper_bound' : 'isolated_renderer_process_private_upper_bound';
      if (!Number.isFinite(browser.runtime_memory_mb) || browser.runtime_memory_mb <= 0
        || browser.memory_method !== expectedMemoryMethod) {
        throw new Error(`${key} lacks a valid runtime memory measurement`);
      }
      if (browser.runtime_memory_mb >= 450) {
        if (!functionalCandidate) throw new Error(`${key} lacks a passing runtime memory measurement`);
        targetMisses.push(`${key}: runtime private-memory upper bound ${browser.runtime_memory_mb} MB exceeds 450 MB`);
      }
      if (!browser.final_screenshot || screenshotStat(browser.final_screenshot).size < 10_000) {
        throw new Error(`${key} lacks a captured gameplay screenshot`);
      }
      if ((report.route_scope === MAIN_SCOPE || (functionalCandidate && browser.browser === 'Chrome'))
        && browser.audio_unlock !== 'observed_running') {
        throw new Error(`${key} did not prove a user-unlocked real-time audio context`);
      }
      if (report.route_scope === MAIN_SCOPE) {
        const performance = browser.final_telemetry?.performance;
        if (!performance || Number(performance.samples) < 120
          || !Number.isFinite(performance.average_fps)
          || !Number.isFinite(performance.one_percent_low_fps)) {
          throw new Error(`${key} lacks complete native-720p browser performance evidence`);
        }
        if (performance.average_fps < 32 || performance.one_percent_low_fps < 30) {
          if (!functionalCandidate) throw new Error(`${key} lacks passing native-720p browser performance evidence`);
          targetMisses.push(`${key}: ${performance.average_fps} average / ${performance.one_percent_low_fps} 1% low FPS`);
        }
        targetMisses.push(...requireZonePerformance(browser.performance_by_zone, undefined, acceptanceProfile));
      }
      if (functionalCandidate) {
        if (!Array.isArray(browser.startup_runs) || !browser.startup_runs.length
          || browser.startup_runs.some(run => !Number.isFinite(run.navigation_to_control_ms) || !Number.isFinite(run.click_to_control_ms))) {
          throw new Error(`${key} lacks startup measurements`);
        }
        targetMisses.push(...(browser.target_misses || []).map(message => `${key}: ${message}`));
        if (browser.browser === 'Chrome') {
          const events = browser.checkpoints || [];
          if (!events.some(event => event.event === 'interaction_used' && event.id === 'sister_anwen')
            || !events.some(event => ['zone_arrival', 'seamless_boundary_crossed'].includes(event.event) && event.zone === 'wychwood')
            || !events.some(event => ['zone_arrival', 'seamless_boundary_crossed'].includes(event.event) && event.zone === 'greyfen')) {
            throw new Error(`${key} lacks actual Anwen and bridge return proof`);
          }
        }
      }
      requireRouteOutcome(browser, report.route_scope);
      observed.add(key);
    }
  }
  const missing = [...required].filter(key => !observed.has(key));
  if (missing.length) throw new Error(`Missing QA-002 scopes: ${missing.join(', ')}`);
  return {
    ticket: 'QA-002',
    acceptance_profile: acceptanceProfile,
    performance_certified: !functionalCandidate,
    listening_reviewed: false,
    target_misses: [...new Set(targetMisses)],
    status: 'accepted',
    complete_qa_002_acceptance: true,
    browser_certification_scope: functionalCandidate ? 'lean_functional_smoke' : 'exhaustive_campaign',
    exhaustive_browser_campaign_certified: !functionalCandidate,
    artifact_fingerprint: identity.fingerprint,
    artifact_bytes: identity.total_bytes,
    browser_scopes: [...observed].sort(),
    limitations: functionalCandidate ? ['Numerical performance targets are not certified.', 'Mix is not listening-reviewed.', 'Exhaustive autonomous browser campaign, boss and ending coverage was intentionally removed from release scope; it did not pass.', 'Unchanged native story/branch evidence is reused at its proven dependency scope.', 'Edge and Firefox have startup/input/save smoke coverage only.', 'Unavailable physical controllers are untested.'] : ['Graphical performance and semantic visual approval are separate gates.'],
  };
}

function parseCli(argv) {
  const options = { reports: [], acceptanceProfile: 'strict' };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = argv[++index];
    if (!value || value.startsWith('--')) throw new Error(`Missing value for ${flag}`);
    if (flag === '--report') options.reports.push(resolve(value));
    else if (flag === '--export') options.exportDir = resolve(value);
    else if (flag === '--output') options.output = resolve(value);
    else if (flag === '--acceptance-profile') options.acceptanceProfile = value;
    else throw new Error(`Unknown option ${flag}`);
  }
  if (!options.exportDir || !options.output || !options.reports.length) {
    throw new Error('Usage: --export DIR --output FILE --report FILE [--report FILE ...]');
  }
  return options;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const options = parseCli(process.argv.slice(2));
  const result = { ticket: 'QA-002', status: 'fail', acceptance_profile: options.acceptanceProfile, complete_qa_002_acceptance: false };
  try {
    const identity = artifactIdentity(options.exportDir);
    const reports = options.reports.map(path => JSON.parse(readFileSync(path, 'utf8')));
    Object.assign(result, assessQaCandidate(identity, reports, statSync, options.acceptanceProfile));
  } catch (error) {
    result.failure = error.message;
  }
  if (!existsSync(dirname(options.output))) throw new Error('QA-002 report output directory is missing');
  writeFileSync(options.output, `${JSON.stringify(result, null, 2)}\n`);
  console.log(`QA-002 CANDIDATE: ${result.status.toUpperCase()}${result.failure ? ` - ${result.failure}` : ''}`);
  if (result.status !== 'accepted') process.exitCode = 1;
}
