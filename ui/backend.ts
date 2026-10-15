import {invoke as nativeInvoke,type InvokeArgs} from '@tauri-apps/api/core';
// Scheduling is UX only. Every backend operation independently authorizes scope.
let tail:Promise<unknown>=Promise.resolve();
const managed=new Set(['policy_request','control_request','files_request','lifecycle_request','select_policy_path']);
export function invoke<T=unknown>(command:string,args?:InvokeArgs):Promise<T> {
 const action=(args as {request?:{action?:string}}|undefined)?.request?.action;
 const notify=(result:Promise<T>)=>result.then(value=>{
  if(managed.has(command)&&action&&!['LIST','STATUS','INSPECT','PREVIEW'].includes(action))window.dispatchEvent(new Event('securerun:managed-state'));
  return value;
 });
 if(!managed.has(command)||(command==='files_request'&&action==='CANCEL'))return notify(nativeInvoke<T>(command,args));
 const run=()=>nativeInvoke<T>(command,args);const result=tail.then(run,run);tail=result.catch(()=>{});return notify(result);
}
