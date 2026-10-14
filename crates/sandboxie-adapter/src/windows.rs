//! Independently declared read-only ABI for the source-pinned native 64-bit engine.
pub mod provisioning;
use crate::*;
use sha2::{Digest, Sha256};
use std::{
    ffi::c_void,
    fs::{File, OpenOptions},
    io::Read,
    os::windows::{fs::OpenOptionsExt, io::AsRawHandle, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    ptr,
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Authorization::*, WinTrust::*, *},
    Storage::FileSystem::*,
    System::{
        JobObjects::*, LibraryLoader::*, Services::*, SystemInformation::*, Threading::*,
        WindowsProgramming::*,
    },
};

type R<T> = Result<T, &'static str>;
fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(Some(0)).collect()
}
fn box_wide(name: &str) -> R<[u16; 40]> {
    if !valid_box(name) {
        return Err("BOX_NAMESPACE_INVALID");
    }
    let mut data = [0u16; 40];
    for (i, c) in name.encode_utf16().enumerate() {
        data[i] = c;
    }
    Ok(data)
}
fn text(data: &[u16]) -> R<String> {
    let end = data
        .iter()
        .position(|v| *v == 0)
        .ok_or("NATIVE_TEXT_BOUND")?;
    let value = String::from_utf16(&data[..end]).map_err(|_| "NATIVE_TEXT_INVALID")?;
    if value
        .chars()
        .any(|c| c.is_control() || matches!(c,'\u{202a}'..='\u{202e}'|'\u{2066}'..='\u{2069}'))
    {
        return Err("NATIVE_TEXT_INVALID");
    }
    Ok(value)
}
unsafe fn pointer_text(p: *const u16, max: usize) -> R<String> {
    if p.is_null() {
        return Err("NATIVE_TEXT_INVALID");
    }
    let mut v = Vec::new();
    for i in 0..max {
        let c = unsafe { *p.add(i) };
        v.push(c);
        if c == 0 {
            return text(&v);
        }
    }
    Err("NATIVE_TEXT_BOUND")
}
struct Handle(HANDLE);
impl Drop for Handle {
    fn drop(&mut self) {
        unsafe {
            CloseHandle(self.0);
        }
    }
}
unsafe fn sid_string(sid: PSID) -> R<String> {
    let mut p = ptr::null_mut();
    if unsafe { ConvertSidToStringSidW(sid, &mut p) } == 0 {
        return Err("IDENTITY_UNKNOWN");
    }
    let s = unsafe { pointer_text(p, 184) };
    unsafe {
        LocalFree(p as _);
    };
    s
}
fn privileged(s: &str) -> bool {
    matches!(
        s,
        "S-1-5-18"
            | "S-1-5-32-544"
            | "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"
    )
}
fn identity(file: &File) -> R<String> {
    unsafe {
        let mut info = std::mem::zeroed::<BY_HANDLE_FILE_INFORMATION>();
        if GetFileInformationByHandle(file.as_raw_handle(), &mut info) == 0
            || info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0
            || (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == 0 && info.nNumberOfLinks != 1)
        {
            return Err("REPARSE_OR_HARDLINK_REJECTED");
        }
        Ok(format!(
            "{:08x}:{:08x}{:08x}",
            info.dwVolumeSerialNumber, info.nFileIndexHigh, info.nFileIndexLow
        ))
    }
}
fn protected(file: &File) -> R<()> {
    unsafe {
        let mut owner = ptr::null_mut();
        let mut dacl = ptr::null_mut();
        let mut descriptor = ptr::null_mut();
        if GetSecurityInfo(
            file.as_raw_handle(),
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            &mut owner,
            ptr::null_mut(),
            &mut dacl,
            ptr::null_mut(),
            &mut descriptor,
        ) != 0
        {
            return Err("COMPONENT_ACL_UNKNOWN");
        }
        let result = (|| {
            if !privileged(&sid_string(owner)?) || dacl.is_null() {
                return Err("COMPONENT_WRITABLE");
            }
            let acl = &*dacl;
            if acl.AceCount > 256 {
                return Err("COMPONENT_ACL_UNKNOWN");
            }
            for index in 0..acl.AceCount as u32 {
                let mut ace = ptr::null_mut();
                if GetAce(dacl, index, &mut ace) == 0 {
                    return Err("COMPONENT_ACL_UNKNOWN");
                }
                let header = &*(ace as *const ACE_HEADER);
                if header.AceFlags & INHERIT_ONLY_ACE as u8 != 0 {
                    continue;
                }
                // Unknown access-grant forms are rejected, never interpreted as harmless.
                if header.AceType == 0 {
                    // ACCESS_ALLOWED_ACE_TYPE
                    let allowed = &*(ace as *const ACCESS_ALLOWED_ACE);
                    let write = 0x10000000 | 0x40000000 | 0x000d0000 | 0x00000156;
                    if allowed.Mask & write != 0
                        && !privileged(&sid_string(&allowed.SidStart as *const _ as _)?)
                    {
                        return Err("COMPONENT_WRITABLE");
                    }
                } else if header.AceType != 1 {
                    return Err("COMPONENT_ACL_UNKNOWN");
                } // ACCESS_DENIED_ACE_TYPE
            }
            Ok(())
        })();
        LocalFree(descriptor as _);
        result
    }
}
fn lease(path: &Path, writable: bool) -> R<File> {
    let f = OpenOptions::new()
        .access_mode(if writable {
            FILE_READ_ATTRIBUTES | READ_CONTROL
        } else {
            GENERIC_READ | READ_CONTROL
        })
        .share_mode(if writable {
            FILE_SHARE_READ | FILE_SHARE_WRITE
        } else {
            FILE_SHARE_READ
        })
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
        .map_err(|_| "COMPONENT_OPEN_FAILED")?;
    identity(&f)?;
    Ok(f)
}
fn ancestry(path: &Path) -> R<Vec<File>> {
    if !path.is_absolute() || path.to_string_lossy().starts_with("\\\\") {
        return Err("INSTALL_PATH_UNSAFE");
    }
    let mut paths = path.ancestors().collect::<Vec<_>>();
    paths.reverse();
    paths.into_iter().map(|p| lease(p, true)).collect()
}
fn signature(path: &Path, file: &File) -> R<()> {
    unsafe {
        let p = wide(&path.to_string_lossy());
        let mut fi = std::mem::zeroed::<WINTRUST_FILE_INFO>();
        fi.cbStruct = std::mem::size_of_val(&fi) as u32;
        fi.pcwszFilePath = p.as_ptr();
        fi.hFile = file.as_raw_handle();
        let mut data = std::mem::zeroed::<WINTRUST_DATA>();
        data.cbStruct = std::mem::size_of_val(&data) as u32;
        data.dwUIChoice = WTD_UI_NONE;
        data.dwUnionChoice = WTD_CHOICE_FILE;
        data.Anonymous.pFile = &mut fi;
        data.dwStateAction = WTD_STATEACTION_VERIFY;
        // Windows Authenticode policy defaults. No trust/revocation bypass flags.
        let mut action = WINTRUST_ACTION_GENERIC_VERIFY_V2;
        let status = WinVerifyTrust(ptr::null_mut(), &mut action, &mut data as *mut _ as _);
        data.dwStateAction = WTD_STATEACTION_CLOSE;
        WinVerifyTrust(ptr::null_mut(), &mut action, &mut data as *mut _ as _);
        if status != 0 {
            Err("AUTHENTICODE_REJECTED")
        } else {
            Ok(())
        }
    }
}
pub fn process_birth(pid: u32) -> R<u64> {
    let h = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) };
    if h.is_null() {
        return Err("PROCESS_IDENTITY_UNKNOWN");
    }
    let h = Handle(h);
    birth(&h)
}
pub fn has_engine_module() -> bool {
    // The desktop never loads engine code in-process. Presence conservatively
    // refuses startup; absence is NOT evidence of an unboxed context.
    unsafe { !GetModuleHandleW(wide("SbieDll.dll").as_ptr()).is_null() }
}
pub fn host_transition_marker() -> String {
    let mut unbiased = 0;
    let epoch = unsafe {
        if QueryUnbiasedInterruptTime(&mut unbiased) != 0 {
            GetTickCount64().saturating_sub(unbiased / 10000) / 1000
        } else {
            0
        }
    };
    match (service("SbieSvc"), service("SbieDrv")) {
        (Ok(s), Ok(d)) => format!("{:?}:{}:{}:{}", s.identity, s.running, d.running, epoch),
        _ => format!("UNKNOWN:{epoch}"),
    }
}
fn birth(h: &Handle) -> R<u64> {
    unsafe {
        let (mut a, mut b, mut c, mut d) = (
            std::mem::zeroed::<FILETIME>(),
            std::mem::zeroed(),
            std::mem::zeroed(),
            std::mem::zeroed(),
        );
        if GetProcessTimes(h.0, &mut a, &mut b, &mut c, &mut d) == 0 {
            return Err("PROCESS_IDENTITY_UNKNOWN");
        }
        Ok(((a.dwHighDateTime as u64) << 32) | a.dwLowDateTime as u64)
    }
}
struct Service {
    path: PathBuf,
    running: bool,
    identity: Option<String>,
    identity_complete: bool,
}
fn service(name: &str) -> R<Service> {
    unsafe {
        let scm = OpenSCManagerW(ptr::null(), ptr::null(), SC_MANAGER_CONNECT);
        if scm.is_null() {
            return Err("SERVICE_ACCESS_UNKNOWN");
        }
        let svc = OpenServiceW(
            scm,
            wide(name).as_ptr(),
            SERVICE_QUERY_CONFIG | SERVICE_QUERY_STATUS,
        );
        let open_error = GetLastError();
        CloseServiceHandle(scm);
        if svc.is_null() {
            return Err(if open_error == ERROR_SERVICE_DOES_NOT_EXIST {
                "ENGINE_MISSING"
            } else {
                "SERVICE_ACCESS_UNKNOWN"
            });
        }
        let result = (|| {
            let mut bytes = 0;
            QueryServiceConfigW(svc, ptr::null_mut(), 0, &mut bytes);
            if bytes == 0 || bytes > 16384 {
                return Err("SERVICE_METADATA_INVALID");
            }
            let mut buffer = vec![0u64; (bytes as usize).div_ceil(8)];
            let cfg = buffer.as_mut_ptr() as *mut QUERY_SERVICE_CONFIGW;
            if QueryServiceConfigW(svc, cfg, bytes, &mut bytes) == 0 {
                return Err("SERVICE_METADATA_INVALID");
            }
            let command = pointer_text((*cfg).lpBinaryPathName, 4096)?;
            let path = if let Some(s) = command.strip_prefix('"') {
                let end = s.find('"').ok_or("SERVICE_PATH_INVALID")?;
                if !s[end + 1..].trim().is_empty() {
                    return Err("SERVICE_ARGUMENTS_REJECTED");
                }
                &s[..end]
            } else {
                command.as_str()
            };
            let mut status = std::mem::zeroed::<SERVICE_STATUS_PROCESS>();
            let mut needed = 0;
            if QueryServiceStatusEx(
                svc,
                SC_STATUS_PROCESS_INFO,
                &mut status as *mut _ as _,
                std::mem::size_of_val(&status) as u32,
                &mut needed,
            ) == 0
            {
                return Err("SERVICE_STATUS_UNKNOWN");
            }
            let mut identity_complete = false;
            let id = if status.dwProcessId != 0 {
                let process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, status.dwProcessId);
                if process.is_null() {
                    // Original SbieSvc protects its process object from ordinary
                    // users. SCM status is still an OS observation, not birth/image
                    // proof. Permit read-only queries and keep controls unavailable.
                    Some(format!(
                        "SCM_PID:{}:PROCESS_IDENTITY_UNKNOWN",
                        status.dwProcessId
                    ))
                } else {
                    let process = Handle(process);
                    let mut image = [0u16; 4096];
                    let mut chars = image.len() as u32;
                    if QueryFullProcessImageNameW(process.0, 0, image.as_mut_ptr(), &mut chars) == 0
                        || !text(&image)?
                            .eq_ignore_ascii_case(path.strip_prefix("\\??\\").unwrap_or(path))
                    {
                        return Err("SERVICE_IMAGE_MISMATCH");
                    }
                    identity_complete = true;
                    Some(format!("{}:{}", status.dwProcessId, birth(&process)?))
                }
            } else {
                None
            };
            Ok(Service {
                path: PathBuf::from(path.strip_prefix("\\??\\").unwrap_or(path)),
                running: status.dwCurrentState == SERVICE_RUNNING,
                identity: id,
                identity_complete,
            })
        })();
        CloseServiceHandle(svc);
        result
    }
}
struct Trusted {
    home: PathBuf,
    _leases: Vec<File>,
    identity: String,
    svc: Service,
    drv: Service,
}
fn discover() -> R<Trusted> {
    let svc = service("SbieSvc")?;
    let drv = service("SbieDrv")?;
    if svc.path.file_name().and_then(|s| s.to_str()) != Some("SbieSvc.exe") {
        return Err("SERVICE_PATH_INVALID");
    }
    let home = svc
        .path
        .parent()
        .ok_or("SERVICE_PATH_INVALID")?
        .to_path_buf();
    if drv.path != home.join("SbieDrv.sys") {
        return Err("DRIVER_PATH_MISMATCH");
    }
    let mut held = ancestry(&home)?;
    protected(held.last().ok_or("INSTALL_PATH_UNSAFE")?)?;
    let manifest: serde_json::Value =
        serde_json::from_str(COMPATIBILITY).map_err(|_| "MANIFEST_INVALID")?;
    if manifest["schema_version"] != 1 || manifest["adapter_protocol"] != PROTOCOL {
        return Err("MANIFEST_VERSION_UNSUPPORTED");
    }
    let target = manifest["targets"]
        .as_array()
        .ok_or("MANIFEST_INVALID")?
        .iter()
        .find(|t| t["architecture"] == std::env::consts::ARCH)
        .ok_or("ARCHITECTURE_UNTESTED")?;
    let mut digest = Sha256::new();
    for entry in target["components"].as_array().ok_or("MANIFEST_INVALID")? {
        let name = entry["name"].as_str().ok_or("MANIFEST_INVALID")?;
        let p = home.join(name);
        let mut f = lease(&p, false)?;
        protected(&f)?;
        if f.metadata().map_err(|_| "COMPONENT_OPEN_FAILED")?.len() > 32 * 1024 * 1024 {
            return Err("COMPONENT_SIZE_BOUND");
        }
        let mut data = Vec::new();
        f.read_to_end(&mut data)
            .map_err(|_| "COMPONENT_READ_FAILED")?;
        let hash = format!("{:x}", Sha256::digest(&data));
        if entry["sha256"] != hash {
            return Err("COMPONENT_UNTESTED_OR_CHANGED");
        }
        if data.len() < 64 {
            return Err("COMPONENT_PE_INVALID");
        }
        let offset = u32::from_le_bytes(data[0x3c..0x40].try_into().unwrap()) as usize;
        let machine = data
            .get(offset + 4..offset + 6)
            .ok_or("COMPONENT_PE_INVALID")?;
        if machine
            != if cfg!(target_arch = "aarch64") {
                [0x64, 0xaa]
            } else {
                [0x64, 0x86]
            }
        {
            return Err("COMPONENT_ARCHITECTURE_MISMATCH");
        }
        signature(&p, &f)?;
        digest.update(hash.as_bytes());
        digest.update(identity(&f)?.as_bytes());
        held.push(f);
    }
    Ok(Trusted {
        home,
        _leases: held,
        identity: format!("{:x}", digest.finalize()),
        svc,
        drv,
    })
}

