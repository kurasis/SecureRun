#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
#[cfg(windows)]
mod app;
#[cfg(all(windows, feature = "foundation-ci"))]
mod ci;
#[cfg(windows)]
mod native;

#[cfg(windows)]
fn main() {
    app::run();
}
#[cfg(not(windows))]
fn main() {
    eprintln!(
        "SecureRun's native application runs on Windows. Use cargo test -p securerun-foundation for portable data tests."
    );
}
