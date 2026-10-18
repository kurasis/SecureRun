"""Retain P11 only from successful, exact-source, installed Windows laboratory runs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RUNNERS = {'windows-2025': ('x86_64-pc-windows-msvc', '8664', 26100),
           'windows-11-arm': ('aarch64-pc-windows-msvc', 'aa64', 26200)}
MANDATORY = {
    'installer_rejects_user_writable_existing_code_directory',
    'installer_rejects_junction_without_touching_destination',
    'official_webview_prerequisite_matches_os_baseline',
    'clean_install_has_exact_reviewed_payload_and_native_architecture',
    'failed_upgrade_rolls_back_files_and_retains_profile',
    'upgrade_installs_candidate_without_elevated_profile_migration',
    'older_package_is_refused_without_database_downgrade',
    'installed_boxed_manager_and_all_workers_refuse_unboxed_parent_claim',
    'uninstall_removes_only_code_and_retains_profile_engine_runtime',
    'reinstall_preserves_data_before_owner_reconciliation',
    'installed_build_provisions_and_verifies_real_offline_policy',
    'installed_import_export_preserves_bytes_and_provenance',
    'future_schema_is_refused_without_downgrade',
    'failed_initial_migration_is_refused_without_destroying_existing_data',
}
for mode in ('seed', 'upgrade', 'reinstall'):
    for case in ('ordinary_user_cannot_modify_installed_code',
                 'installed_manager_opens_real_webview_and_closes',
                 'installed_production_launcher_stays_boxed'):
        MANDATORY.add(mode + '_' + case)
for mode in ('upgrade', 'reinstall'):
    MANDATORY.add(mode + '_same_account_reopens_verified_retained_environment_and_file')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def check_webview(event, runner):
    """Require absent-runtime installation on Server; preserve Windows 11's baseline."""
    if (event['security_settings_modified'] or event['runtime_signature'] != 'Valid'
            or not re.fullmatch(r'\d+\.\d+\.\d+\.\d+', event['runtime_version'])
            or int(event['runtime_version'].split('.')[0]) < 120):
        raise ValueError('P11 actual suitable Microsoft runtime was not verified')
    missing = event['tested_state'] == 'ABSENT_OFFICIAL_BOOTSTRAPPER_INSTALL'
    if runner == 'windows-2025' and not missing:
        raise ValueError('P11 Server must exercise the missing-runtime prerequisite')
    if missing:
        if not event['runtime_absent_before_install']:
            raise ValueError('P11 missing-runtime installation was not actually executed')
    elif (runner != 'windows-11-arm' or event['tested_state'] != 'WINDOWS_11_PREINSTALLED_RUNTIME'
          or event['runtime_absent_before_install'] or event['runtime_uninstall_dispatched']
          or event['missing_runtime_arm_installation_tested']):
        raise ValueError('P11 preinstalled-runtime scope was mislabeled')
    return missing


def sources(root=ROOT):
    spec = importlib.util.spec_from_file_location('p10_sources', root / 'tools/lab/retain_p10_evidence.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return sorted(set(module.source_paths(root)) | {
        p.relative_to(root).as_posix() for p in (root / 'packaging').rglob('*')
        if p.is_file() and '__pycache__' not in p.parts
    })