type Version = unsafe extern "C" fn(*mut u16, *mut u32) -> i32;
type Query =
    unsafe extern "C" fn(HANDLE, u32, *mut u16, *mut u16, *mut u16, *mut u32, *mut u64) -> i32;
type Info = unsafe extern "C" fn(u32, *mut c_void, u32) -> i32;
type Conf = unsafe extern "C" fn(*const u16, *const u16, u32, *mut u16, u32) -> i32;
type Enum = unsafe extern "C" fn(*const u16, u8, u32, *mut u32, *mut u32) -> i32;
type Roots = unsafe extern "C" fn(
    *const u16,
    *mut u16,
    *mut u16,
    *mut u16,
    *mut u32,
    *mut u32,
    *mut u32,
) -> i32;
type Translate = unsafe extern "C" fn(*mut u16) -> u8;
struct Api {
    module: HMODULE,
    version: Version,
    query: Query,
    info: Info,
    conf: Conf,
    enumerate: Enum,
    roots: Roots,
    translate: Translate,
}
impl Drop for Api {
    fn drop(&mut self) {
        unsafe {
            FreeLibrary(self.module);
        }
    }
}
impl Api {
    fn load(home: &Path) -> R<Self> {
        unsafe {
            if SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32) == 0 {
                return Err("DLL_SEARCH_UNSAFE");
            }
            let m = LoadLibraryExW(
                wide(&home.join("SbieDll.dll").to_string_lossy()).as_ptr(),
                ptr::null_mut(),
                LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32,
            );
            if m.is_null() {
                return Err("DLL_LOAD_FAILED");
            }
            macro_rules! bind {
                ($name:literal,$t:ty) => {{
                    let p = GetProcAddress(m, concat!($name, "\0").as_ptr());
                    if p.is_none() {
                        FreeLibrary(m);
                        return Err("ABI_EXPORT_MISSING");
                    }
                    std::mem::transmute::<unsafe extern "system" fn() -> isize, $t>(p.unwrap())
                }};
            }
            Ok(Self {
                module: m,
                version: bind!("SbieApi_GetVersionEx", Version),
                query: bind!("SbieApi_QueryProcessEx2", Query),
                info: bind!("SbieApi_QueryDrvInfo", Info),
                conf: bind!("SbieApi_QueryConf", Conf),
                enumerate: bind!("SbieApi_EnumProcessEx", Enum),
                roots: bind!("SbieApi_QueryBoxPath", Roots),
                translate: bind!("SbieDll_TranslateNtToDosPath", Translate),
            })
        }
    }
    fn context(&self, pid: u32) -> Context {
        let mut name = [0u16; 40];
        let mut session = 0;
        let status = unsafe {
            (self.query)(
                pid as usize as _,
                0,
                name.as_mut_ptr(),
                ptr::null_mut(),
                ptr::null_mut(),
                &mut session,
                ptr::null_mut(),
            )
        };
        match status as u32 {
            0 => Context::Boxed,
            0xc000000b => Context::Unboxed,
            _ => Context::Unknown,
        }
    }
    fn conf(&self, section: Option<&str>, key: Option<&str>, index: u32) -> R<Option<String>> {
        let section = section.map(wide);
        let key = key.map(wide);
        let mut output = [0u16; 2048];
        let status = unsafe {
            (self.conf)(
                section.as_ref().map_or(ptr::null(), |v| v.as_ptr()),
                key.as_ref().map_or(ptr::null(), |v| v.as_ptr()),
                index,
                output.as_mut_ptr(),
                4096,
            )
        };
        if status as u32 == 0xc000008b {
            Ok(None)
        } else if status != 0 {
            Err("CONFIGURATION_UNKNOWN")
        } else {
            text(&output).map(Some)
        }
    }
    fn values(&self, section: &str, key: &str, flags: u32) -> R<Vec<String>> {
        let mut values = Vec::new();
        for i in 0..64 {
            match self.conf(Some(section), Some(key), i | flags)? {
                Some(v) => values.push(v),
                None => return Ok(values),
            }
        }
        Err("CONFIGURATION_BOUND")
    }
    fn count(&self, name: &[u16]) -> R<usize> {
        let mut count = 0;
        if unsafe { (self.enumerate)(name.as_ptr(), 1, u32::MAX, ptr::null_mut(), &mut count) } != 0
        {
            Err("ENUMERATION_UNKNOWN")
        } else {
            Ok(count as usize)
        }
    }
    fn processes(&self, name: &str) -> R<Vec<ProcessIdentity>> {
        let b = box_wide(name)?;
        let before = self.count(&b)?;
        if before >= MAX_PROCESSES {
            return Err("ENUMERATION_BOUND");
        }
        let mut pids = [0u32; MAX_PROCESSES];
        let mut count = MAX_PROCESSES as u32;
        if unsafe { (self.enumerate)(b.as_ptr(), 1, u32::MAX, pids.as_mut_ptr(), &mut count) } != 0
            || !enumeration_complete(before, count as usize, self.count(&b)?, MAX_PROCESSES)
        {
            return Err("ENUMERATION_INCOMPLETE");
        }
        let mut out = Vec::new();
        for pid in &pids[..count as usize] {
            let h = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, *pid) };
            if h.is_null() {
                return Err("PROCESS_IDENTITY_UNKNOWN");
            }
            let h = Handle(h);
            let actual = birth(&h)?;
            let mut box_name = [0u16; 40];
            let mut sid = [0u16; 96];
            let mut session = 0;
            let mut created = 0;
            if unsafe {
                (self.query)(
                    *pid as usize as _,
                    0,
                    box_name.as_mut_ptr(),
                    ptr::null_mut(),
                    sid.as_mut_ptr(),
                    &mut session,
                    &mut created,
                )
            } != 0
                || actual != created
                || text(&box_name)? != name
            {
                return Err("PROCESS_IDENTITY_CHANGED");
            }
            if out.iter().any(|p: &ProcessIdentity| p.pid == *pid) {
                return Err("ENUMERATION_DUPLICATE");
            }
            out.push(ProcessIdentity {
                pid: *pid,
                creation_time: created,
                owner_sid: text(&sid)?,
                session,
                box_name: name.into(),
            });
        }
        if self.count(&b)? != out.len() {
            return Err("ENUMERATION_CHANGED");
        }
        Ok(out)
    }
    fn root(&self, name: &str) -> RootObservation {
        let result = (|| {
            let b = box_wide(name)?;
            let mut bytes = 0;
            if unsafe {
                (self.roots)(
                    b.as_ptr(),
                    ptr::null_mut(),
                    ptr::null_mut(),
                    ptr::null_mut(),
                    &mut bytes,
                    ptr::null_mut(),
                    ptr::null_mut(),
                )
            } != 0
                || bytes == 0
                || bytes > 8192
                || bytes % 2 != 0
            {
                return Err("ROOT_QUERY_UNKNOWN");
            }
            let mut output = [0u16; 4096];
            let mut capacity = 8192;
            if unsafe {
                (self.roots)(
                    b.as_ptr(),
                    output.as_mut_ptr(),
                    ptr::null_mut(),
                    ptr::null_mut(),
                    &mut capacity,
                    ptr::null_mut(),
                    ptr::null_mut(),
                )
            } != 0
                || capacity > 8192
                || unsafe { (self.translate)(output.as_mut_ptr()) } == 0
            {
                return Err("ROOT_QUERY_UNKNOWN");
            }
            let path = text(&output)?;
            let p = Path::new(&path);
            if let Err(error) = std::fs::symlink_metadata(p) {
                if error.kind() != std::io::ErrorKind::NotFound {
                    return Err("ROOT_IDENTITY_UNKNOWN");
                }
                return Ok(RootObservation {
                    path: Some(path),
                    identity: None,
                    reason: "PENDING_ROOT".into(),
                    scope: "CURRENT_CALLER_ONLY".into(),
                });
            }
            let held = ancestry(p)?;
            let id = identity(held.last().ok_or("ROOT_IDENTITY_UNKNOWN")?)?;
            Ok(RootObservation {
                path: Some(path),
                identity: Some(id),
                reason: "OBSERVED_NOT_ADOPTED".into(),
                scope: "CURRENT_CALLER_ONLY".into(),
            })
        })();
        result.unwrap_or_else(|reason| RootObservation {
            path: None,
            identity: None,
            reason: reason.into(),
            scope: "CURRENT_CALLER_ONLY".into(),
        })
    }
    fn box_observation(&self, name: &str) -> BoxObservation {
        let processes = self.processes(name);
        let mut complete = processes.is_ok();
        let mut reason = processes.as_ref().err().copied().unwrap_or("OBSERVED");
        let mut configuration = Vec::new();
        for key in [
            "Enabled",
            "FileRootPath",
            "KeyRootPath",
            "IpcRootPath",
            "Template",
            "AutoRecover",
            "AutoDelete",
            "NeverDelete",
            "OpenFilePath",
            "ClosedFilePath",
            "ReadFilePath",
            "OpenIpcPath",
            "ClosedIpcPath",
            "OpenKeyPath",
            "ClosedKeyPath",
            "ReadKeyPath",
            "BlockNetworkFiles",
            "AllowNetworkAccess",
            "NetworkAccess",
            "DropAdminRights",
            "RunCommand",
            "OnBoxDelete",
            "OnBoxTerminate",
            "OnFileRecovery",
        ] {
            match (
                self.values(name, key, 0x70000000),
                self.values(name, key, 0),
            ) {
                (Ok(raw), Ok(effective)) => {
                    configuration.push(ConfigurationEntry {
                        key: key.into(),
                        raw,
                        effective,
                    });
                    if configuration
                        .iter()
                        .flat_map(|v| v.raw.iter().chain(v.effective.iter()))
                        .map(String::len)
                        .sum::<usize>()
                        > 32768
                    {
                        complete = false;
                        reason = "CONFIGURATION_BOUND";
                        break;
                    }
                }
                _ => {
                    complete = false;
                    reason = "CONFIGURATION_INCOMPLETE";
                    break;
                }
            }
        }
        let data = serde_json::to_vec(&configuration).unwrap_or_default();
        let processes = processes.unwrap_or_default();
        let root = self.root(name);
        BoxObservation {
            name: name.into(),
            owned: false,
            read_only: true,
            activity: if !complete {
                "UNKNOWN"
            } else if processes.is_empty() {
                "IDLE"
            } else {
                "RUNNING"
            }
            .into(),
            complete,
            reason: reason.into(),
            processes,
            root,
            configuration,
            configuration_fingerprint: format!("{:x}", Sha256::digest(data)),
        }
    }
}

