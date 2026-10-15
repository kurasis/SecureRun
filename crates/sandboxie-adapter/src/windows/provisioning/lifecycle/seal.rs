//! Bounded object snapshots and the P02-proven owner/namespace seal.
//! Restoration changes only recorded identities and known seal-derived ACLs.
use super::*;
use serde::{Deserialize, Serialize};

const MAX_NODES: usize = 4096;
const MAX_DESCRIPTOR_BYTES: usize = 8 * 1024 * 1024;
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct Node {
    relative: String,
    identity: String,
    attributes: u32,
    descriptor: Vec<u8>,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct Snapshot {
    pub root_identity: String,
    pub parent_identity: String,
    nodes: Vec<Node>,
}
pub(super) struct Seal {
    path: PathBuf,
    owner: String,
    pub snapshot: Snapshot,
    _namespace: Vec<File>,
    security: Vec<Option<File>>,
    changed: bool,
}
fn open(path: &Path, access: u32, sharing: u32) -> R<File> {
    let f = OpenOptions::new()
        .access_mode(access)
        .share_mode(sharing)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
        .map_err(|error| match error.raw_os_error() {
            Some(5) => "CLEANUP_OBJECT_ACCESS_DENIED",
            Some(32) => "CLEANUP_OBJECT_SHARING_VIOLATION",
            _ => "CLEANUP_OBJECT_HANDLE_UNAVAILABLE",
        })?;
    checked(&f)?;
    Ok(f)
}
fn checked(f: &File) -> R<BY_HANDLE_FILE_INFORMATION> {
    let mut info = BY_HANDLE_FILE_INFORMATION::default();
    if unsafe { GetFileInformationByHandle(f.as_raw_handle(), &mut info) } == 0 {
        return Err("CLEANUP_OBJECT_IDENTITY_UNKNOWN");
    }
    if info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err("CLEANUP_REPARSE_REJECTED");
    }
    if info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == 0 && info.nNumberOfLinks != 1 {
        return Err("CLEANUP_HARDLINK_REJECTED");
    }
    if info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0 {
        let mut flags = 0u32;
        if unsafe {
            GetFileInformationByHandleEx(
                f.as_raw_handle(),
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
    Ok(info)
}
fn descriptor(f: &File) -> R<Vec<u8>> {
    unsafe {
        let mut sd = ptr::null_mut();
        if GetSecurityInfo(
            f.as_raw_handle(),
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            ptr::null_mut(),
            ptr::null_mut(),
            ptr::null_mut(),
            ptr::null_mut(),
            &mut sd,
        ) != 0
        {
            return Err("CLEANUP_ACL_UNKNOWN");
        }
        let n = GetSecurityDescriptorLength(sd) as usize;
        let result = if (20..=16384).contains(&n) {
            Ok(std::slice::from_raw_parts(sd as *const u8, n).to_vec())
        } else {
            Err("CLEANUP_ACL_BOUND")
        };
        LocalFree(sd as _);
        result
    }
}
fn acl_bytes(sd: &[u8]) -> R<(Vec<u8>, bool)> {
    unsafe {
        let mut present = 0;
        let mut defaulted = 0;
        let mut acl = ptr::null_mut();
        let mut flags = 0;
        let mut revision = 0;
        if GetSecurityDescriptorDacl(sd.as_ptr() as _, &mut present, &mut acl, &mut defaulted) == 0
            || present == 0
            || acl.is_null()
            || GetSecurityDescriptorControl(sd.as_ptr() as _, &mut flags, &mut revision) == 0
        {
            return Err("CLEANUP_ACL_UNKNOWN");
        }
        let size = (*acl).AclSize as usize;
        if !(8..=16384).contains(&size) {
            return Err("CLEANUP_ACL_BOUND");
        }
        Ok((
            std::slice::from_raw_parts(acl as *const u8, size).to_vec(),
            flags & SE_DACL_PROTECTED != 0,
        ))
    }
}
fn inherited_only(sd: &[u8]) -> R<bool> {
    unsafe {
        let mut present = 0;
        let mut defaulted = 0;
        let mut acl = ptr::null_mut();
        if GetSecurityDescriptorDacl(sd.as_ptr() as _, &mut present, &mut acl, &mut defaulted) == 0
            || present == 0
            || acl.is_null()
        {
            return Err("CLEANUP_ACL_UNKNOWN");
        }
        for i in 0..(*acl).AceCount as u32 {
            let mut ace = ptr::null_mut();
            if GetAce(acl, i, &mut ace) == 0 {
                return Err("CLEANUP_ACL_UNKNOWN");
            };
            if (*(ace as *const ACE_HEADER)).AceFlags & INHERITED_ACE as u8 == 0 {
                return Ok(false);
            }
        }
        Ok(true)
    }
}
fn apply(f: &File, sd: &[u8]) -> R<()> {
    unsafe {
        let mut present = 0;
        let mut defaulted = 0;
        let mut acl = ptr::null_mut();
        let mut flags = 0;
        let mut revision = 0;
        if GetSecurityDescriptorDacl(sd.as_ptr() as _, &mut present, &mut acl, &mut defaulted) == 0
            || present == 0
            || acl.is_null()
            || GetSecurityDescriptorControl(sd.as_ptr() as _, &mut flags, &mut revision) == 0
        {
            return Err("CLEANUP_ACL_INVALID");
        }
        let protection = if flags & SE_DACL_PROTECTED != 0 {
            PROTECTED_DACL_SECURITY_INFORMATION
        } else {
            UNPROTECTED_DACL_SECURITY_INFORMATION
        };
        if SetSecurityInfo(
            f.as_raw_handle(),
            SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION | protection,
            ptr::null_mut(),
            ptr::null_mut(),
            acl,
            ptr::null_mut(),
        ) != 0
        {
            return Err("CLEANUP_ACL_RESTORE_REQUIRED");
        }
        Ok(())
    }
}
fn sddl(value: &str) -> R<Vec<u8>> {
    unsafe {
        let mut raw = ptr::null_mut();
        let mut n = 0;
        if ConvertStringSecurityDescriptorToSecurityDescriptorW(
            wide(value).as_ptr(),
            1,
            &mut raw,
            &mut n,
        ) == 0
        {
            return Err("CLEANUP_ACL_INVALID");
        };
        let data = std::slice::from_raw_parts(raw as *const u8, n as usize).to_vec();
        LocalFree(raw as _);
        Ok(data)
    }
}
fn frozen(owner: &str) -> R<Vec<u8>> {
    sddl(&format!(
        "D:P(D;OICI;0x000c0116;;;OW)(D;OICI;0x000c0116;;;{owner})(A;OICI;0x001300e9;;;{owner})(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"
    ))
}
fn normalized(attributes: u32) -> u32 {
    let attrs =
        attributes & !(FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM);
    if attrs == 0 || attrs == FILE_ATTRIBUTE_DIRECTORY {
        FILE_ATTRIBUTE_NORMAL
    } else {
        attrs
    }
}
fn attributes(f: &File, value: u32) -> R<()> {
    let basic = FILE_BASIC_INFO {
        FileAttributes: value,
        ..Default::default()
    };
    if unsafe {
        SetFileInformationByHandle(
            f.as_raw_handle(),
            FileBasicInfo,
            &basic as *const _ as _,
            std::mem::size_of_val(&basic) as u32,
        )
    } == 0
    {
        return Err("CLEANUP_ATTRIBUTE_PREPARATION_FAILED");
    }
    Ok(())
}
pub(super) fn sealed_root(engine: &NativeEngine, e: &OwnedEnvironment) -> R<Vec<File>> {
    let path = PathBuf::from(engine.root_for(e.id));
    let held = canonical_validated(&path, FILE_SHARE_READ | FILE_SHARE_WRITE, true)?;
    let root = held.last().ok_or("CLEANUP_ROOT_UNKNOWN")?;
    let actual = engine.api.root(&e.name());
    if actual.path.as_deref() != path.to_str()
        || actual.identity != e.root_identity
        || Some(identity(root)?) != e.root_identity
    {
        return Err("CLEANUP_ROOT_CHANGED");
    }
    let sd = descriptor(root)?;
    let mut owner = ptr::null_mut();
    let mut defaulted = 0;
    if unsafe { GetSecurityDescriptorOwner(sd.as_ptr() as _, &mut owner, &mut defaulted) } == 0
        || unsafe { sid_string(owner) }? != engine.owner
        || acl_bytes(&sd)? != acl_bytes(&frozen(&engine.owner)?)?
    {
        return Err("CLEANUP_SEAL_CHANGED");
    }
    Ok(held)
}
impl Seal {
    pub fn capture(engine: &NativeEngine, e: &OwnedEnvironment) -> R<Self> {
        let path = PathBuf::from(engine.root_for(e.id));
        Self::capture_path(
            path,
            &engine.owner,
            e.root_identity.as_deref().ok_or("CLEANUP_ROOT_UNKNOWN")?,
        )
    }
    fn capture_path(path: PathBuf, owner: &str, expected: &str) -> R<Self> {
        let namespace = canonical_validated(&path, FILE_SHARE_READ | FILE_SHARE_WRITE, true)?;
        let root_identity = identity(namespace.last().ok_or("CLEANUP_ROOT_UNKNOWN")?)?;
        if root_identity != expected {
            return Err("CLEANUP_ROOT_CHANGED");
        }
        private(namespace.last().unwrap(), owner)?;
        let parent_identity = identity(
            namespace
                .get(
                    namespace
                        .len()
                        .checked_sub(2)
                        .ok_or("CLEANUP_PARENT_UNKNOWN")?,
                )
                .ok_or("CLEANUP_PARENT_UNKNOWN")?,
        )?;
        let mut result = Self {
            path,
            owner: owner.into(),
            snapshot: Snapshot {
                root_identity,
                parent_identity,
                nodes: vec![],
            },
            _namespace: namespace,
            security: vec![],
            changed: false,
        };
        result.capture_node(Path::new(""), 0, &mut 0)?;
        Ok(result)
    }
    fn resolve(&self, relative: &Path) -> PathBuf {
        if relative.as_os_str().is_empty() {
            self.path.clone()
        } else {
            self.path.join(relative)
        }
    }
    fn capture_node(&mut self, relative: &Path, depth: usize, bytes: &mut usize) -> R<()> {
        if depth > 32 || self.snapshot.nodes.len() >= MAX_NODES {
            return Err("CLEANUP_TREE_BOUND");
        }
        let path = self.resolve(relative);
        crate::files::local_path(path.to_str().ok_or("CLEANUP_PATH_INVALID")?)?;
        let file = open(
            &path,
            READ_CONTROL | WRITE_DAC | FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        )?;
        let info = checked(&file)?;
        let sd = descriptor(&file)?;
        *bytes += sd.len();
        if *bytes > MAX_DESCRIPTOR_BYTES {
            return Err("CLEANUP_SNAPSHOT_BOUND");
        }
        self.snapshot.nodes.push(Node {
            relative: relative.to_str().ok_or("CLEANUP_PATH_INVALID")?.into(),
            identity: identity(&file)?,
            attributes: info.dwFileAttributes,
            descriptor: sd,
        });
        self.security.push(Some(file));
        if info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0 {
            let pin = open(
                &path,
                READ_CONTROL | FILE_READ_ATTRIBUTES,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
            )?;
            for child in std::fs::read_dir(&path).map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")? {
                let child = child.map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?;
                self.capture_node(&relative.join(child.file_name()), depth + 1, bytes)?
            }
            drop(pin);
        }
        Ok(())
    }
    pub fn root(&self) -> HANDLE {
        self._namespace.last().unwrap().as_raw_handle()
    }
    pub fn release_children(&mut self) {
        self.security.truncate(1)
    }
    pub fn freeze(&mut self) -> R<()> {
        self.changed = true;
        apply(
            self.security[0]
                .as_ref()
                .ok_or("CLEANUP_RESTORE_AUTHORITY_LOST")?,
            &frozen(&self.owner)?,
        )?;
        let inherited = sddl("D:AI")?;
        for file in self.security.iter().skip(1).flatten() {
            apply(file, &inherited)?
        }
        let mut observed = std::collections::BTreeMap::new();
        self.snapshot_current(Path::new(""), 0, &mut observed)?;
        if observed.len() != self.snapshot.nodes.len()
            || self
                .snapshot
                .nodes
                .iter()
                .any(|n| observed.get(&n.relative) != Some(&n.identity))
        {
            return Err("CLEANUP_SNAPSHOT_CHANGED");
        }
        for (node, file) in self.snapshot.nodes.iter().zip(&self.security) {
            let file = file.as_ref().ok_or("CLEANUP_RESTORE_AUTHORITY_LOST")?;
            if identity(file)? != node.identity {
                return Err("CLEANUP_OBJECT_REPLACED");
            };
            attributes(file, normalized(node.attributes))?
        }
        Ok(())
    }
    fn snapshot_current(
        &self,
        relative: &Path,
        depth: usize,
        found: &mut std::collections::BTreeMap<String, String>,
    ) -> R<()> {
        if depth > 32 || found.len() >= MAX_NODES {
            return Err("CLEANUP_TREE_BOUND");
        }
        let file = open(
            &self.resolve(relative),
            FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        )?;
        let info = checked(&file)?;
        found.insert(
            relative.to_str().ok_or("CLEANUP_PATH_INVALID")?.into(),
            identity(&file)?,
        );
        if info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0 {
            for c in std::fs::read_dir(self.resolve(relative))
                .map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?
            {
                self.snapshot_current(
                    &relative.join(c.map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?.file_name()),
                    depth + 1,
                    found,
                )?
            }
        }
        Ok(())
    }
    pub fn empty(&self) -> R<()> {
        if identity(self._namespace.last().unwrap())? != self.snapshot.root_identity {
            return Err("CLEANUP_ROOT_CHANGED");
        }
        if std::fs::read_dir(&self.path)
            .map_err(|_| "CLEANUP_ENUMERATION_UNKNOWN")?
            .next()
            .is_some()
        {
            return Err("CLEANUP_CONTENTS_REMAIN");
        };
        Ok(())
    }
    /// Release only objects the original deleter has already marked delete-pending.
    /// Every surviving object retains preauthorized DACL/attribute restoration access.
    pub fn reap_deleted(&mut self) -> R<()> {
        for file in self.security.iter_mut().skip(1) {
            if let Some(held) = file.as_ref() {
                let mut info = FILE_STANDARD_INFO::default();
                if unsafe {
                    GetFileInformationByHandleEx(
                        held.as_raw_handle(),
                        FileStandardInfo,
                        &mut info as *mut _ as _,
                        std::mem::size_of_val(&info) as u32,
                    )
                } == 0
                {
                    return Err("CLEANUP_DELETE_STATE_UNKNOWN");
                }
                if info.DeletePending {
                    *file = None;
                }
            }
        }
        Ok(())
    }
    pub fn delegated_restore(&mut self) {
        self.changed = false;
        self.release_children();
    }
    pub fn restore(&mut self) -> R<()> {
        if identity(
            self.security[0]
                .as_ref()
                .ok_or("CLEANUP_RESTORE_AUTHORITY_LOST")?,
        )? != self.snapshot.root_identity
        {
            return Err("CLEANUP_ROOT_CHANGED");
        }
        let current = descriptor(
            self.security[0]
                .as_ref()
                .ok_or("CLEANUP_RESTORE_AUTHORITY_LOST")?,
        )?;
        let original = &self.snapshot.nodes[0].descriptor;
        if acl_bytes(&current)? != acl_bytes(original)? {
            if acl_bytes(&current)? != acl_bytes(&frozen(&self.owner)?)? {
                return Err("CLEANUP_ACL_EXTERNAL_CHANGE");
            }
            apply(
                self.security[0]
                    .as_ref()
                    .ok_or("CLEANUP_RESTORE_AUTHORITY_LOST")?,
                original,
            )?;
        }
        let mut result = Ok(());
        self.reap_deleted()?;
        for (index, node) in self.snapshot.nodes.iter().enumerate() {
            let Some(file) = self.security.get(index).and_then(Option::as_ref) else {
                continue;
            };
            if identity(file)? != node.identity {
                return Err("CLEANUP_RESTORE_IDENTITY_CHANGED");
            }
            let current = descriptor(file)?;
            if acl_bytes(&current)? != acl_bytes(&node.descriptor)? {
                if node.relative.is_empty() || !inherited_only(&current)? {
                    return Err("CLEANUP_ACL_EXTERNAL_CHANGE");
                }
                apply(file, &node.descriptor)?;
            }
            let info = checked(file)?;
            if info.dwFileAttributes & !FILE_ATTRIBUTE_NORMAL
                == (node.attributes
                    & !(FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM))
                    & !FILE_ATTRIBUTE_NORMAL
            {
                attributes(file, node.attributes)?
            } else if info.dwFileAttributes != node.attributes {
                result = Err("CLEANUP_ATTRIBUTES_EXTERNAL_CHANGE")
            }
        }
        self.changed = false;
        result
    }
    /// The independent supervisor retains root restoration authority through a
    /// killed executor. No stored path grants authority to delete or rebind.
    pub fn enable_supervision(&mut self) {
        self.changed = true;
    }
}
impl Drop for Seal {
    fn drop(&mut self) {
        if self.changed {
            let _ = self.restore();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[link(name = "ntdll")]
    unsafe extern "system" {
        fn NtDeleteFile(attributes: *const NtAttributes) -> i32;
    }
    #[test]
    fn delete_pending_objects_are_released_without_losing_survivor_restore_authority() {
        let (_directory, path, owner, id) = fixture();
        std::fs::write(path.join("keep.txt"), b"SYNTHETIC").unwrap();
        let mut seal = Seal::capture_path(path.clone(), &owner, &id).unwrap();
        let text: Vec<u16> = "keep.txt".encode_utf16().collect();
        let name = NtName {
            length: (text.len() * 2) as u16,
            maximum: (text.len() * 2) as u16,
            buffer: text.as_ptr(),
        };
        let attributes = NtAttributes {
            length: std::mem::size_of::<NtAttributes>() as u32,
            root: seal.root(),
            name: &name,
            flags: 0x40,
            security: ptr::null_mut(),
            qos: ptr::null_mut(),
        };
        let status = unsafe { NtDeleteFile(&attributes) };
        eprintln!(
            "METADATA_DELETE_NATIVE status={status:08x} entries={}",
            std::fs::read_dir(&path).unwrap().count()
        );
        assert_eq!(status, 0);
        seal.reap_deleted().unwrap();
        assert_eq!(std::fs::read_dir(&path).unwrap().count(), 0);
        drop(seal);
    }
    fn fixture() -> (tempfile::TempDir, PathBuf, String, String) {
        let owner = process_sid(unsafe { GetCurrentProcess() }).unwrap();
        let directory = tempfile::tempdir_in(profile_path().unwrap().parent().unwrap()).unwrap();
        let path = directory.path().join("root");
        let root = fresh_directory(&path, &owner).unwrap();
        let id = identity(&root).unwrap();
        drop(root);
        (directory, path, owner, id)
    }
    #[test]
    fn seal_denies_new_owner_acl_and_attribute_handles_and_restores_retained_data() {
        let (_directory, path, owner, id) = fixture();
        std::fs::create_dir(path.join("nested")).unwrap();
        std::fs::write(path.join("nested/keep.txt"), b"SYNTHETIC").unwrap();
        let mut seal = Seal::capture_path(path.clone(), &owner, &id).unwrap();
        seal.freeze().unwrap();
        assert!(
            OpenOptions::new()
                .create_new(true)
                .write(true)
                .open(path.join("insert.txt"))
                .is_err()
        );
        assert!(open(&path, WRITE_DAC, 7).is_err());
        assert!(open(&path, FILE_WRITE_ATTRIBUTES, 7).is_err());
        seal.restore().unwrap();
        assert_eq!(
            std::fs::read(path.join("nested/keep.txt")).unwrap(),
            b"SYNTHETIC"
        );
        std::fs::write(path.join("restored.txt"), b"RESTORED").unwrap();
    }
    #[test]
    fn independent_controller_restores_known_seal_after_executor_handle_loss() {
        let (_directory, path, owner, id) = fixture();
        std::fs::write(path.join("keep.txt"), b"RETAINED").unwrap();
        let mut controller = Seal::capture_path(path.clone(), &owner, &id).unwrap();
        controller.enable_supervision();
        let mut executor = Seal::capture_path(path.clone(), &owner, &id).unwrap();
        executor.freeze().unwrap();
        // Unit fixture closes executor handles without its normal unwind restore;
        // the native phase separately kills real executor processes at each step.
        executor.changed = false;
        drop(executor);
        assert!(open(&path, WRITE_DAC, 7).is_err());
        controller.restore().unwrap();
        assert_eq!(std::fs::read(path.join("keep.txt")).unwrap(), b"RETAINED");
        std::fs::write(path.join("new.txt"), b"NEW").unwrap();
    }
    #[test]
    fn hardlinked_payload_is_refused_before_namespace_seal() {
        let (_directory, path, owner, id) = fixture();
        std::fs::write(path.join("first.txt"), b"CANARY").unwrap();
        std::fs::hard_link(path.join("first.txt"), path.join("second.txt")).unwrap();
        assert!(matches!(
            Seal::capture_path(path.clone(), &owner, &id),
            Err("CLEANUP_HARDLINK_REJECTED")
        ));
        std::fs::write(path.join("not_sealed.txt"), b"UNCHANGED").unwrap();
    }
}
