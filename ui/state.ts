import type { Snapshot, StateEvent } from './contracts.ts';
export function applyEvent(snapshot: Snapshot, event: StateEvent): Snapshot {
  if (event.engine_generation !== snapshot.engine_generation) return snapshot;
  const environment = snapshot.environments.find(item => item.id === event.environment_id);
  if (!environment || environment.generation !== event.environment_generation || event.expected_revision !== environment.desired_revision || event.sequence <= environment.last_sequence || (event.operation_id !== null && event.operation_id !== environment.current_operation)) return snapshot;
  return { ...snapshot, sequence: Math.max(snapshot.sequence, event.sequence), environments: snapshot.environments.map(item => item.id === environment.id ? { ...item, activity: event.activity, eligibility: event.eligibility, last_sequence: event.sequence } : item) };
}

export function acceptSnapshot(current: Snapshot | null, incoming: Snapshot): Snapshot {
  if (current && (incoming.engine_generation < current.engine_generation || (incoming.engine_generation === current.engine_generation && incoming.sequence < current.sequence))) return current;
  return incoming;
}
