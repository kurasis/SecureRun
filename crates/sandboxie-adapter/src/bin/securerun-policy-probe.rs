//! Fixed benign diagnostic executable. It refuses every unboxed invocation.
#[cfg(windows)]
fn main() {
    std::panic::set_hook(Box::new(|_| {}));
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        std::process::exit(64);
    }
    std::process::exit(securerun_sandboxie_adapter::windows::provisioning::run_canary(&args[1]));
}
#[cfg(not(windows))]
fn main() {
    eprintln!("The policy canary executes only inside a fresh Windows diagnostic box.");
}
