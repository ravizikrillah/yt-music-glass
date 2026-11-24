(function () {
  const STYLE_ID = 'ytmg-apple-glass-style';
  const site = location.hostname.startsWith('music.') ? 'ytm' : 'youtube';
  document.documentElement.dataset.ytmgSite = site;

  const cssText = window.__YTMG_GLASS_CSS__ || '';
  if (cssText && !document.getElementById(STYLE_ID)) {
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = cssText;
    (document.head || document.documentElement).appendChild(style);
  }

  window.__ytmgSetTheme = function (enabled) {
    document.documentElement.dataset.ytmgTheme = enabled ? 'apple-glass' : 'original';
  };

  window.__ytmgSetFontStyle = function (style) {
    document.documentElement.dataset.ytmgFont = style === 'sfpro' ? 'sfpro' : 'roboto';
  };

  window.__ytmgSetPalette = function (accentRgb, bgTop, bgBottom, artworkUrl) {
    const root = document.documentElement.style;
    root.setProperty('--ytmg-accent-rgb', accentRgb);
    root.setProperty('--ytmg-bg-top', bgTop);
    root.setProperty('--ytmg-bg-bottom', bgBottom);
    if (artworkUrl) {
      const safeUrl = String(artworkUrl).replace(/["'\\()\n\r]/g, '');
      root.setProperty('--ytmg-artwork-url', 'url("' + safeUrl + '")');
    } else {
      root.setProperty('--ytmg-artwork-url', 'none');
    }
  };

  document.documentElement.dataset.ytmgTheme = 'apple-glass';
})();
