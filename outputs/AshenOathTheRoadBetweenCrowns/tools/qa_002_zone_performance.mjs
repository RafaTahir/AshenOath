export const REQUIRED_BROWSER_ZONES = Object.freeze([
  'greyfen', 'wychwood', 'vargan_court', 'record_hall', 'hart_glade',
]);

export class ZonePerformanceEvidence {
  constructor() {
    this.zones = new Map();
  }

  observe(state) {
    const zone = state?.zone;
    const performance = state?.performance;
    if (!state?.ready || state?.transition_pending || !state?.player?.can_control
      || !zone || performance?.zone !== zone || Number(performance.samples) < 120
      || !Number.isFinite(performance.average_fps)
      || !Number.isFinite(performance.one_percent_low_fps)) return;
    const previous = this.zones.get(zone);
    this.zones.set(zone, {
      samples: Math.max(previous?.samples || 0, performance.samples),
      min_average_fps: Math.min(previous?.min_average_fps ?? Infinity, performance.average_fps),
      min_one_percent_low_fps: Math.min(previous?.min_one_percent_low_fps ?? Infinity, performance.one_percent_low_fps),
    });
  }

  summary() {
    return Object.fromEntries([...this.zones.entries()].sort(([a], [b]) => a.localeCompare(b)));
  }
}

export function requireZonePerformance(evidence, zones = REQUIRED_BROWSER_ZONES, acceptanceProfile = 'strict') {
  if (!['strict', 'functional_candidate'].includes(acceptanceProfile)) throw new Error('Unknown acceptance profile');
  const targetMisses = [];
  for (const zone of zones) {
    const sample = evidence?.[zone];
    if (!sample || !Number.isInteger(sample.samples) || sample.samples < 120
      || !Number.isFinite(sample.min_average_fps)
      || !Number.isFinite(sample.min_one_percent_low_fps)) {
      throw new Error(`Browser route lacks complete ${zone} performance evidence`);
    }
    if (sample.min_average_fps < 32 || sample.min_one_percent_low_fps < 30) {
      const message = `Browser ${zone} performance ${sample.min_average_fps.toFixed(2)} avg / ${sample.min_one_percent_low_fps.toFixed(2)} 1% low`;
      if (acceptanceProfile === 'strict') throw new Error(message);
      targetMisses.push(message);
    }
  }
  return targetMisses;
}
