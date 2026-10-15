//! Lifecycle intent, immutable operation tombstones and inspect-only recovery.
use crate::policy::{PolicyResult, fingerprint};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::path::Path;
use uuid::Uuid;

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum State {
    #[default]
    Active,
    Archived,
}
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Mode {
    #[default]
    Persistent,
    Disposable,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Action {
    Reset,
    Archive,
    Unarchive,
    Remove,
    Persistent,
    Disposable,
    Resume,
}
impl Action {
    pub fn destructive(self) -> bool {
        matches!(self, Self::Reset | Self::Remove)
    }
    pub fn retention(self) -> &'static str {
        match self {
            Self::Reset => {
                "Delete all boxed contents. Keep the environment definition and application records. Imported executable references become unavailable."
            }
            Self::Remove => {
                "Delete all boxed contents, then remove the engine definition. Keep an audit tombstone and the verified empty root identity."
            }
            Self::Archive => {
                "Keep the definition, applications and all data. Disable manager launch. Export and Reset remain available."
            }
            Self::Unarchive => {
                "Keep all data. Revalidate ownership, roots and policy before allowing manager launch."
            }
            Self::Persistent => {
                "Keep data and workloads after the manager exits. Never clean automatically."
            }
            Self::Disposable => {
                "Keep a unique private environment. After the last process exits, offer Resume, Export or Delete. Never export or clean automatically."
            }
            Self::Resume => {
                "Keep leftover disposable data and acknowledge a new explicit session. This does not replay a previous launch."
            }
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum Request {
    List,
    Prepare {
        environment_id: Uuid,
        expected_revision: u64,
        expected_generation: u64,
        operation_id: Uuid,
        intent: Action,
    },
    Commit {
        operation_id: Uuid,
        plan_id: Uuid,
    },
    Recover {
        operation_id: Uuid,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Record {
    pub operation_id: Uuid,
    pub plan_id: Uuid,
    pub environment_id: Uuid,
    pub display_name: String,
    pub owner: String,
    pub engine: String,
    pub generation: u64,
    pub revision: u64,
    pub root_identity: String,
    pub parent_identity: String,
    pub intent: Action,
    pub signature: String,
    pub scope: String,
    pub created: u64,
    pub updated: u64,
    pub stage: String,
    pub reason: String,
    pub native_status: Option<u32>,
    pub snapshot: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OperationView {
    pub operation_id: Uuid,
    pub environment_id: Uuid,
    pub display_name: String,
    pub intent: Action,
    pub generation: u64,
    pub stage: String,
    pub reason: String,
}
impl From<Record> for OperationView {
    fn from(r: Record) -> Self {
        Self {
            operation_id: r.operation_id,
            environment_id: r.environment_id,
            display_name: r.display_name,
            intent: r.intent,
            generation: r.generation,
            stage: r.stage,
            reason: r.reason,
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EnvironmentView {
    pub environment_id: Uuid,
    pub display_name: String,
    pub revision: u64,
    pub generation: u64,
    pub lifecycle: State,
    pub mode: Mode,
    pub disposable_pending: bool,
    pub activity: String,
    pub complete: bool,
    pub reason: String,
    pub pending_operation: Option<Uuid>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Plan {
    pub plan_id: Uuid,
    pub operation_id: Uuid,
    pub environment_id: Uuid,
    pub display_name: String,
    pub intent: Action,
    pub retention: String,
    pub generation: u64,
    pub expires_in_seconds: u32,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reply {
    pub protocol: u32,
    pub reason: String,
    pub environments: Vec<EnvironmentView>,
    pub operations: Vec<OperationView>,
    pub plan: Option<Plan>,
}
impl Reply {
    pub fn failure(reason: &str) -> Self {
        Self {
            protocol: 1,
            reason: reason.into(),
            environments: vec![],
            operations: vec![],
            plan: None,
        }
    }
}
fn sql(_: rusqlite::Error) -> &'static str {
    "LIFECYCLE_JOURNAL_UNAVAILABLE"
}
pub fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}
pub struct Journal {
    db: Connection,
    owner: String,
}
impl Journal {
    pub fn open(path: &Path, owner: &str) -> PolicyResult<Self> {
        let db = Connection::open(path).map_err(sql)?;
        db.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(sql)?;
        db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL;")
            .map_err(sql)?;
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(sql)?;
        if version > 1 {
            return Err("LIFECYCLE_SCHEMA_UNSUPPORTED");
        }
        if version == 0 {
            let count: u32 = db
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
                    [],
                    |r| r.get(0),
                )
                .map_err(sql)?;
            if count != 0 {
                return Err("LIFECYCLE_FOREIGN_DATABASE");
            }
            db.execute_batch("BEGIN IMMEDIATE; CREATE TABLE operations(id TEXT PRIMARY KEY,owner TEXT NOT NULL,document TEXT NOT NULL); PRAGMA user_version=1; COMMIT;").map_err(sql)?;
        }
        let check: String = db
            .query_row("PRAGMA quick_check(1)", [], |r| r.get(0))
            .map_err(sql)?;
        if check != "ok" {
            return Err("LIFECYCLE_JOURNAL_CORRUPT");
        }
        db.execute_batch("PRAGMA journal_mode=WAL;").map_err(sql)?;
        Ok(Self {
            db,
            owner: owner.into(),
        })
    }
    pub fn get(&self, id: Uuid) -> PolicyResult<Option<Record>> {
        let text: Option<String> = self
            .db
            .query_row(
                "SELECT document FROM operations WHERE id=?1 AND owner=?2",
                params![id.to_string(), self.owner],
                |r| r.get(0),
            )
            .optional()
            .map_err(sql)?;
        text.map(|t| {
            let r: Record = serde_json::from_str(&t).map_err(|_| "LIFECYCLE_JOURNAL_CORRUPT")?;
            if r.operation_id != id || r.owner != self.owner {
                return Err("LIFECYCLE_JOURNAL_CORRUPT");
            }
            Ok(r)
        })
        .transpose()
    }
    pub fn save(&mut self, r: &Record) -> PolicyResult<()> {
        if r.owner != self.owner {
            return Err("LIFECYCLE_OWNER_CHANGED");
        }
        if let Some(old) = self.get(r.operation_id)?
            && (old.signature != r.signature
                || old.plan_id != r.plan_id
                || old.environment_id != r.environment_id)
        {
            return Err("OPERATION_CONFLICT");
        }
        let text = serde_json::to_string(r).map_err(|_| "LIFECYCLE_JOURNAL_CORRUPT")?;
        if text.len() > 16 * 1024 * 1024 {
            return Err("LIFECYCLE_SNAPSHOT_BOUND");
        }
        self.db.execute("INSERT INTO operations VALUES(?1,?2,?3) ON CONFLICT(id) DO UPDATE SET document=excluded.document",params![r.operation_id.to_string(),self.owner,text]).map_err(sql)?;
        Ok(())
    }
    pub fn views(&self) -> PolicyResult<Vec<OperationView>> {
        let mut q = self
            .db
            .prepare("SELECT document FROM operations WHERE owner=?1 ORDER BY rowid DESC LIMIT 64")
            .map_err(sql)?;
        let mut result = vec![];
        for t in q
            .query_map([&self.owner], |r| r.get::<_, String>(0))
            .map_err(sql)?
        {
            let r: Record =
                serde_json::from_str(&t.map_err(sql)?).map_err(|_| "LIFECYCLE_JOURNAL_CORRUPT")?;
            if r.owner != self.owner {
                return Err("LIFECYCLE_JOURNAL_CORRUPT");
            }
            result.push(r.into())
        }
        Ok(result)
    }
}
pub fn signature(request: &Request) -> String {
    fingerprint(request)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn retention_is_explicit_and_renderer_flags_are_not_authority() {
        assert!(Action::Reset.retention().contains("Keep"));
        assert!(Action::Remove.destructive());
        assert!(!Action::Archive.destructive());
        assert!(Action::Disposable.retention().contains("Never"));
        assert!(serde_json::from_str::<Request>(r#"{"action":"COMMIT","operation_id":"00000000-0000-0000-0000-000000000000","plan_id":"00000000-0000-0000-0000-000000000000","confirmed":true}"#).is_err());
    }
    #[test]
    fn lifecycle_journal_preserves_non_replayable_identity_bound_intent() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("journal");
        let id = Uuid::new_v4();
        let mut j = Journal::open(&path, "owner").unwrap();
        let mut r = Record {
            operation_id: id,
            plan_id: Uuid::new_v4(),
            environment_id: Uuid::new_v4(),
            display_name: "fixture".into(),
            owner: "owner".into(),
            engine: "engine".into(),
            generation: 2,
            revision: 3,
            root_identity: "root".into(),
            parent_identity: "parent".into(),
            intent: Action::Reset,
            signature: "request".into(),
            scope: "scope".into(),
            created: now(),
            updated: now(),
            stage: "DISPATCH_RESERVED".into(),
            reason: "UNKNOWN".into(),
            native_status: None,
            snapshot: None,
        };
        j.save(&r).unwrap();
        drop(j);
        let mut j = Journal::open(&path, "owner").unwrap();
        assert_eq!(j.get(id).unwrap().unwrap().stage, "DISPATCH_RESERVED");
        r.signature = "changed".into();
        assert!(j.save(&r).is_err());
        assert!(
            Journal::open(&path, "other")
                .unwrap()
                .get(id)
                .unwrap()
                .is_none()
        );
    }
}
