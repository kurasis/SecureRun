import {useEffect,useState} from 'react';
import {invoke} from './backend';
import type {Language} from './strings';
import {ErrorView} from './error';
import {escaped,productText} from './product';
type Event={action:string;outcome:string;unix_ms:number;diagnostic_id:string;environment_id:string|null};
type Reply={history:{reason:string;events:Event[];free_volume_bytes:string|null;retention_days:number;retention_limit:number};preview_id:string|null;bundle:string|null;saved:boolean};
export function Diagnostics({language,environmentId}:{language:Language;environmentId?:string}) {
 const t=productText[language];const [reply,setReply]=useState<Reply|null>(null);const [preview,setPreview]=useState<{id:string;body:string;expires:number}|null>(null);const [busy,setBusy]=useState(false);const [error,setError]=useState('');const [saved,setSaved]=useState(false);const [now,setNow]=useState(Date.now());
 async function request(request:object) {setBusy(true);setError('');try {const value=await invoke<Reply>('product_request',{request});setReply(value);setSaved(value.saved);if(value.preview_id&&value.bundle)setPreview({id:value.preview_id,body:value.bundle,expires:Date.now()+60000});return value;}catch(e){setError((e as {code?:string})?.code??'BACKEND_UNAVAILABLE');}finally{setBusy(false);}}
 useEffect(()=>{void request({action:'LIST'});const timer=setInterval(()=>setNow(Date.now()),1000);return()=>clearInterval(timer);},[]);
 const events=reply?.history.events.filter(e=>!environmentId||e.environment_id===environmentId)??[];
 const actionName=(action:string)=>({POLICY_CREATE:language==='ru'?'Создание политики':'Create policy',POLICY_APPLY:language==='ru'?'Применение политики':'Apply policy',POLICY_REPAIR:language==='ru'?'Исправление политики':'Repair policy',REGISTER:language==='ru'?'Регистрация приложения':'Register application',LAUNCH:language==='ru'?'Запрос запуска':'Launch request',STOP:language==='ru'?'Остановка окружения':'Stop environment',STOP_MANAGED:language==='ru'?'Остановка управляемых':'Stop managed',IMPORT:language==='ru'?'Импорт':'Import',EXPORT:language==='ru'?'Экспорт':'Export',RETENTION_CHANGE:language==='ru'?'Изменение хранения':'Retention change',DIAGNOSTIC_PREVIEW:t.preview,DIAGNOSTIC_SAVE:t.save} as Record<string,string>)[action]??t.recheck;
 return <section aria-labelledby="history-heading"><h2 id="history-heading">{t.history}</h2><p>{t.scope}</p><p>{t.retentionHistory}</p><button disabled={busy} onClick={()=>void request({action:'LIST'})}>{t.recheck}</button>
 {reply&&reply.history.reason!=='OBSERVED'&&<p role="status">{t.sessionOnly}</p>}
 {reply?.history.free_volume_bytes!=null&&<div><p>{t.free}: {new Intl.NumberFormat(language).format(Number(reply.history.free_volume_bytes)/1073741824)} GiB</p><p>{t.advisory}</p>{BigInt(reply.history.free_volume_bytes)<1073741824n&&<p role="status">{t.low}</p>}</div>}
 {error&&<ErrorView language={language} code={error} action={t.history}/>}{saved&&<p role="status">{t.saved}</p>}
 {events.length?<div className="tableScroll"><table><thead><tr><th>{language==='ru'?'Время':'Time'}</th><th>{language==='ru'?'Операция':'Action'}</th><th>{language==='ru'?'Результат':'Outcome'}</th><th>{t.diagnostic}</th></tr></thead><tbody>{events.map(e=><tr key={e.diagnostic_id}><td>{new Date(e.unix_ms).toLocaleString(language)}</td><td>{actionName(e.action)}</td><td>{e.outcome==='OBSERVED'?t.observed:e.outcome==='UNKNOWN'?t.uncertain:t.refused}</td><td><code>{escaped(e.diagnostic_id)}</code></td></tr>)}</tbody></table></div>:<p>{t.emptyHistory}</p>}
 <button disabled={busy} onClick={()=>void request({action:'PREVIEW'})}>{t.preview}</button>
 {preview&&<section className="diagnosticPreview" aria-labelledby="preview-heading"><h3 id="preview-heading">{t.previewTitle}</h3><p>{t.review}</p><pre tabIndex={0} aria-label={t.previewTitle}>{preview.body}</pre><p>{t.expiry}</p><button disabled={busy||now>=preview.expires} onClick={()=>{const id=preview.id;setPreview(null);void request({action:'SAVE',preview_id:id,language});}}>{t.save}</button><button disabled={busy} onClick={()=>{const id=preview.id;setPreview(null);void request({action:'CANCEL',preview_id:id});}}>{t.cancel}</button></section>}
 </section>;
}
