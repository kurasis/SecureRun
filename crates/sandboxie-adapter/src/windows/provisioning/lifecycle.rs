//! Native lifecycle service; only the source-pinned original narrow cleanup ABI.
use super::*;
use crate::lifecycle::{self as contract, Action, Mode, Plan, Record, State};
use std::io::{BufRead, BufReader};
mod seal;

fn checkpoint(stage: &str) {
    #[cfg(feature = "policy-ci")]
    if std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true")
        && std::env::var("SECURERUN_P08_PAUSE_STAGE").as_deref() == Ok(stage)
    {
        println!("CHECKPOINT_{stage}");
        let _ = std::io::stdout().flush();
        loop {
            std::thread::park_timeout(Duration::from_secs(1));
        }
    }
    let _ = stage;
}
fn lock(engine: &NativeEngine) -> R<File> {
    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .share_mode(0)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(engine.profile.join("metadata/policy-writer.lock"))
        .map_err(|_| "NAMESPACE_OPERATION_BUSY")?;
    identity(&f)?;
    Ok(f)
}
fn journals(engine: &NativeEngine) -> R<(Journal, contract::Journal)> {
    let meta = engine.profile.join("metadata");
    for name in ["policy.sqlite", "lifecycle.sqlite"] {
        let p = meta.join(name);
        if p.exists() {
            let _ = lease(&p, true)?;
        }
    }
    Ok((
        Journal::open(&meta.join("policy.sqlite"), &engine.owner)?,
        contract::Journal::open(&meta.join("lifecycle.sqlite"), &engine.owner)?,
    ))
}
fn scope(engine: &NativeEngine, e: &OwnedEnvironment, all: &[OwnedEnvironment]) -> R<String> {
    scope_checked(engine, e, all, false)
}
fn scope_sealed(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
) -> R<String> {
    scope_checked(engine, e, all, true)
}
fn scope_checked(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
    sealed: bool,
) -> R<String> {
    engine.mutation_context()?;
    if e.owner_sid != engine.owner || e.engine_identity != engine.engine_identity() {
        return Err("LIFECYCLE_OWNERSHIP_CHANGED");
    }
    let _root = if sealed {
        seal::sealed_root(engine, e)?
    } else {
        engine.control_scope(e)?
    };
    // Independent cleanup readiness: no paid/network-enforcement prerequisite,
    // but current complete policy/inheritance, ownership and hooks are mandatory.
    let raw = engine.section(&e.name(), false)?;
    if e.compiled.section.get("FileRootPath") != Some(&vec![engine.root_for(e.id)])
        || raw.get("SecureRunOwner") != Some(&vec![e.marker()])
    {
        return Err("LIFECYCLE_SCOPE_CHANGED");
    }
    let fingerprint = verify_readback(
        &e.compiled,
        &raw,
        &engine.section(&e.name(), true)?,
        &engine.global()?,
    )?;
    for other in all.iter().filter(|x| x.id != e.id) {
        if engine
            .root_for(other.id)
            .eq_ignore_ascii_case(&engine.root_for(e.id))
        {
            return Err("LIFECYCLE_ROOT_OVERLAP");
        }
    }
    engine.idle(&e.name())?;
    Ok(fingerprint)
}
fn unchanged(engine: &NativeEngine, e: &OwnedEnvironment, r: &Record) -> R<()> {
    if e.id != r.environment_id
        || e.owner_sid != r.owner
        || e.engine_identity != r.engine
        || e.generation != r.generation
        || e.revision != r.revision
        || e.root_identity.as_deref() != Some(&r.root_identity)
    {
        return Err("STALE_LIFECYCLE_OPERATION");
    }
    let root = engine.control_scope(e)?;
    if identity(
        root.get(root.len().checked_sub(2).ok_or("CLEANUP_PARENT_UNKNOWN")?)
            .ok_or("CLEANUP_PARENT_UNKNOWN")?,
    )? != r.parent_identity
    {
        return Err("CLEANUP_PARENT_CHANGED");
    }
    Ok(())
}
fn stage(j: &mut contract::Journal, r: &mut Record, value: &str, reason: &str) -> R<()> {
    r.stage = value.into();
    r.reason = reason.into();
    r.updated = contract::now();
    j.save(r)
}
fn plan(r: &Record) -> Plan {
    Plan {
        plan_id: r.plan_id,
        operation_id: r.operation_id,
        environment_id: r.environment_id,
        display_name: r.display_name.clone(),
        intent: r.intent,
        retention: r.intent.retention().into(),
        generation: r.generation,
        expires_in_seconds: 60,
    }
}
fn control_reconciled(engine: &NativeEngine, id: Uuid) -> R<()> {
    let path = engine.profile.join("metadata/control.sqlite");
    if !path.exists() {
        return Ok(());
    }
    let mut control = crate::control::Journal::open(&path, &engine.owner)?;
    control.reconcile_environment(id)?;
    Ok(())
}
fn prepare(
    engine: &NativeEngine,
    j: &mut Journal,
    ops: &mut contract::Journal,
    request: &contract::Request,
) -> R<Plan> {
    let contract::Request::Prepare {
        environment_id,
        expected_revision,
        expected_generation,
        operation_id,
        intent,
    } = request
    else {
        return Err("LIFECYCLE_REQUEST_INVALID");
    };
    let signature = contract::signature(request);
    if let Some(old) = ops.get(*operation_id)? {
        if old.signature != signature {
            return Err("OPERATION_CONFLICT");
        }
        if old.stage != "PREPARED" {
            return Err("LIFECYCLE_OPERATION_ALREADY_RECORDED");
        }
        if contract::now().saturating_sub(old.created) > 60 {
            return Err("LIFECYCLE_CONFIRMATION_EXPIRED");
        }
        return Ok(plan(&old));
    }
    let e = j.get(*environment_id)?;
    if e.revision != *expected_revision || e.generation != *expected_generation {
        return Err("STALE_LIFECYCLE_OPERATION");
    }
    if e.lifecycle_operation.is_some() {
        return Err("LIFECYCLE_RECONCILIATION_REQUIRED");
    }
    let all = j.list()?;
    let policy = scope(engine, &e, &all)?;
    if *intent == Action::Unarchive {
        validate_owned(engine, &e, &all)?
    }
    let root = engine.control_scope(&e)?;
    let r = Record {
        operation_id: *operation_id,
        plan_id: Uuid::new_v4(),
        environment_id: e.id,
        display_name: e.display_name.clone(),
        owner: e.owner_sid.clone(),
        engine: e.engine_identity.clone(),
        generation: e.generation,
        revision: e.revision,
        root_identity: e.root_identity.clone().ok_or("CLEANUP_ROOT_UNKNOWN")?,
        parent_identity: identity(root.get(root.len() - 2).ok_or("CLEANUP_PARENT_UNKNOWN")?)?,
        intent: *intent,
        signature,
        scope: policy,
        created: contract::now(),
        updated: contract::now(),
        stage: "PREPARED".into(),
        reason: "NATIVE_CONFIRMATION_REQUIRED".into(),
        native_status: None,
        snapshot: None,
    };
    ops.save(&r)?;
    Ok(plan(&r))
}
fn finish_simple(
    engine: &NativeEngine,
    j: &mut Journal,
    ops: &mut contract::Journal,
    e: &mut OwnedEnvironment,
    r: &mut Record,
) -> R<()> {
    match r.intent {
        Action::Archive => e.lifecycle = State::Archived,
        Action::Unarchive => {
            validate_owned(engine, e, &j.list()?)?;
            e.lifecycle = State::Active
        }
        Action::Persistent => {
            e.mode = Mode::Persistent;
            e.disposable_pending = false
        }
        Action::Disposable => {
            e.mode = Mode::Disposable;
            e.disposable_pending = false
        }
        Action::Resume => {
            if e.lifecycle != State::Active {
                return Err("LIFECYCLE_NOT_ACTIVE");
            };
            e.disposable_pending = false
        }
        _ => return Err("LIFECYCLE_REQUEST_INVALID"),
    }
    // Journal before metadata; recovery only checks the recorded desired state.
    stage(ops, r, "METADATA_RESERVED", "OUTCOME_UNKNOWN")?;
    checkpoint("MetadataReserved");
    j.save(e)?;
    checkpoint("MetadataCommitted");
    stage(ops, r, "COMPLETE", "RETENTION_POSTCONDITIONS_VERIFIED")
}
struct Module(HMODULE);
impl Drop for Module {
    fn drop(&mut self) {
        unsafe {
            FreeLibrary(self.0);
        }
    }
}
type DeleteNative = unsafe extern "C" fn(
    *mut NtAttributes,
    unsafe extern "C" fn(*const u16, *mut c_void) -> bool,
    *mut c_void,
) -> i32;
struct Cleanup {
    _module: Module,
    _held: Vec<File>,
    delete: DeleteNative,
}

