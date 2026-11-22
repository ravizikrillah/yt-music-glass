(function () {
  const OWNER = 'ravizikrillah';
  const REPO = 'yt-music-glass';
  const RELEASES_API = `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`;
  const FALLBACK_URL = `https://github.com/${OWNER}/${REPO}/releases`;

  // 1. Live fetch latest macOS DMG link, version & file size from GitHub Releases
  async function syncLatestRelease() {
    try {
      const res = await fetch(RELEASES_API, {
        headers: { Accept: 'application/vnd.github+json' },
      });
      if (!res.ok) return;
      const data = await res.json();
      const tag = data.tag_name || 'v1.0.0';
      const assets = Array.isArray(data.assets) ? data.assets : [];
      const dmg =
        assets.find((a) => /arm64.*\.dmg$/i.test(a.name || '')) ||
        assets.find((a) => /\.dmg$/i.test(a.name || ''));

      const downloadUrl = (dmg && dmg.browser_download_url) || data.html_url || FALLBACK_URL;
      document.querySelectorAll('[data-download-link]').forEach((el) => {
        el.setAttribute('href', downloadUrl);
      });

      const metaEl = document.getElementById('release-meta');
      if (metaEl) {
        const sizeMb = dmg && dmg.size ? `${(dmg.size / 1048576).toFixed(1)} MB DMG` : 'macOS DMG';
        metaEl.textContent = `${tag} for macOS 14+ · Apple Silicon · ${sizeMb}`;
      }

      const btnLabel = document.getElementById('download-btn-label');
      if (btnLabel && dmg) {
        btnLabel.textContent = `Download ${tag} (.dmg)`;
      }
    } catch {
      // Keep clean fallback pointing to GitHub Releases
    }
  }

  // 2. Interactive Smart Translate language preview in the hero mockup
  const langToggle = document.getElementById('preview-lang-toggle');
  const dockLang = document.getElementById('preview-dock-lang');
  let previewLang = 'id';

  if (langToggle) {
    langToggle.addEventListener('click', () => {
      previewLang = previewLang === 'id' ? 'en' : 'id';
      langToggle.textContent = previewLang === 'id' ? 'Translate · Auto→ID' : 'Translate · Auto→EN';
      if (dockLang) dockLang.textContent = previewLang.toUpperCase();
      document.querySelectorAll('.l-trans').forEach((el) => {
        const nextText = el.getAttribute(`data-${previewLang}`);
        if (nextText) el.textContent = nextText;
      });
    });
  }

  // 3. One-click copy for install Terminal commands
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

  syncLatestRelease();
})();
