"""Retain current production P04 evidence, refusing failed or stale native runs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {
    'missing_engine_fail_closed', 'trusted_installed_components',
    'changed_component_rejected_before_loading', 'stopped_service_is_not_ready',
    'fresh_observation_after_service_restart', 'unavailable_driver_never_reports_idle',
    'bounded_typed_protocol_and_generation_tests',
    'optional_paid_capabilities_do_not_invent_entitlement',
    'hostile_cwd_path_and_dll_are_not_loaded', 'user_writable_installation_refused',
    'false_service_installation_metadata_refused',
    'unowned_configuration_roots_remain_read_only',
    'boxed_actual_manager_and_bridge_refuse_controls',
    'live_process_wrong_birth_cannot_be_attributed', 'exited_process_identity_is_not_reused',
    'standard_user_same_sid_in_two_actual_sessions',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}


def check_target(folder, commit, machine):
    summary, cases = read(folder / 'run-summary.json'), read(folder / 'observation-cases.json')
    if (summary['manager_commit'] != commit or summary['phase'] != 'P04'
            or summary['result'] != 'PASSED' or summary['pe_machine'] != machine
            or not re.fullmatch('[0-9a-f]{64}', summary['manager_binary_sha256'])
            or summary['adapter_tests_passed'] < 9 or summary['production_target_launches'] != 0
            or summary['production_mutations'] != 0 or summary['os_security_settings_modified']):
        raise ValueError('P04 native source/architecture/phase boundary invalid')
    if (not REQUIRED.issubset({c['name'] for c in cases}) or any(c['status'] != 'PASSED' for c in cases)
            or len(cases) != summary['native_cases_passed']):
        raise ValueError('Required production P04 cases did not pass')
    by_name = {c['name']: c['evidence'] for c in cases}
    trusted = by_name['trusted_installed_components']
    if trusted['trust'] != 'VERIFIED' or trusted['manager_context'] != 'UNBOXED' or trusted['bridge_context'] != 'UNBOXED':
        raise ValueError('Trusted production context not observed')
    boxed = by_name['boxed_actual_manager_and_bridge_refuse_controls']
    if (not boxed['actual_manager_executed'] or boxed['manager_context'] == 'UNBOXED'
            or boxed['boxes_observed'] != 0 or boxed['production_launch_available']
            or boxed['control_or_elevation_dispatched'] or boxed['self_relaunch_or_escape_attempted']):
        raise ValueError('Actual boxed manager gate did not pass')
    standard = read(folder / 'standard-user.json')
    if (standard['status'] != 'PASSED' or not standard['standard_user']
            or standard['simultaneous_session_count'] < 2 or not standard['same_owner_verified']
            or not standard['all_session_complete'] or standard['activity'] != 'RUNNING'
            or not standard['all_births_present'] or not standard['unowned_read_only']):
        raise ValueError('Production standard-user all-session evidence missing')
    return summary


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Exact source commit and run required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'headSha,status,conclusion'], cwd=ROOT))
    if run['headSha'] != commit or run['status'] != 'completed' or run['conclusion'] != 'success':
        raise ValueError('Actions source/run did not complete successfully')
    evidence = ROOT / 'docs/evidence/p04'
    copies, targets = [], []
    for runner, machine in (('windows-2025', '8664'), ('windows-11-arm', 'aa64')):
        folder = download / f'p04-{runner}-{commit}'
        summary = check_target(folder, commit, machine)
        relative = f'completion-{commit[:7]}/{runner}'
        for name in ('stage.json', 'run-summary.json', 'observation-cases.json', 'standard-user.json'):
            source = folder / name
            copies.append((source, evidence / relative / name, record(source, f'{relative}/{name}')))
        targets.append({'runner': runner, 'evidence_directory': relative, 'summary': summary})
    paths = ['Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', '.github/workflows/p04.yml',
             'tools/lab/Invoke-P04.ps1', 'tools/probe/p04_boxed.ps1', 'tools/probe/p04_standard.ps1']
    paths += [p.relative_to(ROOT).as_posix() for base in ('crates/sandboxie-adapter', 'src-tauri', 'ui')
              for p in sorted((ROOT / base).rglob('*')) if p.is_file() and 'gen' not in p.parts
              and p.suffix in {'.rs', '.toml', '.json', '.ts', '.tsx', '.css', '.ico', '.png'}]
    sources = []
    for path in paths:
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError(f'Stale P04 source: {path}')
        sources.append(record(ROOT / path, path))
    for source, destination, _ in copies:
        if destination.exists() and destination.read_bytes() != source.read_bytes():
            raise ValueError('Historical evidence must not be overwritten')
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    old = read(evidence / 'manifest.json') if (evidence / 'manifest.json').exists() else {}
    known = {f['path']: f for f in old.get('files', [])}
    known.update({f['path']: f for _, _, f in copies})
    manifest = {'phase': 'P04', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                'targets': targets, 'files': list(known.values()), 'tested_sources': sources,
                'production_acceptance_scenarios_passed': 0,
                'note': 'Production read-only observation paths only; P02 produces synthetic fixtures, no product launch or mutation.'}
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('P04 production evidence retained for both Windows targets')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
