//! Host-side inert file handling. No shell, recovery hooks, preview or host EXE dispatch.
use super::*;
use crate::files::{self as contract, Entry, Node, Record};

fn generation(e: &OwnedEnvironment) -> String {
    fingerprint(&(
        &e.id,
        &e.owner_sid,
        &e.engine_identity,
        &e.root_identity,
        e.revision,
    ))
}
fn scope(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
    stopped: bool,
) -> R<Vec<File>> {
    validate_owned(engine, e, all)?;
    let held = engine.control_scope(e)?;
    if stopped {
        engine.idle(&e.name())?;
    }
    Ok(held)
}
fn contained(engine: &NativeEngine, e: &OwnedEnvironment, path: &Path) -> R<Vec<File>> {
    let root = engine.root_for(e.id);
    let prefix = format!("{root}\\");
    let s = path.to_str().ok_or("FILE_PATH_INVALID")?;
    if !s.eq_ignore_ascii_case(&root) && !s.to_lowercase().starts_with(&prefix.to_lowercase()) {
        return Err("SOURCE_OUTSIDE_OWNED_ROOT");
    }
    let held = canonical(path)?;
    let root_file = held
        .iter()
        .find(|f| identity(f).ok().as_ref() == e.root_identity.as_ref())
        .ok_or("ROOT_IDENTITY_CHANGED")?;
    private(root_file, &engine.owner)?;
    Ok(held)
}
fn streams(path: &Path) -> R<Vec<u8>> {
    let mut data = unsafe { std::mem::zeroed::<WIN32_FIND_STREAM_DATA>() };
    let handle = unsafe {
        FindFirstStreamW(
            wide(&path.to_string_lossy()).as_ptr(),
            FindStreamInfoStandard,
            &mut data as *mut _ as _,
            0,
        )
    };
    if handle == INVALID_HANDLE_VALUE {
        return Err("SOURCE_STREAMS_UNKNOWN");
    }
    let result = (|| {
        let mut count = 0;
        loop {
            count += 1;
            if count > 2 {
                return Err("SOURCE_STREAM_UNSUPPORTED");
            }
            let name = text(&data.cStreamName)?;
            if name != "::$DATA" && name != ":Zone.Identifier:$DATA" {
                return Err("SOURCE_STREAM_UNSUPPORTED");
            }
            if unsafe { FindNextStreamW(handle, &mut data as *mut _ as _) } == 0 {
                if unsafe { GetLastError() } != ERROR_HANDLE_EOF {
                    return Err("SOURCE_STREAMS_UNKNOWN");
                }
                break;
            }
        }
        let ads = format!("{}:Zone.Identifier", path.display());
        match OpenOptions::new()
            .read(true)
            .share_mode(FILE_SHARE_READ)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(ads)
        {
            Ok(mut f) => {
                let mut bytes = vec![];
                Read::by_ref(&mut f)
                    .take(4097)
                    .read_to_end(&mut bytes)
                    .map_err(|_| "PROVENANCE_READ_FAILED")?;
                Ok(contract::marker(&bytes))
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(contract::marker(&[])),
            Err(_) => Err("PROVENANCE_READ_FAILED"),
        }
    })();
    unsafe { FindClose(handle) };
    result
}
fn exact_marker(path: &Path) -> R<Vec<u8>> {
    let mut file = OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_DELETE)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(format!("{}:Zone.Identifier", path.display()))
        .map_err(|_| "PROVENANCE_MISSING")?;
    let mut data = vec![];
    Read::by_ref(&mut file)
        .take(4097)
        .read_to_end(&mut data)
        .map_err(|_| "PROVENANCE_READ_FAILED")?;
    if data.len() > 4096 || contract::marker(&data) != data {
        return Err("PROVENANCE_INVALID");
    }
    Ok(data)
}
fn known(id: &windows_sys::core::GUID) -> R<PathBuf> {
    let mut raw = ptr::null_mut();
    if unsafe { SHGetKnownFolderPath(id, 0, ptr::null_mut(), &mut raw) } != 0 {
        return Err("KNOWN_FOLDER_UNAVAILABLE");
    }
    let value = unsafe { pointer_text(raw, 1024) };
    unsafe { CoTaskMemFree(raw as _) };
    Ok(PathBuf::from(value?))
}
fn destination(engine: &NativeEngine, path: &str, all: &[OwnedEnvironment]) -> R<Vec<File>> {
    let held = canonical(Path::new(path))?;
    if !held
        .last()
        .ok_or("DESTINATION_INVALID")?
        .metadata()
        .map_err(|_| "DESTINATION_INVALID")?
        .is_dir()
    {
        return Err("DESTINATION_FOLDER_REQUIRED");
    }
    let mut forbidden = vec![
        engine.profile.clone(),
        engine.trusted.home.clone(),
        system_directory()?
            .parent()
            .ok_or("SYSTEM_PATH_UNKNOWN")?
            .to_path_buf(),
    ];
    for id in [
        &FOLDERID_ProgramFiles,
        &FOLDERID_ProgramFilesX86,
        &FOLDERID_ProgramData,
        &FOLDERID_LocalAppData,
        &FOLDERID_RoamingAppData,
        &FOLDERID_Startup,
        &FOLDERID_CommonStartup,
    ] {
        if let Ok(p) = known(id) {
            forbidden.push(p);
        }
    }
    forbidden.extend(all.iter().map(|e| PathBuf::from(engine.root_for(e.id))));
    let selected = path.to_lowercase();
    for p in forbidden {
        let p = p.to_string_lossy().to_lowercase();
        if selected == p
            || selected.starts_with(&(p.clone() + "\\"))
            || p.starts_with(&(selected.clone() + "\\"))
        {
            return Err("DESTINATION_SENSITIVE_SCOPE");
        }
    }
    Ok(held)
}
/// Pinned upstream GetBoxedPath drive branch (SbieAPI.cpp:2064–2106).
/// No user-folder, network, serial-number, image or snapshot mapping is accepted.
fn workspace(engine: &NativeEngine, e: &OwnedEnvironment) -> R<(PathBuf, String)> {
    let config = engine.section(&e.name(), true)?;
    for key in ["UseVolumeSerialNumbers", "UseFileImage"] {
        if config.get(key).is_some_and(|v| {
            v.iter()
                .any(|s| !matches!(s.to_lowercase().as_str(), "n" | "no" | "false" | "0"))
        }) {
            return Err("WORKSPACE_MAPPING_UNSUPPORTED");
        }
    }
    let drive = system_directory()?
        .to_string_lossy()
        .chars()
        .next()
        .ok_or("SYSTEM_PATH_UNKNOWN")?
        .to_ascii_uppercase();
    let logical = format!("{drive}:\\SecureRunWorkspace\\{}", e.id.simple());
    if std::fs::symlink_metadata(&logical).is_ok() {
        return Err("WORKSPACE_HOST_SHADOW_PRESENT");
    }
    let physical = PathBuf::from(engine.root_for(e.id))
        .join("drive")
        .join(drive.to_string())
        .join("SecureRunWorkspace")
        .join(e.id.simple().to_string());
    Ok((physical, logical))
}
fn materialize(engine: &NativeEngine, e: &OwnedEnvironment, path: &Path) -> R<Vec<File>> {
    let root = PathBuf::from(engine.root_for(e.id));
    let tail = path
        .strip_prefix(&root)
        .map_err(|_| "WORKSPACE_OUTSIDE_ROOT")?;
    let mut current = root;
    let mut held = vec![];
    for part in tail.components() {
        current.push(part);
        held.extend(ensure_private(&current, &engine.owner)?);
    }
    Ok(held)
}
fn fresh_payload(directory: &Path) -> R<File> {
    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .access_mode(GENERIC_READ | GENERIC_WRITE | DELETE | READ_CONTROL)
        .create_new(true)
        .share_mode(FILE_SHARE_READ)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(directory.join("payload.part"))
        .map_err(|_| "STAGING_CREATE_FAILED")?;
    identity(&f)?;
    Ok(f)
}
fn write_marker(path: &Path, expected: &[u8]) -> R<File> {
    let ads = format!("{}:Zone.Identifier", path.display());
    {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .share_mode(FILE_SHARE_READ | FILE_SHARE_DELETE)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(&ads)
            .map_err(|_| "PROVENANCE_WRITE_FAILED")?;
        file.write_all(expected)
            .and_then(|_| file.sync_all())
            .map_err(|_| "PROVENANCE_WRITE_FAILED")?;
    }
    // Reopen read-only and verify under the lease that remains held through
    // publication. No payload is copied before this read-back succeeds.
    let mut held = OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_DELETE)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(&ads)
        .map_err(|_| "PROVENANCE_VERIFY_FAILED")?;
    let mut data = vec![];
    Read::by_ref(&mut held)
        .take(4097)
        .read_to_end(&mut data)
        .map_err(|_| "PROVENANCE_VERIFY_FAILED")?;
    if data != expected {
        return Err("PROVENANCE_VERIFY_FAILED");
    }
    Ok(held)
}

