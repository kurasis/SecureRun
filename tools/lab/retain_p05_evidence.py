"""Retain complete native P05 proof; failed, partial or stale runs cannot close the gate."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IDS = {f'T{i:02}' for i in (*range(8, 19), 27, 31, 35, *range(37, 41), 47, 51, 52, 53, 55, *range(57, 61))}
REQUIRED = {
    'native_pending_root_and_verified_policy', 'baseline_effective_file_registry_network_evidence',
    'unsolicited_incoming_ipv4_ipv6_tcp_udp_denied',
    'bits_com_activation_is_explicitly_denied',
    'paid_presets_rejected_without_entitlement', 'literal_grammar_and_root_grants_rejected',
    'online_policy_keeps_file_and_sibling_protection', 'wfp_loss_invalidates_offline_policy',
    'external_owned_setting_requires_reviewed_repair', 'global_template_changes_block_without_overwrite',
    'configuration_password_refused_without_secret_transport',
    'populated_readonly_view_change_preserves_overlay_and_restores_it',
    'new_supported_path_grant_keeps_tested_family', 'same_path_root_replacement_is_not_adopted',
    'actual_subst_namespace_is_rejected_before_mutation', 'polluted_existing_box_does_not_host_diagnostic',
    'running_sibling_prevents_any_new_storage', 'running_policy_mutation_is_deferred',
    'actual_other_session_prevents_policy_and_sibling_mutation',
    'future_sibling_denials_verified_before_root_creation', 'production_provisioning_as_actual_standard_user',
    'second_standard_user_cannot_read_root_or_metadata',
    'forged_metadata_cannot_authorize_foreign_root_or_drop_mandatory_rules',
    'accepted_writes_without_independent_enforcement_remain_conflicted',
    'boxed_production_manager_and_worker_refuse_forged_parent',
    'boxed_same_sid_client_cannot_claim_unboxed_authority', 'boxed_ipc_client_has_no_privileged_route',
    'different_admin_uac_route_is_absent',
} | {f'actual_worker_interruption_{stage}' for stage in ('intent', 'fenced', 'writing', 'readback', 'pendingroot', 'rootbound', 'verifying')}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, name):
    data = path.read_bytes()
    return {'path': name, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}


def check_target(folder, commit, machine):
    summary, cases = read(folder / 'run-summary.json'), read(folder / 'policy-cases.json')
    if (summary['manager_commit'] != commit or summary['phase'] != 'P05' or summary['result'] != 'PASSED'
            or summary['pe_machine'] != machine or summary['adapter_tests_passed'] < 28
            or summary['failed'] != 0 or summary['production_target_launches'] != 0
            or summary['elevated_helper'] or summary['os_security_settings_modified']
            or summary['fault_feature_release_enabled']):
        raise ValueError('P05 source/architecture/result/phase boundary is invalid')
    for key in ('manager_binary_sha256', 'probe_binary_sha256', 'fault_binary_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', summary[key]):
            raise ValueError('Native binary provenance missing')
    names = [c['name'] for c in cases]
    if len(set(names)) != len(names) or not REQUIRED.issubset(names) or not IDS.issubset({c['id'] for c in cases}):
        raise ValueError('Mandatory P05 production scenario coverage is incomplete')
    allowed_na = 'different_admin_uac_route_is_absent'
    for case in cases:
        expected = 'NOT_APPLICABLE' if case['name'] == allowed_na else 'PASSED'
        if case['status'] != expected:
            raise ValueError('A required P05 case did not pass')
    if (summary['native_cases_passed'] != sum(c['status'] == 'PASSED' for c in cases)
            or summary['native_not_applicable'] != 1):
        raise ValueError('P05 result counts do not match actual cases')
    for stage in ('intent', 'fenced', 'writing', 'readback', 'pendingroot', 'rootbound', 'verifying'):
        fault = read(folder / f'fault-{stage}.json')
        if (fault['status'] != 'PASSED' or not fault['standard_user'] or not fault['real_process_interruption']
                or not fault['conflict_after_restart'] or fault['automatic_replay'] or not fault['launch_blocked']):
            raise ValueError('Actual journal interruption proof missing')
    for name in ('standard-user.json', 'metadata-authority.json', 'no-enforcement.json', 'boxed-policy.json', 'cross-session.json'):
        if read(folder / name)['status'] != 'PASSED':
            raise ValueError('Native security boundary report failed')
    return summary


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Exact tested source required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'headSha,status,conclusion'], cwd=ROOT))
    if run != {'headSha': commit, 'status': 'completed', 'conclusion': 'success'}:
        raise ValueError('Exact Actions source did not complete successfully')
    for phase in ('p03', 'p04'):
        dependency = read(ROOT / f'docs/evidence/{phase}/manifest.json')
        if dependency['result'] != 'DONE' or dependency['tested_commit'] != commit:
            raise ValueError('Current P03 and P04 regressions must pass on the same runtime source')
    evidence = ROOT / 'docs/evidence/p05'
    old = read(evidence / 'manifest.json') if (evidence / 'manifest.json').exists() else {}
    known = {f['path']: f for f in old.get('files', [])}
    targets, copies = [], []
    for runner, machine in (('windows-2025', '8664'), ('windows-11-arm', 'aa64')):
        folder = download / f'p05-{runner}-{commit}'
        summary = check_target(folder, commit, machine)
        relative = f'completion-{commit[:7]}/{runner}'
        for source in sorted(folder.glob('*.json')):
            destination = evidence / relative / source.name
            if destination.exists() and destination.read_bytes() != source.read_bytes():
                raise ValueError('Historical proof cannot be overwritten')
            copies.append((source, destination))
            known[f'{relative}/{source.name}'] = record(source, f'{relative}/{source.name}')
        targets.append({'runner': runner, 'evidence_directory': relative, 'summary': summary})
    paths = ['Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', '.github/workflows/p05.yml']
    paths += [p.relative_to(ROOT).as_posix() for base in ('crates', 'src-tauri', 'ui', 'tools')
              for p in sorted((ROOT / base).rglob('*')) if p.is_file() and 'gen' not in p.parts
              and p.suffix in {'.rs', '.toml', '.json', '.ts', '.tsx', '.css', '.c', '.cs', '.ps1', '.py'}]
    sources = []
    for path in paths:
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError(f'Stale P05 source: {path}')
        sources.append(record(ROOT / path, path))
    for source, destination in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    manifest = {'phase': 'P05', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                'targets': targets, 'files': list(known.values()), 'tested_sources': sources,
                'production_acceptance_scenarios_passed': 0,
                'note': 'P05 production policy/provisioning paths and fixed synthetic diagnostics only; this regression executes no P06 user-target launch.'}
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Complete P05 proof retained for both Windows laboratories')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
