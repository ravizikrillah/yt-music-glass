(function () {
  const OWNER = 'ravizikrillah';
  const REPO = 'yt-music-glass';
  const RELEASES_API = `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`;
  const FALLBACK_URL = `https://github.com/${OWNER}/${REPO}/releases`;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // 1. Live fetch latest multi-platform release assets + auto-detect visitor OS/arch
  const releaseBar = document.getElementById('release-status-bar');
  const metaEl = document.getElementById('release-meta');
  const retryBtn = document.getElementById('retry-release-btn');
  const btnLabel = document.getElementById('download-btn-label');
  const navCta = document.querySelector('.nav-cta');
  const detectedHintEl = document.getElementById('detected-platform-hint');

  async function detectVisitorPlatform() {
    const ua = navigator.userAgent || '';
    const plat = navigator.platform || '';

    if (/Win/i.test(plat) || /Windows/i.test(ua)) {
      return { key: 'windows-exe', label: 'Windows (.exe)', shortLabel: 'Download Windows .exe' };
    }
    if (/Linux/i.test(plat) || (/Linux/i.test(ua) && !/Android/i.test(ua))) {
      return { key: 'linux-appimage', label: 'Linux (.AppImage)', shortLabel: 'Download AppImage' };
    }

    // macOS: distinguish Apple Silicon vs Intel where browser exposes it
    let isArm = false;
    try {
      if (navigator.userAgentData && navigator.userAgentData.getHighEntropyValues) {
        const vals = await navigator.userAgentData.getHighEntropyValues(['architecture']);
        if (vals.architecture === 'arm') isArm = true;
      }
    } catch {}
    if (!isArm) {
      try {
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
        if (gl) {
          const dbg = gl.getExtension('WEBGL_debug_renderer_info');
          const renderer = dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : '';
          if (/Apple\s*M\d|Apple GPU/i.test(String(renderer))) isArm = true;
        }
      } catch {}
    }
    if (/arm64|aarch64/i.test(ua)) isArm = true;

    if (isArm) {
      return { key: 'mac-arm64', label: 'macOS Apple Silicon (.dmg)', shortLabel: 'Download DMG' };
    }
    if (/Mac/i.test(plat) || /Macintosh/i.test(ua)) {
      return { key: 'mac-x86_64', label: 'macOS Intel (.dmg)', shortLabel: 'Download Intel DMG' };
    }
    return { key: 'mac-arm64', label: 'macOS Apple Silicon (.dmg)', shortLabel: 'Download' };
  }

  function mapReleaseAssets(assets) {
    const find = (re) => assets.find((a) => re.test(a.name || ''));
    return {
      'mac-arm64': find(/arm64.*\.dmg$/i),
      'mac-x86_64': find(/(x86_64|intel).*\.dmg$/i),
      'windows-exe': find(/windows.*\.exe$|setup\.exe$/i) || find(/\.exe$/i),
      'windows-zip': find(/windows.*\.zip$/i),
      'linux-appimage': find(/\.AppImage$/i),
      'linux-deb': find(/\.deb$/i),
    };
  }

  async function syncLatestRelease() {
    if (releaseBar) releaseBar.setAttribute('data-release-state', 'loading');
    if (retryBtn) retryBtn.hidden = true;
    const detected = await detectVisitorPlatform();

    try {
      const res = await fetch(RELEASES_API, {
        headers: { Accept: 'application/vnd.github+json' },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const tag = data.tag_name || 'v1.2.0';
      const assets = Array.isArray(data.assets) ? data.assets : [];
      const mapped = mapReleaseAssets(assets);
      const primaryAsset = mapped[detected.key] || mapped['mac-arm64'] || assets[0];

      const primaryUrl = (primaryAsset && primaryAsset.browser_download_url) || data.html_url || FALLBACK_URL;
      document.querySelectorAll('[data-download-link]').forEach((el) => {
        el.setAttribute('href', primaryUrl);
      });

      document.querySelectorAll('[data-asset-key]').forEach((el) => {
        const key = el.getAttribute('data-asset-key');
        const asset = key ? mapped[key] : null;
        if (asset && asset.browser_download_url) {
          el.setAttribute('href', asset.browser_download_url);
          const sizeBadge = el.querySelector('.plat-size');
          if (sizeBadge && asset.size) {
            sizeBadge.textContent = `${(asset.size / 1048576).toFixed(1)} MB`;
          }
        } else {
          el.setAttribute('href', data.html_url || FALLBACK_URL);
        }
      });

      if (metaEl) {
        const sizeMb = primaryAsset && primaryAsset.size ? `${(primaryAsset.size / 1048576).toFixed(1)} MB` : 'macOS · Windows · Linux';
        metaEl.textContent = `${tag} verified on GitHub Releases · ${detected.label} · ${sizeMb}`;
      }
      if (releaseBar) releaseBar.setAttribute('data-release-state', 'ready');
      if (btnLabel) btnLabel.textContent = `Download ${tag} · ${detected.label}`;
      if (navCta) navCta.textContent = detected.shortLabel;
      if (detectedHintEl) {
        detectedHintEl.textContent = `Auto-detected ${detected.label}. On another desktop? Pick any OS below.`;
      }
    } catch {
      if (releaseBar) releaseBar.setAttribute('data-release-state', 'fallback');
      if (metaEl) {
        metaEl.textContent = `Latest Release · macOS 13+ (Silicon & Intel) · Windows · Linux`;
      }
      if (btnLabel) btnLabel.textContent = `Download · ${detected.label}`;
      if (retryBtn) retryBtn.hidden = false;
    }
  }

  if (retryBtn) {
    retryBtn.addEventListener('click', () => {
      syncLatestRelease();
    });
  }

  // 2. Demo Tracks Data (3 real songs with distinct adaptive palettes, equalizer profiles & multilingual lyrics)
  const DEMO_TRACKS = [
    {
      title: 'The Chase',
      artist: 'Hearts2Hearts',
      durationSec: 179,
      startSec: 58,
      accentHex: '#e11d48',
      glowHex: '#fb7185',
      rgb: '225, 29, 72',
      energy: 1.0,
      tempo: 3.1,
      lines: [
        {
          orig: 'Hop, 내 모험의 첫걸음을 디뎌',
          hero: 'Hop, nae moheomui cheotgeoreumeul didyeo',
          id: 'Hop, ambil langkah pertama dalam petualanganku',
          en: 'Hop, taking the first step of my adventure',
        },
        {
          orig: '온통 수수께끼 난 더 알고 싶어',
          hero: 'ontong susukkekki nan deo algo sipeo',
          id: 'Itu semua misteri, aku ingin tahu lebih banyak',
          en: 'It is all a mystery, I want to know more',
        },
        {
          orig: 'Sparkle, sparkle, 뭔가를 본 것 같아',
          hero: 'Sparkle, sparkle, mwongareul bon geot gata',
          id: 'Berkilau, berkilau, sepertinya aku melihat sesuatu',
          en: 'Sparkle, sparkle, I think I just saw something',
        },
      ],
    },
    {
      title: '夜に駆ける (Into The Night)',
      artist: 'YOASOBI',
      durationSec: 261,
      startSec: 31,
      accentHex: '#f59e0b',
      glowHex: '#fcd34d',
      rgb: '245, 158, 11',
      energy: 1.18,
      tempo: 3.8,
      lines: [
        {
          orig: '沈むように溶けてゆくように',
          hero: 'shizumu you ni toke te yuku you ni',
          id: 'Bagai tenggelam dan larut perlahan',
          en: 'Like sinking, like melting away into the night',
        },
        {
          orig: '二人だけの空が広がる夜に',
          hero: 'futari dake no sora ga hirogaru yoru ni',
          id: 'Di malam saat langit hanya milik kita berdua',
          en: 'In the night where the sky expands just for the two of us',
        },
        {
          orig: '日が沈み出した空と君の姿',
          hero: 'hi ga shizumi dashi ta sora to kimi no sugata',
          id: 'Langit senja yang mulai gelap dan sosok dirimu',
          en: 'The setting sun in the sky and your silhouette',
        },
      ],
    },
    {
      title: 'See You Again (feat. Charlie Puth)',
      artist: 'Wiz Khalifa',
      durationSec: 230,
      startSec: 18,
      accentHex: '#eab308',
      glowHex: '#fde047',
      rgb: '234, 179, 8',
      energy: 0.85,
      tempo: 2.35,
      lines: [
        {
          orig: 'Nine Track Mind · Synced Word-Flow LRC',
          hero: "It's been a long day without you, my friend",
          id: 'Hari terasa begitu panjang tanpamu, kawanku',
          en: 'Auto-skipped (song already matches English target)',
        },
        {
          orig: 'Nine Track Mind · Synced Word-Flow LRC',
          hero: "And I'll tell you all about it when I see you again",
          id: 'Dan akan kuceritakan semuanya saat kita berjumpa lagi',
          en: 'Auto-skipped (song already matches English target)',
        },
        {
          orig: 'Nine Track Mind · Synced Word-Flow LRC',
          hero: "We've come a long way from where we began",
          id: 'Kita telah melangkah jauh dari tempat kita bermula',
          en: 'Auto-skipped (song already matches English target)',
        },
      ],
    },
  ];

  let currentTrackIdx = 0;
  let activeLineIdx = 1;
  let lineProgress = 0.56;
  let isPlaying = !prefersReducedMotion;
  let translateTarget = 'id';
  let offsetSec = 0.0;
  let transientBoost = 0.0;
  let pointerRibbonNorm = -1;
  let siteMode = 'music';

  // Build 32-band Hero Spectrum & 48-band Acoustic Ribbon bars
  const heroSpectrumEl = document.getElementById('hero-spectrum-bars');
  const ribbonSpectrumEl = document.getElementById('ribbon-spectrum-bars');
  const ribbonFreqReadout = document.getElementById('ribbon-freq-readout');
  const heroBars = [];
  const ribbonBars = [];

  if (heroSpectrumEl) {
    heroSpectrumEl.innerHTML = '';
    for (let i = 0; i < 32; i++) {
      const b = document.createElement('span');
      b.className = 'spec-bar';
      heroSpectrumEl.appendChild(b);
      heroBars.push(b);
    }
  }

  if (ribbonSpectrumEl) {
    ribbonSpectrumEl.innerHTML = '';
    for (let i = 0; i < 48; i++) {
      const b = document.createElement('span');
      b.className = 'rib-bar';
      ribbonSpectrumEl.appendChild(b);
      ribbonBars.push(b);
    }

    ribbonSpectrumEl.addEventListener('pointermove', (e) => {
      const rect = ribbonSpectrumEl.getBoundingClientRect();
      pointerRibbonNorm = Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width)));
      const freqHz = Math.round(60 + Math.pow(pointerRibbonNorm, 1.7) * 14800);
      const label = freqHz >= 1000 ? `${(freqHz / 1000).toFixed(1)} kHz` : `${freqHz} Hz`;
      if (ribbonFreqReadout) {
        ribbonFreqReadout.textContent = `CURSOR RESONANCE · ${label} · +4.6 dB`;
      }
    });

    ribbonSpectrumEl.addEventListener('pointerleave', () => {
      pointerRibbonNorm = -1;
      if (ribbonFreqReadout) {
        ribbonFreqReadout.textContent = isPlaying
          ? 'HARMONIC LOCK · 48 BANDS ACTIVE'
          : 'PAUSED · CLICK PLAY TO RESUME';
      }
    });
  }

  const miniEqBars = Array.from(document.querySelectorAll('#player-mini-eq i, .sb-eq i'));

  function formatTime(sec) {
    const s = Math.max(0, Math.floor(sec));
    const m = Math.floor(s / 60);
    const rem = s % 60;
    return `${m}:${rem < 10 ? '0' : ''}${rem}`;
  }

  function renderSplitSweep(text, progress) {
    const clamped = Math.max(0.08, Math.min(1, progress));
    const splitAt = Math.max(1, Math.round(text.length * clamped));
    const lit = text.slice(0, splitAt);
    const dim = text.slice(splitAt);
    return { lit, dim };
  }

  function renderLyricsDom() {
    const track = DEMO_TRACKS[currentTrackIdx];
    const listEl = document.getElementById('demo-lyrics-list');
    if (!listEl) return;

    listEl.innerHTML = '';
    track.lines.forEach((line, idx) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `lyric-row${idx === activeLineIdx ? ' active' : idx < activeLineIdx ? ' past' : ''}`;
      btn.setAttribute('data-line-idx', String(idx));

      const origSpan = document.createElement('span');
      origSpan.className = 'l-orig';
      origSpan.textContent = line.orig;

      const heroSpan = document.createElement('span');
      heroSpan.className = 'l-hero';
      if (idx === activeLineIdx) {
        const { lit, dim } = renderSplitSweep(line.hero, lineProgress);
        const litEl = document.createElement('span');
        litEl.className = 'lit';
        litEl.textContent = lit;
        const dimEl = document.createElement('span');
        dimEl.className = 'dim';
        dimEl.textContent = dim;
        heroSpan.appendChild(litEl);
        heroSpan.appendChild(dimEl);
      } else {
        heroSpan.textContent = line.hero;
      }

      const transSpan = document.createElement('span');
      transSpan.className = 'l-trans';
      transSpan.textContent = translateTarget === 'id' ? line.id : line.en;

      btn.appendChild(origSpan);
      btn.appendChild(heroSpan);
      btn.appendChild(transSpan);

      btn.addEventListener('click', () => {
        activeLineIdx = idx;
        lineProgress = 0.25;
        transientBoost = 0.55;
        renderLyricsDom();
        syncFloatingHudText();
      });

      listEl.appendChild(btn);
    });
  }

  function syncFloatingHudText() {
    const track = DEMO_TRACKS[currentTrackIdx];
    const line = track.lines[activeLineIdx] || track.lines[0];
    const hudLyric = document.getElementById('dfh-live-lyric');
    const hudTrans = document.getElementById('dfh-live-trans');
    if (hudLyric) hudLyric.textContent = line.hero;
    if (hudTrans) hudTrans.textContent = translateTarget === 'id' ? line.id : line.en;
  }

  function applyTrack(index) {
    currentTrackIdx = (index + DEMO_TRACKS.length) % DEMO_TRACKS.length;
    const track = DEMO_TRACKS[currentTrackIdx];
    activeLineIdx = 1;
    lineProgress = 0.35;
    transientBoost = 0.7;

    const root = document.documentElement;
    root.style.setProperty('--accent-live', track.accentHex);
    root.style.setProperty('--accent-glow', track.glowHex);
    root.style.setProperty('--accent-rgb', track.rgb);

    document.querySelectorAll('.track-pill').forEach((pill, idx) => {
      pill.classList.toggle('active', idx === currentTrackIdx);
    });

    const setTxt = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = val;
    };

    setTxt('demo-search-box', `Playing: ${track.artist} · ${track.title}`);
    setTxt('demo-track-headline', `${track.title} · ${track.artist}`);
    setTxt('demo-palette-readout', `Adaptive Palette · RGB(${track.rgb}) · 60fps Sync`);
    setTxt('demo-mp-title', track.title);
    setTxt('demo-mp-artist', track.artist);
    setTxt('demo-sb-title', track.title);
    setTxt('demo-sb-artist', `${track.artist} · Offline Vault ✓`);
    setTxt('demo-dur-time', formatTime(track.durationSec));

    renderLyricsDom();
    syncFloatingHudText();
  }

  document.querySelectorAll('.track-pill').forEach((pill) => {
    pill.addEventListener('click', () => {
      const idx = Number(pill.getAttribute('data-track-idx') || '0');
      applyTrack(idx);
    });
  });

  // Play / Pause controls (Hero player + Header global motion toggle for WCAG 2.2.2)
  const playBtn = document.getElementById('demo-play-btn');
  const globalToggle = document.getElementById('global-eq-toggle');
  const globalLabel = document.getElementById('global-eq-label');

  function setPlayingState(nextPlaying) {
    isPlaying = nextPlaying;
    document.body.setAttribute('data-motion-paused', isPlaying ? 'false' : 'true');
    if (playBtn) {
      playBtn.textContent = isPlaying ? '⏸' : '▶';
      playBtn.setAttribute('aria-label', isPlaying ? 'Pause demo playback' : 'Resume demo playback');
    }
    if (globalLabel) {
      globalLabel.textContent = isPlaying ? 'Pause Motion' : 'Resume Motion';
    }
    if (ribbonFreqReadout && pointerRibbonNorm < 0) {
      ribbonFreqReadout.textContent = isPlaying
        ? 'HARMONIC LOCK · 48 BANDS ACTIVE'
        : 'PAUSED · CLICK PLAY TO RESUME';
    }
  }

  if (playBtn) {
    playBtn.addEventListener('click', () => setPlayingState(!isPlaying));
  }
  if (globalToggle) {
    globalToggle.addEventListener('click', () => setPlayingState(!isPlaying));
  }

  const prevBtn = document.getElementById('demo-prev-btn');
  const nextBtn = document.getElementById('demo-next-btn');
  if (prevBtn) prevBtn.addEventListener('click', () => applyTrack(currentTrackIdx - 1));
  if (nextBtn) nextBtn.addEventListener('click', () => applyTrack(currentTrackIdx + 1));

  // Interactive seek bar
  const seekBar = document.getElementById('demo-seek-bar');
  if (seekBar) {
    seekBar.addEventListener('click', (e) => {
      const rect = seekBar.getBoundingClientRect();
      const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width)));
      const track = DEMO_TRACKS[currentTrackIdx];
      activeLineIdx = Math.min(track.lines.length - 1, Math.floor(ratio * track.lines.length));
      lineProgress = (ratio * track.lines.length) % 1;
      transientBoost = 0.65;
      renderLyricsDom();
      syncFloatingHudText();
    });
  }

  // Platform switcher (YouTube Music vs YouTube)
  document.querySelectorAll('[data-site-mode]').forEach((btn) => {
    btn.addEventListener('click', () => {
      siteMode = btn.getAttribute('data-site-mode') || 'music';
      document.querySelectorAll('[data-site-mode]').forEach((b) => {
        b.classList.toggle('active', b === btn);
      });
      const siteLabel = document.getElementById('demo-site-label');
      if (siteLabel) {
        siteLabel.textContent = siteMode === 'music' ? 'Music' : 'YouTube';
      }
      transientBoost = 0.4;
    });
  });

  // Smart Translate language toggle (ID <-> EN)
  const langToggle = document.getElementById('preview-lang-toggle');
  const dockLang = document.getElementById('preview-dock-lang');
  if (langToggle) {
    langToggle.addEventListener('click', () => {
      translateTarget = translateTarget === 'id' ? 'en' : 'id';
      langToggle.textContent = translateTarget === 'id' ? 'Translate · Auto→ID' : 'Translate · Auto→EN';
      if (dockLang) dockLang.textContent = translateTarget.toUpperCase();
      renderLyricsDom();
      syncFloatingHudText();
    });
  }

  // Floating HUD preview toggle inside Hero stage
  const floatToggle = document.getElementById('preview-float-toggle');
  const sidebarFloatBtn = document.getElementById('sidebar-float-btn');
  const dfhCloseBtn = document.getElementById('dfh-close-btn');
  const floatingHudEl = document.getElementById('demo-floating-hud');

  function toggleFloatingHud(forceState) {
    if (!floatingHudEl) return;
    const nextOpen = typeof forceState === 'boolean' ? forceState : floatingHudEl.hidden;
    floatingHudEl.hidden = !nextOpen;
    if (floatToggle) floatToggle.classList.toggle('active', nextOpen);
    transientBoost = 0.35;
  }

  if (floatToggle) floatToggle.addEventListener('click', () => toggleFloatingHud());
  if (sidebarFloatBtn) sidebarFloatBtn.addEventListener('click', () => toggleFloatingHud(true));
  if (dfhCloseBtn) dfhCloseBtn.addEventListener('click', () => toggleFloatingHud(false));

  // Sync offset controls (-0.2s / +0.2s)
  const offsetValEl = document.getElementById('demo-offset-val');
  document.querySelectorAll('[data-offset-step]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const step = parseFloat(btn.getAttribute('data-offset-step') || '0');
      offsetSec = Math.max(-2.0, Math.min(2.0, Math.round((offsetSec + step) * 10) / 10));
      if (offsetValEl) {
        offsetValEl.textContent = `${offsetSec > 0 ? '+' : ''}${offsetSec.toFixed(1)}s`;
      }
      transientBoost = 0.3;
    });
  });

  // 3. 60fps Harmonic Equalizer & Karaoke Word-Sweep Loop
  let lastFrameTs = performance.now();

  function tick(now) {
    const dt = Math.min(0.1, (now - lastFrameTs) / 1000);
    lastFrameTs = now;

    const track = DEMO_TRACKS[currentTrackIdx];
    const t = (now / 1000) * track.tempo;
    transientBoost = Math.max(0, transientBoost - dt * 1.8);

    if (isPlaying) {
      // Advance word-by-word karaoke sweep
      lineProgress += dt * 0.24;
      if (lineProgress >= 1.04) {
        lineProgress = 0.08;
        activeLineIdx = (activeLineIdx + 1) % track.lines.length;
        transientBoost = 0.42;
        renderLyricsDom();
        syncFloatingHudText();
      } else {
        // Update active line split without recreating DOM
        const activeHero = document.querySelector('.lyric-row.active .l-hero');
        const line = track.lines[activeLineIdx];
        if (activeHero && line) {
          const { lit, dim } = renderSplitSweep(line.hero, lineProgress);
          const litEl = activeHero.querySelector('.lit');
          const dimEl = activeHero.querySelector('.dim');
          if (litEl && dimEl) {
            litEl.textContent = lit;
            dimEl.textContent = dim;
          }
        }
      }

      // Update seek bar & elapsed time
      const overallRatio = (activeLineIdx + Math.min(1, lineProgress)) / track.lines.length;
      const curSec = track.startSec + overallRatio * 24;
      const curTimeEl = document.getElementById('demo-cur-time');
      const seekFillEl = document.getElementById('demo-seek-fill');
      if (curTimeEl) curTimeEl.textContent = formatTime(curSec);
      if (seekFillEl) {
        const pct = Math.min(96, Math.max(12, ((curSec / track.durationSec) * 100)));
        seekFillEl.style.width = `${pct.toFixed(1)}%`;
      }
    }

    // Animate 32-band Hero Spectrum Equalizer via GPU scaleY
    const beatPulse = isPlaying ? (0.5 + 0.5 * Math.sin(t * 2.1)) : 0.05;
    for (let i = 0; i < heroBars.length; i++) {
      const norm = i / heroBars.length;
      // Bass-heavy left + vocal mid hump + crisp treble air
      const envelope = Math.sin(norm * Math.PI) * 0.65 + (1 - norm) * 0.35;
      const waveA = Math.sin(t * 2.4 + i * 0.48) * 0.5 + 0.5;
      const waveB = Math.cos(t * 3.7 - i * 0.31) * 0.5 + 0.5;
      let level = isPlaying
        ? (0.14 + (waveA * 0.55 + waveB * 0.45) * envelope * track.energy * (0.72 + beatPulse * 0.28) + transientBoost * 0.45)
        : 0.14 + Math.sin(i * 0.4) * 0.04;
      level = Math.max(0.12, Math.min(1.0, level));
      heroBars[i].style.transform = `scaleY(${level.toFixed(3)})`;
    }

    // Animate 48-band Interactive Acoustic Ribbon
    for (let i = 0; i < ribbonBars.length; i++) {
      const norm = i / ribbonBars.length;
      const wave = Math.sin(t * 1.9 + i * 0.36) * 0.5 + 0.5;
      const harmonic = Math.cos(t * 3.1 - i * 0.22) * 0.5 + 0.5;
      let cursorBoost = 0;
      if (pointerRibbonNorm >= 0) {
        const dist = Math.abs(norm - pointerRibbonNorm);
        cursorBoost = Math.max(0, 1 - dist * 5.2) * 0.62;
      }
      let level = isPlaying
        ? 0.15 + (wave * 0.5 + harmonic * 0.5) * 0.58 * track.energy + cursorBoost + transientBoost * 0.3
        : 0.14 + cursorBoost;
      level = Math.max(0.12, Math.min(1.0, level));
      ribbonBars[i].style.transform = `scaleY(${level.toFixed(3)})`;
    }

    // Animate Player & Sidebar Mini Equalizers
    for (let i = 0; i < miniEqBars.length; i++) {
      const lvl = isPlaying
        ? Math.max(0.2, Math.min(1.0, 0.28 + (Math.sin(t * 3.2 + i * 1.3) * 0.5 + 0.5) * 0.72))
        : 0.22;
      miniEqBars[i].style.transform = `scaleY(${lvl.toFixed(3)})`;
    }

    requestAnimationFrame(tick);
  }

  requestAnimationFrame(tick);

  // 4. Interactive Multi-Script Romanizer Lab (Row 1)
  const SCRIPT_SAMPLES = {
    kr: {
      orig: 'But you DM me, \u201c니가 궁금해서\u201d',
      romaji: 'But you DM me, \u201cniga gunggeumhaeseo\u201d',
      trans: 'Tapi kamu DM aku, \u201ckarena aku penasaran padamu\u201d',
      hideTrans: false,
      note: 'Phonological liaison rule active: Hangul syllables romanize 100% offline in <0.2 ms.',
    },
    jp: {
      orig: '二人だけの空が広がる夜に',
      romaji: 'futari dake no sora ga hirogaru yoru ni',
      trans: 'Di malam saat langit hanya milik kita berdua',
      hideTrans: false,
      note: 'Apple CoreFoundation CFStringTokenizer converts Kanji & Kana to Romaji offline.',
    },
    id: {
      orig: 'Kita telah melangkah jauh dari tempat kita bermula',
      romaji: 'Pure Latin script detected (Auto-Romaji skipped cleanly)',
      trans: 'Hidden automatically because song language already matches target (ID)',
      hideTrans: true,
      note: 'NLLanguageRecognizer detects Indonesian and hides redundant ID→ID translation lines.',
    },
  };

  document.querySelectorAll('[data-script]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.getAttribute('data-script') || 'kr';
      const sample = SCRIPT_SAMPLES[key];
      if (!sample) return;

      document.querySelectorAll('[data-script]').forEach((b) => b.classList.toggle('active', b === btn));
      const origEl = document.getElementById('lab-orig-text');
      const romajiEl = document.getElementById('lab-romaji-text');
      const transEl = document.getElementById('lab-trans-text');
      const transRow = document.getElementById('lab-trans-row');
      const noteEl = document.getElementById('lab-footnote');

      if (origEl) origEl.textContent = sample.orig;
      if (romajiEl) romajiEl.textContent = sample.romaji;
      if (transEl) transEl.textContent = sample.trans;
      if (transRow) transRow.style.opacity = sample.hideTrans ? '0.45' : '1';
      if (noteEl) noteEl.textContent = sample.note;
    });
  });

  // 5. Interactive Floating HUD Opacity Simulator (0% to 85% slider, Row 2)
  const opacityRange = document.getElementById('hud-opacity-range');
  const opacityReadout = document.getElementById('hud-opacity-readout');
  const simHudCard = document.getElementById('sim-hud-card');

  function updateHudSimulator(val) {
    const pct = Number(val);
    const alpha = pct / 100;
    if (opacityReadout) {
      if (pct === 0) {
        opacityReadout.textContent = '0% (Pure Click-Through Text)';
      } else if (pct < 45) {
        opacityReadout.textContent = `${pct}% (Translucent Glass)`;
      } else {
        opacityReadout.textContent = `${pct}% (Frosted Obsidian Glass)`;
      }
    }
    if (simHudCard) {
      simHudCard.style.backgroundColor = `rgba(12, 12, 20, ${(alpha * 0.94).toFixed(3)})`;
      simHudCard.style.borderColor = `rgba(255, 255, 255, ${(alpha * 0.26).toFixed(3)})`;
      simHudCard.style.boxShadow = pct > 4 ? `0 18px 40px rgba(0, 0, 0, ${(alpha * 0.75).toFixed(2)})` : 'none';
    }
  }

  if (opacityRange) {
    opacityRange.addEventListener('input', (e) => {
      updateHudSimulator(e.target.value);
    });
    updateHudSimulator(opacityRange.value);
  }

  // 6. Screenshots Filter Tabs
  const filterTabs = document.querySelectorAll('[data-filter]');
  const shotCards = document.querySelectorAll('.shot-card[data-category]');

  filterTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const cat = tab.getAttribute('data-filter') || 'all';
      filterTabs.forEach((t) => {
        const active = t === tab;
        t.classList.toggle('active', active);
        t.setAttribute('aria-selected', active ? 'true' : 'false');
      });

      shotCards.forEach((card) => {
        const cardCat = card.getAttribute('data-category');
        card.hidden = !(cat === 'all' || cardCat === cat);
      });
    });
  });

  // 7. One-click copy for install Terminal commands
  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const targetId = btn.getAttribute('data-copy');
      const codeEl = targetId ? document.getElementById(targetId) : null;
      if (!codeEl) return;
      try {
        await navigator.clipboard.writeText(codeEl.textContent || '');
        const prev = btn.textContent;
        btn.textContent = 'Copied';
        setTimeout(() => {
          btn.textContent = prev || 'Copy';
        }, 1600);
      } catch {
        // Clipboard permission unavailable
      }
    });
  });

  // 8. Native <dialog> screenshot lightbox with Safari closedby fallback
  const lightbox = document.getElementById('lightbox');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxTitle = document.getElementById('lightbox-title');
  const lightboxDesc = document.getElementById('lightbox-desc');

  if (lightbox && lightboxImg && lightboxTitle && lightboxDesc) {
    document.querySelectorAll('[data-shot-src]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const src = btn.getAttribute('data-shot-src') || '';
        const title = btn.getAttribute('data-shot-title') || 'Screenshot Preview';
        const desc = btn.getAttribute('data-shot-desc') || '';
        const thumb = btn.querySelector('img');
        lightboxImg.src = src;
        lightboxImg.alt = (thumb && thumb.alt) || title;
        lightboxTitle.textContent = title;
        lightboxDesc.textContent = desc;
        lightbox.showModal();
      });
    });

    lightbox.addEventListener('close', () => {
      lightbox.returnValue = '';
    });

    if (!('closedBy' in HTMLDialogElement.prototype)) {
      const outside = (e) => {
        const r = lightbox.getBoundingClientRect();
        return e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom;
      };
      let pressedOutside = false;
      lightbox.addEventListener('pointerdown', (e) => {
        pressedOutside = outside(e);
      });
      lightbox.addEventListener('pointerup', (e) => {
        if (pressedOutside && outside(e)) lightbox.close();
      });
    }
  }

  syncLatestRelease();
})();