pub fn observe(manager_pid: u32, manager_birth: u64) -> Observation {
    let mut report = Observation::failure("NOT_OBSERVED");
    report.manager_pid = manager_pid;
    report.manager_birth = manager_birth;
    let result = (|| -> R<()> {
        // Retain the actual parent object before trusting any PID-based engine reply.
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
        if unsafe { WaitForSingleObject(parent.0, 0) } != WAIT_TIMEOUT {
            return Err("MANAGER_NOT_RUNNING");
        }
        if birth(&parent)? != manager_birth {
            return Err("MANAGER_IDENTITY_CHANGED");
        }
        let trusted = discover()?;
        report.trust = "VERIFIED".into();
        report.installation_identity = Some(trusted.identity.clone());
        report.service_running = trusted.svc.running;
        report.driver_running = trusted.drv.running;
        report.service_identity = trusted.svc.identity.clone();
        report.service_identity_complete = trusted.svc.identity_complete;
        report.service_identity_reason = if trusted.svc.identity_complete {
            "PROCESS_IMAGE_AND_BIRTH_VERIFIED"
        } else {
            "SCM_STATUS_ONLY_PROCESS_IDENTITY_UNKNOWN"
        }
        .into();
        let api = Api::load(&trusted.home)?;
        let mut version = [0u16; 16];
        let mut abi = 0;
        if unsafe { (api.version)(version.as_mut_ptr(), &mut abi) } != 0 {
            return Err("DRIVER_UNHEALTHY");
        }
        report.core_version = Some(text(&version)?);
        report.abi = Some(abi);
        if report.core_version.as_deref() != Some("5.73.6") || abi != 0x57230 {
            return Err("ENGINE_VERSION_UNTESTED");
        }
        report.bridge_context = api.context(unsafe { GetCurrentProcessId() });
        report.manager_context = api.context(manager_pid);
        if birth(&parent)? != manager_birth {
            return Err("MANAGER_IDENTITY_CHANGED");
        }
        if unsafe { WaitForSingleObject(parent.0, 0) } != WAIT_TIMEOUT {
            return Err("MANAGER_NOT_RUNNING");
        }
        if report.manager_context != Context::Unboxed || report.bridge_context != Context::Unboxed {
            return Err("MANAGER_CONTEXT_UNSAFE");
        }
        if !report.service_running || !report.driver_running {
            return Err("ENGINE_SERVICE_STOPPED");
        }
        let mut flags = 0u32;
        if unsafe { (api.info)(0, &mut flags as *mut _ as _, 4) } != 0 {
            return Err("DRIVER_INFORMATION_UNKNOWN");
        }
        report.driver_flags = Some(flags);
        let mut cert = 0u32;
        let certificate_status = unsafe { (api.info)(u32::MAX, &mut cert as *mut _ as _, 4) };
        if certificate_status == 0 {
            report.certificate_state = Some(cert);
        }
        report.capabilities = vec![
            Capability {
                name: "service_process_identity".into(),
                availability: if report.service_identity_complete {
                    Availability::Available
                } else {
                    Availability::Unknown
                },
                reason: report.service_identity_reason.clone(),
                provenance: "OS_SCM_AND_PROCESS_OBJECT_ACCESS".into(),
            },
            Capability {
                name: "read_only_observation".into(),
                availability: Availability::Available,
                reason: "TRUSTED_NATIVE_QUERY".into(),
                provenance: "FRESH_DRIVER_SERVICE_CONTEXT".into(),
            },
            Capability {
                name: "paid_profiles".into(),
                availability: if certificate_status == 0 && cert & 1 == 0 {
                    Availability::Unavailable
                } else {
                    Availability::Unknown
                },
                reason: if certificate_status != 0 {
                    "ENTITLEMENT_UNKNOWN"
                } else {
                    "NO_VERIFIED_ENTITLEMENT_AND_ENFORCEMENT"
                }
                .into(),
                provenance: "QUERY_DRV_INFO_LOW32_NOT_CERTIFICATE_CONTENT".into(),
            },
            Capability {
                name: "production_launch".into(),
                availability: Availability::Unavailable,
                reason: "P05_P06_NOT_IMPLEMENTED".into(),
                provenance: "PHASE_BOUNDARY".into(),
            },
        ];
        let mut ended = false;
        for index in 0..MAX_BOXES as u32 {
            let Some(section) = api.conf(None, None, index | 0x30000000)? else {
                ended = true;
                break;
            };
            if matches!(section.as_str(), "GlobalSettings" | "UserSettings")
                || section.starts_with("UserSettings_")
                || section.starts_with("Template_")
            {
                continue;
            }
            if !valid_box(&section) {
                return Err("BOX_NAMESPACE_INVALID");
            }
            // Only sections with an actual Enabled directive are classified as boxes.
            if api.conf(Some(&section), Some("Enabled"), 0)?.is_none() {
                continue;
            }
            report.boxes.push(api.box_observation(&section));
            if serde_json::to_vec(&report.boxes)
                .map_err(|_| "BRIDGE_PROTOCOL_INVALID")?
                .len()
                > RESPONSE_LIMIT / 2
            {
                report.boxes.pop();
                return Err("BOX_RESPONSE_BOUND");
            }
        }
        report.enumeration_complete = ended && report.boxes.iter().all(|b| b.complete);
        if !ended {
            return Err("BOX_ENUMERATION_BOUND");
        }
        let mut unbiased = 0;
        unsafe {
            if QueryUnbiasedInterruptTime(&mut unbiased) != 0 {
                report.resume_epoch_ms = GetTickCount64().saturating_sub(unbiased / 10000);
            }
        }
        Ok(())
    })();
    report.reason = result.err().unwrap_or("OBSERVED").into();
    report.restart_required = matches!(
        report.reason.as_str(),
        "DRIVER_UNHEALTHY" | "ENGINE_VERSION_UNTESTED"
    );
    report
}

