use crate::native;
use securerun_foundation::{binding::*, *};
use securerun_sandboxie_adapter::{Health, HealthView};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs::File, sync::Mutex, time::Instant};
use tauri::{Manager, State, WebviewWindow};
use uuid::Uuid;

#[derive(Serialize)]
pub struct EnvironmentView {
    id: Uuid,
    display_name: String,
    generation: u64,
    desired_revision: u64,
    verified_revision: Option<u64>,
    lifecycle: Lifecycle,
    activity: Activity,
    eligibility: Eligibility,
    current_operation: Option<Uuid>,
    last_sequence: u64,
}
impl From<Environment> for EnvironmentView {
    fn from(e: Environment) -> Self {
        Self {
            id: e.id,
            display_name: e.display_name,
            generation: e.generation,
            desired_revision: e.desired_revision,
            verified_revision: e.verified_revision,
            lifecycle: e.lifecycle,
            activity: e.activity,
            eligibility: e.eligibility,
            current_operation: e.current_operation,
            last_sequence: e.last_sequence,
        }
    }
}
#[derive(Serialize)]
pub struct Snapshot {
    pub engine_generation: u64,
    pub sequence: u64,
    pub environments: Vec<EnvironmentView>,
    pub mode: &'static str,
    pub mutations_available: bool,
    pub engine_operations_available: bool,
    pub reason: ErrorCode,
}
#[derive(Serialize)]
pub struct OperationView {
    id: Uuid,
    idempotency_key: Uuid,
    environment_id: Uuid,
    environment_generation: u64,
    requested_revision: u64,
    kind: OperationKind,
    dispatch_state: DispatchState,
    phase: OperationPhase,
    error: Option<ErrorCode>,
    recovery_action: RecoveryAction,
}
impl From<Operation> for OperationView {
    fn from(op: Operation) -> Self {
        Self {
            id: op.id,
            idempotency_key: op.idempotency_key,
            environment_id: op.environment_id,
            environment_generation: op.environment_generation,
            requested_revision: op.requested_revision,
            kind: op.kind,
            dispatch_state: op.dispatch_state,
            phase: op.phase,
            error: op.error,
            recovery_action: op.recovery_action,
        }
    }
}
pub struct Backend {
    pub health: Health,
    pub observation_inflight: bool,
    pub state_channels: HashMap<Uuid, tauri::ipc::Channel<StateEvent>>,
    pub store: Store,
    pub selections: Selections,
    pub handles: HashMap<Uuid, native::SelectionLease>,
    pub started: Instant,
    pub session: u32,
    pub fixture: bool,
    pub profile: Option<std::path::PathBuf>,
    pub _writer: Option<File>,
}
pub struct AppState(pub Mutex<Backend>);
impl Backend {
    fn allow_metadata(&self) -> Result<()> {
        // P04 supplies trusted self-context. No renderer can set or override this gate.
        if !self.fixture {
            return err(ErrorCode::ManagerContextUnsafe);
        }
        Ok(())
    }
    fn snapshot(&self) -> Result<Snapshot> {
        Ok(Snapshot {
            engine_generation: self.store.engine_generation()?,
            sequence: self.store.sequence()?,
            environments: self
                .store
                .environments()?
                .into_iter()
                .map(Into::into)
                .collect(),
            mode: if self.fixture {
                "FOUNDATION_TEST_FIXTURE"
            } else {
                "READ_ONLY_SETUP"
            },
            mutations_available: self.fixture,
            engine_operations_available: false,
            reason: ErrorCode::CapabilityUnavailable,
        })
    }
    fn prune_selections(&mut self) {
        for id in self.selections.prune(self.started.elapsed().as_secs()) {
            self.handles.remove(&id);
        }
    }
    fn flush_diagnostics(&self) -> Result<()> {
        if let Some(profile) = &self.profile {
            let data = serde_json::to_vec(&self.store.diagnostics()?)
                .map_err(|_| AppError::new(ErrorCode::CorruptRecord))?;
            if data.len() > 1024 * 1024 {
                return err(ErrorCode::InvalidInput);
            }
            std::fs::write(profile.join("local-diagnostics.json"), data)
                .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
        }
        Ok(())
    }
}
fn authorize(window: &WebviewWindow) -> Result<()> {
    let url = window
        .url()
        .map_err(|_| AppError::new(ErrorCode::Unauthorized))?;
    if !authorized_origin(window.label(), url.as_str(), cfg!(debug_assertions)) {
        return err(ErrorCode::Unauthorized);
    }
    Ok(())
}
fn locked<'a>(
    window: &WebviewWindow,
    state: &'a State<AppState>,
) -> Result<std::sync::MutexGuard<'a, Backend>> {
    authorize(window)?;
    state
        .inner()
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DraftRequest {
    display_name: String,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OperationReference {
    operation_id: Uuid,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SelectRequest {
    operation_id: Uuid,
    purpose: SelectionPurpose,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PrepareRequest {
    operation_id: Uuid,
    selection_id: Uuid,
    purpose: SelectionPurpose,
}
#[derive(Serialize)]
pub struct SelectionView {
    selection_id: Uuid,
    display_name: String,
    expires_in_seconds: u64,
}

#[tauri::command]
fn get_snapshot(window: WebviewWindow, state: State<AppState>) -> Result<Snapshot> {
    locked(&window, &state)?.snapshot()
}
#[tauri::command]
async fn get_engine_health(
    window: WebviewWindow,
    state: State<'_, AppState>,
) -> Result<HealthView> {
    let ticket = {
        let mut backend = locked(&window, &state)?;
        if backend.fixture || backend.observation_inflight {
            return Ok(backend.health.view(Instant::now()));
        }
        backend.observation_inflight = true;
        let before = backend.health.view(Instant::now()).generation;
        let ticket = backend.health.begin(Instant::now());
        if backend.health.view(Instant::now()).generation != before {
            backend.store.reconnect()?;
            backend.handles.clear();
            backend.selections = Selections::default();
        }
        ticket
    };
    let observation =
        tauri::async_runtime::spawn_blocking(securerun_sandboxie_adapter::windows::bounded_observe)
            .await
            .unwrap_or_else(|_| {
                securerun_sandboxie_adapter::Observation::failure("BRIDGE_TASK_FAILED")
            });
    let mut backend = locked(&window, &state)?;
    backend.observation_inflight = false;
    let before = backend.health.view(Instant::now()).generation;
    backend.health.accept(ticket, observation, Instant::now());
    let view = backend.health.view(Instant::now());
    if view.generation != before {
        backend.store.reconnect()?;
        backend.handles.clear();
        backend.selections = Selections::default();
    }
    Ok(view)
}
#[derive(Serialize)]
pub struct SubscriptionView {
    id: Uuid,
    snapshot: Snapshot,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SubscriptionReference {
    subscription_id: Uuid,
}
#[tauri::command]
fn subscribe_state(
    window: WebviewWindow,
    state: State<AppState>,
    channel: tauri::ipc::Channel<StateEvent>,
) -> Result<SubscriptionView> {
    let mut backend = locked(&window, &state)?;
    if backend.state_channels.len() >= 4 {
        return err(ErrorCode::CapabilityUnavailable);
    }
    let id = Uuid::new_v4();
    backend.state_channels.insert(id, channel);
    Ok(SubscriptionView {
        id,
        snapshot: backend.snapshot()?,
    })
}
#[tauri::command]
fn unsubscribe_state(
    window: WebviewWindow,
    state: State<AppState>,
    request: SubscriptionReference,
) -> Result<()> {
    let mut backend = locked(&window, &state)?;
    if backend
        .state_channels
        .remove(&request.subscription_id)
        .is_none()
    {
        return err(ErrorCode::Unauthorized);
    }
    Ok(())
}
#[tauri::command]
fn create_draft(
    window: WebviewWindow,
    state: State<AppState>,
    request: DraftRequest,
) -> Result<EnvironmentView> {
    let mut backend = locked(&window, &state)?;
    backend.allow_metadata()?;
    let env = backend.store.create_draft(&request.display_name)?;
    let event = backend
        .store
        .next_event(env.id, env.generation, env.desired_revision)?;
    let env = backend
        .store
        .environment(env.id, env.generation, env.desired_revision)?;
    backend
        .state_channels
        .retain(|_, channel| channel.send(event.clone()).is_ok());
    backend.flush_diagnostics()?;
    Ok(env.into())
}
#[tauri::command]
fn reserve_operation(
    window: WebviewWindow,
    state: State<AppState>,
    request: ReservationRequest,
) -> Result<OperationView> {
    let mut backend = locked(&window, &state)?;
    backend.allow_metadata()?;
    if !matches!(request.kind, OperationKind::Import | OperationKind::Export) {
        return err(ErrorCode::CapabilityUnavailable);
    }
    let session = backend.session;
    let (operation, _) = backend.store.reserve(&request, session)?;
    backend.flush_diagnostics()?;
    Ok(operation.into())
}
#[tauri::command]
async fn select_file(
    window: WebviewWindow,
    state: State<'_, AppState>,
    request: SelectRequest,
) -> Result<Option<SelectionView>> {
    let fixture_profile = {
        let backend = locked(&window, &state)?;
        backend.allow_metadata()?;
        let op = backend.store.operation(request.operation_id)?;
        let expected = match request.purpose {
            SelectionPurpose::Import => OperationKind::Import,
            SelectionPurpose::Export => OperationKind::Export,
        };
        if op.kind != expected || op.dispatch_state != DispatchState::Reserved {
            return err(ErrorCode::SelectionScopeMismatch);
        }
        backend.profile.clone()
    };
    let purpose = request.purpose;
    let chosen = tauri::async_runtime::spawn_blocking(move || {
        let mut dialog = rfd::FileDialog::new().set_title("SecureRun file selection");
        if let Some(profile) = fixture_profile {
            dialog = dialog
                .set_title("SecureRun selection fixture")
                .set_directory(&profile)
                .set_file_name("selection.txt");
            #[cfg(feature = "foundation-ci")]
            native::accept_fixture_picker();
        }
        match purpose {
            SelectionPurpose::Import => dialog.pick_file(),
            SelectionPurpose::Export => dialog.pick_folder(),
        }
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
    let Some(path) = chosen else { return Ok(None) };
    let display_name = validate_name(
        &path
            .file_name()
            .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?
            .to_string_lossy(),
    )?;
    let lease = native::capture(&path)?;
    // Re-authorize after the asynchronous picker: stale operations cannot reuse it.
    let mut backend = locked(&window, &state)?;
    backend.allow_metadata()?;
    let op = backend.store.operation(request.operation_id)?;
    if op.dispatch_state != DispatchState::Reserved {
        return err(ErrorCode::StaleOperation);
    }
    let id = Uuid::new_v4();
    let now = backend.started.elapsed().as_secs();
    backend.prune_selections();
    backend.selections.insert(BoundSelection {
        id,
        operation_id: op.id,
        environment_id: op.environment_id,
        generation: op.environment_generation,
        revision: op.requested_revision,
        purpose,
        caller_label: window.label().to_owned(),
        expires_at: now + 60,
        path,
        identity: lease.identity.clone(),
    })?;
    backend.handles.insert(id, lease);
    backend.store.audit(AuditCode::SelectionBound)?;
    backend.flush_diagnostics()?;
    Ok(Some(SelectionView {
        selection_id: id,
        display_name,
        expires_in_seconds: 60,
    }))
}
#[tauri::command]
fn prepare_transfer(
    window: WebviewWindow,
    state: State<AppState>,
    request: PrepareRequest,
) -> Result<()> {
    let mut backend = locked(&window, &state)?;
    backend.allow_metadata()?;
    let op = backend.store.operation(request.operation_id)?;
    let now = backend.started.elapsed().as_secs();
    backend.prune_selections();
    let item = backend.selections.consume(
        request.selection_id,
        &op,
        request.purpose,
        window.label(),
        now,
    )?;
    let lease = backend
        .handles
        .remove(&item.id)
        .ok_or_else(|| AppError::new(ErrorCode::SelectionScopeMismatch))?;
    if native::identify(&lease.file)? != item.identity {
        return err(ErrorCode::IdentityMismatch);
    }
    for parent in &lease.parents {
        native::identify(parent)?;
    }
    // Selection authority is implemented; copying/launching is owned by P07/P06.
    err(ErrorCode::CapabilityUnavailable)
}
#[tauri::command]
fn get_operation(
    window: WebviewWindow,
    state: State<AppState>,
    request: OperationReference,
) -> Result<OperationView> {
    let backend = locked(&window, &state)?;
    backend
        .store
        .operation(request.operation_id)
        .map(Into::into)
}
#[tauri::command]
fn diagnostic_summary(window: WebviewWindow, state: State<AppState>) -> Result<Vec<AuditEntry>> {
    locked(&window, &state)?.store.diagnostics()
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct CiCase {
    pub id: String,
    pub name: String,
    pub passed: bool,
}
#[tauri::command]
async fn ci_report(
    window: WebviewWindow,
    state: State<'_, AppState>,
    cases: Vec<CiCase>,
) -> Result<()> {
    authorize(&window)?;
    #[cfg(feature = "foundation-ci")]
    {
        let profile = {
            let backend = locked(&window, &state)?;
            if !backend.fixture
                || cases.len() > 32
                || cases.iter().any(|c| {
                    c.id.len() > 8
                        || c.name.len() > 80
                        || c.name
                            .chars()
                            .any(|v| !v.is_ascii_alphanumeric() && v != '_')
                })
            {
                return err(ErrorCode::Unauthorized);
            }
            backend.flush_diagnostics()?;
            backend
                .profile
                .clone()
                .ok_or_else(|| AppError::new(ErrorCode::Unauthorized))?
        };
        let app = window.app_handle().clone();
        tauri::async_runtime::spawn_blocking(move || crate::ci::finish(&app, &profile, cases))
            .await
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))??;
        Ok(())
    }
    #[cfg(not(feature = "foundation-ci"))]
    {
        let _ = (state, cases);
        err(ErrorCode::Unauthorized)
    }
}

pub fn run() {
    std::panic::set_hook(Box::new(|_| eprintln!("MANAGER_INTERNAL_ERROR")));
    // Missing engine context never opens/migrates the persistent production profile.
    let owner = match native::current_sid() {
        Ok(v) => v,
        Err(_) => {
            return;
        }
    };
    let session = match native::session() {
        Ok(v) => v,
        Err(_) => {
            return;
        }
    };
    #[cfg(feature = "foundation-ci")]
    let (profile, fixture, writer): (Option<std::path::PathBuf>, bool, Option<File>) =
        if std::env::args().any(|arg| arg == "--foundation-self-test") {
            match crate::ci::profile() {
                Ok((path, file)) => (Some(path), true, Some(file)),
                Err(_) => return,
            }
        } else {
            (None, false, None)
        };
    #[cfg(not(feature = "foundation-ci"))]
    let (profile, fixture, writer): (Option<std::path::PathBuf>, bool, Option<File>) =
        (None, false, None);
    let store = match &profile {
        Some(path) => Store::open(&path.join("manager.sqlite"), &owner),
        None => Store::memory(&owner),
    };
    let store = match store {
        Ok(v) => v,
        Err(_) => return,
    };
    let backend = Backend {
        health: Health::default(),
        observation_inflight: false,
        store,
        state_channels: HashMap::new(),
        selections: Selections::default(),
        handles: HashMap::new(),
        started: Instant::now(),
        session,
        fixture,
        profile: profile.clone(),
        _writer: writer,
    };
    let app = tauri::Builder::default()
        .manage(AppState(Mutex::new(backend)))
        .invoke_handler(tauri::generate_handler![
            get_snapshot,
            get_engine_health,
            subscribe_state,
            unsubscribe_state,
            create_draft,
            reserve_operation,
            select_file,
            prepare_transfer,
            get_operation,
            diagnostic_summary,
            ci_report
        ])
        .setup(move |app| {
            if !fixture {
                let handle = app.handle().clone();
                std::thread::spawn(move || {
                    let mut previous =
                        securerun_sandboxie_adapter::windows::host_transition_marker();
                    loop {
                        std::thread::sleep(std::time::Duration::from_secs(1));
                        let current =
                            securerun_sandboxie_adapter::windows::host_transition_marker();
                        let state = handle.state::<AppState>();
                        if let Ok(mut backend) = state.inner().0.lock() {
                            let changed = current != previous;
                            let expired = backend.health.expire(Instant::now());
                            if changed {
                                backend.health.invalidate("HOST_TRANSITION");
                            }
                            if changed || expired {
                                let _ = backend.store.reconnect();
                                backend.handles.clear();
                                backend.selections = Selections::default();
                            }
                        }
                        previous = current;
                    }
                });
            }
            let mut config = app.config().app.windows[0].clone();
            if fixture {
                config.url = tauri::WebviewUrl::App("index.html?foundation-ci".into());
            }
            tauri::WebviewWindowBuilder::from_config(app, &config)?
                .on_navigation(|url| {
                    authorized_origin("main", url.as_str(), cfg!(debug_assertions))
                })
                .on_new_window(|_, _| tauri::webview::NewWindowResponse::Deny)
                .build()?;
            #[cfg(feature = "foundation-ci")]
            if fixture {
                crate::ci::start(app.handle().clone(), profile.clone().unwrap())?;
            }
            Ok(())
        })
        .build(tauri::generate_context!());
    let app = match app {
        Ok(value) => value,
        Err(_) => {
            eprintln!("APPLICATION_INITIALIZATION_FAILED");
            return;
        }
    };
    app.run(|_, _| {});
}

#[cfg(test)]
mod normal_configuration_tests {
    use super::*;
    #[test]
    fn normal_shell_context_unknown_cannot_enable_metadata_or_engine_actions() {
        let backend = Backend {
            health: Health::default(),
            observation_inflight: false,
            state_channels: HashMap::new(),
            store: Store::memory("S-1-5-21-SYNTHETIC").unwrap(),
            selections: Selections::default(),
            handles: HashMap::new(),
            started: Instant::now(),
            session: 2,
            fixture: false,
            profile: None,
            _writer: None,
        };
        assert_eq!(
            backend.allow_metadata().unwrap_err().code,
            ErrorCode::ManagerContextUnsafe
        );
        let snapshot = backend.snapshot().unwrap();
        assert!(!snapshot.mutations_available);
        assert!(!snapshot.engine_operations_available);
        assert_eq!(snapshot.mode, "READ_ONLY_SETUP");
        assert!(snapshot.environments.is_empty());
    }
    #[test]
    fn normal_capabilities_exclude_test_report_and_remote_origins() {
        let config: serde_json::Value =
            serde_json::from_str(include_str!("../tauri.conf.json")).unwrap();
        assert_eq!(
            config["app"]["security"]["capabilities"],
            serde_json::json!(["main"])
        );
        let main: serde_json::Value =
            serde_json::from_str(include_str!("../capabilities/main.json")).unwrap();
        assert_eq!(main["webviews"], serde_json::json!(["main"]));
        assert!(main.get("remote").is_none());
        assert!(
            !main["permissions"]
                .as_array()
                .unwrap()
                .iter()
                .any(|p| p == "allow-ci-report")
        );
    }
}
