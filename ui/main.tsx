import {useEffect,useRef,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {invoke} from './backend';
import type {EngineHealth,Snapshot} from './contracts';
import {strings,type Language} from './strings';
import {escaped,productText,setupState,statusName} from './product';
import {ErrorView} from './error';
import {Policies} from './policies';
import {Controls} from './controls';
import {Files} from './files';
import {Lifecycle} from './lifecycle';
import {Diagnostics} from './diagnostics';
import icon from './icon.svg';
import './style.css';

type Owned={id:string;display_name:string;revision:number;generation:number;stage:string;reason:string;lifecycle:string;mode:string;desired:{preset:string}};
type Control={environment_id:string;activity:string;complete:boolean;launch_eligible:boolean;reason:string};
type Tab='applications'|'processes'|'files'|'permissions'|'activity'|'retention';
const tabs:Tab[]=['applications','processes','files','permissions','activity','retention'];
function preference<T extends string>(key:string,allowed:readonly T[],fallback:T):T {
 try {const value=localStorage.getItem(`SecureRun.${key}`);return allowed.includes(value as T)?value as T:fallback;}catch{return fallback;}
}
function savePreference(key:string,value:string) {try{localStorage.setItem(`SecureRun.${key}`,value);}catch{/* Appearance remains usable without persistent WebView storage. */}}
function Creation({language,onClose,enabled}:{language:Language;onClose:()=>void;enabled:boolean}) {
 const ref=useRef<HTMLDialogElement>(null);const t=productText[language];
 useEffect(()=>{ref.current?.showModal();},[]);
 return <dialog ref={ref} onCancel={onClose} aria-labelledby="create-title"><header><h2 id="create-title">{t.create}</h2><button onClick={onClose}>{t.close}</button></header><fieldset className="actionScope" disabled={!enabled}><legend className="srOnly">{t.create}</legend><Policies language={language} creationOnly onCreated={onClose}/></fieldset></dialog>;
}
function Rename({language,environment,onClose,onRenamed}:{language:Language;environment:Owned;onClose:()=>void;onRenamed:()=>void}) {
 const ref=useRef<HTMLDialogElement>(null);const [name,setName]=useState(environment.display_name);const [error,setError]=useState('');const [busy,setBusy]=useState(false);
 const title=language==='ru'?'Переименовать окружение':'Rename environment';
 useEffect(()=>{ref.current?.showModal();},[]);
 async function submit(event:React.FormEvent) {event.preventDefault();setBusy(true);try{const r=await invoke<{reason:string}>('policy_request',{request:{action:'RENAME',environment_id:environment.id,expected_revision:environment.revision,expected_generation:environment.generation,expected_display_name:environment.display_name,display_name:name,operation_id:crypto.randomUUID()}});if(r.reason==='OBSERVED')onRenamed();else setError(r.reason);}catch(e){setError((e as {code?:string})?.code??'OPERATION_OUTCOME_UNKNOWN');}finally{setBusy(false);}}
 return <dialog ref={ref} onCancel={onClose} aria-labelledby="rename-title"><h2 id="rename-title">{title}</h2><p>{language==='ru'?'Меняется только отображаемое имя. Идентичность, данные и разрешения окружения сохраняются.':'Only the display name changes. Environment identity, data and permissions are preserved.'}</p>{error&&<ErrorView language={language} code={error} action={title}/>}<form onSubmit={event=>void submit(event)}><label>{language==='ru'?'Имя окружения':'Environment name'}<input autoFocus required maxLength={80} value={name} onChange={event=>setName(event.target.value)}/></label><button disabled={busy||!name.trim()} type="submit">{language==='ru'?'Сохранить имя':'Save name'}</button><button type="button" disabled={busy} onClick={onClose}>{productText[language].cancel}</button></form></dialog>;
}
function App() {
 const [language,setLanguage]=useState<Language>(()=>preference('language',['en','ru'],'en'));
 const [theme,setTheme]=useState(()=>preference('theme',['system','light','dark'],'system'));
 const [scale,setScale]=useState(()=>preference('scale',['100','150','200'],'100'));
 const [page,setPage]=useState<'environments'|'settings'>('environments');const [tab,setTab]=useState<Tab>('applications');
 const [health,setHealth]=useState<EngineHealth|null>(null);const [snapshot,setSnapshot]=useState<Snapshot|null>(null);
 const [environments,setEnvironments]=useState<Owned[]>([]);const [controls,setControls]=useState<Control[]>([]);const [selected,setSelected]=useState('');const [search,setSearch]=useState('');
 const [error,setError]=useState('');const [busy,setBusy]=useState(false);const [creation,setCreation]=useState(false);const [clock,setClock]=useState(Date.now());
 const [routeAt,setRouteAt]=useState(0);const [routeGeneration,setRouteGeneration]=useState(0);const healthGeneration=useRef(0);healthGeneration.current=health?.generation??0;
 const [renaming,setRenaming]=useState<Owned|null>(null);const [stopPlan,setStopPlan]=useState<Owned[]|null>(null);const stopDialog=useRef<HTMLDialogElement>(null);const serial=useRef(0);const observer=useRef(false);const loading=useRef(false);const metadataAt=useRef(0);const controlPolling=useRef(false);const [controlAt,setControlAt]=useState(0);
 const t=strings[language];const p=productText[language];const fresh=!!health?.fresh&&clock-health.observation.observed_unix_ms<15000;const setup=setupState(health,fresh,routeAt>0&&routeGeneration===health?.generation&&clock-routeAt<15000);
 const canBrowse=fresh&&health?.observation.trust==='VERIFIED'&&health.observation.reason==='OBSERVED'&&health.observation.manager_context==='UNBOXED'&&health.observation.bridge_context==='UNBOXED'&&health.observation.service_running&&health.observation.driver_running;
 const env=environments.find(e=>e.id===selected);
 function recordRoute(ticket:number) {setRouteGeneration(ticket);setRouteAt(Date.now());}
 async function refreshMetadata() {
  if(loading.current)return;loading.current=true;const routeTicket=healthGeneration.current;const ticket=++serial.current;setBusy(true);
  try {const policies=await invoke<{reason:string;environments:Owned[]}>('policy_request',{request:{action:'LIST'}});if(ticket!==serial.current)return;
   if(policies.reason!=='OBSERVED'){setRouteAt(0);setError(policies.reason);return;}recordRoute(routeTicket);setEnvironments(policies.environments);metadataAt.current=Date.now();
   const control=await invoke<{reason:string;environments:Control[]}>('control_request',{request:{action:'LIST'}});if(ticket!==serial.current)return;setControls(control.environments);setControlAt(Date.now());if(control.reason!=='OBSERVED')setError(control.reason);else setError('');
  }catch(e){setRouteAt(0);setError((e as {code?:string})?.code??'BACKEND_UNAVAILABLE');}finally{loading.current=false;setBusy(false);}
 }
 async function pollControls() {
  if(controlPolling.current||loading.current)return;controlPolling.current=true;const routeTicket=healthGeneration.current;
  try {const value=await invoke<{reason:string;environments:Control[]}>('control_request',{request:{action:'LIST'}});if(value.reason==='OBSERVED'){recordRoute(routeTicket);setControls(value.environments);setControlAt(Date.now());}else{setRouteAt(0);setControls([]);setControlAt(0);}}
  catch{setRouteAt(0);setControls([]);setControlAt(0);}finally{controlPolling.current=false;}
 }
 async function observe() {
  if(observer.current)return;observer.current=true;
  try {const value=await invoke<EngineHealth>('get_engine_health');setHealth(old=>old&&(old.generation>value.generation||(old.generation===value.generation&&old.sequence>value.sequence))?old:value);}
  catch{setHealth(null);}finally{observer.current=false;}
 }
 useEffect(()=>{void invoke<Snapshot>('get_snapshot').then(setSnapshot).catch(()=>setError('BACKEND_UNAVAILABLE'));void observe();const timer=setInterval(()=>{setClock(Date.now());void observe();},1000);const resume=()=>{setRouteAt(0);setHealth(null);metadataAt.current=0;void observe();};window.addEventListener('focus',resume);document.addEventListener('visibilitychange',resume);return()=>{serial.current++;clearInterval(timer);window.removeEventListener('focus',resume);document.removeEventListener('visibilitychange',resume);};},[]);
 useEffect(()=>{if(canBrowse&&metadataAt.current===0)void refreshMetadata();if(!canBrowse)return;const timer=setInterval(()=>void pollControls(),5000);return()=>clearInterval(timer);},[canBrowse]);
 useEffect(()=>{document.documentElement.lang=language;document.documentElement.dataset.theme=theme;savePreference('language',language);savePreference('theme',theme);},[language,theme]);
 useEffect(()=>{savePreference('scale',scale);void invoke('product_request',{request:{action:'SCALE',percent:Number(scale)}}).catch(()=>setError('CAPABILITY_UNAVAILABLE'));},[scale]);
 useEffect(()=>{if(stopPlan)stopDialog.current?.showModal();},[stopPlan]);
 useEffect(()=>{const key=(event:KeyboardEvent)=>{if(event.ctrlKey&&event.key==='1'){event.preventDefault();setPage('environments');}if(event.ctrlKey&&event.key===','){event.preventDefault();setPage('settings');}if(event.key==='F6'){event.preventDefault();document.querySelector<HTMLButtonElement>('nav button')?.focus();}};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key);},[]);
 function box(e:Owned) {return fresh?health?.observation.boxes.find(b=>b.name.toLowerCase()===`SR_${e.id.replaceAll('-','')}`.toLowerCase()):undefined;}
 function activity(e:Owned) {const b=box(e);return b?.complete?b.activity:'UNKNOWN';}
 function activityLabel(value:string) {return ({RUNNING:t.running,IDLE:language==='ru'?'Простой':'Idle',STARTING:language==='ru'?'Запускается':'Starting',STOPPING:language==='ru'?'Останавливается':'Stopping',CLEANING:language==='ru'?'Очищается':'Cleaning'} as Record<string,string>)[value]??p.unknown;}
 function launchReason(e:Owned) {
  if(!fresh)return 'OBSERVATION_STALE';
  if(clock-controlAt>=15000)return 'CONTROL_OBSERVATION_STALE';
  if(e.lifecycle!=='ACTIVE')return 'ENVIRONMENT_NOT_ACTIVE';
  const control=controls.find(c=>c.environment_id===e.id);
  return control?.launch_eligible?'CURRENT_PREREQUISITES_SATISFIED':control?.reason??'ENVIRONMENT_NOT_OBSERVED';
 }
 function networkPolicy(e:Owned) {
  if(!fresh||clock-metadataAt.current>=15000||e.stage!=='VERIFIED'||e.lifecycle!=='ACTIVE')return p.unknown;
  return e.desired.preset==='STANDARD_OFFLINE'?p.offlineVerified:p.onlineVerified;
 }
 function launchDetails(e:Owned) {
  const reason=launchReason(e);
  return reason==='CURRENT_PREREQUISITES_SATISFIED'?p.allowed:<>{p.blocked}<details><summary>{p.cause}</summary><code>{escaped(reason)}</code></details></>;
 }
 async function stopListed() {
  const plan=stopPlan;if(!plan)return;setStopPlan(null);setBusy(true);let failure='';
  try{for(const e of plan){const value=await invoke<{reason:string}>('control_request',{request:{action:'STOP',environment_id:e.id,operation_id:crypto.randomUUID()}});if(value.reason!=='OBSERVED')failure=value.reason;}}
  catch{failure='OPERATION_OUTCOME_UNKNOWN';}finally{setBusy(false);await refreshMetadata();if(failure)setError(failure);}
 }
 const recheck=()=>{metadataAt.current=0;void observe();void refreshMetadata();};
 return <><a className="skipLink" href="#workspace">{p.skip}</a><div className="shell"><aside><div className="brand"><img src={icon} width="30" height="30" alt=""/>SecureRun</div><nav aria-label={language==='ru'?'Главная навигация':'Main navigation'}>{(['environments','settings'] as const).map(item=><button key={item} aria-current={page===item?'page':undefined} onClick={()=>setPage(item)}>{t[item]}</button>)}</nav><p className="version">SecureRun · 0.3</p></aside>
 <main id="workspace" tabIndex={-1}><header><div><h1>{page==='settings'?t.settings:env?escaped(env.display_name):t.title}</h1><p>{t.subtitle}</p></div><button disabled={busy} onClick={recheck}>{p.recheck}</button></header>
 {snapshot?.mode==='FOUNDATION_TEST_FIXTURE'&&<p className="fixture" role="status">{t.fixture}</p>}
 <section className={`notice setup-${setup}`} aria-label={p[setup]}><div><h2>{p[setup]}</h2><p>{setup==='ready'?t.phaseGuard:p.install}</p>{setup==='ready'&&!health?.observation.service_identity_complete&&<p>{p.serviceRestricted}</p>}{setup!=='ready'&&<button onClick={()=>void invoke('product_request',{request:{action:'HELP',topic:'INSTALL'}}).catch(()=>setError('CAPABILITY_UNAVAILABLE'))}>{p.official}</button>}</div><span className="badge">{health?.observation.core_version??p.unknown}</span></section>
 {error&&<ErrorView code={error} language={language} action={page==='settings'?t.settings:t.environments}/>}
 {page==='settings'?<><section className="settings" aria-labelledby="settings-title"><h2 id="settings-title">{t.settings}</h2><label>{t.language}<select data-testid="language" value={language} onChange={e=>setLanguage(e.target.value as Language)}><option value="en">English</option><option value="ru">Русский</option></select></label><label>{t.appearance}<select data-testid="theme" value={theme} onChange={e=>setTheme(e.target.value as typeof theme)}><option value="system">{t.system}</option><option value="light">{t.light}</option><option value="dark">{t.dark}</option></select></label><label>{p.scale}<select data-testid="scale" value={scale} onChange={e=>setScale(e.target.value as typeof scale)}>{['100','150','200'].map(v=><option key={v} value={v}>{v}%</option>)}</select></label><p>{p.keyboard}</p><h3>{p.clipboard}</h3><p>{p.clipboardReason}</p><h3>{p.paid}</h3><p>{p.paidReason}</p><button onClick={()=>void invoke('product_request',{request:{action:'HELP',topic:'CERTIFICATE'}}).catch(()=>setError('CAPABILITY_UNAVAILABLE'))}>{language==='ru'?'Официальные возможности и сертификаты':'Official features and certificates'}</button></section>
 <details className="engineHealth"><summary>{p.technical}</summary><dl><dt>{t.trust}</dt><dd>{health?.observation.trust??p.unknown}</dd><dt>{t.service}</dt><dd>{health?.observation.service_running?t.running:p.unknown}</dd><dt>{t.driver}</dt><dd>{health?.observation.driver_running?t.running:p.unknown}</dd><dt>{t.version}</dt><dd>{health?.observation.core_version??p.unknown}</dd><dt>{t.freshness}</dt><dd>{fresh?t.fresh:p.unknown}</dd></dl><p><code>{escaped(health?.observation.reason??'OBSERVATION_PENDING')}</code></p>{health?.observation.capabilities.map(c=><p key={c.name}><code>{escaped(c.name)} · {escaped(c.availability)} · {escaped(c.reason)}</code></p>)}<details><summary>{language==='ru'?'Обнаруженные окружения движка — только чтение':'Detected engine environments — read only'}</summary>{health?.observation.boxes.map(box=><article key={box.name}><h3>{escaped(box.name)}</h3><p>{box.owned?(language==='ru'?'Управляется SecureRun':'Managed by SecureRun'):(language==='ru'?'Внешнее окружение. Изменения недоступны.':'External environment. Changes unavailable.')}</p><p>{box.complete?activityLabel(box.activity):p.unknown}</p><details><summary>{p.technical}</summary><code>{escaped(box.reason)}</code><dl><dt>{language==='ru'?'Корень хранилища':'Storage root'}</dt><dd>{escaped(box.root.path??p.unknown)}</dd></dl>{box.configuration.map(rule=><div key={rule.key}><strong>{escaped(rule.key)}</strong><pre>{rule.effective.map(escaped).join('\n')}</pre></div>)}</details></article>)}</details></details><Diagnostics language={language}/>
</>:
 env?<><button onClick={()=>{setSelected('');void refreshMetadata();}}>{p.back}</button><button disabled={setup!=='ready'||busy} onClick={()=>setRenaming(env)}>{language==='ru'?'Переименовать окружение':'Rename environment'}</button><section className="environmentSummary" aria-label={p.selected}><dl><dt>{p.status}</dt><dd>{activityLabel(activity(env))}</dd><dt>{p.count}</dt><dd>{box(env)?.complete?box(env)!.processes.length:p.unknown}</dd><dt>{p.eligibility}</dt><dd>{launchDetails(env)}</dd><dt>{p.networkPolicy}</dt><dd>{networkPolicy(env)}</dd><dt>{p.retention}</dt><dd>{statusName(env.lifecycle,language)}</dd><dt>{p.mode}</dt><dd>{env.mode==='DISPOSABLE'?p.disposable:p.persistent}</dd></dl></section>
 <div className="tabs" role="tablist" aria-label={p.selected} onKeyDown={event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();const buttons=Array.from(event.currentTarget.querySelectorAll<HTMLButtonElement>('[role=tab]'));const index=event.key==='Home'?0:event.key==='End'?tabs.length-1:(tabs.indexOf(tab)+(event.key==='ArrowRight'?1:tabs.length-1))%tabs.length;setTab(tabs[index]);void refreshMetadata();buttons[index]?.focus();}}>{tabs.map(item=><button role="tab" id={`tab-${item}`} aria-controls="environment-panel" aria-selected={tab===item} tabIndex={tab===item?0:-1} key={item} onClick={()=>{setTab(item);void refreshMetadata();}}>{p[item]}</button>)}</div>
 <section id="environment-panel" role="tabpanel" aria-labelledby={`tab-${tab}`} key={`${env.id}:${tab}`}><fieldset className="actionScope" disabled={setup!=='ready'&&tab!=='activity'}><legend className="srOnly">{p[tab]}</legend>{tab==='applications'?<Controls language={language} environmentId={env.id}/>:tab==='files'?<Files language={language} environmentId={env.id}/>:tab==='permissions'?<Policies language={language} environmentId={env.id} stopped={box(env)?.complete&&activity(env)==='IDLE'}/>:tab==='retention'?<Lifecycle language={language} environmentId={env.id}/>:tab==='activity'?<Diagnostics language={language} environmentId={env.id}/>:<section><h2>{p.processes}</h2><p>{box(env)?.complete?t.complete:t.incomplete}</p>{!box(env)?.complete&&<p role="status">{p.stale}</p>}<ul>{box(env)?.processes.map(proc=><li key={`${proc.pid}:${proc.creation_time}`}>PID {proc.pid} · {t.session} {proc.session}</li>)}</ul><button disabled={busy} onClick={()=>{setStopPlan([env]);}}>{language==='ru'?'Остановить окружение':'Stop environment'}</button></section>}</fieldset></section></>:
 <><div className="toolbar"><label className="search">{t.search}<input type="search" value={search} onChange={e=>setSearch(e.target.value)}/></label><button className="primary" disabled={setup!=='ready'||busy} onClick={()=>setCreation(true)}>{p.create}</button><button disabled={busy||environments.length===0} onClick={()=>setStopPlan([...environments])}>{p.stopAll}</button></div>
 {environments.length?<div className="cards">{environments.filter(e=>e.display_name.toLocaleLowerCase(language).includes(search.toLocaleLowerCase(language))).map(e=><article key={e.id}><h2><button className="environmentLink" onClick={()=>{setSelected(e.id);setTab('applications');}}>{escaped(e.display_name)}</button></h2><p>{p.configuredPreset}: {e.desired.preset==='STANDARD_OFFLINE'?'Standard offline':'Standard online'} · {e.mode==='DISPOSABLE'?p.disposable:p.persistent}</p><dl><dt>{p.status}</dt><dd>{activityLabel(activity(e))}</dd><dt>{p.count}</dt><dd>{box(e)?.complete?box(e)!.processes.length:p.unknown}</dd><dt>{p.networkPolicy}</dt><dd>{networkPolicy(e)}</dd><dt>{p.eligibility}</dt><dd>{launchDetails(e)}</dd></dl>{e.reason!=='POLICY_VERIFIED_TARGET_LAUNCH_DEFERRED'&&e.reason!=='OBSERVED'&&<details><summary>{p.cause}</summary><code>{escaped(e.reason)}</code></details>}</article>)}</div>:<section className="empty"><h2>{p.empty}</h2><p>{p.emptyDetail}</p></section>}
 {environments.length>0&&!environments.some(e=>e.display_name.toLocaleLowerCase(language).includes(search.toLocaleLowerCase(language)))&&<p role="status">{p.none}</p>}</>}
 </main></div>{creation&&<Creation language={language} enabled={setup==='ready'} onClose={()=>{setCreation(false);void refreshMetadata();}}/>}
 {renaming&&<Rename language={language} environment={renaming} onClose={()=>setRenaming(null)} onRenamed={()=>{setRenaming(null);void refreshMetadata();}}/>}
 {stopPlan&&<dialog ref={stopDialog} onCancel={()=>setStopPlan(null)} aria-labelledby="stop-title"><h2 id="stop-title">{p.stopTitle}</h2><p>{p.stopDetail}</p><ul>{stopPlan.map(e=><li key={e.id}>{escaped(e.display_name)} <code>{e.id}</code></li>)}</ul><button onClick={()=>void stopListed()}>{p.stopAccept}</button><button autoFocus onClick={()=>setStopPlan(null)}>{p.cancel}</button></dialog>}</>;
}
const query=new URLSearchParams(location.search);
if(query.has('acl-probe')||query.has('foundation-ci')) {if(import.meta.env.VITE_FOUNDATION_CI==='1')void import('./selftest').then(module=>module.run(query.has('acl-probe')));}
createRoot(document.getElementById('root')!).render(<App/>);