/// Same caller used by the desktop shell and the native command-line diagnostic.
/// No user executable/path/arguments or engine mutation can enter this protocol.
pub fn bounded_observe() -> Observation {
    let pid = unsafe { GetCurrentProcessId() };
    let Ok(created) = process_birth(pid) else {
        return Observation::failure("MANAGER_IDENTITY_UNKNOWN");
    };
    let result = (|| -> R<Observation> {
        let executable = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let directory = executable.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?;
        let _home = ancestry(directory)?;
        let _image = lease(&executable, false)?;
        // The worker is this same held image in a narrow console mode. There is
        // no interchangeable sibling executable or PATH lookup.
        let windows = system_directory()?;
        let mut command = Command::new(&executable);
        command
            .args([
                "--engine-worker".into(),
                pid.to_string(),
                created.to_string(),
            ])
            .current_dir(&windows)
            .env_clear()
            .env("SystemRoot", windows.parent().ok_or("SYSTEM_PATH_UNKNOWN")?)
            .env("WINDIR", windows.parent().unwrap())
            .env("PATH", &windows)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW);
        let data = bounded_capture(&mut command, Duration::from_secs(20))?;
        parse_response(&data, pid, created)
    })();
    result.unwrap_or_else(|reason| {
        let mut o = Observation::failure(reason);
        o.manager_pid = pid;
        o.manager_birth = created;
        o
    })
}
fn bounded_capture(command: &mut Command, timeout: Duration) -> R<Vec<u8>> {
    let child = command.spawn().map_err(|_| "BRIDGE_START_FAILED")?;
    capture_child(child, timeout, None)
}
fn capture_child(
    mut child: std::process::Child,
    timeout: Duration,
    request: Option<Vec<u8>>,
) -> R<Vec<u8>> {
    let job = unsafe { Handle(CreateJobObjectW(ptr::null(), ptr::null())) };
    let mut limits = unsafe { std::mem::zeroed::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() };
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        | JOB_OBJECT_LIMIT_ACTIVE_PROCESS
        | JOB_OBJECT_LIMIT_PROCESS_MEMORY;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.ProcessMemoryLimit = 128 * 1024 * 1024;
    if job.0.is_null()
        || unsafe {
            SetInformationJobObject(
                job.0,
                JobObjectExtendedLimitInformation,
                &limits as *const _ as _,
                std::mem::size_of_val(&limits) as u32,
            )
        } == 0
        || unsafe { AssignProcessToJobObject(job.0, child.as_raw_handle()) } == 0
    {
        let _ = child.kill();
        return Err("BRIDGE_JOB_FAILED");
    }
    if let Some(data) = request {
        let mut stdin = child.stdin.take().ok_or("BRIDGE_PIPE_FAILED")?;
        // No mutation request is released until job containment is established.
        std::thread::spawn(move || {
            use std::io::Write;
            let _ = stdin.write_all(&data);
        });
    }
    let mut stdout = child.stdout.take().ok_or("BRIDGE_PIPE_FAILED")?;
    let (sender, receiver) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut data = Vec::new();
        let result = stdout
            .by_ref()
            .take((RESPONSE_LIMIT + 1) as u64)
            .read_to_end(&mut data);
        let _ = sender.send((result, data));
    });
    let deadline = Instant::now() + timeout;
    let mut captured = None;
    loop {
        if captured.is_none()
            && let Ok((result, data)) = receiver.try_recv()
        {
            result.map_err(|_| "BRIDGE_PIPE_FAILED")?;
            if data.len() > RESPONSE_LIMIT {
                let _ = child.kill();
                return Err("BRIDGE_RESPONSE_BOUND");
            }
            captured = Some(data);
        }
        match child.try_wait() {
            Ok(Some(status)) => {
                if !status.success() {
                    return Err("BRIDGE_EXIT_FAILED");
                }
                let data = if let Some(data) = captured {
                    data
                } else {
                    let (result, data) = receiver
                        .recv_timeout(Duration::from_secs(1))
                        .map_err(|_| "BRIDGE_PIPE_TIMEOUT")?;
                    result.map_err(|_| "BRIDGE_PIPE_FAILED")?;
                    data
                };
                if data.len() > RESPONSE_LIMIT {
                    return Err("BRIDGE_RESPONSE_BOUND");
                }
                return Ok(data);
            }
            Err(_) => {
                let _ = child.kill();
                return Err("BRIDGE_WAIT_FAILED");
            }
            _ => {}
        }
        if Instant::now() >= deadline {
            let _ = child.kill();
            return Err("BRIDGE_TIMEOUT");
        }
        std::thread::sleep(Duration::from_millis(20));
    }
}

