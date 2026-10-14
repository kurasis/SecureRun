import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { applyEvent } from '../ui/state.ts';
import { strings } from '../ui/strings.ts';
import type { Snapshot, StateEvent } from '../ui/contracts.ts';
const snapshot:Snapshot={engine_generation:2,mode:'READ_ONLY_SETUP',mutations_available:false,engine_operations_available:false,reason:'CAPABILITY_UNAVAILABLE',environments:[{id:'fixture',display_name:'Fixture',generation:3,desired_revision:4,verified_revision:null,lifecycle:'ACTIVE',activity:'RUNNING',eligibility:'BLOCKED',current_operation:null,last_sequence:10}]};
const event:StateEvent={environment_id:'fixture',environment_generation:3,engine_generation:2,sequence:11,activity:'IDLE',eligibility:'UNVERIFIED',expected_revision:4,operation_id:null};
test('T56 late engine, environment, revision, sequence and operation events are ignored',()=>{
  for(const change of [{engine_generation:1},{environment_generation:2},{expected_revision:3},{sequence:9},{operation_id:'older'}]) assert.equal(applyEvent(snapshot,{...event,...change}),snapshot);
  assert.equal(applyEvent(snapshot,event).environments[0].activity,'IDLE');assert.equal(snapshot.environments[0].activity,'RUNNING');
});
test('English and Russian dictionaries have complete matching keys',()=>{assert.deepEqual(Object.keys(strings.en),Object.keys(strings.ru));});
