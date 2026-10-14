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
export interface EngineHealth { generation: number; sequence: number; fresh: boolean; control_plane_safe: boolean; observation: {
  trust: string; reason: string; manager_context: string; bridge_context: string; observed_unix_ms: number;
  core_version: string | null; architecture: string; service_running: boolean; driver_running: boolean;
  restart_required: boolean; enumeration_complete: boolean; release_evidence: string;
  service_identity_complete: boolean; service_identity_reason: string;
  production_launch_available: boolean; capabilities: {name: string; availability: string; reason: string; provenance: string}[];
  boxes: {name: string; owned: boolean; read_only: boolean; activity: string; complete: boolean; reason: string;
    root: {path: string | null; identity: string | null; reason: string; scope: string};
    processes: {pid: number; creation_time: number; session: number; owner_sid: string; box_name: string}[];
    configuration: {key: string; raw: string[]; effective: string[]}[]; configuration_fingerprint: string}[];
} }