fn publish(file: &File, parent: &File, name: &str) -> R<()> {
    contract::leaf(name)?;
    #[repr(C)]
    struct Rename {
        replace: u8,
        root: HANDLE,
        length: u32,
        name: [u16; 181],
    }
    let mut info = Rename {
        replace: 0,
        root: parent.as_raw_handle(),
        length: (name.encode_utf16().count() * 2) as u32,
        name: [0; 181],
    };
    for (i, c) in name.encode_utf16().enumerate() {
        info.name[i] = c;
    }
    if unsafe {
        SetFileInformationByHandle(
            file.as_raw_handle(),
            FileRenameInfo,
            &info as *const _ as _,
            (std::mem::offset_of!(Rename, name) + info.length as usize) as u32,
        )
    } == 0
    {
        return Err(
            if matches!(
                unsafe { GetLastError() },
                ERROR_ALREADY_EXISTS | ERROR_FILE_EXISTS
            ) {
                "DESTINATION_COLLISION_RENAME_OR_SKIP"
            } else {
                "PUBLISH_NO_REPLACE_FAILED"
            },
        );
    }
    Ok(())
}
fn checkpoint(stage: &str) {
    #[cfg(feature = "policy-ci")]
    if std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true")
        && std::env::var("SECURERUN_P07_PAUSE_STAGE").as_deref() == Ok(stage)
    {
        println!("CHECKPOINT_{stage}");
        let _ = std::io::stdout().flush();
        loop {
            if std::env::var("SECURERUN_P07_PAUSE_MODE").as_deref() == Ok("resume")
                && profile_path().ok().is_some_and(|p| {
                    p.join("metadata")
                        .join(format!("resume-{stage}.flag"))
                        .exists()
                })
            {
                break;
            }
            std::thread::park_timeout(Duration::from_millis(100));
        }
    }
    #[cfg(not(feature = "policy-ci"))]
    let _ = stage;
}
fn cancelled(engine: &NativeEngine, id: Uuid) -> bool {
    engine
        .profile
        .join("metadata")
        .join(format!("cancel-{id}.flag"))
        .try_exists()
        .unwrap_or(true)
}
#[expect(
    clippy::too_many_arguments,
    reason = "Explicit verified transfer scope and endpoints"
)]
fn transfer(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
    journal: &contract::Journal,
    request: &contract::Request,
    id: Uuid,
    source: &Path,
    parent: &Path,
    name: &str,
    direction: &str,
) -> R<()> {
    contract::leaf(name)?;
    let gen_id = generation(e);
    let signature = fingerprint(&(request, &gen_id));
    if let Some(old) = journal.get(id)? {
        return if old.signature == signature {
            Ok(())
        } else {
            Err("TRANSFER_OPERATION_CONFLICT")
        };
    }
    let _scope = scope(engine, e, all, true)?;
    let _source_parents = if direction == "EXPORT" {
        contained(engine, e, source)?
    } else {
        let held = canonical(source)?;
        let source_lower = source.to_string_lossy().to_lowercase();
        if source_lower.starts_with(&engine.profile.to_string_lossy().to_lowercase()) {
            return Err("IMPORT_BOXED_SOURCE_USE_FILE_VIEW");
        }
        held
    };
    let mut source_file = lease(source, false)?;
    let before = source_file.metadata().map_err(|_| "SOURCE_UNAVAILABLE")?;
    if !before.is_file() {
        return Err("REGULAR_FILE_REQUIRED");
    }
    let source_identity = identity(&source_file)?;
    let provenance = streams(source)?;
    let size = before.len();
    if size > contract::MAX_BYTES {
        return Err("TRANSFER_SIZE_BOUND");
    }
    let _parents = if direction == "EXPORT" {
        destination(engine, parent.to_str().ok_or("DESTINATION_INVALID")?, all)?
    } else {
        contained(engine, e, parent)?
    };
    let parent_file = lease(parent, true)?;
    let parent_identity = identity(&parent_file)?;
    let mut free = 0;
    if unsafe {
        GetDiskFreeSpaceExW(
            wide(&parent.to_string_lossy()).as_ptr(),
            &mut free,
            ptr::null_mut(),
            ptr::null_mut(),
        )
    } == 0
        || size.saturating_add(1048576) > free
    {
        return Err("INSUFFICIENT_LOGICAL_FREE_SPACE");
    }
    let staging = parent.join(format!(".securerun-{}", id.simple()));
    let mut r = Record {
        operation_id: id,
        environment_id: e.id,
        generation: gen_id,
        signature,
        direction: direction.into(),
        stage: "INTENT".into(),
        reason: "TRANSFER_INCOMPLETE".into(),
        size: size.to_string(),
        parent: parent.to_string_lossy().into(),
        parent_identity,
        staging_directory: staging.to_string_lossy().into(),
        staging_directory_identity: None,
        artifact_identity: None,
        source_identity,
        name: name.into(),
        digest: None,
        provenance,
    };
    journal.save(&r)?;
    let result = (|| {
        let stage_dir = fresh_directory(&staging, &engine.owner)?;
        r.staging_directory_identity = Some(identity(&stage_dir)?);
        journal.save(&r)?;
        let mut payload = fresh_payload(&staging)?;
        r.artifact_identity = Some(identity(&payload)?);
        r.stage = "UNMARKED".into();
        journal.save(&r)?;
        checkpoint("BeforeMark");
        let _marker = write_marker(&staging.join("payload.part"), &r.provenance)?;
        r.stage = "MARKED_INCOMPLETE".into();
        journal.save(&r)?;
        checkpoint("AfterMark");
        let mut checked = Instant::now() - Duration::from_secs(1);
        let mut mid = false;
        let digest = contract::copy_stream(&mut source_file, &mut payload, size, |bytes| {
            if bytes > 0 && !mid {
                mid = true;
                checkpoint("MidCopy");
            }
            if cancelled(engine, id) {
                return Err("TRANSFER_CANCELLED");
            }
            if checked.elapsed() >= Duration::from_millis(250) {
                engine.mutation_context()?;
                engine.idle(&e.name())?;
                engine.validate_root(e)?;
                checked = Instant::now();
            }
            Ok(())
        })?;
        let after = source_file.metadata().map_err(|_| "SOURCE_UNAVAILABLE")?;
        if before.len() != after.len()
            || before.modified().ok() != after.modified().ok()
            || identity(&source_file)? != r.source_identity
        {
            return Err("SOURCE_CHANGED");
        }
        payload.sync_all().map_err(|_| "PAYLOAD_FLUSH_FAILED")?;
        r.digest = Some(digest);
        r.stage = "READY_TO_PUBLISH".into();
        journal.save(&r)?;
        checkpoint("BeforeRename");
        let _scope = scope(engine, e, all, true)?;
        if cancelled(engine, id) {
            return Err("TRANSFER_CANCELLED");
        }
        if identity(&parent_file)? != r.parent_identity
            || identity(&stage_dir).ok() != r.staging_directory_identity
            || identity(&payload).ok() != r.artifact_identity
        {
            return Err("ARTIFACT_IDENTITY_CHANGED");
        }
        if exact_marker(&staging.join("payload.part"))? != r.provenance {
            return Err("PROVENANCE_CHANGED");
        }
        publish(&payload, &parent_file, name)?;
        checkpoint("AfterRename");
        r.stage = "COMPLETE".into();
        r.reason = "TRANSFER_COMPLETED_UNTRUSTED".into();
        journal.save(&r)?;
        Ok(())
    })();
    if let Err(code) = result {
        r.reason = code.into();
        journal.save(&r)?;
    }
    result
}
fn node_path(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    journal: &contract::Journal,
    id: Uuid,
) -> R<(Node, Vec<File>)> {
    let n = journal.resolve(id, e.id, &generation(e))?;
    let held = contained(engine, e, Path::new(&n.path))?;
    if identity(held.last().ok_or("FILE_REFERENCE_INVALID")?)? != n.identity {
        return Err("FILE_IDENTITY_CHANGED");
    }
    Ok((n, held))
}
fn list(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    journal: &contract::Journal,
    id: Option<Uuid>,
    offset: u32,
    reply: &mut contract::Reply,
) -> R<()> {
    if offset > 4096 {
        return Err("ENUMERATION_BOUND");
    }
    let root = engine.root_for(e.id);
    let path = if let Some(id) = id {
        let (n, _) = node_path(engine, e, journal, id)?;
        if !n.directory {
            return Err("DIRECTORY_REQUIRED");
        }
        n.path
    } else {
        root.clone()
    };
    let _held = contained(engine, e, Path::new(&path))?;
    let mut count = 0;
    let iterator = std::fs::read_dir(&path).map_err(|_| "DIRECTORY_ENUMERATION_FAILED")?;
    for item in iterator.skip(offset as usize).take(contract::PAGE + 1) {
        let item = item.map_err(|_| "DIRECTORY_ENUMERATION_FAILED")?;
        count += 1;
        if count > contract::PAGE {
            reply.next_offset = Some(offset + contract::PAGE as u32);
            break;
        }
        let raw = item
            .file_name()
            .into_string()
            .map_err(|_| "FILENAME_ENCODING_UNSUPPORTED")?;
        if raw.starts_with(".securerun-")
            || (path == root && !["drive", "user", "share"].contains(&raw.to_lowercase().as_str()))
        {
            continue;
        }
        let p = item.path();
        let held = match contained(engine, e, &p) {
            Ok(h) => h,
            Err(_) => continue,
        };
        let f = held.last().ok_or("FILE_IDENTITY_UNKNOWN")?;
        let m = f.metadata().map_err(|_| "FILE_METADATA_UNKNOWN")?;
        let (workspace, logical) = workspace(engine, e)?;
        let logical = if !m.is_dir() {
            p.strip_prefix(&workspace)
                .ok()
                .filter(|p| p.components().count() == 1)
                .map(|p| format!("{logical}\\{}", p.display()))
        } else {
            None
        };
        let id = journal.node(&Node {
            environment_id: e.id,
            generation: generation(e),
            path: p.to_string_lossy().into(),
            identity: identity(f)?,
            directory: m.is_dir(),
            logical: logical.clone(),
        })?;
        reply.entries.push(Entry {
            id,
            name: contract::display(&raw),
            directory: m.is_dir(),
            size: m.len().to_string(),
            modified_ms: m
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_millis().to_string())
                .unwrap_or_default(),
            executable: logical.is_some() && raw.to_lowercase().ends_with(".exe"),
        });
    }
    Ok(())
}
fn recover(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
    journal: &contract::Journal,
    id: Uuid,
) -> R<()> {
    let mut r = journal.get(id)?.ok_or("TRANSFER_NOT_FOUND")?;
    if r.environment_id != e.id || r.generation != generation(e) {
        return Err("ARTIFACT_GENERATION_CHANGED");
    }
    let _scope = scope(engine, e, all, true)?;
    let _parents = if r.direction == "EXPORT" {
        destination(engine, &r.parent, all)?
    } else {
        contained(engine, e, Path::new(&r.parent))?
    };
    let parent = lease(Path::new(&r.parent), true)?;
    if identity(&parent)? != r.parent_identity {
        return Err("ARTIFACT_PARENT_CHANGED");
    }
    contract::leaf(&r.name)?;
    let final_path = PathBuf::from(&r.parent).join(&r.name);
    let candidate = if final_path
        .try_exists()
        .map_err(|_| "ARTIFACT_STATE_UNKNOWN")?
    {
        final_path
    } else {
        let held = canonical(Path::new(&r.staging_directory))?;
        if identity(held.last().ok_or("ARTIFACT_STATE_UNKNOWN")?).ok()
            != r.staging_directory_identity
        {
            return Err("ARTIFACT_DIRECTORY_CHANGED");
        }
        PathBuf::from(&r.staging_directory).join("payload.part")
    };
    let _held = canonical(&candidate)?;
    let mut file = lease(&candidate, false)?;
    if identity(&file).ok() != r.artifact_identity {
        return Err("ARTIFACT_IDENTITY_CHANGED");
    }
    let is_final = candidate == PathBuf::from(&r.parent).join(&r.name);
    if is_final {
        if exact_marker(&candidate)? != r.provenance
            || file
                .metadata()
                .map_err(|_| "ARTIFACT_STATE_UNKNOWN")?
                .len()
                .to_string()
                != r.size
        {
            return Err("ARTIFACT_CONTENT_CHANGED");
        }
        let digest = contract::copy_stream(
            &mut file,
            &mut std::io::sink(),
            r.size.parse().map_err(|_| "ARTIFACT_STATE_UNKNOWN")?,
            |_| engine.idle(&e.name()),
        )?;
        if r.digest.as_ref() != Some(&digest) {
            return Err("ARTIFACT_CONTENT_CHANGED");
        }
        r.stage = "COMPLETE_RECOVERED".into();
        r.reason = "TRANSFER_COMPLETED_UNTRUSTED".into();
    } else {
        r.stage = "INCOMPLETE_RETAINED".into();
        r.reason = "EXPLICIT_NEW_OPERATION_REQUIRED".into();
    }
    journal.save(&r)
}
fn discard(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    all: &[OwnedEnvironment],
    journal: &contract::Journal,
    id: Uuid,
) -> R<()> {
    let mut r = journal.get(id)?.ok_or("TRANSFER_NOT_FOUND")?;
    if r.environment_id != e.id || r.generation != generation(e) {
        return Err("ARTIFACT_GENERATION_CHANGED");
    }
    if matches!(r.stage.as_str(), "COMPLETE" | "COMPLETE_RECOVERED") {
        return Err("COMPLETED_OUTPUT_NOT_A_STAGING_ARTIFACT");
    }
    let _scope = scope(engine, e, all, true)?;
    let parent = Path::new(&r.parent);
    let expected = parent.join(format!(".securerun-{}", id.simple()));
    if expected != PathBuf::from(&r.staging_directory) {
        return Err("ARTIFACT_SCOPE_CHANGED");
    }
    let _parents = if r.direction == "EXPORT" {
        destination(engine, &r.parent, all)?
    } else {
        contained(engine, e, parent)?
    };
    if identity(_parents.last().ok_or("ARTIFACT_PARENT_CHANGED")?)? != r.parent_identity {
        return Err("ARTIFACT_PARENT_CHANGED");
    }
    {
        let held = canonical(&expected)?;
        if identity(held.last().ok_or("ARTIFACT_DIRECTORY_CHANGED")?).ok()
            != r.staging_directory_identity
        {
            return Err("ARTIFACT_DIRECTORY_CHANGED");
        }
        if let Some(id) = &r.artifact_identity {
            let payload = OpenOptions::new()
                .access_mode(DELETE | FILE_READ_ATTRIBUTES | READ_CONTROL)
                .share_mode(0)
                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                .open(expected.join("payload.part"))
                .map_err(|_| "ARTIFACT_STATE_UNKNOWN")?;
            if identity(&payload)? != *id {
                return Err("ARTIFACT_IDENTITY_CHANGED");
            }
            let delete = FILE_DISPOSITION_INFO { DeleteFile: true };
            if unsafe {
                SetFileInformationByHandle(
                    payload.as_raw_handle(),
                    FileDispositionInfo,
                    &delete as *const _ as _,
                    std::mem::size_of_val(&delete) as u32,
                )
            } == 0
            {
                return Err("ARTIFACT_DELETE_FAILED");
            }
        }
    }
    let directory = OpenOptions::new()
        .access_mode(DELETE | FILE_READ_ATTRIBUTES | READ_CONTROL)
        .share_mode(0)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(&expected)
        .map_err(|_| "ARTIFACT_DIRECTORY_CHANGED")?;
    if identity(&directory).ok() != r.staging_directory_identity {
        return Err("ARTIFACT_DIRECTORY_CHANGED");
    }
    let delete = FILE_DISPOSITION_INFO { DeleteFile: true };
    if unsafe {
        SetFileInformationByHandle(
            directory.as_raw_handle(),
            FileDispositionInfo,
            &delete as *const _ as _,
            std::mem::size_of_val(&delete) as u32,
        )
    } == 0
    {
        return Err("ARTIFACT_DIRECTORY_NOT_EMPTY_OR_BUSY");
    }
    r.stage = "DISCARDED".into();
    r.reason = "VERIFIED_STAGING_REMOVED".into();
    journal.save(&r)
}
pub fn execute(
    manager_pid: u32,
    manager_birth: u64,
    request: contract::Request,
) -> contract::Reply {
    let mut reply = contract::Reply::failure("NOT_OBSERVED");
    let result = (|| -> R<()> {
        let engine = NativeEngine::new(manager_pid, manager_birth)?;
        let meta = engine.profile.join("metadata");
        if let contract::Request::Cancel { operation_id } = request {
            let p = meta.join(format!("cancel-{operation_id}.flag"));
            let _f = OpenOptions::new()
                .write(true)
                .create_new(true)
                .share_mode(0)
                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                .open(p)
                .map_err(|_| "CANCELLATION_ALREADY_RECORDED")?;
            return Ok(());
        }
        let _lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .share_mode(0)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(meta.join("policy-writer.lock"))
            .map_err(|_| "NAMESPACE_OPERATION_BUSY")?;
        identity(&_lock)?;
        let policy = Journal::open(&meta.join("policy.sqlite"), &engine.owner)?;
        let all = policy.list()?;
        let path = meta.join("transfers.sqlite");
        if path.exists() {
            let _ = lease(&path, true)?;
        }
        let journal = contract::Journal::open(&path)?;
        let (environment_id, revision) = match &request {
            contract::Request::List {
                environment_id,
                expected_revision,
                ..
            }
            | contract::Request::Import {
                environment_id,
                expected_revision,
                ..
            }
            | contract::Request::Export {
                environment_id,
                expected_revision,
                ..
            }
            | contract::Request::Register {
                environment_id,
                expected_revision,
                ..
            }
            | contract::Request::Discard {
                environment_id,
                expected_revision,
                ..
            }
            | contract::Request::Recover {
                environment_id,
                expected_revision,
                ..
            } => (*environment_id, *expected_revision),
            _ => unreachable!(),
        };
        let e = all
            .iter()
            .find(|e| e.id == environment_id)
            .ok_or("OWNERSHIP_NOT_FOUND")?;
        if e.revision != revision || e.stage != Stage::Verified {
            return Err("REVISION_CONFLICT");
        }
        let _scope = scope(&engine, e, &all, false)?;
        let action = (|| match &request {
            contract::Request::List {
                node_id, offset, ..
            } => list(&engine, e, &journal, *node_id, *offset, &mut reply),
            contract::Request::Import {
                operation_id,
                source,
                name,
                ..
            } => {
                engine.idle(&e.name())?;
                let (physical, _) = workspace(&engine, e)?;
                let _held = materialize(&engine, e, &physical)?;
                transfer(
                    &engine,
                    e,
                    &all,
                    &journal,
                    &request,
                    *operation_id,
                    Path::new(source),
                    &physical,
                    name,
                    "IMPORT",
                )
            }
            contract::Request::Export {
                operation_id,
                file_id,
                destination,
                name,
                ..
            } => {
                let (n, _held) = node_path(&engine, e, &journal, *file_id)?;
                if n.directory {
                    return Err("REGULAR_FILE_REQUIRED");
                }
                transfer(
                    &engine,
                    e,
                    &all,
                    &journal,
                    &request,
                    *operation_id,
                    Path::new(&n.path),
                    Path::new(destination),
                    name,
                    "EXPORT",
                )
            }
            contract::Request::Discard { operation_id, .. } => {
                discard(&engine, e, &all, &journal, *operation_id)
            }
            contract::Request::Recover { operation_id, .. } => {
                recover(&engine, e, &all, &journal, *operation_id)
            }
            contract::Request::Register {
                operation_id,
                file_id,
                arguments,
                ..
            } => {
                let (n, _held) = node_path(&engine, e, &journal, *file_id)?;
                engine.idle(&e.name())?;
                let logical = n.logical.as_ref().ok_or("IMPORTED_BOX_EXE_REQUIRED")?;
                let (p, l) = workspace(&engine, e)?;
                let raw = Path::new(&n.path)
                    .file_name()
                    .and_then(|s| s.to_str())
                    .ok_or("FILE_REFERENCE_INVALID")?;
                contract::leaf(raw)?;
                if p.join(raw) != PathBuf::from(&n.path) || format!("{l}\\{raw}") != *logical {
                    return Err("BOX_MAPPING_CHANGED");
                }
                crate::control::command(logical, arguments)?;
                let (identity, _) = super::control::target(&engine, &n.path, true)?;
                let a = crate::control::Application {
                    id: *operation_id,
                    environment_id: e.id,
                    revision: e.revision,
                    display_name: contract::display(raw),
                    executable: logical.clone(),
                    identity: identity.clone(),
                    arguments: arguments.clone(),
                    working_directory: None,
                    directory_identity: None,
                    boxed: Some(crate::control::BoxExecutableRef {
                        generation: generation(e),
                        physical: n.path.clone(),
                        logical: logical.clone(),
                        identity,
                    }),
                };
                let mut applications =
                    crate::control::Journal::open(&meta.join("control.sqlite"), &engine.owner)?;
                applications.register(&a)?;
                reply.application_id = Some(a.id);
                Ok(())
            }
            _ => unreachable!(),
        })();
        reply.transfers = journal.views(e.id)?;
        action
    })();
    reply.reason = result.err().unwrap_or("OBSERVED").into();
    reply
}
pub(super) fn validate_executable(
    engine: &NativeEngine,
    e: &OwnedEnvironment,
    b: &crate::control::BoxExecutableRef,
) -> R<Vec<File>> {
    if b.generation != generation(e) {
        return Err("BOX_EXECUTABLE_GENERATION_CHANGED");
    }
    let (p, l) = workspace(engine, e)?;
    let raw = Path::new(&b.physical)
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or("BOX_EXECUTABLE_INVALID")?;
    contract::leaf(raw)?;
    if p.join(raw) != PathBuf::from(&b.physical) || format!("{l}\\{raw}") != b.logical {
        return Err("BOX_MAPPING_CHANGED");
    }
    let held = contained(engine, e, Path::new(&b.physical))?;
    let (id, _) = super::control::target(engine, &b.physical, true)?;
    if id != b.identity {
        return Err("BOX_EXECUTABLE_IDENTITY_CHANGED");
    }
    Ok(held)
}

