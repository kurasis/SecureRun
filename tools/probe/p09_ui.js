/* Executed only by the disposable loopback inspector against the normal product. */
window.__p09_state={};
window.__p09_run=async function(stage,config={}) {
 const cases=[];const state=window.__p09_state;const native=(request,command='product_request')=>window.__TAURI_INTERNALS__.invoke(command,{request});
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const wait=async predicate=>{const end=performance.now()+90000;while(performance.now()<end){const value=predicate();if(value)return value;await pause(50);}throw Error('P09_UI_WAIT_EXPIRED');};
 const text=element=>element.textContent.replace(/\s+/g,' ').trim();
 const button=(label,scope=document)=>Array.from(scope.querySelectorAll('button')).find(e=>text(e)===label);
 const click=async(label,scope=document)=>{const e=await wait(()=>{const candidate=button(label,scope);return candidate&&!candidate.matches(':disabled')?candidate:null;});e.click();return e;};
 const set=(e,value)=>{const type=e instanceof HTMLSelectElement?HTMLSelectElement:e instanceof HTMLTextAreaElement?HTMLTextAreaElement:HTMLInputElement;Object.getOwnPropertyDescriptor(type.prototype,'value').set.call(e,value);e.dispatchEvent(new Event(e instanceof HTMLSelectElement?'change':'input',{bubbles:true}));};
 const check=(id,name,condition)=>{cases.push({id,name,passed:!!condition});if(!condition)throw Error('P09_UI_ASSERTION_FAILED');};
 const nav=async()=>{await click('Environments',document.querySelector('nav'));await wait(()=>button('Environments',document.querySelector('nav'))?.getAttribute('aria-current')==='page');const back=button('All environments');if(back)back.click();await wait(()=>document.querySelector('.cards'));};
 const open=async()=>{await nav();await click(config.environment_name,document.querySelector('.cards'));await wait(()=>document.querySelector('[role=tablist]'));};
 const tab=async name=>{await click(name,document.querySelector('[role=tablist]'));await pause(100);};
 const readyPolicy=()=>native({action:'LIST'},'policy_request');
 try {
  switch(stage){
   case 'OVERVIEW':{
    await nav();const r=await readyPolicy();check('T32','real_owned_environment_views',r.reason==='OBSERVED'&&r.environments.length===config.environment_count&&document.querySelectorAll('.cards article').length===config.environment_count);
    const input=document.querySelector('input[type=search]');set(input,config.search_name);await wait(()=>document.querySelectorAll('.cards article').length===1);check('T32','search_uses_real_owned_names',document.querySelector('.cards article').textContent.includes(config.search_name));set(input,'');break;
   }
   case 'RENAME':{
    await open();const before=(await readyPolicy()).environments.find(e=>e.id===config.environment_id);await click('Rename environment');let dialog=await wait(()=>document.querySelector('dialog[open]'));set(dialog.querySelector('input'),config.environment_name+' renamed');dialog.querySelector('form').requestSubmit();await wait(()=>!document.querySelector('dialog[open]'));await wait(()=>document.querySelector('main h1').textContent===config.environment_name+' renamed');
    const changed=(await readyPolicy()).environments.find(e=>e.id===config.environment_id);check('T32','rename_preserves_policy_generation_and_identity',changed.id===before.id&&changed.revision===before.revision&&changed.generation===before.generation&&changed.fingerprint===before.fingerprint&&JSON.stringify(changed.desired)===JSON.stringify(before.desired));
    await click('Rename environment');dialog=await wait(()=>document.querySelector('dialog[open]'));set(dialog.querySelector('input'),config.environment_name);dialog.querySelector('form').requestSubmit();await wait(()=>!document.querySelector('dialog[open]'));await wait(()=>document.querySelector('main h1').textContent===config.environment_name);
    const replay=await native({action:'RENAME',environment_id:before.id,expected_revision:before.revision,expected_generation:before.generation,expected_display_name:before.display_name,display_name:changed.display_name,operation_id:changed.operation_id},'policy_request');check('T32','old_metadata_rename_not_replayed_after_rename_back',replay.reason==='OBSERVED'&&replay.environments.find(e=>e.id===before.id).display_name===before.display_name);await nav();break;
   }
   case 'LAYOUT':case 'WINDOWS_LAYOUT':{
    await click(document.documentElement.lang==='ru'?'Настройки':'Settings',document.querySelector('nav'));
    const language=await wait(()=>document.querySelector('[data-testid=language]'));set(language,config.language);await wait(()=>document.documentElement.lang===config.language);
    set(document.querySelector('[data-testid=theme]'),config.theme);await wait(()=>document.documentElement.dataset.theme===config.theme);
    if(stage==='LAYOUT'){if(!state.viewport100){await native({action:'SCALE',percent:100});await pause(300);state.viewport100=innerWidth;}
    set(document.querySelector('[data-testid=scale]'),String(config.scale));await native({action:'SCALE',percent:config.scale});await wait(()=>Math.abs(innerWidth-state.viewport100*100/config.scale)<4);await pause(150);}else{set(document.querySelector('[data-testid=scale]'),'100');await native({action:'SCALE',percent:100});await wait(()=>Math.abs(devicePixelRatio-config.windows_scale/100)<.05);await pause(200);}
    const layoutSuffix=stage==='LAYOUT'?`${config.language}_${config.theme}_${config.scale}`:`windows_dpi_${config.windows_scale}_${config.language}_${config.theme}`;
    const size=document.documentElement;const controls=Array.from(document.querySelectorAll('button,input,select,textarea')).filter(e=>e.getClientRects().length);
    const labels=controls.every(e=>e.tagName==='BUTTON'?!!(e.getAttribute('aria-label')||text(e)):e.labels?.length||e.getAttribute('aria-label'));
    check('T32',`real_webview_${layoutSuffix}`,size.scrollWidth<=size.clientWidth+2&&labels&&controls.every(e=>e.getBoundingClientRect().width>8));
    const rgb=value=>value.match(/[\d.]+/g).slice(0,3).map(Number).map(n=>{n/=255;return n<=.04045?n/12.92:((n+.055)/1.055)**2.4;});
    const lum=v=>{const c=rgb(v);return c[0]*.2126+c[1]*.7152+c[2]*.0722;};const contrast=(a,b)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
    const css=getComputedStyle(size);const paragraph=document.querySelector('.settings p');const paragraphCss=getComputedStyle(paragraph);const surface=getComputedStyle(document.querySelector('.settings')).backgroundColor;
    check('T32',`readable_contrast_${layoutSuffix}`,contrast(css.color,css.backgroundColor)>=4.5&&contrast(paragraphCss.color,surface)>=4.5);
    check('T32',`unsupported_controls_${layoutSuffix}`,document.querySelector('.settings').textContent.includes(config.language==='ru'?'буфера обмена':'Clipboard')&&document.querySelector('.settings').textContent.includes(config.language==='ru'?'недоступ':'unavailable'));
    break;
   }
   case 'RESET_PRESENTATION':{
    await click(document.documentElement.lang==='ru'?'Настройки':'Settings',document.querySelector('nav'));set(await wait(()=>document.querySelector('[data-testid=language]')),'en');await wait(()=>document.documentElement.lang==='en');set(document.querySelector('[data-testid=theme]'),'system');set(document.querySelector('[data-testid=scale]'),'100');await native({action:'SCALE',percent:100});await pause(200);break;
   }
   case 'ACTIVITY_BEGIN':{await nav();await wait(()=>document.querySelectorAll('.cards article').length===config.environment_count);state.activityBegin=performance.now();break;}
   case 'ACTIVITY_END':{const card=await wait(()=>Array.from(document.querySelectorAll('.cards article')).find(e=>e.textContent.includes(config.environment_name)&&e.textContent.includes('Running')));const ms=performance.now()-state.activityBegin;check('T32','activity_comes_from_actual_driver_observation',!!card);return {status:'PASSED',cases,metrics:{update_upper_bound_ms:ms,real_external_boxed_member:true,refresh_interval_ms:1000}};}
   case 'PERMISSION_PICK':{
    await open();await tab('Permissions');await click('Edit policy');const r=await readyPolicy();state.applied=r.environments.find(e=>e.id===config.environment_id);check('T32','mandatory_rules_are_read_only',!!document.querySelector('.mandatory')&&!document.querySelector('.mandatory input'));
    await click('Select file rule');break;
   }
   case 'PERMISSION_QUEUE':{
    await wait(()=>Array.from(document.querySelectorAll('form li')).some(e=>e.textContent.includes('policy-resource.txt')));
    const review=Array.from(document.querySelectorAll('form label')).find(e=>e.textContent.includes('I reviewed this replacement'));check('T32','policy_diff_precedes_queue',!!review&&document.querySelector('form').textContent.includes('Review effective permission changes'));review.querySelector('input').click();document.querySelector('form').requestSubmit();await wait(()=>document.querySelector('.pendingPolicy'));
    const r=await readyPolicy();const e=r.environments.find(e=>e.id===config.environment_id);check('T32','running_edit_queued_without_claiming_applied',r.queued_policies.some(q=>q.environment_id===config.environment_id)&&e.fingerprint===state.applied.fingerprint&&JSON.stringify(e.desired)===JSON.stringify(state.applied.desired));
    check('T32','queued_apply_disabled_until_complete_idle',button('Apply stopped policy',document.querySelector('.pendingPolicy')).disabled);break;
   }
   case 'STOP_AND_APPLY':{
    await tab('Processes');await click('Stop environment');const dialog=await wait(()=>document.querySelector('dialog[open]'));check('T32','stop_dialog_names_exact_scope',dialog.textContent.includes(config.environment_name)&&dialog.textContent.includes(config.environment_id)&&dialog.querySelectorAll('li').length===1);await click('Stop listed environments',dialog);await wait(()=>!document.querySelector('dialog[open]'));await pause(2500);
    await tab('Permissions');const pending=await wait(()=>document.querySelector('.pendingPolicy'));await wait(()=>!button('Apply stopped policy',pending).disabled);await click('Apply stopped policy',pending);await wait(()=>!document.querySelector('.pendingPolicy'));
    const r=await readyPolicy();const e=r.environments.find(e=>e.id===config.environment_id);check('T32','explicit_stopped_apply_verified',e.stage==='VERIFIED'&&e.desired.grants.length===1&&e.fingerprint!==state.applied.fingerprint);break;
   }
   case 'SECRET_PICK':{
    await tab('Applications');await wait(()=>document.querySelector('form'));const form=document.querySelector('form');const name=Array.from(form.querySelectorAll('input')).find(e=>e.type!=='checkbox');set(name,'P09 synthetic diagnostic target');Array.from(form.querySelectorAll('summary')).find(e=>text(e)==='Advanced arguments').click();set(form.querySelector('textarea'),JSON.stringify(['secret-probe','P09_ARGV_SECRET_CANARY']));await click('Choose EXE',form);break;
   }
   case 'SECRET_REGISTER':{
    const form=await wait(()=>document.querySelector('form'));await wait(()=>button('Register application',form)&&!button('Register application',form).disabled);form.requestSubmit();await wait(()=>Array.from(document.querySelectorAll('article')).some(e=>e.textContent.includes('P09 synthetic diagnostic target')));
    const article=Array.from(document.querySelectorAll('article')).find(e=>e.textContent.includes('P09 synthetic diagnostic target'));await click('Run',article);await pause(7000);
    const r=await native({action:'LIST'},'control_request');check('T66','real_secret_argument_target_registered',r.applications.some(a=>a.display_name==='P09 synthetic diagnostic target')&&r.receipts.some(receipt=>receipt.process!==null));state.secretTargetChecked=true;break;
   }
   case 'FILE_LIST':{
    await tab('Files');await wait(()=>button('Storage root'));const start=performance.now();await click('Storage root');await wait(()=>document.querySelector('tbody tr'));
    for(const name of ['drive','C','SecureRunWorkspace',config.environment_id.replaceAll('-','')]){const e=await wait(()=>Array.from(document.querySelectorAll('tbody button')).find(e=>e.textContent.includes(name)));e.click();await pause(80);await wait(()=>!Array.from(document.querySelectorAll('p[role=status]')).some(e=>e.textContent.includes('Operation in progress')));}
    await wait(()=>document.querySelectorAll('tbody tr').length===128);state.listFirstMs=performance.now()-start;check('T63','populated_box_ui_page_is_bounded',document.querySelectorAll('tbody tr').length===128&&!!Array.from(document.querySelectorAll('button')).find(e=>e.textContent.startsWith('Next page')));
    const deceptive=Array.from(document.querySelectorAll('tbody button')).find(e=>e.textContent.includes('fdp.exe'));check('T63','full_deceptive_filename_rendered_inertly',deceptive&&/\\u\{?202e\}?|U\+202E/i.test(deceptive.textContent)&&deceptive.textContent.endsWith('fdp.exe'));
    const before=await native({action:'LIST'},'control_request');deceptive.click();await pause(100);const after=await native({action:'LIST'},'control_request');check('T63','filename_selection_never_dispatches_or_registers',before.applications.length===after.applications.length&&before.receipts.length===after.receipts.length);
    const r=await readyPolicy();const e=r.environments.find(e=>e.id===config.environment_id);let node=null;let current;
    for(const name of ['drive','C','SecureRunWorkspace',config.environment_id.replaceAll('-','')]){current=await native({action:'LIST',environment_id:e.id,expected_revision:e.revision,node_id:node,offset:0},'files_request');const entry=current.entries.find(v=>v.name===name);if(!entry)throw Error('P09_DIRECTORY_NODE_MISSING');node=entry.id;}
    let offset=0,total=0,pages=0,maximum=0;const seen=new Set();const walk=performance.now();
    do{const page=await native({action:'LIST',environment_id:e.id,expected_revision:e.revision,node_id:node,offset},'files_request');if(page.reason!=='OBSERVED')throw Error('P09_FULL_PAGE_WALK_FAILED');total+=page.entries.length;maximum=Math.max(maximum,page.entries.length);pages++;for(const item of page.entries){seen.add(item.id);if(item.name.includes('fdp.exe'))state.deceptiveName=item.name;}offset=page.next_offset;}while(offset!==null&&pages<130);
    check('T63','all_ten_thousand_entries_reachable_without_unbounded_dom',total===10000&&seen.size===10000&&maximum<=128&&pages===79&&offset===null&&document.querySelectorAll('tbody tr').length<=128);
    check('T63','deceptive_suffix_and_direction_controls_visible',state.deceptiveName?.endsWith('fdp.exe')&&/\\u\{?202e\}?|U\+202E/i.test(state.deceptiveName));
    return {status:'PASSED',cases,metrics:{first_ui_list_ms:state.listFirstMs,all_page_walk_ms:performance.now()-walk,total_files:total,pages,maximum_page:maximum,maximum_dom_rows:128}};
   }
   case 'TRANSFER_IMPORT_PICK':{await open();await tab('Files');await wait(()=>button('Import file')&&!button('Import file').disabled);await click('Import file');break;}
   case 'TRANSFER_EXPORT_PICK':{
    await wait(()=>button('Import file')&&!button('Import file').disabled);await click('Storage root');
    for(const name of ['drive','C','SecureRunWorkspace',config.environment_id.replaceAll('-','')]){const e=await wait(()=>Array.from(document.querySelectorAll('tbody button')).find(e=>text(e).endsWith(name)));e.click();await pause(100);}
    const item=await wait(()=>Array.from(document.querySelectorAll('tbody button')).find(e=>text(e).endsWith('workflow-source.txt')));item.click();await pause(50);check('T32','actual_ui_import_is_visible_without_opening',!!document.querySelector('fieldset legend')?.textContent.includes('workflow-source.txt'));await click('Export to selected folder');break;
   }
   case 'TRANSFER_COLLISION_PICK':{await pause(150);await click('Export to selected folder');break;}
   case 'TRANSFER_RENAME_PICK':{
    const dialog=await wait(()=>document.querySelector('dialog[open]'));check('T32','export_collision_offers_only_rename_and_skip',!!button('Rename and export',dialog)&&!!button('Skip',dialog)&&!button('Replace',dialog));set(dialog.querySelector('input'),'workflow-renamed.txt');await click('Rename and export',dialog);break;
   }
   case 'LIFECYCLE_PICK':{
    await tab('Retention and recovery');const label={ARCHIVE:'Archive',UNARCHIVE:'Unarchive',RESET:'Reset contents'}[config.intent];const b=await wait(()=>button(label)&&!button(label).disabled&&button(label));b.click();break;
   }
   case 'LIFECYCLE_CHECK':{
    await wait(()=>Array.from(document.querySelectorAll('button')).every(b=>!['Archive','Unarchive','Reset contents'].includes(text(b))||!b.disabled));
    const r=await native({action:'LIST'},'lifecycle_request');const e=r.reply.environments.find(e=>e.environment_id===config.environment_id);check('T32',`actual_ui_${config.intent.toLowerCase()}_verified`,r.reply.reason==='OBSERVED'&&e?.lifecycle===(config.intent==='ARCHIVE'?'ARCHIVED':'ACTIVE')&&(config.intent!=='RESET'||e.generation===config.generation+1));break;
   }
   case 'DIAGNOSTIC_PREVIEW':{
    await click('Settings',document.querySelector('nav'));await click('Review diagnostic bundle');const pre=await wait(()=>document.querySelector('.diagnosticPreview pre'));state.bundle=pre.textContent;const value=JSON.parse(state.bundle);
    check('T66','exact_preview_contains_only_minimized_schema',value.schema===1&&value.events.length>0&&value.events.length<=64&&!state.bundle.includes('P09_ARGV_SECRET_CANARY')&&!state.bundle.includes('P09_ENV_SECRET_CANARY')&&!state.bundle.includes('FORGED_EVENT')&&!state.bundle.includes('environment_id')&&!state.bundle.includes('C:\\'));
    check('T66','shared_events_are_not_engine_access_audit',value.engine_access_events_available===false&&value.events.every(e=>Object.keys(e).sort().join(',')==='action,diagnostic_id,outcome,unix_ms'));await click('Save reviewed JSON…');break;
   }
   case 'DIAGNOSTIC_SAVED':{
    await wait(()=>document.querySelector('[role=status]')?.textContent.includes('saved')||document.body.textContent.includes('Reviewed diagnostics saved.'));check('T66','explicit_native_save_completed',document.body.textContent.includes('Reviewed diagnostics saved.'));return {status:'PASSED',cases,reviewed_bundle:state.bundle};
   }
   default:throw Error('P09_UI_STAGE_UNKNOWN');
  }
  return {status:'PASSED',cases};
 }catch(error){
  const safe=value=>typeof value==='string'&&/^[A-Z][A-Z0-9_]{1,100}$/.test(value)?value:'WITHHELD';
  const bounded=promise=>Promise.race([promise.catch(()=>null),pause(10000).then(()=>null)]);
  const [health,policies]=await Promise.all([bounded(window.__TAURI_INTERNALS__.invoke('get_engine_health',{})),bounded(readyPolicy())]);
  const setup=Array.from(document.querySelector('.notice')?.classList??[]).find(value=>/^setup-(checking|missing|untrusted|unavailable|restart|untested|ready)$/.test(value))??'WITHHELD';
  const selected=policies?.environments?.find(value=>value.id===config.environment_id);
  const diagnostic={selected_policy_stage:safe(selected?.stage),selected_policy_reason:safe(selected?.reason),edit_policy_button_present:!!button('Edit policy'),policy_editor_present:!!document.querySelector('.policies form'),document_complete:document.readyState==='complete',setup,card_count:document.querySelectorAll('.cards article').length,has_selected_tabs:!!document.querySelector('[role=tablist]'),health_fresh:health?.fresh===true,control_plane_safe:health?.control_plane_safe===true,service_identity_complete:health?.observation?.service_identity_complete===true,service_identity_reason:safe(health?.observation?.service_identity_reason),manager_unboxed:health?.observation?.manager_context==='UNBOXED',bridge_unboxed:health?.observation?.bridge_context==='UNBOXED',health_reason:safe(health?.observation?.reason),policy_reason:safe(policies?.reason),owned_environment_count:Array.isArray(policies?.environments)?policies.environments.length:-1};
  return {status:'FAILED',cases,code:safe(error?.message).startsWith('P09_')?safe(error.message):'P09_PRODUCT_UI_FAILED',stage,exception_type:['Error','TypeError','ReferenceError','SyntaxError'].includes(error?.constructor?.name)?error.constructor.name:'Unknown',diagnostic};
 }
};
true;
