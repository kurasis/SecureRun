"""Retain real P03 Actions evidence with exact source and result provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Exact full source commit/run required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'headSha,status,conclusion'], cwd=ROOT))
    if run['headSha'] != commit or run['status'] != 'completed' or run['conclusion'] != 'success':
        raise ValueError('Actions run does not match completed source validation')
    evidence = ROOT / 'docs/evidence/p03'
    copies, targets = [], []
    for runner, machine in (('windows-2025', '8664'), ('windows-11-arm', 'aa64')):
        folder = download / f'p03-{runner}-{commit}'
        summary, boundary = read(folder / 'run-summary.json'), read(folder / 'command-boundary.json')
        if summary['manager_commit'] != commit or summary['result'] != 'PASSED' or summary['pe_machine'] != machine:
            raise ValueError('Native Windows source/result mismatch')
        if summary['foundation_tests_passed'] < 19 or summary['normal_native_tests_passed'] < 3 or summary['frontend_tests_passed'] != 3:
            raise ValueError('Required actual test suites missing')
        if boundary['result'] != 'PASSED' or not boundary['real_webview2'] or not boundary['real_native_picker'] or boundary['engine_operations_executed'] != 0:
            raise ValueError('Actual command boundary was not proven')
        cases = boundary['cases']
        if not cases or any(not case['passed'] for case in cases) or len(cases) != summary['windows_command_cases_passed']:
            raise ValueError('Actual command outcomes do not close the gate')
        acl = read(folder / 'acl-manifests.json')['__app-acl__']['permissions']
        if acl['allow-get-snapshot']['commands']['allow'] != ['get_snapshot']:
            raise ValueError('Generated application command ACL absent')
        capabilities = read(folder / 'capabilities.json')
        if capabilities['main'].get('remote') or capabilities['main']['webviews'] != ['main']:
            raise ValueError('Unexpected remote/unscoped capability')
        relative = f'completion-{commit[:7]}/{runner}'
        for path in sorted(folder.glob('*.json')):
            destination = evidence / relative / path.name
            if destination.exists() and destination.read_bytes() != path.read_bytes():
                raise ValueError('Existing evidence cannot be replaced')
            copies.append((path, destination, record(path, f'{relative}/{path.name}')))
        targets.append({'runner': runner, 'evidence_directory': relative, 'summary': summary})
    source_paths = ['Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', '.cargo/config.toml',
                    'package.json', 'package-lock.json', 'index.html', 'vite.config.ts', 'tsconfig.json',
                    '.github/workflows/p03.yml', 'tools/lab/Invoke-P03.ps1', 'tests/ui_state.test.ts']
    source_paths += [path.relative_to(ROOT).as_posix() for parent in ('crates', 'src-tauri', 'ui')
                     for path in sorted((ROOT / parent).rglob('*'))
                     if path.is_file() and 'gen' not in path.parts and path.suffix in {'.rs', '.toml', '.json', '.sql', '.ts', '.tsx', '.css', '.svg', '.ico', '.png'}]
    sources = []
    for path in source_paths:
        data = subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT)
        if (ROOT / path).read_bytes() != data:
            raise ValueError(f'Stale source evidence: {path}')
        sources.append(record(ROOT / path, path))
    for source, destination, _ in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    old_path = evidence / 'manifest.json'
    old = read(old_path) if old_path.exists() else {}
    known = {entry['path']: entry for entry in old.get('files', [])}
    known.update({entry['path']: entry for _, _, entry in copies})
    historical = old.get('historical_runs', [])
    if old.get('tested_commit') and old['tested_commit'] != commit:
        historical.append({key: old[key] for key in ('tested_commit', 'run_id', 'url', 'result', 'note') if key in old})
    manifest = {'phase': 'P03', 'result': 'DONE', 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}', 'tested_commit': commit,
                'targets': targets, 'files': list(known.values()), 'tested_sources': sources, 'historical_runs': historical,
                'production_acceptance_scenarios_passed': 0,
                'note': 'Foundation paths only. No engine execution, production target launcher or P04 observation is claimed.'}
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(targets, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
