import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Channel, invoke } from '@tauri-apps/api/core';
import type { Snapshot, StateEvent, AppError, EngineHealth } from './contracts';
import { applyEvent, acceptSnapshot } from './state';
import { strings, type Language } from './strings';
import './style.css';

function App() {
  const [language, setLanguage] = useState<Language>('en');
  const [page, setPage] = useState<'environments' | 'settings'>('environments');
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [health, setHealth] = useState<EngineHealth | null>(null);
  const [clock, setClock] = useState(Date.now());
  const healthFresh = !!health?.fresh && clock - health.observation.observed_unix_ms < 15000;
  const [error, setError] = useState<AppError | null>(null);
  const [search, setSearch] = useState(''); const [name, setName] = useState('');
  const [theme, setTheme] = useState('system'); const t = strings[language];
  const refresh = async () => { try { const incoming = await invoke<Snapshot>('get_snapshot'); setSnapshot(current => acceptSnapshot(current, incoming)); setError(null); } catch (error) { const value = error as AppError; setError({ code: value?.code ?? 'BACKEND_UNAVAILABLE', diagnostic_id: value?.diagnostic_id ?? '' }); } };
  useEffect(() => { let disposed = false; let subscriptionId: string | undefined;
    let initialized = false; const pending: StateEvent[] = [];
    const channel = new Channel<StateEvent>(event => {
      if (!initialized) { if (pending.length < 1024) pending.push(event); return; }
      setSnapshot(current => current ? applyEvent(current, event) : current);
    });
    void invoke<{ id: string; snapshot: Snapshot }>('subscribe_state', { channel }).then(value => {
      if (disposed) { void invoke('unsubscribe_state', { request: { subscription_id: value.id } }).catch(() => {}); return; }
      subscriptionId = value.id; initialized = true;
      setSnapshot(current => pending.reduce(applyEvent, acceptSnapshot(current, value.snapshot)));
    }).catch(() => void refresh());
    return () => { disposed = true; if (subscriptionId) void invoke('unsubscribe_state', { request: { subscription_id: subscriptionId } }).catch(() => {}); };
  }, []);
  useEffect(() => { document.documentElement.lang = language; document.documentElement.dataset.theme = theme; }, [language, theme]);
  useEffect(() => {
    let disposed = false; let inflight = false;
    const observe = async () => {
      if (inflight) return; inflight = true;
      try { const value = await invoke<EngineHealth>('get_engine_health'); if (!disposed) setHealth(old => old && (old.generation > value.generation || (old.generation === value.generation && old.sequence > value.sequence)) ? old : value); }
      catch { if (!disposed) setHealth(null); } finally { inflight = false; }
    };
    const timer = window.setInterval(() => void observe(), 5000);
    const ageTimer = window.setInterval(() => setClock(Date.now()), 1000);
    const resume = () => { setHealth(null); void observe(); }; window.addEventListener('focus', resume); document.addEventListener('visibilitychange', resume);
    void observe(); return () => { disposed = true; window.clearInterval(timer); window.clearInterval(ageTimer); window.removeEventListener('focus', resume); document.removeEventListener('visibilitychange', resume); };
  }, []);
  const create = async (event: React.FormEvent) => { event.preventDefault(); try { await invoke('create_draft', { request: { display_name: name } }); setName(''); await refresh(); } catch (error) { setError(error as AppError); } };
  return <div className="shell"><aside><div className="brand"><span className="brandMark" aria-hidden>SR</span>SecureRun</div><nav aria-label={language === 'en' ? 'Main navigation' : 'Главная навигация'}>{(['environments', 'settings'] as const).map(item => <button key={item} aria-current={page === item ? 'page' : undefined} onClick={() => setPage(item)}>{t[item]}</button>)}</nav><span className="version">SecureRun · 0.3</span></aside><main>
    {snapshot?.mode === 'FOUNDATION_TEST_FIXTURE' && <div className="fixture" role="status">{t.fixture}</div>}
    <header><div><h1>{page === 'environments' ? t.title : t.settings}</h1><p>{t.subtitle}</p></div><button onClick={() => void refresh()}>{t.refresh}</button></header>
    <section className="notice" aria-labelledby="engine-heading"><span className="statusDot" aria-hidden/><div><h2 id="engine-heading">{t.engine}</h2><p>{t.unavailable}</p></div><span className="badge">{t.readonly}</span></section>
    <section className="engineHealth" aria-labelledby="health-heading"><h2 id="health-heading">{t.health}</h2>
      <dl><dt>{t.trust}</dt><dd>{health?.observation.trust ?? t.unknown}</dd><dt>{t.context}</dt><dd>{health?.observation.manager_context ?? t.unknown} / {health?.observation.bridge_context ?? t.unknown}</dd><dt>{t.service}</dt><dd>{health?.observation.service_running ? t.running : t.unknown}</dd><dt>{t.driver}</dt><dd>{health?.observation.driver_running ? t.running : t.unknown}</dd><dt>{t.version}</dt><dd>{health?.observation.core_version ?? t.unknown}</dd><dt>{t.freshness}</dt><dd>{healthFresh ? t.fresh : t.unknown}</dd></dl>
      <p role="status">{health?.observation.reason ?? t.observing}</p><p>{t.serviceIdentity}: {health?.observation.service_identity_complete ? t.verified : t.unknown}</p><p>{t.phaseGuard}</p>
      {health?.observation.capabilities.map(item => <p key={item.name}>{item.name}: {item.availability} · {item.reason}</p>)}
      <h3>{t.existingBoxes}</h3><p>{t.unowned}</p>
      {health?.observation.boxes.map(box => <article key={box.name}><h3>{box.name}</h3><p>{t.activity}: {healthFresh ? box.activity : t.unknown} · {healthFresh && box.complete ? t.complete : t.incomplete}</p><p>{box.reason}</p><details><summary>{t.observationDetails}</summary><p>{t.root}: {box.root.path ?? t.unknown} · {box.root.reason} ({t.callerScope})</p><p>{t.fingerprint}: <code>{box.configuration_fingerprint}</code></p><ul>{box.processes.map(p => <li key={`${p.pid}:${p.creation_time}`}>PID {p.pid} · {t.session} {p.session} · {p.creation_time}</li>)}</ul><table><thead><tr><th>{t.directive}</th><th>{t.raw}</th><th>{t.effective}</th></tr></thead><tbody>{box.configuration.map(v => <tr key={v.key}><td>{v.key}</td><td>{v.raw.join(' · ')}</td><td>{v.effective.join(' · ')}</td></tr>)}</tbody></table><p>{t.notOracle}</p></details></article>)}
    </section>
    {error && <section className="error" role="alert"><strong>{t.error}</strong><p>{t.next}</p><details><summary>{t.diagnosticId}</summary><code>{error.code} {error.diagnostic_id}</code></details></section>}
    {page === 'environments' ? <><label className="search">{t.search}<input value={search} onChange={event => setSearch(event.target.value)} type="search"/></label>{snapshot?.mutations_available && <form onSubmit={create}><label>{t.name}<input value={name} onChange={event => setName(event.target.value)} maxLength={80} required/></label><button type="submit">{t.add}</button></form>}
      {snapshot?.environments.length ? <div className="cards">{snapshot.environments.filter(item => item.display_name.toLocaleLowerCase().includes(search.toLocaleLowerCase())).map(item => <article key={item.id}><h2>{item.display_name}</h2><dl><dt>{t.activity}</dt><dd>{item.activity === 'UNKNOWN' ? t.unknown : item.activity}</dd><dt>{t.eligibility}</dt><dd>{item.eligibility === 'UNVERIFIED' ? t.unverified : t.blocked}</dd></dl></article>)}</div> : <section className="empty"><span aria-hidden>□</span><h2>{t.empty}</h2><p>{t.emptyDetail}</p></section>}</> : <section className="settings"><label>{t.language}<select value={language} onChange={event => setLanguage(event.target.value as Language)}><option value="en">English</option><option value="ru">Русский</option></select></label><label>{t.appearance}<select value={theme} onChange={event => setTheme(event.target.value)}><option value="system">{t.system}</option><option value="light">{t.light}</option><option value="dark">{t.dark}</option></select></label><div><h2>{t.diagnostics}</h2><p>{t.diagnosticsDetail}</p></div></section>}
  </main></div>;
}
const query = new URLSearchParams(location.search);
if (query.has('acl-probe') || query.has('foundation-ci')) {
  if (import.meta.env.VITE_FOUNDATION_CI === '1') void import('./selftest').then(module => module.run(query.has('acl-probe')));
}
createRoot(document.getElementById('root')!).render(<App/>);
