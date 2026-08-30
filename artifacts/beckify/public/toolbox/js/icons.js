/* Beckify line icons. Replaces legacy emoji labels without a third-party icon font. */
(function () {
  'use strict';

  const ICONS = {
    '\u26a1': 'bolt', '\ud83d\udd0c': 'plug', '\ud83e\uddea': 'flask', '\ud83d\udd0b': 'battery',
    '\ud83d\udeb2': 'bike', '\ud83d\udccb': 'clipboard', '\ud83d\udce1': 'antenna', '\ud83d\udcda': 'book',
    '\ud83d\udccd': 'ruler', '\ud83d\udd27': 'wrench', '\ud83d\udd2c': 'scope', '\ud83d\uddc2': 'folder',
    '\ud83d\ude80': 'rocket', '\ud83d\udee0': 'tools', '\ud83d\udcdd': 'note', '\ud83d\udd04': 'cycle',
    '\ud83d\udd17': 'link', '\ud83d\udcc9': 'chart-down', '\ud83d\udccc': 'pin', '\ud83c\udfdb': 'building',
    '\ud83d\udcc8': 'chart', '\ud83d\udd14': 'bell', '\ud83d\udfe2': 'status', '\ud83d\udd35': 'dot',
    '\ud83d\udd00': 'switch', '\ud83d\udccf': 'measure', '\ud83d\udcbe': 'save', '\ud83d\udcc1': 'folder',
    '\u222b': 'chart', '\ud83c\udf00': 'cycle', '\ud83c\udfd7': 'building', '\ud83d\udee1': 'status',
    '\ud83d\uddc4': 'folder', '\ud83d\udca1': 'bolt', '\ud83d\udcf7': 'scope', '\ud83d\udd0a': 'bell'
  };
  const PATHS = {
    bolt: 'M13 2 5 13h6l-1 9 8-12h-6l1-8Z', plug: 'M8 3v6m8-6v6M6 9h12v3a6 6 0 0 1-12 0V9Zm6 9v3',
    flask: 'M9 3h6m-5 0v6l-5 8a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-8V3M7 15h10', battery: 'M6 7h12v13H6zM9 4h6v3H9zM9 11h6M12 8v6',
    bike: 'M5 18a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm14 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM5 15h5l3-6 3 6m-6 0 3-6 3-3', clipboard: 'M8 4h8v3H8zM6 6H4v15h16V6h-2M8 11h8m-8 4h6',
    antenna: 'M12 18v3m-4 0h8M6 14a8 8 0 0 1 12 0M3 11a12 12 0 0 1 18 0M12 18a2 2 0 1 0 0-4 2 2 0 0 0 0 4', book: 'M4 4h7a2 2 0 0 1 2 2v14a2 2 0 0 0-2-2H4zM20 4h-7a2 2 0 0 0-2 2v14a2 2 0 0 1 2-2h7z',
    ruler: 'M4 17 17 4l3 3L7 20H4zM8 13l3 3m-1-7 3 3m-1-7 3 3', wrench: 'M14 6a4 4 0 0 0 5 5l-8 8-3-3 8-8a4 4 0 0 0-5-5l3 3-3 3-3-3 3-3Z', scope: 'M5 5h5v5H5zM14 14h5v5h-5zM10 7h4v2h-4zm4 8h-4v2h4zM7 10v4m10-4v4', folder: 'M3 6h7l2 2h9v11H3z',
    rocket: 'M12 3c4 1 6 4 6 8l-6 7-6-7c0-4 2-7 6-8Zm-3 9h.01M15 12h.01M9 19l-2 2m8-2 2 2', tools: 'M4 20 14 10m-2-6a4 4 0 0 0 5 5l3 3-3 3-3-3m-8 8 3-3', note: 'M5 4h14v16H5zM8 8h8m-8 4h8m-8 4h5', cycle: 'M5 8a8 8 0 0 1 13-2l2 2m-3 8a8 8 0 0 1-13 2l-2-2m0 0h5m12-10v5',
    link: 'M9 15 7 17a4 4 0 0 1-6-6l3-3a4 4 0 0 1 6 0m5-3 2-2a4 4 0 0 1 6 6l-3 3a4 4 0 0 1-6 0m-5 3 8-8', 'chart-down': 'M4 4v16h16M7 8l4 4 3-3 5 5', pin: 'M12 21s6-6 6-11a6 6 0 1 0-12 0c0 5 6 11 6 11Zm0-9h.01', building: 'M4 21V5l8-2 8 2v16M8 8h2m4 0h2M8 12h2m4 0h2M8 16h2m4 0h2M11 21v-4h2v4',
    chart: 'M4 19V5m0 14h16M7 15l3-4 3 2 5-7', bell: 'M6 17h12l-2-3v-4a4 4 0 0 0-8 0v4l-2 3Zm4 3h4', status: 'M12 3a9 9 0 1 0 9 9', dot: 'M12 12h.01', switch: 'M5 7h14m-14 10h14M8 4v6m8 4v6', measure: 'M4 18 18 4l2 2L6 20H4zM8 14l2 2m0-6 2 2m0-6 2 2', save: 'M4 4h13l3 3v13H4zM8 4v6h8V4m-8 11h8v5H8z'
  };

  function makeIcon(key) {
    const span = document.createElement('span');
    span.className = 'beckify-icon';
    span.dataset.icon = ICONS[key] || 'dot';
    span.setAttribute('aria-hidden', 'true');
    span.innerHTML = '<svg viewBox="0 0 24 24" focusable="false"><path d="' + (PATHS[ICONS[key]] || PATHS.dot) + '"></path></svg>';
    return span;
  }

  function replaceTextNode(node) {
    const value = node.nodeValue;
    if (!value || !Object.keys(ICONS).some((key) => value.includes(key))) return;
    const fragment = document.createDocumentFragment();
    let rest = value;
    while (rest) {
      let match = null;
      for (const key of Object.keys(ICONS)) {
        const index = rest.indexOf(key);
        if (index >= 0 && (!match || index < match.index)) match = { key, index };
      }
      if (!match) { fragment.appendChild(document.createTextNode(rest)); break; }
      if (match.index) fragment.appendChild(document.createTextNode(rest.slice(0, match.index)));
      fragment.appendChild(makeIcon(match.key));
      rest = rest.slice(match.index + match.key.length);
    }
    node.parentNode.replaceChild(fragment, node);
  }

  function init() {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) {
      const parent = walker.currentNode.parentElement;
      if (parent && !parent.closest('script, style, textarea, .no-icon-replace')) nodes.push(walker.currentNode);
    }
    nodes.forEach(replaceTextNode);
    const home = document.querySelector('.header-logo');
    if (home) home.setAttribute('aria-label', 'Back to Beckify home');
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
}());