def check_target(folder, runner, commit):
    target, machine, build_number = RUNNERS[runner]
    s = read(folder / 'run-summary.json')
    if (s['phase'], s['result'], s['tested_commit'], s['target'], s['os_build']) != (
            'P11', 'PASSED', commit, target, build_number):
        raise ValueError('P11 source, result or laboratory tuple mismatch')
    if (s['cases_failed'] or s['final_acceptance_scenarios_passed'] or s['engine_bundled']
            or s['elevated_product_helper'] or s['os_security_settings_modified']
            or s['signing'] != 'UNSIGNED_DEVELOPMENT_ONLY'
            or not all(s[k] for k in ('webview_prerequisite_verified', 'installed_payload_verified',
                                     'retention_verified', 'installed_smoke_after_reinstall'))):
        raise ValueError('P11 installed boundaries/retention/signing scope failed')
    cases = []
    for name in ('packaging', 'seed', 'upgrade', 'reinstall'):
        cases += read(folder / (name + '-cases.json'))
    if (len(cases) != len(MANDATORY) or s['cases_passed'] != len(cases)
            or {c['name'] for c in cases} != MANDATORY
            or any(c['status'] != 'PASSED' for c in cases)):
        raise ValueError('P11 required actual installed cases missing/failed/duplicated')
    by_name = {c['name']: c['evidence'] for c in cases}
    runtime = by_name['official_webview_prerequisite_matches_os_baseline']
    missing_runtime = check_webview(runtime, runner)
    setup = read(folder / 'setup-observations.json')
    if (len(setup) != 8 or any(r['private_log_retained'] for r in setup)
            or not all(r['final_log_closed'] for r in setup)
            or any('P11_WEBVIEW_INSTALL_REQUIRED' in r['events'] for r in setup) != missing_runtime
            or any('P11_GUARD_EXACT_BYTES_VERIFIED' not in r['events'] for r in setup if r['exit_code'] == 0)):
        raise ValueError('P11 actual prerequisite/embedded-guard execution proof missing')
    for name in ('failed_upgrade_rolls_back_files_and_retains_profile',
                 'upgrade_installs_candidate_without_elevated_profile_migration',
                 'uninstall_removes_only_code_and_retains_profile_engine_runtime',
                 'reinstall_preserves_data_before_owner_reconciliation'):
        event = by_name[name]
        if event['profile_before'] != event['profile_after'] or event['profile_before']['files'] < 4:
            raise ValueError('P11 retained profile changed across installer operation')
    uninstall = by_name['uninstall_removes_only_code_and_retains_profile_engine_runtime']
    if not uninstall['all_owned_payload_removed'] or not uninstall['registration_removed']:
        raise ValueError('P11 uninstaller did not finish removing its own payload/registration')
    boxed = read(folder / 'boxed-policy.json')
    if (boxed['status'] != 'PASSED' or not boxed['actual_boxed_worker_executed']
            or boxed['claimed_unboxed_parent_accepted'] or boxed['control_dispatched']
            or {r['mode'] for r in boxed['worker_boundaries']} != {'control', 'files', 'lifecycle', 'product'}
            or any(r['reason'] != 'MANAGER_CONTEXT_UNSAFE' for r in boxed['worker_boundaries'])):
        raise ValueError('P11 installed boxed-context proof missing')
    unit = read(folder / 'migration-unit-tests.json')
    if (not unit['production_tests_passed'] or unit['source_commit'] != commit
            or unit['foundation_tests'] != 19 or unit['adapter_tests'] != 62
            or unit['foundation_unit_tests'] != 1 or unit['foundation_integration_tests'] != 18):
        raise ValueError('P11 actual migration rollback tests not completed')
    package = read(folder / 'package-manifest.json')
    if (package['source_commit'] != commit or package['features'] or package['engine_bundled']
            or package['signing_status'] != 'UNSIGNED_DEVELOPMENT_ONLY'):
        raise ValueError('P11 artifact is not the ordinary development product')
    binaries = {f['name']: f for f in package['files'] if f['name'].endswith('.exe')}
    expected = {'securerun.exe', 'install-guard.exe', 'securerun-box-launcher.exe'}
    for suffix in ('', '-x86') + (('-x64',) if machine == 'aa64' else ()):
        for role in ('policy', 'launch'):
            expected.add('securerun-' + role + '-probe' + suffix + '.exe')
    if set(binaries) != expected or any(f['signature'] != 'NotSigned' for f in binaries.values()):
        raise ValueError('P11 executable allowlist/development signature status mismatch')
    for name, f in binaries.items():
        expected_machine = '014c' if '-x86.exe' in name else '8664' if '-x64.exe' in name else machine
        if f['pe_machine'] != expected_machine or not re.fullmatch('[0-9a-f]{64}', f['sha256']):
            raise ValueError('P11 payload architecture or hash mismatch')
    build = read(folder / 'build.json')
    if (build['source_commit'], build['target']) != (commit, target):
        raise ValueError('P11 installer build provenance mismatch')
    for mode in ('seed', 'upgrade', 'reinstall'):
        actor = read(folder / (mode + '-summary.json'))
        if (actor['status'] != 'PASSED' or not actor['standard_user']
                or actor['installed_manager_sha256'] != binaries['securerun.exe']['sha256']):
            raise ValueError('P11 actor did not test the packaged installed manager')
    if {p['package_version'] for p in build['packages']} != {'0.3.0.10', '0.3.0.11'}:
        raise ValueError('P11 actual baseline/candidate installer missing')
    for p in build['packages']:
        if p['signature'] != 'NotSigned' or not re.fullmatch('[0-9a-f]{64}', p['sha256']) or p['size'] <= 0:
            raise ValueError('P11 installer development status/hash missing')
    if any(t['signature'] != 'Valid' for t in build['prerequisite_trust']):
        raise ValueError('P11 upstream prerequisite signature invalid')
    inventory = read(folder / 'dependency-inventory.json')
    components = inventory['components']
    if (inventory['manager_license'] != 'NOT_SELECTED_BY_OWNER' or len(components) < 250
            or not any(c['name'] == 'tauri' for c in components)
            or not any(c['name'] == 'react' for c in components)
            or any(not c.get('notices') for c in components if c['ecosystem'] == 'cargo' and c['scope'] != 'ORIGINAL_MANAGER_SOURCE')):
        raise ValueError('P11 incomplete target-specific dependency/notices inventory')
    return s