pub fn bounded_request(request: &crate::files::Request) -> crate::files::Reply {
    let result = (|| -> R<crate::files::Reply> {
        let pid = unsafe { GetCurrentProcessId() };
        let created = process_birth(pid)?;
        let executable = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let _parents = ancestry(executable.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let _image = lease(&executable, false)?;
        let data = serde_json::to_vec(request).map_err(|_| "FILES_REQUEST_INVALID")?;
        if data.len() > 16384 {
            return Err("FILES_REQUEST_BOUND");
        }
        let windows = system_directory()?;
        let mut command = Command::new(executable);
        command
            .args([
                "--files-worker".into(),
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
        let child = command.spawn().map_err(|_| "BRIDGE_START_FAILED")?;
        let bytes = capture_child(child, Duration::from_secs(3600), Some(data))?;
        let reply: crate::files::Reply =
            serde_json::from_slice(&bytes).map_err(|_| "FILES_RESPONSE_INVALID")?;
        if reply.protocol != 1 || reply.entries.len() > 128 || reply.transfers.len() > 64 {
            return Err("FILES_RESPONSE_INVALID");
        }
        Ok(reply)
    })();
    result.unwrap_or_else(crate::files::Reply::failure)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ntfs_marker_precedes_payload_and_handle_rename_never_replaces() {
        let temp = tempfile::tempdir_in(known(&FOLDERID_LocalAppData).unwrap()).unwrap();
        let owner = process_sid(unsafe { GetCurrentProcess() }).unwrap();
        let stage = temp.path().join("staging");
        let _directory = fresh_directory(&stage, &owner).unwrap();
        let mut payload = fresh_payload(&stage).unwrap();
        assert_eq!(payload.metadata().unwrap().len(), 0);
        let provenance = contract::marker(&[]);
        let _marker = write_marker(&stage.join("payload.part"), &provenance).unwrap();
        payload.write_all(b"SYNTHETIC").unwrap();
        payload.sync_all().unwrap();
        let parent = lease(temp.path(), true).unwrap();
        let existing = temp.path().join("existing.txt");
        std::fs::write(&existing, b"CANARY").unwrap();
        assert!(publish(&payload, &parent, "existing.txt").is_err());
        assert_eq!(std::fs::read(&existing).unwrap(), b"CANARY");
        let id = identity(&payload).unwrap();
        publish(&payload, &parent, "published.html").unwrap();
        let final_path = temp.path().join("published.html");
        assert_eq!(exact_marker(&final_path).unwrap(), provenance);
        assert_eq!(identity(&payload).unwrap(), id);
        assert!(!stage.join("payload.part").exists());
    }
    #[test]
    fn ntfs_unmarked_or_forged_marker_is_never_recovery_proof() {
        let temp = tempfile::tempdir_in(known(&FOLDERID_LocalAppData).unwrap()).unwrap();
        let path = temp.path().join("synthetic.txt");
        std::fs::write(&path, b"SYNTHETIC").unwrap();
        assert_eq!(exact_marker(&path).unwrap_err(), "PROVENANCE_MISSING");
        std::fs::write(format!("{}:Zone.Identifier", path.display()), b"INVALID").unwrap();
        assert_eq!(exact_marker(&path).unwrap_err(), "PROVENANCE_INVALID");
        assert_eq!(
            write_marker(&path, &contract::marker(&[])).unwrap_err(),
            "PROVENANCE_WRITE_FAILED"
        );
    }
    #[test]
    fn ntfs_source_leases_reject_hardlinks_and_deny_growth() {
        let temp = tempfile::tempdir_in(known(&FOLDERID_LocalAppData).unwrap()).unwrap();
        let path = temp.path().join("synthetic.txt");
        std::fs::write(&path, b"SYNTHETIC").unwrap();
        {
            let _held = lease(&path, false).unwrap();
            assert!(
                OpenOptions::new()
                    .write(true)
                    .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
                    .open(&path)
                    .is_err()
            );
        }
        let alias = temp.path().join("alias.txt");
        std::fs::hard_link(&path, &alias).unwrap();
        assert_eq!(
            lease(&path, false).unwrap_err(),
            "REPARSE_OR_HARDLINK_REJECTED"
        );
    }
}
