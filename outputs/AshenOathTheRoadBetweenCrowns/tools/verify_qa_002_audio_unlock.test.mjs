import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const routeSource = readFileSync(new URL('./verify_qa_002_browser.mjs', import.meta.url), 'utf8');
const smokeSource = readFileSync(new URL('./verify_web_browser.mjs', import.meta.url), 'utf8');
const firefoxProbe = readFileSync(new URL('./firefox_audio_context_probe.js', import.meta.url), 'utf8');
const audioFunction = routeSource.slice(
  routeSource.indexOf('function audioContextTimeline('),
  routeSource.indexOf('function consoleWarningLine('),
);
const context = vm.createContext({});
vm.runInContext(audioFunction, context);

test('browser QA cannot bypass the user gesture needed to unlock audio', () => {
  assert.ok(!routeSource.includes('--autoplay-policy=no-user-gesture-required'));
  assert.ok(!smokeSource.includes('--autoplay-policy=no-user-gesture-required'));
  assert.match(routeSource, /cdp\.send\("WebAudio\.enable"\)/);
  assert.match(routeSource, /Web Audio context never entered running state after real browser input/);
});

test('audio timeline retains only context state transitions in order', () => {
  const timeline = context.audioContextTimeline({ events: [
    { method: 'Runtime.consoleAPICalled', params: {} },
    { method: 'WebAudio.contextCreated', params: { context: {
      contextId: 'a', contextType: 'realtime', contextState: 'suspended',
    } } },
    { method: 'WebAudio.contextChanged', params: { context: {
      contextId: 'a', contextType: 'realtime', contextState: 'running',
    } } },
  ] });
  assert.deepEqual(Array.from(timeline, item => ({ ...item })), [
    { context_id: 'a', type: 'realtime', state: 'suspended' },
    { context_id: 'a', type: 'realtime', state: 'running' },
  ]);
});

test('offline audio context does not count as gameplay unlock', () => {
  const timeline = context.audioContextTimeline({ events: [
    { method: 'WebAudio.contextCreated', params: { context: {
      contextId: 'offline', contextType: 'offline', contextState: 'running',
    } } },
  ] });
  assert.equal(timeline.some(item => item.type === 'realtime' && item.state === 'running'), false);
});

test('Firefox probe observes only a real-time context entering running after input', () => {
  const window = {};
  window.top = window;
  class FakeAudioContext {
    state = 'suspended';
    listeners = [];
    addEventListener(name, listener) {
      if (name === 'statechange') this.listeners.push(listener);
    }
    resume() {
      this.state = 'running';
      for (const listener of this.listeners) listener();
    }
  }
  window.AudioContext = FakeAudioContext;
  window.OfflineAudioContext = class {};
  vm.runInNewContext(firefoxProbe, { window, performance: { now: () => 42 } });
  const context = new window.AudioContext();
  assert.equal(context instanceof FakeAudioContext, true);
  assert.deepEqual(Array.from(window.__ASHEN_QA_AUDIO_TIMELINE__, item => item.state), ['suspended']);
  context.resume();
  assert.deepEqual(Array.from(window.__ASHEN_QA_AUDIO_TIMELINE__, item => item.state), ['suspended', 'running']);
  assert.equal(window.OfflineAudioContext.name, '');
  assert.match(routeSource, /firefox_audio_context_probe\.js/);
  assert.match(routeSource, /const audioContexts = await observedAudioContexts\(cdp, name\)/);
});
