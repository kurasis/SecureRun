"""Validate phase evidence provenance and the untouched specification (stdlib only)."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def verify_file(path: Path, expected_hash: str, expected_size: int | None = None) -> None:
    if not re.fullmatch(r'[0-9a-f]{64}', expected_hash):
        raise ValueError('Invalid SHA256 declaration')
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != expected_hash:
        raise ValueError(f'Checksum mismatch: {path.name}')
    if expected_size is not None and path.stat().st_size != expected_size:
        raise ValueError(f'Size mismatch: {path.name}')


def validate(root: Path) -> None:
    spec = root / 'docs/specification'
    entries = (spec / 'SHA256SUMS').read_text().splitlines()
    recorded = set()
    for line in entries:
        digest, name = line.split('  ', 1)
        path = (spec / name).resolve()
        if not path.is_relative_to(spec.resolve()) or name in recorded:
            raise ValueError('Unsafe or duplicate specification path')
        recorded.add(name)
        verify_file(path, digest)
    actual = {p.relative_to(spec).as_posix() for p in spec.rglob('*.md')}
    if actual != recorded or len(recorded) != 26:
        raise ValueError('Specification must contain the original 26 documents')
    for page in root.rglob('*.md'):
        if any(part in {'.git', 'artifacts', 'node_modules', 'target', 'dist', 'gen'} for part in page.parts):
            continue
        for target in re.findall(r'\[[^\]]*\]\(([^\s)]+)\)', page.read_text(encoding='utf-8')):
            if '://' in target or target.startswith('#'):
                continue
            file_part = target.split('#', 1)[0]
            if file_part and not (page.parent / file_part).exists():
                raise ValueError(f'Broken relative link in {page.relative_to(root)}: {target}')
    pin = json.loads((root / 'docs/engine-candidate.json').read_text())
    if not re.fullmatch(r'[0-9a-f]{40}', pin['source_commit']):
        raise ValueError('Candidate needs a full source commit')
    if pin['support_status'] != 'UNTESTED_CANDIDATE':
        raise ValueError('An unresolved feasibility gate cannot declare a supported engine')
    for installer in (pin['installer'], pin['lab_installer']):
        prefix = f"https://github.com/{pin['repository']}/releases/download/{pin['tag']}/"
        if installer['url'] != prefix + installer['name'] or not re.fullmatch(r'[0-9a-f]{64}', installer['sha256']):
            raise ValueError('Candidate installer must use the pinned official release')
    results = json.loads((root / 'docs/test-catalog.json').read_text())
    if [test['id'] for test in results] != [f'T{i:02}' for i in range(1, 67)]:
        raise ValueError('Acceptance catalog must contain T01–T66 exactly once')
    if any(test['status'] != 'NOT_STARTED' for test in results):
        raise ValueError('Lab feasibility cannot pass a production acceptance scenario')
    for name in ('STATUS', 'REPOSITORY_ASSESSMENT', 'LAB_SETUP', 'ENGINE_MATRIX', 'OPERATION_MAP', 'TEST_REPORT'):
        if not (root / f'docs/{name}.md').is_file():
            raise ValueError(f'Missing P01 output: {name}')
    if not (root / 'docs/phases/P01_REPORT.md').is_file():
        raise ValueError('Missing phase report')
    manifest_path = root / 'docs/evidence/p02/manifest.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest['phase'] != 'P02' or manifest['result'] not in {'DONE', 'BLOCKED'}:
            raise ValueError('Invalid P02 gate result')
        for name in ('FEASIBILITY_REPORT', 'OPERATION_MAP', 'ENGINE_MATRIX'):
            if not (root / f'docs/{name}.md').is_file():
                raise ValueError(f'Missing P02 output: {name}')
        seen = set()
        for entry in manifest['files']:
            name = entry['path']
            path = (manifest_path.parent / name).resolve()
            if name in seen or not path.is_relative_to(manifest_path.parent.resolve()):
                raise ValueError('Unsafe or duplicate evidence path')
            seen.add(name)
            verify_file(path, entry['sha256'], entry['size'])
        for run in manifest['runs']:
            if not re.fullmatch(r'[0-9a-f]{40}', run['tested_commit']):
                raise ValueError('Evidence needs exact tested commit')
            if run['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{run['id']}":
                raise ValueError('Invalid evidence run provenance')
        if manifest['result'] == 'DONE':
            current = [run for run in manifest['runs'] if run.get('role') == 'current']
            if len(current) != 1 or current[0]['job_collection_conclusion'] != 'success':
                raise ValueError('P02 DONE requires one successful current evidence run')
            targets = current[0]['targets']
            if {target['runner'] for target in targets} != {'windows-2025', 'windows-11-arm'} or len(targets) != 2:
                raise ValueError('P02 DONE requires both owner-selected Windows laboratories')
            required = {'T01', 'T05', 'T08', 'T09', 'T12', 'T33', 'T35', 'T36', 'T55', 'T57', 'T58', 'T60', 'T62'}
            for target in targets:
                folder = manifest_path.parent / target['evidence_directory']
                for name in ('phase-result.json', 'feasibility-cases.json', 'standard-user-result.json'):
                    if (folder / name).relative_to(manifest_path.parent).as_posix() not in seen:
                        raise ValueError('Current P02 result must be checksum-bound')
                phase = json.loads((folder / 'phase-result.json').read_text(encoding='utf-8-sig'))
                cases = json.loads((folder / 'feasibility-cases.json').read_text(encoding='utf-8-sig'))
                worker = json.loads((folder / 'standard-user-result.json').read_text(encoding='utf-8-sig'))['worker']
                if phase['result'] != 'DONE' or phase['gate_blockers'] or any(case['status'] not in {'PASSED', 'NOT_APPLICABLE'} for case in cases):
                    raise ValueError('P02 DONE contradicts current Windows outcomes')
                if not required.issubset({case['id'] for case in cases if case['status'] == 'PASSED'}):
                    raise ValueError('P02 DONE requires every representative scenario')
                for status, key in (('PASSED', 'passed'), ('FAILED', 'failed'), ('BLOCKED', 'blocked'), ('NOT_APPLICABLE', 'not_applicable'), ('NOT_RUN', 'not_run')):
                    if sum(case['status'] == status for case in cases) != phase[f'{key}_smoke_cases']:
                        raise ValueError('P02 outcome counts contradict raw cases')
                if worker['status'] != 'PASSED' or not worker['standard_user'] or worker['elevated_helper'] or not worker['sessions']['same_owner_verified'] or worker['sessions']['simultaneous_session_count'] < 2:
                    raise ValueError('P02 DONE requires real standard-user multi-session evidence')
            for entry in manifest['tested_sources']:
                path = (root / entry['path']).resolve()
                if not path.is_relative_to(root.resolve()):
                    raise ValueError('Unsafe tested source path')
                verify_file(path, entry['sha256'], entry['size'])

    p03_path = root / 'docs/evidence/p03/manifest.json'
    if p03_path.exists():
        p03 = json.loads(p03_path.read_text())
        if p03['phase'] != 'P03' or p03['result'] not in {'DONE', 'BLOCKED'} or not re.fullmatch(r'[0-9a-f]{40}', p03['tested_commit']):
            raise ValueError('Invalid P03 completed evidence provenance')
        if p03['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{p03['run_id']}":
            raise ValueError('Invalid P03 run provenance')
        seen = set()
        for entry in p03['files']:
            path = (p03_path.parent / entry['path']).resolve()
            if entry['path'] in seen or not path.is_relative_to(p03_path.parent.resolve()):
                raise ValueError('Unsafe/duplicate P03 evidence path')
            seen.add(entry['path'])
            verify_file(path, entry['sha256'], entry['size'])
        if {target['runner'] for target in p03['targets']} != {'windows-2025', 'windows-11-arm'}:
            raise ValueError('P03 DONE requires both Windows laboratories')
        for target in p03['targets'] if p03['result'] == 'DONE' else []:
            folder = p03_path.parent / target['evidence_directory']
            for name in ('command-boundary.json', 'run-summary.json', 'acl-manifests.json', 'capabilities.json'):
                if (folder / name).relative_to(p03_path.parent).as_posix() not in seen:
                    raise ValueError('P03 current results must be checksum-bound')
            summary = json.loads((folder / 'run-summary.json').read_text(encoding='utf-8-sig'))
            boundary = json.loads((folder / 'command-boundary.json').read_text(encoding='utf-8-sig'))
            if summary['manager_commit'] != p03['tested_commit'] or summary['result'] != 'PASSED' or boundary['result'] != 'PASSED' or any(not case['passed'] for case in boundary['cases']):
                raise ValueError('P03 DONE contradicts native command outcomes')
            if not boundary['real_webview2'] or not boundary['real_native_picker'] or boundary['engine_operations_executed'] != 0:
                raise ValueError('Missing real P03 boundary/phase separation')
            if summary['foundation_tests_passed'] < 19 or summary['frontend_tests_passed'] != 3 or summary['normal_native_tests_passed'] != 2 or len(boundary['cases']) != summary['windows_command_cases_passed']:
                raise ValueError('P03 required suites did not execute')
            names = {case['name'] for case in boundary['cases']}
            if not {'local_ungranted_webview_denied', 'remote_origin_commands_denied', 'standard_user_token_observed', 'actual_replaced_windows_artifact_retained', 'selection_consumed_once', 'backend_event_has_independent_generations_and_sequence'}.issubset(names):
                raise ValueError('Required P03 native cases missing')
            acl = json.loads((folder / 'acl-manifests.json').read_text())['__app-acl__']['permissions']
            if acl['allow-get-snapshot']['commands']['allow'] != ['get_snapshot']:
                raise ValueError('P03 generated custom command ACL missing')
        for entry in p03['tested_sources'] if p03['result'] == 'DONE' else []:
            path = (root / entry['path']).resolve()
            if not path.is_relative_to(root.resolve()):
                raise ValueError('Unsafe P03 tested source path')
            verify_file(path, entry['sha256'], entry['size'])


    p04_path = root / 'docs/evidence/p04/manifest.json'
    if p04_path.exists():
        p04 = json.loads(p04_path.read_text())
        if p04['phase'] != 'P04' or p04['result'] not in {'DONE', 'BLOCKED'} or not re.fullmatch(r'[0-9a-f]{40}', p04['tested_commit']):
            raise ValueError('Invalid P04 source provenance')
        if p04['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{p04['run_id']}":
            raise ValueError('Invalid P04 run provenance')
        seen = set()
        for entry in p04['files']:
            path = (p04_path.parent / entry['path']).resolve()
            if entry['path'] in seen or not path.is_relative_to(p04_path.parent.resolve()):
                raise ValueError('Unsafe/duplicate P04 evidence path')
            seen.add(entry['path'])
            verify_file(path, entry['sha256'], entry['size'])
        if p04['result'] == 'DONE':
            if not p03_path.exists() or p03['result'] != 'DONE' or p03['tested_commit'] != p04['tested_commit']:
                raise ValueError('P04 DONE requires current P03 regression for the same source')
            if {t['runner'] for t in p04['targets']} != {'windows-2025', 'windows-11-arm'}:
                raise ValueError('Both P04 native laboratories required')
            import importlib.util
            module_spec = importlib.util.spec_from_file_location('p04_retainer', root / 'tools/lab/retain_p04_evidence.py')
            module = importlib.util.module_from_spec(module_spec)
            module_spec.loader.exec_module(module)
            for target in p04['targets']:
                folder = (p04_path.parent / target['evidence_directory']).resolve()
                if not folder.is_relative_to(p04_path.parent.resolve()):
                    raise ValueError('Unsafe P04 target directory')
                for name in ('run-summary.json', 'observation-cases.json', 'standard-user.json'):
                    if (folder / name).relative_to(p04_path.parent).as_posix() not in seen:
                        raise ValueError('P04 outcome is not checksum-bound')
                machine = 'aa64' if target['runner'] == 'windows-11-arm' else '8664'
                module.check_target(folder, p04['tested_commit'], machine)
            for entry in p04['tested_sources']:
                path = (root / entry['path']).resolve()
                if not path.is_relative_to(root.resolve()):
                    raise ValueError('Unsafe P04 tested source path')
                verify_file(path, entry['sha256'], entry['size'])

    p05_path = root / 'docs/evidence/p05/manifest.json'
    if p05_path.exists():
        p05 = json.loads(p05_path.read_text())
        if (p05['phase'] != 'P05' or p05['result'] not in {'DONE', 'BLOCKED'}
                or not re.fullmatch(r'[0-9a-f]{40}', p05['tested_commit'])
                or p05['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{p05['run_id']}"):
            raise ValueError('Invalid P05 source/run provenance')
        seen = set()
        for entry in p05['files']:
            path = (p05_path.parent / entry['path']).resolve()
            if entry['path'] in seen or not path.is_relative_to(p05_path.parent.resolve()):
                raise ValueError('Unsafe/duplicate P05 evidence path')
            seen.add(entry['path'])
            verify_file(path, entry['sha256'], entry['size'])
        if p05['result'] == 'DONE':
            if (not p04_path.exists() or p04['result'] != 'DONE'
                    or p04['tested_commit'] != p05['tested_commit']):
                raise ValueError('P05 DONE requires current P03/P04 regression for the same source')
            if {t['runner'] for t in p05['targets']} != {'windows-2025', 'windows-11-arm'}:
                raise ValueError('Both P05 native laboratories required')
            import importlib.util
            module_spec = importlib.util.spec_from_file_location('p05_retainer', root / 'tools/lab/retain_p05_evidence.py')
            module = importlib.util.module_from_spec(module_spec)
            module_spec.loader.exec_module(module)
            for target in p05['targets']:
                folder = (p05_path.parent / target['evidence_directory']).resolve()
                if not folder.is_relative_to(p05_path.parent.resolve()):
                    raise ValueError('Unsafe P05 target directory')
                for path in folder.glob('*.json'):
                    if path.relative_to(p05_path.parent).as_posix() not in seen:
                        raise ValueError('P05 report is not checksum-bound')
                module.check_target(folder, p05['tested_commit'], 'aa64' if target['runner'] == 'windows-11-arm' else '8664')
            for entry in p05['tested_sources']:
                path = (root / entry['path']).resolve()
                if not path.is_relative_to(root.resolve()):
                    raise ValueError('Unsafe P05 tested source path')
                verify_file(path, entry['sha256'], entry['size'])



    p06_path = root / 'docs/evidence/p06/manifest.json'
    if p06_path.exists():
        p06 = json.loads(p06_path.read_text())
        if p06['phase'] != 'P06' or p06['result'] not in {'DONE', 'BLOCKED'} or not re.fullmatch('[0-9a-f]{40}', p06['tested_commit']):
            raise ValueError('Invalid P06 phase/source')
        seen = set()
        for entry in p06['files']:
            path = (p06_path.parent / entry['path']).resolve()
            if entry['path'] in seen or not path.is_relative_to(p06_path.parent.resolve()):
                raise ValueError('Unsafe/duplicate P06 evidence path')
            seen.add(entry['path'])
            verify_file(path, entry['sha256'], entry['size'])
        if p06['result'] == 'DONE':
            for phase in ('p03', 'p04', 'p05'):
                dependency = json.loads((root / f'docs/evidence/{phase}/manifest.json').read_text())
                if dependency['result'] != 'DONE' or dependency['tested_commit'] != p06['tested_commit']:
                    raise ValueError('P06 DONE requires matching current P03/P04/P05 regression')
            if p06['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{p06['run_id']}" or p06['run_id'] <= 0:
                raise ValueError('Invalid P06 run provenance')
            if len(p06['targets']) != 2 or {t['runner'] for t in p06['targets']} != {'windows-2025', 'windows-11-arm'}:
                raise ValueError('P06 requires both Windows laboratories')
            import importlib.util
            module_spec = importlib.util.spec_from_file_location('p06_gate', root / 'tools/lab/retain_p06_evidence.py')
            module = importlib.util.module_from_spec(module_spec)
            module_spec.loader.exec_module(module)
            for target in p06['targets']:
                folder = p06_path.parent / target['evidence_directory']
                for name in ('run-summary.json', 'control-cases.json', *(f'standard-{mode}.json' for mode in ('normal', 'reserved', 'accepted', 'scope', 'sessions'))):
                    if (folder / name).relative_to(p06_path.parent).as_posix() not in seen:
                        raise ValueError('P06 required report is not checksum-bound')
                module.check_target(folder, p06['tested_commit'], 'aa64' if target['runner'] == 'windows-11-arm' else '8664')
            if not p06['tested_sources']:
                raise ValueError('P06 tested source bindings absent')
            for entry in p06['tested_sources']:
                path = (root / entry['path']).resolve()
                if not path.is_relative_to(root.resolve()):
                    raise ValueError('Unsafe P06 source path')
                verify_file(path, entry['sha256'], entry['size'])


if __name__ == '__main__':
    try:
        validate(ROOT)
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
    print('PASS: original specification, links, candidate pin, phase evidence and 66 unrun acceptance entries')
