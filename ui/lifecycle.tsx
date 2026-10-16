import { useEffect, useRef, useState } from 'react';
import { invoke } from './backend';
import type { Language } from './strings';
import {escaped,statusName} from './product';
import {ErrorView} from './error';
type Intent = 'RESET' | 'REMOVE' | 'ARCHIVE' | 'UNARCHIVE' | 'PERSISTENT' | 'DISPOSABLE' | 'RESUME';
type Environment = { environment_id: string; display_name: string; revision: number; generation: number; lifecycle: 'ACTIVE' | 'ARCHIVED'; mode: 'PERSISTENT' | 'DISPOSABLE'; disposable_pending: boolean; activity: string; complete: boolean; reason: string; pending_operation: string | null };
type Operation = { operation_id: string; environment_id: string; display_name: string; intent: Intent; generation: number; stage: string; reason: string };
type Reply = { diagnostic_id?:string;reason: string; environments: Environment[]; operations: Operation[] };
export function Lifecycle({ language,environmentId }: { language: Language;environmentId?:string }) {
  const ru = language === 'ru'; const [reply, setReply] = useState<Reply | null>(null); const [error, setError] = useState(''); const [busy, setBusy] = useState(false); const [fresh, setFresh] = useState(false);
  const serial = useRef(0); const active = useRef(false); const observed = useRef(0); const engine = useRef(-1);
  async function request(request: object) {
    const ticket = ++serial.current; const value = await invoke<{ reply: Reply; engine_generation: number;diagnostic_id:string }>('lifecycle_request', { request });
    if (ticket !== serial.current || value.engine_generation < engine.current) return;
    engine.current = value.engine_generation; setReply({...value.reply,diagnostic_id:value.diagnostic_id}); setError(value.reply.reason === 'OBSERVED' ? '' : value.reply.reason); observed.current = Date.now(); setFresh(true);
  }
  useEffect(() => { let disposed = false; let polling = false;
    async function refresh() { if (active.current || polling || disposed) return; polling = true; try { await request({ action: 'LIST' }); } catch { if (!disposed) { setError('BACKEND_UNAVAILABLE'); setFresh(false); } } finally { polling = false; } }
    void refresh(); const poll = window.setInterval(() => void refresh(), 6000); const age = window.setInterval(() => { if (Date.now() - observed.current > 15000) setFresh(false); }, 1000);
    return () => { disposed = true; serial.current++; clearInterval(poll); clearInterval(age); };
  }, []);
  async function act(e: Environment, intent: Intent) { if (active.current) return; active.current = true; setBusy(true); serial.current++;
    try { await request({ action: 'ACT', environment_id: e.environment_id, expected_revision: e.revision, expected_generation: e.generation, operation_id: crypto.randomUUID(), intent, language }); }
    catch { setError('BACKEND_UNAVAILABLE_RECHECK_OPERATION'); setFresh(false); } finally { active.current = false; setBusy(false); }
  }
  async function recover(operation: string) { if (active.current) return; active.current = true; setBusy(true); serial.current++;
    try { await request({ action: 'RECOVER', operation_id: operation }); } catch { setError('BACKEND_UNAVAILABLE_RECHECK_OPERATION'); setFresh(false); } finally { active.current = false; setBusy(false); }
  }
  return <section className="engineHealth"><h2>{ru ? 'Хранение и восстановление' : 'Retention and recovery'}</h2>
    <p>{ru ? 'Persistent сохраняет данные и процессы после закрытия менеджера. Disposable предлагает продолжение, экспорт или удаление после выхода всех процессов. Автоматической очистки и экспорта нет.' : 'Persistent keeps data and workloads after manager exit. Disposable offers Resume, Export or Delete after all processes exit. Cleanup and export are never automatic.'}</p>
    <p>{ru ? 'Экспорт доступен в разделе «Файлы». Сброс удаляет содержимое и сохраняет приложения; удаление очищает содержимое до удаления определения. Каждое изменение подтверждается отдельным системным диалогом с именем среды.' : 'Use Files to export first. Reset clears contents and keeps applications; Remove clears contents before deleting the definition. Each change requires a separate native confirmation naming the environment.'}</p>
    <button disabled={busy} onClick={() => void request({ action: 'LIST' }).catch(() => { setError('BACKEND_UNAVAILABLE'); setFresh(false); })}>{ru ? 'Перепроверить' : 'Recheck'}</button>
    {!fresh && <p role="status">{ru ? 'Состояние устарело или неизвестно. Изменения недоступны.' : 'State is stale or unknown. Changes are unavailable.'}</p>}
    {error && <ErrorView language={language} code={error} diagnosticId={reply?.diagnostic_id} action={ru?'Хранение':'Retention'}/>}
    {reply?.environments.filter(e=>!environmentId||e.environment_id===environmentId).map(e => { const stopped = fresh && e.complete && e.activity === 'IDLE' && !e.pending_operation;
      return <article key={e.environment_id}><h3>{escaped(e.display_name)}</h3><p>{statusName(e.lifecycle,language)} · {statusName(e.mode,language)} · {statusName(e.activity,language)} · {ru ? 'поколение' : 'generation'} {e.generation}</p>
        {e.reason !== 'OBSERVED' && <ErrorView language={language} code={e.reason} action={ru?'Хранение':'Retention'} diagnosticId={reply?.diagnostic_id}/>}
        {e.mode === 'DISPOSABLE' && e.disposable_pending && <p role="status">{ru ? 'Осталось disposable-состояние. После завершения всех процессов выберите продолжение, экспорт или удаление. Перезапуск менеджера ничего не удаляет.' : 'Disposable state remains. After all processes exit, choose Resume, Export or Delete. Restarting the manager deletes nothing.'}</p>}
        <button disabled={busy || !stopped} onClick={() => void act(e, e.lifecycle === 'ACTIVE' ? 'ARCHIVE' : 'UNARCHIVE')}>{e.lifecycle === 'ACTIVE' ? (ru ? 'Архивировать' : 'Archive') : (ru ? 'Вернуть из архива' : 'Unarchive')}</button>
        <button disabled={busy || !stopped} onClick={() => void act(e, e.mode === 'PERSISTENT' ? 'DISPOSABLE' : 'PERSISTENT')}>{e.mode === 'PERSISTENT' ? (ru ? 'Режим Disposable' : 'Use disposable mode') : (ru ? 'Режим Persistent' : 'Use persistent mode')}</button>
        {e.mode === 'DISPOSABLE' && e.lifecycle === 'ACTIVE' && <button disabled={busy || !stopped} onClick={() => void act(e, 'RESUME')}>{ru ? 'Сохранить и продолжить' : 'Keep and resume'}</button>}
        <button disabled={busy || !stopped} onClick={() => void act(e, 'RESET')}>{ru ? 'Сбросить содержимое' : 'Reset contents'}</button>
        <button disabled={busy || !stopped} onClick={() => void act(e, 'REMOVE')}>{ru ? 'Очистить и удалить среду' : 'Clear and remove environment'}</button>
        {e.pending_operation && <button disabled={busy} onClick={() => void recover(e.pending_operation!)}>{ru ? 'Проверить прерванную операцию' : 'Inspect interrupted operation'}</button>}
      </article>;
    })}
    <h3>{ru ? 'Операции' : 'Operations'}</h3><p>{ru ? 'Восстановление проверяет фактическое состояние. Оно не повторяет удаление, не запускает приложения и не удаляет временные файлы по имени.' : 'Recovery inspects actual state. It never repeats deletion, launches applications or deletes temporary files by name.'}</p>
    {reply?.operations.filter(o=>!environmentId||o.environment_id===environmentId).map(o => <article key={o.operation_id}>{escaped(o.display_name)} · {statusName(o.intent,language)} · {statusName(o.stage,language)} <details><summary>{ru?'Технический код':'Technical code'}</summary><code>{escaped(o.reason)}</code></details> <button disabled={busy} onClick={() => void recover(o.operation_id)}>{ru ? 'Проверить' : 'Inspect'}</button></article>)}
  </section>;
}
