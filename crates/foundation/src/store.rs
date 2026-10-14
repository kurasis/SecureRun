use crate::*;
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use std::path::Path;
use uuid::Uuid;
fn timestamp() -> Result<u64> {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .map_err(|_| AppError::new(ErrorCode::InvalidInput))
}

pub struct Store {
    db: Connection,
    owner: String,
}
fn db_error(_: rusqlite::Error) -> AppError {
    AppError::new(ErrorCode::DatabaseUnavailable)
}
fn encode<T: serde::Serialize>(value: &T) -> Result<String> {
    serde_json::to_string(value).map_err(|_| AppError::new(ErrorCode::CorruptRecord))
}
fn decode<T: serde::de::DeserializeOwned>(text: String) -> Result<T> {
    serde_json::from_str(&text).map_err(|_| AppError::new(ErrorCode::CorruptRecord))
}
fn run_migration(db: &mut Connection, sql: &str) -> Result<()> {
    let tx = db
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .map_err(|_| AppError::new(ErrorCode::MigrationFailed))?;
    tx.execute_batch(sql)
        .map_err(|_| AppError::new(ErrorCode::MigrationFailed))?;
    tx.commit()
        .map_err(|_| AppError::new(ErrorCode::MigrationFailed))?;
    Ok(())
}

