fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        tauri_build::try_build(tauri_build::Attributes::new().app_manifest(
            tauri_build::AppManifest::new().commands(&[
                "get_snapshot",
                "get_engine_health",
                "subscribe_state",
                "unsubscribe_state",
                "create_draft",
                "reserve_operation",
                "select_file",
                "prepare_transfer",
                "get_operation",
                "diagnostic_summary",
                "policy_request",
                "select_policy_path",
                "ci_report",
            ]),
        ))
        .expect("Tauri permission/configuration generation failed");
    }
}
