//! Durable intent and postconditions. A restart inspects, never replays mutations.
use crate::policy::*;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::path::Path;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Stage {
    Intent,
    Fenced,
    Writing,
    Readback,
    PendingRoot,
    RootBound,
    Verifying,
    Verified,
    Conflict,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OwnedEnvironment {
    pub id: Uuid,
    pub display_name: String,
    pub owner_sid: String,
    pub engine_identity: String,
    pub root_identity: Option<String>,
    pub revision: u64,
    pub stage: Stage,
    pub desired: DesiredPolicy,
    pub compiled: CompiledPolicy,
    pub fingerprint: Option<String>,
    pub enforcement_evidence: Option<String>,
    #[serde(default)]
    pub enforcement_binding: Option<String>,
    pub reason: String,
    pub operation_id: Uuid,
    pub operation_signature: String,
    pub baseline: Option<Section>,
    pub observed: Option<Section>,
    #[serde(default)]
    pub generation: u64,
    #[serde(default)]
    pub lifecycle: crate::lifecycle::State,
    #[serde(default)]
    pub mode: crate::lifecycle::Mode,
    #[serde(default)]
    pub disposable_pending: bool,
    #[serde(default)]
    pub lifecycle_operation: Option<Uuid>,
    pub production_launch_available: bool,
}
impl OwnedEnvironment {
    pub fn name(&self) -> String {
        format!("SR_{}", self.id.simple())
    }
    pub fn marker(&self) -> String {
        format!("v1:{}:{}", self.owner_sid, self.id.simple())
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
    Create {
        display_name: String,
        policy: DesiredPolicy,
        operation_id: Uuid,
    },
    Apply {
        environment_id: Uuid,
        expected_revision: u64,
        policy: DesiredPolicy,
        operation_id: Uuid,
        acknowledge_view_change: bool,
    },
    Inspect {
        environment_id: Uuid,
    },
    Repair {
        environment_id: Uuid,
        expected_revision: u64,
        observed_fingerprint: String,
        operation_id: Uuid,
        acknowledge_view_change: bool,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reply {
    pub protocol: u32,
    pub reason: String,
    pub environments: Vec<OwnedEnvironment>,
    pub production_launch_available: bool,
    pub elevated_helper: bool,
}
impl Reply {
    pub fn failure(reason: &str) -> Self {
        Self {
            protocol: 1,
            reason: reason.into(),
            environments: vec![],
            production_launch_available: false,
            elevated_helper: false,
        }
    }
}

pub struct Journal {
    db: Connection,
    owner: String,
}
fn sql_error(_: rusqlite::Error) -> &'static str {
    "POLICY_JOURNAL_UNAVAILABLE"
}
impl Journal {
    pub fn open(path: &Path, owner: &str) -> PolicyResult<Self> {
        let db = Connection::open(path).map_err(sql_error)?;
        db.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(sql_error)?;
        db.execute_batch(
            "PRAGMA foreign_keys=ON; PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL;",
        )
        .map_err(sql_error)?;
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(sql_error)?;
        if version > 1 {
            return Err("POLICY_JOURNAL_SCHEMA_UNSUPPORTED");
        }
        if version == 0 {
            let count: u32 = db
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
                    [],
                    |r| r.get(0),
                )
                .map_err(sql_error)?;
            if count != 0 {
                return Err("POLICY_JOURNAL_FOREIGN_DATABASE");
            }
            db.execute_batch("BEGIN IMMEDIATE; CREATE TABLE owned(id TEXT PRIMARY KEY, owner TEXT NOT NULL, operation TEXT UNIQUE NOT NULL, document TEXT NOT NULL); CREATE TABLE operations(id TEXT PRIMARY KEY, environment TEXT NOT NULL, signature TEXT NOT NULL); CREATE TABLE events(sequence INTEGER PRIMARY KEY, id TEXT NOT NULL, stage TEXT NOT NULL); PRAGMA user_version=1; COMMIT;").map_err(sql_error)?;
        }
        let check: String = db
            .query_row("PRAGMA quick_check(1)", [], |r| r.get(0))
            .map_err(sql_error)?;
        if check != "ok" {
            return Err("POLICY_JOURNAL_CORRUPT");
        }
        db.execute_batch("PRAGMA journal_mode=WAL;")
            .map_err(sql_error)?;
        Ok(Self {
            db,
            owner: owner.into(),
        })
    }
    pub fn list(&self) -> PolicyResult<Vec<OwnedEnvironment>> {
        let mut stmt = self
            .db
            .prepare("SELECT id,owner,document FROM owned ORDER BY id LIMIT 13")
            .map_err(sql_error)?;
        let rows = stmt
            .query_map([], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, String>(2)?,
                ))
            })
            .map_err(sql_error)?;
        let mut result = vec![];
        for row in rows {
            let (id, owner, text) = row.map_err(sql_error)?;
            let e: OwnedEnvironment =
                serde_json::from_str(&text).map_err(|_| "POLICY_JOURNAL_CORRUPT")?;
            if e.id.to_string() != id
                || e.owner_sid != owner
                || owner != self.owner
                || e.production_launch_available
            {
                return Err("OWNERSHIP_RECORD_INVALID");
            }
            result.push(e);
        }
        if result.len() > 12 {
            return Err("OWNED_ENVIRONMENT_BOUND");
        }
        Ok(result)
    }
    pub fn get(&self, id: Uuid) -> PolicyResult<OwnedEnvironment> {
        self.list()?
            .into_iter()
            .find(|e| e.id == id)
            .ok_or("OWNERSHIP_NOT_FOUND")
    }
    pub fn operation(&self, id: Uuid, signature: &str) -> PolicyResult<Option<OwnedEnvironment>> {
        let record: Option<(String, String)> = self
            .db
            .query_row(
                "SELECT environment,signature FROM operations WHERE id=?1",
                [id.to_string()],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(sql_error)?;
        if let Some((environment, recorded)) = record {
            if signature != recorded {
                return Err("OPERATION_CONFLICT");
            }
            return self
                .get(Uuid::parse_str(&environment).map_err(|_| "POLICY_JOURNAL_CORRUPT")?)
                .map(Some);
        }
        Ok(None)
    }
    pub fn save(&mut self, e: &OwnedEnvironment) -> PolicyResult<()> {
        if e.owner_sid != self.owner || e.production_launch_available {
            return Err("OWNERSHIP_RECORD_INVALID");
        }
        let document = serde_json::to_string(e).map_err(|_| "POLICY_JOURNAL_CORRUPT")?;
        if document.len() > 262144 {
            return Err("POLICY_JOURNAL_BOUND");
        }
        let recorded: Option<(String, String)> = self
            .db
            .query_row(
                "SELECT environment,signature FROM operations WHERE id=?1",
                [e.operation_id.to_string()],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(sql_error)?;
        if recorded.is_some_and(|(id, signature)| {
            id != e.id.to_string() || signature != e.operation_signature
        }) {
            return Err("OPERATION_CONFLICT");
        }
        let tx = self.db.transaction().map_err(sql_error)?;
        tx.execute("INSERT INTO owned VALUES(?1,?2,?3,?4) ON CONFLICT(id) DO UPDATE SET operation=excluded.operation,document=excluded.document",params![e.id.to_string(),self.owner,e.operation_id.to_string(),document]).map_err(sql_error)?;
        tx.execute(
            "INSERT OR IGNORE INTO operations VALUES(?1,?2,?3)",
            params![
                e.operation_id.to_string(),
                e.id.to_string(),
                e.operation_signature
            ],
        )
        .map_err(sql_error)?;
        tx.execute(
            "INSERT INTO events(id,stage) VALUES(?1,?2)",
            params![e.id.to_string(), format!("{:?}", e.stage)],
        )
        .map_err(sql_error)?;
        tx.execute("DELETE FROM events WHERE sequence < (SELECT coalesce(max(sequence),0)-4096 FROM events)",[]).map_err(sql_error)?;
        tx.commit().map_err(sql_error)?;
        #[cfg(all(windows, feature = "policy-ci"))]
        if std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true")
            && std::env::var("SECURERUN_P05_PAUSE_STAGE").ok().as_deref()
                == Some(format!("{:?}", e.stage).as_str())
        {
            use std::io::Write;
            println!("CHECKPOINT_{:?}", e.stage);
            let _ = std::io::stdout().flush();
            loop {
                std::thread::park();
            }
        }
        Ok(())
    }
    pub fn remove(&mut self, id: Uuid) -> PolicyResult<()> {
        self.db
            .execute(
                "DELETE FROM owned WHERE id=?1 AND owner=?2",
                params![id.to_string(), self.owner],
            )
            .map_err(sql_error)?;
        Ok(())
    }
    pub fn recover(&mut self) -> PolicyResult<usize> {
        let mut count = 0;
        for mut e in self.list()? {
            if !matches!(e.stage, Stage::Verified | Stage::Conflict) {
                e.stage = Stage::Conflict;
                e.reason = "OUTCOME_UNKNOWN_INSPECT_ONLY".into();
                e.fingerprint = None;
                e.enforcement_evidence = None;
                e.enforcement_binding = None;
                self.save(&e)?;
                count += 1;
            }
        }
        Ok(count)
    }
}

/// Native operations cannot be called with renderer-supplied root/INI keys.
pub trait Engine {
    fn root_for(&self, id: Uuid) -> String;
    fn exists(&self, name: &str) -> PolicyResult<bool> {
        Ok(!self.section(name, false)?.is_empty())
    }
    fn metadata(&self) -> String;
    fn code(&self) -> String;
    fn engine_identity(&self) -> String;
    fn enforcement_identity(&self) -> String {
        fingerprint(&(FAMILY, self.engine_identity()))
    }
    fn global(&self) -> PolicyResult<Section>;
    fn section(&self, name: &str, effective: bool) -> PolicyResult<Section>;
    fn idle(&self, name: &str) -> PolicyResult<()>;
    fn fence(&self, e: &OwnedEnvironment) -> PolicyResult<()>;
    fn write(&self, e: &OwnedEnvironment, baseline: &Section) -> PolicyResult<()>;
    fn create_root(&self, e: &OwnedEnvironment) -> PolicyResult<String>;
    fn validate_root(&self, e: &OwnedEnvironment) -> PolicyResult<()>;
    fn verify_enforcement(&self, e: &OwnedEnvironment) -> PolicyResult<String>;
}
fn mandatory(engine: &impl Engine, id: Uuid, owner: &str, all: &[OwnedEnvironment]) -> Mandatory {
    // Future rollouts append a new identity; the durable listing sorts by UUID.
    // Mandatory denials have identical semantics and must compile canonically.
    let mut siblings: Vec<_> = all
        .iter()
        .filter(|e| e.id != id)
        .map(|e| engine.root_for(e.id))
        .collect();
    siblings.sort();
    Mandatory {
        root: engine.root_for(id),
        metadata: engine.metadata(),
        code: engine.code(),
        siblings,
        marker: format!("v1:{owner}:{}", id.simple()),
    }
}
pub fn validate_display_name(display_name: &str) -> PolicyResult<()> {
    if display_name.trim().is_empty()
        || display_name.chars().count() > 80
        || display_name
            .chars()
            .any(|c| c.is_control() || matches!(c,'\u{202a}'..='\u{202e}'|'\u{2066}'..='\u{2069}'))
    {
        return Err("DISPLAY_NAME_INVALID");
    }
    Ok(())
}
pub fn create(
    journal: &mut Journal,
    engine: &impl Engine,
    owner: &str,
    display_name: &str,
    policy: DesiredPolicy,
    operation_id: Uuid,
) -> PolicyResult<OwnedEnvironment> {
    let operation_signature = fingerprint(&("CREATE", owner, display_name, &policy));
    if let Some(e) = journal.operation(operation_id, &operation_signature)? {
        return Ok(e);
    }
    validate_display_name(display_name)?;
    let all = journal.list()?;
    if all.len() >= 12 {
        return Err("OWNED_ENVIRONMENT_BOUND");
    }
    let global = engine.global()?;
    validate_inheritance(&global, &[])?;
    for existing in &all {
        if existing.stage != Stage::Verified {
            return Err("SIBLING_RECONCILIATION_REQUIRED");
        }
        engine.idle(&existing.name())?;
        validate_owned(engine, existing, &all)?;
    }
    let id = Uuid::new_v4();
    let name = format!("SR_{}", id.simple());
    if engine.exists(&name)? {
        return Err("PREEXISTING_BOX_NOT_ADOPTED");
    }
    let compiled = compile(&policy, &mandatory(engine, id, owner, &all))?;
    let mut e = OwnedEnvironment {
        id,
        display_name: display_name.trim().into(),
        owner_sid: owner.into(),
        engine_identity: engine.engine_identity(),
        root_identity: None,
        generation: 0,
        lifecycle: crate::lifecycle::State::Active,
        mode: crate::lifecycle::Mode::Persistent,
        disposable_pending: false,
        lifecycle_operation: None,
        revision: 0,
        stage: Stage::Intent,
        desired: policy,
        compiled,
        fingerprint: None,
        enforcement_evidence: None,
        enforcement_binding: None,
        reason: "PENDING_ROOT".into(),
        operation_id,
        operation_signature,
        baseline: Some(Section::new()),
        observed: None,
        production_launch_available: false,
    };
    journal.save(&e)?;
    let result: PolicyResult<()> = (|| {
        // Update and verify every old box before materializing any future storage.
        let mut future = all.clone();
        future.push(e.clone());
        for mut sibling in all {
            let desired = compile(
                &sibling.desired,
                &mandatory(engine, sibling.id, owner, &future),
            )?;
            if sibling.compiled.desired_fingerprint == desired.desired_fingerprint {
                continue;
            }
            let baseline = engine.section(&sibling.name(), false)?;
            sibling.compiled = desired;
            sibling.operation_id = Uuid::new_v4();
            sibling.operation_signature = fingerprint(&(
                "ROLLOUT",
                sibling.id,
                e.id,
                sibling.revision,
                &sibling.compiled,
            ));
            sibling.baseline = Some(minimize_section(&baseline));
            sibling.stage = Stage::Fenced;
            sibling.reason = "FUTURE_SIBLING_ROLLOUT".into();
            sibling.fingerprint = None;
            sibling.enforcement_evidence = None;
            sibling.enforcement_binding = None;
            journal.save(&sibling)?;
            engine.fence(&sibling)?;
            engine.idle(&sibling.name())?;
            sibling.stage = Stage::Writing;
            journal.save(&sibling)?;
            engine.write(&sibling, &baseline)?;
            let fp = verify_readback(
                &sibling.compiled,
                &engine.section(&sibling.name(), false)?,
                &engine.section(&sibling.name(), true)?,
                &engine.global()?,
            )?;
            engine.validate_root(&sibling)?;
            sibling.fingerprint = Some(fp);
            sibling.enforcement_evidence = Some(engine.verify_enforcement(&sibling)?);
            sibling.enforcement_binding = Some(engine.enforcement_identity());
            sibling.stage = Stage::Verified;
            sibling.reason = "POLICY_VERIFIED_TARGET_LAUNCH_DEFERRED".into();
            sibling.revision += 1;
            journal.save(&sibling)?;
        }
        e.stage = Stage::Writing;
        journal.save(&e)?;
        engine.write(&e, &Section::new())?;
        e.stage = Stage::Readback;
        journal.save(&e)?;
        let fp = verify_readback(
            &e.compiled,
            &engine.section(&e.name(), false)?,
            &engine.section(&e.name(), true)?,
            &engine.global()?,
        )?;
        e.stage = Stage::PendingRoot;
        journal.save(&e)?;
        e.root_identity = Some(engine.create_root(&e)?);
        e.stage = Stage::RootBound;
        journal.save(&e)?;
        engine.validate_root(&e)?;
        e.stage = Stage::Verifying;
        journal.save(&e)?;
        e.enforcement_evidence = Some(engine.verify_enforcement(&e)?);
        e.enforcement_binding = Some(engine.enforcement_identity());
        e.fingerprint = Some(fp);
        e.revision = 1;
        e.stage = Stage::Verified;
        e.reason = "POLICY_VERIFIED_TARGET_LAUNCH_DEFERRED".into();
        journal.save(&e)?;
        Ok(())
    })();
    if let Err(reason) = result {
        e.stage = Stage::Conflict;
        e.reason = reason.into();
        e.fingerprint = None;
        e.enforcement_evidence = None;
        e.enforcement_binding = None;
        journal.save(&e)?;
        return Err(reason);
    }
    Ok(e)
}
pub fn validate_owned(
    engine: &impl Engine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
) -> PolicyResult<()> {
    if e.lifecycle_operation.is_some() {
        return Err("LIFECYCLE_RECONCILIATION_REQUIRED");
    }
    if e.engine_identity != engine.engine_identity()
        || e.compiled.section.get("FileRootPath") != Some(&vec![engine.root_for(e.id)])
        || e.compiled.section.get("SecureRunOwner") != Some(&vec![e.marker()])
    {
        return Err("OWNERSHIP_BINDING_CHANGED");
    }
    let expected = compile(&e.desired, &mandatory(engine, e.id, &e.owner_sid, all))?;
    if expected.section != e.compiled.section
        || expected.offline != e.compiled.offline
        || e.compiled.family != FAMILY
    {
        return Err("MANDATORY_POLICY_DRIFT");
    }
    if e.enforcement_evidence.is_none()
        || e.enforcement_binding.as_ref() != Some(&engine.enforcement_identity())
    {
        return Err("ENFORCEMENT_BINDING_CHANGED");
    }
    engine.validate_root(e)?;
    let raw = engine.section(&e.name(), false)?;
    let fp = verify_readback(
        &e.compiled,
        &raw,
        &engine.section(&e.name(), true)?,
        &engine.global()?,
    )?;
    if e.fingerprint.as_ref() != Some(&fp) {
        return Err("CONFIGURATION_DRIFT");
    }
    Ok(())
}
#[expect(
    clippy::too_many_arguments,
    reason = "Explicit ownership, revision, operation and repair bindings"
)]
pub fn apply(
    journal: &mut Journal,
    engine: &impl Engine,
    id: Uuid,
    revision: u64,
    policy: DesiredPolicy,
    operation_id: Uuid,
    view_ack: bool,
    repair_fingerprint: Option<&str>,
) -> PolicyResult<OwnedEnvironment> {
    let operation_signature = fingerprint(&(
        if repair_fingerprint.is_some() {
            "REPAIR"
        } else {
            "APPLY"
        },
        id,
        revision,
        &policy,
        view_ack,
        repair_fingerprint,
    ));
    if let Some(e) = journal.operation(operation_id, &operation_signature)? {
        return Ok(e);
    }
    let mut e = journal.get(id)?;
    if e.lifecycle_operation.is_some() {
        return Err("LIFECYCLE_NOT_ACTIVE");
    }
    if e.revision != revision {
        return Err("REVISION_CONFLICT");
    }
    engine.idle(&e.name())?;
    let creating = e.root_identity.is_none();
    if !creating {
        engine.validate_root(&e)?;
    }
    let all = journal.list()?;
    let global = engine.global()?;
    validate_inheritance(&global, &[])?;
    let baseline = engine.section(&e.name(), false)?;
    if let Some(expected) = repair_fingerprint {
        if expected != fingerprint(&baseline) {
            return Err("REPAIR_BASELINE_CHANGED");
        }
        let root_acceptable = baseline
            .get("FileRootPath")
            .map_or(creating, |v| v == &vec![engine.root_for(e.id)]);
        if !(creating && baseline.is_empty())
            && (baseline.get("SecureRunOwner") != Some(&vec![e.marker()]) || !root_acceptable)
        {
            return Err("OWNERSHIP_BINDING_CHANGED");
        }
    } else {
        if e.stage != Stage::Verified {
            return Err("RECONCILIATION_REQUIRED");
        }
        validate_owned(engine, &e, &all)?;
    }
    if creating {
        for sibling in all.iter().filter(|s| s.id != e.id) {
            validate_owned(engine, sibling, &all)?;
            engine.idle(&sibling.name())?;
        }
    }
    let compiled = compile(&policy, &mandatory(engine, id, &e.owner_sid, &all))?;
    if compiled.read_only_view_change
        && (policy != e.desired || repair_fingerprint.is_some())
        && !view_ack
    {
        return Err("READ_ONLY_VIEW_CHANGE_ACK_REQUIRED");
    }
    e.compiled = compiled;
    e.desired = policy;
    e.baseline = Some(minimize_section(&baseline));
    e.operation_id = operation_id;
    e.operation_signature = operation_signature;
    e.stage = Stage::Fenced;
    e.fingerprint = None;
    e.enforcement_evidence = None;
    e.enforcement_binding = None;
    e.reason = "POLICY_UPDATE_PENDING".into();
    journal.save(&e)?;
    let result: PolicyResult<()> = (|| {
        engine.fence(&e)?;
        engine.idle(&e.name())?;
        e.stage = Stage::Writing;
        journal.save(&e)?;
        engine.write(&e, &baseline)?;
        e.stage = Stage::Readback;
        journal.save(&e)?;
        let fp = verify_readback(
            &e.compiled,
            &engine.section(&e.name(), false)?,
            &engine.section(&e.name(), true)?,
            &engine.global()?,
        )?;
        if creating {
            e.stage = Stage::PendingRoot;
            journal.save(&e)?;
            e.root_identity = Some(engine.create_root(&e)?);
            e.stage = Stage::RootBound;
            journal.save(&e)?;
        }
        engine.validate_root(&e)?;
        e.stage = Stage::Verifying;
        journal.save(&e)?;
        e.enforcement_evidence = Some(engine.verify_enforcement(&e)?);
        e.enforcement_binding = Some(engine.enforcement_identity());
        e.fingerprint = Some(fp);
        e.revision += 1;
        e.stage = Stage::Verified;
        e.reason = "POLICY_VERIFIED_TARGET_LAUNCH_DEFERRED".into();
        journal.save(&e)?;
        Ok(())
    })();
    if let Err(reason) = result {
        e.stage = Stage::Conflict;
        e.reason = reason.into();
        e.fingerprint = None;
        e.enforcement_evidence = None;
        e.enforcement_binding = None;
        journal.save(&e)?;
        return Err(reason);
    }
    Ok(e)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    struct Fake {
        sections: RefCell<std::collections::HashMap<String, Section>>,
        busy: RefCell<bool>,
        probe_fail: bool,
        probe_version: RefCell<String>,
        roots: RefCell<Vec<Uuid>>,
    }
    impl Fake {
        fn new() -> Self {
            Self {
                sections: Default::default(),
                busy: RefCell::new(false),
                probe_fail: false,
                probe_version: RefCell::new("TEST_ONLY_VERSION_ONE".into()),
                roots: Default::default(),
            }
        }
    }
    impl Engine for Fake {
        fn root_for(&self, id: Uuid) -> String {
            format!("C:\\Private\\boxes\\{}", id.simple())
        }
        fn metadata(&self) -> String {
            "C:\\Private\\metadata".into()
        }
        fn code(&self) -> String {
            "C:\\Program Files\\SecureRun".into()
        }
        fn engine_identity(&self) -> String {
            "pinned".into()
        }
        fn enforcement_identity(&self) -> String {
            fingerprint(&*self.probe_version.borrow())
        }
        fn global(&self) -> PolicyResult<Section> {
            Ok(Section::from([
                ("NetworkEnableWFP".into(), vec!["y".into()]),
                ("SecureRunWfpState".into(), vec!["READY".into()]),
            ]))
        }
        fn section(&self, n: &str, _: bool) -> PolicyResult<Section> {
            Ok(self.sections.borrow().get(n).cloned().unwrap_or_default())
        }
        fn idle(&self, _: &str) -> PolicyResult<()> {
            if *self.busy.borrow() {
                Err("STOP_REQUIRED")
            } else {
                Ok(())
            }
        }
        fn fence(&self, _: &OwnedEnvironment) -> PolicyResult<()> {
            Ok(())
        }
        fn write(&self, e: &OwnedEnvironment, b: &Section) -> PolicyResult<()> {
            if self.section(&e.name(), false)? != *b {
                return Err("CONFIGURATION_CONFLICT");
            }
            self.sections
                .borrow_mut()
                .insert(e.name(), e.compiled.section.clone());
            Ok(())
        }
        fn create_root(&self, e: &OwnedEnvironment) -> PolicyResult<String> {
            self.roots.borrow_mut().push(e.id);
            Ok(e.id.to_string())
        }
        fn validate_root(&self, e: &OwnedEnvironment) -> PolicyResult<()> {
            if e.root_identity.as_ref() == Some(&e.id.to_string()) {
                Ok(())
            } else {
                Err("ROOT_IDENTITY_CHANGED")
            }
        }
        fn verify_enforcement(&self, _: &OwnedEnvironment) -> PolicyResult<String> {
            if self.probe_fail {
                Err("ENFORCEMENT_NOT_PROVEN")
            } else {
                Ok("SYNTHETIC_TEST_DOUBLE_NOT_WINDOWS_EVIDENCE".into())
            }
        }
    }
    fn store(t: &tempfile::TempDir) -> Journal {
        Journal::open(&t.path().join("policy.sqlite"), "test-owner").unwrap()
    }
    #[test]
    fn duplicate_create_never_dispatches_twice_and_binds_pending_root() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let op = Uuid::new_v4();
        let a = create(&mut j, &f, "test-owner", "A", Default::default(), op).unwrap();
        let b = create(&mut j, &f, "test-owner", "A", Default::default(), op).unwrap();
        assert_eq!(a.id, b.id);
        assert_eq!(f.roots.borrow().len(), 1);
        assert_eq!(a.stage, Stage::Verified);
        assert!(!a.production_launch_available);
    }
    #[test]
    fn operation_tombstones_survive_updates_and_reject_cross_request_replay() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let create_op = Uuid::new_v4();
        let original =
            create(&mut j, &f, "test-owner", "A", Default::default(), create_op).unwrap();
        let next = DesiredPolicy {
            preset: crate::policy::Preset::StandardOnline,
            ..Default::default()
        };
        let apply_op = Uuid::new_v4();
        let updated = apply(
            &mut j,
            &f,
            original.id,
            1,
            next.clone(),
            apply_op,
            false,
            None,
        )
        .unwrap();
        assert_eq!(updated.revision, 2);
        let retry = create(&mut j, &f, "test-owner", "A", Default::default(), create_op).unwrap();
        assert_eq!(retry.revision, 2);
        assert_eq!(f.roots.borrow().len(), 1);
        assert_eq!(
            apply(
                &mut j,
                &f,
                original.id,
                1,
                next.clone(),
                apply_op,
                false,
                None
            )
            .unwrap()
            .revision,
            2
        );
        assert!(
            apply(
                &mut j,
                &f,
                original.id,
                2,
                next.clone(),
                create_op,
                false,
                None
            )
            .is_err()
        );
        assert!(apply(&mut j, &f, original.id, 2, next, apply_op, false, None).is_err());
        drop(j);
        let mut j = store(&t);
        assert_eq!(
            create(&mut j, &f, "test-owner", "A", Default::default(), create_op)
                .unwrap()
                .revision,
            2
        );
        assert!(
            create(
                &mut j,
                &f,
                "test-owner",
                "Different payload",
                Default::default(),
                create_op
            )
            .is_err()
        );
        assert_eq!(f.roots.borrow().len(), 1);
    }
    #[test]
    fn metadata_cannot_drop_generated_protections_or_adopt_replaced_roots() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let mut e = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        e.compiled.section.remove("ClosedFilePath");
        e.fingerprint = Some("forged".into());
        j.save(&e).unwrap();
        assert_eq!(
            validate_owned(&f, &e, &[e.clone()]).unwrap_err(),
            "MANDATORY_POLICY_DRIFT"
        );
        assert!(
            apply(
                &mut j,
                &f,
                e.id,
                1,
                Default::default(),
                Uuid::new_v4(),
                false,
                None
            )
            .is_err()
        );
        e.compiled = compile(&e.desired, &mandatory(&f, e.id, &e.owner_sid, &[e.clone()])).unwrap();
        e.root_identity = Some("different-volume-file-id".into());
        assert_eq!(
            validate_owned(&f, &e, &[e.clone()]).unwrap_err(),
            "ROOT_IDENTITY_CHANGED"
        );
        assert_eq!(f.roots.borrow().len(), 1);
    }
    #[test]
    fn rollout_and_reopened_journal_have_identical_sibling_protections() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let base = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        let mut a = base.clone();
        a.id = Uuid::from_u128(1);
        let mut b = base.clone();
        b.id = Uuid::from_u128(2);
        let mut c = base;
        c.id = Uuid::from_u128(3);
        let listing = vec![a.clone(), b.clone(), c.clone()];
        let rollout = vec![c, a, b.clone()];
        let before = compile(&b.desired, &mandatory(&f, b.id, "test-owner", &rollout)).unwrap();
        let after = compile(&b.desired, &mandatory(&f, b.id, "test-owner", &listing)).unwrap();
        assert_eq!(before.section, after.section);
        assert_eq!(before.desired_fingerprint, after.desired_fingerprint);
    }
    #[test]
    fn ten_sequential_creations_preserve_every_current_owned_policy() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        for index in 0..10 {
            create(
                &mut j,
                &f,
                "test-owner",
                &format!("Reference {index}"),
                Default::default(),
                Uuid::new_v4(),
            )
            .unwrap();
            let all = j.list().unwrap();
            assert_eq!(all.len(), index + 1);
            for e in &all {
                validate_owned(&f, e, &all).unwrap();
            }
        }
        assert_eq!(f.roots.borrow().len(), 10);
    }
    #[test]
    fn new_sibling_requires_stopped_rollout_before_materialization() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let a = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        *f.busy.borrow_mut() = true;
        assert_eq!(
            create(
                &mut j,
                &f,
                "test-owner",
                "B",
                Default::default(),
                Uuid::new_v4()
            )
            .unwrap_err(),
            "STOP_REQUIRED"
        );
        assert_eq!(f.roots.borrow().len(), 1);
        *f.busy.borrow_mut() = false;
        let b = create(
            &mut j,
            &f,
            "test-owner",
            "B",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        assert!(
            f.section(&a.name(), false).unwrap()["ClosedFilePath"]
                .contains(&format!("{}\\*", f.root_for(b.id)))
        );
    }
    #[test]
    fn accepted_configuration_without_enforcement_stays_blocked() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let mut f = Fake::new();
        f.probe_fail = true;
        assert!(
            create(
                &mut j,
                &f,
                "test-owner",
                "A",
                Default::default(),
                Uuid::new_v4()
            )
            .is_err()
        );
        let e = j.list().unwrap().remove(0);
        assert_eq!(e.stage, Stage::Conflict);
        assert!(e.fingerprint.is_none());
        assert!(e.enforcement_evidence.is_none());
    }
    #[test]
    fn changed_verifier_invalidates_cached_proof_without_adopting_or_rewriting() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let e = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        validate_owned(&f, &e, std::slice::from_ref(&e)).unwrap();
        let before = f.section(&e.name(), false).unwrap();
        *f.probe_version.borrow_mut() = "TEST_ONLY_VERSION_TWO".into();
        assert_eq!(
            validate_owned(&f, &e, std::slice::from_ref(&e)).unwrap_err(),
            "ENFORCEMENT_BINDING_CHANGED"
        );
        assert!(
            apply(
                &mut j,
                &f,
                e.id,
                1,
                Default::default(),
                Uuid::new_v4(),
                false,
                None
            )
            .is_err()
        );
        assert_eq!(before, f.section(&e.name(), false).unwrap());
        assert_eq!(f.roots.borrow().len(), 1);
    }
    #[test]
    fn mutation_revision_drift_and_view_changes_are_explicit() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let a = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        assert_eq!(
            apply(
                &mut j,
                &f,
                a.id,
                0,
                Default::default(),
                Uuid::new_v4(),
                true,
                None
            )
            .unwrap_err(),
            "REVISION_CONFLICT"
        );
        let p = DesiredPolicy {
            grants: vec![Grant {
                path: "C:\\Input".into(),
                permission: Permission::ReadOnly,
            }],
            ..Default::default()
        };
        assert_eq!(
            apply(&mut j, &f, a.id, 1, p.clone(), Uuid::new_v4(), false, None).unwrap_err(),
            "READ_ONLY_VIEW_CHANGE_ACK_REQUIRED"
        );
        apply(&mut j, &f, a.id, 1, p, Uuid::new_v4(), true, None).unwrap();
    }
    #[test]
    fn restart_after_every_partial_stage_is_inspect_only() {
        for stage in [
            Stage::Intent,
            Stage::Fenced,
            Stage::Writing,
            Stage::Readback,
            Stage::PendingRoot,
            Stage::RootBound,
            Stage::Verifying,
        ] {
            let t = tempfile::tempdir().unwrap();
            let mut j = store(&t);
            let f = Fake::new();
            let mut a = create(
                &mut j,
                &f,
                "test-owner",
                "A",
                Default::default(),
                Uuid::new_v4(),
            )
            .unwrap();
            a.stage = stage;
            j.save(&a).unwrap();
            drop(j);
            let mut j = store(&t);
            assert_eq!(j.recover().unwrap(), 1);
            let a = j.get(a.id).unwrap();
            assert_eq!(a.stage, Stage::Conflict);
            assert!(a.fingerprint.is_none());
            assert_eq!(f.roots.borrow().len(), 1);
        }
    }
    #[test]
    fn forged_owner_and_database_schema_cannot_expand_authority() {
        let t = tempfile::tempdir().unwrap();
        let mut j = store(&t);
        let f = Fake::new();
        let mut a = create(
            &mut j,
            &f,
            "test-owner",
            "A",
            Default::default(),
            Uuid::new_v4(),
        )
        .unwrap();
        a.owner_sid = "other-user".into();
        assert!(j.save(&a).is_err());
        drop(j);
        assert!(
            Journal::open(&t.path().join("policy.sqlite"), "other-user")
                .unwrap()
                .list()
                .is_err()
        );
    }
}
