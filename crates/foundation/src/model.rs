use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    Unauthorized,
    InvalidInput,
    UnknownEnvironment,
    StaleOperation,
    RevisionConflict,
    DatabaseUnavailable,
    MigrationFailed,
    CorruptRecord,
    UnsupportedSchema,
    OperationConflict,
    OperationOutcomeUnknown,
    IdentityMismatch,
    SelectionExpired,
    SelectionScopeMismatch,
    ManagerContextUnsafe,
    CapabilityUnavailable,
    PathUnsafe,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct AppError {
    pub code: ErrorCode,
    pub diagnostic_id: Uuid,
}
impl AppError {
    pub fn new(code: ErrorCode) -> Self {
        Self {
            code,
            diagnostic_id: Uuid::new_v4(),
        }
    }
}
impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?} [{}]", self.code, self.diagnostic_id)
    }
}
impl std::error::Error for AppError {}
pub type Result<T> = std::result::Result<T, AppError>;
pub fn err<T>(code: ErrorCode) -> Result<T> {
    Err(AppError::new(code))
}

macro_rules! value_enum {
    ($name:ident { $($value:ident),+ }) => {
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
        #[serde(rename_all="SCREAMING_SNAKE_CASE")]
        pub enum $name { $($value),+ }
    }
}
value_enum!(Lifecycle {
    Unconfigured,
    Active,
    Archived,
    Removed
});
value_enum!(Activity {
    Unknown,
    Idle,
    Starting,
    Running,
    Stopping,
    Cleaning
});
value_enum!(Eligibility {
    Unverified,
    Allowed,
    Blocked
});
value_enum!(OperationKind {
    Launch,
    Import,
    Export,
    ApplyPolicy,
    Cleanup
});
value_enum!(DispatchState {
    Reserved,
    Dispatched,
    Completed,
    OutcomeUnknown,
    ReconciliationRequired
});
value_enum!(SelectionPurpose { Import, Export });
value_enum!(OperationPhase {
    IntentReserved,
    ExternalDispatch,
    AwaitingReconciliation,
    Completed
});
value_enum!(RecoveryAction { None, InspectOnly });
value_enum!(NetworkMode { Offline, Online });
value_enum!(Persistence {
    Persistent,
    Disposable
});
value_enum!(TrustState {
    Unknown,
    Trusted,
    Untrusted
});
value_enum!(PathRuleKind {
    ReadDeny,
    ReadOnly,
    VirtualizedWrite,
    DirectWrite
});

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Policy {
    pub id: Uuid,
    pub schema_version: u32,
    pub preset: String,
    pub network: NetworkMode,
    pub path_rules: Vec<PathRule>,
    pub required_capabilities: Vec<String>,
    pub approved_templates: Vec<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PathRule {
    pub kind: PathRuleKind,
    pub canonical_path: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Application {
    pub id: Uuid,
    pub environment_id: Uuid,
    pub environment_generation: u64,
    pub display_name: String,
    pub target: TargetReference,
    pub arguments: Vec<String>,
    pub working_directory: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "SCREAMING_SNAKE_CASE", deny_unknown_fields)]
pub enum TargetReference {
    HostExecutable {
        canonical_path: String,
    },
    BoxedExecutable {
        logical_path: String,
        root_identity: FileIdentity,
        file_identity: FileIdentity,
        content_sha256: String,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EngineObservation {
    pub connection_generation: u64,
    pub version: String,
    pub architecture: String,
    pub installation_path: String,
    pub trust: TrustState,
    pub observed_at: u64,
    pub available_capabilities: Vec<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExportRecord {
    pub operation_id: Uuid,
    pub source_identity: FileIdentity,
    pub destination_identity: Option<FileIdentity>,
    pub bytes: u64,
    pub result: DispatchState,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Environment {
    pub id: Uuid,
    pub owner_sid: String,
    pub display_name: String,
    pub generation: u64,
    pub desired_revision: u64,
    pub verified_revision: Option<u64>,
    pub lifecycle: Lifecycle,
    pub activity: Activity,
    pub eligibility: Eligibility,
    pub engine_box_name: Option<String>,
    pub root_identity: Option<FileIdentity>,
    pub current_operation: Option<Uuid>,
    pub last_sequence: u64,
    pub created_at: u64,
    pub updated_at: u64,
    pub persistence: Persistence,
    pub policy_id: Option<Uuid>,
    pub policy_version: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct FileIdentity {
    pub volume: u64,
    pub file_id: String,
    pub owner_sid: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Operation {
    pub id: Uuid,
    pub idempotency_key: Uuid,
    pub environment_id: Uuid,
    pub environment_generation: u64,
    pub requested_revision: u64,
    pub initiator_sid: String,
    pub session: u32,
    pub kind: OperationKind,
    pub dispatch_state: DispatchState,
    pub error: Option<ErrorCode>,
    pub phase: OperationPhase,
    pub recovery_action: RecoveryAction,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReservationRequest {
    pub environment_id: Uuid,
    pub expected_generation: u64,
    pub expected_revision: u64,
    pub idempotency_key: Uuid,
    pub kind: OperationKind,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StateEvent {
    pub environment_id: Uuid,
    pub environment_generation: u64,
    pub engine_generation: u64,
    pub sequence: u64,
    pub activity: Activity,
    pub eligibility: Eligibility,
    pub expected_revision: u64,
    pub operation_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ArtifactRecord {
    pub id: Uuid,
    pub operation_id: Uuid,
    pub environment_generation: u64,
    pub parent_identity: FileIdentity,
    pub identity: FileIdentity,
    pub role: ArtifactRole,
    pub leaf_name: String,
}
value_enum!(ArtifactRole {
    ImportStaging,
    ExportStaging,
    CleanupQuarantine
});

pub fn validate_name(name: &str) -> Result<String> {
    let clean = name.trim();
    if clean.is_empty()
        || clean.chars().count() > 80
        || clean.chars().any(|c| {
            c.is_control() || matches!(c, '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}')
        })
    {
        return err(ErrorCode::InvalidInput);
    }
    Ok(clean.to_owned())
}
pub fn authorized_origin(label: &str, url: &str, development: bool) -> bool {
    if label != "main" {
        return false;
    }
    let origin = url.split(['?', '#']).next().unwrap_or("");
    matches!(
        origin,
        "https://tauri.localhost/"
            | "https://tauri.localhost/index.html"
            | "tauri://localhost/"
            | "tauri://localhost/index.html"
    ) || (development
        && matches!(
            origin,
            "http://127.0.0.1:1420/" | "http://127.0.0.1:1420/index.html"
        ))
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub sequence: u64,
    pub timestamp: u64,
    pub code: AuditCode,
    pub diagnostic_id: Uuid,
}
value_enum!(AuditCode {
    DraftCreated,
    ReservationStored,
    DispatchReserved,
    RecoveryRequired,
    SelectionBound,
    RequestRejected
});

// Untrusted diagnostic payloads never become record fields, even in local debug logs.
pub fn minimized_diagnostic(
    code: AuditCode,
    _untrusted: &str,
    sequence: u64,
    timestamp: u64,
) -> AuditEntry {
    AuditEntry {
        sequence,
        timestamp,
        code,
        diagnostic_id: Uuid::new_v4(),
    }
}
