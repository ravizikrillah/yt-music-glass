import Foundation

enum WebBridgeScript {
    static let source = #"""
(function () {
  if (window.__ytmgBridgeInstalled) return;
  window.__ytmgBridgeInstalled = true;

  const isYtm = location.hostname.startsWith('music.');
  let lastTrackIdentity = '';
  let lastNativeLyrics = '';
  let lastSignature = '';

  function getVideo() {
    return document.querySelector('video.html5-main-video') || document.querySelector('video');
  }

  function isAdPlaying() {
    return Boolean(
      document.querySelector(
        '#movie_player.ad-showing, #movie_player.ad-interrupting, .ad-showing, .ytp-ad-player-overlay-layout'
      )
    );
  }

  function extractIdFromArt(url) {
    if (!url) return '';
    const m = url.match(/\/vi(?:_webp)?\/([a-zA-Z0-9_-]{11})(?:\/|\?|$)/);
    return m ? m[1] : '';
  }

  function extractYtmTrack(duration) {
    const mediaMeta = navigator.mediaSession && navigator.mediaSession.metadata;
    const barTitleEl = document.querySelector(
      'ytmusic-player-bar .title.style-scope.ytmusic-player-bar, ytmusic-player-bar yt-formatted-string.title'
    );
    const barBylineEl = document.querySelector(
      'ytmusic-player-bar .byline.style-scope.ytmusic-player-bar, ytmusic-player-bar yt-formatted-string.byline'
    );
    const barImgEl = document.querySelector('ytmusic-player-bar img.image, ytmusic-player-bar #img');

    const domTitle = (barTitleEl && barTitleEl.textContent ? barTitleEl.textContent : '').trim();
    let domArtist = '';
    let domAlbum = undefined;

    if (barBylineEl) {
      const links = Array.from(barBylineEl.querySelectorAll('a'));
      if (links[0] && links[0].textContent) domArtist = links[0].textContent.trim();
      if (links[1] && links[1].textContent) domAlbum = links[1].textContent.trim();
      if (!domArtist && barBylineEl.textContent) domArtist = barBylineEl.textContent.trim();
    }

    const title = domTitle || (mediaMeta && mediaMeta.title ? mediaMeta.title.trim() : '');
    const artist = domTitle
      ? (domArtist || (mediaMeta && mediaMeta.artist ? mediaMeta.artist.trim() : ''))
      : ((mediaMeta && mediaMeta.artist ? mediaMeta.artist.trim() : '') || domArtist);
    const album = domAlbum || (mediaMeta && mediaMeta.album ? mediaMeta.album.trim() : undefined);

    if (!title && !artist) return null;

    let artworkUrl = undefined;
    if (barImgEl && barImgEl.src && /^https?:\/\//i.test(barImgEl.src)) {
      artworkUrl = barImgEl.src;
    }
    if (!artworkUrl && mediaMeta && mediaMeta.artwork && mediaMeta.artwork.length > 0) {
      const candidate = mediaMeta.artwork[mediaMeta.artwork.length - 1].src;
      if (candidate && /^https?:\/\//i.test(candidate)) artworkUrl = candidate;
    }
    if (artworkUrl && artworkUrl.includes('googleusercontent.com')) {
      artworkUrl = artworkUrl.replace(/=w\d+-h\d+[^&]*/i, '=w226-h226-l90-rj');
    }

    let videoId = '';
    const playerLink = document.querySelector(
      '#movie_player a.ytp-title-link[href*="v="], ytmusic-player-bar a.ytp-title-link[href*="v="]'
    );
    if (playerLink && playerLink.href) {
      try { videoId = new URL(playerLink.href, location.origin).searchParams.get('v') || ''; } catch {}
    }
    if (!videoId) videoId = extractIdFromArt(artworkUrl);
    if (!videoId && location.pathname === '/watch') {
      try { videoId = new URLSearchParams(location.search).get('v') || ''; } catch {}
    }

    return { id: videoId, title, artist, album: album || null, duration, artworkUrl: artworkUrl || null };
  }

  function extractYouTubeTrack(duration) {
    const isWatch = location.pathname === '/watch';
    const miniActive = Boolean(document.querySelector('ytd-miniplayer[active]'));
    if (!isWatch && !miniActive) return null;

    let videoId = '';
    try { videoId = new URLSearchParams(location.search).get('v') || ''; } catch {}
    if (!videoId) {
      const flexy = document.querySelector('ytd-watch-flexy[video-id]');
      videoId = (flexy && flexy.getAttribute('video-id')) || '';
    }

    const watchMeta = document.querySelector('ytd-watch-metadata');
    const metaVideoId = watchMeta && watchMeta.getAttribute('video-id');
    if (isWatch && videoId && metaVideoId && metaVideoId !== videoId) {
      return null;
    }

    const card = document.querySelector(
      'ytd-watch-metadata ytd-video-description-music-section-renderer yt-video-attribute-view-model, ytd-watch-metadata ytd-horizontal-card-list-renderer yt-video-attribute-view-model'
    );
    const attrTitle = card && card.querySelector('.yt-video-attribute-view-model__title');
    const attrArtist = card && card.querySelector('.yt-video-attribute-view-model__subtitle');

    const titleEl = document.querySelector(
      'ytd-watch-metadata h1 yt-formatted-string, #title h1 yt-formatted-string, ytd-miniplayer .title'
    );
    const chanEl = document.querySelector(
      'ytd-watch-metadata ytd-channel-name #text a, ytd-watch-metadata ytd-channel-name #text, ytd-miniplayer .owner-name'
    );
    const mediaMeta = navigator.mediaSession && navigator.mediaSession.metadata;

    const title = (
      (attrTitle && attrTitle.textContent) ||
      (titleEl && titleEl.textContent) ||
      (mediaMeta && mediaMeta.title) ||
      ''
    ).trim();
    const artist = (
      (attrArtist && attrArtist.textContent) ||
      (chanEl && chanEl.textContent) ||
      (mediaMeta && mediaMeta.artist) ||
      ''
    ).trim();

    if (!title && !artist) return null;

    const artworkUrl = videoId
      ? 'https://i.ytimg.com/vi/' + encodeURIComponent(videoId) + '/hqdefault.jpg'
      : null;

    return { id: videoId, title, artist, album: null, duration, artworkUrl };
  }

  function readNativeLyrics(track) {
    if (!isYtm || !track) return null;
    const selectors = [
      'ytmusic-description-shelf-renderer yt-formatted-string.description',
      'ytmusic-description-shelf-renderer .non-expandable.description',
      '#tab-renderer ytmusic-description-shelf-renderer .description',
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      const text = el && el.textContent ? el.textContent.trim() : '';
      if (text && text.length > 20 && !/^lyrics not available/i.test(text)) {
        const id = track.title + '::' + track.artist;
        if (id !== lastTrackIdentity && text === lastNativeLyrics) {
          return null;
        }
        lastTrackIdentity = id;
        lastNativeLyrics = text;
        return text;
      }
    }
    return null;
  }

  function postSnapshot(force) {
    if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.ytmgBridge) {
      return;
    }

    const video = getVideo();
    const duration = video && Number.isFinite(video.duration) && video.duration > 0 ? video.duration : 0;
    const currentTime = video && Number.isFinite(video.currentTime) ? video.currentTime : 0;
    const paused = video ? Boolean(video.paused) : true;
    const playbackRate = video && Number.isFinite(video.playbackRate) ? video.playbackRate : 1;
    const ad = isAdPlaying();

    const track = isYtm ? extractYtmTrack(duration) : extractYouTubeTrack(duration);
    const nativeLyrics = readNativeLyrics(track);

    const sig = [
      track ? track.id : '',
      track ? track.title : '',
      track ? track.artist : '',
      Math.round(duration),
      paused ? 1 : 0,
      ad ? 1 : 0,
      Math.floor(currentTime),
    ].join('|');

    if (!force && sig === lastSignature) return;
    lastSignature = sig;

    window.webkit.messageHandlers.ytmgBridge.postMessage({
      platform: isYtm ? 'ytm' : 'youtube',
      track,
      nativeLyrics,
      isOfflineContext: isYtm ? isCurrentPlaybackOffline() : false,
      playback: {
        currentTime,
        duration,
        paused,
        playbackRate,
        isAdPlaying: ad,
        capturedAtMs: Date.now(),
      },
    });
  }

  // =========================================================================
  // OFFLINE & DOWNLOADS AUTO-DISCOVERY FOR YOUTUBE MUSIC
  // Automatically syncs lyrics whenever user visits Downloads, clicks Download
  // on any album/playlist/song, or views downloaded collections.
  // =========================================================================
  const reportedOfflineKeys = new Set();
  let offlineScanTimer = null;

  function parseDurationSec(text) {
    if (!text) return 0;
    const m = String(text).trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
    if (!m) return 0;
    if (m[3] !== undefined) {
      return parseInt(m[1], 10) * 3600 + parseInt(m[2], 10) * 60 + parseInt(m[3], 10);
    }
    return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
  }

  function isDownloadsPage() {
    if (!isYtm) return false;
    const p = (location.pathname || '').toLowerCase();
    if (p.includes('/downloads') || p.includes('/library/downloads')) return true;
    const activeChip = document.querySelector('ytmusic-chip-cloud-chip-renderer[is-selected] a, ytmusic-tabs .iron-selected');
    if (activeChip && /\b(downloads?|hasil download|offline)\b/i.test(activeChip.textContent || '')) return true;
    return false;
  }

  function isCollectionDownloadedHeader() {
    if (!isYtm) return false;
    const header = document.querySelector('ytmusic-responsive-header-renderer, ytmusic-detail-header-renderer');
    if (!header) return false;
    const dlBtn = header.querySelector(
      'ytmusic-download-button-renderer, button[aria-label*="download" i], button[aria-label*="unduh" i]'
    );
    if (!dlBtn) return false;
    const label = (dlBtn.getAttribute('aria-label') || dlBtn.textContent || '').toLowerCase();
    if (label.includes('remove download') || label.includes('hapus download') || label.includes('downloaded') || label.includes('didownload')) {
      return true;
    }
    if (dlBtn.querySelector('[icon*="offline_pin"], [icon*="check"], .downloaded')) {
      return true;
    }
    return false;
  }

  function isCurrentPlaybackOffline() {
    if (isDownloadsPage() || isCollectionDownloadedHeader()) return true;
    const selectedQueue = document.querySelector('ytmusic-player-queue-item[selected]');
    if (selectedQueue && selectedQueue.querySelector('ytmusic-offline-badge-renderer, [icon*="offline_pin"]')) {
      return true;
    }
    return false;
  }

  function extractHeaderContext() {
    const header = document.querySelector('ytmusic-responsive-header-renderer, ytmusic-detail-header-renderer, ytmusic-immersive-header-renderer');
    if (!header) return { artist: '', album: '' };
    const titleEl = header.querySelector('h1.title, yt-formatted-string.title, .title');
    const album = titleEl && titleEl.textContent ? titleEl.textContent.trim() : '';

    let artist = '';
    const strapLinks = header.querySelectorAll('.strapline-text a, .subtitle a, ytmusic-strapline-text-one-line a');
    for (const a of strapLinks) {
      const txt = (a.textContent || '').trim();
      if (txt && !/^(album|ep|single|playlist|songs?|lagu|\d{4})$/i.test(txt)) {
        artist = txt;
        break;
      }
    }
    if (!artist) {
      const strapEl = header.querySelector('.strapline-text, ytmusic-strapline-text-one-line');
      if (strapEl && strapEl.textContent) {
        artist = strapEl.textContent.split(/[•·]/)[0].trim();
      }
    }
    return { artist, album };
  }

  function extractTrackFromRow(row, ctx) {
    if (!row) return null;
    const link = row.querySelector('a.yt-simple-endpoint[href*="watch?v="], a[href*="v="]');
    let videoId = '';
    if (link && link.href) {
      try { videoId = new URL(link.href, location.origin).searchParams.get('v') || ''; } catch {}
    }

    const titleEl =
      row.querySelector('.title-column yt-formatted-string.title a') ||
      row.querySelector('.title-column yt-formatted-string.title') ||
      row.querySelector('yt-formatted-string.song-title') ||
      link;
    const title = titleEl && titleEl.textContent ? titleEl.textContent.trim() : '';
    if (!title) return null;

    let artist = '';
    const secCols = row.querySelectorAll('.secondary-flex-columns yt-formatted-string, yt-formatted-string.byline');
    for (const col of secCols) {
      const a = col.querySelector('a');
      const raw = (a ? a.textContent : col.textContent) || '';
      const firstPart = raw.split(/[•·]/)[0].trim();
      if (
        firstPart &&
        !/^\d+[\.,]?\d*\s*[KMBkmb]?\s*(plays?|views?|putar|ditonton)/i.test(firstPart) &&
        !/^\d{1,2}:\d{2}/.test(firstPart) &&
        firstPart.toLowerCase() !== title.toLowerCase()
      ) {
        artist = firstPart;
        break;
      }
    }
    if (!artist && ctx && ctx.artist) artist = ctx.artist;

    let duration = 0;
    const fixedCols = row.querySelectorAll('.fixed-columns yt-formatted-string, yt-formatted-string.duration');
    for (const fc of fixedCols) {
      const sec = parseDurationSec(fc.textContent);
      if (sec > 0) { duration = sec; break; }
    }

    const imgEl = row.querySelector('img#img, img');
    let artworkUrl = null;
    if (imgEl && imgEl.src && /^https?:\/\//i.test(imgEl.src)) {
      artworkUrl = imgEl.src.replace(/=w\d+-h\d+[^&]*/i, '=w226-h226-l90-rj');
    }

    const hasOfflineBadge = Boolean(
      row.querySelector('ytmusic-offline-badge-renderer, [icon*="offline_pin"], [aria-label*="downloaded" i], [aria-label*="offline" i]')
    );

    return {
      id: videoId,
      title,
      artist,
      album: (ctx && ctx.album) || null,
      duration,
      artworkUrl,
      hasOfflineBadge,
    };
  }

  function sendOfflineTracks(tracks, reason, forceResend) {
    if (!tracks || !tracks.length) return;
    if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.ytmgBridge) return;

    const fresh = [];
    for (const t of tracks) {
      if (!t || !t.title) continue;
      const key = (t.id || '') + '::' + t.title.toLowerCase() + '::' + (t.artist || '').toLowerCase();
      if (!forceResend && reportedOfflineKeys.has(key)) continue;
      reportedOfflineKeys.add(key);
      fresh.push({
        id: t.id || '',
        title: t.title,
        artist: t.artist || '',
        album: t.album || null,
        duration: t.duration || 0,
        artworkUrl: t.artworkUrl || null,
      });
    }
    if (!fresh.length) return;

    window.webkit.messageHandlers.ytmgBridge.postMessage({
      action: 'offlineTracksDiscovered',
      reason,
      tracks: fresh,
    });
  }

  function scanOfflineTracks(includeAllVisible, reason, forceResend) {
    if (!isYtm) return;
    const onDownloads = isDownloadsPage();
    const wholeCollectionDownloaded = isCollectionDownloadedHeader();
    const shouldTakeAll = includeAllVisible || onDownloads || wholeCollectionDownloaded;

    const ctx = extractHeaderContext();
    const rows = document.querySelectorAll(
      'ytmusic-responsive-list-item-renderer, ytmusic-playlist-panel-video-renderer'
    );
    const collected = [];
    for (const row of rows) {
      const item = extractTrackFromRow(row, ctx);
      if (!item) continue;
      if (shouldTakeAll || item.hasOfflineBadge) {
        collected.push(item);
      }
    }

    if (includeAllVisible) {
      const video = getVideo();
      const dur = video && Number.isFinite(video.duration) ? video.duration : 0;
      const playing = extractYtmTrack(dur);
      if (playing) collected.unshift(playing);
    }

    if (collected.length) {
      sendOfflineTracks(
        collected,
        reason || (onDownloads ? 'downloads_page' : (wholeCollectionDownloaded ? 'downloaded_collection' : 'offline_badge')),
        Boolean(forceResend)
      );
    }
  }

  function scheduleOfflineScan() {
    if (!isYtm) return;
    if (offlineScanTimer) clearTimeout(offlineScanTimer);
    offlineScanTimer = setTimeout(() => {
      offlineScanTimer = null;
      scanOfflineTracks(false, null, false);
    }, 650);
  }

  window.__ytmgScanOfflinePage = function () {
    scanOfflineTracks(true, 'manual_page_sync', true);
  };

  // Detect clicks on YouTube Music's Download button (Album/Playlist header, song row, or 3-dot menu)
  if (isYtm) {
    document.addEventListener('click', (e) => {
      const target = e.target instanceof Element ? e.target : null;
      if (!target) return;
      const dlHost = target.closest(
        'ytmusic-download-button-renderer, button[aria-label*="download" i], button[aria-label*="unduh" i], tp-yt-paper-item, ytmusic-menu-service-item-renderer, ytmusic-toggle-menu-service-item-renderer'
      );
      if (!dlHost) return;
      const label = ((dlHost.getAttribute('aria-label') || '') + ' ' + (dlHost.textContent || '')).trim().toLowerCase();
      const isDownloadClick =
        dlHost.tagName === 'YTMUSIC-DOWNLOAD-BUTTON-RENDERER' ||
        /\b(download|unduh)\b/i.test(label);
      if (!isDownloadClick || /\b(remove|hapus|delete|cancel|batal)\b/i.test(label)) return;

      const row = dlHost.closest('ytmusic-responsive-list-item-renderer, ytmusic-playlist-panel-video-renderer');
      if (row) {
        const ctx = extractHeaderContext();
        const item = extractTrackFromRow(row, ctx);
        if (item) sendOfflineTracks([item], 'download_click_row', true);
      } else {
        setTimeout(() => scanOfflineTracks(true, 'download_click_collection', true), 250);
      }
    }, true);
  }

  window.__ytmgCmd = function (action, value) {
    const video = getVideo();
    if (action === 'seek') {
      if (video && Number.isFinite(value)) {
        const maxT = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : value;
        video.currentTime = Math.max(0, Math.min(value, maxT));
        postSnapshot(true);
      }
      return;
    }
    if (action === 'play') {
      if (video && video.paused) {
        const sel = isYtm
          ? 'ytmusic-player-bar #play-pause-button, ytmusic-player-bar .play-pause-button'
          : '#movie_player .ytp-play-button';
        const btn = document.querySelector(sel);
        if (btn) btn.click();
        else video.play();
        setTimeout(() => postSnapshot(true), 80);
      }
      return;
    }
    if (action === 'pause') {
      if (video && !video.paused) {
        const sel = isYtm
          ? 'ytmusic-player-bar #play-pause-button, ytmusic-player-bar .play-pause-button'
          : '#movie_player .ytp-play-button';
        const btn = document.querySelector(sel);
        if (btn) btn.click();
        else video.pause();
        setTimeout(() => postSnapshot(true), 80);
      }
      return;
    }
    if (action === 'togglePlay') {
      const sel = isYtm
        ? 'ytmusic-player-bar #play-pause-button, ytmusic-player-bar .play-pause-button'
        : '#movie_player .ytp-play-button';
      const btn = document.querySelector(sel);
      if (btn) btn.click();
      else if (video) (video.paused ? video.play() : video.pause());
      setTimeout(() => postSnapshot(true), 80);
      return;
    }
    if (action === 'next') {
      const sel = isYtm
        ? 'ytmusic-player-bar .next-button, ytmusic-player-bar tp-yt-paper-icon-button.next-button'
        : '#movie_player .ytp-next-button';
      const btn = document.querySelector(sel);
      if (btn) btn.click();
      setTimeout(() => postSnapshot(true), 250);
      return;
    }
    if (action === 'prev') {
      if (isYtm) {
        const btn = document.querySelector(
          'ytmusic-player-bar .previous-button, ytmusic-player-bar tp-yt-paper-icon-button.previous-button'
        );
        if (btn) btn.click();
      } else {
        const btn = document.querySelector('#movie_player .ytp-prev-button');
        if (btn && btn.style.display !== 'none') btn.click();
        else if (video) video.currentTime = 0;
      }
      setTimeout(() => postSnapshot(true), 250);
    }
  };

  let sidebarActiveState = false;

  window.__ytmgSetSidebarActive = function (active) {
    sidebarActiveState = Boolean(active);
    const btn = document.getElementById('ytmg-native-trigger-btn');
    if (btn) btn.dataset.active = String(sidebarActiveState);
  };

  function installPlayerTriggerButton() {
    const STYLE_ID = 'ytmg-native-trigger-style';
    const BTN_ID = 'ytmg-native-trigger-btn';

    if (!document.getElementById(STYLE_ID) && document.head) {
      const style = document.createElement('style');
      style.id = STYLE_ID;
      style.textContent = `
        #${BTN_ID}.ytmg-ytm-btn {
          appearance: none; border: 0; background: transparent;
          color: rgba(255,255,255,0.8); width: 40px; height: 40px; border-radius: 50%;
          display: inline-flex; align-items: center; justify-content: center;
          cursor: pointer; margin: 0 2px; padding: 0;
          transition: background 0.16s ease, color 0.16s ease, transform 0.12s ease;
        }
        #${BTN_ID}.ytmg-ytm-btn:hover { background: rgba(255,255,255,0.12); color: #fff; }
        #${BTN_ID}.ytmg-ytm-btn:active { transform: scale(0.92); }
        #${BTN_ID}.ytmg-ytm-btn[data-active="true"] { color: rgb(var(--ytmg-accent-rgb, 244, 63, 108)); background: rgba(var(--ytmg-accent-rgb, 244, 63, 108), 0.22); }
        #${BTN_ID}.ytmg-yt-btn {
          display: inline-flex; align-items: center; justify-content: center;
          vertical-align: top; color: rgba(255,255,255,0.9);
        }
        #${BTN_ID}.ytmg-yt-btn[data-active="true"] { color: rgb(var(--ytmg-accent-rgb, 244, 63, 108)); }
      `;
      document.head.appendChild(style);
    }

    const container = isYtm
      ? document.querySelector('ytmusic-player-bar .right-controls-buttons')
      : document.querySelector('#movie_player .ytp-right-controls');
    if (!container) return;

    let btn = document.getElementById(BTN_ID);
    if (!btn) {
      btn = document.createElement('button');
      btn.id = BTN_ID;
      btn.type = 'button';
      btn.className = isYtm ? 'ytmg-ytm-btn' : 'ytp-button ytmg-yt-btn';
      btn.title = 'Toggle Lyrics Sidebar (Shift+L)';
      btn.setAttribute('aria-label', 'Toggle Lyrics Sidebar');
      btn.dataset.active = String(sidebarActiveState);

      const ns = 'http://www.w3.org/2000/svg';
      const svg = document.createElementNS(ns, 'svg');
      svg.setAttribute('width', '22');
      svg.setAttribute('height', '22');
      svg.setAttribute('viewBox', '0 0 24 24');
      svg.setAttribute('fill', 'none');
      svg.setAttribute('stroke', 'currentColor');
      svg.setAttribute('stroke-width', '2');
      svg.setAttribute('stroke-linecap', 'round');
      svg.setAttribute('stroke-linejoin', 'round');
      [['4','7','15','7'],['4','12','20','12'],['4','17','12','17']].forEach(([x1,y1,x2,y2]) => {
        const l = document.createElementNS(ns, 'line');
        l.setAttribute('x1', x1); l.setAttribute('y1', y1);
        l.setAttribute('x2', x2); l.setAttribute('y2', y2);
        svg.appendChild(l);
      });
      const c = document.createElementNS(ns, 'circle');
      c.setAttribute('cx', '18.5'); c.setAttribute('cy', '17'); c.setAttribute('r', '2.5');
      c.setAttribute('fill', 'currentColor'); c.setAttribute('stroke', 'none');
      svg.appendChild(c);
      btn.appendChild(svg);

      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytmgBridge) {
          window.webkit.messageHandlers.ytmgBridge.postMessage({ action: 'toggleSidebar' });
        }
      });
      container.prepend(btn);
    } else if (!container.contains(btn)) {
      container.prepend(btn);
    }
  }

  window.addEventListener('keydown', (e) => {
    if (!e.shiftKey || e.ctrlKey || e.metaKey || e.altKey || e.repeat) return;
    if (e.key.toLowerCase() !== 'l') return;
    const path = typeof e.composedPath === 'function' ? e.composedPath() : [e.target];
    for (const node of path) {
      if (!(node instanceof HTMLElement)) continue;
      if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA' || node.isContentEditable) return;
    }
    e.preventDefault();
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytmgBridge) {
      window.webkit.messageHandlers.ytmgBridge.postMessage({ action: 'toggleSidebar' });
    }
  }, true);

  let boundVideo = null;
  const onVideoChange = () => postSnapshot(true);

  function bindVideo() {
    const v = getVideo();
    if (v === boundVideo) return;
    if (boundVideo) {
      ['play', 'pause', 'seeked', 'loadedmetadata', 'durationchange', 'ratechange'].forEach((ev) =>
        boundVideo.removeEventListener(ev, onVideoChange)
      );
    }
    boundVideo = v;
    if (boundVideo) {
      ['play', 'pause', 'seeked', 'loadedmetadata', 'durationchange', 'ratechange'].forEach((ev) =>
        boundVideo.addEventListener(ev, onVideoChange)
      );
    }
  }

  // Custom Spotify-style interactive progress bar inside ytmusic-player-bar
  let isSeekingCustomBar = false;
  let customBarSeekRatio = 0;

  function formatMmSs(sec) {
    if (!Number.isFinite(sec) || sec < 0) return '0:00';
    const total = Math.floor(sec);
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const ss = s < 10 ? '0' + s : '' + s;
    if (h > 0) return h + ':' + (m < 10 ? '0' + m : m) + ':' + ss;
    return m + ':' + ss;
  }

  function installCustomProgressBar() {
    if (!isYtm) return;
    const playerBar = document.querySelector('ytmusic-player-bar');
    if (!playerBar) return;

    let bar = document.getElementById('ytmg-progress-bar');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'ytmg-progress-bar';

      const curEl = document.createElement('span');
      curEl.className = 'ytmg-pb-time ytmg-pb-cur';
      curEl.textContent = '0:00';

      const hit = document.createElement('div');
      hit.className = 'ytmg-pb-hit';
      hit.setAttribute('role', 'slider');
      hit.setAttribute('aria-label', 'Seek song progress');

      const track = document.createElement('div');
      track.className = 'ytmg-pb-track';
      const buf = document.createElement('div');
      buf.className = 'ytmg-pb-buf';
      const fill = document.createElement('div');
      fill.className = 'ytmg-pb-fill';
      track.appendChild(buf);
      track.appendChild(fill);

      const knob = document.createElement('div');
      knob.className = 'ytmg-pb-knob';

      const tip = document.createElement('div');
      tip.className = 'ytmg-pb-tooltip';
      tip.textContent = '0:00';

      hit.appendChild(track);
      hit.appendChild(knob);
      hit.appendChild(tip);

      const durEl = document.createElement('span');
      durEl.className = 'ytmg-pb-time ytmg-pb-dur';
      durEl.textContent = '0:00';

      bar.appendChild(curEl);
      bar.appendChild(hit);
      bar.appendChild(durEl);

      const ratioFromEvent = (ev) => {
        const rect = hit.getBoundingClientRect();
        if (rect.width <= 0) return 0;
        return Math.max(0, Math.min(1, (ev.clientX - rect.left) / rect.width));
      };

      const updatePreview = (ratio) => {
        const pct = (ratio * 100).toFixed(3) + '%';
        fill.style.width = pct;
        knob.style.left = pct;
        const v = getVideo();
        const dur = v && Number.isFinite(v.duration) && v.duration > 0 ? v.duration : 0;
        const formatted = formatMmSs(ratio * dur);
        curEl.textContent = formatted;
        tip.style.left = pct;
        tip.textContent = formatted;
      };

      const commitSeek = (ratio) => {
        const v = getVideo();
        if (v && Number.isFinite(v.duration) && v.duration > 0) {
          v.currentTime = Math.max(0, Math.min(v.duration, ratio * v.duration));
          postSnapshot(true);
        }
      };

      hit.addEventListener('pointermove', (ev) => {
        const r = ratioFromEvent(ev);
        const v = getVideo();
        const dur = v && Number.isFinite(v.duration) && v.duration > 0 ? v.duration : 0;
        tip.style.left = (r * 100).toFixed(3) + '%';
        tip.textContent = formatMmSs(r * dur);
        if (isSeekingCustomBar) {
          customBarSeekRatio = r;
          updatePreview(r);
        }
      });

      hit.addEventListener('pointerdown', (ev) => {
        if (ev.button !== 0) return;
        ev.preventDefault();
        ev.stopPropagation();
        isSeekingCustomBar = true;
        bar.classList.add('dragging');
        if (hit.setPointerCapture) {
          try { hit.setPointerCapture(ev.pointerId); } catch {}
        }
        customBarSeekRatio = ratioFromEvent(ev);
        updatePreview(customBarSeekRatio);
      });

      const finishDrag = (ev) => {
        if (!isSeekingCustomBar) return;
        isSeekingCustomBar = false;
        bar.classList.remove('dragging');
        if (hit.releasePointerCapture) {
          try { hit.releasePointerCapture(ev.pointerId); } catch {}
        }
        customBarSeekRatio = ratioFromEvent(ev);
        updatePreview(customBarSeekRatio);
        commitSeek(customBarSeekRatio);
      };

      hit.addEventListener('pointerup', finishDrag);
      hit.addEventListener('pointercancel', finishDrag);

      playerBar.appendChild(bar);
    } else if (!playerBar.contains(bar)) {
      playerBar.appendChild(bar);
    }
  }

  function updateCustomProgressBar() {
    if (!isYtm || isSeekingCustomBar) return;
    const bar = document.getElementById('ytmg-progress-bar');
    if (!bar) return;
    const v = getVideo();
    const fill = bar.querySelector('.ytmg-pb-fill');
    const knob = bar.querySelector('.ytmg-pb-knob');
    const buf = bar.querySelector('.ytmg-pb-buf');
    const curEl = bar.querySelector('.ytmg-pb-cur');
    const durEl = bar.querySelector('.ytmg-pb-dur');
    if (!fill || !knob) return;

    const dur = v && Number.isFinite(v.duration) && v.duration > 0 ? v.duration : 0;
    const cur = v && Number.isFinite(v.currentTime) ? v.currentTime : 0;
    const ratio = dur > 0 ? Math.max(0, Math.min(1, cur / dur)) : 0;
    const pct = (ratio * 100).toFixed(3) + '%';
    fill.style.width = pct;
    knob.style.left = pct;
    if (curEl) curEl.textContent = formatMmSs(cur);
    if (durEl) durEl.textContent = formatMmSs(dur);

    if (buf && v && dur > 0 && v.buffered && v.buffered.length > 0) {
      let bufEnd = 0;
      for (let i = 0; i < v.buffered.length; i++) {
        if (v.buffered.start(i) <= cur + 0.5 && v.buffered.end(i) > bufEnd) {
          bufEnd = v.buffered.end(i);
        }
      }
      buf.style.width = (Math.max(0, Math.min(1, bufEnd / dur)) * 100).toFixed(2) + '%';
    }
  }

  function tickCustomProgressLoop() {
    updateCustomProgressBar();
    requestAnimationFrame(tickCustomProgressLoop);
  }
  if (isYtm) {
    requestAnimationFrame(tickCustomProgressLoop);
  }

  // Dynamic theme-colored Music logo synced with --ytmg-accent-rgb
  function installDynamicLogo() {
    if (!isYtm) return;
    const navBar = document.querySelector('ytmusic-nav-bar');
    if (!navBar) return;
    const logoImg = navBar.querySelector('img.logo');
    const anchor = (logoImg && logoImg.closest('a')) || navBar.querySelector('.left-content a.yt-simple-endpoint');
    if (!anchor) return;

    anchor.classList.add('ytmg-has-dyn-logo');
    if (anchor.querySelector('#ytmg-dynamic-logo')) return;

    const wrap = document.createElement('span');
    wrap.id = 'ytmg-dynamic-logo';

    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', '25');
    svg.setAttribute('height', '25');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');

    const disc = document.createElementNS(ns, 'circle');
    disc.setAttribute('class', 'ytmg-logo-disc');
    disc.setAttribute('cx', '12');
    disc.setAttribute('cy', '12');
    disc.setAttribute('r', '11.5');
    svg.appendChild(disc);

    const ring = document.createElementNS(ns, 'circle');
    ring.setAttribute('cx', '12');
    ring.setAttribute('cy', '12');
    ring.setAttribute('r', '6.6');
    ring.setAttribute('fill', 'none');
    ring.setAttribute('stroke', '#ffffff');
    ring.setAttribute('stroke-width', '1.35');
    svg.appendChild(ring);

    const tri = document.createElementNS(ns, 'polygon');
    tri.setAttribute('points', '10.1,8.8 15.8,12 10.1,15.2');
    tri.setAttribute('fill', '#ffffff');
    svg.appendChild(tri);

    const text = document.createElement('span');
    text.className = 'ytmg-logo-wordmark';
    text.textContent = 'Music';

    wrap.appendChild(svg);
    wrap.appendChild(text);
    anchor.appendChild(wrap);
  }

  // Hide redundant Lyrics & Comments tabs on YTM Watch/Player page (keep UP NEXT & RELATED)
  function cleanPlayerPageTabs() {
    if (!isYtm) return;
    const tabs = document.querySelectorAll('ytmusic-player-page tp-yt-paper-tab');
    if (!tabs || !tabs.length) return;

    let firstVisibleTab = null;
    let hiddenTabWasSelected = false;

    for (const tab of tabs) {
      const label = (tab.textContent || '').trim();
      const shouldHide = /^(lyrics?|lirik|comments?|komentar)$/i.test(label);
      if (shouldHide) {
        if (tab.dataset.ytmgHiddenTab !== 'true') {
          tab.dataset.ytmgHiddenTab = 'true';
        }
        const isSelected =
          tab.hasAttribute('selected') ||
          tab.classList.contains('iron-selected') ||
          tab.getAttribute('aria-selected') === 'true';
        if (isSelected) hiddenTabWasSelected = true;
      } else {
        if (tab.dataset.ytmgHiddenTab) delete tab.dataset.ytmgHiddenTab;
        if (!firstVisibleTab) firstVisibleTab = tab;
      }
    }

    if (
      hiddenTabWasSelected &&
      firstVisibleTab &&
      document.documentElement.dataset.ytmgTheme === 'apple-glass'
    ) {
      firstVisibleTab.click();
    }
  }

  const observer = new MutationObserver(() => {
    installPlayerTriggerButton();
    installCustomProgressBar();
    installDynamicLogo();
    cleanPlayerPageTabs();
    bindVideo();
    postSnapshot(false);
    scheduleOfflineScan();
  });

  function startObserving() {
    if (document.body) {
      observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    }
    installPlayerTriggerButton();
    installCustomProgressBar();
    installDynamicLogo();
    cleanPlayerPageTabs();
    bindVideo();
    postSnapshot(true);
    scheduleOfflineScan();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserving, { once: true });
  } else {
    startObserving();
  }

  window.addEventListener('yt-navigate-finish', () => {
    installPlayerTriggerButton();
    installCustomProgressBar();
    installDynamicLogo();
    cleanPlayerPageTabs();
    bindVideo();
    postSnapshot(true);
    scheduleOfflineScan();
  });

  setInterval(() => {
    installPlayerTriggerButton();
    bindVideo();
    postSnapshot(true);
  }, 850);
})();
"""#
}
