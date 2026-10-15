//! Fixed synthetic production-path test target. No I/O while unboxed.
#[cfg(windows)]
#[expect(
    clippy::zombie_processes,
    reason = "Synthetic background descendants intentionally outlive their parent on Windows"
)]
fn main() {
    use std::{io::Write, os::windows::process::CommandExt};
    use windows_sys::Win32::{
        Foundation::*,
        System::{LibraryLoader::*, Threading::*},
    };
    type Query = unsafe extern "system" fn(HANDLE, *mut u16, *mut u16, *mut u16, *mut u32) -> i32;
    let module =
        unsafe { GetModuleHandleW("SbieDll.dll\0".encode_utf16().collect::<Vec<_>>().as_ptr()) };
    if module.is_null() {
        std::process::exit(91)
    }
    let Some(address) =
        (unsafe { GetProcAddress(module, c"SbieApi_QueryProcess".as_ptr().cast()) })
    else {
        std::process::exit(92)
    };
    let query: Query = unsafe { std::mem::transmute(address) };
    let mut name = [0u16; 40];
    let mut sid = [0u16; 96];
    let mut session = 0;
    if unsafe {
        query(
            GetCurrentProcessId() as usize as _,
            name.as_mut_ptr(),
            std::ptr::null_mut(),
            sid.as_mut_ptr(),
            &mut session,
        )
    } != 0
        || name[0] == 0
    {
        std::process::exit(93)
    }
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    if args.len() < 2 {
        std::process::exit(64)
    }
    let mode = &args[0];
    let output = &args[1];
    let expected = [
        "",
        "Unicode Привет 🧪",
        "spaces in argument",
        "a\"quote",
        "trailing\\",
        "/terminate_all",
        "& echo SHOULD_NOT_EXECUTE",
        "\\\"tail\\",
    ];
    let exact = mode != "arguments" || args[2..] == expected;
    let report =
        serde_json::json!({"boxed":true,"session":session,"arguments_exact":exact,"mode":mode});
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(output)
        .unwrap();
    writeln!(f, "{report}").unwrap();
    drop(f);
    if !exact {
        std::process::exit(94)
    }
    if mode == "tree" || mode == "background" || mode == "child" {
        let child_mode = if mode == "child" { "hold" } else { "child" };
        std::process::Command::new(std::env::current_exe().unwrap())
            .args([child_mode, output])
            .creation_flags(CREATE_NO_WINDOW)
            .spawn()
            .unwrap();
    }
    if mode != "short" && mode != "arguments" && mode != "background" {
        std::thread::sleep(std::time::Duration::from_secs(90));
    }
}
#[cfg(not(windows))]
fn main() {
    eprintln!("WINDOWS_ONLY");
}
