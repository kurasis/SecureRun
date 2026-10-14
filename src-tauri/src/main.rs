#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
#[cfg(windows)]
mod app;
#[cfg(all(windows, feature = "foundation-ci"))]
mod ci;
#[cfg(windows)]
mod native;

#[cfg(windows)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("--engine-worker") {
        std::panic::set_hook(Box::new(|_| {}));
        if args.len() != 4 {
            std::process::exit(64);
        }
        let (Ok(pid), Ok(birth)) = (args[2].parse(), args[3].parse()) else {
            std::process::exit(64);
        };
        let report = securerun_sandboxie_adapter::windows::observe(pid, birth);
        if let Ok(data) = serde_json::to_string(&report) {
            println!("{data}");
        } else {
            std::process::exit(65);
        }
        return;
    }
    if args.len() == 2 && args[1] == "--observation-once" {
        let report = securerun_sandboxie_adapter::windows::bounded_observe();
        if let Ok(data) = serde_json::to_string(&report) {
            println!("{data}");
        }
        return;
    }
    app::run();
}
#[cfg(not(windows))]
fn main() {
    eprintln!(
        "SecureRun's native application runs on Windows. Use cargo test -p securerun-foundation for portable data tests."
    );
}
