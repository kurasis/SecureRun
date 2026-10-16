//! User-owned application registrations and durable, non-replayable dispatch receipts.
use crate::{
    ProcessIdentity,
    policy::{PolicyResult, fingerprint},
};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::path::Path;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BoxExecutableRef {
    pub stage_identity: String,
    pub generation: String,
    pub physical: String,
    pub logical: String,
    pub identity: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Application {
    pub id: Uuid,
    pub environment_id: Uuid,
    pub revision: u64,
    pub display_name: String,
    pub executable: String,
    pub identity: String,
    pub arguments: Vec<String>,
    pub working_directory: Option<String>,
    pub directory_identity: Option<String>,
    #[serde(default)]
    pub boxed: Option<BoxExecutableRef>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ApplicationView {
    pub id: Uuid,
    pub environment_id: Uuid,
    pub revision: u64,
    pub display_name: String,
    pub boxed: bool,
    pub available: bool,
    pub unavailable_reason: Option<String>,
}
impl From<Application> for ApplicationView {
    fn from(a: Application) -> Self {
        Self {
            id: a.id,
            environment_id: a.environment_id,
            revision: a.revision,
            display_name: a.display_name,
            boxed: a.boxed.is_some(),
            available: true,
            unavailable_reason: None,
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
    Register {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        display_name: String,
        executable: String,
        arguments: Vec<String>,
        working_directory: Option<String>,
    },
    Launch {
        application_id: Uuid,
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
    },
    Stop {
        environment_id: Uuid,
        operation_id: Uuid,
    },
    StopManaged {
        operation_id: Uuid,
    },
    Reconcile {
        operation_id: Uuid,
    },
}
impl Request {
    pub fn environment_scope(&self) -> Option<Uuid> {
        match self {
            Self::Register { environment_id, .. }
            | Self::Launch { environment_id, .. }
            | Self::Stop { environment_id, .. } => Some(*environment_id),
            Self::List | Self::StopManaged { .. } | Self::Reconcile { .. } => None,
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub operation_id: Uuid,
    pub environment_id: Option<Uuid>,
    pub state: String,
    pub reason: String,
    pub process: Option<ProcessIdentity>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProcessView {
    pub environment_id: Uuid,
    pub activity: String,
    pub complete: bool,
    pub processes: Vec<ProcessIdentity>,
    pub launch_eligible: bool,
    pub launch_reason: String,
    pub reason: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reply {
    pub protocol: u32,
    pub environment_scope: Option<Uuid>,
    pub reason: String,
    pub applications: Vec<ApplicationView>,
    pub environments: Vec<ProcessView>,
    pub receipts: Vec<Receipt>,
}
impl Reply {
    pub fn failure(reason: &str) -> Self {
        Self {
            protocol: 1,
            environment_scope: None,
            reason: reason.into(),
            applications: vec![],
            environments: vec![],
            receipts: vec![],
        }
    }
}
fn db_error(_: rusqlite::Error) -> &'static str {
    "CONTROL_JOURNAL_UNAVAILABLE"
}
pub struct Journal {
    db: Connection,
    owner: String,
}
impl Journal {
    pub fn open(path: &Path, owner: &str) -> PolicyResult<Self> {
        let db = Connection::open(path).map_err(db_error)?;
        db.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(db_error)?;
        db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL;")
            .map_err(db_error)?;
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(db_error)?;
        if version > 1 {
            return Err("CONTROL_SCHEMA_UNSUPPORTED");
        }
        if version == 0 {
            let count: u32 = db
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
                    [],
                    |r| r.get(0),
                )
                .map_err(db_error)?;
            if count != 0 {
                return Err("CONTROL_FOREIGN_DATABASE");
            }
            db.execute_batch("BEGIN IMMEDIATE; CREATE TABLE applications(id TEXT PRIMARY KEY,owner TEXT NOT NULL,document TEXT NOT NULL); CREATE TABLE dispatch(id TEXT PRIMARY KEY,owner TEXT NOT NULL,signature TEXT NOT NULL,receipt TEXT NOT NULL,environment TEXT,launch INTEGER NOT NULL); CREATE TABLE reconciliations(id TEXT PRIMARY KEY); PRAGMA user_version=1; COMMIT;").map_err(db_error)?;
        }
        let check: String = db
            .query_row("PRAGMA quick_check(1)", [], |r| r.get(0))
            .map_err(db_error)?;
        if check != "ok" {
            return Err("CONTROL_JOURNAL_CORRUPT");
        }
        db.execute_batch("PRAGMA journal_mode=WAL;")
            .map_err(db_error)?;
        Ok(Self {
            db,
            owner: owner.into(),
        })
    }
    pub fn applications(&self) -> PolicyResult<Vec<Application>> {
        let mut stmt = self
            .db
            .prepare("SELECT id,owner,document FROM applications LIMIT 129")
            .map_err(db_error)?;
        let rows = stmt
            .query_map([], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, String>(2)?,
                ))
            })
            .map_err(db_error)?;
        let mut out = vec![];
        for row in rows {
            let (id, owner, json) = row.map_err(db_error)?;
            if owner != self.owner || json.len() > 32768 {
                return Err("APPLICATION_RECORD_INVALID");
            }
            let a: Application =
                serde_json::from_str(&json).map_err(|_| "APPLICATION_RECORD_INVALID")?;
            if a.id.to_string() != id {
                return Err("APPLICATION_RECORD_INVALID");
            }
            out.push(a);
        }
        if out.len() > 128 {
            return Err("APPLICATION_BOUND");
        }
        Ok(out)
    }
    pub fn register(&mut self, a: &Application) -> PolicyResult<()> {
        let applications = self.applications()?;
        if let Some(old) = applications.iter().find(|old| old.id == a.id) {
            return if fingerprint(old) == fingerprint(a) {
                Ok(())
            } else {
                Err("APPLICATION_OPERATION_CONFLICT")
            };
        }
        if applications.len() >= 128 {
            return Err("APPLICATION_BOUND");
        }
        self.db
            .execute(
                "INSERT INTO applications VALUES(?1,?2,?3)",
                params![
                    a.id.to_string(),
                    self.owner,
                    serde_json::to_string(a).map_err(|_| "APPLICATION_RECORD_INVALID")?
                ],
            )
            .map_err(db_error)?;
        Ok(())
    }
    pub fn receipt(&self, id: Uuid) -> PolicyResult<Option<Receipt>> {
        let row: Option<(String, String)> = self
            .db
            .query_row(
                "SELECT owner,receipt FROM dispatch WHERE id=?1",
                [id.to_string()],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(db_error)?;
        row.map(|(owner, json)| {
            if owner != self.owner || json.len() > 8192 {
                return Err("OPERATION_RECORD_INVALID");
            }
            let r: Receipt = serde_json::from_str(&json).map_err(|_| "OPERATION_RECORD_INVALID")?;
            if r.operation_id != id {
                return Err("OPERATION_RECORD_INVALID");
            }
            Ok(r)
        })
        .transpose()
    }
    /// The durable initial receipt already means unknown. A crash needs no replaying recovery.
    pub fn reserve(
        &mut self,
        id: Uuid,
        request: &Request,
        scope: &impl Serialize,
    ) -> PolicyResult<Option<Receipt>> {
        let signature = fingerprint(&(request, scope));
        let row: Option<(String, String)> = self
            .db
            .query_row(
                "SELECT owner,signature FROM dispatch WHERE id=?1",
                [id.to_string()],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(db_error)?;
        if let Some((owner, old)) = row {
            if owner != self.owner || old != signature {
                return Err("OPERATION_CONFLICT");
            }
            return self.receipt(id);
        }
        let receipt = Receipt {
            operation_id: id,
            environment_id: match request {
                Request::Launch { environment_id, .. }
                | Request::Stop { environment_id, .. }
                | Request::Register { environment_id, .. } => Some(*environment_id),
                _ => None,
            },
            state: "UNKNOWN".into(),
            reason: "DISPATCH_RESERVED_NO_AUTOMATIC_REPLAY".into(),
            process: None,
        };
        self.db
            .execute(
                "INSERT INTO dispatch VALUES(?1,?2,?3,?4,?5,?6)",
                params![
                    id.to_string(),
                    self.owner,
                    signature,
                    serde_json::to_string(&receipt).map_err(|_| "OPERATION_RECORD_INVALID")?,
                    receipt.environment_id.map(|id| id.to_string()),
                    matches!(request, Request::Launch { .. })
                ],
            )
            .map_err(db_error)?;
        Ok(None)
    }
    pub fn finish(&mut self, r: &Receipt) -> PolicyResult<()> {
        let changed = self
            .db
            .execute(
                "UPDATE dispatch SET receipt=?1 WHERE id=?2 AND owner=?3",
                params![
                    serde_json::to_string(r).map_err(|_| "OPERATION_RECORD_INVALID")?,
                    r.operation_id.to_string(),
                    self.owner
                ],
            )
            .map_err(db_error)?;
        if changed != 1 {
            return Err("OPERATION_RECORD_INVALID");
        }
        Ok(())
    }
    pub fn unresolved(&self, environment: Uuid, except: Uuid) -> PolicyResult<bool> {
        let mut stmt=self.db.prepare("SELECT id FROM dispatch WHERE owner=?1 AND environment=?2 AND launch=1 AND id!=?3 AND id NOT IN (SELECT id FROM reconciliations)").map_err(db_error)?;
        let rows = stmt
            .query_map(
                params![self.owner, environment.to_string(), except.to_string()],
                |r| r.get::<_, String>(0),
            )
            .map_err(db_error)?;
        for id in rows {
            let id =
                Uuid::parse_str(&id.map_err(db_error)?).map_err(|_| "OPERATION_RECORD_INVALID")?;
            if self.receipt(id)?.ok_or("OPERATION_RECORD_INVALID")?.state == "UNKNOWN" {
                return Ok(true);
            }
        }
        Ok(false)
    }
    pub fn reconcile_environment(&mut self, environment: Uuid) -> PolicyResult<()> {
        self.db.execute("INSERT OR IGNORE INTO reconciliations SELECT id FROM dispatch WHERE owner=?1 AND environment=?2",params![self.owner,environment.to_string()]).map_err(db_error)?;
        Ok(())
    }
    pub fn remove_applications(&mut self, environment: Uuid) -> PolicyResult<()> {
        for application in self
            .applications()?
            .into_iter()
            .filter(|a| a.environment_id == environment)
        {
            self.db
                .execute(
                    "DELETE FROM applications WHERE id=?1 AND owner=?2",
                    params![application.id.to_string(), self.owner],
                )
                .map_err(db_error)?;
        }
        Ok(())
    }
    pub fn reconcile(&mut self, id: Uuid) -> PolicyResult<()> {
        self.receipt(id)?.ok_or("OPERATION_NOT_FOUND")?;
        self.db
            .execute(
                "INSERT OR IGNORE INTO reconciliations VALUES(?1)",
                [id.to_string()],
            )
            .map_err(db_error)?;
        Ok(())
    }
    pub fn receipts(&self) -> PolicyResult<Vec<Receipt>> {
        let mut stmt = self
            .db
            .prepare("SELECT id FROM dispatch ORDER BY rowid DESC LIMIT 64")
            .map_err(db_error)?;
        let rows = stmt
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(db_error)?;
        rows.map(|row| {
            self.receipt(
                Uuid::parse_str(&row.map_err(db_error)?).map_err(|_| "OPERATION_RECORD_INVALID")?,
            )?
            .ok_or("OPERATION_RECORD_INVALID")
        })
        .collect()
    }
}
/// Microsoft CRT argv encoding; the engine receives no Start.exe switches.
pub fn quote(value: &str) -> String {
    let mut out = String::from("\"");
    let mut slashes = 0;
    for c in value.chars() {
        if c == '\\' {
            slashes += 1;
            continue;
        }
        if c == '"' {
            out.push_str(&"\\".repeat(slashes * 2 + 1));
        } else {
            out.push_str(&"\\".repeat(slashes));
        }
        slashes = 0;
        out.push(c);
    }
    out.push_str(&"\\".repeat(slashes * 2));
    out.push('"');
    out
}
pub fn command(executable: &str, args: &[String]) -> PolicyResult<String> {
    if args.len() > 64
        || executable.is_empty()
        || executable.contains('"')
        || std::iter::once(executable)
            .chain(args.iter().map(String::as_str))
            .any(|v| v.chars().any(char::is_control))
    {
        return Err("TARGET_ARGUMENTS_INVALID");
    }
    let result = std::iter::once(executable)
        .chain(args.iter().map(String::as_str))
        .map(quote)
        .collect::<Vec<_>>()
        .join(" ");
    if result.encode_utf16().count() > 24000 {
        return Err("TARGET_ARGUMENTS_BOUND");
    }
    Ok(result)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reservation_survives_lost_receipt_restart_and_empty_process_list() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("control.sqlite");
        let id = Uuid::new_v4();
        let request = Request::StopManaged { operation_id: id };
        let mut j = Journal::open(&path, "owner").unwrap();
        assert!(
            j.reserve(id, &request, &"root-generation")
                .unwrap()
                .is_none()
        );
        drop(j);
        let mut j = Journal::open(&path, "owner").unwrap();
        assert_eq!(
            j.reserve(id, &request, &"root-generation")
                .unwrap()
                .unwrap()
                .state,
            "UNKNOWN"
        );
        assert_eq!(
            j.reserve(id, &request, &"recreated-root").unwrap_err(),
            "OPERATION_CONFLICT"
        );
        assert!(
            Journal::open(&path, "other-owner")
                .unwrap()
                .receipt(id)
                .is_err()
        );
    }
    #[test]
    fn uncertainty_blocks_new_operations_until_explicit_reconciliation_without_erasing_receipt() {
        let t = tempfile::tempdir().unwrap();
        let mut j = Journal::open(&t.path().join("control.sqlite"), "owner").unwrap();
        let environment_id = Uuid::new_v4();
        let operation_id = Uuid::new_v4();
        let r = Request::Launch {
            application_id: Uuid::new_v4(),
            environment_id,
            expected_revision: 1,
            operation_id,
        };
        assert!(j.reserve(operation_id, &r, &"scope").unwrap().is_none());
        assert!(j.unresolved(environment_id, Uuid::nil()).unwrap());
        assert!(!j.unresolved(environment_id, operation_id).unwrap());
        j.reconcile(operation_id).unwrap();
        assert!(!j.unresolved(environment_id, Uuid::nil()).unwrap());
        assert_eq!(j.receipt(operation_id).unwrap().unwrap().state, "UNKNOWN");
        assert_eq!(
            j.reserve(operation_id, &r, &"scope")
                .unwrap()
                .unwrap()
                .state,
            "UNKNOWN"
        );
    }
    #[test]
    fn crt_quoting_and_bounds() {
        assert_eq!(quote(""), "\"\"");
        assert_eq!(quote("x\\"), "\"x\\\\\"");
        assert_eq!(quote("a\"b"), "\"a\\\"b\"");
        assert!(command("x.exe", &["bad\n".into()]).is_err());
        assert!(command("x.exe", &vec!["a".into(); 65]).is_err());
        assert!(command("x.exe", &["/terminate_all".into(), "Привет 🧪 ".into()]).is_ok());
    }
}
