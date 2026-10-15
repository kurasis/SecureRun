import {invoke as nativeInvoke,type InvokeArgs} from '@tauri-apps/api/core';
// Scheduling is UX only. Every backend operation independently authorizes scope.
let tail:Promise<unknown>=Promise.resolve();
const managed=new Set(['policy_request','control_request','files_request','lifecycle_request','select_policy_path']);
export function invoke<T=unknown>(command:string,args?:InvokeArgs):Promise<T> {
 const action=(args as {request?:{action?:string}}|undefined)?.request?.action;
 if(!managed.has(command)||(command==='files_request'&&action==='CANCEL'))return nativeInvoke<T>(command,args);
 const run=()=>nativeInvoke<T>(command,args);const result=tail.then(run,run);tail=result.catch(()=>{});return result;
}
