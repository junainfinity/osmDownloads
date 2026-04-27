// osmDownloads — main app
const { useState, useEffect, useRef, useMemo, useCallback } = React;

// =========================================================================
// Source icon helper
// =========================================================================
function SrcIcon({ kind, size = 16 }) {
  if (kind === 'hf') return <span style={{fontSize: size, lineHeight: 1}}>🤗</span>;
  if (kind === 'gh') return <Ic.github s={size}/>;
  return <Ic.globe s={size}/>;
}
// Replace the emoji on hf — render an inline atom-like glyph that matches our brand
function HFGlyph({ size = 16 }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none">
      <ellipse cx="12" cy="12" rx="9" ry="4" stroke="currentColor" strokeWidth="1.4" transform="rotate(30 12 12)"/>
      <ellipse cx="12" cy="12" rx="9" ry="4" stroke="currentColor" strokeWidth="1.4" transform="rotate(-30 12 12)"/>
      <circle cx="12" cy="12" r="2.2" fill="#FFDD55"/>
    </svg>
  );
}
function Src({ kind, size = 16 }) {
  if (kind === 'hf') return <HFGlyph size={size}/>;
  if (kind === 'gh') return <Ic.github s={size}/>;
  return <Ic.globe s={size}/>;
}

// =========================================================================
// New download bar — detects URL type and lets user pick files
// =========================================================================
function NewDownloadBar({ onSubmit, theme }) {
  const [url, setUrl] = useState('');
  const [resolved, setResolved] = useState(null);
  const [selected, setSelected] = useState({});
  const [dest, setDest] = useState('~/Downloads/osmDownloads');
  const [resolving, setResolving] = useState(false);
  const detect = useMemo(() => classify(url), [url]);

  // simulate URL resolution after a short debounce when it looks recognized
  useEffect(() => {
    setResolved(null);
    if (!detect || detect.kind === 'invalid' || !url.startsWith('http')) return;
    setResolving(true);
    const t = setTimeout(() => {
      const preset = SEED_PRESETS[url.trim()];
      if (preset) {
        setResolved(preset);
        const sel = {};
        preset.files.forEach((f, i) => sel[i] = f.sel);
        setSelected(sel);
      } else {
        // Synthesize a reasonable mock resource for any plausible URL
        if (detect.kind === 'unsupported') {
          setResolved({ kind: 'unsupported', title: url.split('/').pop() || url, subtitle: detect.host, files: [] });
        } else if (detect.kind === 'hf') {
          const slug = url.replace(/^https?:\/\/huggingface\.co\//, '').replace(/\/$/, '');
          setResolved({
            kind: 'hf',
            title: slug || 'unknown/repo',
            subtitle: 'huggingface.co · main branch · 6 files',
            files: [
              { name: 'model.safetensors', size: 4_390_000_000, sel: true },
              { name: 'config.json', size: 712, sel: true },
              { name: 'tokenizer.json', size: 4_900_000, sel: true },
              { name: 'tokenizer_config.json', size: 38_000, sel: true },
              { name: 'special_tokens_map.json', size: 280, sel: true },
              { name: 'README.md', size: 12_000, sel: true },
            ],
          });
          setSelected({0:true,1:true,2:true,3:true,4:true,5:true});
        } else if (detect.kind === 'gh') {
          const slug = url.replace(/^https?:\/\/github\.com\//, '').replace(/\/$/, '');
          setResolved({
            kind: 'gh',
            title: slug || 'unknown/repo',
            subtitle: 'github.com · latest release · 4 assets',
            files: [
              { name: 'binary-x86_64-linux.tar.gz', size: 28_000_000, sel: true },
              { name: 'binary-aarch64-darwin.tar.gz', size: 24_000_000, sel: true },
              { name: 'Source code (zip)', size: 9_400_000, sel: false },
              { name: 'Source code (tar.gz)', size: 7_700_000, sel: false },
            ],
          });
          setSelected({0:true,1:true,2:false,3:false});
        }
      }
      setResolving(false);
    }, 600);
    return () => clearTimeout(t);
  }, [url, detect?.kind]);

  const total = useMemo(() => {
    if (!resolved) return 0;
    return resolved.files.reduce((s, f, i) => s + (selected[i] ? f.size : 0), 0);
  }, [resolved, selected]);
  const selCount = useMemo(() => resolved ? resolved.files.filter((_, i) => selected[i]).length : 0, [resolved, selected]);

  const submit = () => {
    if (!resolved || resolved.kind === 'unsupported') return;
    const files = resolved.files.filter((_, i) => selected[i]);
    if (!files.length) return;
    onSubmit({ kind: resolved.kind, title: resolved.title, subtitle: resolved.subtitle, dest, files });
    setUrl(''); setResolved(null); setSelected({});
  };

  const pillClass = !detect ? '' : detect.kind === 'hf' ? 'hf' : detect.kind === 'gh' ? 'gh' : detect.kind === 'unsupported' ? 'bad' : detect.kind === 'invalid' ? 'bad' : '';

  return (
    <div>
      <div className="newbar">
        {detect && (
          <span className={'src-pill ' + pillClass}>
            {detect.kind === 'hf' && <><Src kind="hf" size={13}/> Hugging Face</>}
            {detect.kind === 'gh' && <><Ic.github s={13}/> GitHub</>}
            {detect.kind === 'unsupported' && <><Ic.warn s={13}/> Unsupported</>}
            {detect.kind === 'invalid' && <><Ic.warn s={13}/> Invalid</>}
          </span>
        )}
        <input
          autoFocus
          placeholder="Paste a Hugging Face, GitHub, or any download URL…"
          value={url}
          onChange={e => setUrl(e.target.value)}
          spellCheck={false}
          onKeyDown={e => {
            if (e.key === 'Enter' && resolved && resolved.kind !== 'unsupported') submit();
          }}
        />
        {resolving && <span style={{fontSize:11, color:'var(--text-3)'}}>Resolving…</span>}
        {!url && (
          <span style={{display:'flex', gap:6, alignItems:'center', color:'var(--text-3)', fontSize:11.5, paddingRight: 6}}>
            <span className="kbd">⌘</span><span className="kbd">V</span> to paste
          </span>
        )}
        <button className="btn primary" onClick={submit} disabled={!resolved || resolved.kind === 'unsupported' || selCount === 0}>
          <Ic.download s={14}/> Download
        </button>
      </div>

      {/* Resolved preview */}
      {resolved && resolved.kind !== 'unsupported' && (
        <div className="detect">
          <div className="detect-head">
            <div className="ico"><Src kind={resolved.kind} size={20}/></div>
            <div style={{minWidth:0}}>
              <div className="ttl">{resolved.title}</div>
              <div className="meta">{resolved.subtitle}</div>
            </div>
            <div className="right">
              <button className="btn sm ghost" onClick={() => {
                const all = {}; resolved.files.forEach((_, i) => all[i] = true); setSelected(all);
              }}>Select all</button>
              <button className="btn sm ghost" onClick={() => {
                const none = {}; resolved.files.forEach((_, i) => none[i] = false); setSelected(none);
              }}>None</button>
            </div>
          </div>
          <div className="detect-files">
            {resolved.files.map((f, i) => (
              <div key={i} className={'file-row' + (selected[i] ? ' checked' : '')} onClick={() => setSelected(s => ({...s, [i]: !s[i]}))}>
                <div className="check">{selected[i] && <span style={{color:'var(--accent-ink)'}}><Ic.check s={11}/></span>}</div>
                <div className="name">
                  <span className="ext">{ext(f.name) || 'file'}</span>
                  <span className="label mono">{f.name}</span>
                </div>
                <div className="size mono">{fmtBytes(f.size)}</div>
                <div className="tag">{f.group || ''}</div>
              </div>
            ))}
          </div>
          <div className="detect-foot">
            <div className="summary">
              <b>{selCount}</b> of {resolved.files.length} selected · <b className="mono">{fmtBytes(total)}</b>
            </div>
            <div className="right">
              <span className="dest-chip" title="Click to change destination">
                <Ic.folder s={13}/> <span className="mono" style={{maxWidth:200, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{dest}</span>
              </span>
              <button className="btn primary" onClick={submit} disabled={selCount === 0}>
                <Ic.download s={14}/> Start download
              </button>
            </div>
          </div>
        </div>
      )}

      {resolved && resolved.kind === 'unsupported' && (
        <div className="unsupported">
          <div className="ico"><Ic.warn s={18}/></div>
          <div style={{flex:1}}>
            <div className="ttl">Unsupported source</div>
            <div className="desc">
              osmDownloads can fetch files from this URL, but multi-file resolution and verification are only available for Hugging Face and GitHub. The download will be treated as a single file.
            </div>
            <div className="url">{url}</div>
          </div>
          <button className="btn primary" onClick={() => onSubmit({
            kind: 'web', title: url.split('/').pop() || url, subtitle: detect?.host || '',
            dest, files: [{ name: url.split('/').pop() || 'download', size: 240_000_000, downloaded: 0, status: 'queued' }],
          })}>
            <Ic.download s={14}/> Download anyway
          </button>
        </div>
      )}
    </div>
  );
}

// =========================================================================
// Job card
// =========================================================================
function JobCard({ job, onAction, expanded, onToggleExpand }) {
  const totalSize = job.files.reduce((s, f) => s + f.size, 0);
  const downloaded = job.files.reduce((s, f) => s + f.downloaded, 0);
  const pct = totalSize ? (downloaded / totalSize) * 100 : 0;
  const doneCount = job.files.filter(f => f.status === 'done').length;
  const eta = job.speed > 0 ? (totalSize - downloaded) / job.speed : null;

  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef(null);
  useEffect(() => {
    if (!menuOpen) return;
    const close = (e) => { if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false); };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [menuOpen]);

  return (
    <div className={'job' + (expanded ? ' expanded' : '')}>
      <div className="job-head" onClick={onToggleExpand}>
        <div className={'src-ico ' + (job.kind === 'hf' ? 'hf' : '')}>
          <Src kind={job.kind} size={15}/>
        </div>
        <div className="job-mid">
          <div className="ttl">
            <span style={{overflow:'hidden', textOverflow:'ellipsis'}}>{job.title}</span>
            <span className={'status-pill ' + job.status}>
              {job.status === 'downloading' && <span className="pulse"/>}
              {job.status}
            </span>
          </div>
          <div className="meta">
            <span>{doneCount}/{job.files.length} files</span>
            <span className="dot"/>
            <span className="mono">{fmtBytes(downloaded)} / {fmtBytes(totalSize)}</span>
            {job.status === 'downloading' && <>
              <span className="dot"/>
              <span className="mono">{fmtSpeed(job.speed)}</span>
              <span className="dot"/>
              <span>ETA {fmtEta(eta)}</span>
            </>}
            {job.status === 'paused' && <>
              <span className="dot"/>
              <span>Paused</span>
            </>}
            {job.status === 'queued' && <>
              <span className="dot"/>
              <span>Waiting in queue</span>
            </>}
          </div>
        </div>
        <div className="job-actions" onClick={e => e.stopPropagation()}>
          {job.status === 'downloading' && (
            <button className="iconbtn" title="Pause" onClick={() => onAction('pause', job)}><Ic.pause s={13}/></button>
          )}
          {(job.status === 'paused' || job.status === 'queued') && (
            <button className="iconbtn" title="Resume" onClick={() => onAction('resume', job)}><Ic.play s={13}/></button>
          )}
          <button className="iconbtn" title="Stop & remove" onClick={() => onAction('stop', job)}><Ic.x s={14}/></button>
          <div style={{position:'relative'}}>
            <button className="iconbtn" title="More" onClick={() => setMenuOpen(v => !v)}><Ic.more s={16}/></button>
            {menuOpen && (
              <div className="menu" ref={menuRef} style={{right:0, top:34}}>
                <div className="menu-item" onClick={() => { onAction('reveal', job); setMenuOpen(false); }}>
                  <Ic.folderOpen s={14}/> Reveal in Finder
                  <span className="k">⌘R</span>
                </div>
                <div className="menu-item" onClick={() => { onAction('copyUrl', job); setMenuOpen(false); }}>
                  <Ic.link s={14}/> Copy source URL
                </div>
                <div className="menu-item" onClick={() => { onToggleExpand(); setMenuOpen(false); }}>
                  <Ic.chevronDown s={14}/> {expanded ? 'Collapse files' : 'Expand files'}
                </div>
                <div className="menu-sep"/>
                <div className="menu-item danger" onClick={() => { onAction('stop', job); setMenuOpen(false); }}>
                  <Ic.stop s={13}/> Stop & remove
                </div>
              </div>
            )}
          </div>
          <button className="iconbtn" title={expanded ? 'Collapse' : 'Expand'} style={{transition:'transform .15s', transform: expanded ? 'rotate(90deg)' : 'none'}}>
            <Ic.chevronRight s={14}/>
          </button>
        </div>
      </div>
      <div className="prog-wrap">
        <div className={'prog ' + (job.status === 'paused' ? 'paused' : '') + (job.status === 'failed' ? ' failed' : '')}>
          <i style={{width: pct + '%'}} className={job.status === 'queued' ? 'indeterminate' : ''}/>
        </div>
        <div className="prog-pct mono">{pct.toFixed(1)}%</div>
      </div>

      {expanded && (
        <div className="job-files">
          {job.files.map((f, i) => {
            const fpct = f.size ? (f.downloaded / f.size) * 100 : 0;
            return (
              <div key={i} className={'job-file ' + f.status}>
                <span className="ext" style={{
                  fontSize:9.5, fontWeight:600, padding:'1.5px 4px', borderRadius:3,
                  background: 'var(--surface-3)', color: 'var(--text-3)', textTransform:'uppercase'
                }}>{ext(f.name).slice(0,4) || '·'}</span>
                <div className="nm">
                  <span className="label mono" title={f.name}>{f.name}</span>
                </div>
                <div className="pf"><i style={{width: fpct + '%'}}/></div>
                <div className="sz mono">{fmtBytes(f.downloaded)}/{fmtBytes(f.size)}</div>
                <div className="st">{f.status === 'done' ? '✓ done' : f.status === 'active' ? Math.round(fpct) + '%' : f.status}</div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// =========================================================================
// History row
// =========================================================================
function HistoryRow({ h, onAction }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef(null);
  useEffect(() => {
    if (!menuOpen) return;
    const close = (e) => { if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false); };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [menuOpen]);

  return (
    <div className="job">
      <div className="job-head" style={{cursor:'default'}}>
        <div className={'src-ico ' + (h.kind === 'hf' ? 'hf' : '')}>
          <Src kind={h.kind} size={15}/>
        </div>
        <div className="job-mid">
          <div className="ttl">
            <span style={{overflow:'hidden', textOverflow:'ellipsis'}}>{h.title}</span>
            <span className={'status-pill ' + h.status}>{h.status}</span>
          </div>
          <div className="meta">
            <span>{h.subtitle}</span>
            <span className="dot"/>
            <span><Ic.clock s={11}/> {fmtTimeAgo(h.finished)}</span>
            <span className="dot"/>
            <span className="mono">{h.dest}</span>
          </div>
          {h.error && <div style={{fontSize:11.5, color:'var(--danger)', marginTop:5}}>{h.error}</div>}
        </div>
        <div className="job-actions">
          {h.status === 'completed' && (
            <button className="btn sm ghost" onClick={() => onAction('reveal', h)}>
              <Ic.folderOpen s={13}/> Reveal
            </button>
          )}
          {(h.status === 'failed' || h.status === 'cancelled') && (
            <button className="btn sm" onClick={() => onAction('retry', h)}>
              <Ic.refresh s={13}/> Retry
            </button>
          )}
          <div style={{position:'relative'}}>
            <button className="iconbtn" title="More" onClick={() => setMenuOpen(v => !v)}><Ic.more s={16}/></button>
            {menuOpen && (
              <div className="menu" ref={menuRef} style={{right:0, top:34}}>
                <div className="menu-item" onClick={() => { onAction('reveal', h); setMenuOpen(false); }}>
                  <Ic.folderOpen s={14}/> Reveal in Finder
                </div>
                <div className="menu-item" onClick={() => { onAction('copyUrl', h); setMenuOpen(false); }}>
                  <Ic.link s={14}/> Copy source URL
                </div>
                {(h.status === 'failed' || h.status === 'cancelled') && (
                  <div className="menu-item" onClick={() => { onAction('retry', h); setMenuOpen(false); }}>
                    <Ic.refresh s={14}/> Retry download
                  </div>
                )}
                <div className="menu-sep"/>
                <div className="menu-item danger" onClick={() => { onAction('remove', h); setMenuOpen(false); }}>
                  <Ic.trash s={13}/> Remove from history
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// =========================================================================
// Theme toggle
// =========================================================================
function ThemeToggle({ theme, setTheme }) {
  return (
    <div className="theme-toggle">
      <button className={theme === 'light' ? 'active' : ''} onClick={() => setTheme('light')} title="Light"><Ic.sun s={13}/></button>
      <button className={theme === 'dark' ? 'active' : ''} onClick={() => setTheme('dark')} title="Dark"><Ic.moon s={13}/></button>
    </div>
  );
}

// =========================================================================
// App
// =========================================================================
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "density": "comfortable",
  "startView": "active"
}/*EDITMODE-END*/;

function App() {
  const tweaks = useTweaks ? useTweaks(TWEAK_DEFAULTS) : [TWEAK_DEFAULTS, () => {}];
  const [tw, setTw] = tweaks;

  const [theme, setThemeState] = useState(tw.theme || 'light');
  const setTheme = (t) => { setThemeState(t); setTw({ theme: t }); };
  useEffect(() => { document.documentElement.dataset.theme = theme; }, [theme]);

  const [view, setView] = useState(tw.startView || 'active');
  const [jobs, setJobs] = useState(SEED_JOBS);
  const [history, setHistory] = useState(SEED_HISTORY);
  const [expanded, setExpanded] = useState({ j1: true });
  const [toast, setToast] = useState(null);
  const [historyFilter, setHistoryFilter] = useState('all');
  const [historyQuery, setHistoryQuery] = useState('');

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(t => t === msg ? null : t), 2400);
  };

  // Simulate downloads
  useEffect(() => {
    const t = setInterval(() => {
      setJobs(prev => prev.map(job => {
        if (job.status !== 'downloading') return job;
        // distribute speed across active files
        const activeFiles = job.files.filter(f => f.status === 'active');
        if (!activeFiles.length) {
          // promote a queued file
          const next = job.files.findIndex(f => f.status === 'queued');
          if (next === -1) {
            // job complete
            const completed = { ...job, status: 'completed', speed: 0 };
            setHistory(h => [{
              id: 'h_' + job.id, kind: job.kind, status: 'completed',
              title: job.title, subtitle: job.files.length + ' files · ' + fmtBytes(job.files.reduce((s,f)=>s+f.size,0)),
              dest: job.dest, finished: Date.now(),
              duration: Math.round((Date.now() - job.started)/1000),
              totalSize: job.files.reduce((s,f)=>s+f.size,0),
            }, ...h]);
            showToast('✓ ' + job.title + ' downloaded');
            return null; // remove from active
          }
          const files = job.files.slice();
          files[next] = { ...files[next], status: 'active' };
          return { ...job, files };
        }
        const perFile = job.speed / activeFiles.length;
        const files = job.files.map(f => {
          if (f.status !== 'active') return f;
          const newDl = Math.min(f.size, f.downloaded + perFile);
          if (newDl >= f.size) return { ...f, downloaded: f.size, status: 'done' };
          return { ...f, downloaded: newDl };
        });
        // jitter speed
        const newSpeed = Math.max(20_000_000, job.speed + (Math.random() - 0.5) * 12_000_000);
        return { ...job, files, speed: newSpeed };
      }).filter(Boolean));
    }, 1000);
    return () => clearInterval(t);
  }, []);

  const handleNewDownload = (req) => {
    const id = 'j_' + Date.now();
    const newJob = {
      id, kind: req.kind, title: req.title, subtitle: req.subtitle,
      dest: req.dest, started: Date.now(),
      status: 'downloading', speed: 75_000_000,
      files: req.files.map(f => ({ ...f, downloaded: 0, status: 'queued' })),
    };
    // promote first 3 to active
    newJob.files.slice(0, 3).forEach((_, i) => newJob.files[i].status = 'active');
    setJobs(j => [newJob, ...j]);
    setExpanded(e => ({ ...e, [id]: true }));
    setView('active');
    showToast('Started downloading ' + req.title);
  };

  const handleJobAction = (act, job) => {
    if (act === 'pause') {
      setJobs(jobs => jobs.map(j => j.id === job.id ? {
        ...j, status: 'paused', speed: 0,
        files: j.files.map(f => f.status === 'active' ? { ...f, status: 'paused' } : f),
      } : j));
      showToast('Paused ' + job.title);
    } else if (act === 'resume') {
      setJobs(jobs => jobs.map(j => j.id === job.id ? {
        ...j, status: 'downloading', speed: 75_000_000,
        files: j.files.map(f => f.status === 'paused' ? { ...f, status: 'active' } : f),
      } : j));
      showToast('Resumed ' + job.title);
    } else if (act === 'stop') {
      setJobs(jobs => jobs.filter(j => j.id !== job.id));
      setHistory(h => [{
        id: 'h_' + job.id, kind: job.kind, status: 'cancelled',
        title: job.title, subtitle: 'cancelled at ' + Math.round(job.files.reduce((s,f)=>s+f.downloaded,0) / job.files.reduce((s,f)=>s+f.size,0) * 100) + '%',
        dest: job.dest, finished: Date.now(),
        duration: Math.round((Date.now() - job.started)/1000),
        totalSize: job.files.reduce((s,f)=>s+f.size,0),
      }, ...h]);
      showToast('Stopped ' + job.title);
    } else if (act === 'reveal') {
      showToast('Revealed ' + job.dest);
    } else if (act === 'copyUrl') {
      showToast('Source URL copied to clipboard');
    }
  };

  const handleHistoryAction = (act, h) => {
    if (act === 'reveal') showToast('Revealed ' + h.dest);
    else if (act === 'remove') { setHistory(hs => hs.filter(x => x.id !== h.id)); showToast('Removed from history'); }
    else if (act === 'retry') { showToast('Retrying ' + h.title); setHistory(hs => hs.filter(x => x.id !== h.id)); }
    else if (act === 'copyUrl') showToast('Source URL copied');
  };

  // Derived metrics
  const overall = useMemo(() => {
    const active = jobs.filter(j => j.status === 'downloading');
    const totalSize = jobs.reduce((s, j) => s + j.files.reduce((a, f) => a + f.size, 0), 0);
    const downloaded = jobs.reduce((s, j) => s + j.files.reduce((a, f) => a + f.downloaded, 0), 0);
    const speed = active.reduce((s, j) => s + j.speed, 0);
    const eta = speed > 0 ? (totalSize - downloaded) / speed : null;
    return { totalSize, downloaded, speed, eta, active: active.length };
  }, [jobs]);

  const counts = {
    active: jobs.length,
    downloading: jobs.filter(j => j.status === 'downloading').length,
    paused: jobs.filter(j => j.status === 'paused').length,
    queued: jobs.filter(j => j.status === 'queued').length,
    history: history.length,
    completed: history.filter(h => h.status === 'completed').length,
    failed: history.filter(h => h.status === 'failed' || h.status === 'cancelled').length,
  };

  const filteredHistory = useMemo(() => {
    let h = history;
    if (historyFilter === 'completed') h = h.filter(x => x.status === 'completed');
    else if (historyFilter === 'failed') h = h.filter(x => x.status === 'failed' || x.status === 'cancelled');
    if (historyQuery) {
      const q = historyQuery.toLowerCase();
      h = h.filter(x => x.title.toLowerCase().includes(q) || x.subtitle.toLowerCase().includes(q));
    }
    return h;
  }, [history, historyFilter, historyQuery]);

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <img src={theme === 'dark' ? 'assets/logo-dark.png' : 'assets/logo-light.png'} alt="osmDownloads"/>
          <div className="name">osm<em>Downloads</em></div>
        </div>

        <div className={'nav-item ' + (view === 'active' ? 'active' : '') + (counts.downloading ? ' dot' : '')} onClick={() => setView('active')}>
          <Ic.download s={14}/> Active
          <span className="count">{counts.active}</span>
        </div>
        <div className={'nav-item ' + (view === 'history' ? 'active' : '')} onClick={() => setView('history')}>
          <Ic.clock s={14}/> History
          <span className="count">{counts.history}</span>
        </div>
        <div className={'nav-item ' + (view === 'queue' ? 'active' : '')} onClick={() => setView('queue')}>
          <Ic.inbox s={14}/> Queue
          <span className="count">{counts.queued}</span>
        </div>

        <div className="nav-section-title">Sources</div>
        <div className="nav-item">
          <Src kind="hf" size={14}/> Hugging Face
          <span className="count">{[...jobs, ...history].filter(x => x.kind === 'hf').length}</span>
        </div>
        <div className="nav-item">
          <Ic.github s={14}/> GitHub
          <span className="count">{[...jobs, ...history].filter(x => x.kind === 'gh').length}</span>
        </div>
        <div className="nav-item">
          <Ic.globe s={14}/> Other URLs
          <span className="count">{[...jobs, ...history].filter(x => x.kind !== 'hf' && x.kind !== 'gh').length}</span>
        </div>

        <div className="sidebar-footer">
          <div className="disk-meter">
            <div className="row"><span>Disk · ~/Models</span><span className="mono">412 GB free</span></div>
            <div className="bar"><i style={{width:'58%'}}/></div>
          </div>
          <div className="nav-item">
            <Ic.settings s={14}/> Settings
          </div>
        </div>
      </aside>

      <main className="main">
        <div className="titlebar">
          <h1>{view === 'active' ? 'Downloads' : view === 'history' ? 'History' : 'Queue'}</h1>
          <span className="sub">
            {view === 'active' && (counts.downloading ? `${counts.downloading} active · ${fmtSpeed(overall.speed)}` : 'Idle')}
            {view === 'history' && `${history.length} jobs`}
            {view === 'queue' && `${counts.queued} waiting`}
          </span>
          <div className="spacer"/>
          <div className="actions">
            <ThemeToggle theme={theme} setTheme={setTheme}/>
            <button className="iconbtn" title="Settings"><Ic.settings s={15}/></button>
          </div>
        </div>

        <div className="content">
          {view === 'active' && (
            <>
              <NewDownloadBar onSubmit={handleNewDownload} theme={theme}/>

              {/* Overall progress */}
              {counts.downloading > 0 && (
                <>
                  <div className="section-h" style={{marginTop:24}}>
                    <h2>Overall progress</h2>
                  </div>
                  <div className="overall">
                    <div className="col">
                      <span className="lbl">Active</span>
                      <span className="num mono">{counts.downloading}</span>
                    </div>
                    <div className="col">
                      <span className="lbl">Speed</span>
                      <span className="num mono">{fmtSpeed(overall.speed)}</span>
                    </div>
                    <div className="col">
                      <span className="lbl">ETA</span>
                      <span className="num mono">{fmtEta(overall.eta)}</span>
                    </div>
                    <div className="bar-wrap">
                      <div className="top">
                        <span className="mono">{fmtBytes(overall.downloaded)} of {fmtBytes(overall.totalSize)}</span>
                        <span className="mono">{(overall.totalSize ? overall.downloaded/overall.totalSize*100 : 0).toFixed(1)}%</span>
                      </div>
                      <div className="bar"><i style={{width: (overall.totalSize ? overall.downloaded/overall.totalSize*100 : 0) + '%'}}/></div>
                    </div>
                  </div>
                </>
              )}

              <div className="section-h">
                <h2>Active downloads</h2>
                <span className="count">{counts.active}</span>
                <div className="right">
                  <button className="btn sm ghost" onClick={() => {
                    setJobs(js => js.map(j => j.status === 'downloading' ? { ...j, status: 'paused', speed: 0, files: j.files.map(f => f.status === 'active' ? {...f, status:'paused'} : f) } : j));
                    showToast('Paused all');
                  }}><Ic.pause s={11}/> Pause all</button>
                  <button className="btn sm ghost" onClick={() => {
                    setJobs(js => js.map(j => (j.status === 'paused' || j.status === 'queued') ? { ...j, status: 'downloading', speed: 75_000_000, files: j.files.map(f => f.status === 'paused' ? {...f, status:'active'} : f) } : j));
                    showToast('Resumed all');
                  }}><Ic.play s={11}/> Resume all</button>
                  <button className="btn sm danger" onClick={() => {
                    if (jobs.length === 0) return;
                    jobs.forEach(j => handleJobAction('stop', j));
                  }}><Ic.x s={12}/> Clear all</button>
                </div>
              </div>

              {jobs.length === 0 && (
                <div className="empty">
                  <div className="ico"><Ic.download s={20}/></div>
                  <div className="h">No active downloads</div>
                  <p>Paste a URL above to get started. osmDownloads detects Hugging Face repos, GitHub releases, and direct URLs.</p>
                </div>
              )}

              {jobs.map(j => (
                <JobCard
                  key={j.id} job={j}
                  onAction={handleJobAction}
                  expanded={!!expanded[j.id]}
                  onToggleExpand={() => setExpanded(e => ({ ...e, [j.id]: !e[j.id] }))}
                />
              ))}
            </>
          )}

          {view === 'history' && (
            <>
              <div className="list-toolbar">
                <span className={'seg ' + (historyFilter === 'all' ? 'active' : '')} onClick={() => setHistoryFilter('all')}>
                  All <span className="n">{history.length}</span>
                </span>
                <span className={'seg ' + (historyFilter === 'completed' ? 'active' : '')} onClick={() => setHistoryFilter('completed')}>
                  Completed <span className="n">{counts.completed}</span>
                </span>
                <span className={'seg ' + (historyFilter === 'failed' ? 'active' : '')} onClick={() => setHistoryFilter('failed')}>
                  Failed / Cancelled <span className="n">{counts.failed}</span>
                </span>
                <div className="spacer"/>
                <div style={{display:'flex', alignItems:'center', gap:6, padding:'0 6px', color:'var(--text-3)'}}>
                  <Ic.search s={13}/>
                  <input
                    placeholder="Search history…"
                    value={historyQuery}
                    onChange={e => setHistoryQuery(e.target.value)}
                    style={{background:'transparent', border:0, outline:0, color:'var(--text)', fontSize:12.5, width:170}}
                  />
                </div>
                <button className="btn sm ghost" onClick={() => {
                  setHistory(hs => hs.filter(h => h.status !== 'completed'));
                  showToast('Cleared completed');
                }}>Clear completed</button>
                <button className="btn sm ghost" onClick={() => {
                  setHistory(hs => hs.filter(h => h.status === 'completed'));
                  showToast('Cleared failed & cancelled');
                }}>Clear failed</button>
                <button className="btn sm danger" onClick={() => {
                  setHistory([]);
                  showToast('Cleared all history');
                }}><Ic.trash s={11}/> Clear all</button>
              </div>

              {filteredHistory.length === 0 && (
                <div className="empty">
                  <div className="ico"><Ic.clock s={20}/></div>
                  <div className="h">No history yet</div>
                  <p>Completed and failed downloads will appear here.</p>
                </div>
              )}

              {filteredHistory.map(h => (
                <HistoryRow key={h.id} h={h} onAction={handleHistoryAction}/>
              ))}
            </>
          )}

          {view === 'queue' && (
            <>
              <div className="section-h">
                <h2>Waiting in queue</h2>
                <span className="count">{counts.queued}</span>
              </div>
              {jobs.filter(j => j.status === 'queued').length === 0 && (
                <div className="empty">
                  <div className="ico"><Ic.inbox s={20}/></div>
                  <div className="h">Queue is empty</div>
                  <p>Jobs waiting their turn will appear here. osmDownloads runs up to 2 downloads in parallel by default.</p>
                </div>
              )}
              {jobs.filter(j => j.status === 'queued').map(j => (
                <JobCard
                  key={j.id} job={j}
                  onAction={handleJobAction}
                  expanded={!!expanded[j.id]}
                  onToggleExpand={() => setExpanded(e => ({ ...e, [j.id]: !e[j.id] }))}
                />
              ))}
            </>
          )}
        </div>
      </main>

      {toast && (
        <div className="toast-wrap">
          <div className="toast">{toast}</div>
        </div>
      )}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
