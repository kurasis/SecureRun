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
    issued: Instant,
}
#[derive(Default)]
pub struct PolicyState(Mutex<HashMap<Uuid, Selection>>);
fn authorize(window: &WebviewWindow) -> Result<()> {
    let url = window
        .url()
        .map_err(|_| AppError::new(ErrorCode::Unauthorized))?;
    if !authorized_origin(window.label(), url.as_str(), cfg!(debug_assertions)) {
        return err(ErrorCode::Unauthorized);
    }
    Ok(())
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PickerRequest {
    operation_id: Uuid,
    environment_id: Option<Uuid>,
    expected_revision: u64,
    directory: bool,
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
    let selected = tauri::async_runtime::spawn_blocking(move || {
        let dialog = rfd::FileDialog::new();
        if directory {
            dialog.pick_folder()
        } else {
            dialog.pick_file()
        }
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?
    .ok_or_else(|| AppError::new(ErrorCode::SelectionExpired))?;
    let path = selected
        .to_str()
        .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?
        .to_owned();
    literal_path(&path).map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
    let lease = native::capture(&selected)?;
    let selection_id = Uuid::new_v4();
    let display_name = selected
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("Selected resource")
        .to_owned();
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
fn grants(
    state: &PolicyState,
    requested: Vec<UiGrant>,
    operation: Uuid,
    environment: Option<Uuid>,
    revision: u64,
) -> Result<(Vec<Grant>, Vec<Selection>)> {
    if requested.len() > 24 {
        return err(ErrorCode::InvalidInput);
    }
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
#[tauri::command]
pub async fn policy_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiRequest,
) -> Result<Reply> {
    authorize(&window)?;
    let mut held = vec![];
    let request = match request {
        UiRequest::List => Request::List,
        UiRequest::Create {
            display_name,
            preset,
            grants: requested,
            operation_id,
        } => {
            let (g, h) = grants(&state, requested, operation_id, None, 0)?;
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
            )?;
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
#[tauri::command]
pub async fn control_request(
    window: WebviewWindow,
    state: State<'_, PolicyState>,
    request: UiControlRequest,
) -> Result<securerun_sandboxie_adapter::control::Reply> {
    authorize(&window)?;
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
            )?;
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
    tauri::async_runtime::spawn_blocking(move || {
        let _held = held;
        securerun_sandboxie_adapter::windows::provisioning::control::bounded_request(&request)
    })
    .await
    .map_err(|_| AppError::new(ErrorCode::OperationOutcomeUnknown))
}
