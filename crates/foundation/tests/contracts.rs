use rusqlite::Connection;
use securerun_foundation::{binding::*, *};
use std::{cell::Cell, fs};
use uuid::Uuid;

const OWNER: &str = "S-1-5-21-SYNTHETIC";
fn request(e: &Environment) -> ReservationRequest {
    ReservationRequest {
        environment_id: e.id,
        expected_generation: e.generation,
        expected_revision: e.desired_revision,
        idempotency_key: Uuid::new_v4(),
        kind: OperationKind::Launch,
    }
}
fn identity(id: &str) -> FileIdentity {
    FileIdentity {
        volume: 1,
        file_id: id.to_owned(),
        owner_sid: OWNER.to_owned(),
    }
}

#[test]
fn t49_origins_and_labels_are_independent_of_renderer_claims() {
    assert!(authorized_origin(
        "main",
        "https://tauri.localhost/index.html",
        false
    ));
    for (label, url) in [
        ("extra", "https://tauri.localhost/index.html"),
        ("main", "https://tauri.localhost.evil/index.html"),
        ("main", "https://evil.test/"),
        ("main", "https://tauri.localhost/evil.html"),
        ("main", "file:///index.html"),
        ("main", "http://127.0.0.1:1420/"),
    ] {
        assert!(!authorized_origin(label, url, false));
    }
}
#[test]
fn t49_forged_ids_owner_and_unknown_payload_fields_fail() {
    let mut s = Store::memory(OWNER).unwrap();
    let e = s.create_draft("Fixture").unwrap();
    assert_eq!(
        s.environment(Uuid::new_v4(), 1, 0).unwrap_err().code,
        ErrorCode::UnknownEnvironment
    );
    assert_eq!(
        s.environment(e.id, 2, 0).unwrap_err().code,
        ErrorCode::StaleOperation
    );
    assert_eq!(
        s.environment(e.id, 1, 1).unwrap_err().code,
        ErrorCode::RevisionConflict
    );
    let payload = serde_json::json!({"environment_id":e.id,"expected_generation":1,"expected_revision":0,"idempotency_key":Uuid::new_v4(),"kind":"LAUNCH","path":"UNTRUSTED","confirmed":true});
    assert!(serde_json::from_value::<ReservationRequest>(payload).is_err());
}
#[test]
fn t28_missing_metadata_does_not_adopt_engine_boxes() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("fresh.sqlite");
    let store = Store::open(&db, OWNER).unwrap();
    assert!(store.environments().unwrap().is_empty());
    assert!(store.diagnostics().unwrap().is_empty());
}
#[test]
fn t28_unknown_and_foreign_schema_are_preserved() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("foreign.sqlite");
    let c = Connection::open(&db).unwrap();
    c.execute_batch(
        "CREATE TABLE external_fixture(value TEXT); INSERT INTO external_fixture VALUES('KEEP');",
    )
    .unwrap();
    drop(c);
    assert_eq!(
        Store::open(&db, OWNER).err().unwrap().code,
        ErrorCode::MigrationFailed
    );
    let c = Connection::open(&db).unwrap();
    let value: String = c
        .query_row("SELECT value FROM external_fixture", [], |r| r.get(0))
        .unwrap();
    assert_eq!(value, "KEEP");
    c.execute_batch("PRAGMA user_version=999").unwrap();
    drop(c);
    assert_eq!(
        Store::open(&db, OWNER).err().unwrap().code,
        ErrorCode::UnsupportedSchema
    );
}
#[test]
fn t28_corruption_is_not_repaired_by_replacing_the_database() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("broken.sqlite");
    let marker = b"SYNTHETIC_NOT_A_DATABASE";
    fs::write(&db, marker).unwrap();
    assert!(Store::open(&db, OWNER).is_err());
    assert_eq!(fs::read(db).unwrap(), marker);
}
#[test]
fn t28_migration_and_ownership_survive_reopen() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("manager.sqlite");
    let e = {
        let mut s = Store::open(&db, OWNER).unwrap();
        s.create_draft("Стандарт").unwrap()
    };
    let s = Store::open(&db, OWNER).unwrap();
    assert_eq!(s.environment(e.id, 1, 0).unwrap().display_name, "Стандарт");
    drop(s);
    let foreign = Store::open(&db, "S-1-5-21-OTHER").unwrap();
    assert!(foreign.environments().unwrap().is_empty());
    assert_eq!(
        foreign.environment(e.id, 1, 0).unwrap_err().code,
        ErrorCode::Unauthorized
    );
}
#[test]
fn t28_inconsistent_persisted_identity_is_rejected() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("manager.sqlite");
    let e = {
        let mut s = Store::open(&db, OWNER).unwrap();
        s.create_draft("Fixture").unwrap()
    };
    let c = Connection::open(&db).unwrap();
    c.execute("UPDATE environments SET generation=2", [])
        .unwrap();
    drop(c);
    let s = Store::open(&db, OWNER).unwrap();
    assert_eq!(
        s.environment(e.id, 2, 0).unwrap_err().code,
        ErrorCode::CorruptRecord
    );
}
#[test]
fn t56_stale_engine_environment_and_sequence_cannot_overwrite_state() {
    let mut s = Store::memory(OWNER).unwrap();
    let e = s.create_draft("Fixture").unwrap();
    let mut event = StateEvent {
        environment_id: e.id,
        environment_generation: 1,
        engine_generation: 1,
        sequence: 2,
        activity: Activity::Running,
        eligibility: Eligibility::Blocked,
        expected_revision: 0,
        operation_id: None,
    };
    assert!(s.apply_event(&event).unwrap());
    event.sequence = 1;
    event.activity = Activity::Idle;
    event.eligibility = Eligibility::Allowed;
    assert!(!s.apply_event(&event).unwrap());
    let live = s.environment(e.id, 1, 0).unwrap();
    assert_eq!(live.activity, Activity::Running);
    assert_eq!(live.eligibility, Eligibility::Blocked);
    assert_eq!(s.reconnect().unwrap(), 2);
    event.sequence = 3;
    assert!(!s.apply_event(&event).unwrap());
    let live = s.invalidate_environment(e.id, 1, 0).unwrap();
    assert_eq!(live.generation, 2);
    assert_eq!(s.engine_generation().unwrap(), 2);
    event.engine_generation = 2;
    assert!(!s.apply_event(&event).unwrap());
    assert_eq!(
        s.environment(e.id, 2, 0).unwrap().activity,
        Activity::Unknown
    );
}
#[test]
fn t61_duplicate_delivery_never_calls_dispatch_twice() {
    let mut s = Store::memory(OWNER).unwrap();
    let e = s.create_draft("Fixture").unwrap();
    let r = request(&e);
    let calls = Cell::new(0);
    assert!(
        s.dispatch_once(&r, 2, || calls.set(calls.get() + 1))
            .unwrap()
            .is_some()
    );
    assert!(
        s.dispatch_once(&r, 2, || calls.set(calls.get() + 1))
            .unwrap()
            .is_none()
    );
    assert_eq!(calls.get(), 1);
    let mut changed = r.clone();
    changed.kind = OperationKind::Cleanup;
    assert_eq!(
        s.reserve(&changed, 2).unwrap_err().code,
        ErrorCode::OperationConflict
    );
}
#[test]
fn t61_restart_after_reservation_is_unknown_and_never_replayed() {
    for accepted in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("manager.sqlite");
        let (r, id) = {
            let mut s = Store::open(&db, OWNER).unwrap();
            let e = s.create_draft("Fixture").unwrap();
            let r = request(&e);
            let (op, _) = s.reserve(&r, 2).unwrap();
            if accepted {
                s.mark_dispatched(op.id).unwrap();
            }
            (r, op.id)
        };
        let mut s = Store::open(&db, OWNER).unwrap();
        assert_eq!(
            s.operation(id).unwrap().dispatch_state,
            DispatchState::OutcomeUnknown
        );
        let replayed = Cell::new(false);
        assert!(
            s.dispatch_once(&r, 2, || replayed.set(true))
                .unwrap()
                .is_none()
        );
        assert!(!replayed.get());
        assert_eq!(
            s.mark_dispatched(id).unwrap_err().code,
            ErrorCode::OperationOutcomeUnknown
        );
    }
}
#[test]
fn t61_uncertainty_does_not_release_the_environment_operation_lock() {
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("manager.sqlite");
    let e = {
        let mut s = Store::open(&db, OWNER).unwrap();
        let e = s.create_draft("Fixture").unwrap();
        s.reserve(&request(&e), 2).unwrap();
        e
    };
    let mut s = Store::open(&db, OWNER).unwrap();
    assert_eq!(
        s.reserve(&request(&e), 2).unwrap_err().code,
        ErrorCode::OperationConflict
    );
}
#[test]
fn t65_replaced_identity_and_old_generation_never_authorize_recovery() {
    let mut s = Store::memory(OWNER).unwrap();
    let e = s.create_draft("Fixture").unwrap();
    let (op, _) = s.reserve(&request(&e), 2).unwrap();
    let item = ArtifactRecord {
        id: Uuid::new_v4(),
        operation_id: op.id,
        environment_generation: 1,
        parent_identity: identity("parent"),
        identity: identity("created-object"),
        role: ArtifactRole::ImportStaging,
        leaf_name: "owned-stage".to_owned(),
    };
    s.record_artifact(&item).unwrap();
    assert!(
        s.reconcile_artifact(item.id, &item.parent_identity, &item.identity)
            .unwrap()
    );
    assert_eq!(
        s.reconcile_artifact(item.id, &item.parent_identity, &identity("replacement"))
            .unwrap_err()
            .code,
        ErrorCode::IdentityMismatch
    );
    s.invalidate_environment(e.id, 1, 0).unwrap();
    assert_eq!(
        s.reconcile_artifact(item.id, &item.parent_identity, &item.identity)
            .unwrap_err()
            .code,
        ErrorCode::StaleOperation
    );
}
#[test]
fn t65_artifact_records_cannot_supply_arbitrary_recovery_paths() {
    let mut s = Store::memory(OWNER).unwrap();
    let e = s.create_draft("Fixture").unwrap();
    let (op, _) = s.reserve(&request(&e), 2).unwrap();
    let item = ArtifactRecord {
        id: Uuid::new_v4(),
        operation_id: op.id,
        environment_generation: 1,
        parent_identity: identity("parent"),
        identity: identity("file"),
        role: ArtifactRole::ExportStaging,
        leaf_name: "../outside".to_owned(),
    };
    assert_eq!(
        s.record_artifact(&item).unwrap_err().code,
        ErrorCode::Unauthorized
    );
}
#[test]
fn t66_local_and_shared_diagnostics_drop_secrets_before_serialization() {
    let secret = "P03_SYNTHETIC_SECRET_ARGUMENT_ENV_PASSWORD\r\nFORGED_EVENT\u{202e}";
    let entry = minimized_diagnostic(AuditCode::RequestRejected, secret, 1, 10);
    let local = serde_json::to_string(&entry).unwrap();
    let shared = serde_json::to_string(&vec![entry]).unwrap();
    for text in [local, shared] {
        assert!(!text.contains("P03_SYNTHETIC_SECRET"));
        assert!(!text.contains("FORGED_EVENT"));
        assert!(!text.contains('\n'));
    }
    for name in ["injected\nlog", "injected\rlog", "hidden\u{202e}exe"] {
        assert_eq!(
            validate_name(name).unwrap_err().code,
            ErrorCode::InvalidInput
        );
    }
}
#[test]
fn t66_retention_is_bounded_before_rendering() {
    let mut s = Store::memory(OWNER).unwrap();
    for _ in 0..4100 {
        s.audit(AuditCode::RequestRejected).unwrap();
    }
    let items = s.diagnostics().unwrap();
    assert_eq!(items.len(), 4096);
    assert!(serde_json::to_vec(&items).unwrap().len() < 1024 * 1024);
}
#[test]
fn coordinator_denies_a_second_writer_without_deleting_the_lock_file() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("writer.lock");
    let first = fs::OpenOptions::new()
        .create_new(true)
        .read(true)
        .write(true)
        .open(&path)
        .unwrap();
    first.try_lock().unwrap();
    let second = fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open(&path)
        .unwrap();
    assert!(second.try_lock().is_err());
    drop(first);
    second.try_lock().unwrap();
    assert!(path.exists());
}

