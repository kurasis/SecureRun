//! Compiled only in the explicit foundation test binary. No engine implementation.
use crate::{app::CiCase, native};
use securerun_foundation::*;
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    net::TcpListener,
    path::{Path, PathBuf},
    sync::mpsc,
    time::{Duration, Instant},
};
use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindowBuilder};
use uuid::Uuid;

pub fn profile() -> Result<(PathBuf, File)> {
    let args = std::env::args().collect::<Vec<_>>();
    let index = args
        .iter()
        .position(|v| v == "--ci-run-id")
        .ok_or_else(|| AppError::new(ErrorCode::InvalidInput))?;
    let id = Uuid::parse_str(
        args.get(index + 1)
            .ok_or_else(|| AppError::new(ErrorCode::InvalidInput))?,
    )
    .map_err(|_| AppError::new(ErrorCode::InvalidInput))?;
    let profile = std::env::temp_dir().join(format!("SecureRunP03-{}", id.simple()));
    fs::create_dir(&profile).map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    let writer = OpenOptions::new()
        .create_new(true)
        .read(true)
        .write(true)
        .open(profile.join("writer.lock"))
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    writer
        .try_lock()
        .map_err(|_| AppError::new(ErrorCode::Unauthorized))?;
    fs::write(profile.join("selection.txt"), "P03_SYNTHETIC_SELECTION")
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    Ok((profile, writer))
}
const REMOTE: &str = r#"<!doctype html><title>Unauthorized origin fixture</title><script>
(async()=>{window.__foundationRemoteStarted=true;let denied=true;for(const command of ['get_snapshot','create_draft','reserve_operation','diagnostic_summary','ci_report','policy_request','select_policy_path','control_request','files_request','lifecycle_request','product_request']){
if(window.__TAURI_INTERNALS__){try{await window.__TAURI_INTERNALS__.invoke(command,{request:{display_name:'UNAUTHORIZED'},cases:[]});denied=false;window.__foundationRemoteCommandAccepted=true}catch(error){const acl=typeof error==='string' && /not allowed|permission|capability|scope/i.test(error);denied &&= acl;if(!acl)window.__foundationRemoteUnexpectedDenial=true}}}
window.__foundationAclDenied=denied;})();</script>"#;
pub fn start(
    app: AppHandle,
    profile: PathBuf,
) -> std::result::Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let address = listener.local_addr()?;
    listener.set_nonblocking(true)?;
    std::thread::spawn(move || {
        let deadline = Instant::now();
        let mut requests = 0;
        while deadline.elapsed().as_secs() < 120 && requests < 32 {
            if let Ok((mut stream, _)) = listener.accept() {
                let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));
                let mut request = [0u8; 4096];
                let read = stream.read(&mut request).unwrap_or(0);
                if read == 0 || !request[..read].starts_with(b"GET ") {
                    continue;
                }
                requests += 1;
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    REMOTE.len(),
                    REMOTE
                );
                let _ = stream.write_all(response.as_bytes());
            } else {
                std::thread::sleep(Duration::from_millis(20));
            }
        }
    });
    WebviewWindowBuilder::new(
        &app,
        "unauthorized-local",
        WebviewUrl::App("index.html?acl-probe".into()),
    )
    .use_https_scheme(true)
    .title("Unauthorized local fixture")
    .build()?;
    let url = tauri::Url::parse(&format!("http://{address}/"))?;
    let expected = url.clone();
    WebviewWindowBuilder::new(&app, "unauthorized-remote", WebviewUrl::External(url))
        .on_navigation(move |url| url == &expected)
        .title("Unauthorized remote fixture")
        .build()?;
    let timeout_app = app.clone();
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_secs(120));
        if !profile.join("command-boundary.json").exists() {
            let diagnostic = serde_json::json!({"result":"FAILED","diagnostic_code":"WEBVIEW_TEST_TIMEOUT","script_started":script_bool(&timeout_app,"main","window.__foundationTestsStarted === true"),"picker_waiting":script_bool(&timeout_app,"main","window.__foundationPickerWaiting === true"),"report_started":script_bool(&timeout_app,"main","window.__foundationReportStarted === true"),"native_dialog_title_seen":native::PICKER_TITLE_SEEN.load(std::sync::atomic::Ordering::Relaxed),"native_dialog_button_seen":native::PICKER_BUTTON_SEEN.load(std::sync::atomic::Ordering::Relaxed)});
            let _ = fs::write(
                profile.join("command-boundary.json"),
                serde_json::to_vec_pretty(&diagnostic).unwrap_or_default(),
            );
            timeout_app.exit(1);
        }
    });
    Ok(())
}
fn script_bool(app: &AppHandle, label: &str, script: &'static str) -> bool {
    let Some(window) = app.get_webview_window(label) else {
        return false;
    };
    let (sender, receiver) = mpsc::channel();
    let result = window.with_webview(move |view| unsafe {
        if let Ok(core) = view.controller().CoreWebView2() {
            let callback = webview2_com::ExecuteScriptCompletedHandler::create(Box::new(
                move |status, result| {
                    let _ = sender.send(status.is_ok() && result == "true");
                    Ok(())
                },
            ));
            let _ = core.ExecuteScript(&windows::core::HSTRING::from(script), &callback);
        }
    });
    result.is_ok()
        && receiver
            .recv_timeout(Duration::from_secs(3))
            .unwrap_or(false)
}
fn wait_denied(app: &AppHandle, label: &str) -> bool {
    let start = Instant::now();
    while start.elapsed().as_secs() < 15 {
        if script_bool(app, label, "window.__foundationAclDenied === true") {
            return true;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    false
}
fn artifact_test(profile: &Path) -> Result<bool> {
    let owner = native::current_sid()?;
    let mut store = Store::open(&profile.join("artifact-recovery.sqlite"), &owner)?;
    let env = store.create_draft("Artifact recovery fixture")?;
    let (op, _) = store.reserve(
        &ReservationRequest {
            environment_id: env.id,
            expected_generation: 1,
            expected_revision: 0,
            idempotency_key: Uuid::new_v4(),
            kind: OperationKind::Import,
        },
        native::session()?,
    )?;
    let path = profile.join("stage.txt");
    fs::write(&path, "P03_CREATED_ARTIFACT")
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    let lease = native::capture(&path)?;
    let parent = native::capture(profile)?;
    let record = ArtifactRecord {
        id: Uuid::new_v4(),
        operation_id: op.id,
        environment_generation: 1,
        parent_identity: parent.identity.clone(),
        identity: lease.identity.clone(),
        role: ArtifactRole::ImportStaging,
        leaf_name: "stage.txt".to_owned(),
    };
    store.record_artifact(&record)?;
    drop(lease);
    fs::rename(&path, profile.join("stage.original"))
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    fs::write(&path, "P03_REPLACEMENT_CANARY")
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    let replacement = native::capture(&path)?;
    let refused = store
        .reconcile_artifact(record.id, &parent.identity, &replacement.identity)
        .err()
        .is_some_and(|e| e.code == ErrorCode::IdentityMismatch);
    store.invalidate_environment(env.id, 1, 0)?;
    let stale = store
        .reconcile_artifact(record.id, &parent.identity, &record.identity)
        .err()
        .is_some_and(|e| e.code == ErrorCode::StaleOperation);
    Ok(refused
        && stale
        && fs::read(&path).map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?
            == b"P03_REPLACEMENT_CANARY")
}
pub fn finish(app: &AppHandle, profile: &Path, mut cases: Vec<CiCase>) -> Result<()> {
    cases.push(CiCase {
        id: "T49".into(),
        name: "standard_user_token_observed".into(),
        passed: native::administrator().is_ok_and(|value| !value),
    });
    cases.push(CiCase {
        id: "T49".into(),
        name: "local_ungranted_webview_denied".into(),
        passed: wait_denied(app, "unauthorized-local"),
    });
    cases.push(CiCase {
        id: "T49".into(),
        name: "remote_origin_commands_denied".into(),
        passed: wait_denied(app, "unauthorized-remote"),
    });
    let remote_started = script_bool(
        app,
        "unauthorized-remote",
        "window.__foundationRemoteStarted === true",
    );
    let remote_accepted = script_bool(
        app,
        "unauthorized-remote",
        "window.__foundationRemoteCommandAccepted === true",
    );
    let remote_unexpected = script_bool(
        app,
        "unauthorized-remote",
        "window.__foundationRemoteUnexpectedDenial === true",
    );
    cases.push(CiCase {
        id: "T65".into(),
        name: "actual_replaced_windows_artifact_retained".into(),
        passed: artifact_test(profile).unwrap_or(false),
    });
    let local = fs::read_to_string(profile.join("local-diagnostics.json"))
        .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    let redacted = !local.contains("P03_SYNTHETIC_SECRET") && !local.contains("FORGED_EVENT");
    cases.push(CiCase {
        id: "T66".into(),
        name: "local_log_and_shared_bundle_minimized".into(),
        passed: redacted,
    });
    let passed = cases.iter().all(|c| c.passed) && cases.len() >= 10;
    let report = serde_json::json!({"phase":"P03","result":if passed{"PASSED"}else{"FAILED"},"real_webview2":true,"real_native_picker":true,"engine_operations_executed":0,"cases":cases,"remote_probe_started":remote_started,"remote_command_accepted":remote_accepted,"remote_unexpected_denial":remote_unexpected});
    fs::write(
        profile.join("command-boundary.json"),
        serde_json::to_vec_pretty(&report).map_err(|_| AppError::new(ErrorCode::CorruptRecord))?,
    )
    .map_err(|_| AppError::new(ErrorCode::DatabaseUnavailable))?;
    app.exit(if passed { 0 } else { 1 });
    Ok(())
}
