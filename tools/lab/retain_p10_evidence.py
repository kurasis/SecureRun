"""Close integrated review only with exact-source P03-P09 proof on both Windows labs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = {'windows-2025', 'windows-11-arm'}
CASE_FILES = {3: 'command-boundary.json', 4: 'observation-cases.json',
              5: 'policy-cases.json', 6: 'control-cases.json', 7: 'file-cases.json',
              8: 'lifecycle-cases.json', 9: 'product-cases.json'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def source_paths(root=ROOT):
    paths = {'Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', '.cargo/config.toml',
             'docs/engine-candidate.json',
             'package.json', 'package-lock.json', 'index.html', 'tsconfig.json', 'vite.config.ts', '.gitattributes'}
    paths.update(p.relative_to(root).as_posix()
                 for base in ('crates', 'src-tauri', 'ui', 'tools') for p in (root / base).rglob('*')
                 if p.is_file() and 'gen' not in p.parts and p.suffix in {
                     '.rs', '.toml', '.json', '.ts', '.tsx', '.css', '.c', '.cs', '.ps1', '.py',
                     '.js', '.sql', '.svg', '.png', '.ico'})
    return sorted(paths | {
        p.relative_to(root).as_posix() for base in ('.github/workflows', 'tests')
        for p in (root / base).rglob('*') if p.is_file() and p.suffix in {'.yml', '.py', '.ts'}
    })


def commands(root=ROOT):
    build = (root / 'src-tauri/build.rs').read_text()
    return set(re.findall(r'^\s+"([a-z_]+)",?$', build, re.M))


def check_integrated(root, commit):
    """Recheck independent source manifests and raw native assertions, not just counts."""
    proof = {runner: {} for runner in RUNNERS}
    dependencies = []
    for phase in range(3, 10):
        path = root / f'docs/evidence/p{phase:02}/manifest.json'
        manifest = read(path)
        if manifest['result'] != 'DONE' or manifest['tested_commit'] != commit:
            raise ValueError('P10 requires all P03-P09 gates on the same exact source')
        if len(manifest['targets']) != 2 or {t['runner'] for t in manifest['targets']} != RUNNERS:
            raise ValueError('P10 requires both native laboratories for every gate')
        dependencies.append(record(path, path.relative_to(root).as_posix()))
        for target in manifest['targets']:
            folder = path.parent / target['evidence_directory']
            cases = read(folder / CASE_FILES[phase])
            if phase == 3:
                cases = cases['cases']
            proof[target['runner']][phase] = (folder, cases)
    for runner, phases in proof.items():
        folder, cases = phases[3]
        names = {c['name'] for c in cases if c['passed']}
        if not {'valid_diagnostic_preview_cannot_save_in_unknown_native_context',
                'refused_diagnostic_save_consumes_preview_without_picker',
                'local_ungranted_webview_denied', 'remote_origin_commands_denied',
                'all_17_commands_attempted_from_ungranted_local_webview',
                'all_17_commands_attempted_from_remote_origin'}.issubset(names):
            raise ValueError('P10 unknown-context diagnostic and IPC regressions missing')
        required = commands(root)
        if len(required) != 17:
            raise ValueError('Review newly registered application commands before P10 closure')
        for file in ('ui/selftest.ts', 'src-tauri/src/ci.rs'):
            content = (root / file).read_text()
            if not required.issubset(set(re.findall(r"'([a-z_]+)'", content))):
                raise ValueError('P10 must exercise every application command from both denied origins')
        folder, cases = phases[5]
        boxed = read(folder / 'boxed-policy.json')
        boundaries = boxed.get('worker_boundaries', [])
        if (boxed['status'] != 'PASSED' or len(boundaries) != 4
                or {b['mode'] for b in boundaries} != {'control', 'files', 'lifecycle', 'product'}
                or any(b['reason'] != 'MANAGER_CONTEXT_UNSAFE'
                       or not b['actual_boxed_execution'] or b['claimed_unboxed_parent_accepted']
                       for b in boundaries)):
            raise ValueError('P10 actual same-SID boxed worker attacks missing')
        by_name = {c['name']: c['evidence'] for c in cases}
        reports = by_name['actual_baseline_report_t12']['reports']
        if len(reports) != (3 if runner == 'windows-11-arm' else 2):
            raise ValueError('P10 requires native/x86/emulated network coverage')
        for report in reports:
            if (not report['endpoint_control_counts'] or any(n < 1 for n in report['endpoint_control_counts'])
                    or report['dns_server_observed'] or any(report['incoming_host_observed'])
                    or not report['smb_host_positive'] or not report['mapped_share_host_positive']
                    or report['icmp_observer']['target_packets'] != 0):
                raise ValueError('P10 network positive/server observations failed')
            for observed in (report['report'], report['report']['child_network']):
                if observed['dns_network'] or any(observed['sockets']):
                    raise ValueError('P10 offline target/child egress observed')
        if not by_name['online_policy_keeps_file_and_sibling_protection']['controlled_tcp_udp_ipv4_ipv6_positive']:
            raise ValueError('P10 online policy positive control absent')
    return proof, dependencies


def catalog(proof, root=ROOT):
    rows = []
    for scenario in read(root / 'docs/test-catalog.json'):
        identifier = scenario['id']
        references = []
        for runner, phases in sorted(proof.items()):
            for phase, (folder, cases) in phases.items():
                matches = [c['name'] for c in cases if identifier in [c['id'], *c.get('also_ids', [])]
                           and (c.get('status') == 'PASSED' or c.get('passed') is True)]
                if matches:
                    references.append({'runner': runner, 'phase': f'P{phase:02}',
                                       'path': (folder / CASE_FILES[phase]).relative_to(root).as_posix(),
                                       'cases': matches})
        status = 'PASSED_APPLICABLE_FEATURE_SCOPE'
        scope = 'Production-path phase checks; final installed-candidate acceptance remains P12.'
        if identifier == 'T29':
            status, scope = 'ASSIGNED_P11', 'Installer upgrade/uninstall is outside P10; no packaging pass claimed.'
        elif identifier == 'T32':
            status, scope = 'NOT_APPLICABLE_NOT_ADVERTISED', 'No clipboard/device restriction is advertised or enabled; generic P09 case tags do not prove these controls.'
        elif identifier == 'T52':
            status, scope = 'NOT_APPLICABLE_NO_HELPER', 'No product elevation or different-administrator UAC route exists.'
        elif identifier == 'T48':
            scope = 'Archive/unarchive passed; uninstall retention and installed migration/rollback remain P11/P12.'
        elif identifier in {'T27', 'T47', 'T57'}:
            scope = 'Applicable boxed-client, ownership and forged-metadata checks passed; privileged-helper subcases are N/A because no helper exists.'
        elif identifier == 'T54':
            scope = 'Scoped Stop under launch-policy ineligibility passed; no paid preset/certificate path is enabled.'
        if status.startswith('PASSED') and {ref['runner'] for ref in references} != RUNNERS:
            raise ValueError(f'P10 scenario lacks both native targets: {identifier}')
        rows.append({'id': identifier, 'status': status, 'scope': scope, 'evidence': references,
                     'installed_acceptance': 'NOT_STARTED'})
    return rows


def retain(commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Exact source/run required')
    # The repository validator checks every dependency raw file, gate and source hash.
    subprocess.run(['python', 'tools/lab/validate_repository.py'], cwd=ROOT, check=True)
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json',
                                            'headSha,status,conclusion'], cwd=ROOT))
    if run != {'headSha': commit, 'status': 'completed', 'conclusion': 'success'}:
        raise ValueError('P10 full integration run did not pass at the exact source')
    proof, dependencies = check_integrated(ROOT, commit)
    rows = catalog(proof)
    sources = []
    for path in source_paths():
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError(f'Stale P10 source: {path}')
        sources.append(record(ROOT / path, path))
    directory = ROOT / 'docs/evidence/p10'
    directory.mkdir(parents=True, exist_ok=True)
    trace = directory / 'integration-catalog.json'
    trace.write_text(json.dumps(rows, indent=2) + '\n')
    manifest = {'phase': 'P10', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                'dependencies': dependencies, 'tested_sources': sources,
                'files': [record(trace, trace.name)],
                'unresolved_mandatory_containment_findings': [],
                'review_kind': 'INTERNAL_IMPLEMENTATION_REVIEW_NOT_INDEPENDENT_AUDIT',
                'production_acceptance_scenarios_passed': 0,
                'release_prerequisites': ['P11 packaging/install/upgrade/uninstall', 'P12 installed-candidate T01-T66 acceptance']}
    (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('P10: exact-source integrated gates and all 66 scoped scenario dispositions retained')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.tested_commit, args.run_id)
