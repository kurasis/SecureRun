//! Review-before-save diagnostics. Renderer text and filesystem paths are never accepted.
use crate::{app::AppState, native};
use securerun_foundation::{AppError, ErrorCode, Result, authorized_origin, err};
use securerun_sandboxie_adapter::product::{self as contract, Action, Event, Outcome};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, VecDeque},
    io::Write,
    sync::Mutex,
    time::{Duration, Instant},
};
use tauri::{State, WebviewWindow};
use uuid::Uuid;

struct Preview {
    body: String,
    created: Instant,
}
fn require_unboxed_save_context() -> Result<()> {
    // History may fall back to an in-memory setup view. That is not authority
    // to write a host file. Reobserve the actual manager/worker at each use,
    // including after the asynchronous native picker.
    let observation = securerun_sandboxie_adapter::windows::bounded_observe();
    if !contract::diagnostic_save_context(&observation) {
        return err(ErrorCode::ManagerContextUnsafe);
    }
    Ok(())
}
#[derive(Default)]
pub struct ProductState {
    events: Mutex<VecDeque<Event>>,
    previews: Mutex<HashMap<Uuid, Preview>>,
    gate: tauri::async_runtime::Mutex<()>,
    active: std::sync::atomic::AtomicUsize,
    persistence_failed: std::sync::atomic::AtomicBool,
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
fn persistent(backend: &AppState) -> bool {
    backend.0.lock().is_ok_and(|b| {
        !b.fixture && contract::may_attempt_native_history(&b.health.view(Instant::now()))
    })
}
async fn record_unlocked(
    state: &ProductState,
    backend: &AppState,
    action: Action,
    outcome: Outcome,
    environment_id: Option<Uuid>,
    diagnostic_id: Option<Uuid>,
) {
    let mut event = Event::new(action, outcome);
    event.environment_id = environment_id;
    if let Some(id) = diagnostic_id {
        event.diagnostic_id = id;
    }
    if let Ok(mut events) = state.events.lock() {
        events.push_front(event.clone());
        events.retain(|e| {
            e.unix_ms >= contract::now().saturating_sub(contract::RETENTION_DAYS * 86400000)
        });
        events.truncate(contract::HISTORY_LIMIT);
    }
    if persistent(backend) {
        let persisted = tauri::async_runtime::spawn_blocking(move || {
            securerun_sandboxie_adapter::windows::provisioning::product::bounded_request(
                &contract::Request::Record { event },
            )
        })
        .await;
        if !persisted.is_ok_and(|r| r.reason == "OBSERVED") {
            state
                .persistence_failed
                .store(true, std::sync::atomic::Ordering::SeqCst);
        }
    } else {
        state
            .persistence_failed
            .store(true, std::sync::atomic::Ordering::SeqCst);
    }
}
pub async fn record(
    state: &ProductState,
    backend: &AppState,
    action: Action,
    outcome: Outcome,
    environment_id: Option<Uuid>,
    diagnostic_id: Option<Uuid>,
) {
    let _gate = state.gate.lock().await;
    record_unlocked(
        state,
        backend,
        action,
        outcome,
        environment_id,
        diagnostic_id,
    )
    .await;
}
struct ProductSlot<'a>(&'a std::sync::atomic::AtomicUsize);
impl Drop for ProductSlot<'_> {
    fn drop(&mut self) {
        self.0.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }
}
fn slot(state: &ProductState) -> Result<ProductSlot<'_>> {
    state
        .active
        .fetch_update(
            std::sync::atomic::Ordering::SeqCst,
            std::sync::atomic::Ordering::SeqCst,
            |n| (n < 4).then_some(n + 1),
        )
        .map_err(|_| AppError::new(ErrorCode::OperationConflict))?;
    Ok(ProductSlot(&state.active))
}
async fn history(state: &ProductState, backend: &AppState) -> Result<contract::Reply> {
    let mut reply = if persistent(backend) {
        tauri::async_runtime::spawn_blocking(|| {
            securerun_sandboxie_adapter::windows::provisioning::product::bounded_request(
                &contract::Request::List,
            )
        })
        .await
        .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?
    } else {
        contract::Reply::failure("SESSION_HISTORY_ONLY")
    };
    for event in state
        .events
        .lock()
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
        .iter()
    {
        if event.unix_ms >= contract::now().saturating_sub(contract::RETENTION_DAYS * 86400000)
            && !reply
                .events
                .iter()
                .any(|e| e.diagnostic_id == event.diagnostic_id)
        {
            reply.events.push(event.clone());
        }
    }
    reply.events.sort_by_key(|e| std::cmp::Reverse(e.unix_ms));
    reply.events.truncate(contract::HISTORY_LIMIT);
    if state
        .persistence_failed
        .load(std::sync::atomic::Ordering::SeqCst)
    {
        reply.reason = "SESSION_EVENTS_NOT_PERSISTED".into();
    }
    Ok(reply)
}
#[derive(Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum HelpTopic {
    Install,
    Certificate,
}
#[derive(Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum Request {
    Help { topic: HelpTopic },
    Scale { percent: u16 },
    List,
    Preview,
    Save { preview_id: Uuid, language: String },
    Cancel { preview_id: Uuid },
}
#[derive(Serialize)]
pub struct Reply {
    history: contract::Reply,
    preview_id: Option<Uuid>,
    bundle: Option<String>,
    saved: bool,
}

