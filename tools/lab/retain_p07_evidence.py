"""Retain exact-source P07 production evidence after matching P03 through P06."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IDS = {f'T{i:02}' for i in (20,21,22,23,42,43,44,45,49,63,64,65)}
REQUIRED = {
 'production_export_correct_bytes_and_motw',
 'import_collision_duplicate_operation_and_regular_file_only',
 'unsafe_names_and_extensions',
 'hardlinks_streams_reparse_and_sensitive_destinations_rejected',
 'inert_metadata_for_html_svg_shortcut_and_executable',
 'forged_file_and_raw_path_fields_rejected',
 'existing_destination_and_restricted_zone_preserved',
 'running_environment_blocks_file_mutation',
 'greater_than_four_gib_streamed_with_bounded_memory',
 'replaced_staging_file_never_deleted_or_adopted',
 'discard_only_verified_staging_identity',
 'actual_collision_inserted_before_no_replace_rename',
 'actual_transfer_cancel_retains_marked_partial',
 'marker_failure_before_any_payload',
 'actual_ntfs_disk_full_during_streaming_copy',
 'source_and_destination_replacement_denied_while_copy_handles_held',
 'old_generation_transfer_never_mutates_recreated_root',
 *(f'real_crash_{stage}' for stage in ('BeforeMark','AfterMark','MidCopy','BeforeRename','AfterRename')),
}

def read(path):
 return json.loads(path.read_text(encoding='utf-8-sig'))

def record(path, relative):
 data = path.read_bytes()
 return {'path':relative,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def check_target(folder,commit,machine):
 summary,cases=read(folder/'run-summary.json'),read(folder/'file-cases.json')
 if (summary['phase']!='P07' or summary['result']!='PASSED' or summary['manager_commit']!=commit
     or summary['pe_machine']!=machine or summary['failed']!=0 or summary['actor_failures']!=0
     or not summary['standard_user'] or summary['elevated_helper'] or summary['fault_feature_release_enabled'] or summary['os_security_settings_modified']):
  raise ValueError('P07 native source/result invalid')
 for key in ('manager_binary_sha256','fault_binary_sha256'):
  if not re.fullmatch('[0-9a-f]{64}',summary[key]):raise ValueError('P07 binary provenance missing')
 names=[c['name'] for c in cases]
 if (len(set(names))!=len(names) or not REQUIRED.issubset(names) or not IDS.issubset({c['id'] for c in cases})
     or any(c['status']!='PASSED' for c in cases) or summary['native_cases_passed']!=len(cases)):
  raise ValueError('P07 mandatory cases incomplete')
 by_name={c['name']:c['evidence'] for c in cases}
 architectures=['securerun-launch-probe','securerun-launch-probe-x86']
 if machine=='aa64':architectures.append('securerun-launch-probe-x64')
 for architecture in architectures:
  proof=by_name[f'imported_boxed_exe_{architecture}']
  if (not proof['boxed'] or not proof['logical_launch'] or not proof['original_get_handle_path_verified']
      or proof['physical_host_fallback'] or not proof['host_report_absent']):raise ValueError('P07 original engine boxed mapping/launch absent')
 for stage in ('BeforeMark','AfterMark','MidCopy','BeforeRename','AfterRename'):
  proof=by_name[f'real_crash_{stage}']
  if (not proof['real_worker_killed'] or proof['checkpoint']!=stage or proof['replayed']
      or proof['payload_before_marker'] or not proof['no_overwrite']
      or proof['recovered_state']!=('COMPLETE_RECOVERED' if stage=='AfterRename' else 'INCOMPLETE_RETAINED')):
   raise ValueError('P07 actual crash recovery missing')
 large=by_name['greater_than_four_gib_streamed_with_bounded_memory']
 if int(large['logical_size'])<=2**32 or not large['actual_sparse_source'] or not large['equal_hash'] or large['chunk_bytes']!=1048576:
  raise ValueError('P07 large sparse streaming not proven')
 for mode in ('normal','fault'):
  actor=read(folder/f'standard-{mode}.json')
  if actor['status']!='PASSED' or not actor['standard_user'] or actor['failed']!=0:raise ValueError('P07 ordinary-user actor failed')
 return summary

def retain(download,commit,run_id):
 if not re.fullmatch('[0-9a-f]{40}',commit) or run_id<=0:raise ValueError('P07 exact source/run required')
 run=json.loads(subprocess.check_output(['gh','run','view',str(run_id),'--json','headSha,status,conclusion'],cwd=ROOT))
 if run!={'headSha':commit,'status':'completed','conclusion':'success'}:raise ValueError('P07 exact source did not complete successfully')
 for phase in ('p03','p04','p05','p06'):
  dependency=read(ROOT/f'docs/evidence/{phase}/manifest.json')
  if dependency['result']!='DONE' or dependency['tested_commit']!=commit:raise ValueError('P07 requires matching current P03/P04/P05/P06 regression')
 evidence=ROOT/'docs/evidence/p07';old=read(evidence/'manifest.json') if (evidence/'manifest.json').exists() else {};known={f['path']:f for f in old.get('files',[])};targets=[];copies=[]
 for runner,machine in (('windows-2025','8664'),('windows-11-arm','aa64')):
  folder=download/f'p07-{runner}-{commit}';summary=check_target(folder,commit,machine);relative=f'completion-{commit[:7]}/{runner}'
  for source in sorted(folder.glob('*.json')):
   destination=evidence/relative/source.name
   if destination.exists() and destination.read_bytes()!=source.read_bytes():raise ValueError('Historical P07 proof cannot be overwritten')
   copies.append((source,destination));known[f'{relative}/{source.name}']=record(source,f'{relative}/{source.name}')
  targets.append({'runner':runner,'evidence_directory':relative,'summary':summary})
 paths=['Cargo.toml','Cargo.lock','rust-toolchain.toml','.github/workflows/p07.yml']
 paths += [p.relative_to(ROOT).as_posix() for base in ('crates','src-tauri','ui','tools') for p in sorted((ROOT/base).rglob('*')) if p.is_file() and 'gen' not in p.parts and p.suffix in {'.rs','.toml','.json','.ts','.tsx','.css','.c','.cs','.ps1','.py'}]
 sources=[]
 for path in paths:
  if (ROOT/path).read_bytes()!=subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=ROOT):raise ValueError(f'Stale P07 source: {path}')
  sources.append(record(ROOT/path,path))
 for source,destination in copies:
  destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
 evidence.mkdir(parents=True,exist_ok=True)
 manifest={'phase':'P07','result':'DONE','tested_commit':commit,'run_id':run_id,'url':f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}','targets':targets,'files':list(known.values()),'tested_sources':sources,'production_acceptance_scenarios_passed':0,'note':'Production file paths; reset-invalidates-reference finishes in P08 and installed-candidate acceptance remains P12.','historical_runs':old.get('historical_runs',[])+([{key:old[key] for key in ('tested_commit','run_id','url','result','note') if key in old}] if old.get('tested_commit') and old['tested_commit']!=commit else [])}
 (evidence/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(targets,indent=2))

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--download-directory',type=Path,required=True);parser.add_argument('--tested-commit',required=True);parser.add_argument('--run-id',type=int,required=True);args=parser.parse_args();retain(args.download_directory,args.tested_commit,args.run_id)
