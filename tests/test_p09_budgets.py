"""Engineering deviations require complete measurements and honest explanations."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('p09_budget_retainer', ROOT / 'tools/lab/retain_p09_evidence.py')
BUDGETS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUDGETS)


def fixture():
    return ({'idle_environments': 10, 'populated_box_files': 10000, 'inspector_enabled': False,
             'job_group_complete': True, 'includes_exited_child_cpu': True,
             'target_and_engine_processes_excluded': True, 'duration_ms': 60000,
             'samples': 240, 'webview_processes': 4,
             'startup_interactive_upper_bound_ms': 2500, 'cpu_percent': 0.5,
             'average_working_set_bytes': 200000000, 'startup_target_met': True,
             'idle_cpu_target_met': True, 'idle_working_set_target_met': True},
            {'update_upper_bound_ms': 1500, 'real_external_boxed_member': True},
            {'manager_added_upper_bound_ms': 500, 'same_fixed_benign_probe': True,
             'no_required_check_removed': True, 'target_met': True})


class BudgetEvidenceTests(unittest.TestCase):
    def test_exact_targets_keep_strict_and_inclusive_boundaries_distinct(self):
        performance, update, launch = fixture()
        performance.update(startup_interactive_upper_bound_ms=3000, cpu_percent=1,
                           average_working_set_bytes=250000000, idle_cpu_target_met=False,
                           idle_working_set_target_met=False)
        update['update_upper_bound_ms'] = 2000
        launch.update(manager_added_upper_bound_ms=1000, target_met=False)
        result = BUDGETS.assess_budgets(performance, update, launch)
        self.assertEqual(result['status'], 'MEASURED_DEVIATION')
        self.assertFalse(result['mandatory_checks_waived'])
        self.assertEqual([m['result'] for m in result['metrics']],
                         ['MET', 'DEVIATION', 'DEVIATION', 'MET', 'DEVIATION'])
        self.assertTrue(all(m['user_impact'] for m in result['metrics']))

    def test_reference_proof_and_actual_finite_values_cannot_be_waived(self):
        for key, value in [('idle_environments', 4), ('populated_box_files', 9999),
                           ('duration_ms', 59999), ('samples', 199), ('webview_processes', 1),
                           ('job_group_complete', False), ('inspector_enabled', True),
                           ('cpu_percent', float('nan')), ('cpu_percent', float('inf')),
                           ('cpu_percent', True), ('startup_interactive_upper_bound_ms', 0)]:
            with self.subTest(key=key, value=value):
                performance, update, launch = fixture()
                performance[key] = value
                with self.assertRaises(ValueError):
                    BUDGETS.assess_budgets(performance, update, launch)

    def test_lying_target_flags_and_removed_checks_are_refused(self):
        performance, update, launch = fixture()
        performance['cpu_percent'] = 1.5
        with self.assertRaisesRegex(ValueError, 'contradicts'):
            BUDGETS.assess_budgets(performance, update, launch)
        performance['idle_cpu_target_met'] = False
        launch['no_required_check_removed'] = False
        with self.assertRaises(ValueError):
            BUDGETS.assess_budgets(performance, update, launch)

    def test_missing_or_changed_explanations_never_become_phase_evidence(self):
        performance, update, launch = fixture()
        performance.update(cpu_percent=1.5, idle_cpu_target_met=False)
        expected = BUDGETS.assess_budgets(performance, update, launch)
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            path = folder / 'performance-budget-assessment.json'
            with self.assertRaises(FileNotFoundError):
                BUDGETS.check_budget_assessment(folder, performance, update, launch)
            changed = copy.deepcopy(expected)
            changed['metrics'][1]['user_impact'] = ''
            path.write_text(json.dumps(changed))
            with self.assertRaises(ValueError):
                BUDGETS.check_budget_assessment(folder, performance, update, launch)
            path.write_text(json.dumps(expected))
            self.assertEqual(BUDGETS.check_budget_assessment(folder, performance, update, launch), expected)
