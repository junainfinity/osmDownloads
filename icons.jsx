// Inline SVG icons — single stroke set, 1.5px
const Ic = {
  plus: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>,
  download: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v12m0 0l-4-4m4 4l4-4M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2"/></svg>,
  pause: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="currentColor"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>,
  play: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="currentColor"><path d="M7 4.5v15c0 .8.9 1.3 1.6.9l12-7.5c.6-.4.6-1.4 0-1.8l-12-7.5C7.9 3.2 7 3.7 7 4.5z"/></svg>,
  stop: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="1.5"/></svg>,
  trash: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M6 6l1 14a2 2 0 002 2h6a2 2 0 002-2l1-14M10 11v6M14 11v6"/></svg>,
  folder: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/></svg>,
  folderOpen: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v1H3V7zM3 9h18l-2 8a2 2 0 01-2 1.5H5A2 2 0 013 17V9z"/></svg>,
  more: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="currentColor"><circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/></svg>,
  search: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="11" cy="11" r="6"/><path d="M16 16l4 4"/></svg>,
  check: (p) => <svg viewBox="0 0 24 24" width={p?.s||12} height={p?.s||12} fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>,
  chevronDown: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9l6 6 6-6"/></svg>,
  chevronRight: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>,
  x: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>,
  warn: (p) => <svg viewBox="0 0 24 24" width={p?.s||18} height={p?.s||18} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M12 9v4m0 3v.01M10.3 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.7 3.86a2 2 0 00-3.4 0z"/></svg>,
  link: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M10 13a5 5 0 007 0l3-3a5 5 0 00-7-7l-1 1M14 11a5 5 0 00-7 0l-3 3a5 5 0 007 7l1-1"/></svg>,
  globe: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>,
  inbox: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M22 12h-6l-2 3h-4l-2-3H2M5.45 5.11L2 12v6a2 2 0 002 2h16a2 2 0 002-2v-6l-3.45-6.89A2 2 0 0016.76 4H7.24a2 2 0 00-1.79 1.11z"/></svg>,
  clock: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  settings: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.6 1.6 0 00-1.8-.3 1.6 1.6 0 00-1 1.5V21a2 2 0 11-4 0v-.1A1.6 1.6 0 008 19.4a1.6 1.6 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1A1.6 1.6 0 003.7 15a1.6 1.6 0 00-1.5-1H2a2 2 0 110-4h.1A1.6 1.6 0 003.7 9 1.6 1.6 0 003.4 7.2l-.1-.1a2 2 0 112.8-2.8l.1.1A1.6 1.6 0 008 4.7H8a1.6 1.6 0 001-1.5V3a2 2 0 114 0v.1a1.6 1.6 0 001 1.5 1.6 1.6 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.6 1.6 0 00-.3 1.8v0a1.6 1.6 0 001.5 1H21a2 2 0 110 4h-.1a1.6 1.6 0 00-1.5 1z"/></svg>,
  refresh: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 0115-6.7L21 8M21 3v5h-5M21 12a9 9 0 01-15 6.7L3 16M3 21v-5h5"/></svg>,
  filter: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M3 5h18l-7 9v6l-4-2v-4L3 5z"/></svg>,
  sun: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>,
  moon: (p) => <svg viewBox="0 0 24 24" width={p?.s||14} height={p?.s||14} fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z"/></svg>,
  hf: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="currentColor"><path d="M12 3a8 8 0 00-7.5 11 2 2 0 00-.5 3.5l1.5 1.3c.3.3.7.4 1.1.3l1.5-.4a2.4 2.4 0 003 0l.6-.4.6.4a2.4 2.4 0 003 0l1.5.4c.4.1.8 0 1.1-.3l1.5-1.3a2 2 0 00-.5-3.5A8 8 0 0012 3zm-3 8a1.2 1.2 0 110-2.4A1.2 1.2 0 019 11zm6 0a1.2 1.2 0 110-2.4 1.2 1.2 0 010 2.4zm-3 5.5a3.5 3.5 0 01-3-1.7c-.2-.4.1-.8.6-.8h4.8c.5 0 .8.4.6.8a3.5 3.5 0 01-3 1.7z"/></svg>,
  github: (p) => <svg viewBox="0 0 24 24" width={p?.s||16} height={p?.s||16} fill="currentColor"><path d="M12 2a10 10 0 00-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.04 1.53 1.04.9 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.99 1.03-2.69-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02A9.6 9.6 0 0112 6.8c.85 0 1.7.11 2.5.34 1.91-1.3 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.6 1.03 2.69 0 3.84-2.34 4.69-4.57 4.94.36.31.68.92.68 1.86v2.76c0 .27.18.58.69.48A10 10 0 0012 2z"/></svg>,
};

function classify(url) {
  if (!url) return null;
  const u = url.trim();
  if (!u) return null;
  if (!/^https?:\/\//i.test(u)) {
    if (/^[\w-]+\/[\w.-]+$/.test(u)) return { kind: 'hf', label: 'Hugging Face', host: 'huggingface.co' };
    return { kind: 'invalid', label: 'Invalid URL', host: '' };
  }
  let host = '';
  try { host = new URL(u).host.toLowerCase(); } catch { return { kind: 'invalid', label: 'Invalid URL', host: '' }; }
  if (host.includes('huggingface.co')) return { kind: 'hf', label: 'Hugging Face', host };
  if (host === 'github.com' || host.endsWith('.github.com') || host === 'raw.githubusercontent.com') return { kind: 'gh', label: 'GitHub', host };
  return { kind: 'unsupported', label: 'Unsupported', host };
}

function fmtBytes(n) {
  if (n == null) return '—';
  if (n < 1024) return n + ' B';
  const u = ['KB','MB','GB','TB'];
  let i = -1, v = n;
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
  return v.toFixed(v < 10 ? 2 : v < 100 ? 1 : 0) + ' ' + u[i];
}
function fmtSpeed(bps) {
  if (!bps) return '—';
  return fmtBytes(bps) + '/s';
}
function fmtEta(s) {
  if (!s || !isFinite(s)) return '—';
  if (s < 60) return Math.round(s) + 's';
  if (s < 3600) return Math.floor(s/60) + 'm ' + Math.round(s%60) + 's';
  return Math.floor(s/3600) + 'h ' + Math.round((s%3600)/60) + 'm';
}
function fmtTimeAgo(t) {
  const d = (Date.now() - t) / 1000;
  if (d < 60) return 'just now';
  if (d < 3600) return Math.floor(d/60) + ' min ago';
  if (d < 86400) return Math.floor(d/3600) + ' hr ago';
  return Math.floor(d/86400) + ' days ago';
}
function ext(name) {
  const m = name.match(/\.([a-z0-9]+)$/i);
  return m ? m[1].toLowerCase() : '';
}

Object.assign(window, { Ic, classify, fmtBytes, fmtSpeed, fmtEta, fmtTimeAgo, ext });
