import type { Snapshot, StateEvent } from './contracts.ts';
export function applyEvent(snapshot: Snapshot, event: StateEvent): Snapshot {
  if (event.engine_generation !== snapshot.engine_generation) return snapshot;
  const environment = snapshot.environments.find(item => item.id === event.environment_id);
  if (!environment || environment.generation !== event.environment_generation || event.expected_revision !== environment.desired_revision || event.sequence <= environment.last_sequence || (event.operation_id !== null && event.operation_id !== environment.current_operation)) return snapshot;
  return { ...snapshot, environments: snapshot.environments.map(item => item.id === environment.id ? { ...item, activity: event.activity, eligibility: event.eligibility, last_sequence: event.sequence } : item) };
}
