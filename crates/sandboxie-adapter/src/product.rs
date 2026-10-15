//! Bounded manager history. Untrusted strings are absent from the event schema.
use crate::policy::PolicyResult;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::path::Path;
use uuid::Uuid;

pub const HISTORY_LIMIT: usize = 512;
pub const SHARED_LIMIT: usize = 64;
pub const RETENTION_DAYS: u64 = 30;

pub fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Action {
    Rename,
    PolicyCreate,
    PolicyApply,
    PolicyInspect,
    PolicyRepair,
    Register,
    Launch,
    Stop,
    StopManaged,
    Import,
    Export,
    TransferInspect,
    TransferDiscard,
    RetentionChange,
    LifecycleInspect,
    DiagnosticPreview,
    DiagnosticSave,
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Outcome {
    Observed,
    Refused,
    Unknown,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Event {
    pub environment_id: Option<Uuid>,
    pub action: Action,
    pub outcome: Outcome,
    pub diagnostic_id: Uuid,
    pub unix_ms: u64,
}
impl Event {
    pub fn new(action: Action, outcome: Outcome) -> Self {
        Self {
            environment_id: None,
            action,
            outcome,
            diagnostic_id: Uuid::new_v4(),
            unix_ms: now(),
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
    Rename {
        environment_id: Uuid,
        expected_revision: u64,
        expected_generation: u64,
        expected_display_name: String,
        display_name: String,
        operation_id: Uuid,
    },
    Record {
        event: Event,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Reply {
    pub reason: String,
    pub events: Vec<Event>,
    pub free_volume_bytes: Option<String>,
    pub retention_days: u64,
    pub retention_limit: usize,
}
impl Reply {
    pub fn failure(reason: &str) -> Self {
        Self {
            reason: reason.into(),
            events: vec![],
            free_volume_bytes: None,
            retention_days: RETENTION_DAYS,
            retention_limit: HISTORY_LIMIT,
        }
    }
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SharedEvent {
    pub action: Action,
    pub outcome: Outcome,
    pub diagnostic_id: Uuid,
    pub unix_ms: u64,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DiagnosticBundle {
    pub schema: u32,
    pub product: String,
    pub events: Vec<SharedEvent>,
    pub engine_access_events_available: bool,
}
pub fn bundle(events: &[Event]) -> PolicyResult<String> {
    let value = DiagnosticBundle {
        schema: 1,
        product: "SecureRun 0.3.0".into(),
        events: events
            .iter()
            .take(SHARED_LIMIT)
            .map(|e| SharedEvent {
                action: e.action,
                outcome: e.outcome,
                diagnostic_id: e.diagnostic_id,
                unix_ms: e.unix_ms,
            })
            .collect(),
        engine_access_events_available: false,
    };
    let text = serde_json::to_string_pretty(&value).map_err(|_| "DIAGNOSTIC_ENCODING_FAILED")?;
    if text.len() > 32768 {
        return Err("DIAGNOSTIC_BOUND");
    }
    Ok(text)
}

pub struct Journal {
    db: Connection,
}
impl Journal {
    pub fn open(path: &Path, owner: &str) -> PolicyResult<Self> {
        if path.metadata().is_ok_and(|m| m.len() > 8 * 1024 * 1024) {
            return Err("HISTORY_BOUND");
        }
        let db = Connection::open(path).map_err(|_| "HISTORY_UNAVAILABLE")?;
        db.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(|_| "HISTORY_UNAVAILABLE")?;
        db.execute_batch(
            "PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL; PRAGMA secure_delete=ON;",
        )
        .map_err(|_| "HISTORY_UNAVAILABLE")?;
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(|_| "HISTORY_CORRUPT")?;
        if version > 1 {
            return Err("HISTORY_SCHEMA_UNSUPPORTED");
        }
        if version == 0 {
            let count: u32 = db
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
                    [],
                    |r| r.get(0),
                )
                .map_err(|_| "HISTORY_CORRUPT")?;
            if count != 0 {
                return Err("HISTORY_FOREIGN_DATABASE");
            }
            db.execute_batch("BEGIN IMMEDIATE; CREATE TABLE owner(singleton INTEGER PRIMARY KEY CHECK(singleton=1),sid TEXT NOT NULL); CREATE TABLE events(sequence INTEGER PRIMARY KEY,unix_ms INTEGER NOT NULL,document TEXT NOT NULL); PRAGMA user_version=1;").map_err(|_| "HISTORY_UNAVAILABLE")?;
            db.execute("INSERT INTO owner VALUES(1,?1)", [owner])
                .map_err(|_| "HISTORY_UNAVAILABLE")?;
            db.execute_batch("COMMIT;")
                .map_err(|_| "HISTORY_UNAVAILABLE")?;
        }
        let stored: Option<String> = db
            .query_row("SELECT sid FROM owner WHERE singleton=1", [], |r| r.get(0))
            .optional()
            .map_err(|_| "HISTORY_CORRUPT")?;
        if stored.as_deref() != Some(owner) {
            return Err("HISTORY_OWNER_CHANGED");
        }
        let integrity: String = db
            .query_row("PRAGMA quick_check(1)", [], |r| r.get(0))
            .map_err(|_| "HISTORY_CORRUPT")?;
        if integrity != "ok" {
            return Err("HISTORY_CORRUPT");
        }
        db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA journal_size_limit=1048576; PRAGMA wal_autocheckpoint=128;").map_err(|_| "HISTORY_UNAVAILABLE")?;
        let journal = Self { db };
        journal.prune()?;
        Ok(journal)
    }
    fn prune(&self) -> PolicyResult<()> {
        let oldest = now().saturating_sub(RETENTION_DAYS * 86400 * 1000);
        self.db.execute("DELETE FROM events WHERE unix_ms<?1 OR sequence NOT IN (SELECT sequence FROM events ORDER BY sequence DESC LIMIT ?2)", params![oldest,HISTORY_LIMIT as u64]).map_err(|_| "HISTORY_UNAVAILABLE")?;
        Ok(())
    }
    pub fn record(&self, event: &Event) -> PolicyResult<()> {
        let now = now();
        if event.unix_ms > now.saturating_add(60000) || event.unix_ms < now.saturating_sub(86400000)
        {
            return Err("HISTORY_EVENT_EXPIRED");
        }
        let text = serde_json::to_string(event).map_err(|_| "HISTORY_ENCODING_FAILED")?;
        self.db
            .execute(
                "INSERT INTO events(unix_ms,document) VALUES(?1,?2)",
                params![event.unix_ms, text],
            )
            .map_err(|_| "HISTORY_UNAVAILABLE")?;
        self.prune()
    }
    pub fn list(&self) -> PolicyResult<Vec<Event>> {
        self.prune()?;
        let mut stmt = self
            .db
            .prepare("SELECT document FROM events ORDER BY sequence DESC LIMIT ?1")
            .map_err(|_| "HISTORY_UNAVAILABLE")?;
        let rows = stmt
            .query_map([HISTORY_LIMIT as u64], |r| r.get::<_, String>(0))
            .map_err(|_| "HISTORY_UNAVAILABLE")?;
        rows.map(|r| {
            let text = r.map_err(|_| "HISTORY_CORRUPT")?;
            if text.len() > 512 {
                return Err("HISTORY_CORRUPT");
            }
            serde_json::from_str(&text).map_err(|_| "HISTORY_CORRUPT")
        })
        .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn history_is_bounded_redacted_and_survives_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("history.sqlite");
        let journal = Journal::open(&path, "owner").unwrap();
        for _ in 0..600 {
            journal
                .record(&Event::new(Action::Launch, Outcome::Unknown))
                .unwrap();
        }
        assert_eq!(journal.list().unwrap().len(), HISTORY_LIMIT);
        drop(journal);
        let events = Journal::open(&path, "owner").unwrap().list().unwrap();
        let text = bundle(&events).unwrap();
        let shared: DiagnosticBundle = serde_json::from_str(&text).unwrap();
        assert_eq!(shared.events.len(), SHARED_LIMIT);
        assert!(!shared.engine_access_events_available);
        assert!(!text.contains("owner"));
        assert!(Journal::open(&path, "different-owner").is_err());
    }
    #[test]
    fn secrets_and_forged_events_are_not_schema_fields() {
        for field in [
            "arguments",
            "environment",
            "path",
            "message",
            "certificate",
            "password",
        ] {
            let mut event =
                serde_json::to_value(Event::new(Action::Launch, Outcome::Unknown)).unwrap();
            event[field] = serde_json::json!("P09_SYNTHETIC_SECRET\nFORGED_EVENT");
            assert!(serde_json::from_value::<Event>(event).is_err());
        }
        let mut event = serde_json::to_value(Event::new(Action::Launch, Outcome::Unknown)).unwrap();
        event["action"] = serde_json::json!("P09_SYNTHETIC_SECRET");
        assert!(serde_json::from_value::<Event>(event).is_err());
    }
}
