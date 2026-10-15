import React, { useEffect, useRef, useState } from 'react';
import { invoke } from './backend';
import type { Language } from './strings';
import {escaped,statusName,productText} from './product';
import {ErrorView} from './error';
type Env = { id: string; revision: number; display_name: string };
type Process = { pid: number; creation_time: string; session: number };
type Receipt = { operation_id: string; state: string; reason: string };
type Reply = { diagnostic_id?:string;reason: string; applications: { id: string; environment_id: string; revision: number; display_name: string; boxed: boolean; available: boolean; unavailable_reason: string | null }[]; environments: { environment_id: string; activity: string; complete: boolean; launch_eligible: boolean; reason: string; processes: Process[] }[]; receipts: Receipt[] };
export function Controls({ language, environmentId }: { language: Language;environmentId?:string }) {
  const ru = language === 'ru';const product=productText[language]; const [reply, setReply] = useState<Reply | null>(null); const [envs, setEnvs] = useState<Env[]>([]);
  const [environment, setEnvironment] = useState(environmentId??''); const [name, setName] = useState(''); const [args, setArgs] = useState('[]');
  const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [selection, setSelection] = useState<{ id: string; label: string; operation: string; issued: number } | null>(null);
  const [cwdSelection, setCwdSelection] = useState<{ id: string; label: string } | null>(null);
  const [lastOperation, setLastOperation] = useState<string | null>(null); const sequence = useRef(0); const busyRef = useRef(false); const updated = useRef(0); const [fresh, setFresh] = useState(false);
  async function request(request: object) {
    const ticket = ++sequence.current;
    const incoming = await invoke<Reply>('control_request', { request });
    if (ticket === sequence.current) { setReply(incoming); updated.current = Date.now(); setFresh(true); setError(incoming.reason === 'OBSERVED' ? '' : incoming.reason); }
  }
  async function refresh() {
    const started = sequence.current;
    try { const value = await invoke<{ environments: Env[] }>('policy_request', { request: { action: 'LIST' } }); if (busyRef.current || started !== sequence.current) return; setEnvs(value.environments.filter(e=>!environmentId||e.id===environmentId)); await request({ action: 'LIST' }); }
    catch { setError('BACKEND_UNAVAILABLE'); setFresh(false); }
  }
  useEffect(() => { let inflight = false; let disposed = false;
    const run = async () => { if (inflight || disposed) return; inflight = true; try { await refresh(); } finally { inflight = false; } };
    void run(); const timer = window.setInterval(() => { if (Date.now() - updated.current >= 15000) setFresh(false); if (!busyRef.current) void run(); }, 2000);
    const resume = () => { setFresh(false); if (!busyRef.current) { ++sequence.current; void run(); } }; window.addEventListener('focus', resume); document.addEventListener('visibilitychange', resume);
    return () => { disposed = true; ++sequence.current; window.clearInterval(timer); window.removeEventListener('focus', resume); document.removeEventListener('visibilitychange', resume); };
  }, []);
  async function action(value: Record<string, unknown>) {
    busyRef.current = true; setBusy(true); const operation = crypto.randomUUID(); setLastOperation(operation);
    try { await request({ ...value, operation_id: operation }); } catch { setError('OUTCOME_UNKNOWN'); setFresh(false); } finally { busyRef.current = false; setBusy(false); }
  }
  async function reconcile(operation: string) {
    busyRef.current = true; setBusy(true);
    try { await request({ action: 'RECONCILE', operation_id: operation }); }
    catch { setError('RECONCILIATION_NOT_CONFIRMED'); setFresh(false); }
    finally { busyRef.current = false; setBusy(false); }
  }
  async function pick(directory = false) {
    const e = envs.find(e => e.id === environment); if (!e) return;
    busyRef.current = true; setBusy(true); const operation = directory && selection ? selection.operation : crypto.randomUUID();
    try { const s = await invoke<{ selection_id: string; display_name: string }>('select_policy_path', { request: { operation_id: operation, environment_id: e.id, expected_revision: e.revision, directory,language } }); if (directory) setCwdSelection({ id: s.selection_id, label: s.display_name }); else { setCwdSelection(null); setSelection({ id: s.selection_id, label: s.display_name, operation, issued: Date.now() }); } }
    catch { setError('SELECTION_UNAVAILABLE'); } finally { busyRef.current = false; setBusy(false); }
  }
  async function register(event: React.FormEvent) {
    event.preventDefault(); const e = envs.find(e => e.id === environment); if (!e || !selection) return; busyRef.current = true; setBusy(true);
    try { const argumentsValue: unknown = JSON.parse(args); if (!Array.isArray(argumentsValue) || !argumentsValue.every(a => typeof a === 'string') || Date.now() - selection.issued >= 60000) throw new Error();
      setLastOperation(selection.operation); await request({ action: 'REGISTER', environment_id: e.id, expected_revision: e.revision, operation_id: selection.operation, display_name: name, executable_selection: selection.id, arguments: argumentsValue, directory_selection: cwdSelection?.id ?? null }); setSelection(null); setCwdSelection(null);
    } catch { setError('REGISTRATION_NOT_CONFIRMED'); } finally { busyRef.current = false; setBusy(false); }
  }
  let argumentPreview:string[]|null=null;try{const value:unknown=JSON.parse(args);if(Array.isArray(value)&&value.every(v=>typeof v==='string'))argumentPreview=value;}catch{/* Input is shown without execution. */}
  return <section className="engineHealth"><h2>{ru ? 'Приложения и процессы' : 'Applications and processes'}</h2>
    <p>{ru ? 'Выберите EXE на хосте. Аргументы — JSON-массив строк; командная строка не предназначена для секретов. По умолчанию рабочая папка — системная папка Windows.' : 'Choose a host EXE. Arguments are a JSON array of strings; command lines are not secret storage. The default working directory is the Windows system directory.'}</p>
    <form onSubmit={event => void register(event)}><label>{ru ? 'Окружение' : 'Environment'}<select required value={environment} onChange={e => { setEnvironment(e.target.value); setSelection(null); setCwdSelection(null); }}><option value="">—</option>{envs.map(e => <option key={e.id} value={e.id}>{escaped(e.display_name)}</option>)}</select></label>
      <label>{ru ? 'Название' : 'Name'}<input required maxLength={80} value={name} onChange={e => setName(e.target.value)}/></label>
      <button type="button" disabled={busy || !environment} onClick={() => void pick(false)}>{selection?.label ?? (ru ? 'Выбрать EXE' : 'Choose EXE')}</button>
      <button type="button" disabled={busy || !selection} onClick={() => void pick(true)}>{cwdSelection?.label ?? (ru ? 'Выбрать рабочую папку' : 'Choose working directory')}</button><button type="button" disabled={busy || !cwdSelection} onClick={() => setCwdSelection(null)}>{ru ? 'Системная папка' : 'Use system directory'}</button>
      <details><summary>{ru ? 'Дополнительные аргументы' : 'Advanced arguments'}</summary><label>{ru ? 'Аргументы' : 'Arguments'}<textarea value={args} onChange={e => setArgs(e.target.value)} maxLength={12000}/></label><p>{ru?'Массив аргументов — только просмотр':'Argument array — preview only'}</p><pre>{argumentPreview?JSON.stringify(argumentPreview.map(escaped),null,2):(ru?'Введите JSON-массив строк.':'Enter a JSON array of strings.')}</pre></details><button disabled={busy || !selection}>{ru ? 'Добавить приложение' : 'Register application'}</button></form>
    <button disabled={busy} onClick={() => void refresh()}>{ru ? 'Обновить' : 'Refresh'}</button>
    {error && <ErrorView language={language} code={error} diagnosticId={reply?.diagnostic_id??lastOperation??undefined} action={ru?'Приложения':'Applications'}/>}{!fresh && <p role="status">{ru ? 'Активность неизвестна: обновите состояние.' : 'Activity unknown: refresh state.'}</p>}
    {reply?.environments.filter(e=>!environmentId||e.environment_id===environmentId).map(e => <article key={e.environment_id}><h3>{escaped(envs.find(v => v.id === e.environment_id)?.display_name ?? e.environment_id)}</h3><p>{product.status}: {statusName(fresh&&e.complete?e.activity:'UNKNOWN',language)} · {product.eligibility}: {fresh&&e.launch_eligible?product.allowed:product.blocked}</p>
      {fresh&&!e.launch_eligible&&<ErrorView language={language} code={e.reason} diagnosticId={reply.diagnostic_id} action={product.applications}/>}
      {reply.applications.filter(a => a.environment_id === e.environment_id).map(a => <p key={a.id}>{escaped(a.display_name)} <small>({a.boxed ? (ru ? 'импортированный boxed EXE' : 'imported boxed EXE') : (ru ? 'установленный на хосте EXE' : 'host-installed EXE')})</small> <button disabled={busy || !fresh || !e.launch_eligible || !a.available} onClick={() => void action({ action: 'LAUNCH', application_id: a.id, environment_id: e.environment_id, expected_revision: a.revision })}>{ru ? 'Запустить' : 'Run'}</button>{!a.available && <span role="status"> {ru ? 'Недоступно: импортируйте EXE заново после сброса.' : 'Unavailable: reimport the EXE after reset.'}</span>}</p>)}
      <button disabled={busy} onClick={() => void action({ action: 'STOP', environment_id: e.environment_id })}>{ru ? 'Остановить окружение' : 'Stop environment'}</button>
      <ul>{e.processes.map(p => <li key={`${p.pid}:${p.creation_time}`}>PID {p.pid} · {ru ? 'сеанс' : 'session'} {p.session}</li>)}</ul></article>)}
    {lastOperation && <button disabled={busy} onClick={() => void reconcile(lastOperation)}>{ru ? 'Проверить последнюю операцию без повторного запуска' : 'Reconcile last operation without replay'}</button>}
    {reply?.receipts.some(r=>r.state==='UNKNOWN')&&<p role="status">{product.unknownCause} {product.unknownNext}</p>}
    <details><summary>{ru ? 'Результаты операций' : 'Operation receipts'}</summary>{reply?.receipts.map(r => <article key={r.operation_id}><code>{r.operation_id}</code> · {statusName(r.state,language)} <details><summary>{ru?'Технический код':'Technical code'}</summary><code>{escaped(r.reason)}</code></details> {r.state === 'UNKNOWN' && <button disabled={busy} onClick={() => void reconcile(r.operation_id)}>{ru ? 'Проверить без повторного запуска' : 'Reconcile without replay'}</button>}</article>)}</details>
  </section>;
}
