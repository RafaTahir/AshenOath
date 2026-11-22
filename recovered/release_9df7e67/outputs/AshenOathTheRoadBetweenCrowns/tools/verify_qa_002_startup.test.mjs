import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('./verify_qa_002_browser.mjs', import.meta.url), 'utf8');
const body = source.slice(source.indexOf('async function activateNewGame('), source.indexOf('async function startNewGame('));

test('mouse startup propagates original failure without keyboard rescue', async () => {
  const failure = new Error('readiness failure');
  let clicks = 0;
  let keys = 0;
  const context = vm.createContext({
    clickPoint: async () => { clicks++; },
    waitForNewGameReady: async () => { throw failure; },
    tapKey: async () => { keys++; },
  });
  vm.runInContext(body, context);
  await assert.rejects(context.activateNewGame({}, {}), error => error === failure);
  assert.equal(clicks, 1);
  assert.equal(keys, 0);
});

test('mouse startup returns observed readiness after exactly one click', async () => {
  const ready = { zone: 'greyfen' };
  let clicks = 0;
  const context = vm.createContext({
    clickPoint: async () => { clicks++; },
    waitForNewGameReady: async () => ready,
  });
  vm.runInContext(body, context);
  assert.equal(await context.activateNewGame({}, {}), ready);
  assert.equal(clicks, 1);
});

test('extended startup observation cannot produce an acceptance pass', async () => {
  const statusExpression = source.match(/status: (startupDiagnostic \? "diagnostic" : "pass")/)[1];
  const browserStatus = vm.runInNewContext(statusExpression, { startupDiagnostic: true });
  const reportBody = source.slice(source.lastIndexOf('const report = {'));
  const routeFlags = Object.fromEntries(
    [...new Set(reportBody.match(/\bthrough[A-Z][A-Za-z]+\b/g) || [])].map(name => [name, false]),
  );
  let exitCode;
  let savedReport;
  const context = vm.createContext({
    ...routeFlags,
    fullCampaign: false, openingOnly: true, openingSaveContinue: false, endingMatrix: false, shrineMatrix: false, reportMatrix: false, widowMatrix: false, ironMatrix: false, returnedSoldierMatrix: false, bitterRootsMatrix: false, blackDogMatrix: false, namedDeadMatrix: false, rooksMapMatrix: false, millersMeasureMatrix: false, bannerlessMatrix: false, ledgerMatrix: false, edricMatrix: false, millMatrix: false, sennMatrix: false,
    productionObserver: false, diagnosticPreparation: false,
    exportDir: 'fixture', reportPath: 'fixture.json', QA_TEMP_ROOT: 'fixture',
    candidateIdentity: { fingerprint: 'fixture', files: [] },
    browsers: [['Chrome', 'fixture']],
    testBrowser: async () => ({ status: browserStatus, failure: 'diagnostic-only' }),
    server: { close() {} }, mkdirSync() {}, resolve: value => value,
    writeFileSync: (_path, value) => { savedReport = JSON.parse(value); },
    console: { log() {}, error() {} }, process: { exit: value => { exitCode = value; } },
  });
  await vm.runInContext(`(async () => { ${reportBody} })()`, context);
  assert.equal(savedReport.status, 'fail');
  assert.equal(savedReport.browsers[0].status, 'diagnostic');
  assert.equal(exitCode, 1);
});

test('headed diagnosis removes the headless switch without changing renderer selection', () => {
  const expression = source.match(/\.\.\.(\(presentationMode === "headless" \? \["--headless=new"\] : \[\]\))/)[1];
  assert.equal(vm.runInNewContext(expression, { presentationMode: 'headed' }).length, 0);
  assert.equal(vm.runInNewContext(expression, { presentationMode: 'headless' })[0], '--headless=new');
});

test('startup profiling stops at first controllable gameplay before route traversal', () => {
  const startupBody = source.slice(
    source.indexOf('async function startNewGame('),
    source.indexOf('async function driveToGate('),
  );
  assert.ok(startupBody.includes('await onStartupReady();'));
  assert.ok(
    startupBody.indexOf('await onStartupReady();') > startupBody.indexOf('await waitForNewGameReady(cdp, 10000);'),
    'profiling must include the complete startup readiness path',
  );

  const routeBody = source.slice(
    source.indexOf('const routeScope = routeTransport(cdp);'),
    source.indexOf('if (fullCampaign) {', source.indexOf('const routeScope = routeTransport(cdp);')),
  );
  assert.ok(routeBody.includes('finishStartupProfile'));
  assert.ok(!routeBody.includes('window.__ASHEN_WEBGL_PROFILE__'));
});
