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
    let mapping_verified = if mode == "mapping" {
        use std::os::windows::io::AsRawHandle;
        type Mapping = unsafe extern "system" fn(HANDLE, *mut u16, *mut u8) -> u32;
        type Translate = unsafe extern "system" fn(*mut u16) -> u8;
        let map = unsafe { GetProcAddress(module, c"SbieDll_GetHandlePath".as_ptr().cast()) };
        let translate =
            unsafe { GetProcAddress(module, c"SbieDll_TranslateNtToDosPath".as_ptr().cast()) };
        if let (Some(map), Some(translate), Some(expected)) = (map, translate, args.get(2)) {
            let map: Mapping = unsafe { std::mem::transmute(map) };
            let translate: Translate = unsafe { std::mem::transmute(translate) };
            let file = std::fs::File::open(std::env::current_exe().unwrap()).unwrap();
            let mut path = [0u16; 4096];
            let mut boxed = 0;
            (unsafe { map(file.as_raw_handle(), path.as_mut_ptr(), &mut boxed) }) == 0
                && boxed != 0
                && unsafe { translate(path.as_mut_ptr()) } != 0
                && String::from_utf16_lossy(
                    &path[..path.iter().position(|c| *c == 0).unwrap_or(path.len())],
                )
                .eq_ignore_ascii_case(expected)
        } else {
            false
        }
    } else {
        true
    };
    let report = serde_json::json!({"boxed":true,"mapping_verified":mapping_verified,"environment_clean":std::env::var_os("SECURERUN_P06_SECRET").is_none(),"session":session,"arguments_exact":exact,"cwd_exact":mode!="cwd" || args.get(2).is_some_and(|p|std::env::current_dir().ok().is_some_and(|cwd|cwd.to_string_lossy().eq_ignore_ascii_case(p))),"mode":mode});
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
    if mode != "short" && mode != "arguments" && mode != "background" && mode != "cwd" {
        std::thread::sleep(std::time::Duration::from_secs(
            if mode == "exit-during-stop" { 8 } else { 90 },
        ));
    }
}
#[cfg(not(windows))]
fn main() {
    eprintln!("WINDOWS_ONLY");
}
