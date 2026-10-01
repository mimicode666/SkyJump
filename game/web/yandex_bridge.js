/* Godot Web adapter. The loopback build never requests the Yandex SDK. */
(() => {
  'use strict';
  if (window.SkyJumpPlatform) return;
  let sdk = null;
  let listener = null;
  let status = 'idle';
  let language = 'ru';
  let readyWanted = false;
  let readySent = false;
  let playingWanted = false;
  let playingSent = false;
  let sdkPaused = false;
  let hidden = false;
  let blurred = false;
  let request = null;
  let suspended = false;
  let initPromise = null;
  const emit = event => listener?.(JSON.stringify(event));
  const available = () => status === 'ready' && typeof sdk?.adv?.showRewardedVideo === 'function';
  const state = () => emit({type: 'state', status, language, available: available()});
  function sync() {
    const blocked = sdkPaused || hidden || blurred || request !== null;
    if (blocked !== suspended) {
      suspended = blocked;
      emit({type: 'suspend', value: suspended});
    }
    if (!sdk) return;
    if (readyWanted && !readySent) {
      sdk.features?.LoadingAPI?.ready();
      readySent = true;
    }
    const playing = readySent && playingWanted && !blocked;
    if (playing !== playingSent) {
      playingSent = playing;
      if (playing) sdk.features?.GameplayAPI?.start();
      else sdk.features?.GameplayAPI?.stop();
    }
  }
  function bindFocus() {
    hidden = document.hidden;
    blurred = !document.hasFocus();
    document.addEventListener('visibilitychange', () => { hidden = document.hidden; sync(); });
    window.addEventListener('blur', () => { blurred = true; sync(); });
    window.addEventListener('focus', () => { blurred = false; sync(); });
    sync();
  }
  function loadSdk() {
    if (window.YaGames) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/sdk.js';
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error('sdk_load_failed'));
      document.head.appendChild(script);
    });
  }
  async function initialize(qa) {
    document.addEventListener('contextmenu', event => {
      if (event.target?.id === 'canvas') event.preventDefault();
    });
    if (!qa) bindFocus();
    const local = ['localhost', '127.0.0.1', '[::1]', '::1', ''].includes(location.hostname);
    if (local || qa) {
      // Local translation preview only; hosted games always use SDK language.
      const preview = new URLSearchParams(location.search || '').get('lang');
      language = preview === 'en' ? 'en' : 'ru';
      status = 'local'; state(); return;
    }
    status = 'loading'; state();
    let timeout;
    try {
      sdk = await Promise.race([
        loadSdk().then(() => window.YaGames.init()),
        new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('sdk_timeout')), 12000); })
      ]);
      language = sdk.environment?.i18n?.lang || 'ru';
      sdk.on('game_api_pause', () => { sdkPaused = true; sync(); });
      sdk.on('game_api_resume', () => { sdkPaused = false; sync(); });
      status = 'ready'; state(); sync();
    } catch (_) {
      sdk = null;
      status = 'unavailable'; state();
    } finally { clearTimeout(timeout); }
  }
  window.SkyJumpPlatform = {
    listen(callback) { listener = callback; state(); emit({type: 'suspend', value: suspended}); },
    init(qa = false) { initPromise ??= initialize(qa); return initPromise; },
    markReady() { readyWanted = true; sync(); },
    setGameplay(playing) { playingWanted = Boolean(playing); sync(); },
    nowSeconds() {
      const ms = typeof sdk?.serverTime === 'function' ? sdk.serverTime() : Date.now();
      return Math.floor(ms / 1000);
    },
    // Synchronous mirror closes the reload race before Godot's IndexedDB flush.
    // Storage may be blocked in an iframe; Godot keeps its user:// fallback.
    loadProfile(path) {
      try { return window.localStorage.getItem('skyjump:' + path) || ''; }
      catch (_) { return ''; }
    },
    saveProfile(path, text) {
      try { window.localStorage.setItem('skyjump:' + path, text); return true; }
      catch (_) { return false; }
    },
    clearProfile(path) {
      try { window.localStorage.removeItem('skyjump:' + path); } catch (_) { /* blocked */ }
    },
    requestRewarded(id, placement) {
      if (!available() || request || suspended || !['continue', 'double_coins'].includes(placement)) {
        emit({type: 'reward', id, granted: false}); return;
      }
      const current = {id, granted: false, done: false};
      request = current;
      sync();
      const finish = () => {
        if (current.done) return;
        current.done = true;
        request = null;
        sync();
        emit({type: 'reward', id, granted: current.granted});
      };
      try {
        sdk.adv.showRewardedVideo({callbacks: {
          onOpen: () => { if (!current.done) sync(); },
          onRewarded: () => { if (!current.done) current.granted = true; },
          onClose: finish,
          onError: finish
        }});
      } catch (_) { finish(); }
    }
  };
})();
