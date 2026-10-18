"""Build a target-specific dependency/notice inventory from locked local inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tomllib
import urllib.request


def digest(data):
    return hashlib.sha256(data).hexdigest()


def generate(root, target, output):
    metadata = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--locked', '--format-version', '1'], cwd=root))
    graph = subprocess.check_output(['cargo', 'tree', '--locked', '--workspace', '--target', target,
                                    '-e', 'normal,build', '--prefix', 'none', '--format', '{p}'],
                                   cwd=root, text=True, encoding='utf-8')
    selected = set(re.findall(r'^([\w-]+) v([^\s]+)', graph, re.M))
    supplements = json.loads((root / 'packaging/license-supplements.json').read_text(encoding='utf-8'))
    cargo_checksums = {(p['name'], p['version']): p.get('checksum')
                       for p in tomllib.loads((root / 'Cargo.lock').read_text(encoding='utf-8'))['package']}
    inventory, notices = [], []
    for package in sorted(metadata['packages'], key=lambda p: (p['name'], p['version'])):
        if (package['name'], package['version']) not in selected:
            continue
        if package['source'] is None:
            inventory.append({'ecosystem': 'cargo', 'name': package['name'],
                              'version': package['version'], 'license': 'OWNER_LICENSE_NOT_SELECTED',
                              'scope': 'ORIGINAL_MANAGER_SOURCE'})
            continue
        home = Path(package['manifest_path']).parent
        texts = sorted({p for p in home.iterdir() if p.is_file() and
                        re.match(r'(?i)^(licen[sc]e|copying|notice|copyright)', p.name)})
        if package.get('license_file'):
            texts = sorted(set(texts) | {home / package['license_file']})
        records = []
        if not texts:
            supplement = next((s for s in supplements if (s['name'], s['version']) ==
                               (package['name'], package['version'])), None)
            vcs = json.loads((home / '.cargo_vcs_info.json').read_text(encoding='utf-8'))
            if not supplement or vcs['git']['sha1'] != supplement['commit']:
                raise ValueError(f"Missing pinned license text: {package['name']}")
            data = urllib.request.urlopen(supplement['url'], timeout=60).read()
            if digest(data) != supplement['sha256']:
                raise ValueError('Supplemental license checksum mismatch')
            records.append({'name': 'UPSTREAM_LICENSE', 'sha256': digest(data),
                            'url': supplement['url'], 'source_commit': supplement['commit']})
            notices.append(f"\n===== Cargo {package['name']} {package['version']} / UPSTREAM_LICENSE =====\n"
                           + data.decode('utf-8'))
        for path in texts:
            data = path.read_bytes()
            records.append({'name': path.name, 'sha256': digest(data)})
            notices.append(f"\n===== Cargo {package['name']} {package['version']} / {path.name} =====\n"
                           + data.decode('utf-8', errors='replace'))
        inventory.append({'ecosystem': 'cargo', 'name': package['name'], 'version': package['version'],
                          'license': package['license'], 'registry': package['source'],
                          'source_archive': f"https://static.crates.io/crates/{package['name']}/{package['name']}-{package['version']}.crate",
                          'source_archive_sha256': cargo_checksums[(package['name'], package['version'])],
                          'scope': 'WINDOWS_RUNTIME_OR_BUILD_DEPENDENCY', 'notices': records})
    sdk = json.loads((root / 'packaging/microsoft-sdk.json').read_text(encoding='utf-8'))
    binding = next(p for p in metadata['packages'] if p['name'] == 'webview2-com-sys')
    binding_home = Path(binding['manifest_path']).parent
    for loader in sdk['loaders']:
        if digest((binding_home / loader['architecture'] / loader['name']).read_bytes()) != loader['sha256']:
            raise ValueError('Microsoft WebView2 static loader changed from reviewed official SDK')
    for entry in sdk['notices']:
        data = (root / 'packaging/notices' / entry['name']).read_bytes()
        if digest(data) != entry['sha256']:
            raise ValueError('Microsoft SDK notice changed')
        notices.append('\n===== Microsoft WebView2 SDK ' + sdk['version'] + ' / ' + entry['name'] + ' =====\n'
                       + data.decode('utf-8-sig'))
    inventory.append({'ecosystem': 'microsoft-sdk', 'name': sdk['name'], 'version': sdk['version'],
                      'license': sdk['license'], 'scope': 'STATICALLY_LINKED_WEBVIEW2_LOADER',
                      'source_package': sdk['url'], 'source_package_sha256': sdk['sha256'],
                      'notices': sdk['notices'], 'loader_bytes_match_official_sdk': True})
    sysroot = Path(subprocess.check_output(['rustc', '--print', 'sysroot'], cwd=root,
                                          text=True, encoding='utf-8').strip())
    rust_version = subprocess.check_output(['rustc', '--version'], cwd=root,
                                           text=True, encoding='utf-8').strip()
    rust_notice = (sysroot / 'share/doc/rust/COPYRIGHT-library.html').read_bytes()
    notices.append('\n===== Rust standard library original notices =====\n' + rust_notice.decode('utf-8'))
    inventory.append({'ecosystem': 'rust-toolchain', 'name': 'Rust standard library',
                      'version': rust_version, 'license': 'Apache-2.0 OR MIT, with original incorporated-code notices',
                      'scope': 'LINKED_STANDARD_LIBRARY',
                      'notices': [{'name': 'COPYRIGHT-library.html', 'sha256': digest(rust_notice)}]})
    sqlite_package = next(p for p in metadata['packages'] if p['name'] == 'libsqlite3-sys')
    sqlite_home = Path(sqlite_package['manifest_path']).parent / 'sqlite3'
    sqlite_source = (sqlite_home / 'sqlite3.c').read_bytes()
    sqlite_header = (sqlite_home / 'sqlite3.h').read_text(encoding='utf-8')
    sqlite_version = re.search(r'#define SQLITE_VERSION\s+"([^"]+)"', sqlite_header).group(1)
    at = sqlite_source.index(b'The author disclaims copyright')
    license_header = sqlite_source[sqlite_source.rfind(b'/*', 0, at):sqlite_source.index(b'*/', at) + 2]
    notices.append('\n===== Bundled SQLite ' + sqlite_version + ' original public-domain statement =====\n'
                   + license_header.decode('utf-8'))
    inventory.append({'ecosystem': 'bundled-c', 'name': 'SQLite', 'version': sqlite_version,
                      'license': 'PUBLIC_DOMAIN_UPSTREAM_STATEMENT', 'scope': 'BUNDLED_SQLITE_CORE',
                      'wrapper': 'libsqlite3-sys ' + sqlite_package['version'],
                      'amalgamation_sha256': digest(sqlite_source),
                      'notices': [{'name': 'sqlite3.c public-domain header', 'sha256': digest(license_header)}]})
    lock = json.loads((root / 'package-lock.json').read_text(encoding='utf-8'))
    for location, locked in sorted(lock['packages'].items()):
        if not location:
            continue
        home = root / location
        if not (home / 'package.json').is_file():
            continue  # Optional binaries for a different build host are not copied.
        package = json.loads((home / 'package.json').read_text(encoding='utf-8'))
        texts = sorted(p for p in home.iterdir() if p.is_file() and
                       re.match(r'(?i)^(licen[sc]e|copying|notice|copyright)', p.name))
        notice_origin = package['name']
        for binary_prefix, parent_name in (('@rolldown/binding-', 'rolldown'),
                                           ('@tauri-apps/cli-', '@tauri-apps/cli')):
            if not texts and package['name'].startswith(binary_prefix):
                parent = root / 'node_modules' / parent_name
                parent_meta = json.loads((parent / 'package.json').read_text(encoding='utf-8'))
                if (parent_meta['version'], parent_meta['license']) != (package['version'], package['license']):
                    raise ValueError('Native npm binding notice version/license mismatch')
                texts = sorted(p for p in parent.iterdir() if p.is_file() and
                               re.match(r'(?i)^(licen[sc]e|copying|notice|copyright|third-party-license)', p.name))
                notice_origin = parent_name
        if not texts:
            raise ValueError(f"Missing license text: {package['name']}")
        records = []
        for path in texts:
            data = path.read_bytes()
            records.append({'name': path.name, 'sha256': digest(data)})
            notices.append(f"\n===== npm {package['name']} {package['version']} / {path.name} =====\n"
                           + data.decode('utf-8', errors='replace'))
        inventory.append({'ecosystem': 'npm', 'name': package['name'], 'version': package['version'],
                          'license': package.get('license', locked.get('license', 'UNDECLARED')),
                          'scope': 'FRONTEND_BUILD_TOOL' if locked.get('dev') else 'BUNDLED_FRONTEND',
                          'integrity': locked.get('integrity'), 'notice_origin': notice_origin, 'notices': records})
    text = '\n'.join(notices).encode()
    output.mkdir(parents=True, exist_ok=True)
    (output / 'THIRD_PARTY_NOTICES.txt').write_bytes(text)
    document = {'schema': 1, 'target': target, 'manager_license': 'NOT_SELECTED_BY_OWNER',
                'distribution_status': 'DEVELOPMENT_ONLY_NO_PRODUCTION_LICENSE_CLEARANCE',
                'cargo_lock_sha256': digest((root / 'Cargo.lock').read_bytes()),
                'npm_lock_sha256': digest((root / 'package-lock.json').read_bytes()),
                'notices_sha256': digest(text), 'components': inventory,
                'external_not_bundled': ['Sandboxie', 'Microsoft WebView2 runtime'],
                'installer_runtime': {'name': 'Inno Setup', 'version': '6.7.3',
                                      'license': 'Inno Setup License (modified BSD)',
                                      'notice': 'INNO_LICENSE.txt'},
                'microsoft_bootstrapper': 'Unmodified Microsoft-signed prerequisite; separate Microsoft terms'}
    pins = json.loads((root / 'packaging/toolchain.json').read_text(encoding='utf-8'))
    architectures = ['x86', 'x64'] + (['arm64'] if target.startswith('aarch64') else [])
    document['microsoft_crt_prerequisites'] = [dict(pins['vcredist'][arch], architecture=arch)
                                            for arch in architectures]
    document['microsoft_crt_terms'] = 'https://visualstudio.microsoft.com/license-terms/vs2022-cruntime/'
    (output / 'dependency-inventory.json').write_text(json.dumps(document, indent=2) + '\n')
    return document


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = generate(Path(__file__).resolve().parents[1], args.target, args.output)
    print(json.dumps({'components': len(result['components']), 'target': args.target}))
