use securerun_foundation::*;
use std::{
    fs::{File, OpenOptions},
    os::windows::{fs::OpenOptionsExt, io::AsRawHandle},
    path::{Component, Path, Prefix},
    ptr,
};
use windows_sys::Win32::{
    Foundation::*,
    Security::Authorization::*,
    Security::*,
    Storage::FileSystem::*,
    System::{RemoteDesktop::*, Threading::*},
};

unsafe fn sid_text(sid: PSID) -> Result<String> {
    let mut text = ptr::null_mut();
    if unsafe { ConvertSidToStringSidW(sid, &mut text) } == 0 {
        return err(ErrorCode::Unauthorized);
    }
    let mut length = 0;
    while unsafe { *text.add(length) } != 0 {
        length += 1;
        if length > 184 {
            unsafe { LocalFree(text as _) };
            return err(ErrorCode::Unauthorized);
        }
    }
    let value = String::from_utf16(unsafe { std::slice::from_raw_parts(text, length) })
        .map_err(|_| AppError::new(ErrorCode::Unauthorized));
    unsafe { LocalFree(text as _) };
    value
}
pub fn current_sid() -> Result<String> {
    unsafe {
        let mut token = ptr::null_mut();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) == 0 {
            return err(ErrorCode::Unauthorized);
        }
        let mut bytes = 0;
        GetTokenInformation(token, TokenUser, ptr::null_mut(), 0, &mut bytes);
        if bytes == 0 || bytes > 16384 {
            CloseHandle(token);
            return err(ErrorCode::Unauthorized);
        }
        let mut data = vec![0u8; bytes as usize];
        let success =
            GetTokenInformation(token, TokenUser, data.as_mut_ptr() as _, bytes, &mut bytes);
        CloseHandle(token);
        if success == 0 {
            return err(ErrorCode::Unauthorized);
        }
        let user = ptr::read_unaligned(data.as_ptr() as *const TOKEN_USER);
        sid_text(user.User.Sid)
    }
}
pub fn session() -> Result<u32> {
    unsafe {
        let mut id = 0;
        if ProcessIdToSessionId(GetCurrentProcessId(), &mut id) == 0 {
            err(ErrorCode::Unauthorized)
        } else {
            Ok(id)
        }
    }
}
#[cfg(feature = "foundation-ci")]
pub fn administrator() -> Result<bool> {
    unsafe {
        let mut data = [0u8; 68];
        let mut bytes = 68u32;
        if CreateWellKnownSid(
            WinBuiltinAdministratorsSid,
            std::ptr::null_mut(),
            data.as_mut_ptr() as _,
            &mut bytes,
        ) == 0
        {
            return err(ErrorCode::Unauthorized);
        }
        let mut member = 0;
        if CheckTokenMembership(std::ptr::null_mut(), data.as_ptr() as _, &mut member) == 0 {
            return err(ErrorCode::Unauthorized);
        }
        Ok(member != 0)
    }
}
pub fn identify(file: &File) -> Result<FileIdentity> {
    unsafe {
        let handle = file.as_raw_handle();
        let mut data = std::mem::zeroed::<BY_HANDLE_FILE_INFORMATION>();
        if GetFileInformationByHandle(handle, &mut data) == 0
            || data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0
            || (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == 0 && data.nNumberOfLinks != 1)
        {
            return err(ErrorCode::PathUnsafe);
        }
        let mut owner = ptr::null_mut();
        let mut descriptor = ptr::null_mut();
        if GetSecurityInfo(
            handle,
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION,
            &mut owner,
            ptr::null_mut(),
            ptr::null_mut(),
            ptr::null_mut(),
            &mut descriptor,
        ) != 0
        {
            return err(ErrorCode::PathUnsafe);
        }
        let owner_sid = sid_text(owner);
        LocalFree(descriptor as _);
        Ok(FileIdentity {
            volume: data.dwVolumeSerialNumber as u64,
            file_id: format!("{:08x}{:08x}", data.nFileIndexHigh, data.nFileIndexLow),
            owner_sid: owner_sid?,
        })
    }
}
pub struct SelectionLease {
    pub file: File,
    pub parents: Vec<File>,
    pub identity: FileIdentity,
}
pub fn capture(path: &Path) -> Result<SelectionLease> {
    if !path.is_absolute()
        || !matches!(path.components().next(),Some(Component::Prefix(p)) if matches!(p.kind(),Prefix::Disk(_)|Prefix::VerbatimDisk(_)))
    {
        return err(ErrorCode::PathUnsafe);
    }
    let mut ancestors = path.ancestors().skip(1).collect::<Vec<_>>();
    ancestors.reverse();
    let mut parents = Vec::new();
    for parent in ancestors {
        let file = OpenOptions::new()
            .access_mode(FILE_READ_ATTRIBUTES | READ_CONTROL)
            .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
            .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
            .open(parent)
            .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
        identify(&file)?;
        parents.push(file);
    }
    let file = OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | READ_CONTROL)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
        .map_err(|_| AppError::new(ErrorCode::PathUnsafe))?;
    let identity = identify(&file)?;
    Ok(SelectionLease {
        file,
        parents,
        identity,
    })
}