fn system_directory() -> R<PathBuf> {
    let mut data = [0u16; 32768];
    let len = unsafe { GetSystemDirectoryW(data.as_mut_ptr(), data.len() as u32) };
    if len == 0 || len as usize >= data.len() {
        return Err("SYSTEM_PATH_UNKNOWN");
    }
    Ok(PathBuf::from(text(&data)?))
}

#[cfg(test)]
mod native_bounds {
    use super::*;
    fn fixture(script: &str) -> Command {
        let system = system_directory().unwrap();
        let mut command = Command::new(system.join("WindowsPowerShell/v1.0/powershell.exe"));
        command
            .args([
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                script,
            ])
            .current_dir(system)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());
        command
    }
    #[test]
    fn actual_native_worker_timeout_closes_the_job() {
        let result = bounded_capture(
            &mut fixture("Start-Sleep -Seconds 5"),
            Duration::from_millis(300),
        );
        assert_eq!(result.unwrap_err(), "BRIDGE_TIMEOUT");
    }
    #[test]
    fn actual_native_pipe_output_is_bounded() {
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args([
                "--exact",
                "windows::native_bounds::pipe_fixture_child",
                "--nocapture",
            ])
            .env("SECURERUN_TEST_PIPE_FIXTURE", "1")
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());
        let result = bounded_capture(&mut command, Duration::from_secs(15));
        assert_eq!(result.unwrap_err(), "BRIDGE_RESPONSE_BOUND");
    }
    #[test]
    fn pipe_fixture_child() {
        if std::env::var("SECURERUN_TEST_PIPE_FIXTURE").as_deref() == Ok("1") {
            use std::io::Write;
            std::io::stdout()
                .write_all(&vec![b'A'; RESPONSE_LIMIT + 1024])
                .unwrap();
        }
    }
}