#[tauri::command]
pub async fn product_request(
    window: WebviewWindow,
    state: State<'_, ProductState>,
    backend: State<'_, AppState>,
    request: Request,
) -> Result<Reply> {
    authorize(&window)?;
    let _slot = slot(&state)?;
    let _gate = state.gate.lock().await;
    let mut result = Reply {
        history: if matches!(&request, Request::Help { .. } | Request::Scale { .. }) {
            // Presentation and the fixed official help link do not read history.
            contract::Reply::failure("HISTORY_NOT_REQUESTED")
        } else {
            history(&state, &backend).await?
        },
        preview_id: None,
        bundle: None,
        saved: false,
    };
    match request {
        Request::Help { topic } => {
            let url = match topic {
                HelpTopic::Install => "https://sandboxie-plus.com/downloads/",
                HelpTopic::Certificate => "https://sandboxie-plus.com/feature-comparison/",
            };
            let operation = "open".encode_utf16().chain(Some(0)).collect::<Vec<_>>();
            let target = url.encode_utf16().chain(Some(0)).collect::<Vec<_>>();
            let code = unsafe {
                windows_sys::Win32::UI::Shell::ShellExecuteW(
                    std::ptr::null_mut(),
                    operation.as_ptr(),
                    target.as_ptr(),
                    std::ptr::null(),
                    std::ptr::null(),
                    1,
                )
            };
            if code as isize <= 32 {
                return err(ErrorCode::CapabilityUnavailable);
            }
        }
        Request::Scale { percent } => {
            if !matches!(percent, 100 | 150 | 200) {
                return err(ErrorCode::InvalidInput);
            }
            window
                .set_zoom(f64::from(percent) / 100.0)
                .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?;
        }
        Request::List => {}
        Request::Preview => {
            let body = contract::bundle(&result.history.events)
                .map_err(|_| AppError::new(ErrorCode::CorruptRecord))?;
            let id = Uuid::new_v4();
            {
                let mut previews = state
                    .previews
                    .lock()
                    .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
                previews.retain(|_, p| p.created.elapsed() < Duration::from_secs(60));
                if previews.len() >= 4 {
                    return err(ErrorCode::OperationConflict);
                }
                previews.insert(
                    id,
                    Preview {
                        body: body.clone(),
                        created: Instant::now(),
                    },
                );
            }
            result.preview_id = Some(id);
            result.bundle = Some(body);
            record_unlocked(
                &state,
                &backend,
                Action::DiagnosticPreview,
                Outcome::Observed,
                None,
                None,
            )
            .await;
        }
        Request::Cancel { preview_id } => {
            state
                .previews
                .lock()
                .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
                .remove(&preview_id);
        }
        Request::Save {
            preview_id,
            language,
        } => {
            if !matches!(language.as_str(), "en" | "ru") {
                return err(ErrorCode::InvalidInput);
            }
            let body = {
                let mut previews = state
                    .previews
                    .lock()
                    .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
                let preview = previews
                    .remove(&preview_id)
                    .ok_or_else(|| AppError::new(ErrorCode::SelectionExpired))?;
                if preview.created.elapsed() >= Duration::from_secs(60) {
                    return err(ErrorCode::SelectionExpired);
                }
                preview.body
            };
            let dialog_parent = window.clone();
            let saved = tauri::async_runtime::spawn_blocking(move || -> Result<bool> {
                require_unboxed_save_context()?;
                let title = if language == "ru" {
                    "Сохранить просмотренную диагностику"
                } else {
                    "Save reviewed diagnostics"
                };
                let Some(path) = native::picker_thread(|| {
                    rfd::FileDialog::new()
                        .set_title(title)
                        .set_parent(&dialog_parent)
                        .add_filter("JSON", &["json"])
                        .set_file_name("SecureRun-diagnostics.json")
                        .save_file()
                })?
                else {
                    return Ok(false);
                };
                require_unboxed_save_context()?;
                securerun_sandboxie_adapter::files::local_path(
                    path.to_str()
                        .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?,
                )
                .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
                let leaf = path
                    .file_name()
                    .and_then(|v| v.to_str())
                    .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?;
                securerun_sandboxie_adapter::files::leaf(leaf)
                    .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
                if !leaf.to_lowercase().ends_with(".json") {
                    return err(ErrorCode::PathUnsafe);
                }
                let _parent = native::capture(
                    path.parent()
                        .ok_or_else(|| AppError::new(ErrorCode::PathUnsafe))?,
                )?;
                use std::os::windows::fs::OpenOptionsExt;
                let mut file = std::fs::OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .share_mode(0)
                    .custom_flags(
                        windows_sys::Win32::Storage::FileSystem::FILE_FLAG_OPEN_REPARSE_POINT,
                    )
                    .open(&path)
                    .map_err(|error| {
                        AppError::new(if error.kind() == std::io::ErrorKind::AlreadyExists {
                            ErrorCode::DestinationExists
                        } else {
                            ErrorCode::PathUnsafe
                        })
                    })?;
                native::identify(&file)?;
                file.write_all(body.as_bytes())
                    .and_then(|_| file.sync_all())
                    .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
                Ok(true)
            })
            .await
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))??;
            authorize(&window)?;
            result.saved = saved;
            record_unlocked(
                &state,
                &backend,
                Action::DiagnosticSave,
                if saved {
                    Outcome::Observed
                } else {
                    Outcome::Refused
                },
                None,
                None,
            )
            .await;
        }
    }
    Ok(result)
}