#[test]
fn t49_selection_tokens_are_one_use_and_bound_to_operation_purpose_and_caller() {
    let mut store = Store::memory(OWNER).unwrap();
    let e = store.create_draft("Fixture").unwrap();
    let (op, _) = store.reserve(&request(&e), 2).unwrap();
    let mut selections = Selections::default();
    let id = Uuid::new_v4();
    selections
        .insert(BoundSelection {
            id,
            operation_id: op.id,
            environment_id: e.id,
            generation: 1,
            revision: 0,
            purpose: SelectionPurpose::Import,
            caller_label: "main".into(),
            expires_at: 60,
            path: "PRIVATE_BACKEND_ONLY".into(),
            identity: identity("selected"),
        })
        .unwrap();
    assert_eq!(
        selections
            .consume(id, &op, SelectionPurpose::Export, "main", 1)
            .err()
            .unwrap()
            .code,
        ErrorCode::SelectionScopeMismatch
    );
    assert_eq!(
        selections
            .consume(id, &op, SelectionPurpose::Import, "other", 1)
            .err()
            .unwrap()
            .code,
        ErrorCode::SelectionScopeMismatch
    );
    assert!(
        selections
            .consume(id, &op, SelectionPurpose::Import, "main", 1)
            .is_ok()
    );
    assert!(
        selections
            .consume(id, &op, SelectionPurpose::Import, "main", 1)
            .is_err()
    );
}
#[test]
fn t49_expired_or_invalidated_selections_cannot_be_consumed() {
    let mut store = Store::memory(OWNER).unwrap();
    let e = store.create_draft("Fixture").unwrap();
    let (op, _) = store.reserve(&request(&e), 2).unwrap();
    let mut selections = Selections::default();
    let id = Uuid::new_v4();
    selections
        .insert(BoundSelection {
            id,
            operation_id: op.id,
            environment_id: e.id,
            generation: 1,
            revision: 0,
            purpose: SelectionPurpose::Import,
            caller_label: "main".into(),
            expires_at: 60,
            path: "PRIVATE_BACKEND_ONLY".into(),
            identity: identity("selected"),
        })
        .unwrap();
    assert_eq!(
        selections
            .consume(id, &op, SelectionPurpose::Import, "main", 60)
            .err()
            .unwrap()
            .code,
        ErrorCode::SelectionExpired
    );
    selections.invalidate_environment(e.id);
    assert!(
        selections
            .consume(id, &op, SelectionPurpose::Import, "main", 1)
            .is_err()
    );
}
