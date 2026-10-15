import {strict as assert} from 'node:assert';
import {test} from 'node:test';
import {escaped,errorText,productText,setupState} from '../ui/product.ts';
import type {EngineHealth} from '../ui/contracts.ts';
const health=(change:Record<string,unknown>={})=>({fresh:true,control_plane_safe:true,observation:{trust:'VERIFIED',reason:'OBSERVED',service_running:true,driver_running:true,service_identity_complete:true,restart_required:false,...change}} as EngineHealth);
test('T63 complete Unicode suffixes survive while control and bidi characters are visible',()=>{
 assert.equal(escaped('Отчёт_α.png.exe'),'Отчёт_α.png.exe');
 assert.equal(escaped('invoice\u202Efdp.exe\nFORGED_EVENT'),'invoice[U+202E]fdp.exe[U+000A]FORGED_EVENT');
});
test('T32 setup status requires actual fresh trust, service and unboxed context',()=>{
 assert.equal(setupState(health(),true),'ready');
 assert.equal(setupState(health(),false),'checking');
 assert.equal(setupState(health({reason:'ENGINE_MISSING'}),true),'missing');
 assert.equal(setupState(health({reason:'ENGINE_VERSION_UNTESTED'}),true),'untested');
 assert.equal(setupState(health({reason:'SIGNATURE_INVALID'}),true),'untrusted');
 assert.equal(setupState(health({service_running:false}),true),'unavailable');
 assert.equal(setupState({...health(),control_plane_safe:false},true),'unavailable');
 assert.equal(setupState(health({restart_required:true}),true),'restart');
});
test('T15 product localization covers the same nonempty keys in English and Russian',()=>{
 assert.deepEqual(Object.keys(productText.en),Object.keys(productText.ru));
 for(const dict of Object.values(productText)) for(const value of Object.values(dict)) assert.ok(value.trim().length);
});
test('T61/T66 uncertain action guidance never suggests replay and never renders external text as its cause',()=>{
 const code='OUTCOME_UNKNOWN P09_SYNTHETIC_SECRET\nFORGED_EVENT';
 const text=errorText(code,'en');assert.match(text.cause,/may already have executed/);assert.match(text.next,/never replay/);assert.ok(!JSON.stringify(text).includes('P09_SYNTHETIC_SECRET'));
 assert.match(errorText('STALE_OPERATION','ru').next,/новый выбор/);
});