#[cfg(feature = "foundation-ci")]
pub static PICKER_TITLE_SEEN: std::sync::atomic::AtomicBool =
    std::sync::atomic::AtomicBool::new(false);
#[cfg(feature = "foundation-ci")]
pub static PICKER_BUTTON_SEEN: std::sync::atomic::AtomicBool =
    std::sync::atomic::AtomicBool::new(false);
#[cfg(feature = "foundation-ci")]
pub fn accept_fixture_picker() {
    use windows_sys::Win32::UI::{
        Input::KeyboardAndMouse::IsWindowEnabled, WindowsAndMessaging::*,
    };
    unsafe extern "system" fn visit(hwnd: HWND, param: LPARAM) -> i32 {
        unsafe {
            let mut pid = 0;
            GetWindowThreadProcessId(hwnd, &mut pid);
            if pid != param as u32 {
                return 1;
            }
            let mut title = [0u16; 128];
            let len = GetWindowTextW(hwnd, title.as_mut_ptr(), 128);
            if String::from_utf16_lossy(&title[..len.max(0) as usize])
                != "SecureRun selection fixture"
            {
                return 1;
            }
            PICKER_TITLE_SEEN.store(true, std::sync::atomic::Ordering::Relaxed);
            let button = GetDlgItem(hwnd, 1);
            if button.is_null() || IsWindowEnabled(button) == 0 {
                return 1;
            }
            PICKER_BUTTON_SEEN.store(true, std::sync::atomic::Ordering::Relaxed);
            SendMessageW(button, BM_CLICK, 0, 0);
            0
        }
    }
    std::thread::spawn(|| {
        let deadline = std::time::Instant::now();
        while deadline.elapsed().as_secs() < 30 {
            // A freshly created dialog can expose its button before shell view
            // initialization completes. Retry the same scoped native click.
            unsafe { EnumWindows(Some(visit), GetCurrentProcessId() as isize) };
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
    });
}

/// Keep native picker COM state independent of reused asynchronous worker threads.
pub fn picker_thread<T: Send>(action: impl FnOnce() -> T + Send) -> Result<T> {
    std::thread::scope(|scope| {
        std::thread::Builder::new()
            .name("securerun-native-picker".into())
            .spawn_scoped(scope, action)
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))?
            .join()
            .map_err(|_| AppError::new(ErrorCode::CapabilityUnavailable))
    })
}

#[cfg(test)]
mod picker_tests {
    use super::*;
    #[link(name = "ole32")]
    unsafe extern "system" {
        fn CoInitializeEx(reserved: *const core::ffi::c_void, flags: u32) -> i32;
        fn CoUninitialize();
    }
    #[test]
    fn native_picker_apartment_is_independent_of_an_mta_caller() {
        assert!(unsafe { CoInitializeEx(std::ptr::null(), 0) } >= 0);
        let apartment = picker_thread(|| {
            let result = unsafe { CoInitializeEx(std::ptr::null(), 2) };
            if result >= 0 {
                unsafe { CoUninitialize() };
            }
            result
        });
        unsafe { CoUninitialize() };
        assert!(apartment.unwrap() >= 0);
    }
}
