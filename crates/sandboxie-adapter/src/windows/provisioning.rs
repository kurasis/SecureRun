//! User-privilege provisioning. No helper, arbitrary target, global write or raw INI API.
use super::*;
use crate::{policy::*, provision::*};
use std::{io::Write, os::windows::io::FromRawHandle};
use uuid::Uuid;
mod aliases;
pub mod control;
pub mod files;
pub mod lifecycle;
mod network;
pub mod product;
use windows_sys::Win32::{
    System::{Com::CoTaskMemFree, RemoteDesktop::ProcessIdToSessionId},
    UI::Shell::*,
};

type Update = unsafe extern "system" fn(u16, *const u16, *const u16, *const u16, *const u16) -> u32;
type Reload = unsafe extern "system" fn(u32, u32) -> i32;
type Run = unsafe extern "system" fn(
    *const u16,
    *const u16,
    *const u16,
    u32,
    *mut STARTUPINFOW,
    *mut PROCESS_INFORMATION,
) -> i32;
unsafe fn bind<T: Copy>(api: &Api, name: &'static [u8]) -> R<T> {
    let address =
        unsafe { GetProcAddress(api.module, name.as_ptr()) }.ok_or("ABI_EXPORT_MISSING")?;
    if std::mem::size_of::<T>() != std::mem::size_of_val(&address) {
        return Err("ABI_EXPORT_MISSING");
    }
    Ok(unsafe { std::mem::transmute_copy(&address) })
}
fn process_sid(process: HANDLE) -> R<String> {
    unsafe {
        let mut raw = ptr::null_mut();
        if OpenProcessToken(process, TOKEN_QUERY, &mut raw) == 0 {
            return Err("OWNER_IDENTITY_UNKNOWN");
        }
        let token = Handle(raw);
        let mut count = 0;
        GetTokenInformation(token.0, TokenUser, ptr::null_mut(), 0, &mut count);
        if count == 0 || count > 16384 {
            return Err("OWNER_IDENTITY_UNKNOWN");
        }
        let mut data = vec![0u8; count as usize];
        if GetTokenInformation(
            token.0,
            TokenUser,
            data.as_mut_ptr() as _,
            count,
            &mut count,
        ) == 0
        {
            return Err("OWNER_IDENTITY_UNKNOWN");
        }
        let user = ptr::read_unaligned(data.as_ptr() as *const TOKEN_USER);
        sid_string(user.User.Sid)
    }
}
fn os_identity() -> R<String> {
    // RtlGetVersion returns the actual kernel version independent of application
    // compatibility manifests. An OS update must expire cached enforcement.
    type Version = unsafe extern "system" fn(*mut OSVERSIONINFOW) -> i32;
    let module = unsafe { GetModuleHandleW(wide("ntdll.dll").as_ptr()) };
    let address = unsafe { GetProcAddress(module, c"RtlGetVersion".as_ptr().cast()) }
        .ok_or("OS_VERSION_UNKNOWN")?;
    let version: Version = unsafe { std::mem::transmute(address) };
    let mut info = OSVERSIONINFOEXW {
        dwOSVersionInfoSize: std::mem::size_of::<OSVERSIONINFOEXW>() as u32,
        ..Default::default()
    };
    if unsafe { version((&mut info as *mut OSVERSIONINFOEXW).cast()) } != 0 {
        return Err("OS_VERSION_UNKNOWN");
    }
    Ok(fingerprint(&(
        info.dwMajorVersion,
        info.dwMinorVersion,
        info.dwBuildNumber,
        info.wProductType,
        std::env::consts::ARCH,
    )))
}
fn session_owner(session: u32) -> R<String> {
    use windows_sys::Win32::System::RemoteDesktop::*;
    fn field(session: u32, kind: WTS_INFO_CLASS) -> R<String> {
        let mut value = ptr::null_mut();
        let mut bytes = 0;
        if unsafe {
            WTSQuerySessionInformationW(
                WTS_CURRENT_SERVER_HANDLE,
                session,
                kind,
                &mut value,
                &mut bytes,
            )
        } == 0
            || value.is_null()
        {
            return Err("DIAGNOSTIC_SESSION_OWNER_UNKNOWN");
        }
        let result = if bytes > 0 && bytes <= 1024 {
            unsafe { pointer_text(value, (bytes / 2) as usize) }
        } else {
            Err("DIAGNOSTIC_SESSION_OWNER_UNKNOWN")
        };
        unsafe { WTSFreeMemory(value.cast()) };
        result
    }
    let user = field(session, WTSUserName)?;
    let domain = field(session, WTSDomainName)?;
    if user.is_empty() {
        return Err("DIAGNOSTIC_SESSION_OWNER_UNKNOWN");
    }
    let account = wide(&format!("{domain}\\{user}"));
    let mut size = 184;
    let mut sid = [0u64; 23];
    let mut domain_name = [0u16; 256];
    let mut domain_size = 256;
    let mut kind = 0;
    if unsafe {
        LookupAccountNameW(
            ptr::null(),
            account.as_ptr(),
            sid.as_mut_ptr().cast(),
            &mut size,
            domain_name.as_mut_ptr(),
            &mut domain_size,
            &mut kind,
        )
    } == 0
        || kind != SidTypeUser
    {
        return Err("DIAGNOSTIC_SESSION_OWNER_UNKNOWN");
    }
    unsafe { sid_string(sid.as_mut_ptr().cast()) }
}
pub fn profile_path() -> R<PathBuf> {
    let mut raw = ptr::null_mut();
    if unsafe { SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, ptr::null_mut(), &mut raw) } != 0 {
        return Err("KNOWN_FOLDER_UNAVAILABLE");
    }
    let value = unsafe { pointer_text(raw, 1024) };
    unsafe { CoTaskMemFree(raw as _) };
    Ok(PathBuf::from(literal_path(&value?)?).join("SecureRun"))
}
fn fixed_ntfs(path: &Path) -> R<()> {
    let value = path.to_str().ok_or("PATH_GRAMMAR_UNSUPPORTED")?;
    literal_path(value)?;
    fixed_ntfs_volume(path)
}
fn fixed_ntfs_volume(path: &Path) -> R<()> {
    let value = path.to_str().ok_or("PATH_GRAMMAR_UNSUPPORTED")?;
    let volume = wide(&value[..3]);
    let drive = wide(&value[..2]);
    let mut mapping = [0u16; 1024];
    if unsafe { QueryDosDeviceW(drive.as_ptr(), mapping.as_mut_ptr(), 1024) } == 0 {
        return Err("DOS_NAMESPACE_UNKNOWN");
    }
    let device = text(&mapping)?;
    let Some(number) = device.strip_prefix("\\Device\\HarddiskVolume") else {
        return Err("DOS_NAMESPACE_ALIAS_UNSUPPORTED");
    };
    if number.is_empty() || !number.bytes().all(|b| b.is_ascii_digit()) {
        return Err("DOS_NAMESPACE_ALIAS_UNSUPPORTED");
    }
    let mut fs = [0u16; 32];
    if unsafe { GetDriveTypeW(volume.as_ptr()) } != DRIVE_FIXED
        || unsafe {
            GetVolumeInformationW(
                volume.as_ptr(),
                ptr::null_mut(),
                0,
                ptr::null_mut(),
                ptr::null_mut(),
                ptr::null_mut(),
                fs.as_mut_ptr(),
                32,
            )
        } == 0
        || text(&fs)? != "NTFS"
    {
        return Err("FIXED_NTFS_REQUIRED");
    }
    Ok(())
}
fn canonical(path: &Path) -> R<Vec<File>> {
    canonical_sharing(path, FILE_SHARE_READ)
}
// Transfer directory leases exclude DELETE while permitting the kernel's
// rename-target directory open. Existing provisioning callers keep their
// original stricter sharing mode.
fn canonical_sharing(path: &Path, sharing: u32) -> R<Vec<File>> {
    canonical_validated(path, sharing, false)
}
fn canonical_validated(path: &Path, sharing: u32, file_names: bool) -> R<Vec<File>> {
    if file_names {
        crate::files::local_path(path.to_str().ok_or("FILE_PATH_GRAMMAR_UNSUPPORTED")?)?;
        fixed_ntfs_volume(path)?;
    } else {
        fixed_ntfs(path)?;
    }
    let mut paths = path.ancestors().collect::<Vec<_>>();
    paths.reverse();
    let held = paths
        .into_iter()
        .map(|p| {
            let f = OpenOptions::new()
                .access_mode(FILE_READ_ATTRIBUTES | READ_CONTROL)
                .share_mode(sharing)
                .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
                .open(p)
                .map_err(|_| "PATH_LEASE_UNAVAILABLE")?;
            identity(&f)?;
            Ok(f)
        })
        .collect::<R<Vec<File>>>()?;
    let value = path.to_str().ok_or("PATH_GRAMMAR_UNSUPPORTED")?;
    let mut final_name = [0u16; 1024];
    let n = unsafe {
        GetFinalPathNameByHandleW(
            held.last().ok_or("PATH_IDENTITY_UNKNOWN")?.as_raw_handle(),
            final_name.as_mut_ptr(),
            1024,
            FILE_NAME_NORMALIZED | VOLUME_NAME_DOS,
        )
    };
    if n == 0
        || n >= 1024
        || !text(&final_name)?
            .strip_prefix("\\\\?\\")
            .is_some_and(|s| s.eq_ignore_ascii_case(value))
    {
        return Err("PATH_ALIAS_UNSUPPORTED");
    }
    let mut long = [0u16; 1024];
    let n = unsafe { GetLongPathNameW(wide(value).as_ptr(), long.as_mut_ptr(), 1024) };
    if n == 0 || n >= 1024 || !text(&long)?.eq_ignore_ascii_case(value) {
        return Err("PATH_ALIAS_UNSUPPORTED");
    }
    for file in &held {
        let mut info = std::mem::MaybeUninit::<BY_HANDLE_FILE_INFORMATION>::zeroed();
        if unsafe { GetFileInformationByHandle(file.as_raw_handle(), info.as_mut_ptr()) } == 0 {
            return Err("PATH_IDENTITY_UNKNOWN");
        }
        if unsafe { info.assume_init() }.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0 {
            let mut flags = 0u32;
            if unsafe {
                GetFileInformationByHandleEx(
                    file.as_raw_handle(),
                    FileCaseSensitiveInfo,
                    &mut flags as *mut _ as _,
                    4,
                )
            } == 0
                || flags != 0
            {
                return Err("CASE_SENSITIVE_PATH_UNSUPPORTED");
            }
        }
    }
    Ok(held)
}
fn private(file: &File, owner_sid: &str) -> R<()> {
    unsafe {
        let mut owner = ptr::null_mut();
        let mut dacl = ptr::null_mut();
        let mut sd = ptr::null_mut();
        if GetSecurityInfo(
            file.as_raw_handle(),
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            &mut owner,
            ptr::null_mut(),
            &mut dacl,
            ptr::null_mut(),
            &mut sd,
        ) != 0
        {
            return Err("ROOT_ACL_UNKNOWN");
        }
        let result = (|| {
            let mut control = 0u16;
            let mut revision = 0u32;
            if sid_string(owner)? != owner_sid
                || dacl.is_null()
                || GetSecurityDescriptorControl(sd, &mut control, &mut revision) == 0
                || control & SE_DACL_PROTECTED == 0
            {
                return Err("ROOT_ACL_UNSAFE");
            }
            if (*dacl).AceCount > 16 {
                return Err("ROOT_ACL_UNSAFE");
            }
            let mut owner_allowed = false;
            let mut system_allowed = false;
            for i in 0..(*dacl).AceCount as u32 {
                let mut ace = ptr::null_mut();
                if GetAce(dacl, i, &mut ace) == 0 {
                    return Err("ROOT_ACL_UNKNOWN");
                }
                let head = &*(ace as *const ACE_HEADER);
                if head.AceType != 0 {
                    return Err("ROOT_ACL_UNSAFE");
                }
                let allow = &*(ace as *const ACCESS_ALLOWED_ACE);
                let sid = sid_string(&allow.SidStart as *const _ as _)?;
                if ![owner_sid, "S-1-5-18", "S-1-5-32-544"].contains(&sid.as_str()) {
                    return Err("ROOT_ACL_UNSAFE");
                }
                if allow.Mask & FILE_ALL_ACCESS != FILE_ALL_ACCESS || head.AceFlags & 3 != 3 {
                    return Err("ROOT_ACL_UNSAFE");
                }
                owner_allowed |= sid == owner_sid;
                system_allowed |= sid == "S-1-5-18";
            }
            if !owner_allowed || !system_allowed {
                return Err("ROOT_ACL_UNSAFE");
            }
            Ok(())
        })();
        LocalFree(sd as _);
        result
    }
}
#[repr(C)]
struct NtName {
    length: u16,
    maximum: u16,
    buffer: *const u16,
}
#[repr(C)]
struct NtAttributes {
    length: u32,
    root: HANDLE,
    name: *const NtName,
    flags: u32,
    security: *mut c_void,
    qos: *mut c_void,
}
#[repr(C)]
struct IoStatus {
    status: usize,
    information: usize,
}
#[link(name = "ntdll")]
unsafe extern "system" {
    fn NtCreateFile(
        handle: *mut HANDLE,
        access: u32,
        attributes: *const NtAttributes,
        status: *mut IoStatus,
        allocation: *const i64,
        file_attributes: u32,
        share: u32,
        disposition: u32,
        options: u32,
        ea: *const c_void,
        ea_size: u32,
    ) -> i32;
}
fn fresh_directory(path: &Path, owner: &str) -> R<File> {
    fresh_directory_validated(path, owner, false)
}
fn fresh_directory_validated(path: &Path, owner: &str, file_names: bool) -> R<File> {
    if file_names {
        crate::files::local_path(path.to_str().ok_or("FILE_PATH_GRAMMAR_UNSUPPORTED")?)?;
        fixed_ntfs_volume(path)?;
    } else {
        fixed_ntfs(path)?;
    }
    let parent = path.parent().ok_or("ROOT_PARENT_UNSAFE")?;
    let held = canonical_validated(
        parent,
        if file_names {
            FILE_SHARE_READ | FILE_SHARE_WRITE
        } else {
            FILE_SHARE_READ
        },
        file_names,
    )?;
    let leaf = path
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or("ROOT_LEAF_UNSAFE")?;
    if leaf.contains(['\\', '/', ':']) || leaf.len() > 64 {
        return Err("ROOT_LEAF_UNSAFE");
    }
    let leaf = wide(leaf);
    let name = NtName {
        length: ((leaf.len() - 1) * 2) as u16,
        maximum: (leaf.len() * 2) as u16,
        buffer: leaf.as_ptr(),
    };
    let mut descriptor = ptr::null_mut();
    let sddl = wide(&format!(
        "O:{owner}D:P(A;OICI;FA;;;{owner})(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"
    ));
    if unsafe {
        ConvertStringSecurityDescriptorToSecurityDescriptorW(
            sddl.as_ptr(),
            1,
            &mut descriptor,
            ptr::null_mut(),
        )
    } == 0
    {
        return Err("ROOT_ACL_CREATE_FAILED");
    }
    let attr = NtAttributes {
        length: std::mem::size_of::<NtAttributes>() as u32,
        root: held.last().ok_or("ROOT_PARENT_UNSAFE")?.as_raw_handle(),
        name: &name,
        flags: 0x40,
        security: descriptor,
        qos: ptr::null_mut(),
    };
    let mut status = IoStatus {
        status: 0,
        information: 0,
    };
    let mut raw = ptr::null_mut();
    let rc = unsafe {
        NtCreateFile(
            &mut raw,
            0x120081,
            &attr,
            &mut status,
            ptr::null(),
            FILE_ATTRIBUTE_DIRECTORY,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            2,
            0x00200021,
            ptr::null(),
            0,
        )
    };
    unsafe { LocalFree(descriptor as _) };
    if rc != 0 {
        return Err(if rc as u32 == 0xc0000035 {
            "PREEXISTING_ROOT_NOT_ADOPTED"
        } else {
            "ROOT_NATIVE_CREATE_FAILED"
        });
    }
    let file = unsafe { File::from_raw_handle(raw) };
    identity(&file)?;
    private(&file, owner)?;
    Ok(file)
}
fn ensure_private(path: &Path, owner: &str) -> R<Vec<File>> {
    match std::fs::symlink_metadata(path) {
        Ok(_) => {}
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            match fresh_directory(path, owner) {
                Ok(f) => drop(f),
                Err("PREEXISTING_ROOT_NOT_ADOPTED") => {}
                Err(code) => return Err(code),
            };
        }
        Err(_) => return Err("PROFILE_UNAVAILABLE"),
    }
    let held = canonical(path)?;
    private(held.last().ok_or("PROFILE_UNAVAILABLE")?, owner)?;
    Ok(held)
}
fn read_section(api: &Api, name: &str, effective: bool) -> R<Section> {
    let mut keys = std::collections::BTreeSet::new();
    let mut ended = false;
    for i in 0..128 {
        match api.conf(
            Some(name),
            None,
            i | if effective { 0x60000000 } else { RAW_FLAGS },
        )? {
            Some(key) => {
                if key.len() > 64 || !key.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_') {
                    return Err("CONFIGURATION_KEY_UNSUPPORTED");
                }
                keys.insert(key);
            }
            None => {
                ended = true;
                break;
            }
        }
    }
    if !ended {
        return Err("CONFIGURATION_KEY_BOUND");
    }
    // Effective inherited globals must be inspected even if absent in the local section.
    if effective {
        for key in read_section(api, "GlobalSettings", false)?.keys() {
            keys.insert(key.clone());
        }
    }
    let mut section = Section::new();
    for key in keys {
        // Never read configuration credential contents.
        if key.eq_ignore_ascii_case("EditPassword") {
            return Err("PASSWORD_PROTECTED_CONFIGURATION");
        }
        let mut values = api.values(name, &key, if effective { 0 } else { RAW_FLAGS })?;
        // Pinned Conf_Expand_Helper translates DOS paths to NT device paths.
        // Compare filesystem rules only after the original inverse translator;
        // preserve ordering, wildcards and complete inherited values.
        if effective
            && matches!(
                key.as_str(),
                "FileRootPath" | "ClosedFilePath" | "ReadFilePath"
            )
        {
            for value in &mut values {
                if value.starts_with("\\Device\\") || value.starts_with("\\??\\") {
                    let encoded = wide(value);
                    if encoded.len() > 2048 {
                        return Err("EFFECTIVE_PATH_BOUND");
                    }
                    let mut buffer = [0u16; 4096];
                    buffer[..encoded.len()].copy_from_slice(&encoded);
                    if unsafe { (api.translate)(buffer.as_mut_ptr()) } == 0 {
                        return Err("EFFECTIVE_PATH_TRANSLATION_UNKNOWN");
                    }
                    *value = text(&buffer)?;
                }
            }
        }
        if !values.is_empty() {
            section.insert(key, values);
        }
    }
    if serde_json::to_vec(&section)
        .map_err(|_| "CONFIGURATION_UNKNOWN")?
        .len()
        > 65536
    {
        return Err("CONFIGURATION_BOUND");
    }
    Ok(section)
}
fn unexpanded_inheritance(api: &Api, name: &str) -> R<Section> {
    let mut result = Section::new();
    for i in 0..128 {
        let Some(key) = api.conf(Some(name), None, i | 0x60000000)? else {
            return Ok(result);
        };
        if key.eq_ignore_ascii_case("EditPassword") {
            return Err("PASSWORD_PROTECTED_CONFIGURATION");
        }
        result.insert(key.clone(), api.values(name, &key, 0x60000000)?);
    }
    Err("CONFIGURATION_KEY_BOUND")
}
fn template_pin(trusted: &Trusted) -> R<File> {
    let mut file = lease(&trusted.home.join("Templates.ini"), false)?;
    protected(&file)?;
    let mut bytes = vec![];
    Read::by_ref(&mut file)
        .take(524289)
        .read_to_end(&mut bytes)
        .map_err(|_| "TEMPLATE_FILE_UNAVAILABLE")?;
    if bytes.len() > 524288 {
        return Err("TEMPLATE_FILE_BOUND");
    }
    let text = if bytes.starts_with(&[0xff, 0xfe]) {
        if !bytes.len().is_multiple_of(2) {
            return Err("TEMPLATE_FILE_ENCODING");
        }
        let units = bytes[2..]
            .chunks_exact(2)
            .map(|c| u16::from_le_bytes([c[0], c[1]]))
            .collect::<Vec<_>>();
        String::from_utf16(&units).map_err(|_| "TEMPLATE_FILE_ENCODING")?
    } else {
        String::from_utf8(bytes)
            .map_err(|_| "TEMPLATE_FILE_ENCODING")?
            .trim_start_matches('\u{feff}')
            .to_owned()
    };
    let digest = format!(
        "{:x}",
        Sha256::digest(text.replace("\r\n", "\n").as_bytes())
    );
    let pin: serde_json::Value =
        serde_json::from_str(COMPATIBILITY).map_err(|_| "MANIFEST_INVALID")?;
    if pin["policy_inheritance"]["normalized_utf8_sha256"] != digest {
        return Err("TEMPLATE_FILE_UNTESTED_OR_CHANGED");
    }
    Ok(file)
}
fn bfe_ready() -> bool {
    unsafe {
        let scm = OpenSCManagerW(ptr::null(), ptr::null(), SC_MANAGER_CONNECT);
        if scm.is_null() {
            return false;
        }
        let svc = OpenServiceW(scm, wide("BFE").as_ptr(), SERVICE_QUERY_STATUS);
        CloseServiceHandle(scm);
        if svc.is_null() {
            return false;
        }
        let mut status = std::mem::zeroed::<SERVICE_STATUS_PROCESS>();
        let mut count = 0;
        let ok = QueryServiceStatusEx(
            svc,
            SC_STATUS_PROCESS_INFO,
            &mut status as *mut _ as _,
            std::mem::size_of_val(&status) as u32,
            &mut count,
        ) != 0
            && status.dwCurrentState == SERVICE_RUNNING;
        CloseServiceHandle(svc);
        ok
    }
}
struct NativeEngine {
    api: Api,
    parent: Handle,
    parent_pid: u32,
    parent_birth: u64,
    trusted: Trusted,
    owner: String,
    profile: PathBuf,
    image: PathBuf,
    manager_hash: String,
    os_identity: String,
    probe: PathBuf,
    probe_hash: String,
    additional_probes: Vec<(PathBuf, String)>,
    _leases: Vec<File>,
    root_leases: std::cell::RefCell<Vec<File>>,
}
impl NativeEngine {
    fn new(manager_pid: u32, manager_birth: u64) -> R<Self> {
        // This checks held OS identities, protected SCM/component configuration and
        // the actual driver response. It does not invent a service process birth.
        let observed = observe(manager_pid, manager_birth);
        if observed.trust != "VERIFIED"
            || observed.reason != "OBSERVED"
            || observed.manager_context != Context::Unboxed
            || observed.bridge_context != Context::Unboxed
        {
            return Err("MANAGER_CONTEXT_UNSAFE");
        }
        let trusted = discover()?;
        let api = Api::load(&trusted.home)?;
        if api.context(unsafe { GetCurrentProcessId() }) != Context::Unboxed
            || api.context(manager_pid) != Context::Unboxed
        {
            return Err("MANAGER_CONTEXT_UNSAFE");
        }
        let owner = process_sid(unsafe { GetCurrentProcess() })?;
        let os_identity = os_identity()?;
        let parent = unsafe {
            OpenProcess(
                PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE,
                0,
                manager_pid,
            )
        };
        if parent.is_null() {
            return Err("MANAGER_IDENTITY_UNKNOWN");
        }
        let parent = Handle(parent);
        if process_sid(parent.0)? != owner
            || birth(&parent)? != manager_birth
            || unsafe { WaitForSingleObject(parent.0, 0) } != WAIT_TIMEOUT
        {
            return Err("MANAGER_IDENTITY_CHANGED");
        }
        let profile = profile_path()?;
        let image = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let probe = image
            .parent()
            .ok_or("MANAGER_IMAGE_UNKNOWN")?
            .join("securerun-policy-probe.exe");
        let mut leases = canonical(image.parent().unwrap())?;
        protected(leases.last().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let mut manager = lease(&image, false)?;
        protected(&manager)?;
        let mut digest = Sha256::new();
        let mut buffer = [0u8; 65536];
        let mut size = 0usize;
        loop {
            let count = manager
                .read(&mut buffer)
                .map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
            if count == 0 {
                break;
            }
            size += count;
            if size > 512 * 1024 * 1024 {
                return Err("MANAGER_IMAGE_BOUND");
            }
            digest.update(&buffer[..count]);
        }
        let manager_hash = format!("{:x}", digest.finalize());
        leases.push(manager);
        let mut file = lease(&probe, false)?;
        protected(&file)?;
        let mut bytes = vec![];
        Read::by_ref(&mut file)
            .take(32 * 1024 * 1024 + 1)
            .read_to_end(&mut bytes)
            .map_err(|_| "PROBE_IMAGE_UNAVAILABLE")?;
        if bytes.len() > 32 * 1024 * 1024 || bytes.get(..2) != Some(b"MZ") {
            return Err("PROBE_IMAGE_INVALID");
        }
        let probe_hash = format!("{:x}", Sha256::digest(bytes));
        leases.push(file);
        let mut additional_probes = Vec::new();
        let required: &[(&str, u16)] = if std::env::consts::ARCH == "aarch64" {
            &[("x86", 0x014c), ("x64", 0x8664)]
        } else {
            &[("x86", 0x014c)]
        };
        for (architecture, machine) in required {
            let path = image
                .parent()
                .unwrap()
                .join(format!("securerun-policy-probe-{architecture}.exe"));
            let mut file = lease(&path, false)?;
            protected(&file)?;
            let mut bytes = Vec::new();
            Read::by_ref(&mut file)
                .take(33554433)
                .read_to_end(&mut bytes)
                .map_err(|_| "PROBE_IMAGE_UNAVAILABLE")?;
            let offset = bytes
                .get(0x3c..0x40)
                .and_then(|v| v.try_into().ok())
                .map(u32::from_le_bytes)
                .ok_or("PROBE_IMAGE_INVALID")? as usize;
            if bytes.len() > 33554432
                || bytes.get(..2) != Some(b"MZ")
                || bytes.get(offset..offset.saturating_add(4)) != Some(b"PE\0\0")
                || bytes.get(offset.saturating_add(4)..offset.saturating_add(6))
                    != Some(&machine.to_le_bytes())
            {
                return Err("PROBE_ARCHITECTURE_MISMATCH");
            }
            additional_probes.push((path, format!("{:x}", Sha256::digest(&bytes))));
            leases.push(file);
        }
        leases.push(template_pin(&trusted)?);
        let manifest: serde_json::Value =
            serde_json::from_str(COMPATIBILITY).map_err(|_| "MANIFEST_INVALID")?;
        let target = manifest["targets"]
            .as_array()
            .ok_or("MANIFEST_INVALID")?
            .iter()
            .find(|t| t["architecture"] == std::env::consts::ARCH)
            .ok_or("ARCHITECTURE_UNTESTED")?;
        for entry in target["injected_libraries"]
            .as_array()
            .ok_or("MANIFEST_INVALID")?
        {
            let path = trusted
                .home
                .join(entry["name"].as_str().ok_or("MANIFEST_INVALID")?);
            leases.extend(ancestry(path.parent().ok_or("MANIFEST_INVALID")?)?);
            let mut file = lease(&path, false)?;
            protected(&file)?;
            signature(&path, &file)?;
            let mut bytes = vec![];
            Read::by_ref(&mut file)
                .take(33554433)
                .read_to_end(&mut bytes)
                .map_err(|_| "INJECTED_LIBRARY_UNAVAILABLE")?;
            if bytes.len() > 33554432
                || format!("{:x}", Sha256::digest(bytes))
                    != entry["sha256"].as_str().ok_or("MANIFEST_INVALID")?
            {
                return Err("INJECTED_LIBRARY_UNTESTED_OR_CHANGED");
            }
            leases.push(file);
        }
        // Windows environment mutation is thread-safe; this worker has not yet
        // started diagnostic threads. Never serialize inherited credentials into
        // the original engine's child environment, including direct CLI workers.
        for (key, _) in std::env::vars_os() {
            let keep = matches!(key.to_str(), Some("SystemRoot" | "WINDIR" | "PATH"));
            #[cfg(feature = "policy-ci")]
            let keep = keep
                || matches!(
                    key.to_str(),
                    Some(
                        "GITHUB_ACTIONS"
                            | "SECURERUN_P05_PAUSE_STAGE"
                            | "SECURERUN_P06_PAUSE_STAGE"
                            | "SECURERUN_P07_PAUSE_STAGE"
                            | "SECURERUN_P08_PAUSE_STAGE"
                            | "SECURERUN_P07_PAUSE_MODE"
                    )
                );
            if !keep {
                unsafe { std::env::remove_var(&key) };
            }
        }
        let system = system_directory()?;
        unsafe {
            std::env::set_var("SystemRoot", system.parent().ok_or("SYSTEM_PATH_UNKNOWN")?);
            std::env::set_var("WINDIR", system.parent().unwrap());
            // Original File_InitUsers expands ProfileList paths containing
            // %SystemDrive%. Derive it from the OS system directory, not the
            // inherited environment, while keeping credentials scrubbed.
            let system_path = system.to_str().ok_or("SYSTEM_PATH_UNKNOWN")?;
            if system_path.as_bytes().get(1) != Some(&b':') {
                return Err("SYSTEM_PATH_UNKNOWN");
            }
            std::env::set_var("SystemDrive", &system_path[..2]);
            std::env::set_var("PATH", &system);
        }
        leases.extend(ensure_private(&profile, &owner)?);
        for leaf in ["metadata", "boxes", "canaries"] {
            leases.extend(ensure_private(&profile.join(leaf), &owner)?);
        }
        Ok(Self {
            api,
            parent,
            parent_pid: manager_pid,
            parent_birth: manager_birth,
            trusted,
            owner,
            profile,
            image,
            manager_hash,
            os_identity,
            probe,
            probe_hash,
            additional_probes,
            _leases: leases,
            root_leases: Default::default(),
        })
    }
    fn mutation_context(&self) -> R<()> {
        if unsafe { WaitForSingleObject(self.parent.0, 0) } != WAIT_TIMEOUT
            || birth(&self.parent)? != self.parent_birth
        {
            return Err("MANAGER_NOT_RUNNING");
        }
        if self.api.context(self.parent_pid) != Context::Unboxed
            || self.api.context(unsafe { GetCurrentProcessId() }) != Context::Unboxed
        {
            return Err("MANAGER_CONTEXT_UNSAFE");
        }
        if !service("SbieSvc")?.running || !service("SbieDrv")?.running {
            return Err("ENGINE_SERVICE_STOPPED");
        }
        Ok(())
    }
    fn set(&self, name: &str, key: &str, values: &[String]) -> R<()> {
        self.mutation_context()?;
        box_wide(name)?;
        let call: Update = unsafe { bind(&self.api, b"SbieDll_UpdateConf\0")? };
        if !values.is_empty() && values.iter().any(|v| v.contains(['\r', '\n', '\0'])) {
            return Err("INI_VALUE_UNSUPPORTED");
        }
        let section = wide(name);
        let key = wide(key);
        let value = values.first().map(|v| wide(v));
        if unsafe {
            call(
                's' as u16,
                ptr::null(),
                section.as_ptr(),
                key.as_ptr(),
                value.as_ref().map_or(ptr::null(), |v| v.as_ptr()),
            )
        } != 0
        {
            return Err("CONFIGURATION_WRITE_REFUSED");
        }
        for v in values.iter().skip(1) {
            if unsafe {
                call(
                    'a' as u16,
                    ptr::null(),
                    section.as_ptr(),
                    key.as_ptr(),
                    wide(v).as_ptr(),
                )
            } != 0
            {
                return Err("CONFIGURATION_APPEND_REFUSED");
            }
        }
        if self.api.values(name, &text(&key)?, RAW_FLAGS)? != values {
            return Err("CONFIGURATION_WRITE_CONFLICT");
        }
        Ok(())
    }
    fn reload(&self) -> R<()> {
        let call: Reload = unsafe { bind(&self.api, b"SbieApi_ReloadConf\0")? };
        let mut session = 0;
        if unsafe { ProcessIdToSessionId(GetCurrentProcessId(), &mut session) } == 0
            || unsafe { call(session, 0) } != 0
        {
            return Err("CONFIGURATION_RELOAD_FAILED");
        }
        Ok(())
    }
    fn validate_grants(&self, desired: &DesiredPolicy) -> R<Vec<File>> {
        let mut held = vec![];
        for grant in &desired.grants {
            literal_path(&grant.path)?;
            held.extend(canonical(Path::new(&grant.path))?);
        }
        Ok(held)
    }
}
impl Engine for NativeEngine {
    fn exists(&self, name: &str) -> R<bool> {
        for i in 0..MAX_BOXES {
            match self.api.conf(None, None, i as u32 | RAW_FLAGS)? {
                Some(found) if found.eq_ignore_ascii_case(name) => return Ok(true),
                Some(_) => {}
                None => return Ok(false),
            }
        }
        Err("BOX_ENUMERATION_BOUND")
    }
    fn root_for(&self, id: Uuid) -> String {
        self.profile
            .join("boxes")
            .join(id.simple().to_string())
            .to_string_lossy()
            .into()
    }
    fn metadata(&self) -> String {
        self.profile.join("metadata").to_string_lossy().into()
    }
    fn code(&self) -> String {
        self.image.to_string_lossy().into()
    }
    fn engine_identity(&self) -> String {
        self.trusted.identity.clone()
    }
    fn global(&self) -> R<Section> {
        let mut s = read_section(&self.api, "GlobalSettings", false)?;
        if s.keys().any(|key| key.starts_with("SecureRun")) {
            return Err("GLOBAL_SETTING_UNREVIEWED");
        }
        validate_inheritance(&s, &[])?;
        let pin: serde_json::Value =
            serde_json::from_str(COMPATIBILITY).map_err(|_| "MANIFEST_INVALID")?;
        let expected: Vec<String> =
            serde_json::from_value(pin["policy_inheritance"]["default_templates"].clone())
                .map_err(|_| "MANIFEST_INVALID")?;
        if self
            .api
            .values("DefaultTemplates", "Template", 0x60000000)?
            != expected
        {
            return Err("DEFAULT_TEMPLATE_LIST_CHANGED");
        }
        if !read_section(&self.api, "DefaultTemplates", false)?.is_empty() {
            return Err("DEFAULT_TEMPLATE_OVERRIDE_UNAPPROVED");
        }
        for name in &expected {
            if !read_section(&self.api, &format!("Template_{name}"), false)?.is_empty() {
                return Err("DEFAULT_TEMPLATE_OVERRIDE_UNAPPROVED");
            }
        }
        let mut inherited = unexpanded_inheritance(&self.api, "GlobalSettings")?;
        for key in s.keys() {
            inherited.remove(key);
        }
        let inherited_fingerprint = fingerprint(&inherited);
        if pin["policy_inheritance"]["unexpanded_default_settings_sha256"] != inherited_fingerprint
        {
            return Err("DEFAULT_INHERITANCE_CHANGED");
        }
        s.insert(
            "SecureRunDefaultInheritance".into(),
            vec![inherited_fingerprint],
        );
        let expanded = read_section(&self.api, "GlobalSettings", true)?;
        for key in ["ClosedFilePath", "ClosedIpcPath", "ReadFilePath"] {
            if let Some(values) = expanded.get(key) {
                s.insert(format!("SecureRunInherited{key}"), values.clone());
            }
        }
        let mut flags = 0u32;
        let ready = bfe_ready()
            && unsafe { (self.api.info)(0, &mut flags as *mut _ as _, 4) } == 0
            && flags & 1 != 0;
        s.insert(
            "SecureRunWfpState".into(),
            vec![if ready { "READY" } else { "UNAVAILABLE" }.into()],
        );
        Ok(s)
    }
    fn section(&self, name: &str, effective: bool) -> R<Section> {
        read_section(&self.api, name, effective)
    }
    fn idle(&self, name: &str) -> R<()> {
        if !self.api.processes(name)?.is_empty() {
            return Err("STOP_REQUIRED_ALL_SESSIONS");
        }
        Ok(())
    }
    fn fence(&self, e: &OwnedEnvironment) -> R<()> {
        self.mutation_context()?;
        self.idle(&e.name())?;
        let raw = self.section(&e.name(), false)?;
        if raw.is_empty() && e.root_identity.is_none() {
            return Ok(());
        }
        let root_acceptable = raw
            .get("FileRootPath")
            .map_or(e.root_identity.is_none(), |v| {
                v == &vec![self.root_for(e.id)]
            });
        if raw.get("SecureRunOwner") != Some(&vec![e.marker()]) || !root_acceptable {
            return Err("OWNERSHIP_BINDING_CHANGED");
        }
        self.set(&e.name(), "Enabled", &["n".into()])?;
        self.reload()?;
        self.idle(&e.name())
    }
    fn write(&self, e: &OwnedEnvironment, baseline: &Section) -> R<()> {
        let _grants = self.validate_grants(&e.desired)?;
        self.mutation_context()?;
        self.idle(&e.name())?;
        let mut expected = baseline.clone();
        if !expected.is_empty() {
            expected.insert("Enabled".into(), vec!["n".into()]);
        }
        if self.section(&e.name(), false)? != expected {
            return Err("CONFIGURATION_CONFLICT");
        }
        // Every write checks the complete prior section; no optimistic overwrite.
        if baseline.is_empty() {
            // The pinned original CSandBox constructor migrates ConfigLevel <10
            // and adds templates/recovery settings. Declare the reviewed format
            // before publishing Enabled so it cannot migrate this new section.
            self.set(&e.name(), "ConfigLevel", &["10".into()])?;
            expected.insert("ConfigLevel".into(), vec!["10".into()]);
        }
        self.set(&e.name(), "Enabled", &["n".into()])?;
        expected.insert("Enabled".into(), vec!["n".into()]);
        if baseline.is_empty() {
            self.set(&e.name(), "SecureRunOwner", &[e.marker()])?;
            expected.insert("SecureRunOwner".into(), vec![e.marker()]);
        }
        let keys = baseline
            .keys()
            .chain(e.compiled.section.keys())
            .cloned()
            .collect::<std::collections::BTreeSet<_>>();
        for key in keys {
            if key == "Enabled"
                || (baseline.is_empty() && matches!(key.as_str(), "SecureRunOwner" | "ConfigLevel"))
            {
                continue;
            }
            if self.section(&e.name(), false)? != expected {
                return Err("CONFIGURATION_CONFLICT");
            }
            self.idle(&e.name())?;
            let values = e.compiled.section.get(&key).cloned().unwrap_or_default();
            self.set(&e.name(), &key, &values)?;
            if values.is_empty() {
                expected.remove(&key);
            } else {
                expected.insert(key, values);
            }
        }
        self.reload()?;
        if self.section(&e.name(), false)? != e.compiled.section {
            return Err("CONFIGURATION_CONFLICT");
        }
        Ok(())
    }
    fn create_root(&self, e: &OwnedEnvironment) -> R<String> {
        self.idle(&e.name())?;
        let observed = self.api.root(&e.name());
        if observed.reason != "PENDING_ROOT"
            || observed.path.as_deref() != Some(self.root_for(e.id).as_str())
        {
            return Err("PENDING_ROOT_BINDING_CHANGED");
        }
        let f = fresh_directory(Path::new(observed.path.as_ref().unwrap()), &self.owner)?;
        let id = identity(&f)?;
        self.root_leases.borrow_mut().push(f);
        Ok(id)
    }
    fn validate_root(&self, e: &OwnedEnvironment) -> R<()> {
        let _grants = self.validate_grants(&e.desired)?;
        let root = self.api.root(&e.name());
        if root.path.as_ref() != Some(&self.root_for(e.id))
            || root.identity != e.root_identity
            || root.identity.is_none()
        {
            return Err("ROOT_IDENTITY_CHANGED");
        }
        let leases = canonical(Path::new(root.path.as_ref().unwrap()))?;
        private(leases.last().ok_or("ROOT_IDENTITY_UNKNOWN")?, &self.owner)?;
        self.root_leases.borrow_mut().extend(leases);
        Ok(())
    }
    fn enforcement_identity(&self) -> String {
        fingerprint(&(
            FAMILY,
            &self.trusted.identity,
            &self.manager_hash,
            &self.os_identity,
            &self.probe_hash,
            self.additional_probes
                .iter()
                .map(|(_, hash)| hash)
                .collect::<Vec<_>>(),
        ))
    }
    fn verify_enforcement(&self, e: &OwnedEnvironment) -> R<String> {
        let mut reports = vec![self.diagnostic(e, &self.probe, &self.probe_hash)?];
        for (probe, hash) in &self.additional_probes {
            reports.push(self.diagnostic(e, probe, hash)?);
        }
        Ok(fingerprint(&reports))
    }
}

pub fn execute(manager_pid: u32, manager_birth: u64, request: Request) -> Reply {
    let mut environments = vec![];
    let result = (|| -> R<()> {
        let engine = NativeEngine::new(manager_pid, manager_birth)?;
        // Namespace lock is held across every read/write and fresh probe.
        let lock_path = engine.profile.join("metadata").join("policy-writer.lock");
        let _lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .share_mode(0)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(&lock_path)
            .map_err(|_| "NAMESPACE_OPERATION_BUSY")?;
        identity(&_lock)?;
        let db_path = engine.profile.join("metadata").join("policy.sqlite");
        if db_path.exists() {
            let _ = lease(&db_path, true)?;
        }
        let mut journal = Journal::open(&db_path, &engine.owner)?;
        journal.recover()?;
        match request {
            Request::List => {
                let all = journal.list()?;
                for mut e in all.clone() {
                    if e.lifecycle_operation.is_none()
                        && e.stage == Stage::Verified
                        && let Err(reason) = validate_owned(&engine, &e, &all)
                    {
                        e.stage = Stage::Conflict;
                        e.reason = reason.into();
                        e.fingerprint = None;
                        e.enforcement_evidence = None;
                        e.enforcement_binding = None;
                        journal.save(&e)?;
                    }
                }
            }
            Request::Create {
                display_name,
                policy,
                operation_id,
            } => {
                engine.validate_grants(&policy)?;
                create(
                    &mut journal,
                    &engine,
                    &engine.owner,
                    &display_name,
                    policy,
                    operation_id,
                )?;
            }
            Request::Apply {
                environment_id,
                expected_revision,
                policy,
                operation_id,
                acknowledge_view_change,
            } => {
                engine.validate_grants(&policy)?;
                apply(
                    &mut journal,
                    &engine,
                    environment_id,
                    expected_revision,
                    policy,
                    operation_id,
                    acknowledge_view_change,
                    None,
                )?;
            }
            Request::Inspect { environment_id } => {
                let mut e = journal.get(environment_id)?;
                let raw = engine.section(&e.name(), false)?;
                e.reason = format!("INSPECTED_BASELINE:{}", fingerprint(&raw));
                e.observed = Some(minimize_section(&raw));
                if e.stage != Stage::Verified {
                    e.stage = Stage::Conflict;
                }
                journal.save(&e)?;
            }
            Request::Repair {
                environment_id,
                expected_revision,
                observed_fingerprint,
                operation_id,
                acknowledge_view_change,
            } => {
                let e = journal.get(environment_id)?;
                apply(
                    &mut journal,
                    &engine,
                    environment_id,
                    expected_revision,
                    e.desired,
                    operation_id,
                    acknowledge_view_change,
                    Some(&observed_fingerprint),
                )?;
            }
        }
        // Reconcile every returned Verified label, including idempotent retries
        // and inspection responses, against current code/root/effective state.
        let current = journal.list()?;
        for mut e in current.clone() {
            if e.stage == Stage::Verified
                && let Err(reason) = validate_owned(&engine, &e, &current)
            {
                e.stage = Stage::Conflict;
                e.reason = reason.into();
                e.fingerprint = None;
                e.enforcement_evidence = None;
                e.enforcement_binding = None;
                journal.save(&e)?;
            }
        }
        environments = journal.list()?;
        Ok(())
    })();
    Reply {
        protocol: 1,
        reason: result.err().unwrap_or("OBSERVED").into(),
        environments,
        production_launch_available: false,
        elevated_helper: false,
    }
}

/// Fixed worker schema over a private inherited pipe; no command/password/path arguments.
pub fn bounded_request(request: &Request) -> Reply {
    let result = (|| -> R<Reply> {
        let pid = unsafe { GetCurrentProcessId() };
        let created = process_birth(pid)?;
        let executable = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let _parents = ancestry(executable.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let _image = lease(&executable, false)?;
        let data = serde_json::to_vec(request).map_err(|_| "POLICY_REQUEST_INVALID")?;
        if data.len() > 16384 {
            return Err("POLICY_REQUEST_BOUND");
        }
        let windows = system_directory()?;
        let mut command = Command::new(executable);
        command
            .args([
                "--policy-worker".into(),
                pid.to_string(),
                created.to_string(),
            ])
            .current_dir(&windows)
            .env_clear()
            .env("SystemRoot", windows.parent().ok_or("SYSTEM_PATH_UNKNOWN")?)
            .env("WINDIR", windows.parent().unwrap())
            .env("PATH", &windows)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW);
        // The request is bounded before dispatch; the same job/output/timeout
        // machinery as observation kills the narrow worker on failure.
        let child = command.spawn().map_err(|_| "BRIDGE_START_FAILED")?;
        // A full 12-box rollout performs up to 36 fixed architecture-specific
        // enforcement diagnostics. Keep a finite deadline without dropping checks.
        let bytes = capture_child(child, Duration::from_secs(600), Some(data))?;
        let reply: Reply = serde_json::from_slice(&bytes).map_err(|_| "POLICY_RESPONSE_INVALID")?;
        if reply.protocol != 1
            || reply.production_launch_available
            || reply.elevated_helper
            || reply.environments.len() > 12
        {
            return Err("POLICY_RESPONSE_INVALID");
        }
        Ok(reply)
    })();
    result.unwrap_or_else(Reply::failure)
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Canary {
    box_name: String,
    write: String,
    delete: String,
    blocked: String,
    read_only: String,
    metadata: String,
    sibling: Option<String>,
    metadata_alias: String,
    sibling_alias: String,
    metadata_short: Option<String>,
    sibling_short: Option<String>,
    output: String,
    incoming_output: String,
    registry_leaf: String,
    ports: [u16; 6],
    dns_target: String,
    dns_cached: String,
    mapped_share: bool,
    lan_address: [u8; 4],
    child: bool,
    offline: bool,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct CanaryReport {
    member: bool,
    virtualized_write: bool,
    virtualized_delete: bool,
    blocked_read: bool,
    read_only_read: bool,
    read_only_write_denied: bool,
    metadata_denied: bool,
    sibling_denied: bool,
    metadata_case_denied: bool,
    sibling_case_denied: bool,
    metadata_short_denied: Option<bool>,
    sibling_short_denied: Option<bool>,
    metadata_alias_denied: bool,
    sibling_alias_denied: bool,
    standard_read_visible: bool,
    registry_virtualized: bool,
    sockets: [bool; 6],
    incoming: [bool; 4],
    dns_network: bool,
    dns_cached_answer: bool,
    icmp_echo: bool,
    icmp_status: u32,
    smb_denied: bool,
    mapped_share_denied: Option<bool>,
    raw: network::RawReport,
    bits_activation_status: i32,
    child_network: ChildNetwork,
}
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
fn unhex(value: &str) -> R<Vec<u8>> {
    if value.is_empty()
        || value.len() > 16384
        || !value.len().is_multiple_of(2)
        || !value.bytes().all(|b| b.is_ascii_hexdigit())
    {
        return Err("PROBE_REQUEST_INVALID");
    }
    (0..value.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&value[i..i + 2], 16).map_err(|_| "PROBE_REQUEST_INVALID"))
        .collect()
}
fn registry_value(leaf: &str, write: Option<u32>) -> R<u32> {
    use windows_sys::Win32::System::Registry::*;
    if leaf.len() != 32 || !leaf.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("CANARY_SCOPE_INVALID");
    }
    unsafe {
        let mut key = ptr::null_mut();
        let mut disposition = 0;
        let path = wide(&format!("Software\\SecureRunPolicyDiagnostics\\{leaf}"));
        if RegCreateKeyExW(
            HKEY_CURRENT_USER,
            path.as_ptr(),
            0,
            ptr::null(),
            0,
            KEY_READ | KEY_WRITE,
            ptr::null(),
            &mut key,
            &mut disposition,
        ) != 0
        {
            return Err("CANARY_REGISTRY_UNAVAILABLE");
        }
        let result = (|| {
            let name = wide("Canary");
            if let Some(value) = write
                && RegSetValueExW(key, name.as_ptr(), 0, REG_DWORD, &value as *const _ as _, 4) != 0
            {
                return Err("CANARY_REGISTRY_WRITE_FAILED");
            }
            let mut value = 0u32;
            let mut size = 4;
            let mut kind = 0;
            if RegQueryValueExW(
                key,
                name.as_ptr(),
                ptr::null(),
                &mut kind,
                &mut value as *mut _ as _,
                &mut size,
            ) != 0
                || kind != REG_DWORD
                || size != 4
            {
                return Err("CANARY_REGISTRY_READ_FAILED");
            }
            Ok(value)
        })();
        RegCloseKey(key);
        result
    }
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ChildNetwork {
    sockets: [bool; 6],
    dns_network: bool,
    icmp_echo: bool,
    icmp_status: u32,
}
fn exercise_network(canary: &Canary) -> ChildNetwork {
    let mut sockets = [false; 6];
    for (i, port) in canary.ports.iter().enumerate() {
        let address: std::net::SocketAddr = if i >= 4 {
            std::net::SocketAddr::from((canary.lan_address, *port))
        } else if i % 2 == 0 {
            std::net::SocketAddr::from(([127, 0, 0, 1], *port))
        } else {
            std::net::SocketAddr::from(([0, 0, 0, 0, 0, 0, 0, 1], *port))
        };
        if i < 2 || i == 4 {
            let deadline = Instant::now() + Duration::from_secs(4);
            loop {
                if let Ok(mut socket) =
                    std::net::TcpStream::connect_timeout(&address, Duration::from_millis(1500))
                {
                    let _ = socket.set_read_timeout(Some(Duration::from_millis(1500)));
                    let _ = socket.set_write_timeout(Some(Duration::from_millis(1500)));
                    let mut reply = [0u8; 1];
                    sockets[i] = socket.write_all(b"P").is_ok()
                        && socket.read_exact(&mut reply).is_ok()
                        && reply == *b"R";
                }
                // Only online availability retries the exact benign endpoint.
                // Offline retains a single attempt and independent server/tag
                // observations still reject any target-caused traffic.
                if sockets[i] || canary.offline || Instant::now() >= deadline {
                    break;
                }
                std::thread::sleep(Duration::from_millis(50));
            }
        } else {
            let bind = if i >= 4 {
                std::net::SocketAddr::from((canary.lan_address, 0))
            } else if i % 2 == 0 {
                std::net::SocketAddr::from(([127, 0, 0, 1], 0))
            } else {
                std::net::SocketAddr::from(([0, 0, 0, 0, 0, 0, 0, 1], 0))
            };
            if let Ok(socket) = std::net::UdpSocket::bind(bind) {
                let _ = socket.set_read_timeout(Some(Duration::from_millis(750)));
                if socket.connect(address).is_ok() {
                    let deadline = Instant::now() + Duration::from_secs(4);
                    loop {
                        let mut reply = [0u8; 1];
                        sockets[i] = socket.send(b"P").is_ok()
                            && socket.recv(&mut reply).is_ok_and(|n| n == 1)
                            && reply == *b"R";
                        // Availability may repeat this fixed benign online probe.
                        // Offline sends once; independent server observations still
                        // reject any target traffic, including a lost reply.
                        if sockets[i] || canary.offline || Instant::now() >= deadline {
                            break;
                        }
                        std::thread::sleep(Duration::from_millis(50));
                    }
                }
            }
        }
    }
    let icmp_echo = network::icmp_echo(&canary.registry_leaf);
    ChildNetwork {
        sockets,
        dns_network: network::dns_query(&canary.dns_target, false),
        icmp_echo,
        icmp_status: network::icmp_status(),
    }
}
fn spawn_canary_child(canary: &Canary) -> R<ChildNetwork> {
    let mut request: Canary =
        serde_json::from_slice(&serde_json::to_vec(canary).map_err(|_| "PROBE_REQUEST_INVALID")?)
            .map_err(|_| "PROBE_REQUEST_INVALID")?;
    request.child = true;
    request.output = format!("{}.child", canary.output);
    let data = hex(&serde_json::to_vec(&request).map_err(|_| "PROBE_REQUEST_INVALID")?);
    let executable = std::env::current_exe().map_err(|_| "PROBE_IMAGE_UNKNOWN")?;
    let mut child = Command::new(executable)
        .arg(data)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .creation_flags(CREATE_NO_WINDOW)
        .spawn()
        .map_err(|_| "CANARY_CHILD_DISPATCH_FAILED")?;
    let clock = Instant::now();
    loop {
        if let Some(status) = child.try_wait().map_err(|_| "CANARY_CHILD_WAIT_FAILED")? {
            if !status.success() {
                return Err("CANARY_CHILD_FAILED");
            }
            break;
        }
        if clock.elapsed() >= Duration::from_secs(15) {
            let _ = child.kill();
            return Err("CANARY_CHILD_TIMEOUT");
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    let mut file = File::open(&request.output).map_err(|_| "CANARY_CHILD_REPORT_FAILED")?;
    let mut data = Vec::new();
    Read::by_ref(&mut file)
        .take(4097)
        .read_to_end(&mut data)
        .map_err(|_| "CANARY_CHILD_REPORT_FAILED")?;
    if data.len() > 4096 {
        return Err("CANARY_CHILD_REPORT_FAILED");
    }
    serde_json::from_slice(&data).map_err(|_| "CANARY_CHILD_REPORT_FAILED")
}

pub fn run_canary(encoded: &str) -> i32 {
    let result = (|| -> R<()> {
        // This executable cannot read metadata or perform controls, even if unboxed.
        let module = unsafe { GetModuleHandleW(wide("SbieDll.dll").as_ptr()) };
        if module.is_null() {
            return Err("PROBE_NOT_BOXED");
        }
        let address = unsafe { GetProcAddress(module, c"SbieApi_QueryProcess".as_ptr().cast()) }
            .ok_or("PROBE_NOT_BOXED")?;
        type LegacyQuery =
            unsafe extern "system" fn(HANDLE, *mut u16, *mut u16, *mut u16, *mut u32) -> i32;
        let query: LegacyQuery = unsafe { std::mem::transmute(address) };
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
            return Err("PROBE_NOT_BOXED");
        }
        let canary: Canary =
            serde_json::from_slice(&unhex(encoded)?).map_err(|_| "PROBE_REQUEST_INVALID")?;
        if text(&name)? != canary.box_name || !valid_box(&canary.box_name) {
            return Err("PROBE_CONTEXT_MISMATCH");
        }
        for p in [
            &canary.write,
            &canary.delete,
            &canary.blocked,
            &canary.read_only,
            &canary.metadata,
            &canary.output,
            &canary.incoming_output,
        ] {
            literal_path(p)?;
        }
        if canary.child {
            let report = exercise_network(&canary);
            let bytes = serde_json::to_vec(&report).map_err(|_| "CANARY_REPORT_INVALID")?;
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&canary.output)
                .map_err(|_| "CANARY_REPORT_UNAVAILABLE")?;
            file.write_all(&bytes)
                .map_err(|_| "CANARY_REPORT_UNAVAILABLE")?;
            return Ok(());
        }
        let original = std::fs::read(&canary.write).map_err(|_| "CANARY_READ_FAILED")?;
        let virtualized_write = original == b"SYNTHETIC_HOST_CANARY"
            && std::fs::write(&canary.write, b"SYNTHETIC_BOX_CHANGE").is_ok()
            && std::fs::read(&canary.write).is_ok_and(|v| v == b"SYNTHETIC_BOX_CHANGE");
        let denied = |p: &str| {
            std::fs::read(p)
                .err()
                .is_some_and(|e| e.raw_os_error() == Some(5))
        };
        let read_only_read =
            std::fs::read(&canary.read_only).is_ok_and(|v| v == b"SYNTHETIC_HOST_CANARY");
        let read_only_write_denied = std::fs::OpenOptions::new()
            .write(true)
            .open(&canary.read_only)
            .err()
            .is_some_and(|e| e.raw_os_error() == Some(5));
        let child_network = spawn_canary_child(&canary)?;
        let incoming = network::incoming_probe(&canary.incoming_output, canary.offline)?;
        let network = exercise_network(&canary);
        let report = CanaryReport {
            member: true,
            virtualized_write,
            virtualized_delete: std::fs::remove_file(&canary.delete).is_ok()
                && std::fs::read(&canary.delete)
                    .err()
                    .is_some_and(|e| e.kind() == std::io::ErrorKind::NotFound),
            blocked_read: denied(&canary.blocked),
            read_only_read,
            read_only_write_denied,
            metadata_denied: denied(&canary.metadata),
            sibling_denied: canary.sibling.as_ref().is_none_or(|p| denied(p)),
            metadata_case_denied: denied(&canary.metadata.to_ascii_uppercase()),
            sibling_case_denied: canary
                .sibling
                .as_ref()
                .is_none_or(|p| denied(&p.to_ascii_uppercase())),
            metadata_short_denied: canary.metadata_short.as_ref().map(|p| denied(p)),
            sibling_short_denied: canary.sibling_short.as_ref().map(|p| denied(p)),
            metadata_alias_denied: denied(&canary.metadata_alias),
            sibling_alias_denied: denied(&canary.sibling_alias),
            standard_read_visible: original == b"SYNTHETIC_HOST_CANARY",
            registry_virtualized: registry_value(&canary.registry_leaf, Some(2)) == Ok(2),
            sockets: network.sockets,
            incoming,
            dns_network: network.dns_network,
            dns_cached_answer: network::dns_query(&canary.dns_cached, true),
            icmp_echo: network.icmp_echo,
            icmp_status: network.icmp_status,
            raw: network::raw_echo(&canary.registry_leaf),
            bits_activation_status: network::bits_activation_status(),
            child_network,
            smb_denied: denied(network::SHARE_CANARY),
            mapped_share_denied: canary.mapped_share.then(|| denied(network::MAPPED_CANARY)),
        };
        let data = serde_json::to_vec(&report).map_err(|_| "CANARY_REPORT_INVALID")?;
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&canary.output)
            .map_err(|_| "CANARY_REPORT_UNAVAILABLE")?;
        file.write_all(&data)
            .map_err(|_| "CANARY_REPORT_UNAVAILABLE")?;
        file.sync_all().map_err(|_| "CANARY_REPORT_UNAVAILABLE")?;
        Ok(())
    })();
    match result {
        Ok(()) => 0,
        Err("PROBE_NOT_BOXED") => 71,
        Err("PROBE_CONTEXT_MISMATCH") => 72,
        Err("CANARY_READ_FAILED") => 73,
        Err("CANARY_REPORT_UNAVAILABLE") => 74,
        Err("CANARY_REGISTRY_UNAVAILABLE") => 75,
        Err("PROBE_REQUEST_INVALID") => 76,
        Err(_) => 78,
    }
}

struct Endpoints {
    lan_address: [u8; 4],
    ports: [u16; 6],
    counts: std::sync::Arc<[std::sync::atomic::AtomicUsize; 6]>,
    control_counts: [usize; 6],
    stop: std::sync::Arc<std::sync::atomic::AtomicBool>,
    threads: Vec<std::thread::JoinHandle<()>>,
}
impl Endpoints {
    fn new(metadata: &Path, nonce: &str) -> R<Self> {
        use std::sync::{
            Arc,
            atomic::{AtomicBool, AtomicUsize, Ordering},
        };
        let counts = Arc::new(std::array::from_fn(|_| AtomicUsize::new(0)));
        let stop = Arc::new(AtomicBool::new(false));
        let lan_address = network::lan_address()?;
        let lan = std::net::Ipv4Addr::from(lan_address);
        let mut ports = [0u16; 6];
        let mut threads = vec![];
        for (i, port) in ports.iter_mut().enumerate() {
            let address = if i >= 4 {
                format!("{lan}:0")
            } else if i % 2 == 0 {
                "127.0.0.1:0".into()
            } else {
                "[::1]:0".into()
            };
            let counter = counts.clone();
            let stopped = stop.clone();
            if i < 2 || i == 4 {
                let listener = std::net::TcpListener::bind(address)
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?;
                *port = listener
                    .local_addr()
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?
                    .port();
                listener
                    .set_nonblocking(true)
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?;
                threads.push(std::thread::spawn(move || {
                    let deadline = Instant::now() + Duration::from_secs(60);
                    while Instant::now() < deadline && !stopped.load(Ordering::SeqCst) {
                        if let Ok((mut socket, _)) = listener.accept() {
                            let _ = socket.set_read_timeout(Some(Duration::from_secs(3)));
                            let mut b = [0u8; 1];
                            if socket.read_exact(&mut b).is_ok() && b == *b"P" {
                                counter[i].fetch_add(1, Ordering::SeqCst);
                                let _ = socket.write_all(b"R");
                            }
                        }
                        std::thread::sleep(Duration::from_millis(10));
                    }
                }));
            } else {
                let socket = std::net::UdpSocket::bind(address)
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?;
                *port = socket
                    .local_addr()
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?
                    .port();
                socket
                    .set_read_timeout(Some(Duration::from_millis(50)))
                    .map_err(|_| "CONTROLLED_ENDPOINT_UNAVAILABLE")?;
                threads.push(std::thread::spawn(move || {
                    let deadline = Instant::now() + Duration::from_secs(60);
                    while Instant::now() < deadline && !stopped.load(Ordering::SeqCst) {
                        let mut b = [0u8; 1];
                        if let Ok((1, peer)) = socket.recv_from(&mut b)
                            && b == *b"P"
                        {
                            counter[i].fetch_add(1, Ordering::SeqCst);
                            let _ = socket.send_to(b"R", peer);
                        }
                    }
                }));
            }
        }
        let mut endpoints = Self {
            lan_address,
            ports,
            counts,
            control_counts: [0; 6],
            stop,
            threads,
        };
        // Independent unboxed positive control for every live server, before the
        // blocked canary: a failed connection to a dead service is not evidence.
        for (i, port) in endpoints.ports.iter().enumerate() {
            let address = if i >= 4 {
                format!("{lan}:{port}")
            } else if i % 2 == 0 {
                format!("127.0.0.1:{port}")
            } else {
                format!("[::1]:{port}")
            };
            let mut stage = "ADDRESS";
            let deadline = Instant::now() + Duration::from_secs(4);
            let mut attempts = 0;
            let result = loop {
                attempts += 1;
                let result = (|| -> std::io::Result<()> {
                    let mut answer = [0u8; 1];
                    if i < 2 || i == 4 {
                        let address: std::net::SocketAddr = address
                            .parse()
                            .map_err(|_| std::io::Error::from(std::io::ErrorKind::InvalidInput))?;
                        stage = "TCP_CONNECT";
                        let mut socket =
                            std::net::TcpStream::connect_timeout(&address, Duration::from_secs(1))?;
                        socket.set_read_timeout(Some(Duration::from_secs(1)))?;
                        socket.set_write_timeout(Some(Duration::from_secs(1)))?;
                        stage = "TCP_WRITE";
                        socket.write_all(b"P")?;
                        stage = "TCP_READ";
                        socket.read_exact(&mut answer)?;
                    } else {
                        stage = "UDP_BIND";
                        let socket = std::net::UdpSocket::bind(if i >= 4 {
                            format!("{lan}:0")
                        } else if i % 2 == 0 {
                            "127.0.0.1:0".into()
                        } else {
                            "[::1]:0".into()
                        })?;
                        socket.set_read_timeout(Some(Duration::from_millis(750)))?;
                        stage = "UDP_SEND";
                        socket.send_to(b"P", &address)?;
                        stage = "UDP_READ";
                        if socket.recv_from(&mut answer)?.0 != 1 {
                            return Err(std::io::ErrorKind::InvalidData.into());
                        }
                    }
                    stage = "ANSWER";
                    if answer != *b"R" {
                        return Err(std::io::ErrorKind::InvalidData.into());
                    }
                    Ok(())
                })();
                if result.is_ok() || Instant::now() >= deadline {
                    break result;
                }
                std::thread::sleep(Duration::from_millis(50));
            };
            if let Err(error) = result {
                // Only endpoint kind, fixed phase and numeric status are retained;
                // no IP, port, user path or OS error text enters diagnostics.
                let report = serde_json::json!({"schema":1,"endpoint_index":i,"stage":stage,"attempts":attempts,"os_error":error.raw_os_error(),"timed_out":matches!(error.kind(),std::io::ErrorKind::TimedOut|std::io::ErrorKind::WouldBlock),"positive_control":true,"target_dispatched":false});
                let mut file = OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                    .open(metadata.join(format!("endpoint-status-{nonce}.json")))
                    .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                file.write_all(
                    &serde_json::to_vec(&report).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                )
                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                file.sync_all()
                    .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                return Err("ENDPOINT_POSITIVE_CONTROL_FAILED");
            }
        }
        // Every server increments before replying. A successful final handshake
        // therefore includes all earlier control attempts in this baseline.
        // No canary has been dispatched yet. Any later packet counts as target
        // activity; retries must never be mistaken for offline target traffic.
        endpoints.control_counts =
            std::array::from_fn(|i| endpoints.counts[i].load(Ordering::SeqCst));
        Ok(endpoints)
    }
    fn observed(mut self) -> [bool; 6] {
        use std::sync::atomic::Ordering;
        std::thread::sleep(Duration::from_millis(100));
        self.stop.store(true, Ordering::SeqCst);
        for thread in self.threads.drain(..) {
            let _ = thread.join();
        }
        std::array::from_fn(|i| self.counts[i].load(Ordering::SeqCst) > self.control_counts[i])
    }
}
impl Drop for Endpoints {
    fn drop(&mut self) {
        self.stop.store(true, std::sync::atomic::Ordering::SeqCst);
    }
}
#[test]
fn completed_control_attempts_never_hide_later_endpoint_traffic() {
    use std::sync::{
        Arc,
        atomic::{AtomicBool, AtomicUsize},
    };
    for controls in 1..=4 {
        for target in [None, Some(0), Some(1), Some(2), Some(3), Some(4), Some(5)] {
            let endpoint = Endpoints {
                lan_address: [127, 0, 0, 1],
                ports: [0; 6],
                counts: Arc::new(std::array::from_fn(|i| {
                    AtomicUsize::new(controls + usize::from(target == Some(i)))
                })),
                control_counts: [controls; 6],
                stop: Arc::new(AtomicBool::new(false)),
                threads: Vec::new(),
            };
            assert_eq!(
                endpoint.observed(),
                std::array::from_fn(|i| target == Some(i))
            );
        }
    }
}
fn locate_report(root: &Path, leaf: &str) -> R<PathBuf> {
    fn visit(root: &Path, leaf: &str, depth: usize, count: &mut usize) -> R<Option<PathBuf>> {
        if depth > 32 {
            return Err("DIAGNOSTIC_STORAGE_BOUND");
        }
        for item in std::fs::read_dir(root).map_err(|_| "DIAGNOSTIC_STORAGE_UNAVAILABLE")? {
            *count += 1;
            if *count > 512 {
                return Err("DIAGNOSTIC_STORAGE_BOUND");
            }
            let p = item.map_err(|_| "DIAGNOSTIC_STORAGE_UNAVAILABLE")?.path();
            let _held = ancestry(&p)?;
            if p.file_name().and_then(|s| s.to_str()) == Some(leaf) {
                return Ok(Some(p));
            }
            if p.is_dir()
                && let Some(result) = visit(&p, leaf, depth + 1, count)?
            {
                return Ok(Some(result));
            }
        }
        Ok(None)
    }
    visit(root, leaf, 0, &mut 0)?.ok_or("DIAGNOSTIC_REPORT_MISSING")
}
impl NativeEngine {
    fn stop_diagnostic(&self, diagnostic: &OwnedEnvironment) -> R<()> {
        // This private scope was generated and journaled by this worker and
        // never hosted a user target. No caller-selected box stop is exposed.
        self.mutation_context()?;
        self.validate_root(diagnostic)?;
        let section = self.section(&diagnostic.name(), false)?;
        let mut expected = diagnostic.compiled.section.clone();
        expected.insert("Enabled".into(), vec!["y".into()]);
        if section != expected
            || section.get("SecureRunOwner") != Some(&vec![diagnostic.marker()])
            || section.get("FileRootPath") != Some(&vec![self.root_for(diagnostic.id)])
        {
            let keys: Vec<_> = section
                .keys()
                .chain(expected.keys())
                .filter(|key| section.get(*key) != expected.get(*key))
                .map(|key| {
                    if expected.contains_key(key) {
                        key.clone()
                    } else {
                        "UNREVIEWED_KEY_WITHHELD".into()
                    }
                })
                .collect::<std::collections::BTreeSet<_>>()
                .into_iter()
                .collect();
            let data = serde_json::json!({"schema":1,"changed_keys":keys,"enabled":section.get("Enabled").and_then(|v|v.first()).filter(|s|s.as_str()=="y"||s.as_str()=="n")});
            std::fs::write(
                self.profile
                    .join("metadata")
                    .join(format!("scope-status-{}.json", diagnostic.id.simple())),
                serde_json::to_vec(&data).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
            )
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
            return Err("DIAGNOSTIC_SCOPE_CHANGED");
        }
        self.set(&diagnostic.name(), "Enabled", &["n".into()])?;
        self.reload()?;
        for _ in 0..4 {
            let processes = self.api.processes(&diagnostic.name())?;
            if processes.is_empty() {
                return Ok(());
            }
            if processes.len() > 16 {
                return Err("DIAGNOSTIC_PROCESS_BOUND");
            }
            for process in processes {
                let raw = unsafe {
                    OpenProcess(
                        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE | SYNCHRONIZE,
                        0,
                        process.pid,
                    )
                };
                if raw.is_null() {
                    if unsafe { GetLastError() } == ERROR_INVALID_PARAMETER {
                        continue;
                    }
                    return Err("DIAGNOSTIC_PROCESS_HANDLE_UNAVAILABLE");
                }
                let held = Handle(raw);
                if unsafe { WaitForSingleObject(held.0, 0) } == WAIT_OBJECT_0 {
                    continue;
                }
                let created = birth(&held)?;
                let mut critical = 0;
                if unsafe { IsProcessCritical(held.0, &mut critical) } == 0 {
                    if unsafe { WaitForSingleObject(held.0, 0) } == WAIT_OBJECT_0 {
                        continue;
                    }
                    return Err("DIAGNOSTIC_CRITICAL_STATE_UNKNOWN");
                }
                if critical != 0 {
                    return Err("DIAGNOSTIC_CRITICAL_PROCESS_REFUSED");
                }
                if created != process.creation_time || process.owner_sid != self.owner {
                    return Err("DIAGNOSTIC_PROCESS_BIRTH_OR_BOX_OWNER_CHANGED");
                }
                let token_owner = process_sid(held.0)?;
                let _service_helper = if token_owner != self.owner {
                    // Original RunSandboxedGetToken chooses a session token or
                    // SYSTEM for RpcSs. The driver's box SID remains the owner.
                    // Token_RestrictHelper substitutes Anonymous Logon in the
                    // primary token to prevent impersonation. Preserve it and
                    // derive ownership from the independent driver box SID.
                    let mut parent_session = 0;
                    if unsafe { ProcessIdToSessionId(self.parent_pid, &mut parent_session) } == 0
                        || (token_owner != "S-1-5-18"
                            && token_owner != "S-1-5-7"
                            && token_owner != session_owner(parent_session)?)
                    {
                        let kind = match token_owner.as_str() {
                            "S-1-5-19" => "LOCAL_SERVICE",
                            "S-1-5-20" => "NETWORK_SERVICE",
                            "S-1-5-18" => "SYSTEM",
                            "S-1-5-7" => "SANDBOXIE_ANONYMOUS_PRIMARY",
                            _ => "OTHER_TOKEN",
                        };
                        let data = serde_json::json!({"schema":1,"token_kind":kind,"box_owner_matches":process.owner_sid==self.owner});
                        std::fs::write(
                            self.profile
                                .join("metadata")
                                .join(format!("identity-status-{}.json", diagnostic.id.simple())),
                            serde_json::to_vec(&data)
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                        )
                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                        return Err("DIAGNOSTIC_PROCESS_TOKEN_OWNER_CHANGED");
                    }
                    let mut path = [0u16; 32768];
                    let mut length = path.len() as u32;
                    if unsafe {
                        QueryFullProcessImageNameW(held.0, 0, path.as_mut_ptr(), &mut length)
                    } == 0
                    {
                        let error = unsafe { GetLastError() };
                        // Image teardown can precede process-object signaling.
                        // Only completion of this retained object permits skip;
                        // no live unknown image is authorized for termination.
                        let waited = unsafe { WaitForSingleObject(held.0, 5000) };
                        if waited == WAIT_OBJECT_0 {
                            continue;
                        }
                        let status = serde_json::json!({"schema":1,"query_error":error,"wait_status":waited,"complete":false});
                        std::fs::write(
                            self.profile
                                .join("metadata")
                                .join(format!("image-status-{}.json", diagnostic.id.simple())),
                            serde_json::to_vec(&status)
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                        )
                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                        return Err("DIAGNOSTIC_HELPER_IMAGE_UNKNOWN");
                    }
                    let image = PathBuf::from(text(&path)?);
                    // The pinned original apps/com implementations provide both
                    // RpcSs and its DcomLaunch companion. Accept only these two
                    // protected, signed installed images in our fresh scope.
                    let original_helper = ["SandboxieRpcSs.exe", "SandboxieDcomLaunch.exe"]
                        .iter()
                        .any(|name| {
                            image.to_string_lossy().eq_ignore_ascii_case(
                                &self.trusted.home.join(name).to_string_lossy(),
                            )
                        });
                    if !original_helper {
                        // A short-lived OS reporter can finish while its image is
                        // being inspected. Waiting on this same held object is
                        // not authority to terminate an unreviewed live process.
                        if unsafe { WaitForSingleObject(held.0, 60_000) } == WAIT_OBJECT_0 {
                            let data = serde_json::json!({"schema":1,"unreviewed_process_completed":true,"natural_completion_wait_bound_ms":60000,"termination_dispatched":false});
                            let mut record = OpenOptions::new()
                                .write(true)
                                .create_new(true)
                                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                                .open(self.profile.join("metadata").join(format!(
                                    "image-status-{}-{}.json",
                                    diagnostic.id.simple(),
                                    Uuid::new_v4().simple()
                                )))
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                            record
                                .write_all(
                                    &serde_json::to_vec(&data)
                                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                                )
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                            record
                                .sync_all()
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                            continue;
                        }
                        let name = image.file_name().and_then(|s| s.to_str()).unwrap_or("");
                        let allowed_name = [
                            "SandboxieRpcSs.exe",
                            "SandboxieDcomLaunch.exe",
                            "SandboxieCrypto.exe",
                            "SandboxieBITS.exe",
                            "SbieSvc.exe",
                            "WerFault.exe",
                            "conhost.exe",
                            "securerun-policy-probe.exe",
                        ]
                        .iter()
                        .find(|v| name.eq_ignore_ascii_case(v))
                        .copied()
                        .unwrap_or("UNREVIEWED_NAME_WITHHELD");
                        let location = if image.starts_with(&self.trusted.home) {
                            "ENGINE_HOME"
                        } else if image.starts_with(self.profile.join("boxes")) {
                            "DIAGNOSTIC_STORAGE"
                        } else if image.starts_with(system_directory()?) {
                            "OS_SYSTEM_DIRECTORY"
                        } else {
                            "OTHER_LOCATION"
                        };
                        let data = serde_json::json!({"schema":1,"image_kind":allowed_name,"location_kind":location,"unreviewed_process_completed":false,"natural_completion_wait_bound_ms":60000,"termination_dispatched":false});
                        std::fs::write(
                            self.profile
                                .join("metadata")
                                .join(format!("image-status-{}.json", diagnostic.id.simple())),
                            serde_json::to_vec(&data)
                                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                        )
                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                        return Err("DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED");
                    }
                    let file = lease(&image, false)?;
                    protected(&file)?;
                    signature(&image, &file)?;
                    Some(file)
                } else {
                    None
                };
                let mut name = [0u16; 40];
                let mut sid = [0u16; 96];
                let mut session = 0;
                let mut observed_birth = 0;
                let query_status = unsafe {
                    (self.api.query)(
                        process.pid as usize as _,
                        0,
                        name.as_mut_ptr(),
                        ptr::null_mut(),
                        sid.as_mut_ptr(),
                        &mut session,
                        &mut observed_birth,
                    )
                };
                let same_box = query_status == 0 && text(&name)? == diagnostic.name();
                let same_owner = query_status == 0 && text(&sid)? == self.owner;
                let same_birth = query_status == 0 && observed_birth == created;
                if !same_box || !same_owner || !same_birth {
                    // Driver membership can disappear before the same retained
                    // kernel object signals exit. Wait only for that object;
                    // an unknown live process never authorizes termination.
                    let waited = unsafe { WaitForSingleObject(held.0, 1000) };
                    if waited == WAIT_OBJECT_0 {
                        continue;
                    }
                    let status = serde_json::json!({"schema":1,"operation":"DIAGNOSTIC_MEMBERSHIP","query_status":query_status,"same_box":same_box,"same_owner":same_owner,"same_birth":same_birth,"wait_status":waited,"termination_dispatched":false});
                    let mut file = OpenOptions::new()
                        .write(true)
                        .create_new(true)
                        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                        .open(
                            self.profile
                                .join("metadata")
                                .join(format!("scope-status-{}.json", diagnostic.id.simple())),
                        )
                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                    file.write_all(
                        &serde_json::to_vec(&status)
                            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                    )
                    .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                    file.sync_all()
                        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                    return Err("DIAGNOSTIC_PROCESS_SCOPE_CHANGED");
                }
                // A process can finish after membership validation. Windows
                // then refuses TerminateProcess even though this same retained
                // object is already exiting. Completion is the signaled object,
                // never a successful dispatch alone or another numeric PID.
                let dispatched = unsafe { TerminateProcess(held.0, 79) } != 0;
                let error = if dispatched {
                    0
                } else {
                    unsafe { GetLastError() }
                };
                let waited = unsafe { WaitForSingleObject(held.0, 5000) };
                if !dispatched || waited != WAIT_OBJECT_0 {
                    // Bounded OS statuses only: no identities, paths or target data.
                    let status = serde_json::json!({"schema":1,"operation":"DIAGNOSTIC_STOP","termination_dispatched":dispatched,"termination_error":error,"wait_status":waited,"complete":waited==WAIT_OBJECT_0});
                    std::fs::write(
                        self.profile
                            .join("metadata")
                            .join(format!("scope-status-{}.json", diagnostic.id.simple())),
                        serde_json::to_vec(&status)
                            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                    )
                    .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                }
                if waited != WAIT_OBJECT_0 {
                    return Err("DIAGNOSTIC_STOP_UNCONFIRMED");
                }
            }
        }
        self.idle(&diagnostic.name())
    }
    fn diagnostic(&self, owned: &OwnedEnvironment, probe: &Path, probe_hash: &str) -> R<String> {
        self.mutation_context()?;
        let global = self.global()?;
        if owned.compiled.offline {
            let mut flags = 0u32;
            if global.get("NetworkEnableWFP") != Some(&vec!["y".into()])
                || unsafe { (self.api.info)(0, &mut flags as *mut _ as _, 4) } != 0
                || flags & 0x00000001 == 0
            {
                return Err("WFP_ENFORCEMENT_UNAVAILABLE");
            }
        }
        let count = std::fs::read_dir(self.profile.join("metadata"))
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?
            .filter_map(Result::ok)
            .filter(|entry| {
                entry
                    .file_name()
                    .to_string_lossy()
                    .starts_with("diagnostic-")
            })
            .take(MAX_RETAINED_DIAGNOSTICS + 1)
            .count();
        if count >= MAX_RETAINED_DIAGNOSTICS {
            return Err("DIAGNOSTIC_RETENTION_QUOTA");
        }
        let id = Uuid::new_v4();
        let nonce = id.simple().to_string();
        let canary_base = self.profile.join("canaries").join(&nonce);
        let _canary_pin = fresh_directory(&canary_base, &self.owner)?;
        let write = canary_base.join("write.txt");
        let delete = canary_base.join("delete.txt");
        let blocked = canary_base.join("blocked.txt");
        let readonly = canary_base.join("readonly.txt");
        for p in [&write, &delete, &blocked, &readonly] {
            let mut f = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(p)
                .map_err(|_| "CANARY_CREATE_FAILED")?;
            f.write_all(b"SYNTHETIC_HOST_CANARY")
                .map_err(|_| "CANARY_CREATE_FAILED")?;
            f.sync_all().map_err(|_| "CANARY_CREATE_FAILED")?;
        }
        let metadata = self
            .profile
            .join("metadata")
            .join(format!("canary-{nonce}.txt"));
        std::fs::write(&metadata, b"SYNTHETIC_MANAGER_CANARY")
            .map_err(|_| "CANARY_CREATE_FAILED")?;
        let sibling = PathBuf::from(self.root_for(owned.id)).join(format!("canary-{nonce}.txt"));
        std::fs::write(&sibling, b"SYNTHETIC_SIBLING_CANARY")
            .map_err(|_| "CANARY_CREATE_FAILED")?;
        let metadata_alias = canary_base.join("metadata-alias");
        let sibling_alias = canary_base.join("sibling-alias");
        let _metadata_alias_pin =
            aliases::junction(&metadata_alias, &self.profile.join("metadata"), &self.owner)?;
        let _sibling_alias_pin = aliases::junction(
            &sibling_alias,
            Path::new(&self.root_for(owned.id)),
            &self.owner,
        )?;
        let metadata_alias_file =
            metadata_alias.join(metadata.file_name().ok_or("CANARY_SCOPE_INVALID")?);
        let sibling_alias_file =
            sibling_alias.join(sibling.file_name().ok_or("CANARY_SCOPE_INVALID")?);
        if std::fs::read(&metadata_alias_file).map_err(|_| "CANARY_ALIAS_POSITIVE_FAILED")?
            != b"SYNTHETIC_MANAGER_CANARY"
            || std::fs::read(&sibling_alias_file).map_err(|_| "CANARY_ALIAS_POSITIVE_FAILED")?
                != b"SYNTHETIC_SIBLING_CANARY"
        {
            return Err("CANARY_ALIAS_POSITIVE_FAILED");
        }
        let desired = owned.desired.clone();
        let mandatory = Mandatory {
            root: self.root_for(id),
            metadata: self.metadata(),
            code: self.code(),
            siblings: vec![self.root_for(owned.id)],
            marker: format!("v1:{}:{nonce}", self.owner),
        };
        let mut compiled = compile(&desired, &mandatory)?;
        // Keep the full owned policy's mandatory sibling layer, including a
        // stopped rollout's not-yet-materialized root. The diagnostic adds
        // denial of the owned root itself but must not discard other siblings.
        let closed = compiled.section.entry("ClosedFilePath".into()).or_default();
        for path in owned
            .compiled
            .section
            .get("ClosedFilePath")
            .ok_or("MANDATORY_POLICY_DRIFT")?
        {
            if !closed.contains(path) {
                closed.push(path.clone());
            }
        }
        if closed.len() >= 64 {
            return Err("POLICY_RULE_BOUND");
        }
        // Generated synthetic checks do not consume the user's grant quota.
        // They can only narrow this fresh diagnostic, never an owned policy.
        for (key, path) in [("ClosedFilePath", &blocked), ("ReadFilePath", &readonly)] {
            let path = literal_path(&path.to_string_lossy())?;
            let values = compiled.section.entry(key.into()).or_default();
            values.extend([path.clone(), format!("{path}\\*")]);
            if values.len() >= 64 {
                return Err("POLICY_RULE_BOUND");
            }
        }
        compiled.desired_fingerprint = fingerprint(&compiled.section);
        let mut diagnostic = OwnedEnvironment {
            id,
            display_name: "Fresh synthetic diagnostic".into(),
            owner_sid: self.owner.clone(),
            engine_identity: self.engine_identity(),
            root_identity: None,
            generation: 0,
            lifecycle: crate::lifecycle::State::Active,
            mode: crate::lifecycle::Mode::Persistent,
            disposable_pending: false,
            lifecycle_operation: None,
            revision: 0,
            stage: Stage::PendingRoot,
            desired,
            compiled,
            fingerprint: None,
            enforcement_evidence: None,
            enforcement_binding: None,
            reason: "DIAGNOSTIC_ONLY".into(),
            operation_id: id,
            operation_signature: fingerprint(&("DIAGNOSTIC", id)),
            baseline: None,
            observed: None,
            production_launch_available: false,
        };
        // Persist the exact generated scope before engine effects. Failed diagnostics
        // remain disabled and visible; there is no generic recursive cleanup.
        let record = self
            .profile
            .join("metadata")
            .join(format!("diagnostic-{nonce}.json"));
        let mut f = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&record)
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        f.write_all(
            &serde_json::to_vec(&diagnostic).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
        )
        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        f.sync_all().map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        self.write(&diagnostic, &Section::new())?;
        verify_readback(
            &diagnostic.compiled,
            &self.section(&diagnostic.name(), false)?,
            &self.section(&diagnostic.name(), true)?,
            &global,
        )?;
        diagnostic.root_identity = Some(self.create_root(&diagnostic)?);
        self.validate_root(&diagnostic)?;
        registry_value(&nonce, Some(1))?;
        self.root_leases
            .borrow_mut()
            .retain(|file| identity(file).ok() != diagnostic.root_identity);
        let endpoints = Endpoints::new(&self.profile.join("metadata"), &nonce)?;
        let icmp_observer = network::IcmpObserver::new(&nonce)?;
        let dns = network::DnsControl::new(&nonce, &self.profile.join("metadata"))?;
        let raw_host = network::raw_echo(&format!("control-{nonce}"));
        if raw_host.created && !raw_host.echo_received {
            std::fs::write(
                self.profile
                    .join("metadata")
                    .join(format!("raw-status-{nonce}.json")),
                serde_json::to_vec(&raw_host).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
            )
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
            return Err("RAW_CONTROL_POSITIVE_FAILED");
        }
        let icmp_before = network::icmp_sent()?;
        let smb_positive = network::share_positive(network::SHARE_CANARY);
        let mapped_positive = network::share_positive(network::MAPPED_CANARY);
        let output = canary_base.join(format!("report-{nonce}.json"));
        let incoming_output = canary_base.join(format!("incoming-{nonce}.json"));
        let incoming = network::IncomingControl::new(
            PathBuf::from(self.root_for(id)),
            incoming_output
                .file_name()
                .and_then(|v| v.to_str())
                .ok_or("CANARY_SCOPE_INVALID")?
                .to_owned(),
            owned.compiled.offline,
        );
        let canary = Canary {
            box_name: diagnostic.name(),
            write: write.to_string_lossy().into(),
            delete: delete.to_string_lossy().into(),
            blocked: blocked.to_string_lossy().into(),
            read_only: readonly.to_string_lossy().into(),
            metadata: metadata.to_string_lossy().into(),
            sibling: Some(sibling.to_string_lossy().into()),
            metadata_alias: metadata_alias_file.to_string_lossy().into(),
            sibling_alias: sibling_alias_file.to_string_lossy().into(),
            metadata_short: aliases::short(&metadata.to_string_lossy()),
            sibling_short: aliases::short(&sibling.to_string_lossy()),
            output: output.to_string_lossy().into(),
            incoming_output: incoming_output.to_string_lossy().into(),
            registry_leaf: nonce.clone(),
            ports: endpoints.ports,
            dns_target: dns.target_name.clone(),
            dns_cached: dns.cache_name.clone(),
            mapped_share: mapped_positive,
            lan_address: endpoints.lan_address,
            child: false,
            offline: owned.compiled.offline,
        };
        let encoded = hex(&serde_json::to_vec(&canary).map_err(|_| "PROBE_REQUEST_INVALID")?);
        let command = wide(&format!("\"{}\" {encoded}", probe.to_string_lossy()));
        let run: Run = unsafe { bind(&self.api, b"SbieDll_RunSandboxed\0")? };
        self.set(&diagnostic.name(), "Enabled", &["y".into()])?;
        self.reload()?;
        let result = (|| -> R<CanaryReport> {
            let mut startup = unsafe { std::mem::zeroed::<STARTUPINFOW>() };
            startup.cb = std::mem::size_of_val(&startup) as u32;
            let mut receipt = unsafe { std::mem::zeroed::<PROCESS_INFORMATION>() };
            let dir = wide(&system_directory()?.to_string_lossy());
            if unsafe {
                run(
                    wide(&diagnostic.name()).as_ptr(),
                    command.as_ptr(),
                    dir.as_ptr(),
                    CREATE_NO_WINDOW,
                    &mut startup,
                    &mut receipt,
                )
            } == 0
            {
                return Err("DIAGNOSTIC_DISPATCH_REFUSED");
            }
            let process = Handle(receipt.hProcess);
            let _thread = Handle(receipt.hThread);
            if unsafe { WaitForSingleObject(process.0, 30000) } != WAIT_OBJECT_0 {
                // Only the fixed benign process held from this dispatch may be
                // terminated. A timeout never authorizes a PID-based box stop.
                unsafe {
                    TerminateProcess(process.0, 79);
                    WaitForSingleObject(process.0, 5000);
                }
                return Err("DIAGNOSTIC_OUTCOME_UNKNOWN");
            }
            let mut code = 0;
            if unsafe { GetExitCodeProcess(process.0, &mut code) } == 0 {
                return Err("DIAGNOSTIC_EXIT_UNKNOWN");
            }
            if code != 0 {
                // A numeric OS exit status contains no target data. Retain it in
                // private metadata so a failed diagnostic can be distinguished
                // from a missing report without publishing paths or arguments.
                let status = serde_json::json!({"schema":1,"exit_code_hex":format!("{code:08x}")});
                std::fs::write(
                    self.profile
                        .join("metadata")
                        .join(format!("probe-status-{nonce}.json")),
                    serde_json::to_vec(&status).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
                )
                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
                return Err(match code {
                    71 => "DIAGNOSTIC_CONTEXT_NOT_BOXED",
                    72 => "DIAGNOSTIC_BOX_ID_MISMATCH",
                    73 => "DIAGNOSTIC_HOST_CANARY_UNREADABLE",
                    74 => "DIAGNOSTIC_REPORT_WRITE_REFUSED",
                    75 => "DIAGNOSTIC_REGISTRY_UNAVAILABLE",
                    76 => "DIAGNOSTIC_REQUEST_INVALID",
                    0xc0000142 => "DIAGNOSTIC_DLL_INITIALIZATION_FAILED",
                    0xc0000005 => "DIAGNOSTIC_NATIVE_ACCESS_VIOLATION",
                    _ => "DIAGNOSTIC_EXECUTION_FAILED",
                });
            }
            // Original RPC support processes may outlive the fixed canary.
            self.stop_diagnostic(&diagnostic)?;
            let p = locate_report(
                Path::new(&self.root_for(id)),
                output.file_name().unwrap().to_str().unwrap(),
            )?;
            let mut f = lease(&p, false)?;
            let mut data = vec![];
            Read::by_ref(&mut f)
                .take(4097)
                .read_to_end(&mut data)
                .map_err(|_| "DIAGNOSTIC_REPORT_INVALID")?;
            if data.len() > 4096 {
                return Err("DIAGNOSTIC_REPORT_INVALID");
            }
            serde_json::from_slice(&data).map_err(|_| "DIAGNOSTIC_REPORT_INVALID")
        })();
        let fenced = self.set(&diagnostic.name(), "Enabled", &["n".into()]);
        let endpoint_control_counts = endpoints.control_counts;
        let observed = endpoints.observed();
        fenced?;
        let report = result?;
        let incoming_observed = incoming.observed()?;
        let icmp_observed = icmp_observer.observed();
        // Preserve the typed, minimized result even when a mandatory check
        // below refuses verification. These booleans contain no target data
        // and never constitute an enforcement receipt on their own.
        std::fs::write(
            self.profile
                .join("metadata")
                .join(format!("probe-result-{nonce}.json")),
            serde_json::to_vec(&serde_json::json!({"schema":1,"report":report,"raw_host_control":raw_host,"icmp_observer":icmp_observed,"server_observed":observed,"endpoint_control_counts":endpoint_control_counts,"incoming_host_observed":incoming_observed,"dns_server_observed":dns.observed(),"unattributed_icmp_echo_delta":network::icmp_sent()?.wrapping_sub(icmp_before),"smb_host_positive":smb_positive,"mapped_share_host_positive":mapped_positive}))
                .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
        )
        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        for (passed, code) in [
            (report.member, "CANARY_MEMBERSHIP_FAILED"),
            (
                report.virtualized_write,
                "CANARY_WRITE_VIRTUALIZATION_FAILED",
            ),
            (
                report.virtualized_delete,
                "CANARY_DELETE_VIRTUALIZATION_FAILED",
            ),
            (report.blocked_read, "CANARY_BLOCKED_READ_FAILED"),
            (report.read_only_read, "CANARY_READ_ONLY_READ_FAILED"),
            (
                report.read_only_write_denied,
                "CANARY_READ_ONLY_WRITE_FAILED",
            ),
            (report.metadata_denied, "CANARY_METADATA_DENIAL_FAILED"),
            (report.sibling_denied, "CANARY_SIBLING_DENIAL_FAILED"),
            (
                report.metadata_case_denied && report.sibling_case_denied,
                "CANARY_CASE_ALIAS_DENIAL_FAILED",
            ),
            (
                report.metadata_short_denied.unwrap_or(true)
                    && report.sibling_short_denied.unwrap_or(true),
                "CANARY_SHORT_ALIAS_DENIAL_FAILED",
            ),
            (
                report.metadata_alias_denied && report.sibling_alias_denied,
                "CANARY_REPARSE_ALIAS_DENIAL_FAILED",
            ),
            (report.smb_denied, "CANARY_SMB_DENIAL_FAILED"),
            (
                report.bits_activation_status == 0x80070005u32 as i32,
                "CANARY_BITS_ACTIVATION_NOT_DENIED",
            ),
            (
                report.mapped_share_denied.unwrap_or(!mapped_positive),
                "CANARY_MAPPED_SHARE_DENIAL_FAILED",
            ),
            (
                report.standard_read_visible,
                "CANARY_STANDARD_VISIBILITY_FAILED",
            ),
            (
                report.registry_virtualized,
                "CANARY_REGISTRY_VIRTUALIZATION_FAILED",
            ),
        ] {
            if !passed {
                return Err(code);
            }
        }
        if std::fs::read(&delete).map_err(|_| "CANARY_READ_FAILED")? != b"SYNTHETIC_HOST_CANARY"
            || std::fs::read(&write).map_err(|_| "CANARY_READ_FAILED")? != b"SYNTHETIC_HOST_CANARY"
            || std::fs::read(&readonly).map_err(|_| "CANARY_READ_FAILED")?
                != b"SYNTHETIC_HOST_CANARY"
            || registry_value(&nonce, None) != Ok(1)
        {
            return Err("CANARY_HOST_STATE_CHANGED");
        }
        let expected = [!owned.compiled.offline; 6];
        if report.child_network.sockets != expected
            || report.child_network.dns_network == owned.compiled.offline
            || report.child_network.icmp_echo == owned.compiled.offline
            || (owned.compiled.offline && report.raw.echo_received)
            || (!owned.compiled.offline && report.raw.created && !report.raw.echo_received)
            || report.dns_network == owned.compiled.offline
            || dns.observed() == owned.compiled.offline
            || report.icmp_echo == owned.compiled.offline
            || (icmp_observed.available && icmp_observed.control_packets == 0)
            || (icmp_observed.available
                && (icmp_observed.target_packets > 0) == owned.compiled.offline)
            || (owned.compiled.offline
                && (report.icmp_status != ERROR_ACCESS_DENIED
                    || report.child_network.icmp_status != ERROR_ACCESS_DENIED
                    || report.raw.send_accepted))
            || report.sockets != expected
            || observed != expected
            || report.incoming != [!owned.compiled.offline; 4]
            || incoming_observed != [!owned.compiled.offline; 4]
        {
            return Err("NETWORK_ENFORCEMENT_FAILED");
        }
        let evidence = serde_json::json!({"schema":1,"family":FAMILY,"probe_sha256":probe_hash,"report":report,"raw_host_control":raw_host,"icmp_observer":icmp_observed,"smb_host_positive":smb_positive,"mapped_share_host_positive":mapped_positive,"dns_server_observed":dns.observed(),"unattributed_icmp_echo_delta":network::icmp_sent()?.wrapping_sub(icmp_before),"server_observed":observed,"endpoint_control_counts":endpoint_control_counts,"incoming_host_observed":incoming_observed,"host_file_unchanged":true,"host_registry_unchanged":true});
        std::fs::write(
            self.profile
                .join("metadata")
                .join(format!("probe-evidence-{nonce}.json")),
            serde_json::to_vec(&evidence).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
        )
        .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        // Completed private canary definitions must not exhaust ordinary box
        // enumeration. Retire only this worker-generated, fully verified scope;
        // all root data and durable diagnostic evidence remain retained.
        self.mutation_context()?;
        self.validate_root(&diagnostic)?;
        self.idle(&diagnostic.name())?;
        let current_global = self.global()?;
        if current_global != global {
            return Err("DIAGNOSTIC_SCOPE_CHANGED");
        }
        let raw = self.section(&diagnostic.name(), false)?;
        let effective = self.section(&diagnostic.name(), true)?;
        let mut fenced = diagnostic.compiled.clone();
        fenced.section.insert("Enabled".into(), vec!["n".into()]);
        verify_readback(&fenced, &raw, &effective, &current_global)?;
        validate_automation(&raw, &effective, &current_global)?;
        self.set(&diagnostic.name(), "*", &[])?;
        self.reload()?;
        if self.exists(&diagnostic.name())? {
            return Err("DIAGNOSTIC_DEFINITION_STILL_PRESENT");
        }
        let saved_report = locate_report(
            Path::new(&self.root_for(id)),
            output.file_name().unwrap().to_str().unwrap(),
        )?;
        let mut saved_file = lease(&saved_report, false)?;
        let mut saved_bytes = Vec::new();
        Read::by_ref(&mut saved_file)
            .take(4097)
            .read_to_end(&mut saved_bytes)
            .map_err(|_| "DIAGNOSTIC_RETAINED_REPORT_CHANGED")?;
        if saved_bytes.len() > 4096 {
            return Err("DIAGNOSTIC_RETAINED_REPORT_CHANGED");
        }
        let retained: CanaryReport = serde_json::from_slice(&saved_bytes)
            .map_err(|_| "DIAGNOSTIC_RETAINED_REPORT_CHANGED")?;
        if fingerprint(&retained) != fingerprint(&report) {
            return Err("DIAGNOSTIC_RETAINED_REPORT_CHANGED");
        }
        let retired = self
            .profile
            .join("metadata")
            .join(format!("probe-retired-{nonce}.json"));
        let mut retired_file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(retired)
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        let retirement = serde_json::json!({"schema":1,"completed":true,"definition_removed":true,"root_data_retained":true,"synthetic_report_unchanged":true});
        retired_file
            .write_all(
                &serde_json::to_vec(&retirement).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
            )
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        retired_file
            .sync_all()
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
        Ok(fingerprint(&(
            FAMILY,
            probe_hash,
            &report,
            observed,
            incoming_observed,
            icmp_observed,
        )))
    }
}
