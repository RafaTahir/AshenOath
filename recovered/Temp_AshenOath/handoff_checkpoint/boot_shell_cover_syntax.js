(() => {
      const boot = document.getElementById('boot');
      const start = document.getElementById('start');
      const status = document.getElementById('status');
      const progress = document.getElementById('progress');
      const road = document.getElementById('road-canvas');
      const buildMeta = document.getElementById('build-meta');
      const ctx = road.getContext('2d');
      const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      const SHELL_BUILD_ID = 'RECOVERY-004-CANDIDATE';
      const RUNTIME_PACK_CONTRACT = 'recovery-004-20260831';
      let engine = null, started = false, ready = false, engineBooted = false, last = 0, score = 0;
      let gamepadPressed = false;
      const bootMetrics = {
        state: 'shell_ready',
        first_paint_ms: performance.now(),
        engine_start_ms: 0,
        engine_ready_ms: 0,
        progress_samples: 0,
        input_events: 0,
        last_input: '',
        crow_score: 0,
        build_id: SHELL_BUILD_ID,
        runtime_pack_contract: RUNTIME_PACK_CONTRACT,
      };
      window.__ashenOathBoot = bootMetrics;
      document.documentElement.dataset.bootState = bootMetrics.state;
      buildMeta.textContent = SHELL_BUILD_ID + ' | packs ' + RUNTIME_PACK_CONTRACT;
      performance.mark('ashen-oath-first-paint');
      function setBootState(state, extra = {}) {
        bootMetrics.state = state;
        Object.assign(bootMetrics, extra);
        document.documentElement.dataset.bootState = state;
        window.dispatchEvent(new CustomEvent('ashen-oath-boot', { detail: { ...bootMetrics } }));
      }
      function setStatus(text) { status.textContent = text; }
      async function prefetchOpeningPack() {
        try {
          const manifestResponse = await fetch('runtime_pack_manifest.json', { cache: 'no-cache' });
          if (!manifestResponse.ok) throw new Error(`runtime pack manifest HTTP ${manifestResponse.status}`);
          const manifest = await manifestResponse.json();
          const opening = manifest?.packs?.opening;
          if (!opening?.url) throw new Error('runtime pack manifest has no opening pack URL');
          const packUrl = new URL(opening.url, window.location.href).href;
          setBootState(bootMetrics.state, { opening_prefetch_state: 'loading' });
          const packResponse = await fetch(packUrl, { cache: 'force-cache' });
          if (!packResponse.ok) throw new Error(`opening pack HTTP ${packResponse.status}`);
          const payload = await packResponse.arrayBuffer();
          if (opening.bytes > 0 && payload.byteLength !== opening.bytes) {
            throw new Error(`opening pack bytes ${payload.byteLength} != ${opening.bytes}`);
          }
          setBootState(bootMetrics.state, {
            opening_prefetch_state: 'ready',
            opening_prefetch_bytes: payload.byteLength,
          });
        } catch (error) {
          // Godot retains authoritative retry, hash verification, and error UI.
          // A shell prefetch failure must not prevent the engine from starting.
          setBootState(bootMetrics.state, {
            opening_prefetch_state: 'failed',
            opening_prefetch_error: String(error),
          });
        }
      }
      let crowY = 90, crowVelocity = 0, branchOffset = 0, nextBranch = 260;
      const branches = [];
      const ember = { x: 460, y: 72, active: true };
      function flap(source = 'pointer') {
        if (!started || ready) return;
        crowVelocity = -4.8;
        bootMetrics.input_events += 1;
        bootMetrics.last_input = source;
      }
      function resetBranch() { const gap = 70 + Math.random() * 35; const top = 18 + Math.random() * 48; branches.push({ x: road.width + 30, top, bottom: top + gap }); }
      function draw() {
        const w = road.width, h = road.height;
        ctx.clearRect(0, 0, w, h); ctx.fillStyle = '#09171b'; ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = 'rgba(112, 148, 135, .16)';
        for (let i = 0; i < 10; i++) { const x = (i * 82 - branchOffset * (i % 2 ? .35 : .18)) % (w + 60) - 30; ctx.beginPath(); ctx.moveTo(x, h); ctx.lineTo(x + 34, 36 + (i % 3) * 12); ctx.lineTo(x + 62, h); ctx.fill(); }
        ctx.strokeStyle = 'rgba(211, 177, 110, .24)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(0, h - 22); ctx.bezierCurveTo(w * .25, h * .62, w * .60, h * .92, w, h * .55); ctx.stroke();
        ctx.fillStyle = '#d8b56d'; ctx.shadowColor = '#d8b56d'; ctx.shadowBlur = 14; if (ember.active) { ctx.beginPath(); ctx.arc(ember.x, ember.y, 5, 0, Math.PI * 2); ctx.fill(); } ctx.shadowBlur = 0;
        ctx.fillStyle = '#070b0e'; ctx.strokeStyle = '#b7c2b9'; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(110, crowY, 15, 9, -.12, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.moveTo(122, crowY - 1); ctx.lineTo(136, crowY - 6); ctx.lineTo(124, crowY + 4); ctx.fill(); ctx.fillStyle = '#f1d796'; ctx.beginPath(); ctx.arc(120, crowY - 4, 1.5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(22, 35, 36, .92)'; for (const branch of branches) { ctx.fillRect(branch.x, 0, 18, branch.top); ctx.fillRect(branch.x, branch.bottom, 18, h - branch.bottom); }
        ctx.fillStyle = '#c8a767'; ctx.font = '12px system-ui'; ctx.fillText('embers ' + score, 14, 22);
      }
      function tick(time) {
        const dt = Math.min(2.0, (time - last) / 16.67 || 1); last = time;
        if (started && !ready && !reduce) {
          crowVelocity += .22 * dt; crowY += crowVelocity * dt; branchOffset += 1.1 * dt; nextBranch -= 1.55 * dt; ember.x -= 1.7 * dt; if (ember.x < -12) { ember.x = road.width + 12; ember.y = 30 + Math.random() * 110; ember.active = true; }
          for (const branch of branches) branch.x -= 1.55 * dt; while (nextBranch <= 0) { resetBranch(); nextBranch = 150 + Math.random() * 100; } while (branches.length && branches[0].x < -30) branches.shift();
          if (Math.abs(crowY - ember.y) < 18 && Math.abs(110 - ember.x) < 24 && ember.active) { score++; ember.active = false; bootMetrics.crow_score = score; setStatus('The road remembers. Ember ' + score + ' gathered.'); }
          if (crowY < 8 || crowY > road.height - 8 || branches.some((b) => 110 > b.x - 15 && 110 < b.x + 28 && (crowY < b.top || crowY > b.bottom))) { crowY = 90; crowVelocity = 0; branches.length = 0; nextBranch = 260; setStatus('The crow circles back. Keep the oath alive.'); }
        }
        draw(); requestAnimationFrame(tick);
      }
      window.addEventListener('keydown', (event) => { if ([' ', 'ArrowUp', 'w', 'W'].includes(event.key)) { event.preventDefault(); flap('keyboard'); } });
      road.addEventListener('pointerdown', () => flap('pointer'));
      start.addEventListener('click', () => {
        if (engineBooted && window.__ashenOathOpeningState?.state === 'failed') {
          ready = true;
          boot.classList.add('hidden');
          document.getElementById('canvas').focus();
        } else if (!started) begin();
        else flap('button');
      });
      function pollGamepad() {
        let pressed = false;
        if (started && !ready && navigator.getGamepads) {
          const pad = Array.from(navigator.getGamepads()).find(Boolean);
          pressed = Boolean(pad?.buttons?.[0]?.pressed);
          if (pressed && !gamepadPressed) flap('gamepad');
        }
        gamepadPressed = pressed;
        requestAnimationFrame(pollGamepad);
      }
      function begin() {
        if (started) return;
        started = true;
        ready = false;
        start.textContent = 'Flap the Crow';
        start.setAttribute('aria-label', 'Flap the crow while Ashen Oath loads');
        setStatus('Opening the road while you fly.');
        bootMetrics.engine_start_ms = performance.now();
        performance.mark('ashen-oath-engine-start');
        setBootState('engine_starting');
        try { engine = new Engine({}); } catch (error) { setRetryState('The road could not be opened. Choose Retry to try again.', { error: String(error) }); console.error(error); return; }
        const missing = Engine.getMissingFeatures({ threads: false });
        if (missing.length) { setRetryState('This browser is missing WebGL 2.0: ' + missing.join(', '), { missing_features: missing }); console.error(status.textContent); return; }
        setBootState('loading');
        engine.startGame({ onProgress: (current, total) => { const ratio = current > 0 && total > 0 ? current / total : 0; const visibleRatio = Math.min(0.92, ratio); bootMetrics.progress_samples += 1; progress.style.width = `${Math.round(visibleRatio * 100)}%`; setStatus(ratio >= 1 ? 'Runtime files are ready. Preparing Greyfen...' : (ratio > 0 ? `Opening the road... ${Math.round(visibleRatio * 100)}%` : 'Opening the road...')); } }).then(() => {
          engineBooted = true;
          bootMetrics.engine_ready_ms = performance.now();
          performance.mark('ashen-oath-engine-ready');
          setBootState('opening_preparing', { engine_ready_elapsed_ms: Math.round(bootMetrics.engine_ready_ms - bootMetrics.engine_start_ms) });
          setStatus('Runtime ready. Preparing Greyfen\'s first view...');
          waitForOpeningReady();
        }, (error) => { setRetryState('The road could not be opened. Choose Retry to try again.', { error: String(error) }); console.error(error); });
      }
      function waitForOpeningReady() {
        const opening = window.__ashenOathOpeningState;
        if (opening?.state === 'ready') {
          ready = true;
          progress.style.width = '100%';
          setBootState('ready', { opening_ready_ms: performance.now() });
          setStatus(opening.message || 'Greyfen is ready. Enter the road.');
          boot.classList.add('hidden');
          document.getElementById('canvas').focus();
          return;
        }
        if (opening?.state === 'failed') {
          setBootState('opening_failed', { opening_error: opening.message || 'Opening preparation failed' });
          setStatus(opening.message || 'Greyfen could not be prepared. Open the menu to retry.');
          start.textContent = 'Open Retry Menu';
          start.setAttribute('aria-label', 'Open the Ashen Oath retry menu');
          return;
        }
        window.setTimeout(waitForOpeningReady, 50);
      }
      function setRetryState(message, extra = {}) {
        started = false;
        ready = false;
        engineBooted = false;
        engine = null;
        setBootState('failed', extra);
        setStatus(message);
        start.textContent = 'Retry';
        start.setAttribute('aria-label', 'Retry opening Ashen Oath');
      }
      draw(); requestAnimationFrame(tick); requestAnimationFrame(pollGamepad);
      prefetchOpeningPack();
      window.setTimeout(begin, 0);
    })();
