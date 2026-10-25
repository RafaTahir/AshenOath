import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash, webcrypto } from 'node:crypto';
import vm from 'node:vm';

const shell = readFileSync(new URL('../web_boot_shell.html', import.meta.url), 'utf8');
const bridge = shell.slice(shell.indexOf('let saveConfirmation = 0;'), shell.indexOf('function setBootState('));
const path = '/userfs/ashen_oath_save.json';
const pointer = '/userfs/ashen_oath_resume.json';
const bytes = Buffer.from('{"journey_id":"earned-journey"}');
const hash = createHash('sha256').update(bytes).digest('hex');

function storage(snapshots, failure = '') {
  let reads = 0, clock = 0;
  const callbacks = [], timers = new Map();
  const context = {
    window: {}, crypto: webcrypto, performance: { now: () => clock },
    setTimeout(fn, delay) {
      const id = setImmediate(() => { timers.delete(id); clock += delay; fn(); });
      timers.set(id, true);
      return id;
    },
    clearTimeout(id) { clearImmediate(id); timers.delete(id); },
    indexedDB: {
      open(name) {
        assert.equal(name, '/userfs');
        const request = {};
        const snapshot = snapshots[Math.min(reads++, snapshots.length - 1)] || {};
        queueMicrotask(() => {
          if (failure === 'blocked') { request.onblocked(); return; }
          if (failure === 'missing') {
            request.transaction = { abort: () => request.onerror() };
            request.onupgradeneeded(); return;
          }
          request.result = {
            close() {}, objectStoreNames: { contains: name => name === 'FILE_DATA' },
            transaction(name, mode) {
              assert.equal(name, 'FILE_DATA'); assert.equal(mode, 'readonly');
              const transaction = {
                abort() { transaction.onabort(); },
                objectStore() {
                  return { get(key) {
                    const result = {};
                    queueMicrotask(() => result.onsuccess({ target: { result: snapshot[key] ? { contents: snapshot[key] } : undefined } }));
                    return result;
                  } };
                },
              };
              queueMicrotask(() => queueMicrotask(() => transaction.oncomplete()));
              return transaction;
            },
          };
          request.onsuccess();
        });
        return request;
      },
    },
  };
  vm.runInNewContext(bridge, context);
  return {
    confirm: (expected, generation) => context.window.__ashenOathSaveDurability.confirm(JSON.stringify(expected), generation, result => callbacks.push(JSON.parse(result))),
    callbacks, get reads() { return reads; }, get pendingTimers() { return timers.size; },
  };
}

test('durability requires exact persisted save and resume-pointer bytes', async () => {
  const fixture = storage([{ [path]: bytes }, { [path]: bytes, [pointer]: bytes }]);
  await fixture.confirm({ [path]: hash, [pointer]: hash }, 3);
  assert.deepEqual(fixture.callbacks, [{ generation: 3, ok: true }]);
  assert.equal(fixture.reads, 2);
  assert.equal(fixture.pendingTimers, 0);
});

test('stale persisted content never acknowledges a successful write', async () => {
  const fixture = storage([{ [path]: Buffer.from('old journey') }]);
  await fixture.confirm({ [path]: hash }, 4);
  assert.equal(fixture.callbacks.length, 1);
  assert.equal(fixture.callbacks[0].ok, false);
  assert.equal(fixture.pendingTimers, 0);
});

test('a superseded confirmation cannot acknowledge the older generation', async () => {
  const fixture = storage([{ [path]: bytes }]);
  await Promise.all([fixture.confirm({ [path]: hash }, 5), fixture.confirm({ [path]: hash }, 6)]);
  assert.deepEqual(fixture.callbacks, [{ generation: 6, ok: true }]);
  assert.equal(fixture.pendingTimers, 0);
});

for (const failure of ['blocked', 'missing']) {
  test(`storage ${failure} fails boundedly without creating a database`, async () => {
    const fixture = storage([], failure);
    await fixture.confirm({ [path]: hash }, 7);
    assert.equal(fixture.callbacks[0].ok, false);
    assert.match(fixture.callbacks[0].error, /storage/i);
    assert.equal(fixture.pendingTimers, 0);
  });
}
