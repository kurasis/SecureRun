export type Activity = 'UNKNOWN' | 'IDLE' | 'STARTING' | 'RUNNING' | 'STOPPING' | 'CLEANING';
export type Eligibility = 'UNVERIFIED' | 'ALLOWED' | 'BLOCKED';
export interface Environment {
  id: string; display_name: string; generation: number; desired_revision: number;
  verified_revision: number | null; lifecycle: 'UNCONFIGURED' | 'ACTIVE' | 'ARCHIVED' | 'REMOVED';
  activity: Activity; eligibility: Eligibility; current_operation: string | null; last_sequence: number;
}
export interface Snapshot { engine_generation: number; sequence: number; environments: Environment[]; mode: 'READ_ONLY_SETUP' | 'FOUNDATION_TEST_FIXTURE'; mutations_available: boolean; engine_operations_available: boolean; reason: string }
export interface StateEvent { environment_id: string; environment_generation: number; engine_generation: number; sequence: number; activity: Activity; eligibility: Eligibility; expected_revision: number; operation_id: string | null }
export interface Operation { id: string; environment_id: string; environment_generation: number; requested_revision: number; kind: 'IMPORT' | 'EXPORT' | 'LAUNCH'; dispatch_state: string }
export interface AppError { code: string; diagnostic_id: string }
