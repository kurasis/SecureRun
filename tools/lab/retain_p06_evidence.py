"""Retain complete production P06 evidence; no mocked or stale gate promotion."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IDS = {f'T{i:02}' for i in (*range(1, 8), 19, 26, 36, 50, 54, 56, 61, 62)}
REQUIRED = {
    'missing_engine_production_launch_is_refused',
    'unloaded_original_driver_refuses_production_launch',
    'production_child_and_grandchild_membership',
    'background_child_keeps_environment_running',
    'stop_survives_launch_policy_ineligibility_without_entitlement',
    'duplicate_completed_launch_is_never_dispatched_twice',
    'stop_managed_preserves_unmanaged_box_and_host_process',
    'rapid_launch_stop_serializes_and_duplicate_scope_conflicts',
    'stopped_engine_service_never_dispatches_target',
    'changed_original_component_refuses_launch',
    'registered_target_replacement_is_refused',
    'invalid_exe_and_control_characters_are_refused',
    'target_cwd_is_separate_from_host_worker_cwd',
    'stale_application_revision_cannot_dispatch_after_policy_change',
    'actual_dispatch_interruption_reserved', 'actual_dispatch_interruption_accepted',
    'actual_scope_change_after_process_handles_retained',
    'exited_retained_object_does_not_retarget_unrelated_process',
    'production_stop_covers_two_actual_windows_sessions',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def check_target(folder, commit, machine):
    summary, cases = read(folder / 'run-summary.json'), read(folder / 'control-cases.json')
    if (summary['phase'] != 'P06' or summary['result'] != 'PASSED' or summary['manager_commit'] != commit
            or summary['pe_machine'] != machine or summary['failed'] != 0 or not summary['standard_user']
            or summary['elevated_helper'] or summary['fault_feature_release_enabled'] or summary['os_security_settings_modified']):
        raise ValueError('P06 source/architecture/native outcome invalid')
    for key in ('manager_binary_sha256', 'fault_binary_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', summary[key]):
            raise ValueError('P06 compiled binary provenance absent')
    names = [c['name'] for c in cases]
    if (len(names) != len(set(names)) or not REQUIRED.issubset(names)
            or not IDS.issubset({c['id'] for c in cases}) or any(c['status'] != 'PASSED' for c in cases)
            or summary['native_cases_passed'] != len(cases)):
        raise ValueError('P06 mandatory production cases incomplete')
    architectures = ['securerun-launch-probe', 'securerun-launch-probe-x86']
    if machine == 'aa64':
        architectures.append('securerun-launch-probe-x64')
    if not {f'exact_arguments_{arch}' for arch in architectures}.issubset(names):
        raise ValueError('Actual native and emulated target PE evidence absent')
    by_name = {c['name']: c['evidence'] for c in cases}
    for mode, count in (('reserved', 0), ('accepted', 1)):
        proof = by_name[f'actual_dispatch_interruption_{mode}']
        if (not proof['real_worker_killed'] or proof['automatic_replay'] or proof['receipt_state'] != 'UNKNOWN'
                or proof['target_executions'] != count or proof['duplicate_deliveries'] < 3):
            raise ValueError('Actual uncertain-dispatch proof absent')
    stop = by_name['production_stop_covers_two_actual_windows_sessions']
    if (len(set(stop['real_windows_sessions'])) < 2 or 0 not in stop['real_windows_sessions']
            or not stop['same_owner_verified'] or stop['processes_after'] != 0 or not stop['stop_waits_completed']):
        raise ValueError('Actual same-owner multi-session Stop absent')
    for mode in ('normal', 'reserved', 'accepted', 'scope', 'sessions'):
        proof = read(folder / f'standard-{mode}.json')
        if proof['status'] != 'PASSED' or not proof['standard_user']:
            raise ValueError('P06 standard-user execution failed')
    return summary


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Exact P06 source/run required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'headSha,status,conclusion'], cwd=ROOT))
    if run != {'headSha': commit, 'status': 'completed', 'conclusion': 'success'}:
        raise ValueError('P06 exact source did not complete successfully')
    for phase in ('p03', 'p04', 'p05'):
        dependency = read(ROOT / f'docs/evidence/{phase}/manifest.json')
        if dependency['result'] != 'DONE' or dependency['tested_commit'] != commit:
            raise ValueError('P06 requires matching current P03/P04/P05 regression')
    evidence = ROOT / 'docs/evidence/p06'
    old = read(evidence / 'manifest.json') if (evidence / 'manifest.json').exists() else {}
    known = {f['path']: f for f in old.get('files', [])}
    targets, copies = [], []
    for runner, machine in (('windows-2025', '8664'), ('windows-11-arm', 'aa64')):
        folder = download / f'p06-{runner}-{commit}'
        summary = check_target(folder, commit, machine)
        relative = f'completion-{commit[:7]}/{runner}'
        for source in sorted(folder.glob('*.json')):
            destination = evidence / relative / source.name
            if destination.exists() and destination.read_bytes() != source.read_bytes():
                raise ValueError('Historical P06 proof cannot be overwritten')
            copies.append((source, destination))
            known[f'{relative}/{source.name}'] = record(source, f'{relative}/{source.name}')
        targets.append({'runner': runner, 'evidence_directory': relative, 'summary': summary})
    paths = ['Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', '.github/workflows/p06.yml']
    paths += [p.relative_to(ROOT).as_posix() for base in ('crates', 'src-tauri', 'ui', 'tools')
              for p in sorted((ROOT / base).rglob('*')) if p.is_file() and 'gen' not in p.parts
              and p.suffix in {'.rs', '.toml', '.json', '.ts', '.tsx', '.css', '.c', '.cs', '.ps1', '.py'}]
    sources = []
    for path in paths:
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError(f'Stale P06 source: {path}')
        sources.append(record(ROOT / path, path))
    for source, destination in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    manifest = {'phase': 'P06', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                'targets': targets, 'files': list(known.values()), 'tested_sources': sources,
                'production_acceptance_scenarios_passed': 0,
                'note': 'Production phase paths; final installed-candidate acceptance remains P12.',
                'historical_runs': old.get('historical_runs', []) + ([{key: old[key] for key in ('tested_commit', 'run_id', 'url', 'result', 'note') if key in old}] if old.get('tested_commit') and old['tested_commit'] != commit else [])}
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(targets, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
