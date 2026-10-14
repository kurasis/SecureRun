import React, { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import type { Language } from './strings';

type Preset = 'STANDARD_OFFLINE' | 'STANDARD_ONLINE';
type Permission = 'BLOCK' | 'READ_ONLY' | 'ISOLATED_CHANGES';
interface Owned { id: string; display_name: string; revision: number; stage: string; reason: string; desired: {preset: Preset; grants: {path: string; permission: Permission}[]}; compiled: {section: Record<string, string[]>}; fingerprint: string | null; enforcement_evidence: string | null; baseline: Record<string, string[]> | null; observed: Record<string, string[]> | null }
interface Reply {reason: string; environments: Owned[]; production_launch_available: false; elevated_helper: false}
const copy = {
  en: {title:'Managed policies', create:'Create verified environment', offline:'Standard offline', online:'Standard online', limitation:'Standard permits host reads outside selected exclusions. Online can disclose readable data and reach local resources. Network shares remain blocked in both presets.', launch:'Program launch is unavailable until the launch phase is verified.', prerequisite:'Provisioning requires a verified engine, the installed protected diagnostic probe, fixed NTFS storage and explicitly enabled engine WFP. This action does not enable WFP.', name:'Display name', preset:'Preset', addFolder:'Select folder rule', addFile:'Select file rule', rule:'Permission', block:'Block', read:'Read only', isolated:'Isolated changes', remove:'Remove rule', apply:'Apply stopped policy', edit:'Edit policy', inspect:'Inspect current conflict', repair:'Reset to managed policy shown below', reason:'Result', fingerprint:'Verified fingerprint', probes:'Independent synthetic evidence', desired:'Desired policy', current:'Current configuration', revision:'Revision', acknowledgement:'I understand that Read only hides existing boxed changes at this location. They remain stored; export them before switching if needed.', replacement:'Applying this editor replaces the editable rules with the selected list. Mandatory manager and sibling protections always remain.', busy:'Checking native prerequisites and policy…', refresh:'Refresh policies', deferred:'Stop all managed environments before creating a sibling. No process is stopped automatically.', error:'Action unavailable. Refresh and inspect the result before retrying.', cancel:'Cancel edit', noHelper:'Operations use the current user. No elevated helper.'},
  ru: {title:'Управляемые политики', create:'Создать проверенное окружение', offline:'Standard offline', online:'Standard online', limitation:'Standard разрешает чтение хоста вне выбранных исключений. Online может раскрывать читаемые данные и обращаться к локальным ресурсам. Сетевые файловые ресурсы запрещены в обоих режимах.', launch:'Запуск программ станет доступен после проверки этапа запуска.', prerequisite:'Нужны проверенный движок, установленная защищённая диагностическая программа, локальное NTFS-хранилище и явно включённый WFP движка. Эта операция не включает WFP.', name:'Название', preset:'Политика', addFolder:'Выбрать папку', addFile:'Выбрать файл', rule:'Разрешение', block:'Запретить', read:'Только чтение', isolated:'Изолированные изменения', remove:'Убрать правило', apply:'Применить после остановки', edit:'Изменить политику', inspect:'Проверить текущий конфликт', repair:'Восстановить показанную управляемую политику', reason:'Результат', fingerprint:'Проверенный отпечаток', probes:'Независимая синтетическая проверка', desired:'Желаемая политика', current:'Текущая конфигурация', revision:'Ревизия', acknowledgement:'Понимаю: режим «Только чтение» скрывает существующие изменения бокса в этом месте. Они сохранятся; при необходимости сначала экспортируйте их.', replacement:'Применение заменит редактируемые правила выбранным списком. Обязательная защита менеджера и соседних окружений сохраняется.', busy:'Проверяются условия и политика…', refresh:'Обновить политики', deferred:'Перед созданием соседа остановите все управляемые окружения. Автоматической остановки нет.', error:'Действие недоступно. Обновите состояние и изучите результат перед повтором.', cancel:'Отменить изменение', noHelper:'Операции выполняются текущим пользователем, без elevated helper.'}
};
export function Policies({language}: {language: Language}) {
  const t=copy[language];const [reply,setReply]=useState<Reply|null>(null);const [busy,setBusy]=useState(false);const [error,setError]=useState('');
  const [name,setName]=useState('');const [preset,setPreset]=useState<Preset>('STANDARD_OFFLINE');const [permission,setPermission]=useState<Permission>('BLOCK');
  const [operation,setOperation]=useState(()=>crypto.randomUUID());const [editing,setEditing]=useState<Owned|null>(null);const [ack,setAck]=useState(false);
  const [grants,setGrants]=useState<{selection_id:string;display_name:string;permission:Permission}[]>([]);
  const request=async (body:unknown) => {
    setBusy(true);setError('');try {const result=await invoke<Reply>('policy_request',{request:body});setReply(result);if(result.reason!=='OBSERVED')setError(result.reason);return result;}
    catch {setError('POLICY_REQUEST_UNAVAILABLE');return null;}finally{setBusy(false);}
  };
  const refresh=()=>request({action:'LIST'});
  useEffect(()=>{void refresh();},[]);
  const reset=()=>{setEditing(null);setName('');setPreset('STANDARD_OFFLINE');setGrants([]);setAck(false);setOperation(crypto.randomUUID());};
  const pick=async(directory:boolean)=>{
    setBusy(true);try {const selection=await invoke<{selection_id:string;display_name:string}>('select_policy_path',{request:{operation_id:operation,environment_id:editing?.id??null,expected_revision:editing?.revision??0,directory}});setGrants(old=>[...old,{...selection,permission}]);}
    catch{setError('POLICY_SELECTION_UNAVAILABLE');}finally{setBusy(false);}
  };
  const submit=async(event:React.FormEvent)=>{
    event.preventDefault();const selected=grants.map(({selection_id,permission})=>({selection_id,permission}));
    const result=await request(editing?{action:'APPLY',environment_id:editing.id,expected_revision:editing.revision,preset,grants:selected,operation_id:operation,acknowledge_view_change:ack}:{action:'CREATE',display_name:name,preset,grants:selected,operation_id:operation});
    reset();if(result?.reason!=='OBSERVED')await refresh();
  };
  return <section className="policies" aria-labelledby="policies-title"><h2 id="policies-title">{t.title}</h2><p>{t.limitation}</p><p>{t.prerequisite}</p><p>{t.deferred}</p><p>{t.launch} {t.noHelper}</p>
    <button disabled={busy} onClick={()=>void refresh()}>{t.refresh}</button>{busy&&<p role="status">{t.busy}</p>}{error&&<p role="alert">{t.error} <code>{error}</code></p>}
    {reply?.reason==='OBSERVED'&&<form onSubmit={submit}><fieldset disabled={busy}><legend>{editing?t.apply:t.create}</legend>{!editing&&<label>{t.name}<input value={name} onChange={e=>setName(e.target.value)} maxLength={80} required/></label>}
      <label>{t.preset}<select value={preset} onChange={e=>setPreset(e.target.value as Preset)}><option value="STANDARD_OFFLINE">{t.offline}</option><option value="STANDARD_ONLINE">{t.online}</option></select></label>
      <label>{t.rule}<select value={permission} onChange={e=>setPermission(e.target.value as Permission)}><option value="BLOCK">{t.block}</option><option value="READ_ONLY">{t.read}</option><option value="ISOLATED_CHANGES">{t.isolated}</option></select></label>
      <button type="button" onClick={()=>void pick(true)}>{t.addFolder}</button><button type="button" onClick={()=>void pick(false)}>{t.addFile}</button>
      <ul>{grants.map(g=><li key={g.selection_id}>{g.display_name} · {g.permission} <button type="button" onClick={()=>setGrants(old=>old.filter(v=>v.selection_id!==g.selection_id))}>{t.remove}</button></li>)}</ul>
      {editing&&<p>{t.replacement}</p>}{grants.some(g=>g.permission==='READ_ONLY')&&<label><input type="checkbox" checked={ack} onChange={e=>setAck(e.target.checked)} required/>{t.acknowledgement}</label>}
      <button type="submit">{editing?t.apply:t.create}</button>{editing&&<button type="button" onClick={reset}>{t.cancel}</button>}</fieldset></form>}
    {reply?.environments.map(env=><article key={env.id}><h3>{env.display_name}</h3><p>{env.stage} · {t.revision} {env.revision}</p><p>{t.reason}: <code>{env.reason}</code></p><p>{t.fingerprint}: <code>{env.fingerprint??'UNVERIFIED'}</code></p><p>{t.probes}: {env.enforcement_evidence?'VERIFIED':'UNVERIFIED'}</p>
      {env.stage==='VERIFIED'?<button disabled={busy} onClick={()=>{reset();setEditing(env);setPreset(env.desired.preset);}}>{t.edit}</button>:<button disabled={busy} onClick={()=>void request({action:'INSPECT',environment_id:env.id})}>{t.inspect}</button>}
      <details><summary>{t.desired}</summary><table><tbody>{Object.entries(env.compiled.section).map(([key,values])=><tr key={key}><th>{key}</th><td>{values.join(' · ')}</td></tr>)}</tbody></table></details>
      {env.observed&&<details open><summary>{t.current}</summary><table><tbody>{Object.entries(env.observed).map(([key,values])=><tr key={key}><th>{key}</th><td>{values.join(' · ')}</td></tr>)}</tbody></table></details>}
      {env.stage==='CONFLICT'&&env.reason.startsWith('INSPECTED_BASELINE:')&&<button disabled={busy} onClick={()=>void request({action:'REPAIR',environment_id:env.id,expected_revision:env.revision,observed_fingerprint:env.reason.slice('INSPECTED_BASELINE:'.length),operation_id:crypto.randomUUID(),acknowledge_view_change:true})}>{t.repair}</button>}
    </article>)}
  </section>;
}
