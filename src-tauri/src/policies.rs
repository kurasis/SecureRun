//! Every renderer grant originates in a one-use, operation-bound native picker.
use crate::native;
use securerun_foundation::{AppError, ErrorCode, Result, authorized_origin, err};
use securerun_sandboxie_adapter::{policy::*, provision::*};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::Mutex,
    time::{Duration, Instant},
};
use tauri::{State, WebviewWindow};
use uuid::Uuid;

struct Selection {
    path: String,
    _lease: native::SelectionLease,
    operation: Uuid,
    environment: Option<Uuid>,
    revision: u64,
    generation: u64,
    issued: Instant,
}
struct QueuedPolicy {
    environment: Uuid,
    revision: u64,
    generation: u64,
    engine_generation: u64,
    desired: DesiredPolicy,
    held: Vec<Selection>,
    view_ack: bool,
    created: Instant,
}
#[derive(Serialize)]
pub struct QueuedView {
    queue_id: Uuid,
    environment_id: Uuid,
    revision: u64,
    generation: u64,
    desired: DesiredPolicy,
    expires_in_seconds: u64,
}
#[derive(Serialize)]
pub struct PolicyReply {
    diagnostic_id: Uuid,
    #[serde(flatten)]
    reply: Reply,
    queued_policies: Vec<QueuedView>,
}
#[derive(Default)]
pub struct PolicyState(
    Mutex<HashMap<Uuid, Selection>>,
    std::sync::atomic::AtomicU64,
    Mutex<HashMap<Uuid, QueuedPolicy>>,
    tauri::async_runtime::Mutex<()>,
    std::sync::atomic::AtomicUsize,
);
struct CommandSlot<'a>(&'a std::sync::atomic::AtomicUsize);
impl Drop for CommandSlot<'_> {
    fn drop(&mut self) {
        self.0.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }
}
fn command_slot(state: &PolicyState) -> Result<CommandSlot<'_>> {
    state
        .4
        .fetch_update(
            std::sync::atomic::Ordering::SeqCst,
            std::sync::atomic::Ordering::SeqCst,
            |count| (count < 8).then_some(count + 1),
        )
        .map_err(|_| AppError::new(ErrorCode::OperationConflict))?;
    Ok(CommandSlot(&state.4))
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
#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PickerLanguage {
    En,
    Ru,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PickerRequest {
    operation_id: Uuid,
    environment_id: Option<Uuid>,
    expected_revision: u64,
    directory: bool,
    #[serde(default)]
    file_transfer: bool,
    #[serde(default)]
    language: Option<PickerLanguage>,
}
#[derive(Serialize)]
pub struct PickerReply {
    selection_id: Uuid,
    display_name: String,
    expires_in_seconds: u32,
}
#[tauri::command]
pub async fn select_policy_path(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: PickerRequest,
) -> Result<PickerReply> {
    authorize(&window)?;
    let _slot = command_slot(&state)?;
    let _gate = state.3.lock().await;
    let list = tauri::async_runtime::spawn_blocking(|| {
        securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
    if list.reason != "OBSERVED" {
        return err(ErrorCode::ManagerContextUnsafe);
    }
    if let Some(id) = request.environment_id {
        if !list
            .environments
            .iter()
            .any(|e| e.id == id && e.revision == request.expected_revision)
        {
            return err(ErrorCode::RevisionConflict);
        }
    } else if request.expected_revision != 0 {
        return err(ErrorCode::InvalidInput);
    }
    let directory = request.directory;
    let title = match request.language {
        Some(PickerLanguage::Ru) => "Выбор ресурса SecureRun",
        _ => "SecureRun resource selection",
    };
    let dialog_parent = window.clone();
    let selected = tauri::async_runtime::spawn_blocking(move || {
        native::picker_thread(|| {
            let dialog = rfd::FileDialog::new()
                .set_title(title)
                .set_parent(&dialog_parent);
            if directory {
                dialog.pick_folder()
            } else {
                dialog.pick_file()
            }
        })
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::PathUnsafe))??
    .ok_or_else(|| AppError::new(ErrorCode::SelectionExpired))?;
    authorize(&window)?;
    let path = selected
        .to_str()
        .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?
        .to_owned();
    if request.file_transfer {
        securerun_sandboxie_adapter::files::local_path(&path)
            .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
    } else {
        literal_path(&path).map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
    }
    let lease = native::capture(&selected)?;
    let selection_id = Uuid::new_v4();
    let display_name = selected
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("Selected resource");
    let display_name = securerun_sandboxie_adapter::files::display(display_name);
    let mut selections = state
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    selections.retain(|_, s| s.issued.elapsed() < Duration::from_secs(60));
    if selections.len() >= 32 {
        return err(ErrorCode::OperationConflict);
    }
    selections.insert(
        selection_id,
        Selection {
            path,
            _lease: lease,
            operation: request.operation_id,
            environment: request.environment_id,
            revision: request.expected_revision,
            generation: request
                .environment_id
                .and_then(|id| {
                    list.environments
                        .iter()
                        .find(|e| e.id == id)
                        .map(|e| e.generation)
                })
                .unwrap_or(0),
            issued: Instant::now(),
        },
    );
    Ok(PickerReply {
        selection_id,
        display_name,
        expires_in_seconds: 60,
    })
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UiGrant {
    selection_id: Uuid,
    permission: Permission,
}
#[derive(Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum UiRequest {
    List,
    Rename {
        environment_id: Uuid,
        expected_revision: u64,
        expected_generation: u64,
        expected_display_name: String,
        display_name: String,
        operation_id: Uuid,
    },
    Queue {
        environment_id: Uuid,
        expected_revision: u64,
        preset: Preset,
        grants: Vec<UiGrant>,
        operation_id: Uuid,
        acknowledge_view_change: bool,
    },
    ApplyQueued {
        queue_id: Uuid,
        operation_id: Uuid,
    },
    DiscardQueued {
        queue_id: Uuid,
    },

    Create {
        display_name: String,
        preset: Preset,
        grants: Vec<UiGrant>,
        operation_id: Uuid,
    },
    Apply {
        environment_id: Uuid,
        expected_revision: u64,
        preset: Preset,
        grants: Vec<UiGrant>,
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
async fn grants(
    state: &PolicyState,
    requested: Vec<UiGrant>,
    operation: Uuid,
    environment: Option<Uuid>,
    revision: u64,
) -> Result<(Vec<Grant>, Vec<Selection>)> {
    if requested.len() > 24 {
        return err(ErrorCode::InvalidInput);
    }
    {
        let selections = state
            .0
            .lock()
            .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
        if requested
            .iter()
            .any(|r| !selections.contains_key(&r.selection_id))
        {
            return err(ErrorCode::SelectionExpired);
        }
    }
    let current_generation = if let Some(id) = environment {
        let current = tauri::async_runtime::spawn_blocking(|| {
            securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
        })
        .await
        .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
        if current.reason != "OBSERVED" {
            return err(ErrorCode::ManagerContextUnsafe);
        }
        Some(
            current
                .environments
                .iter()
                .find(|e| e.id == id)
                .ok_or_else(|| AppError::new(ErrorCode::SelectionScopeMismatch))?
                .generation,
        )
    } else {
        None
    };
    let mut selections = state
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    let mut result = vec![];
    let mut held = vec![];
    for request in requested {
        let s = selections
            .remove(&request.selection_id)
            .ok_or_else(|| AppError::new(ErrorCode::SelectionExpired))?;
        if s.issued.elapsed() >= Duration::from_secs(60)
            || s.operation != operation
            || s.environment != environment
            || s.revision != revision
            || current_generation.is_some_and(|g| g != s.generation)
        {
            return err(ErrorCode::SelectionScopeMismatch);
        }
        result.push(Grant {
            path: s.path.clone(),
            permission: request.permission,
        });
        held.push(s);
    }
    Ok((result, held))
}
async fn policy_request_inner(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiRequest,
) -> Result<Reply> {
    authorize(&window)?;
    let mut held = vec![];
    let request = match request {
        UiRequest::Queue { .. }
        | UiRequest::ApplyQueued { .. }
        | UiRequest::DiscardQueued { .. } => return err(ErrorCode::InvalidInput),

        UiRequest::Rename {
            environment_id,
            expected_revision,
            expected_generation,
            expected_display_name,
            display_name,
            operation_id,
        } => {
            let renamed = tauri::async_runtime::spawn_blocking(move || {
                securerun_sandboxie_adapter::windows::provisioning::product::bounded_request(
                    &securerun_sandboxie_adapter::product::Request::Rename {
                        environment_id,
                        expected_revision,
                        expected_generation,
                        expected_display_name,
                        display_name,
                        operation_id,
                    },
                )
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))?;
            if renamed.reason != "OBSERVED" {
                return Ok(Reply::failure(&renamed.reason));
            }
            return tauri::async_runtime::spawn_blocking(|| {
                securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown));
        }
        UiRequest::List => Request::List,
        UiRequest::Create {
            display_name,
            preset,
            grants: requested,
            operation_id,
        } => {
            let (g, h) = grants(&state, requested, operation_id, None, 0).await?;
            held = h;
            Request::Create {
                display_name,
                policy: DesiredPolicy {
                    schema: 1,
                    preset,
                    grants: g,
                },
                operation_id,
            }
        }
        UiRequest::Apply {
            environment_id,
            expected_revision,
            preset,
            grants: requested,
            operation_id,
            acknowledge_view_change,
        } => {
            let (g, h) = grants(
                &state,
                requested,
                operation_id,
                Some(environment_id),
                expected_revision,
            )
            .await?;
            held = h;
            Request::Apply {
                environment_id,
                expected_revision,
                policy: DesiredPolicy {
                    schema: 1,
                    preset,
                    grants: g,
                },
                operation_id,
                acknowledge_view_change,
            }
        }
        UiRequest::Inspect { environment_id } => Request::Inspect { environment_id },
        UiRequest::Repair {
            environment_id,
            expected_revision,
            observed_fingerprint,
            operation_id,
            acknowledge_view_change,
        } => Request::Repair {
            environment_id,
            expected_revision,
            observed_fingerprint,
            operation_id,
            acknowledge_view_change,
        },
    };
    let reply = tauri::async_runtime::spawn_blocking(move || {
        let _held = held;
        securerun_sandboxie_adapter::windows::provisioning::bounded_request(&request)
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))?;
    Ok(reply)
}

#[derive(Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum UiControlRequest {
    List,
    Register {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        display_name: String,
        executable_selection: Uuid,
        arguments: Vec<String>,
        directory_selection: Option<Uuid>,
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
#[derive(Serialize)]
pub struct ControlReply {
    diagnostic_id: Uuid,
    #[serde(flatten)]
    reply: securerun_sandboxie_adapter::control::Reply,
    engine_generation: u64,
    sequence: u64,
}
async fn control_request_inner(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiControlRequest,
    backend: State<'_, crate::app::AppState>,
) -> Result<ControlReply> {
    authorize(&window)?;
    let ticket = state.1.fetch_add(1, std::sync::atomic::Ordering::SeqCst) + 1;
    let engine_generation = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    use securerun_sandboxie_adapter::control::Request as Control;
    let mut held = vec![];
    let request = match request {
        UiControlRequest::List => Control::List,
        UiControlRequest::Register {
            environment_id,
            expected_revision,
            operation_id,
            display_name,
            executable_selection,
            arguments,
            directory_selection,
        } => {
            let mut selections = vec![UiGrant {
                selection_id: executable_selection,
                permission: Permission::Block,
            }];
            if let Some(id) = directory_selection {
                selections.push(UiGrant {
                    selection_id: id,
                    permission: Permission::Block,
                })
            }
            let (paths, leases) = grants(
                &state,
                selections,
                operation_id,
                Some(environment_id),
                expected_revision,
            )
            .await?;
            held = leases;
            Control::Register {
                environment_id,
                expected_revision,
                operation_id,
                display_name,
                executable: paths[0].path.clone(),
                arguments,
                working_directory: paths.get(1).map(|p| p.path.clone()),
            }
        }
        UiControlRequest::Launch {
            application_id,
            environment_id,
            expected_revision,
            operation_id,
        } => Control::Launch {
            application_id,
            environment_id,
            expected_revision,
            operation_id,
        },
        UiControlRequest::Stop {
            environment_id,
            operation_id,
        } => Control::Stop {
            environment_id,
            operation_id,
        },
        UiControlRequest::StopManaged { operation_id } => Control::StopManaged { operation_id },
        UiControlRequest::Reconcile { operation_id } => Control::Reconcile { operation_id },
    };
    let reply = tauri::async_runtime::spawn_blocking(move || {
        let _held = held;
        securerun_sandboxie_adapter::windows::provisioning::control::bounded_request(&request)
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))?;
    let current = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    if ticket != state.1.load(std::sync::atomic::Ordering::SeqCst) || current != engine_generation {
        return err(ErrorCode::StaleOperation);
    }
    Ok(ControlReply {
        diagnostic_id: Uuid::new_v4(),
        reply,
        engine_generation,
        sequence: ticket,
    })
}

#[derive(Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum UiFilesRequest {
    List {
        environment_id: Uuid,
        expected_revision: u64,
        node_id: Option<Uuid>,
        offset: u32,
    },
    Import {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        source_selection: Uuid,
        name: String,
    },
    Export {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        file_id: Uuid,
        destination_selection: Uuid,
        name: String,
    },
    Register {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        file_id: Uuid,
        arguments: Vec<String>,
    },
    Recover {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
    },
    Discard {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
    },
    Cancel {
        operation_id: Uuid,
    },
}
#[derive(Serialize)]
pub struct FilesReply {
    diagnostic_id: Uuid,
    #[serde(flatten)]
    reply: securerun_sandboxie_adapter::files::Reply,
    engine_generation: u64,
}
async fn files_request_inner(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiFilesRequest,
    backend: State<'_, crate::app::AppState>,
) -> Result<FilesReply> {
    authorize(&window)?;
    let generation = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    use securerun_sandboxie_adapter::files::Request as F;
    let mut held = vec![];
    let request = match request {
        UiFilesRequest::List {
            environment_id,
            expected_revision,
            node_id,
            offset,
        } => F::List {
            environment_id,
            expected_revision,
            node_id,
            offset,
        },
        UiFilesRequest::Import {
            environment_id,
            expected_revision,
            operation_id,
            source_selection,
            name,
        } => {
            let (paths, leases) = grants(
                &state,
                vec![UiGrant {
                    selection_id: source_selection,
                    permission: Permission::Block,
                }],
                operation_id,
                Some(environment_id),
                expected_revision,
            )
            .await?;
            held = leases;
            F::Import {
                environment_id,
                expected_revision,
                operation_id,
                source: paths[0].path.clone(),
                name,
            }
        }
        UiFilesRequest::Export {
            environment_id,
            expected_revision,
            operation_id,
            file_id,
            destination_selection,
            name,
        } => {
            let (paths, leases) = grants(
                &state,
                vec![UiGrant {
                    selection_id: destination_selection,
                    permission: Permission::Block,
                }],
                operation_id,
                Some(environment_id),
                expected_revision,
            )
            .await?;
            held = leases;
            F::Export {
                environment_id,
                expected_revision,
                operation_id,
                file_id,
                destination: paths[0].path.clone(),
                name,
            }
        }
        UiFilesRequest::Register {
            environment_id,
            expected_revision,
            operation_id,
            file_id,
            arguments,
        } => F::Register {
            environment_id,
            expected_revision,
            operation_id,
            file_id,
            arguments,
        },
        UiFilesRequest::Recover {
            environment_id,
            expected_revision,
            operation_id,
        } => F::Recover {
            environment_id,
            expected_revision,
            operation_id,
        },
        UiFilesRequest::Discard {
            environment_id,
            expected_revision,
            operation_id,
        } => F::Discard {
            environment_id,
            expected_revision,
            operation_id,
        },
        UiFilesRequest::Cancel { operation_id } => F::Cancel { operation_id },
    };
    let reply = tauri::async_runtime::spawn_blocking(move || {
        let _held = held;
        securerun_sandboxie_adapter::windows::provisioning::files::bounded_request(&request)
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))?;
    let current = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    if current != generation {
        return err(ErrorCode::StaleOperation);
    }
    Ok(FilesReply {
        diagnostic_id: Uuid::new_v4(),
        reply,
        engine_generation: generation,
    })
}

#[derive(Clone, Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum UiLifecycleRequest {
    List,
    Act {
        environment_id: Uuid,
        expected_revision: u64,
        expected_generation: u64,
        operation_id: Uuid,
        intent: securerun_sandboxie_adapter::lifecycle::Action,
        language: String,
    },
    Recover {
        operation_id: Uuid,
    },
}
#[derive(Serialize)]
pub struct LifecycleReply {
    diagnostic_id: Uuid,
    reply: securerun_sandboxie_adapter::lifecycle::Reply,
    engine_generation: u64,
}
static LIFECYCLE_DIALOG: Mutex<()> = Mutex::new(());
pub fn perform_lifecycle(
    request: UiLifecycleRequest,
) -> Result<securerun_sandboxie_adapter::lifecycle::Reply> {
    use securerun_sandboxie_adapter::{
        lifecycle::{Action, Request as L},
        windows::provisioning::lifecycle::bounded_request,
    };
    match request {
        UiLifecycleRequest::List => Ok(bounded_request(&L::List)),
        UiLifecycleRequest::Recover { operation_id } => {
            Ok(bounded_request(&L::Recover { operation_id }))
        }
        UiLifecycleRequest::Act {
            environment_id,
            expected_revision,
            expected_generation,
            operation_id,
            intent,
            language,
        } => {
            if !matches!(language.as_str(), "en" | "ru") {
                return err(ErrorCode::InvalidInput);
            }
            let _dialog = LIFECYCLE_DIALOG
                .try_lock()
                .map_err(|_| AppError::new(ErrorCode::OperationConflict))?;
            let prepared = bounded_request(&L::Prepare {
                environment_id,
                expected_revision,
                expected_generation,
                operation_id,
                intent,
            });
            if prepared.reason != "OBSERVED" {
                return Ok(prepared);
            }
            let Some(plan) = prepared.plan else {
                return err(ErrorCode::OperationConflict);
            };
            let russian = language == "ru";
            let retention = if russian {
                match intent {
                    Action::Reset => {
                        "Удалить всё содержимое песочницы. Определение среды и записи приложений сохранятся. Импортированные EXE нужно будет импортировать заново."
                    }
                    Action::Remove => {
                        "Удалить всё содержимое, затем определение среды и записи приложений. Сохранить историю и идентичность проверенного пустого корня."
                    }
                    Action::Archive => {
                        "Сохранить определение, приложения и данные. Запуск через менеджер будет запрещён. Экспорт и сброс останутся доступны."
                    }
                    Action::Unarchive => {
                        "Сохранить данные. Перед разрешением запуска заново проверить владельца, корень и политику."
                    }
                    Action::Persistent => {
                        "Сохранять данные и процессы после закрытия менеджера. Не выполнять автоматическую очистку."
                    }
                    Action::Disposable => {
                        "Использовать отдельную приватную среду. После завершения всех процессов предложить продолжение, экспорт или удаление. Не экспортировать и не очищать автоматически."
                    }
                    Action::Resume => {
                        "Сохранить оставшиеся данные disposable-среды и разрешить новый явный запуск. Предыдущий запуск повторно не выполняется."
                    }
                }
            } else {
                intent.retention()
            };
            let name = securerun_sandboxie_adapter::files::display(&plan.display_name);
            let title = if russian {
                "SecureRun — подтверждение среды"
            } else {
                "SecureRun — environment confirmation"
            };
            let body = format!("{}\n{}\n\n{}", name, environment_id, retention);
            let accepted = rfd::MessageDialog::new()
                .set_title(title)
                .set_description(&body)
                .set_level(if intent.destructive() {
                    rfd::MessageLevel::Warning
                } else {
                    rfd::MessageLevel::Info
                })
                .set_buttons(rfd::MessageButtons::OkCancel)
                .show();
            if accepted != rfd::MessageDialogResult::Ok {
                let mut cancelled = bounded_request(&L::Cancel {
                    operation_id,
                    plan_id: plan.plan_id,
                });
                if cancelled.reason == "OBSERVED" {
                    cancelled.reason = "LIFECYCLE_CONFIRMATION_CANCELLED".into();
                }
                return Ok(cancelled);
            }
            Ok(bounded_request(&L::Commit {
                operation_id,
                plan_id: plan.plan_id,
            }))
        }
    }
}
async fn lifecycle_request_inner(
    window: WebviewWindow,
    request: UiLifecycleRequest,
    backend: State<'_, crate::app::AppState>,
) -> Result<LifecycleReply> {
    authorize(&window)?;
    let generation = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    let reply = tauri::async_runtime::spawn_blocking(move || perform_lifecycle(request))
        .await
        .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))??;
    if generation
        != backend
            .0
            .lock()
            .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
            .health
            .view(Instant::now())
            .generation
    {
        return err(ErrorCode::CapabilityUnavailable);
    }
    Ok(LifecycleReply {
        diagnostic_id: Uuid::new_v4(),
        reply,
        engine_generation: generation,
    })
}

// History accepts typed manager events only; no target arguments or error text.
fn event_outcome(reason: Option<&str>) -> securerun_sandboxie_adapter::product::Outcome {
    use securerun_sandboxie_adapter::product::Outcome;
    match reason {
        Some("OBSERVED") => Outcome::Observed,
        Some(r) if !r.contains("UNKNOWN") => Outcome::Refused,
        _ => Outcome::Unknown,
    }
}
#[tauri::command]
pub async fn policy_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiRequest,
    backend: State<'_, crate::app::AppState>,
    product: State<'_, crate::product::ProductState>,
) -> Result<PolicyReply> {
    authorize(&window)?;
    let _slot = command_slot(&state)?;
    let _gate = state.3.lock().await;
    use securerun_sandboxie_adapter::product::Action as A;
    let environment_id = match &request {
        UiRequest::Rename { environment_id, .. }
        | UiRequest::Apply { environment_id, .. }
        | UiRequest::Queue { environment_id, .. }
        | UiRequest::Inspect { environment_id }
        | UiRequest::Repair { environment_id, .. } => Some(*environment_id),
        _ => None,
    };
    let action = match &request {
        UiRequest::List => None,
        UiRequest::Create { .. } => Some(A::PolicyCreate),
        UiRequest::Rename { .. } => Some(A::Rename),
        UiRequest::Queue { .. } => Some(A::PolicyQueue),
        UiRequest::DiscardQueued { .. } => Some(A::PolicyDraftDiscard),
        UiRequest::Inspect { .. } => Some(A::PolicyInspect),
        UiRequest::Repair { .. } => Some(A::PolicyRepair),
        _ => Some(A::PolicyApply),
    };
    let engine_generation = backend
        .0
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .health
        .view(Instant::now())
        .generation;
    let result: Result<Reply> = match request {
        UiRequest::Queue {
            environment_id,
            expected_revision,
            preset,
            grants: requested,
            operation_id,
            acknowledge_view_change,
        } => {
            let (grants, held) = grants(
                &state,
                requested,
                operation_id,
                Some(environment_id),
                expected_revision,
            )
            .await?;
            let current = tauri::async_runtime::spawn_blocking(|| {
                securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
            if current.reason != "OBSERVED" {
                return err(ErrorCode::ManagerContextUnsafe);
            }
            let e = current
                .environments
                .iter()
                .find(|e| e.id == environment_id && e.revision == expected_revision)
                .ok_or_else(|| AppError::new(ErrorCode::RevisionConflict))?;
            let generation = e.generation;
            let mut queues = state
                .2
                .lock()
                .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
            queues.retain(|_, q| {
                q.created.elapsed() < Duration::from_secs(60) && q.environment != environment_id
            });
            if queues.len() >= 12 {
                return err(ErrorCode::OperationConflict);
            }
            queues.insert(
                operation_id,
                QueuedPolicy {
                    environment: environment_id,
                    revision: expected_revision,
                    generation,
                    engine_generation,
                    desired: DesiredPolicy {
                        schema: 1,
                        preset,
                        grants,
                    },
                    held,
                    view_ack: acknowledge_view_change,
                    created: Instant::now(),
                },
            );
            Ok(current)
        }
        UiRequest::ApplyQueued {
            queue_id,
            operation_id,
        } => {
            let queued = state
                .2
                .lock()
                .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
                .remove(&queue_id)
                .ok_or_else(|| AppError::new(ErrorCode::SelectionExpired))?;
            if queued.created.elapsed() >= Duration::from_secs(60)
                || queued.engine_generation != engine_generation
                || queued.held.iter().any(|s| {
                    s.issued.elapsed() >= Duration::from_secs(60)
                        || native::identify(&s._lease.file).ok() != Some(s._lease.identity.clone())
                })
            {
                return err(ErrorCode::SelectionExpired);
            }
            let current = tauri::async_runtime::spawn_blocking(|| {
                securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
            if current.reason != "OBSERVED"
                || !current.environments.iter().any(|e| {
                    e.id == queued.environment
                        && e.revision == queued.revision
                        && e.generation == queued.generation
                })
            {
                return err(ErrorCode::StaleOperation);
            }
            tauri::async_runtime::spawn_blocking(move || {
                let _held = queued.held;
                securerun_sandboxie_adapter::windows::provisioning::bounded_request(
                    &Request::Apply {
                        environment_id: queued.environment,
                        expected_revision: queued.revision,
                        policy: queued.desired,
                        operation_id,
                        acknowledge_view_change: queued.view_ack,
                    },
                )
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))
        }
        UiRequest::DiscardQueued { queue_id } => {
            state
                .2
                .lock()
                .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
                .remove(&queue_id);
            tauri::async_runtime::spawn_blocking(|| {
                securerun_sandboxie_adapter::windows::provisioning::bounded_request(&Request::List)
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))
        }
        other => policy_request_inner(window, state.clone(), other).await,
    };
    let diagnostic_id = result
        .as_ref()
        .err()
        .map_or_else(Uuid::new_v4, |e| e.diagnostic_id);
    if let Some(action) = action {
        crate::product::record(
            &product,
            &backend,
            action,
            event_outcome(result.as_ref().ok().map(|r| r.reason.as_str())),
            environment_id,
            Some(diagnostic_id),
        )
        .await;
    }
    let reply = result?;
    let queued_policies = {
        let mut queues = state
            .2
            .lock()
            .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
        queues.retain(|_, q| {
            q.created.elapsed() < Duration::from_secs(60)
                && q.engine_generation == engine_generation
                && reply.environments.iter().any(|e| {
                    e.id == q.environment
                        && e.revision == q.revision
                        && e.generation == q.generation
                })
        });
        queues
            .iter()
            .map(|(id, q)| QueuedView {
                queue_id: *id,
                environment_id: q.environment,
                revision: q.revision,
                generation: q.generation,
                desired: q.desired.clone(),
                expires_in_seconds: 60 - q.created.elapsed().as_secs(),
            })
            .collect()
    };
    Ok(PolicyReply {
        diagnostic_id,
        reply,
        queued_policies,
    })
}
#[tauri::command]
pub async fn control_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiControlRequest,
    backend: State<'_, crate::app::AppState>,
    product: State<'_, crate::product::ProductState>,
) -> Result<ControlReply> {
    authorize(&window)?;
    let _slot = command_slot(&state)?;
    let _gate = state.3.lock().await;
    use securerun_sandboxie_adapter::product::Action as A;
    let environment_id = match &request {
        UiControlRequest::Register { environment_id, .. }
        | UiControlRequest::Launch { environment_id, .. }
        | UiControlRequest::Stop { environment_id, .. } => Some(*environment_id),
        _ => None,
    };
    let action = match &request {
        UiControlRequest::List => None,
        UiControlRequest::Register { .. } => Some(A::Register),
        UiControlRequest::Launch { .. } => Some(A::Launch),
        UiControlRequest::Stop { .. } => Some(A::Stop),
        UiControlRequest::StopManaged { .. } => Some(A::StopManaged),
        UiControlRequest::Reconcile { .. } => Some(A::LifecycleInspect),
    };
    let result = control_request_inner(window, state.clone(), request, backend.clone()).await;
    if let Some(action) = action {
        crate::product::record(
            &product,
            &backend,
            action,
            event_outcome(result.as_ref().ok().map(|r| r.reply.reason.as_str())),
            environment_id,
            Some(match &result {
                Ok(reply) => reply.diagnostic_id,
                Err(error) => error.diagnostic_id,
            }),
        )
        .await;
    }
    result
}
#[tauri::command]
pub async fn files_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiFilesRequest,
    backend: State<'_, crate::app::AppState>,
    product: State<'_, crate::product::ProductState>,
) -> Result<FilesReply> {
    authorize(&window)?;
    let cancel = matches!(&request, UiFilesRequest::Cancel { .. });
    let _slot = if cancel {
        None
    } else {
        Some(command_slot(&state)?)
    };
    let _gate = if cancel {
        None
    } else {
        Some(state.3.lock().await)
    };
    use securerun_sandboxie_adapter::product::Action as A;
    let environment_id = match &request {
        UiFilesRequest::List { environment_id, .. }
        | UiFilesRequest::Import { environment_id, .. }
        | UiFilesRequest::Export { environment_id, .. }
        | UiFilesRequest::Register { environment_id, .. }
        | UiFilesRequest::Recover { environment_id, .. }
        | UiFilesRequest::Discard { environment_id, .. } => Some(*environment_id),
        _ => None,
    };
    let action = match &request {
        UiFilesRequest::List { .. } => None,
        UiFilesRequest::Import { .. } => Some(A::Import),
        UiFilesRequest::Export { .. } => Some(A::Export),
        UiFilesRequest::Register { .. } => Some(A::Register),
        UiFilesRequest::Recover { .. } => Some(A::TransferInspect),
        UiFilesRequest::Discard { .. } | UiFilesRequest::Cancel { .. } => Some(A::TransferDiscard),
    };
    let result = files_request_inner(window, state.clone(), request, backend.clone()).await;
    if let Some(action) = action {
        crate::product::record(
            &product,
            &backend,
            action,
            event_outcome(result.as_ref().ok().map(|r| r.reply.reason.as_str())),
            environment_id,
            Some(match &result {
                Ok(reply) => reply.diagnostic_id,
                Err(error) => error.diagnostic_id,
            }),
        )
        .await;
    }
    result
}
#[tauri::command]
pub async fn lifecycle_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiLifecycleRequest,
    backend: State<'_, crate::app::AppState>,
    product: State<'_, crate::product::ProductState>,
) -> Result<LifecycleReply> {
    authorize(&window)?;
    let _slot = command_slot(&state)?;
    let _gate = state.3.lock().await;
    use securerun_sandboxie_adapter::product::Action as A;
    let environment_id = match &request {
        UiLifecycleRequest::Act { environment_id, .. } => Some(*environment_id),
        _ => None,
    };
    let action = match &request {
        UiLifecycleRequest::List => None,
        UiLifecycleRequest::Act { .. } => Some(A::RetentionChange),
        UiLifecycleRequest::Recover { .. } => Some(A::LifecycleInspect),
    };
    let result = lifecycle_request_inner(window, request, backend.clone()).await;
    if let Some(action) = action {
        crate::product::record(
            &product,
            &backend,
            action,
            event_outcome(result.as_ref().ok().map(|r| r.reply.reason.as_str())),
            environment_id,
            Some(match &result {
                Ok(reply) => reply.diagnostic_id,
                Err(error) => error.diagnostic_id,
            }),
        )
        .await;
    }
    result
}

#[cfg(test)]
mod product_command_tests {
    use super::*;
    #[test]
    fn waiting_managed_commands_are_bounded_and_dropped_slots_are_reusable() {
        let state = PolicyState::default();
        let mut held = (0..8)
            .map(|_| command_slot(&state).unwrap())
            .collect::<Vec<_>>();
        assert!(matches!(
            command_slot(&state),
            Err(AppError {
                code: ErrorCode::OperationConflict,
                ..
            })
        ));
        held.pop();
        let replacement = command_slot(&state).unwrap();
        assert!(command_slot(&state).is_err());
        drop(replacement);
        drop(held);
        assert_eq!(state.4.load(std::sync::atomic::Ordering::SeqCst), 0);
    }
}
