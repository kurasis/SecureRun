//! Generated synthetic aliases only; no renderer-selected reparse mutation API.
use super::*;

pub(super) fn junction(path: &Path, target: &Path, owner: &str) -> R<File> {
    let pin = fresh_directory(path, owner)?;
    let target = literal_path(target.to_str().ok_or("CANARY_SCOPE_INVALID")?)?;
    let substitute = wide(&format!("\\??\\{target}"));
    let print = wide(&target);
    let mut data = Vec::new();
    data.extend_from_slice(&0xa0000003u32.to_le_bytes());
    let length = 8 + (substitute.len() + print.len()) * 2;
    data.extend_from_slice(&(length as u16).to_le_bytes());
    data.extend_from_slice(&0u16.to_le_bytes());
    for value in [
        0u16,
        ((substitute.len() - 1) * 2) as u16,
        (substitute.len() * 2) as u16,
        ((print.len() - 1) * 2) as u16,
    ] {
        data.extend_from_slice(&value.to_le_bytes());
    }
    for character in substitute.into_iter().chain(print) {
        data.extend_from_slice(&character.to_le_bytes());
    }
    let file = OpenOptions::new()
        .access_mode(GENERIC_WRITE)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS)
        .open(path)
        .map_err(|_| "CANARY_ALIAS_CREATE_FAILED")?;
    let mut count = 0;
    if unsafe {
        windows_sys::Win32::System::IO::DeviceIoControl(
            file.as_raw_handle(),
            0x000900a4,
            data.as_ptr().cast(),
            data.len() as u32,
            ptr::null_mut(),
            0,
            &mut count,
            ptr::null_mut(),
        )
    } == 0
    {
        return Err("CANARY_ALIAS_CREATE_FAILED");
    }
    Ok(pin)
}
pub(super) fn short(path: &str) -> Option<String> {
    let mut data = [0u16; 1024];
    let length = unsafe { GetShortPathNameW(wide(path).as_ptr(), data.as_mut_ptr(), 1024) };
    if length == 0 || length >= 1024 {
        return None;
    }
    let short = text(&data).ok()?;
    (!short.eq_ignore_ascii_case(path)).then_some(short)
}