fn cleanup(engine: &NativeEngine) -> R<Cleanup> {
    let pin: serde_json::Value =
        serde_json::from_str(include_str!("../../../cleanup-compatibility-v1.json"))
            .map_err(|_| "CLEANUP_MANIFEST_INVALID")?;
    let target = pin["targets"]
        .as_array()
        .and_then(|a| {
            a.iter()
                .find(|x| x["architecture"] == std::env::consts::ARCH)
        })
        .ok_or("CLEANUP_ARCHITECTURE_UNSUPPORTED")?;
    let mut held = vec![];
    for component in target["components"]
        .as_array()
        .ok_or("CLEANUP_MANIFEST_INVALID")?
    {
        let name = component["name"]
            .as_str()
            .ok_or("CLEANUP_MANIFEST_INVALID")?;
        crate::files::leaf(name)?;
        let path = engine.trusted.home.join(name);
        let mut f = lease(&path, false)?;
        protected(&f)?;
        let mut digest = Sha256::new();
        let mut buffer = [0u8; 65536];
        let mut size = 0;
        loop {
            let n = f
                .read(&mut buffer)
                .map_err(|_| "CLEANUP_COMPONENT_UNAVAILABLE")?;
            if n == 0 {
                break;
            };
            size += n;
            if size > 128 * 1024 * 1024 {
                return Err("CLEANUP_COMPONENT_BOUND");
            };
            digest.update(&buffer[..n]);
        }
        if component["sha256"].as_str() != Some(format!("{:x}", digest.finalize()).as_str()) {
            return Err("CLEANUP_COMPONENT_CHANGED");
        }
        if component["signature"] == "Valid" {
            signature(&path, &f)?
        }
        held.push(f);
    }
    let module = unsafe {
        LoadLibraryExW(
            wide(
                engine
                    .trusted
                    .home
                    .join("QSbieAPI.dll")
                    .to_str()
                    .ok_or("CLEANUP_PATH_INVALID")?,
            )
            .as_ptr(),
            ptr::null_mut(),
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32,
        )
    };
    if module.is_null() {
        return Err("CLEANUP_MODULE_UNAVAILABLE");
    }
    let module = Module(module);
    let export = unsafe {
        GetProcAddress(
            module.0,
            c"?NtIo_DeleteFolderRecursively@@YAJPEAU_OBJECT_ATTRIBUTES@@P6A_NPEB_WPEAX@Z2@Z"
                .as_ptr()
                .cast(),
        )
    }
    .ok_or("CLEANUP_EXPORT_UNAVAILABLE")?;
    Ok(Cleanup {
        _module: module,
        _held: held,
        delete: unsafe {
            std::mem::transmute::<unsafe extern "system" fn() -> isize, DeleteNative>(export)
        },
    })
}
unsafe extern "C" fn callback(_text: *const u16, state: *mut c_void) -> bool {
    // No upstream filename/error text is interpreted or retained.
    !state.is_null() && unsafe { &*(state as *const Instant) }.elapsed() < Duration::from_secs(30)
}
fn native_clear(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    ops: &mut contract::Journal,
    r: &mut Record,
) -> R<()> {
    let native = cleanup(engine)?;
    let mut seal = seal::Seal::capture(engine, e)?;
    if seal.snapshot.parent_identity != r.parent_identity {
        return Err("CLEANUP_PARENT_CHANGED");
    }
    let snapshot = serde_json::to_string(&seal.snapshot).map_err(|_| "CLEANUP_SNAPSHOT_INVALID")?;
    if r.snapshot.as_deref() != Some(&snapshot) {
        return Err("CLEANUP_SUPERVISOR_SNAPSHOT_CHANGED");
    }

    stage(ops, r, "SNAPSHOT_CAPTURED", "ORIGINAL_ACLS_RECORDED")?;
    checkpoint("SnapshotCaptured");
    engine.fence(e)?;
    engine.idle(&e.name())?;
    if scope(engine, e, std::slice::from_ref(e))? != r.scope {
        return Err("LIFECYCLE_CONFIGURATION_CHANGED");
    }
    stage(ops, r, "FENCED", "LAUNCH_DISABLED")?;
    checkpoint("Fenced");
    seal.freeze()?;
    seal.delegated_restore();
    stage(ops, r, "SEALED", "NAMESPACE_SEALED")?;
    checkpoint("Sealed");
    engine.mutation_context()?;
    engine.idle(&e.name())?;
    let raw = engine.section(&e.name(), false)?;
    if raw.get("Enabled") != Some(&vec!["n".into()])
        || verify_readback(
            &e.compiled,
            &raw,
            &engine.section(&e.name(), true)?,
            &engine.global()?,
        )? != r.scope
    {
        return Err("LIFECYCLE_CONFIGURATION_CHANGED");
    }
    stage(ops, r, "DISPATCH_RESERVED", "OUTCOME_UNKNOWN")?;
    checkpoint("DispatchReserved");
    let empty = [0u16];
    let mut name = NtName {
        length: 0,
        maximum: 2,
        buffer: empty.as_ptr() as _,
    };
    let mut attributes = NtAttributes {
        length: std::mem::size_of::<NtAttributes>() as u32,
        root: seal.root(),
        name: &mut name,
        flags: 0x40,
        security: ptr::null_mut(),
        qos: ptr::null_mut(),
    };
    let clock = Instant::now();
    // The controller retains metadata restoration handles for all survivors.
    // It closes only handles already marked delete-pending by this original ABI.
    // A bounded in-flight drain handles directories awaiting those final closes;
    // journal recovery never enters this loop or replays native dispatch.
    let status = loop {
        let status =
            unsafe { (native.delete)(&mut attributes, callback, &clock as *const _ as _) } as u32;
        if matches!(status, 0 | 0xc0000043) && seal.empty().is_ok() {
            break status;
        }
        if !matches!(status, 0xc0000043 | 0xc0000101 | 0xc0000056)
            || clock.elapsed() >= Duration::from_secs(30)
        {
            return Err("CLEANUP_NATIVE_STATUS_UNRESOLVED");
        }
        engine.mutation_context()?;
        engine.idle(&e.name())?;
        std::thread::sleep(Duration::from_millis(20));
    };
    checkpoint("NativeReturned");
    r.native_status = Some(status);
    if status != 0 && status != 0xc0000043 {
        return Err("CLEANUP_NATIVE_STATUS_UNRESOLVED");
    }
    seal.empty()?;
    engine.idle(&e.name())?;
    let _root = seal::sealed_root(engine, e)?;
    stage(ops, r, "CLEARED", "VERIFIED_EMPTY_RETAINED_ROOT")?;
    checkpoint("Cleared");
    Ok(())
}
fn commit(
    engine: &NativeEngine,
    j: &mut Journal,
    ops: &mut contract::Journal,
    operation_id: Uuid,
    plan_id: Uuid,
) -> R<()> {
    let mut r = ops
        .get(operation_id)?
        .ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
    if r.plan_id != plan_id {
        return Err("LIFECYCLE_CONFIRMATION_INVALID");
    }
    if r.stage != "PREPARED" {
        return Ok(());
    } // Never dispatch the operation twice.
    if contract::now().saturating_sub(r.created) > 60 {
        return Err("LIFECYCLE_CONFIRMATION_EXPIRED");
    }
    let mut e = j.get(r.environment_id)?;
    unchanged(engine, &e, &r)?;
    if e.lifecycle_operation.is_some() {
        return Err("LIFECYCLE_RECONCILIATION_REQUIRED");
    }
    if scope(engine, &e, &j.list()?)? != r.scope {
        return Err("LIFECYCLE_CONFIGURATION_CHANGED");
    }
    if !r.intent.destructive() {
        return finish_simple(engine, j, ops, &mut e, &mut r);
    }
    e.lifecycle_operation = Some(r.operation_id);
    j.save(&e)?;
    let result = (|| -> R<()> {
        native_clear(engine, &e, ops, &mut r)?;
        if r.intent == Action::Remove {
            engine.mutation_context()?;
            engine.idle(&e.name())?;
            if scope_sealed(engine, &e, &j.list()?)? != r.scope {
                return Err("LIFECYCLE_CONFIGURATION_CHANGED");
            }
            let update: Update = unsafe { bind(&engine.api, b"SbieDll_UpdateConf\0")? };
            if unsafe {
                update(
                    b's' as u16,
                    ptr::null(),
                    wide(&e.name()).as_ptr(),
                    wide("*").as_ptr(),
                    ptr::null(),
                )
            } != 0
            {
                return Err("REMOVE_DEFINITION_FAILED");
            }
            engine.reload()?;
            if engine.exists(&e.name())? {
                return Err("REMOVE_DEFINITION_STILL_PRESENT");
            }
            stage(
                ops,
                &mut r,
                "DEFINITION_REMOVED",
                "KNOWN_EMPTY_ROOT_RETAINED",
            )?;
            checkpoint("DefinitionRemoved");
            control_reconciled(engine, e.id)?;
            crate::control::Journal::open(
                &engine.profile.join("metadata/control.sqlite"),
                &engine.owner,
            )?
            .remove_applications(e.id)?;
            j.remove(e.id)?;
        } else {
            e.generation = e
                .generation
                .checked_add(1)
                .ok_or("ENVIRONMENT_GENERATION_EXHAUSTED")?;
            e.disposable_pending = false;
            e.reason = "RESET_AWAITING_CONTROLLER_RESTORE".into();
            j.save(&e)?;
            control_reconciled(engine, e.id)?;
        }
        checkpoint("MetadataCommitted");
        stage(
            ops,
            &mut r,
            "AWAITING_CONTROLLER_RESTORE",
            "SEALED_RETENTION_POSTCONDITIONS_VERIFIED",
        )
    })();
    if let Err(reason) = result {
        r.reason = reason.into();
        r.updated = contract::now();
        ops.save(&r)?;
        return Err(reason);
    }
    Ok(())
}
fn recover(engine: &NativeEngine, j: &mut Journal, ops: &mut contract::Journal, id: Uuid) -> R<()> {
    let mut r = ops.get(id)?.ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
    if matches!(
        r.stage.as_str(),
        "COMPLETE"
            | "COMPLETE_RECOVERED"
            | "INTERRUPTED_RETAINED_ARCHIVED"
            | "EXPIRED_UNDISPATCHED"
    ) {
        return Ok(());
    }
    if r.owner != engine.owner || r.engine != engine.engine_identity() {
        return Err("LIFECYCLE_OWNERSHIP_CHANGED");
    }
    let e = j.get(r.environment_id);
    if r.intent == Action::Remove
        && matches!(
            r.stage.as_str(),
            "CLEARED" | "DEFINITION_REMOVED" | "AWAITING_CONTROLLER_RESTORE"
        )
        && !engine.exists(&format!("SR_{}", r.environment_id.simple()))?
    {
        let path = PathBuf::from(engine.root_for(r.environment_id));
        let held = canonical_validated(&path, FILE_SHARE_READ | FILE_SHARE_WRITE, true)?;
        if identity(held.last().ok_or("CLEANUP_ROOT_UNKNOWN")?)? != r.root_identity
            || identity(held.get(held.len() - 2).ok_or("CLEANUP_PARENT_UNKNOWN")?)?
                != r.parent_identity
        {
            return Err("CLEANUP_RECOVERY_IDENTITY_CHANGED");
        }
        private(held.last().unwrap(), &engine.owner)?;
        if std::fs::read_dir(&path)
            .map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?
            .next()
            .is_some()
        {
            return Err("CLEANUP_CONTENTS_REMAIN");
        }
        if let Ok(e) = e {
            if e.lifecycle_operation != Some(id) || e.generation != r.generation {
                return Err("STALE_LIFECYCLE_OPERATION");
            };
            j.remove(e.id)?
        }
        control_reconciled(engine, r.environment_id)?;
        crate::control::Journal::open(
            &engine.profile.join("metadata/control.sqlite"),
            &engine.owner,
        )?
        .remove_applications(r.environment_id)?;
        return stage(
            ops,
            &mut r,
            "COMPLETE_RECOVERED",
            "DEFINITION_ABSENT_EMPTY_IDENTITY_VERIFIED",
        );
    }
    let mut e = e?;
    if e.generation == r.generation + 1
        && (e.lifecycle_operation.is_none() || e.lifecycle_operation == Some(id))
        && r.intent == Action::Reset
        && matches!(r.stage.as_str(), "CLEARED" | "AWAITING_CONTROLLER_RESTORE")
    {
        let _scope = engine.control_scope(&e)?;
        engine.idle(&e.name())?;
        if std::fs::read_dir(engine.root_for(e.id))
            .map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?
            .next()
            .is_some()
        {
            return Err("CLEANUP_CONTENTS_REMAIN");
        }
        e.lifecycle_operation = None;
        j.save(&e)?;
        return stage(
            ops,
            &mut r,
            "COMPLETE_RECOVERED",
            "RESET_GENERATION_ALREADY_COMMITTED",
        );
    }
    unchanged(engine, &e, &r)?;
    engine.idle(&e.name())?;
    let policy_matches = scope(engine, &e, &j.list()?).is_ok_and(|current| current == r.scope);
    if r.stage == "PREPARED" && e.lifecycle_operation != Some(id) {
        return stage(ops, &mut r, "EXPIRED_UNDISPATCHED", "NO_MUTATION_REPLAYED");
    }
    if !r.intent.destructive() {
        let matches = match r.intent {
            Action::Archive => e.lifecycle == State::Archived,
            Action::Unarchive => e.lifecycle == State::Active,
            Action::Persistent => e.mode == Mode::Persistent,
            Action::Disposable => e.mode == Mode::Disposable,
            Action::Resume => !e.disposable_pending,
            _ => false,
        };
        return stage(
            ops,
            &mut r,
            if matches {
                "COMPLETE_RECOVERED"
            } else {
                "EXPIRED_UNDISPATCHED"
            },
            "METADATA_OBSERVED_WITHOUT_REPLAY",
        );
    }
    if e.lifecycle_operation != Some(id) {
        return Err("LIFECYCLE_OPERATION_BINDING_CHANGED");
    }
    let empty = std::fs::read_dir(engine.root_for(e.id))
        .map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?
        .next()
        .is_none();
    if r.stage == "CLEARED"
        && r.intent == Action::Reset
        && policy_matches
        && empty
        && matches!(r.native_status, Some(0 | 0xc0000043))
    {
        e.generation = e
            .generation
            .checked_add(1)
            .ok_or("ENVIRONMENT_GENERATION_EXHAUSTED")?;
        e.lifecycle_operation = None;
        e.disposable_pending = false;
        j.save(&e)?;
        control_reconciled(engine, e.id)?;
        return stage(
            ops,
            &mut r,
            "COMPLETE_RECOVERED",
            "KNOWN_CLEANUP_EMPTY_ROOT_VERIFIED",
        );
    }
    // No irreversible retry: preserve possibly partial data, invalidate references
    // and require a fresh explicit intent before any further cleanup or launch.
    // Root identity/private ACL and complete idle were checked above. Do not
    // traverse retained contents or repair external configuration during inspect.
    e.generation = e
        .generation
        .checked_add(1)
        .ok_or("ENVIRONMENT_GENERATION_EXHAUSTED")?;
    e.lifecycle_operation = None;
    e.lifecycle = State::Archived;
    j.save(&e)?;
    control_reconciled(engine, e.id)?;
    stage(
        ops,
        &mut r,
        "INTERRUPTED_RETAINED_ARCHIVED",
        "PARTIAL_DATA_RETAINED_NO_REPLAY",
    )
}
pub fn execute(
    manager_pid: u32,
    manager_birth: u64,
    request: contract::Request,
) -> contract::Reply {
    let mut reply = contract::Reply::failure("NOT_OBSERVED");
    let result = (|| -> R<()> {
        let engine = NativeEngine::new(manager_pid, manager_birth)?;
        let _lock = lock(&engine)?;
        let (mut j, mut ops) = journals(&engine)?;
        match &request {
            contract::Request::List => {}
            contract::Request::Prepare { .. } => {
                reply.plan = Some(prepare(&engine, &mut j, &mut ops, &request)?)
            }
            contract::Request::Commit {
                operation_id,
                plan_id,
            } => commit(&engine, &mut j, &mut ops, *operation_id, *plan_id)?,
            contract::Request::Recover { operation_id } => {
                recover(&engine, &mut j, &mut ops, *operation_id)?
            }
            contract::Request::Cancel {
                operation_id,
                plan_id,
            } => {
                let mut record = ops
                    .get(*operation_id)?
                    .ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
                if record.plan_id != *plan_id {
                    return Err("LIFECYCLE_CONFIRMATION_INVALID");
                }
                if record.stage == "PREPARED" {
                    stage(
                        &mut ops,
                        &mut record,
                        "CANCELLED_UNDISPATCHED",
                        "NATIVE_CONFIRMATION_CANCELLED",
                    )?;
                }
            }
        }
        for e in j.list()? {
            let observation = engine
                .control_scope(&e)
                .and_then(|_scope| engine.api.processes(&e.name()));
            let (activity, complete, reason) = match observation {
                Ok(p) => (
                    if e.lifecycle_operation.is_some() {
                        "CLEANING"
                    } else if p.is_empty() {
                        "IDLE"
                    } else {
                        "RUNNING"
                    },
                    true,
                    "OBSERVED",
                ),
                Err(reason) => ("UNKNOWN", false, reason),
            };
            reply.environments.push(contract::EnvironmentView {
                environment_id: e.id,
                display_name: e.display_name,
                revision: e.revision,
                generation: e.generation,
                lifecycle: e.lifecycle,
                mode: e.mode,
                disposable_pending: e.disposable_pending,
                activity: activity.into(),
                complete,
                reason: reason.into(),
                pending_operation: e.lifecycle_operation,
            });
        }
        reply.operations = ops.views()?;
        Ok(())
    })();
    reply.reason = result.err().unwrap_or("OBSERVED").into();
    reply
}
fn command(mode: &str, pid: u32, birth: u64) -> R<Command> {
    let exe = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
    let windows = system_directory()?;
    let mut c = Command::new(exe);
    c.args([mode.into(), pid.to_string(), birth.to_string()])
        .current_dir(&windows)
        .env_clear()
        .env("SystemRoot", windows.parent().ok_or("SYSTEM_PATH_UNKNOWN")?)
        .env("WINDIR", windows.parent().unwrap())
        .env("PATH", &windows)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .creation_flags(CREATE_NO_WINDOW);
    #[cfg(feature = "policy-ci")]
    for key in ["GITHUB_ACTIONS", "SECURERUN_P08_PAUSE_STAGE"] {
        if let Ok(value) = std::env::var(key) {
            c.env(key, value);
        }
    }
    Ok(c)
}
struct HeldExecutor(std::process::Child);
impl std::ops::Deref for HeldExecutor {
    type Target = std::process::Child;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
impl std::ops::DerefMut for HeldExecutor {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}
impl Drop for HeldExecutor {
    fn drop(&mut self) {
        // This guard is declared after restoration authority. Every error path
        // waits for the exact executor before any seal can unwind and restore.
        if !matches!(self.0.try_wait(), Ok(Some(_))) {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }
}
#[cfg(feature = "policy-ci")]
fn original_fenced_dispatch(engine: &NativeEngine, environment: Uuid) -> R<bool> {
    let probe = lease(&engine.probe, false)?;
    protected(&probe)?;
    let run: Run = unsafe { bind(&engine.api, b"SbieDll_RunSandboxed\0")? };
    let mut startup = unsafe { std::mem::zeroed::<STARTUPINFOW>() };
    startup.cb = std::mem::size_of_val(&startup) as u32;
    let mut process = unsafe { std::mem::zeroed::<PROCESS_INFORMATION>() };
    let rejected = unsafe {
        run(
            wide(&format!("SR_{}", environment.simple())).as_ptr(),
            wide(&crate::control::command(
                engine.probe.to_str().ok_or("PROBE_PATH_INVALID")?,
                &[],
            )?)
            .as_ptr(),
            wide(system_directory()?.to_str().ok_or("SYSTEM_PATH_UNKNOWN")?).as_ptr(),
            CREATE_SUSPENDED | CREATE_NO_WINDOW,
            &mut startup,
            &mut process,
        )
    } == 0;
    // Never resume a surprising successful dispatch; use only returned handles.
    if !process.hThread.is_null() {
        drop(Handle(process.hThread));
    }
    if !process.hProcess.is_null() {
        let held = Handle(process.hProcess);
        if unsafe { TerminateProcess(held.0, 1) } == 0
            || unsafe { WaitForSingleObject(held.0, 10000) } != WAIT_OBJECT_0
        {
            return Err("LIFECYCLE_TEST_UNEXPECTED_DISPATCH_UNRESOLVED");
        }
    }
    Ok(rejected)
}
/// Independent unboxed controller. Its root restoration authority outlives the
/// destructive executor and the UI; no elevation or target execution is exposed.
pub fn supervise(parent: u32, birth: u64, request: contract::Request) -> contract::Reply {
    let result = (|| -> R<contract::Reply> {
        let engine = NativeEngine::new(parent, birth)?;
        let mut restoration = None;
        if let contract::Request::Commit {
            operation_id,
            plan_id,
        } = &request
        {
            let _lock = lock(&engine)?;
            let (j, mut ops) = journals(&engine)?;
            let mut r = ops
                .get(*operation_id)?
                .ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
            if r.plan_id != *plan_id {
                return Err("LIFECYCLE_CONFIRMATION_INVALID");
            }
            if r.intent.destructive() && r.stage == "PREPARED" {
                let e = j.get(r.environment_id)?;
                unchanged(&engine, &e, &r)?;
                scope(&engine, &e, &j.list()?)?;
                let mut seal = seal::Seal::capture(&engine, &e)?;
                r.snapshot = Some(
                    serde_json::to_string(&seal.snapshot)
                        .map_err(|_| "CLEANUP_SNAPSHOT_INVALID")?,
                );
                ops.save(&r)?;
                seal.enable_supervision();
                restoration = Some(seal);
            }
        }
        let pid = unsafe { GetCurrentProcessId() };
        let born = process_birth(pid)?;
        let mut child = HeldExecutor(
            command("--lifecycle-worker", pid, born)?
                .spawn()
                .map_err(|_| "LIFECYCLE_EXECUTOR_START_FAILED")?,
        );
        let job_raw = unsafe { CreateJobObjectW(ptr::null(), ptr::null()) };
        if job_raw.is_null() {
            let _ = child.kill();
            let _ = child.wait();
            return Err("LIFECYCLE_EXECUTOR_JOB_UNAVAILABLE");
        }
        let job = Handle(job_raw);
        let mut limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            | JOB_OBJECT_LIMIT_PROCESS_MEMORY
            | JOB_OBJECT_LIMIT_ACTIVE_PROCESS;
        limits.BasicLimitInformation.ActiveProcessLimit = 1;
        limits.ProcessMemoryLimit = 128 * 1024 * 1024;
        if unsafe {
            SetInformationJobObject(
                job.0,
                JobObjectExtendedLimitInformation,
                &limits as *const _ as _,
                std::mem::size_of_val(&limits) as u32,
            )
        } == 0
            || unsafe { AssignProcessToJobObject(job.0, child.as_raw_handle()) } == 0
        {
            let _ = child.kill();
            let _ = child.wait();
            return Err("LIFECYCLE_EXECUTOR_JOB_UNAVAILABLE");
        }
        let data = serde_json::to_vec(&request).map_err(|_| "LIFECYCLE_REQUEST_INVALID")?;
        child
            .stdin
            .take()
            .ok_or("LIFECYCLE_PIPE_UNAVAILABLE")?
            .write_all(&data)
            .map_err(|_| "LIFECYCLE_PIPE_UNAVAILABLE")?;
        let stdout = child.stdout.take().ok_or("LIFECYCLE_PIPE_UNAVAILABLE")?;
        let (tx, rx) = std::sync::mpsc::sync_channel(4);
        let reader = std::thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut line = String::new();
                match reader
                    .by_ref()
                    .take(2 * 1024 * 1024 + 1)
                    .read_line(&mut line)
                {
                    Ok(0) => break,
                    Ok(_) => {
                        if tx.send(line).is_err() {
                            break;
                        }
                    }
                    Err(_) => break,
                }
            }
        });
        let clock = Instant::now();
        let mut output = None;
        let mut interrupted = false;
        #[cfg(feature = "policy-ci")]
        let mut observed_checkpoint = None;
        #[cfg(feature = "policy-ci")]
        let mut competing_manager_refused = false;
        #[cfg(feature = "policy-ci")]
        let mut external_original_dispatch_rejected = None;
        while clock.elapsed() < Duration::from_secs(180) {
            if let Some(seal) = &mut restoration {
                seal.reap_deleted()?;
            }
            if let Ok(line) = rx.recv_timeout(Duration::from_millis(50)) {
                if line.len() > 2 * 1024 * 1024 {
                    break;
                }
                if line.starts_with("CHECKPOINT_") {
                    #[cfg(feature = "policy-ci")]
                    if std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true") {
                        let stage = line.trim().strip_prefix("CHECKPOINT_").unwrap_or_default();
                        if std::env::var("SECURERUN_P08_PAUSE_STAGE").as_deref() != Ok(stage) {
                            return Err("LIFECYCLE_TEST_CHECKPOINT_MISMATCH");
                        }
                        observed_checkpoint = Some(stage.to_owned());
                        competing_manager_refused = bounded_request(&contract::Request::List)
                            .reason
                            == "NAMESPACE_OPERATION_BUSY";
                        if matches!(stage, "Fenced" | "Sealed" | "DispatchReserved")
                            && let contract::Request::Commit { operation_id, .. } = &request
                        {
                            let (_, ops) = journals(&engine)?;
                            let record = ops
                                .get(*operation_id)?
                                .ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
                            external_original_dispatch_rejected =
                                Some(original_fenced_dispatch(&engine, record.environment_id)?);
                        }
                        child.kill().map_err(|_| "LIFECYCLE_TEST_KILL_FAILED")?;
                        interrupted = true;
                    }
                } else {
                    output = Some(line)
                }
            }
            if child
                .try_wait()
                .map_err(|_| "LIFECYCLE_EXECUTOR_WAIT_UNKNOWN")?
                .is_some()
            {
                break;
            }
        }
        if child
            .try_wait()
            .map_err(|_| "LIFECYCLE_EXECUTOR_WAIT_UNKNOWN")?
            .is_none()
        {
            child
                .kill()
                .map_err(|_| "LIFECYCLE_EXECUTOR_WAIT_UNKNOWN")?;
            interrupted = true
        }
        child
            .wait()
            .map_err(|_| "LIFECYCLE_EXECUTOR_WAIT_UNKNOWN")?;
        // Drain the bounded framing reader only after the held executor exits.
        let _ = reader.join();
        for line in rx.try_iter() {
            if !line.starts_with("CHECKPOINT_") {
                output = Some(line)
            }
        }
        if let Some(mut seal) = restoration {
            seal.restore()?;
        }
        #[cfg(feature = "policy-ci")]
        if interrupted
            && std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true")
            && let Some(checkpoint) = observed_checkpoint
            && let contract::Request::Commit { operation_id, .. } = &request
        {
            let proof = serde_json::json!({"real_executor_killed":true,"held_exit_wait_completed":true,"controller_restored_known_acl":true,"checkpoint":checkpoint,"competing_manager_refused":competing_manager_refused,"external_original_dispatch_rejected":external_original_dispatch_rejected,"product_privileged_helper":false});
            let path = engine
                .profile
                .join("metadata")
                .join(format!("lifecycle-kill-{operation_id}.json"));
            let mut f = OpenOptions::new()
                .create_new(true)
                .write(true)
                .share_mode(0)
                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                .open(path)
                .map_err(|_| "LIFECYCLE_TEST_PROOF_UNAVAILABLE")?;
            f.write_all(
                &serde_json::to_vec(&proof).map_err(|_| "LIFECYCLE_TEST_PROOF_UNAVAILABLE")?,
            )
            .map_err(|_| "LIFECYCLE_TEST_PROOF_UNAVAILABLE")?;
            f.sync_all()
                .map_err(|_| "LIFECYCLE_TEST_PROOF_UNAVAILABLE")?;
        }
        if interrupted {
            return Ok(contract::Reply::failure(
                "LIFECYCLE_EXECUTOR_INTERRUPTED_RECHECK_REQUIRED",
            ));
        }
        let mut reply: contract::Reply =
            serde_json::from_str(&output.ok_or("LIFECYCLE_EXECUTOR_OUTCOME_UNKNOWN")?)
                .map_err(|_| "LIFECYCLE_RESPONSE_INVALID")?;
        if reply.reason == "OBSERVED"
            && let contract::Request::Commit { operation_id, .. } = &request
        {
            let _lock = lock(&engine)?;
            let (mut j, mut ops) = journals(&engine)?;
            let mut r = ops
                .get(*operation_id)?
                .ok_or("LIFECYCLE_OPERATION_NOT_FOUND")?;
            if r.stage == "AWAITING_CONTROLLER_RESTORE" {
                if r.intent == Action::Reset {
                    let mut e = j.get(r.environment_id)?;
                    if e.generation != r.generation + 1
                        || e.lifecycle_operation != Some(*operation_id)
                    {
                        return Err("STALE_LIFECYCLE_OPERATION");
                    }
                    scope(&engine, &e, &j.list()?)?;
                    e.lifecycle_operation = None;
                    e.reason = "RESET_COMPLETE".into();
                    j.save(&e)?;
                    for view in &mut reply.environments {
                        if view.environment_id == e.id {
                            view.pending_operation = None;
                            view.activity = "IDLE".into();
                            view.complete = true;
                            view.reason = "OBSERVED".into();
                        }
                    }
                }
                stage(
                    &mut ops,
                    &mut r,
                    "COMPLETE",
                    "CONTROLLER_RESTORED_RETENTION_VERIFIED",
                )?;
                reply.operations = ops.views()?;
            }
        }
        Ok(reply)
    })();
    result.unwrap_or_else(contract::Reply::failure)
}
pub fn bounded_request(request: &contract::Request) -> contract::Reply {
    let result = (|| -> R<contract::Reply> {
        let pid = unsafe { GetCurrentProcessId() };
        let birth = process_birth(pid)?;
        let data = serde_json::to_vec(request).map_err(|_| "LIFECYCLE_REQUEST_INVALID")?;
        if data.len() > 16384 {
            return Err("LIFECYCLE_REQUEST_BOUND");
        }
        // No kill-on-close job: a dispatched cleanup controller must retain its
        // restoration handle if the UI exits. The controller bounds its child.
        let mut child = command("--lifecycle-supervisor", pid, birth)?
            .spawn()
            .map_err(|_| "LIFECYCLE_SUPERVISOR_START_FAILED")?;
        child
            .stdin
            .take()
            .ok_or("LIFECYCLE_PIPE_UNAVAILABLE")?
            .write_all(&data)
            .map_err(|_| "LIFECYCLE_PIPE_UNAVAILABLE")?;
        let stdout = child.stdout.take().ok_or("LIFECYCLE_PIPE_UNAVAILABLE")?;
        let (tx, rx) = std::sync::mpsc::sync_channel(1);
        std::thread::spawn(move || {
            let mut bytes = vec![];
            let result = stdout.take(2 * 1024 * 1024 + 1).read_to_end(&mut bytes);
            let _ = tx.send((result, bytes));
        });
        let (read, bytes) = rx
            .recv_timeout(Duration::from_secs(200))
            .map_err(|_| "LIFECYCLE_CONTROLLER_OUTCOME_UNKNOWN")?;
        if read.is_err() || bytes.len() > 2 * 1024 * 1024 {
            return Err("LIFECYCLE_RESPONSE_BOUND");
        }
        let reply: contract::Reply =
            serde_json::from_slice(&bytes).map_err(|_| "LIFECYCLE_RESPONSE_INVALID")?;
        if reply.protocol != 1 || reply.environments.len() > 12 || reply.operations.len() > 64 {
            return Err("LIFECYCLE_RESPONSE_INVALID");
        };
        Ok(reply)
    })();
    result.unwrap_or_else(contract::Reply::failure)
}
