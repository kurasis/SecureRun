"""Retain exact-source P08 production evidence after matching P03 through P07."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IDS = {f'T{i:02}' for i in (6,18,24,25,26,28,33,34,36,42,43,48,55,56,61,64,65)}
REQUIRED = {'remove_clears_before_definition_deletion_and_keeps_audit_tombstone', 'archive_retains_data_blocks_manager_launch_and_unarchive_revalidates', 'disposable_waits_for_background_descendants_and_survives_manager_crash', 'current_automation_and_auto_delete_drift_block_cleanup_without_silent_repair', 'old_confirmation_and_import_operation_cannot_mutate_reset_generation', 'original_sandman_coexists_without_automatic_recovery_or_deletion', 'reset_invalidates_imported_executable_and_old_transfer_references', 'hardlinks_and_reparse_traversal_rejected_before_native_dispatch', 'reset_preserves_definition_applications_and_retained_root_identity', 'native_confirmation_names_environment_and_cancel_consumes_plan', 'forged_confirmation_and_stale_generation_refused_without_mutation', 'persistent_workload_survives_actual_normal_window_close', 'root_substitution_and_unsupported_image_configuration_never_authorize_cleanup', 'cleanup_requires_complete_idle_across_actual_windows_sessions', 'missing_ownership_database_cannot_adopt_or_remove_existing_box', 'missing_service_and_changed_original_cleanup_component_fail_closed'}
REQUIRED.add('normal_binary_cannot_activate_lifecycle_fault_checkpoints')
REQUIRED.add('disposable_import_and_independent_activity_remain_visible_after_restart')
REQUIRED.add('locked_file_cleanup_is_refused_or_visible_and_recovers_without_replay')
REQUIRED.update(f'real_cleanup_executor_interruption_{s}' for s in ('SnapshotCaptured','Fenced','Sealed','DispatchReserved','NativeReturned','Cleared','MetadataCommitted'))
REQUIRED.update(f'real_remove_interruption_{s}' for s in ('SnapshotCaptured','Fenced','Sealed','DispatchReserved','NativeReturned','Cleared','DefinitionRemoved','MetadataCommitted'))
REQUIRED.update(f'reset_reconciles_uncertain_launch_without_replay_{s}' for s in ('Reserved','Accepted'))
REQUIRED.update(f'reset_refuses_stale_export_recovery_{s}' for s in ('AfterRename','MidCopy'))

def read(path):
 return json.loads(path.read_text(encoding='utf-8-sig'))

def record(path, relative):
 data = path.read_bytes()
 return {'path':relative,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def check_target(folder,commit,machine):
 summary,cases=read(folder/'run-summary.json'),read(folder/'lifecycle-cases.json')
 if (summary['phase']!='P08' or summary['result']!='PASSED' or summary['manager_commit']!=commit
     or summary['pe_machine']!=machine or summary['failed']!=0 or summary['actor_failures']!=0
     or not summary['standard_user'] or summary['elevated_helper'] or summary['fault_feature_release_enabled'] or summary['os_security_settings_modified']):
  raise ValueError('P08 native source/result invalid')
 for key in ('manager_binary_sha256','fault_binary_sha256','boxed_stage_sha256'):
  if not re.fullmatch('[0-9a-f]{64}',summary[key]):raise ValueError('P08 binary provenance missing')
 if summary['manager_binary_sha256']==summary['fault_binary_sha256']:raise ValueError('P08 normal and fault binaries are not distinct')
 names=[c['name'] for c in cases]
 if (len(set(names))!=len(names) or not REQUIRED.issubset(names) or not IDS.issubset({identifier for c in cases for identifier in [c['id'],*c.get('also_ids',[])]})
     or any(c['status']!='PASSED' for c in cases) or summary['native_cases_passed']!=len(cases)):
  raise ValueError('P08 mandatory cases incomplete')
 by_name={c['name']:c['evidence'] for c in cases}
 for stage in ('SnapshotCaptured','Fenced','Sealed','DispatchReserved','NativeReturned','Cleared','MetadataCommitted'):
  proof=by_name[f'real_cleanup_executor_interruption_{stage}']
  if (not proof['real_executor_killed'] or proof['checkpoint']!=stage or not proof['controller_acl_restored']
      or not proof['recovery_inspection_only'] or not proof['old_cleanup_journal_after_new_reset_inspection_only'] or proof['replayed'] or not proof['fresh_explicit_cleanup']
      or proof['privileged_helper']):raise ValueError('P08 actual cleanup interruption/recovery absent')
  if not proof['competing_manager_refused'] or (stage in ('Fenced','Sealed','DispatchReserved') and proof['external_original_dispatch_rejected'] is not True):raise ValueError('P08 competing original/manager dispatch not refused')
 for stage in ('SnapshotCaptured','Fenced','Sealed','DispatchReserved','NativeReturned','Cleared','DefinitionRemoved','MetadataCommitted'):
  proof=by_name[f'real_remove_interruption_{stage}']
  if not all(proof[k] for k in ('real_executor_killed','competing_manager_refused','actual_definition_absent','metadata_reconciled_without_delete_replay','known_empty_root_retained')) or proof['checkpoint']!=stage:raise ValueError('P08 actual removal interruption absent')
 disposable=by_name['disposable_import_and_independent_activity_remain_visible_after_restart']
 if not all(disposable[k] for k in ('import_pending_before_first_target','fresh_process_reopened_state','launch_waited_for_explicit_resume','independent_original_client_observed','leftover_durable_after_independent_exit','data_preserved')) or disposable['automatic_cleanup']:raise ValueError('P08 disposable input/external activity was lost')
 hooks=by_name['current_automation_and_auto_delete_drift_block_cleanup_without_silent_repair']
 if not all(hooks[k] for k in ('stop_refused_unapproved_termination_hook','safe_stop_after_reviewed_hook_removal','current_hook_rejected','direct_delete_command_rejected','effective_inherited_hook_rejected','real_host_marker_fixture','confirmed_plan_revalidated_after_hook_drift','data_retained')) or hooks['host_hook_executed']:raise ValueError('P08 current/inherited cleanup consumer rejection absent')
 roots=by_name['root_substitution_and_unsupported_image_configuration_never_authorize_cleanup']
 if not roots['missing_root_not_recreated'] or not roots['unexpected_root_identity_refused'] or not roots['replacement_canary_preserved']:raise ValueError('P08 missing/replaced root was adopted')
 locked=by_name['locked_file_cleanup_is_refused_or_visible_and_recovers_without_replay']
 if not all(locked[k] for k in ('actual_no_delete_share_handle','locked_data_preserved','failure_visible','recovery_inspected_without_replay','fresh_explicit_cleanup_after_unlock')) or locked['outside_root_delete']:raise ValueError('P08 actual locked-file recovery absent')
 normal=by_name['normal_binary_cannot_activate_lifecycle_fault_checkpoints']
 if not normal['normal_production_binary'] or not normal['fault_variable_supplied'] or not normal['cleanup_completed'] or normal['fault_checkpoint_activated']:raise ValueError('P08 normal binary activated fault checkpoints')
 remove=by_name['remove_clears_before_definition_deletion_and_keeps_audit_tombstone']
 if not remove['real_native_remove_confirmation'] or not remove['native_cancel_preserved_definition']:raise ValueError('P08 native removal confirmation absent')
 native=by_name['native_confirmation_names_environment_and_cancel_consumes_plan']
 if not all(native[k] for k in ('real_native_dialog','normal_production_binary','affected_environment_uuid_visible','cancel_preserves_data','cancelled_plan_consumed','explicit_accept_completed_reset')) or native['renderer_confirmation_boolean']:raise ValueError('P08 native confirmation absent')
 sessions=by_name['cleanup_requires_complete_idle_across_actual_windows_sessions']
 if len(set(sessions['real_windows_sessions']))!=2 or 0 not in sessions['real_windows_sessions'] or not sessions['cleanup_refused_while_other_session_running'] or not sessions['complete_idle_before_actual_cleanup']:raise ValueError('P08 actual all-session refusal absent')
 for stage in ('Reserved','Accepted'):
  proof=by_name[f'reset_reconciles_uncertain_launch_without_replay_{stage}']
  if not all(proof[k] for k in ('actual_worker_killed','unknown_receipt_preserved','old_operation_refused','fresh_explicit_launch_boxed')) or proof['automatic_replay'] or proof['executions_before_reset']!=(1 if stage=='Accepted' else 0):raise ValueError('P08 uncertain launch replay/refusal invalid')
 for stage in ('AfterRename','MidCopy'):
  proof=by_name[f'reset_refuses_stale_export_recovery_{stage}']
  if not all(proof[k] for k in ('actual_worker_killed','generation_changed','recovery_and_discard_refused','host_artifact_unchanged')) or proof['automatic_replay'] or proof['path_pattern_delete']:raise ValueError('P08 stale export recovery invalid')
 for mode in ('normal','fault','sessions'):
  actor=read(folder/f'standard-{mode}.json')
  if actor['status']!='PASSED' or not actor['standard_user'] or actor['failed']!=0:raise ValueError('P08 ordinary-user actor failed')
 return summary

def retain(download,commit,run_id):
 if not re.fullmatch('[0-9a-f]{40}',commit) or run_id<=0:raise ValueError('P08 exact source/run required')
 run=json.loads(subprocess.check_output(['gh','run','view',str(run_id),'--json','headSha,status,conclusion'],cwd=ROOT))
 if run!={'headSha':commit,'status':'completed','conclusion':'success'}:raise ValueError('P08 exact source did not complete successfully')
 for phase in ('p03','p04','p05','p06','p07'):
  dependency=read(ROOT/f'docs/evidence/{phase}/manifest.json')
  if dependency['result']!='DONE' or dependency['tested_commit']!=commit:raise ValueError('P08 requires matching current P03/P04/P05/P06/P07 regression')
 evidence=ROOT/'docs/evidence/p08';old=read(evidence/'manifest.json') if (evidence/'manifest.json').exists() else {};known={f['path']:f for f in old.get('files',[])};targets=[];copies=[]
 for runner,machine in (('windows-2025','8664'),('windows-11-arm','aa64')):
  folder=download/f'p08-{runner}-{commit}';summary=check_target(folder,commit,machine);relative=f'completion-{commit[:7]}/{runner}'
  for source in sorted(folder.glob('*.json')):
   destination=evidence/relative/source.name
   if destination.exists() and destination.read_bytes()!=source.read_bytes():raise ValueError('Historical P08 proof cannot be overwritten')
   copies.append((source,destination));known[f'{relative}/{source.name}']=record(source,f'{relative}/{source.name}')
  targets.append({'runner':runner,'evidence_directory':relative,'summary':summary})
 paths=['Cargo.toml','Cargo.lock','rust-toolchain.toml','.github/workflows/p08.yml']
 paths += [p.relative_to(ROOT).as_posix() for base in ('crates','src-tauri','ui','tools') for p in sorted((ROOT/base).rglob('*')) if p.is_file() and 'gen' not in p.parts and p.suffix in {'.rs','.toml','.json','.ts','.tsx','.css','.c','.cs','.ps1','.py'}]
 sources=[]
 for path in paths:
  if (ROOT/path).read_bytes()!=subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=ROOT):raise ValueError(f'Stale P08 source: {path}')
  sources.append(record(ROOT/path,path))
 for source,destination in copies:
  destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
 evidence.mkdir(parents=True,exist_ok=True)
 manifest={'phase':'P08','result':'DONE','tested_commit':commit,'run_id':run_id,'url':f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}','targets':targets,'files':list(known.values()),'tested_sources':sources,'production_acceptance_scenarios_passed':0,'note':'Production lifecycle paths; T48 packaging finishes in P11 and installed-candidate acceptance remains P12.','historical_runs':old.get('historical_runs',[])+([{key:old[key] for key in ('tested_commit','run_id','url','result','note') if key in old}] if old.get('tested_commit') and old['tested_commit']!=commit else [])}
 (evidence/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(targets,indent=2))

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--download-directory',type=Path,required=True);parser.add_argument('--tested-commit',required=True);parser.add_argument('--run-id',type=int,required=True);args=parser.parse_args();retain(args.download_directory,args.tested_commit,args.run_id)
