import './styles.css';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWindow } from '@tauri-apps/api/window';
import type { AppSnapshot } from './types';

const params = new URLSearchParams(window.location.search);
const surface = params.get('surface') || 'sidebar';
const root = document.getElementById('app')!;
const currentWindow = getCurrentWindow();

let latestState: AppSnapshot | null = null;
let paletteQuery = '';
let paletteIndex = 0;

if (['settings', 'about', 'tapsync', 'sidebar', 'command-palette'].includes(surface)) {
  document.body.classList.add('solid-window');
}

async function sendCommand(command: string, payload: Record<string, unknown> = {}) {
  try {
    await invoke('ytmg_command', { command, payload });
  } catch (err) {
    console.error('Command failed:', command, err);
  }
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function splitSweep(text: string, progress: number): { lit: string; dim: string } {
  const clamped = Math.max(0.06, Math.min(1, progress));
  const idx = Math.max(1, Math.round(text.length * clamped));
  return { lit: text.slice(0, idx), dim: text.slice(idx) };
}

function getActiveDisplay(state: AppSnapshot) {
  const parsed = state.parsed;
  const idx = state.frame.activeLineIndex;
  if (!parsed || idx < 0 || idx >= parsed.lines.length) {
    return {
      orig: state.track ? `${state.track.title} · ${state.track.artist}` : 'YT Music Glass',
      hero: state.frame.instrumentalActive ? '••• Instrumental •••' : (state.statusMessage || 'Play a track on YouTube Music'),
      trans: '',
      progress: 1,
    };
  }
  const line = parsed.lines[idx];
  const romaji = state.romanizeEnabled ? state.romanizedLines[idx] : null;
  const trans = state.translateEnabled ? state.translatedLines[idx] : null;
  return {
    orig: romaji ? line.text : '',
    hero: romaji || line.text,
    trans: trans || '',
    progress: state.frame.lineProgress,
  };
}

function renderHud(state: AppSnapshot) {
  const d = getActiveDisplay(state);
  const sweep = splitSweep(d.hero, d.progress);
  const alpha = Math.max(0, Math.min(0.85, state.hudOpacity));
  const bg = alpha === 0 ? 'transparent' : `rgba(12, 12, 20, ${alpha.toFixed(2)})`;
  const border = alpha === 0 ? 'transparent' : `rgba(255, 255, 255, ${(alpha * 0.25).toFixed(2)})`;

  root.innerHTML = `
    <div class="hud-shell" data-tauri-drag-region style="background:${bg};border:1px solid ${border};">
      <div class="hud-header" data-tauri-drag-region>
        <span>${escapeHtml(state.track ? `${state.track.title} — ${state.track.artist}` : 'Floating Lyrics HUD')}</span>
        <div class="hud-controls">
          <button class="chip-btn ${state.hudMode === 'compact' ? 'active' : ''}" data-cmd="toggle_hud_mode">${state.hudMode === 'compact' ? 'Full' : 'Compact'}</button>
          <button class="chip-btn ${state.clickThrough ? 'active' : ''}" data-cmd="toggle_click_through">${state.clickThrough ? 'Locked' : 'Lock'}</button>
          <button class="chip-btn" data-cmd="hide_window">Hide</button>
        </div>
      </div>
      <div class="hud-lyrics" data-tauri-drag-region>
        ${d.orig && state.hudMode === 'full' ? `<div class="hud-orig">${escapeHtml(d.orig)}</div>` : ''}
        <div class="hud-hero"><span class="lit">${escapeHtml(sweep.lit)}</span><span class="dim">${escapeHtml(sweep.dim)}</span></div>
        ${d.trans && state.hudMode === 'full' ? `<div class="hud-trans">${escapeHtml(d.trans)}</div>` : ''}
      </div>
    </div>
  `;
}

function renderMiniPlayer(state: AppSnapshot) {
  const d = getActiveDisplay(state);
  const pct = state.playback.duration > 0
    ? Math.min(100, Math.max(0, (state.playback.currentTime / state.playback.duration) * 100))
    : 0;
  const art = state.track?.artworkUrl ? `<img class="mini-art" src="${escapeHtml(state.track.artworkUrl)}" alt="" />` : `<div class="mini-art"></div>`;

  root.innerHTML = `
    <div class="glass-card mini-shell" data-tauri-drag-region>
      <div class="mini-top" data-tauri-drag-region>
        ${art}
        <div class="mini-meta" data-tauri-drag-region>
          <div class="mini-title">${escapeHtml(state.track?.title || 'Not Playing')}</div>
          <div class="mini-artist">${escapeHtml(state.track?.artist || 'YouTube Music')}</div>
        </div>
        <div class="mini-actions">
          <button class="icon-btn" data-cmd="prev" title="Previous">⏮</button>
          <button class="icon-btn primary" data-cmd="toggle_play" title="Play/Pause">${state.playback.paused ? '▶' : '⏸'}</button>
          <button class="icon-btn" data-cmd="next" title="Next">⏭</button>
        </div>
      </div>
      <div class="mini-lyric">${escapeHtml(d.hero)}</div>
      <div class="seek-track"><div class="seek-fill" style="width:${pct.toFixed(1)}%"></div></div>
    </div>
  `;
}

function renderLyricPill(state: AppSnapshot) {
  const d = getActiveDisplay(state);
  root.innerHTML = `
    <div class="pill-shell" data-tauri-drag-region>
      <span class="pill-dot"></span>
      <span class="pill-text" data-tauri-drag-region>${escapeHtml(d.hero)}</span>
      <button class="chip-btn" data-cmd="toggle_play">${state.playback.paused ? '▶' : '⏸'}</button>
      <button class="chip-btn" data-cmd="toggle_hud">HUD</button>
    </div>
  `;
}

function renderSidebar(state: AppSnapshot) {
  const lines = state.parsed?.lines || [];
  const activeIdx = state.frame.activeLineIndex;
  const rowsHtml = lines.length
    ? lines
        .map((line, i) => {
          const romaji = state.romanizeEnabled ? state.romanizedLines[i] : null;
          const trans = state.translateEnabled ? state.translatedLines[i] : null;
          const hero = romaji || line.text || '•••';
          return `
            <button class="lyric-row ${i === activeIdx ? 'active' : ''}" data-seek="${line.startTime}">
              ${romaji ? `<span class="l-orig">${escapeHtml(line.text)}</span>` : ''}
              <span class="l-hero">${escapeHtml(hero)}</span>
              ${trans ? `<span class="l-trans">${escapeHtml(trans)}</span>` : ''}
            </button>
          `;
        })
        .join('')
    : `<div class="panel-sub">${escapeHtml(state.statusMessage || 'Waiting for track...')}</div>`;

  root.innerHTML = `
    <div class="glass-card sidebar-shell">
      <div class="sidebar-toolbar">
        <div>
          <div class="mini-title">${escapeHtml(state.track?.title || 'Lyrics Sidebar')}</div>
          <div class="panel-sub">${escapeHtml(state.track?.artist || '')} ${state.isOfflinePinned ? '· Offline Vault ✓' : ''}</div>
        </div>
        <div class="hud-controls">
          <button class="chip-btn ${state.romanizeEnabled ? 'active' : ''}" data-cmd="toggle_romanize">Romaji</button>
          <button class="chip-btn ${state.translateEnabled ? 'active' : ''}" data-cmd="toggle_translate">Translate</button>
          <button class="chip-btn" data-cmd="offset_minus">-0.2s</button>
          <span class="panel-sub">${(state.offsetMs / 1000).toFixed(1)}s</span>
          <button class="chip-btn" data-cmd="offset_plus">+0.2s</button>
          <button class="chip-btn" data-cmd="pin_offline">Pin</button>
          <button class="chip-btn" data-cmd="open_tapsync">Tap-Sync</button>
        </div>
      </div>
      <div class="lyrics-scroll" id="sidebar-scroll">${rowsHtml}</div>
    </div>
  `;

  const activeEl = root.querySelector('.lyric-row.active');
  if (activeEl) {
    activeEl.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }
}

function getPaletteCommands(state: AppSnapshot) {
  return [
    { id: 'toggle_play', title: state.playback.paused ? 'Play Track' : 'Pause Track', sub: 'Playback control' },
    { id: 'next', title: 'Next Track', sub: 'Skip forward' },
    { id: 'prev', title: 'Previous Track', sub: 'Skip backward' },
    { id: 'toggle_hud', title: 'Toggle Floating HUD', sub: 'Transparent karaoke overlay' },
    { id: 'toggle_mini', title: 'Toggle Mini Player', sub: 'Compact floating widget' },
    { id: 'toggle_pill', title: 'Toggle Screen-Edge Lyric Pill', sub: 'Taskbar/edge 1-line lyrics' },
    { id: 'toggle_romanize', title: 'Toggle Auto-Romaji', sub: 'Offline Hangul/Kana/Pinyin' },
    { id: 'toggle_translate', title: 'Toggle Smart Translate', sub: `${state.translateSource} -> ${state.translateTarget}` },
    { id: 'switch_site', title: `Switch to ${state.siteMode === 'ytm' ? 'YouTube' : 'YouTube Music'}`, sub: 'Swap web platform' },
    { id: 'pin_offline', title: 'Save Track to Offline Vault', sub: `${state.offlineVaultCount} pinned tracks` },
    { id: 'open_tapsync', title: 'Open Live Tap-to-Sync', sub: 'Create synced LRC timestamps' },
    { id: 'open_settings', title: 'Open Settings', sub: 'Appearance, Kanji dictionary, translation' },
    { id: 'open_about', title: 'About & Check Updates', sub: `v${state.version}` },
  ];
}

function renderCommandPalette(state: AppSnapshot) {
  const all = getPaletteCommands(state);
  const q = paletteQuery.trim().toLowerCase();
  const filtered = q ? all.filter((c) => `${c.title} ${c.sub}`.toLowerCase().includes(q)) : all;
  if (paletteIndex >= filtered.length) paletteIndex = Math.max(0, filtered.length - 1);

  root.innerHTML = `
    <div class="glass-card panel-body">
      <input class="palette-input" id="palette-search" placeholder="Type a command..." value="${escapeHtml(paletteQuery)}" autofocus />
      <div class="palette-list">
        ${filtered
          .map(
            (c, i) => `
            <button class="palette-item ${i === paletteIndex ? 'selected' : ''}" data-cmd="${c.id}">
              <div>
                <div class="mini-title">${escapeHtml(c.title)}</div>
                <div class="panel-sub">${escapeHtml(c.sub)}</div>
              </div>
              <span class="panel-sub">↵</span>
            </button>`
          )
          .join('')}
      </div>
    </div>
  `;

  const input = document.getElementById('palette-search') as HTMLInputElement | null;
  if (input) {
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
    input.addEventListener('input', () => {
      paletteQuery = input.value;
      paletteIndex = 0;
      renderCommandPalette(state);
    });
  }
}

function renderSettings(state: AppSnapshot) {
  root.innerHTML = `
    <div class="glass-card panel-body">
      <div class="panel-title">YT Music Glass Settings</div>
      <div class="setting-row">
        <div>
          <div class="mini-title">Obsidian Glass Theme</div>
          <div class="panel-sub">Toggle dark liquid glass styling on YouTube Music</div>
        </div>
        <button class="chip-btn ${state.themeEnabled ? 'active' : ''}" data-cmd="toggle_theme">${state.themeEnabled ? 'Enabled' : 'Original'}</button>
      </div>
      <div class="setting-row">
        <div>
          <div class="mini-title">Floating HUD Opacity (${Math.round(state.hudOpacity * 100)}%)</div>
          <div class="panel-sub">0% pure click-through text to 85% frosted card</div>
        </div>
        <input id="hud-opacity-input" type="range" min="0" max="85" value="${Math.round(state.hudOpacity * 100)}" />
      </div>
      <div class="setting-row">
        <div>
          <div class="mini-title">Screen-Edge Mini Lyric Pill</div>
          <div class="panel-sub">Windows/Linux replacement for macOS Menu Bar lyrics (${state.pillEdge})</div>
        </div>
        <div class="hud-controls">
          <button class="chip-btn ${state.pillEnabled ? 'active' : ''}" data-cmd="toggle_pill">${state.pillEnabled ? 'Shown' : 'Hidden'}</button>
          <button class="chip-btn" data-cmd="toggle_pill_edge">Edge: ${state.pillEdge}</button>
        </div>
      </div>
      <div class="setting-row">
        <div>
          <div class="mini-title">Offline Japanese Kanji Dictionary</div>
          <div class="panel-sub">${
            state.kanjiDictReady
              ? 'Installed locally — Kanji → Romaji runs 100% offline'
              : state.kanjiDictDownloading
              ? 'Downloading offline Kanji reading table...'
              : 'On-demand download (~2.1 MB) for 100% offline Kanji Romaji'
          }</div>
        </div>
        <button class="chip-btn ${state.kanjiDictReady ? 'active' : ''}" data-cmd="download_kanji_dict">
          ${state.kanjiDictReady ? 'Installed ✓' : state.kanjiDictDownloading ? 'Downloading...' : 'Download'}
        </button>
      </div>
      <div class="setting-row">
        <div>
          <div class="mini-title">Smart Translate Target</div>
          <div class="panel-sub">Current: Auto → ${escapeHtml(state.translateTarget.toUpperCase())}</div>
        </div>
        <select id="translate-target-select" class="chip-btn">
          ${['id', 'en', 'ja', 'ko', 'zh-CN', 'ms', 'es']
            .map((code) => `<option value="${code}" ${state.translateTarget === code ? 'selected' : ''}>${code.toUpperCase()}</option>`)
            .join('')}
        </select>
      </div>
    </div>
  `;

  document.getElementById('hud-opacity-input')?.addEventListener('input', (ev) => {
    const val = Number((ev.target as HTMLInputElement).value) / 100;
    sendCommand('set_hud_opacity', { opacity: val });
  });
  document.getElementById('translate-target-select')?.addEventListener('change', (ev) => {
    const target = (ev.target as HTMLSelectElement).value;
    sendCommand('set_translate_target', { target });
  });
}

function renderAbout(state: AppSnapshot) {
  root.innerHTML = `
    <div class="glass-card panel-body">
      <div class="panel-title">YT Music Glass Desktop</div>
      <div class="panel-sub">Version ${escapeHtml(state.version)} · Tauri v2 (Windows & Linux)</div>
      <div class="setting-row">
        <div>
          <div class="mini-title">GitHub Releases Auto-Updater</div>
          <div class="panel-sub">${escapeHtml(state.update.message)}</div>
        </div>
        <button class="primary-btn" data-cmd="check_updates">Check for Updates</button>
      </div>
      ${
        state.update.status === 'available' && state.update.downloadUrl
          ? `<button class="primary-btn" data-cmd="download_update">Download ${escapeHtml(state.update.assetName || 'Latest Release')}</button>`
          : ''
      }
      <div class="panel-sub">Offline Vault: ${state.offlineVaultCount} pinned tracks · Built by Ravi Bangkit Nur Zikrillah</div>
    </div>
  `;
}

function renderTapSync(state: AppSnapshot) {
  const tap = state.tapSync;
  root.innerHTML = `
    <div class="glass-card panel-body">
      <div class="panel-title">Live Tap-to-Sync</div>
      ${
        tap
          ? `
            <div class="panel-sub">Tapped ${tap.tappedCount} / ${tap.totalCount} lines · Press Tap or Space on vocal cues</div>
            <div class="hud-controls">
              <button class="primary-btn" data-cmd="tap_next">Tap Line (Space)</button>
              <button class="chip-btn" data-cmd="tap_undo">Undo</button>
              <button class="chip-btn" data-cmd="tap_save" ${tap.isComplete ? '' : 'disabled'}>Save to Vault</button>
            </div>
            <div class="palette-list">
              ${tap.lines
                .map(
                  (l, i) => `
                  <div class="palette-item ${i === tap.currentIndex ? 'selected' : ''}">
                    <span>${escapeHtml(l.text)}</span>
                    <span class="panel-sub">${l.timestamp !== null ? l.timestamp.toFixed(2) + 's' : '--'}</span>
                  </div>`
                )
                .join('')}
            </div>`
          : `<div class="panel-sub">No active track lyrics to tap-sync yet.</div>`
      }
    </div>
  `;
}

function render(state: AppSnapshot) {
  latestState = state;
  document.documentElement.style.setProperty('--accent-rgb', state.accentRgb || '244, 63, 108');
  switch (surface) {
    case 'hud':
      renderHud(state);
      break;
    case 'mini':
      renderMiniPlayer(state);
      break;
    case 'pill':
      renderLyricPill(state);
      break;
    case 'command-palette':
      renderCommandPalette(state);
      break;
    case 'settings':
      renderSettings(state);
      break;
    case 'about':
      renderAbout(state);
      break;
    case 'tapsync':
      renderTapSync(state);
      break;
    default:
      renderSidebar(state);
  }
}

root.addEventListener('click', (ev) => {
  const target = (ev.target as HTMLElement).closest<HTMLElement>('[data-cmd], [data-seek]');
  if (!target) return;
  const seekVal = target.getAttribute('data-seek');
  if (seekVal !== null) {
    sendCommand('seek', { time: Number(seekVal) });
    return;
  }
  const cmd = target.getAttribute('data-cmd');
  if (!cmd) return;
  if (cmd === 'hide_window') {
    currentWindow.hide();
    return;
  }
  sendCommand(cmd);
});

window.addEventListener('keydown', (ev) => {
  if (surface === 'command-palette' && latestState) {
    const all = getPaletteCommands(latestState);
    const q = paletteQuery.trim().toLowerCase();
    const filtered = q ? all.filter((c) => `${c.title} ${c.sub}`.toLowerCase().includes(q)) : all;
    if (ev.key === 'ArrowDown') {
      ev.preventDefault();
      paletteIndex = Math.min(filtered.length - 1, paletteIndex + 1);
      renderCommandPalette(latestState);
    } else if (ev.key === 'ArrowUp') {
      ev.preventDefault();
      paletteIndex = Math.max(0, paletteIndex - 1);
      renderCommandPalette(latestState);
    } else if (ev.key === 'Enter' && filtered[paletteIndex]) {
      ev.preventDefault();
      sendCommand(filtered[paletteIndex].id);
      currentWindow.hide();
    } else if (ev.key === 'Escape') {
      currentWindow.hide();
    }
  } else if (surface === 'tapsync' && ev.code === 'Space') {
    ev.preventDefault();
    sendCommand('tap_next');
  }
});

async function boot() {
  await listen<AppSnapshot>('ytmg://state', (event) => {
    render(event.payload);
  });
  const initial = await invoke<AppSnapshot>('ytmg_get_state');
  render(initial);
}

boot().catch(console.error);
