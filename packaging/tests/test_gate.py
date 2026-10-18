"""A failed or partial installed run must never close the packaging gate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('p11_gate', ROOT / 'packaging/retain.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class PackagingGate(unittest.TestCase):
    def test_failed_installed_run_cannot_close_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'run-summary.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'FAILED', 'tested_commit': 'a' * 40,
                'target': 'x86_64-pc-windows-msvc', 'os_build': 26100}))
            with self.assertRaises(ValueError):
                gate.check_target(folder, 'windows-2025', 'a' * 40)

    def test_wrong_architecture_cannot_close_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'run-summary.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'PASSED', 'tested_commit': 'a' * 40,
                'target': 'x86_64-pc-windows-msvc', 'os_build': 26100}))
            with self.assertRaises(ValueError):
                gate.check_target(folder, 'windows-11-arm', 'a' * 40)

    def test_installed_evidence_cannot_waive_final_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / 'docs/evidence/p11'
            folder.mkdir(parents=True)
            (folder / 'manifest.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'DONE', 'final_acceptance_scenarios_passed': 1}))
            with self.assertRaises(ValueError):
                gate.validate(root)

    def test_required_cases_include_actual_missing_prerequisite_and_data_retention(self):
        self.assertEqual(len(gate.MANDATORY), 28)
        self.assertIn('official_webview_prerequisite_matches_os_baseline', gate.MANDATORY)
        self.assertIn('uninstall_removes_only_code_and_retains_profile_engine_runtime', gate.MANDATORY)
        self.assertIn('future_schema_is_refused_without_downgrade', gate.MANDATORY)
        self.assertIn('installed_stopped_engine_refuses_registered_target_without_host_fallback', gate.MANDATORY)
        self.assertIn('installed_changed_engine_binary_refuses_registered_target_without_host_fallback', gate.MANDATORY)
        self.assertIn('installed_offline_baseline_has_parent_child_and_server_observations', gate.MANDATORY)

    def test_claimed_network_pass_cannot_hide_actual_server_egress(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            name = 'seed-probe-evidence-' + 'a' * 32 + '.json'
            data = {'probe_sha256': 'b' * 64, 'dns_server_observed': False,
                    'server_observed': [False] * 6, 'incoming_host_observed': [False] * 4,
                    'endpoint_control_counts': [1] * 6, 'host_file_unchanged': True,
                    'host_registry_unchanged': True,
                    'report': {'dns_network': False, 'sockets': [False] * 6,
                               'child_network': {'dns_network': False, 'sockets': [False] * 6}}}
            event = {'original_probe_reports': [name], 'actual_installed_verifier': True,
                     'parent_child_and_live_server_controls': True, 'network_egress_observed': False}
            (folder / name).write_text(json.dumps(data))
            gate.check_offline_reports(folder, event, {'b' * 64})
            data['server_observed'][0] = True
            (folder / name).write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'server/host controls failed'):
                gate.check_offline_reports(folder, event, {'b' * 64})

    def test_preinstalled_arm_runtime_cannot_replace_server_missing_runtime_proof(self):
        evidence = {'tested_state': 'WINDOWS_11_PREINSTALLED_RUNTIME',
                    'runtime_absent_before_install': False, 'runtime_signature': 'Valid',
                    'runtime_version': '155.0.4283.62', 'security_settings_modified': False,
                    'runtime_uninstall_dispatched': False, 'missing_runtime_arm_installation_tested': False}
        self.assertFalse(gate.check_webview(evidence, 'windows-11-arm'))
        with self.assertRaises(ValueError):
            gate.check_webview(evidence, 'windows-2025')

    def test_missing_runtime_label_requires_actual_absence(self):
        with self.assertRaises(ValueError):
            gate.check_webview({'tested_state': 'ABSENT_OFFICIAL_BOOTSTRAPPER_INSTALL',
                               'runtime_absent_before_install': False, 'runtime_signature': 'Valid',
                               'runtime_version': '155.0.4283.62', 'security_settings_modified': False},
                              'windows-2025')


if __name__ == '__main__':
    unittest.main()
