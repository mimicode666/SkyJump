import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../web/yandex_bridge.js', import.meta.url), 'utf8');
function setup(options = {}) {
  const events = [], calls = [], handlers = {}, dom = {}, win = {}, scripts = [];
  let callbacks;
  const sdk = {
    environment: {i18n: {lang: 'ru'}},
    features: {
      LoadingAPI: {ready: () => calls.push('ready')},
      GameplayAPI: {start: () => calls.push('start'), stop: () => calls.push('stop')}
    },
    on: (name, callback) => { handlers[name] = callback; },
    serverTime: () => 1800000000123,
    adv: {showRewardedVideo: args => { callbacks = args.callbacks; calls.push('ad'); }}
  };
  const context = {
    localStorage: new class {
      data = new Map();
      getItem(key) { return this.data.get(key) ?? null; }
      setItem(key, value) { this.data.set(key, value); }
      removeItem(key) { this.data.delete(key); }
    }(),
    location: {hostname: options.host ?? 'yandex-test.invalid'},
    setTimeout: options.setTimeout ?? setTimeout,
    clearTimeout, Date,
    document: {
      hidden: false, hasFocus: () => true,
      addEventListener: (name, callback) => { dom[name] = callback; },
      createElement: () => ({}),
      head: {appendChild: script => { scripts.push(script.src); script.onerror(); }}
    },
    addEventListener: (name, callback) => { win[name] = callback; },
    YaGames: options.noScript ? undefined : {init: options.init ?? (async () => sdk)}
  };
  context.window = context;
  vm.runInNewContext(source, context);
  const bridge = context.SkyJumpPlatform;
  bridge.listen(json => events.push(JSON.parse(json)));
  return {bridge, sdk, events, calls, handlers, dom, win, context, scripts,
    get ad() { return callbacks; },
    rewards: () => events.filter(event => event.type === 'reward')};
}

test('loopback and QA never fetch or initialize an SDK', async () => {
  for (const options of [{host: '127.0.0.1'}, {host: 'localhost'}, {qa: true}]) {
    const t = setup({...options, init: () => { throw Error('must not initialize'); }});
    await t.bridge.init(options.qa);
    assert.equal(t.events.at(-1).status, 'local');
    assert.deepEqual(t.scripts, []);
    t.bridge.requestRewarded(1, 'continue');
    assert.equal(t.rewards()[0].granted, false);
  }
});

test('ready follows actual game readiness; gameplay events are deduplicated', async () => {
  const t = setup();
  await t.bridge.init();
  t.bridge.setGameplay(true);
  assert.deepEqual(t.calls, []);
  t.bridge.markReady(); t.bridge.markReady(); t.bridge.setGameplay(true);
  t.bridge.setGameplay(false); t.bridge.setGameplay(false);
  assert.deepEqual(t.calls, ['ready', 'start', 'stop']);
  assert.equal(t.bridge.nowSeconds(), 1800000000);
});

test('menu can become ready before asynchronous SDK initialization', async () => {
  let resolve;
  const t = setup({init: () => new Promise(done => { resolve = done; })});
  t.bridge.markReady();
  const pending = t.bridge.init();
  await Promise.resolve();
  resolve(t.sdk);
  await pending;
  assert.deepEqual(t.calls, ['ready']);
});

test('SDK load failure, rejected initialization and timeout degrade without rewards', async () => {
  for (const options of [
    {noScript: true},
    {init: async () => { throw Error('not available'); }},
    {init: () => new Promise(() => {}), setTimeout: callback => setTimeout(callback, 1)}
  ]) {
    const t = setup(options);
    await t.bridge.init();
    assert.equal(t.events.at(-1).status, 'unavailable');
    t.bridge.requestRewarded(5, 'double_coins');
    assert.deepEqual(t.rewards(), [{type: 'reward', id: 5, granted: false}]);
    if (options.noScript) assert.deepEqual(t.scripts, ['/sdk.js']);
  }
});

test('nested visibility, focus and SDK pauses resume only after all reasons clear', async () => {
  const t = setup();
  await t.bridge.init(); t.bridge.markReady(); t.bridge.setGameplay(true);
  t.handlers.game_api_pause(); t.win.blur();
  t.context.document.hidden = true; t.dom.visibilitychange();
  t.handlers.game_api_resume(); t.win.focus();
  assert.equal(t.calls.at(-1), 'stop');
  t.context.document.hidden = false; t.dom.visibilitychange();
  assert.equal(t.calls.at(-1), 'start');
  t.bridge.setGameplay(false); // Manual pause or menu must survive SDK resume.
  t.handlers.game_api_pause(); t.handlers.game_api_resume();
  assert.equal(t.calls.at(-1), 'stop');
});

test('reward needs onRewarded plus completion; duplicates and overlapping requests are ignored', async () => {
  const t = setup();
  await t.bridge.init(); t.bridge.markReady();
  t.bridge.requestRewarded(7, 'double_coins');
  t.bridge.requestRewarded(8, 'continue');
  assert.deepEqual(t.rewards(), [{type: 'reward', id: 8, granted: false}]);
  t.ad.onOpen(); t.ad.onRewarded(); t.ad.onRewarded();
  assert.equal(t.rewards().length, 1); // Never resume over an open ad.
  t.ad.onClose(); t.ad.onClose(); t.ad.onError(); t.ad.onRewarded();
  assert.deepEqual(t.rewards().at(-1), {type: 'reward', id: 7, granted: true});
  assert.equal(t.rewards().length, 2);
  assert.equal(t.calls.filter(value => value === 'ad').length, 1);
});

test('closing, errors, thrown exceptions and late reward cannot grant coins', async () => {
  const t = setup(); await t.bridge.init();
  t.bridge.requestRewarded(1, 'continue'); t.ad.onOpen(); t.ad.onClose(); t.ad.onRewarded();
  t.bridge.requestRewarded(2, 'double_coins'); t.ad.onError();
  t.sdk.adv.showRewardedVideo = () => { throw Error('ad unavailable'); };
  t.bridge.requestRewarded(3, 'continue');
  assert.deepEqual(t.rewards().map(result => result.granted), [false, false, false]);
});

test('advertising cannot resume a manually paused game', async () => {
  const t = setup(); await t.bridge.init(); t.bridge.markReady();
  t.bridge.requestRewarded(1, 'continue');
  t.handlers.game_api_pause(); t.ad.onRewarded(); t.ad.onClose();
  assert.equal(t.events.filter(event => event.type === 'suspend').at(-1).value, true);
  t.handlers.game_api_resume();
  assert.deepEqual(t.calls, ['ready', 'ad']);
});

test('profile mirror is synchronous, isolated by save path and tolerates blocked storage', () => {
  const t = setup();
  assert.equal(t.bridge.saveProfile('wallet.cfg', 'coins=13;owned=bunny'), true);
  assert.equal(t.bridge.loadProfile('wallet.cfg'), 'coins=13;owned=bunny');
  assert.equal(t.bridge.loadProfile('qa-wallet.cfg'), '');
  t.bridge.clearProfile('wallet.cfg');
  assert.equal(t.bridge.loadProfile('wallet.cfg'), '');
  Object.defineProperty(t.context, 'localStorage', {get() { throw Error('blocked'); }});
  assert.equal(t.bridge.loadProfile('wallet.cfg'), '');
  assert.equal(t.bridge.saveProfile('wallet.cfg', 'data'), false);
});
