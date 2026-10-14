import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import type { Environment, Operation, Snapshot, StateEvent } from './contracts';
declare global { interface Window { __foundationAclDenied?: boolean; __foundationTestsStarted?: boolean; __foundationPickerWaiting?: boolean; __foundationReportStarted?: boolean } }
export async function run(unauthorized: boolean) {
  if (window.__foundationTestsStarted) return; window.__foundationTestsStarted = true;
  if (unauthorized) {
    let denied = true;
    for (const command of ['get_snapshot', 'create_draft', 'reserve_operation', 'diagnostic_summary', 'ci_report']) {
      try { await invoke(command, { request: { display_name: 'UNAUTHORIZED' }, cases: [] }); denied = false; } catch (error) { denied &&= typeof error === 'string' && /not allowed|permission|capability|scope/i.test(error); }
    }
    window.__foundationAclDenied = denied; return;
  }
  const cases: { id: string; name: string; passed: boolean }[] = [];
  const check = (id: string, name: string, passed: boolean) => cases.push({ id, name, passed });
  const denied = async (command: string, payload: Record<string, unknown>) => { try { await invoke(command, payload); return false; } catch { return true; } };
  const deniedCode = async (command: string, payload: Record<string, unknown>, expected: string) => { try { await invoke(command, payload); return false; } catch (error) { return (error as { code?: string })?.code === expected; } };
  try {
    const snapshot = await invoke<Snapshot>('get_snapshot');
    check('T49', 'trusted_main_scoped_boundary', snapshot.mode === 'FOUNDATION_TEST_FIXTURE' && !snapshot.engine_operations_available);
    let observedEvent: StateEvent | undefined;
    let eventArrived: (() => void) | undefined;
    const arrival = new Promise<void>(resolve => { eventArrived = resolve; });
    const unlisten = await listen<StateEvent>('manager-state', event => { observedEvent = event.payload; eventArrived?.(); });
    const environment = await invoke<Environment>('create_draft', { request: { display_name: 'P03 native IPC fixture' } });
    await Promise.race([arrival, new Promise(resolve => setTimeout(resolve, 5000))]); unlisten();
    check('T56', 'backend_event_has_independent_generations_and_sequence', observedEvent?.environment_id === environment.id && observedEvent.environment_generation === environment.generation && observedEvent.engine_generation === snapshot.engine_generation && observedEvent.sequence > snapshot.sequence);
    check('T49', 'renderer_cannot_emit_authoritative_state', await denied('plugin:event|emit', { event: 'manager-state', payload: {} }));
    check('T28', 'typed_metadata_draft_never_claims_ready', environment.lifecycle === 'UNCONFIGURED' && environment.activity === 'UNKNOWN' && environment.eligibility === 'UNVERIFIED');
    check('T49', 'forged_path_and_confirmation_rejected', await denied('create_draft', { request: { display_name: 'P03_SYNTHETIC_SECRET', path: 'P03_SYNTHETIC_SECRET_PATH', confirmed: true } }));
    check('T66', 'control_character_label_rejected', await deniedCode('create_draft', { request: { display_name: 'P03_SYNTHETIC_SECRET\r\nFORGED_EVENT' } }, 'INVALID_INPUT'));
    const request = { environment_id: environment.id, expected_generation: environment.generation, expected_revision: environment.desired_revision, idempotency_key: crypto.randomUUID(), kind: 'IMPORT' };
    check('T49', 'forged_environment_id_rejected', await deniedCode('reserve_operation', { request: { ...request, environment_id: crypto.randomUUID() } }, 'UNKNOWN_ENVIRONMENT'));
    check('T56', 'stale_generation_rejected_at_boundary', await deniedCode('reserve_operation', { request: { ...request, expected_generation: 999 } }, 'STALE_OPERATION'));
    check('T61', 'launch_command_surface_unavailable', await deniedCode('reserve_operation', { request: { ...request, kind: 'LAUNCH' } }, 'CAPABILITY_UNAVAILABLE'));
    const first = await invoke<Operation>('reserve_operation', { request }); const repeated = await invoke<Operation>('reserve_operation', { request });
    check('T61', 'duplicate_ipc_reservation_same_operation', first.id === repeated.id);
    check('T49', 'unbound_selection_rejected', await deniedCode('prepare_transfer', { request: { operation_id: first.id, selection_id: crypto.randomUUID(), purpose: 'IMPORT' } }, 'SELECTION_SCOPE_MISMATCH'));
    window.__foundationPickerWaiting = true;
    const selection = await invoke<{ selection_id: string } | null>('select_file', { request: { operation_id: first.id, purpose: 'IMPORT' } });
    window.__foundationPickerWaiting = false;
    check('T49', 'real_backend_native_picker_bound', selection !== null);
    if (selection) {
      check('T49', 'raw_path_cannot_replace_selection_authority', await denied('prepare_transfer', { request: { operation_id: first.id, selection_id: selection.selection_id, purpose: 'IMPORT', path: 'P03_SYNTHETIC_SECRET_PATH', confirmed: true } }));
      check('T49', 'engine_file_execution_still_unavailable', await deniedCode('prepare_transfer', { request: { operation_id: first.id, selection_id: selection.selection_id, purpose: 'IMPORT' } }, 'CAPABILITY_UNAVAILABLE'));
      check('T49', 'selection_consumed_once', await deniedCode('prepare_transfer', { request: { operation_id: first.id, selection_id: selection.selection_id, purpose: 'IMPORT' } }, 'SELECTION_SCOPE_MISMATCH'));
    }
    const diagnostics = JSON.stringify(await invoke('diagnostic_summary'));
    check('T66', 'shared_diagnostics_exclude_secret_canaries', !diagnostics.includes('P03_SYNTHETIC_SECRET') && !diagnostics.includes('FORGED_EVENT'));
  } catch { check('T49', 'foundation_command_test_completed', false); }
  window.__foundationReportStarted = true;
  await invoke('ci_report', { cases });
}