impl Store {
    pub fn open(path: &Path, owner: &str) -> Result<Self> {
        let db = Connection::open(path).map_err(db_error)?;
        Self::initialize(db, owner)
    }
    pub fn memory(owner: &str) -> Result<Self> {
        Self::initialize(Connection::open_in_memory().map_err(db_error)?, owner)
    }
    fn initialize(mut db: Connection, owner: &str) -> Result<Self> {
        if owner.is_empty() || owner.len() > 184 {
            return err(ErrorCode::Unauthorized);
        }
        db.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(db_error)?;
        db.execute_batch(
            "PRAGMA foreign_keys=ON; PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL;",
        )
        .map_err(db_error)?;
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .map_err(db_error)?;
        if version > 1 {
            return err(ErrorCode::UnsupportedSchema);
        }
        if version == 0 {
            let count: u32 = db
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
                    [],
                    |row| row.get(0),
                )
                .map_err(db_error)?;
            if count != 0 {
                return err(ErrorCode::MigrationFailed);
            }
            run_migration(&mut db, include_str!("../migrations/001_initial.sql"))?;
        }
        let integrity: String = db
            .query_row("PRAGMA quick_check(1)", [], |row| row.get(0))
            .map_err(db_error)?;
        if integrity != "ok" {
            return err(ErrorCode::CorruptRecord);
        }
        db.execute_batch("PRAGMA journal_mode=WAL;")
            .map_err(db_error)?;
        let mut store = Self {
            db,
            owner: owner.to_owned(),
        };
        // No restart replay: a reservation alone may precede an accepted mutation.
        store.recover()?;
        Ok(store)
    }
    pub fn create_draft(&mut self, name: &str) -> Result<Environment> {
        let name = validate_name(name)?;
        let now = timestamp()?;
        let env = Environment {
            id: Uuid::new_v4(),
            owner_sid: self.owner.clone(),
            display_name: name,
            generation: 1,
            desired_revision: 0,
            verified_revision: None,
            lifecycle: Lifecycle::Unconfigured,
            activity: Activity::Unknown,
            eligibility: Eligibility::Unverified,
            engine_box_name: None,
            root_identity: None,
            current_operation: None,
            last_sequence: 0,
            created_at: now,
            updated_at: now,
        };
        self.db
            .execute(
                "INSERT INTO environments VALUES(?1,?2,?3,?4,?5)",
                params![env.id.to_string(), env.owner_sid, 1, 0, encode(&env)?],
            )
            .map_err(db_error)?;
        self.audit(AuditCode::DraftCreated)?;
        Ok(env)
    }
    pub fn environment(&self, id: Uuid, generation: u64, revision: u64) -> Result<Environment> {
        let row: Option<(String, u64, u64, String)> = self
            .db
            .query_row(
                "SELECT owner_sid,generation,revision,document FROM environments WHERE id=?1",
                [id.to_string()],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
            )
            .optional()
            .map_err(db_error)?;
        let (owner, stored_generation, stored_revision, document) =
            row.ok_or_else(|| AppError::new(ErrorCode::UnknownEnvironment))?;
        let env: Environment = decode(document)?;
        if env.id != id
            || env.owner_sid != owner
            || env.generation != stored_generation
            || env.desired_revision != stored_revision
        {
            return err(ErrorCode::CorruptRecord);
        }
        if owner != self.owner {
            return err(ErrorCode::Unauthorized);
        }
        if stored_generation != generation || env.lifecycle == Lifecycle::Removed {
            return err(ErrorCode::StaleOperation);
        }
        if stored_revision != revision {
            return err(ErrorCode::RevisionConflict);
        }
        Ok(env)
    }
    pub fn environments(&self) -> Result<Vec<Environment>> {
        let mut statement=self.db.prepare("SELECT id,generation,revision FROM environments WHERE owner_sid=?1 ORDER BY id LIMIT 1001").map_err(db_error)?;
        let keys = statement
            .query_map([&self.owner], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, u64>(1)?,
                    row.get::<_, u64>(2)?,
                ))
            })
            .map_err(db_error)?
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(db_error)?;
        if keys.len() > 1000 {
            return err(ErrorCode::CorruptRecord);
        }
        keys.into_iter()
            .map(|(id, g, r)| {
                self.environment(
                    Uuid::parse_str(&id).map_err(|_| AppError::new(ErrorCode::CorruptRecord))?,
                    g,
                    r,
                )
            })
            .collect()
    }
    fn save_environment(db: &Connection, env: &Environment) -> Result<()> {
        db.execute(
            "UPDATE environments SET generation=?1,revision=?2,document=?3 WHERE id=?4",
            params![
                env.generation,
                env.desired_revision,
                encode(env)?,
                env.id.to_string()
            ],
        )
        .map_err(db_error)?;
        Ok(())
    }
    pub fn reserve(
        &mut self,
        request: &ReservationRequest,
        session: u32,
    ) -> Result<(Operation, bool)> {
        let env = self.environment(
            request.environment_id,
            request.expected_generation,
            request.expected_revision,
        )?;
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        let old: Option<String>=tx.query_row("SELECT document FROM operations WHERE environment_id=?1 AND generation=?2 AND idempotency_key=?3",params![env.id.to_string(),env.generation,request.idempotency_key.to_string()],|row|row.get(0)).optional().map_err(db_error)?;
        if let Some(document) = old {
            let op: Operation = decode(document)?;
            if op.environment_id != env.id
                || op.environment_generation != env.generation
                || op.idempotency_key != request.idempotency_key
            {
                return err(ErrorCode::CorruptRecord);
            }
            if op.kind != request.kind
                || op.requested_revision != request.expected_revision
                || op.initiator_sid != self.owner
                || op.session != session
            {
                return err(ErrorCode::OperationConflict);
            }
            return Ok((op, false));
        }
        let busy: u32 = tx
            .query_row(
                "SELECT count(*) FROM operations WHERE environment_id=?1 AND state!='COMPLETED'",
                [env.id.to_string()],
                |row| row.get(0),
            )
            .map_err(db_error)?;
        if busy != 0 {
            return err(ErrorCode::OperationConflict);
        }
        let op = Operation {
            id: Uuid::new_v4(),
            idempotency_key: request.idempotency_key,
            environment_id: env.id,
            environment_generation: env.generation,
            requested_revision: env.desired_revision,
            initiator_sid: self.owner.clone(),
            session,
            kind: request.kind,
            dispatch_state: DispatchState::Reserved,
            error: None,
            phase: OperationPhase::IntentReserved,
            recovery_action: RecoveryAction::None,
            created_at: timestamp()?,
            updated_at: timestamp()?,
        };
        tx.execute(
            "INSERT INTO operations VALUES(?1,?2,?3,?4,'RESERVED',?5)",
            params![
                op.id.to_string(),
                env.id.to_string(),
                env.generation,
                op.idempotency_key.to_string(),
                encode(&op)?
            ],
        )
        .map_err(db_error)?;
        let mut env = env;
        env.current_operation = Some(op.id);
        Self::save_environment(&tx, &env)?;
        tx.commit().map_err(db_error)?;
        self.audit(AuditCode::ReservationStored)?;
        Ok((op, true))
    }
    pub fn operation(&self, id: Uuid) -> Result<Operation> {
        let row: Option<(String, String)> = self
            .db
            .query_row(
                "SELECT state,document FROM operations WHERE id=?1",
                [id.to_string()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(db_error)?;
        let (state, document) = row.ok_or_else(|| AppError::new(ErrorCode::Unauthorized))?;
        let op: Operation = decode(document)?;
        if op.id != id || encode(&op.dispatch_state)? != format!("\"{state}\"") {
            return err(ErrorCode::CorruptRecord);
        }
        self.environment(
            op.environment_id,
            op.environment_generation,
            op.requested_revision,
        )?;
        if op.initiator_sid != self.owner {
            return err(ErrorCode::Unauthorized);
        }
        Ok(op)
    }
    fn save_operation(db: &Connection, op: &Operation) -> Result<()> {
        let state = encode(&op.dispatch_state)?;
        let state = state.trim_matches('"');
        db.execute(
            "UPDATE operations SET state=?1,document=?2 WHERE id=?3",
            params![state, encode(op)?, op.id.to_string()],
        )
        .map_err(db_error)?;
        Ok(())
    }
    pub fn mark_dispatched(&mut self, id: Uuid) -> Result<Operation> {
        let mut op = self.operation(id)?;
        if op.dispatch_state != DispatchState::Reserved {
            return err(ErrorCode::OperationOutcomeUnknown);
        }
        op.dispatch_state = DispatchState::Dispatched;
        op.phase = OperationPhase::ExternalDispatch;
        op.updated_at = timestamp()?;
        Self::save_operation(&self.db, &op)?;
        self.audit(AuditCode::DispatchReserved)?;
        Ok(op)
    }
    pub fn dispatch_once<T>(
        &mut self,
        request: &ReservationRequest,
        session: u32,
        dispatch: impl FnOnce() -> T,
    ) -> Result<Option<T>> {
        let (op, fresh) = self.reserve(request, session)?;
        if !fresh {
            return Ok(None);
        }
        self.mark_dispatched(op.id)?;
        Ok(Some(dispatch()))
    }
    fn recover(&mut self) -> Result<()> {
        let records = {
            let mut s=self.db.prepare("SELECT operations.document FROM operations JOIN environments ON environments.id=operations.environment_id WHERE environments.owner_sid=?1 AND operations.state IN ('RESERVED','DISPATCHED') LIMIT 1001").map_err(db_error)?;
            s.query_map([&self.owner], |row| row.get::<_, String>(0))
                .map_err(db_error)?
                .collect::<std::result::Result<Vec<_>, _>>()
                .map_err(db_error)?
        };
        if records.len() > 1000 {
            return err(ErrorCode::CorruptRecord);
        }
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        for record in records {
            let mut op: Operation = decode(record)?;
            if op.initiator_sid != self.owner {
                return err(ErrorCode::CorruptRecord);
            }
            op.dispatch_state = DispatchState::OutcomeUnknown;
            op.phase = OperationPhase::AwaitingReconciliation;
            op.recovery_action = RecoveryAction::InspectOnly;
            op.updated_at = timestamp()?;
            op.error = Some(ErrorCode::OperationOutcomeUnknown);
            Self::save_operation(&tx, &op)?;
        }
        tx.commit().map_err(db_error)?;
        Ok(())
    }
    pub fn invalidate_environment(
        &mut self,
        id: Uuid,
        generation: u64,
        revision: u64,
    ) -> Result<Environment> {
        let mut env = self.environment(id, generation, revision)?;
        env.generation = env
            .generation
            .checked_add(1)
            .filter(|n| *n <= i64::MAX as u64)
            .ok_or_else(|| AppError::new(ErrorCode::StaleOperation))?;
        env.activity = Activity::Unknown;
        env.eligibility = Eligibility::Unverified;
        env.verified_revision = None;
        env.root_identity = None;
        env.current_operation = None;
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        Self::save_environment(&tx, &env)?;
        tx.commit().map_err(db_error)?;
        Ok(env)
    }
    pub fn engine_generation(&self) -> Result<u64> {
        self.db
            .query_row(
                "SELECT engine_generation FROM manager_meta WHERE singleton=1",
                [],
                |row| row.get(0),
            )
            .map_err(db_error)
    }
    pub fn sequence(&self) -> Result<u64> {
        self.db
            .query_row(
                "SELECT sequence FROM manager_meta WHERE singleton=1",
                [],
                |row| row.get(0),
            )
            .map_err(db_error)
    }
    pub fn next_event(&mut self, id: Uuid, generation: u64, revision: u64) -> Result<StateEvent> {
        let mut env = self.environment(id, generation, revision)?;
        let engine_generation = self.engine_generation()?;
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        let updated=tx.execute("UPDATE manager_meta SET sequence=sequence+1 WHERE singleton=1 AND sequence<9223372036854775807",[]).map_err(db_error)?;
        if updated != 1 {
            return err(ErrorCode::CorruptRecord);
        }
        let seq: u64 = tx
            .query_row(
                "SELECT sequence FROM manager_meta WHERE singleton=1",
                [],
                |row| row.get(0),
            )
            .map_err(db_error)?;
        env.last_sequence = seq;
        Self::save_environment(&tx, &env)?;
        tx.commit().map_err(db_error)?;
        Ok(StateEvent {
            environment_id: id,
            environment_generation: generation,
            engine_generation,
            sequence: seq,
            activity: env.activity,
            eligibility: env.eligibility,
            expected_revision: revision,
            operation_id: env.current_operation,
        })
    }
    pub fn reconnect(&mut self) -> Result<u64> {
        let environments = self.environments()?;
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        let updated=tx.execute("UPDATE manager_meta SET engine_generation=engine_generation+1 WHERE singleton=1 AND engine_generation<9223372036854775807",[]).map_err(db_error)?;
        if updated != 1 {
            return err(ErrorCode::CorruptRecord);
        }
        for mut env in environments {
            env.activity = Activity::Unknown;
            env.eligibility = Eligibility::Unverified;
            env.verified_revision = None;
            Self::save_environment(&tx, &env)?;
        }
        tx.commit().map_err(db_error)?;
        self.engine_generation()
    }
    pub fn apply_event(&mut self, event: &StateEvent) -> Result<bool> {
        if event.engine_generation != self.engine_generation()? {
            return Ok(false);
        }
        let keys: Option<(u64, u64)> = self
            .db
            .query_row(
                "SELECT generation,revision FROM environments WHERE id=?1",
                [event.environment_id.to_string()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(db_error)?;
        let Some((generation, revision)) = keys else {
            return Ok(false);
        };
        if generation != event.environment_generation {
            return Ok(false);
        }
        let mut env = self.environment(event.environment_id, generation, revision)?;
        if event.expected_revision != revision
            || event
                .operation_id
                .is_some_and(|id| env.current_operation != Some(id))
        {
            return Ok(false);
        }
        if event.sequence <= env.last_sequence || event.sequence > i64::MAX as u64 {
            return Ok(false);
        }
        env.last_sequence = event.sequence;
        env.activity = event.activity;
        env.eligibility = event.eligibility;
        Self::save_environment(&self.db, &env)?;
        Ok(true)
    }
    pub fn record_artifact(&mut self, record: &ArtifactRecord) -> Result<()> {
        let op = self.operation(record.operation_id)?;
        if record.environment_generation != op.environment_generation
            || record.identity.owner_sid != self.owner
            || record.parent_identity.owner_sid != self.owner
            || record.leaf_name.is_empty()
            || record.leaf_name.len() > 180
            || record.leaf_name.contains(['\\', '/', ':'])
        {
            return err(ErrorCode::Unauthorized);
        }
        validate_name(&record.leaf_name)?;
        self.db
            .execute(
                "INSERT INTO artifacts VALUES(?1,?2,?3)",
                params![record.id.to_string(), op.id.to_string(), encode(record)?],
            )
            .map_err(db_error)?;
        Ok(())
    }
    pub fn reconcile_artifact(
        &self,
        id: Uuid,
        observed_parent: &FileIdentity,
        observed: &FileIdentity,
    ) -> Result<bool> {
        let text: Option<String> = self
            .db
            .query_row(
                "SELECT document FROM artifacts WHERE id=?1",
                [id.to_string()],
                |row| row.get(0),
            )
            .optional()
            .map_err(db_error)?;
        let item: ArtifactRecord =
            decode(text.ok_or_else(|| AppError::new(ErrorCode::Unauthorized))?)?;
        let op = self.operation(item.operation_id)?;
        if item.environment_generation != op.environment_generation {
            return err(ErrorCode::StaleOperation);
        }
        if &item.parent_identity != observed_parent || &item.identity != observed {
            return err(ErrorCode::IdentityMismatch);
        }
        // Identity agreement only authorizes later reconciliation, never deletion here.
        Ok(true)
    }
    pub fn audit(&mut self, code: AuditCode) -> Result<AuditEntry> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|_| AppError::new(ErrorCode::InvalidInput))?
            .as_secs();
        let tx = self
            .db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db_error)?;
        tx.execute("UPDATE manager_meta SET sequence=sequence+1 WHERE singleton=1 AND sequence<9223372036854775807",[]).map_err(db_error)?;
        let seq: u64 = tx
            .query_row(
                "SELECT sequence FROM manager_meta WHERE singleton=1",
                [],
                |row| row.get(0),
            )
            .map_err(db_error)?;
        let entry = minimized_diagnostic(code, "", seq, now);
        tx.execute(
            "INSERT INTO audit VALUES(?1,?2,?3)",
            params![seq, now, encode(&entry)?],
        )
        .map_err(db_error)?;
        tx.execute(
            "DELETE FROM audit WHERE sequence<=?1 OR timestamp<?2",
            params![seq.saturating_sub(4096), now.saturating_sub(30 * 86400)],
        )
        .map_err(db_error)?;
        tx.commit().map_err(db_error)?;
        Ok(entry)
    }
    pub fn diagnostics(&self) -> Result<Vec<AuditEntry>> {
        let mut statement = self
            .db
            .prepare("SELECT document FROM audit ORDER BY sequence DESC LIMIT 4096")
            .map_err(db_error)?;
        let rows = statement
            .query_map([], |row| row.get::<_, String>(0))
            .map_err(db_error)?
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(db_error)?;
        rows.into_iter().map(decode).collect()
    }
}

#[cfg(test)]
mod migration_tests {
    use super::*;
    #[test]
    fn t28_partial_migration_failure_rolls_back_schema_and_version() {
        let mut db = Connection::open_in_memory().unwrap();
        let error=run_migration(&mut db,"CREATE TABLE partial_fixture(value TEXT); PRAGMA user_version=1; THIS_IS_A_NAMED_FAILURE;").unwrap_err();
        assert_eq!(error.code, ErrorCode::MigrationFailed);
        let count: u32 = db
            .query_row(
                "SELECT count(*) FROM sqlite_master WHERE name='partial_fixture'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        let version: u32 = db
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .unwrap();
        assert_eq!((count, version), (0, 0));
        run_migration(&mut db, include_str!("../migrations/001_initial.sql")).unwrap();
        assert_eq!(
            db.query_row("PRAGMA user_version", [], |r| r.get::<_, u32>(0))
                .unwrap(),
            1
        );
    }
}
