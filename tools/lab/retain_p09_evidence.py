"""Retain actual P09 product proof only after matching P03 through P08 regressions."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
IDS = {'T30', 'T32', 'T41', 'T63', 'T66'}
REQUIRED = {
    'actual_windows_display_dpi_and_bilingual_product_layouts',
    'completed_private_diagnostics_retire_definitions_and_keep_bounded_evidence',
    'actual_ui_import_export_collision_archive_and_reset_workflow',
    'metadata_rename_preserves_identity_and_never_replays',
    'ten_real_idle_environments_and_populated_box',
    'normal_manager_startup_and_complete_process_group_idle_budget',
    'actual_normal_webview_environment_navigation',
    'real_keyboard_and_windows_screen_reader_provider',
    'english_russian_themes_and_native_webview_scaling',
    'real_process_activity_update_latency',
    'running_policy_diff_queue_requires_explicit_stopped_apply',
    'ten_thousand_files_bounded_ui_and_complete_pagination',
    'synthetic_argv_and_environment_do_not_enter_manager_logs',
    'native_diagnostic_save_matches_reviewed_minimized_bytes',
    'local_history_and_debug_error_capture_remain_minimized',
    'official_editor_saves_boxed_document_without_host_write',
    'official_archive_gui_and_create_extract_round_trip',
    'official_browser_existing_host_instance_no_url_or_cookie_handoff',
    'browser_own_child_request_stays_boxed',
    'browser_reachable_protocol_handler_does_not_escape',
    'browser_own_content_sandbox_remains_enabled',
    'launch_overhead_observed_against_same_fixed_original_dispatch',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, name):
    data = path.read_bytes()
    return {'path': name, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}


def check_target(folder, commit, machine):
    summary = read(folder / 'run-summary.json')
    cases, ui = read(folder / 'product-cases.json'), read(folder / 'ui-cases.json')
    actor = read(folder / 'standard-product.json')
    if (summary['phase'] != 'P09' or summary['result'] != 'PASSED'
            or summary.get('workload_mode') != 'FULL'
            or summary['manager_commit'] != commit or summary['pe_machine'] != machine
            or summary['build'] != 'release' or not summary['standard_user']
            or not summary['real_normal_webview'] or not summary['synthetic_profiles_only']
            or summary['browser_sandbox_disabled'] or summary['os_security_settings_modified']
            or summary['elevated_product_helper'] or summary['failed'] != 0 or summary['ui_failed'] != 0
            or not re.fullmatch('[0-9a-f]{64}', summary['manager_binary_sha256'])):
        raise ValueError('P09 native architecture/source/result is invalid')
    names = [case['name'] for case in cases]
    if (len(set(names)) != len(names) or not REQUIRED.issubset(names)
            or not IDS.issubset({c['id'] for c in cases})
            or any(c['status'] != 'PASSED' for c in cases)
            or summary['native_cases_passed'] != len(cases)
            or actor['status'] != 'PASSED' or actor['manager_commit'] != commit
            or not actor['normal_production_binary'] or not actor['standard_user']):
        raise ValueError('P09 mandatory production cases are incomplete')
    ui_names = [c['name'] for c in ui]
    expected_layout = {f'real_webview_{language}_{theme}_{scale}'
                       for language in ('en', 'ru') for theme in ('light', 'dark')
                       for scale in (100, 150, 200)}
    expected_layout.update(f'real_webview_windows_dpi_{scale}_{language}_{theme}'
                           for scale in (100, 150, 200) for language in ('en', 'ru')
                           for theme in ('light', 'dark'))
    if (len(set(ui_names)) != len(ui_names) or not expected_layout.issubset(ui_names)
            or any(not c['passed'] for c in ui) or summary['ui_cases_passed'] != len(ui)):
        raise ValueError('P09 actual bilingual/theme/scaling UI proof is incomplete')
    by_name = {c['name']: c['evidence'] for c in cases}
    dpi = by_name['actual_windows_display_dpi_and_bilingual_product_layouts']
    if (not dpi['actual_windows_display_changes'] or not dpi['production_manager_window_measured']
            or dpi['content_scale_percent'] != 100 or dpi['os_security_settings_modified']
            or dpi['native_dpi_observations'] != [dict(percent=p, native_window_dpi=96*p//100)
                                                  for p in (100, 150, 200)]):
        raise ValueError('P09 actual Windows display DPI proof is incomplete')
    keys = {
        'completed_private_diagnostics_retire_definitions_and_keep_bounded_evidence': ('all_successful_definitions_retired','root_data_retained','synthetic_reports_unchanged','no_recursive_data_deletion'),
        'actual_ui_import_export_collision_archive_and_reset_workflow': ('actual_product_ui','real_native_pickers','import_export_sha256_equal','collision_rename_preserved_original','archive_preserved_data','native_confirmations_scoped','reset_generation_incremented','reset_root_empty','host_input_and_exports_unchanged'),
        'real_keyboard_and_windows_screen_reader_provider': ('real_windows_uia', 'tab_order_actual', 'f6_navigation_actual', 'accessible_labels_and_roles', 'native_invoke_changed_page'),
        'running_policy_diff_queue_requires_explicit_stopped_apply': ('real_native_picker', 'queued_in_backend', 'explicit_whole_box_stop', 'independent_policy_readback'),
        'synthetic_argv_and_environment_do_not_enter_manager_logs': ('real_boxed_target_executed', 'synthetic_argv_received', 'inherited_environment_secret_absent', 'raw_target_errors_not_manager_events'),
        'native_diagnostic_save_matches_reviewed_minimized_bytes': ('real_native_picker', 'explicit_review_before_save', 'reviewed_bytes_equal_saved', 'secret_canaries_absent'),
        'local_history_and_debug_error_capture_remain_minimized': ('persistent_history_present', 'local_history_and_wal_scanned', 'normal_manager_stderr_scanned', 'inspected_manager_stderr_scanned', 'native_worker_error_capture_scanned', 'utf8_and_utf16_scanned', 'argv_environment_error_canaries_absent'),
        'official_editor_saves_boxed_document_without_host_write': ('real_gui_editor', 'actual_keyboard_edit_and_save', 'original_driver_member_observed', 'boxed_saved_bytes_verified', 'host_input_unchanged', 'host_output_absent'),
        'official_archive_gui_and_create_extract_round_trip': ('official_gui_observed_boxed', 'actual_archive_created', 'actual_archive_extracted', 'round_trip_sha256_matches', 'host_input_unchanged', 'host_zip_and_extraction_absent'),
        'browser_reachable_protocol_handler_does_not_escape': ('real_browser_address_action', 'actual_boxed_protocol_link_page', 'host_protocol_positive_control', 'original_registered_handler_fixture', 'reachable_handler_executed_boxed', 'host_marker_absent'),
    }
    for name, fields in keys.items():
        if not all(by_name[name][field] is True for field in fields):
            raise ValueError(f'P09 actual native boundary missing: {name}')
    if by_name['running_policy_diff_queue_requires_explicit_stopped_apply']['applied_while_running']:
        raise ValueError('P09 queued policy was falsely applied while running')
    diagnostic = by_name['native_diagnostic_save_matches_reviewed_minimized_bytes']
    if diagnostic['automatic_upload'] or diagnostic['automatic_open']:
        raise ValueError('P09 diagnostic save was not explicit')
    bundle = read(folder / 'reviewed-diagnostic-example.json')
    if (set(bundle) != {'schema', 'product', 'events', 'engine_access_events_available'}
            or bundle['schema'] != 1 or bundle['engine_access_events_available']
            or not 0 < len(bundle['events']) <= 64
            or any(set(e) != {'action', 'outcome', 'diagnostic_id', 'unix_ms'} for e in bundle['events'])):
        raise ValueError('P09 shared diagnostic minimization is invalid')
    allowed_actions = {'RENAME', 'POLICY_CREATE', 'POLICY_APPLY', 'POLICY_QUEUE', 'POLICY_DRAFT_DISCARD', 'POLICY_INSPECT', 'POLICY_REPAIR', 'REGISTER', 'LAUNCH', 'STOP', 'STOP_MANAGED', 'IMPORT', 'EXPORT', 'TRANSFER_INSPECT', 'TRANSFER_DISCARD', 'RETENTION_CHANGE', 'LIFECYCLE_INSPECT', 'DIAGNOSTIC_PREVIEW', 'DIAGNOSTIC_SAVE'}
    if bundle['product'] != 'SecureRun 0.3.0':
        raise ValueError('P09 diagnostic product schema is invalid')
    for event in bundle['events']:
        if (event['action'] not in allowed_actions or event['outcome'] not in {'OBSERVED','REFUSED','UNKNOWN'}
                or type(event['unix_ms']) is not int or event['unix_ms'] <= 0
                or str(UUID(event['diagnostic_id'])) != event['diagnostic_id']):
            raise ValueError('P09 diagnostic event contains untyped or external fields')
    text = (folder / 'reviewed-diagnostic-example.json').read_text(encoding='utf-8-sig')
    if any(secret in text for secret in ('P09_ARGV_SECRET_CANARY', 'P09_ENV_SECRET_CANARY', 'FORGED_EVENT')):
        raise ValueError('P09 shared diagnostics disclose synthetic secret input')
    performance = read(folder / 'performance.json')
    if (performance['duration_ms'] < 60000 or performance['samples'] < 200
            or performance['webview_processes'] < 2 or performance['idle_environments'] != 10
            or performance['populated_box_files'] != 10000 or performance['inspector_enabled']
            or not performance['includes_exited_child_cpu'] or not performance['job_group_complete']
            or not performance['target_and_engine_processes_excluded']
            or performance['startup_interactive_upper_bound_ms'] > 3000
            or not 0 <= performance['cpu_percent'] < 1
            or not 0 < performance['average_working_set_bytes'] < 250_000_000):
        raise ValueError('P09 reference manager group performance budget is incomplete or exceeded')
    files = read(folder / 'file-workload.json')
    if (files['total_files'] != 10000 or files['pages'] != 79 or files['maximum_page'] > 128
            or files['maximum_dom_rows'] > 128 or files['first_ui_list_ms'] <= 0):
        raise ValueError('P09 actual populated-box workload is incomplete')
    update = read(folder / 'process-update.json')
    launch = by_name['launch_overhead_observed_against_same_fixed_original_dispatch']
    if (not 0 < update['update_upper_bound_ms'] <= 2000
            or not update['real_external_boxed_member'] or not launch['same_fixed_benign_probe']
            or not launch['no_required_check_removed'] or not 0 <= launch['manager_added_upper_bound_ms'] < 1000):
        raise ValueError('P09 actual process/launch latency budget is incomplete or exceeded')
    browser = by_name['official_browser_existing_host_instance_no_url_or_cookie_handoff']
    if (not browser['preexisting_host_browser_verified'] or not browser['separate_clean_profiles']
            or not browser['explicit_profile_and_no_remote'] or browser['unboxed_handoff']
            or not browser['host_profile_cookie_absent_in_boxed_request']):
        raise ValueError('P09 existing host browser handoff was not excluded')
    requests = read(folder / 'browser-http-attribution.json')
    for kind in ('HOST_POSITIVE_CONTROL', 'BOXED_MAIN', 'BOXED_CHILD'):
        rows = [r for r in requests if r['request_kind'] == kind]
        if not rows or any(not r['source_scope_verified'] or not r['held_live_process_identity']
                           or not r['original_driver_query'] or not r['socket_owner_attributed'] for r in rows):
            raise ValueError('P09 live browser socket/driver attribution missing')
        if kind != 'HOST_POSITIVE_CONTROL' and any(not r['source_boxed'] or r['host_profile_cookie_present'] for r in rows):
            raise ValueError('P09 boxed browser used the host scope/profile')
    sandbox = by_name['browser_own_content_sandbox_remains_enabled']
    if not sandbox['real_about_support'] or not sandbox['browser_own_sandbox_enabled'] or sandbox['effective_content_sandbox_level'] <= 0:
        raise ValueError('P09 browser own sandbox was disabled or unobserved')
    pins = read(ROOT / 'tools/lab/p09-applications.json')
    applications = read(folder / 'official-applications.json')
    architecture = 'arm64' if machine == 'aa64' else 'x64'
    if len(applications) != 3 or {a['kind'] for a in applications} != {'editor', 'archive', 'browser'}:
        raise ValueError('P09 official application matrix is incomplete')
    for app in applications:
        pin = pins[app['kind']]
        if (app['version'] != pin['version'] or app['architecture'] != architecture
                or app['source'] != pin['source'] or app['url'] != pin[architecture]['url']
                or app['hash_algorithm'] != pin['algorithm'] or app['package_hash'] != pin[architecture]['hash']
                or not re.fullmatch('[0-9a-f]{64}', app['executable_sha256'])
                or not app['file_version'] or app['bytes'] <= 0
                or app['signature_status'] not in ({'Valid', 'NotSigned'} if app['kind'] == 'archive' else {'Valid'})):
            raise ValueError('P09 application source/version/integrity evidence is invalid')
    return summary


def source_paths(root=ROOT):
    paths=['Cargo.toml','Cargo.lock','rust-toolchain.toml','.cargo/config.toml','package.json','package-lock.json','index.html','tsconfig.json','vite.config.ts','tests/product_ui.test.ts','.github/workflows/p09.yml']
    paths += [p.relative_to(root).as_posix() for base in ('crates','src-tauri','ui','tools') for p in sorted((root/base).rglob('*')) if p.is_file() and 'gen' not in p.parts and p.suffix in {'.rs','.toml','.json','.ts','.tsx','.css','.c','.cs','.ps1','.py','.js','.sql','.svg','.png','.ico'}]
    return paths


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('P09 exact full source and run required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'headSha,status,conclusion'], cwd=ROOT))
    if run != {'headSha': commit, 'status': 'completed', 'conclusion': 'success'}:
        raise ValueError('P09 exact source did not complete successfully')
    for phase in range(3, 9):
        dep = read(ROOT / f'docs/evidence/p{phase:02}/manifest.json')
        if dep['result'] != 'DONE' or dep['tested_commit'] != commit:
            raise ValueError('P09 requires matching current P03 through P08 regressions')
    evidence = ROOT / 'docs/evidence/p09'
    old = read(evidence / 'manifest.json') if (evidence / 'manifest.json').exists() else {}
    known = {f['path']: f for f in old.get('files', [])}
    copies, targets = [], []
    for runner, machine in (('windows-2025', '8664'), ('windows-11-arm', 'aa64')):
        folder = download / f'p09-{runner}-{commit}'
        summary = check_target(folder, commit, machine)
        relative = f'completion-{commit[:7]}/{runner}'
        for source in sorted(folder.iterdir()):
            if source.suffix not in {'.json', '.png'}:
                continue
            destination = evidence / relative / source.name
            if destination.exists() and destination.read_bytes() != source.read_bytes():
                raise ValueError('Historical P09 proof cannot be overwritten')
            copies.append((source, destination))
            known[f'{relative}/{source.name}'] = record(source, f'{relative}/{source.name}')
        targets.append({'runner': runner, 'evidence_directory': relative, 'summary': summary})
    paths = source_paths()
    sources = []
    for path in paths:
        if (ROOT / path).read_bytes() != subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT):
            raise ValueError(f'Stale P09 source: {path}')
        sources.append(record(ROOT / path, path))
    for source, destination in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    history = old.get('historical_runs', [])
    if old.get('tested_commit') and old['tested_commit'] != commit:
        history.append({key: old[key] for key in ('result', 'tested_commit', 'run_id', 'url', 'note') if key in old})
    manifest = {'phase': 'P09', 'result': 'DONE', 'tested_commit': commit, 'run_id': run_id,
                'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}', 'targets': targets,
                'files': list(known.values()), 'tested_sources': sources, 'historical_runs': history,
                'production_acceptance_scenarios_passed': 0,
                'note': 'Actual product UX, official apps and performance; installed-candidate acceptance remains P12.'}
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(targets, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
