import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { QA_002_REQUIRED_SCOPES } from './verify_qa_002_candidate.mjs';

const source = readFileSync(join(fileURLToPath(new URL('.', import.meta.url)), 'run_release_gate.ps1'), 'utf8');
const browserSource = readFileSync(join(fileURLToPath(new URL('.', import.meta.url)), 'verify_qa_002_browser.mjs'), 'utf8');

test('release branch routes exactly cover the required Chrome matrix', () => {
  const routes = [...source.matchAll(/@\{ slug = "([a-z_]+)"; flag = "([a-z-]+)" \}/g)];
  const expected = QA_002_REQUIRED_SCOPES
    .filter(scope => scope.startsWith('Chrome:') && !scope.endsWith(':campaign_main_player_driven'))
    .map(scope => scope.slice('Chrome:'.length));
  assert.equal(routes.length, expected.length);
  assert.deepEqual(routes.map(([, slug]) => `${slug}_partial`).sort(), expected.sort());
  for (const [, slug, flag] of routes) {
    assert.equal(flag.replaceAll('-', '_'), slug === 'named_dead_route' ? 'named_dead_matrix' : slug);
  }
});

test('release gate uses production bytes and requires the QA-002 candidate result', () => {
  assert.match(source, /Invoke-QA002BranchMatrix\s*\n\s*\}/);
  assert.match(source, /\$requiredGateNames \+= "qa_002_candidate"/);
  assert.match(source, /Get-QA002RouteReport "verify_web_002_browser" "web_002_browser\.json"/);
  assert.match(source, /"--production-observer", "true"/);
  const fullCampaignRuns = [...source.matchAll(/Invoke-ExternalGate "verify_web_002_browser"[\s\S]*?\) -TimeoutOverride/g)];
  assert.equal(fullCampaignRuns.length, 3);
  assert.ok(fullCampaignRuns.every(([run]) => run.includes('"--renderer", "hardware"')));
  assert.ok(fullCampaignRuns.every(([run]) => run.includes('"--enforce-performance", $EnforceBrowserPerformance')
    && run.includes('"--acceptance-profile", $AcceptanceProfile')));
  assert.match(source, /\$CampaignBrowser = if \(\$FunctionalCandidate\) \{ "chrome" \} else \{ "all" \}/);
  assert.match(source, /foreach \(\$compatibilityBrowser in @\("edge", "firefox"\)\)/);
  assert.match(source, /if \(\$FunctionalCandidate\) \{ "--opening-save-continue" \} else \{ "--full-campaign" \}/);
  assert.match(source, /"--browser-smoke", "true"/);
  assert.match(source, /foreach \(\$route in \$\(if \(\$FunctionalCandidate\) \{ @\(\) \} else \{ \$Qa002BranchRoutes \}\)\)/);
  assert.match(source, /Invoke-ExternalGate \$gateName \$Node @[\s\S]*?"--browser", "chrome",\s*"--renderer", "hardware"/);
  assert.doesNotMatch(source, /Web QA Browser|qa_web_export|Sync-QAWebPacks/);
  assert.match(browserSource, /requestedBrowser === "all" && browsers\.length !== browserCatalog\.length/);
});

test('mobile campaign runs select Chrome and Edge without unsupported Firefox emulation', () => {
  const mobileRuns = [...source.matchAll(/Invoke-ExternalGate "verify_web_002_mobile"[\s\S]*?\) -TimeoutOverride/g)];
  assert.equal(mobileRuns.length, 3);
  assert.ok(mobileRuns.every(([run]) => run.includes('"--browser", "chromium"')
    && run.includes('"--renderer", "hardware"')));
  const ticketGate = readFileSync(join(fileURLToPath(new URL('.', import.meta.url)), 'run_ticket_gate.ps1'), 'utf8');
  assert.match(ticketGate, /\$gate -eq "verify_web_002_mobile"[\s\S]*?"--browser", "chromium",\s*"--renderer", "hardware"/);
  const result = spawnSync(process.execPath, [
    join(fileURLToPath(new URL('.', import.meta.url)), 'verify_qa_002_browser.mjs'),
    '--browser', 'all', '--mobile', 'true',
  ], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Firefox mobile emulation is unsupported/);
});