def validate(root=ROOT):
    manifest = read(root / 'docs/evidence/p11/manifest.json')
    if manifest['phase'] != 'P11' or manifest['result'] not in {'DONE', 'BLOCKED'}:
        raise ValueError('Invalid P11 phase result')
    if manifest['result'] == 'BLOCKED':
        if not manifest.get('blocked_reason'):
            raise ValueError('P11 blocked gate needs an explicit reason')
        return
    if manifest['phase'] != 'P11' or manifest['final_acceptance_scenarios_passed'] != 0:
        raise ValueError('P11 cannot close P12 installed acceptance')
    p10 = read(root / 'docs/evidence/p10/manifest.json')
    if p10['result'] != 'DONE':
        raise ValueError('P11 needs completed integrated regression evidence')
    dependency = record(root / 'docs/evidence/p10/manifest.json', 'docs/evidence/p10/manifest.json')
    if manifest['integration_dependency'] != dependency:
        raise ValueError('P11 integrated dependency changed after packaging review')
    # A packaging-only descendant can preserve the full P10 source identity.
    # Never remove protected inputs or relabel an earlier run as a new commit.
    spec = importlib.util.spec_from_file_location('p10_identity', root / 'tools/lab/retain_p10_evidence.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if {s['path'] for s in p10['tested_sources']} != set(module.source_paths(root)):
        raise ValueError('P11 integration source inventory is incomplete')
    for entry in p10['tested_sources']:
        if record(root / entry['path'], entry['path']) != entry:
            raise ValueError('P11 runtime/workflow differs from completed P10 source')
    if {r['runner'] for r in manifest['targets']} != set(RUNNERS) or len(manifest['targets']) != 2:
        raise ValueError('P11 requires both installed Windows laboratories')
    bound_files = [entry['path'] for entry in manifest['files']]
    if len(bound_files) != len(set(bound_files)):
        raise ValueError('P11 duplicated evidence entry')
    for target in manifest['targets']:
        folder = (root / 'docs/evidence/p11' / target['directory']).resolve()
        if not folder.is_relative_to((root / 'docs/evidence/p11').resolve()):
            raise ValueError('P11 unsafe target directory')
        check_target(folder, target['runner'], manifest['tested_commit'])
        required = {'run-summary.json', 'package-manifest.json', 'build.json', 'dependency-inventory.json',
                    'boxed-policy.json', 'migration-unit-tests.json', 'scope.json', 'packaging-cases.json',
                    'setup-observations.json'}
        for mode in ('seed', 'upgrade', 'reinstall'):
            required.update({mode + '-summary.json', mode + '-cases.json'})
        if not {target['directory'] + '/' + name for name in required}.issubset(bound_files):
            raise ValueError('P11 required native proof is not hash-bound')
    for entry in manifest['files']:
        path = (root / 'docs/evidence/p11' / entry['path']).resolve()
        if not path.is_relative_to((root / 'docs/evidence/p11').resolve()) or record(path, entry['path']) != entry:
            raise ValueError('P11 altered/unsafe retained evidence')
    if {r['path'] for r in manifest['tested_sources']} != set(sources(root)):
        raise ValueError('P11 missing protected packaging/runtime source')
    for entry in manifest['tested_sources']:
        if record(root / entry['path'], entry['path']) != entry:
            raise ValueError('P11 stale tested source')


def retain(download, commit, run_id):
    actual = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json',
                                                'headSha,status,conclusion'], cwd=ROOT))
    if actual != {'headSha': commit, 'status': 'completed', 'conclusion': 'success'}:
        raise ValueError('P11 run must succeed on the exact source')
    evidence = ROOT / 'docs/evidence/p11'
    entries, targets = [], []
    for runner in RUNNERS:
        folder = download / f'p11-{runner}-{commit}'
        summary = check_target(folder, runner, commit)
        destination = evidence / ('completion-' + commit[:7]) / runner
        destination.mkdir(parents=True, exist_ok=True)
        for path in sorted(folder.glob('*.json')):
            # No private controller state, database or installer logs are accepted.
            data = path.read_text(encoding='utf-8-sig')
            if re.search(r'(?i)(?<![a-z])[a-z]:[\\/]|S-1-5-21-|-----BEGIN|gh[pousr]_[A-Za-z0-9]', data):
                raise ValueError('P11 privacy review failed: ' + path.name)
            target = destination / path.name
            shutil.copyfile(path, target)
            entries.append(record(target, target.relative_to(evidence).as_posix()))
        targets.append({'runner': runner, 'directory': destination.relative_to(evidence).as_posix(),
                        'cases_passed': summary['cases_passed']})
    bound = []
    for path in sources():
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError('P11 source differs from tested commit: ' + path)
        bound.append(record(ROOT / path, path))
    manifest = {'phase': 'P11', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                'targets': targets, 'files': entries, 'tested_sources': bound,
                'integration_dependency': record(ROOT / 'docs/evidence/p10/manifest.json', 'docs/evidence/p10/manifest.json'),
                'signing': 'UNSIGNED_DEVELOPMENT_ONLY', 'manager_license': 'NOT_SELECTED_BY_OWNER',
                'final_acceptance_scenarios_passed': 0,
                'next_phase': 'P12', 'development_limitations': [
                    'No production signing infrastructure', 'No selected original manager license',
                    'Windows 11 x64 installed release not certified by owner-selected labs'],
                'webview_coverage': {'windows-2025': 'Actual absent-runtime installation using the official bootstrapper',
                                     'windows-11-arm': 'Windows 11 preinstalled runtime preserved and exercised; no claim of a stripped-OS missing-runtime test',
                                     'reference': 'https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution'}}
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    validate()
    print(json.dumps(targets))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path)
    parser.add_argument('--tested-commit')
    parser.add_argument('--run-id', type=int)
    args = parser.parse_args()
    if args.download_directory:
        retain(args.download_directory, args.tested_commit, args.run_id)
    else:
        validate()
        print('P11 evidence validation passed')
