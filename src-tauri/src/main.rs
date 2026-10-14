#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
#[cfg(windows)]
mod app;
#[cfg(all(windows, feature = "foundation-ci"))]
mod ci;
#[cfg(windows)]
mod native;
#[cfg(windows)]
mod policies;

#[cfg(windows)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("--policy-worker")
        || (args.len() == 2 && args[1] == "--policy-once")
    {
        use std::io::Read;
        std::panic::set_hook(Box::new(|_| {}));
        let mut data = Vec::new();
        if std::io::stdin().take(16385).read_to_end(&mut data).is_err() || data.len() > 16384 {
            std::process::exit(64);
        }
        let Ok(request) =
            serde_json::from_slice::<securerun_sandboxie_adapter::provision::Request>(&data)
        else {
            std::process::exit(64);
        };
        let reply = if args[1] == "--policy-worker" {
            if args.len() != 4 {
                std::process::exit(64);
            }
            let (Ok(pid), Ok(birth)) = (args[2].parse(), args[3].parse()) else {
                std::process::exit(64);
            };
            securerun_sandboxie_adapter::windows::provisioning::execute(pid, birth, request)
        } else {
            securerun_sandboxie_adapter::windows::provisioning::bounded_request(&request)
        };
        if let Ok(text) = serde_json::to_string(&reply) {
            println!("{text}");
        }
        return;
    }
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
    if args.len() == 2 && args[1] == "--observation-watch" {
        use std::io::Write;
        let mut health = securerun_sandboxie_adapter::Health::default();
        for _ in 0..6 {
            let ticket = health.begin(std::time::Instant::now());
            let report = securerun_sandboxie_adapter::windows::bounded_observe();
            health.accept(ticket, report, std::time::Instant::now());
            if let Ok(data) = serde_json::to_string(&health.view(std::time::Instant::now())) {
                println!("{data}");
            }
            let _ = std::io::stdout().flush();
            std::thread::sleep(std::time::Duration::from_millis(500));
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
