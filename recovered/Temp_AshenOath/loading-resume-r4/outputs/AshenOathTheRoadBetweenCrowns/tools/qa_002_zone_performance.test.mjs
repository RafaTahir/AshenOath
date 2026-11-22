import assert from 'node:assert/strict';
import test from 'node:test';
import { REQUIRED_BROWSER_ZONES, ZonePerformanceEvidence, requireZonePerformance } from './qa_002_zone_performance.mjs';

function observation(zone, average, low, options = {}) {
  return {
    ready: true, transition_pending: false, zone,
    player: { can_control: true },
    performance: { zone, samples: 180, average_fps: average, one_percent_low_fps: low },
    ...options,
  };
}

test('earlier red gameplay zone survives a passing final zone window', () => {
  const evidence = new ZonePerformanceEvidence();
  for (const zone of REQUIRED_BROWSER_ZONES) evidence.observe(observation(zone, 45, 36));
  evidence.observe(observation('greyfen', 31, 27));
  evidence.observe(observation('greyfen', 50, 44));
  assert.equal(evidence.summary().greyfen.min_one_percent_low_fps, 27);
  assert.throws(() => requireZonePerformance(evidence.summary()), /Browser greyfen performance 31.00 avg \/ 27.00 1% low/);
});

test('stale, incomplete and non-playable samples cannot supply a zone', () => {
  const evidence = new ZonePerformanceEvidence();
  evidence.observe(observation('greyfen', 45, 36, { performance: { zone: 'wychwood', samples: 180, average_fps: 45, one_percent_low_fps: 36 } }));
  evidence.observe(observation('greyfen', 45, 36, { transition_pending: true }));
  evidence.observe(observation('greyfen', 45, 36, { player: { can_control: false } }));
  evidence.observe(observation('greyfen', 45, 36, { performance: { zone: 'greyfen', samples: 119, average_fps: 45, one_percent_low_fps: 36 } }));
  assert.deepEqual(evidence.summary(), {});
  assert.throws(() => requireZonePerformance(evidence.summary()), /lacks complete greyfen performance evidence/);
});

test('all five required gameplay zones with sufficient frames pass', () => {
  const evidence = new ZonePerformanceEvidence();
  for (const zone of REQUIRED_BROWSER_ZONES) evidence.observe(observation(zone, 32, 30));
  assert.doesNotThrow(() => requireZonePerformance(evidence.summary()));
});
