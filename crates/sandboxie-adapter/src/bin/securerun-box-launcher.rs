//! Narrow boxed child creation stage. It has no host manager command surface.
#[cfg(windows)]
fn main() {
    use securerun_sandboxie_adapter::{
        control::command,
        files::{leaf, local_path},
    };
    use std::ptr;
    use windows_sys::Win32::{
        Foundation::*,
        System::{LibraryLoader::*, SystemInformation::*, Threading::*},
    };
    fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(Some(0)).collect()
    }
    type Query = unsafe extern "system" fn(HANDLE, *mut u16, *mut u16, *mut u16, *mut u32) -> i32;
    let module = unsafe { GetModuleHandleW(wide("SbieDll.dll").as_ptr()) };
    if module.is_null() {
        std::process::exit(91);
    }
    let Some(address) =
        (unsafe { GetProcAddress(module, c"SbieApi_QueryProcess".as_ptr().cast()) })
    else {
        std::process::exit(92)
    };
    let query: Query = unsafe { std::mem::transmute(address) };
    let mut name = [0u16; 40];
    let mut session = 0;
    if unsafe {
        query(
            GetCurrentProcessId() as usize as _,
            name.as_mut_ptr(),
            ptr::null_mut(),
            ptr::null_mut(),
            &mut session,
        )
    } != 0
    {
        std::process::exit(93);
    }
    let box_name =
        String::from_utf16_lossy(&name[..name.iter().position(|c| *c == 0).unwrap_or(40)]);
    let Some(environment) = box_name
        .strip_prefix("SR_")
        .and_then(|s| uuid::Uuid::parse_str(s).ok())
    else {
        std::process::exit(94)
    };
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    let Some(executable) = args.first() else {
        std::process::exit(64)
    };
    let expected = format!(
        "{}:\\SecureRunWorkspace\\{}\\",
        executable.chars().next().unwrap_or('_'),
        environment.simple()
    );
    if local_path(executable).is_err()
        || !executable.starts_with(&expected)
        || executable
            .strip_prefix(&expected)
            .is_none_or(|s| leaf(s).is_err() || !s.to_lowercase().ends_with(".exe"))
    {
        std::process::exit(65);
    }
    let Ok(command) = command(executable, &args[1..]) else {
        std::process::exit(66)
    };
    let mut command = wide(&command);
    let mut cwd = [0u16; 1024];
    let n = unsafe { GetSystemDirectoryW(cwd.as_mut_ptr(), 1024) };
    if n == 0 || n >= 1024 {
        std::process::exit(67);
    }
    let startup = STARTUPINFOW {
        cb: std::mem::size_of::<STARTUPINFOW>() as u32,
        ..Default::default()
    };
    let mut process = PROCESS_INFORMATION::default();
    // Exact application name, separately CRT-quoted argv, no shell/associations,
    // no environment expansion, no inherited handles and trusted stage CWD.
    if unsafe {
        CreateProcessW(
            wide(executable).as_ptr(),
            command.as_mut_ptr(),
            ptr::null(),
            ptr::null(),
            0,
            CREATE_NO_WINDOW | CREATE_SUSPENDED,
            ptr::null(),
            cwd.as_ptr(),
            &startup,
            &mut process,
        )
    } == 0
    {
        std::process::exit(68);
    }
    let mut child_box = [0u16; 40];
    let mut child_session = 0;
    if unsafe {
        query(
            process.dwProcessId as usize as _,
            child_box.as_mut_ptr(),
            ptr::null_mut(),
            ptr::null_mut(),
            &mut child_session,
        )
    } != 0
        || child_box != name
        || child_session != session
        || unsafe { ResumeThread(process.hThread) } == u32::MAX
    {
        unsafe {
            TerminateProcess(process.hProcess, 69);
            WaitForSingleObject(process.hProcess, 5000);
            CloseHandle(process.hThread);
            CloseHandle(process.hProcess);
        }
        std::process::exit(69);
    }
    unsafe {
        CloseHandle(process.hThread);
        WaitForSingleObject(process.hProcess, INFINITE);
        CloseHandle(process.hProcess);
    }
}
#[cfg(not(windows))]
fn main() {
    eprintln!("WINDOWS_ONLY");
}
