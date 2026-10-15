//! Production host-EXE launch and environment-scoped held-object stopping.
use super::*;
use crate::control::{self as contract, Application, ProcessView, Receipt};

fn checkpoint(stage: &str) {
    #[cfg(feature = "policy-ci")]
    if std::env::var("GITHUB_ACTIONS").as_deref() == Ok("true")
        && std::env::var("SECURERUN_P06_PAUSE_STAGE").as_deref() == Ok(stage)
    {
        println!("CHECKPOINT_{stage}");
        let _ = std::io::stdout().flush();
        if stage == "StopHeld" {
            std::thread::sleep(Duration::from_secs(3));
        } else {
            loop {
                std::thread::park();
            }
        }
    }
    #[cfg(not(feature = "policy-ci"))]
    let _ = stage;
}
fn target(engine: &NativeEngine, path: &str) -> R<(String, Vec<File>)> {
    literal_path(path)?;
    let lower = path.to_lowercase();
    for private in [
        engine.profile.to_string_lossy().to_lowercase(),
        engine.trusted.home.to_string_lossy().to_lowercase(),
    ] {
        if lower == private || lower.starts_with(&(private + "\\")) {
            return Err("HOST_EXE_SCOPE_INVALID");
        }
    }
    if !lower.ends_with(".exe") {
        return Err("HOST_EXE_REQUIRED");
    }
    let mut held = canonical(Path::new(path))?;
    let mut file = lease(Path::new(path), false)?;
    let mut bytes = vec![];
    Read::by_ref(&mut file)
        .take(536870913)
        .read_to_end(&mut bytes)
        .map_err(|_| "TARGET_UNAVAILABLE")?;
    let offset = bytes
        .get(0x3c..0x40)
        .and_then(|v| v.try_into().ok())
        .map(u32::from_le_bytes)
        .ok_or("TARGET_PE_INVALID")? as usize;
    let machine = bytes.get(offset.saturating_add(4)..offset.saturating_add(6));
    if bytes.len() > 536870912
        || bytes.get(..2) != Some(b"MZ")
        || bytes.get(offset..offset.saturating_add(4)) != Some(b"PE\0\0")
        || !matches!(
            machine,
            Some([0x4c, 0x01]) | Some([0x64, 0x86]) | Some([0x64, 0xaa])
        )
    {
        return Err("TARGET_PE_INVALID");
    }
    if std::env::consts::ARCH != "aarch64" && machine == Some(&[0x64, 0xaa]) {
        return Err("TARGET_ARCHITECTURE_UNSUPPORTED");
    }
    let id = fingerprint(&(identity(&file)?, format!("{:x}", Sha256::digest(&bytes))));
    held.push(file);
    Ok((id, held))
}
fn directory(path: &str) -> R<(String, Vec<File>)> {
    let held = canonical(Path::new(path))?;
    let file = held.last().ok_or("TARGET_CWD_INVALID")?;
    if !file.metadata().map_err(|_| "TARGET_CWD_INVALID")?.is_dir() {
        return Err("TARGET_CWD_INVALID");
    }
    Ok((identity(file)?, held))
}
impl NativeEngine {
    /// Stop deliberately does not depend on effective network policy, release
    /// enforcement proof, paid entitlement, target registration or path grants.
    fn control_scope(&self, e: &OwnedEnvironment) -> R<Vec<File>> {
        self.mutation_context()?;
        if e.owner_sid != self.owner || e.engine_identity != self.engine_identity() {
            return Err("STOP_OWNERSHIP_CHANGED");
        }
        let section = self.section(&e.name(), false)?;
        if section.get("SecureRunOwner") != Some(&vec![e.marker()])
            || section.get("FileRootPath") != Some(&vec![self.root_for(e.id)])
        {
            return Err("STOP_SCOPE_CHANGED");
        }
        let root = self.api.root(&e.name());
        if root.path.as_ref() != Some(&self.root_for(e.id))
            || root.identity.is_none()
            || root.identity != e.root_identity
        {
            return Err("STOP_ROOT_CHANGED");
        }
        let held = canonical(Path::new(root.path.as_ref().unwrap()))?;
        private(held.last().ok_or("STOP_ROOT_CHANGED")?, &self.owner)?;
        Ok(held)
    }
    fn member(&self, process: &Handle, pid: u32, e: &OwnedEnvironment) -> R<ProcessIdentity> {
        let mut name = [0u16; 40];
        let mut sid = [0u16; 96];
        let mut session = 0;
        let mut created = 0;
        if unsafe {
            (self.api.query)(
                pid as usize as _,
                0,
                name.as_mut_ptr(),
                ptr::null_mut(),
                sid.as_mut_ptr(),
                &mut session,
                &mut created,
            )
        } != 0
            || text(&name)? != e.name()
            || text(&sid)? != self.owner
            || created == 0
            || birth(process)? != created
        {
            return Err("PROCESS_SCOPE_CHANGED");
        }
        Ok(ProcessIdentity {
            pid,
            creation_time: created,
            owner_sid: self.owner.clone(),
            session,
            box_name: e.name(),
        })
    }
    fn launch_application(
        &self,
        e: &OwnedEnvironment,
        a: &Application,
        all: &[OwnedEnvironment],
    ) -> R<(String, Option<ProcessIdentity>)> {
        if e.stage != Stage::Verified || e.revision != a.revision {
            return Err("LAUNCH_REVISION_NOT_VERIFIED");
        }
        validate_owned(self, e, all)?;
        // Release-family and actual kernel/product tuple, independent of the
        // writable metadata proof. The underlying policy family was exercised
        // in P05 run 38648135812 on precisely these two laboratories.
        let tuple = if std::env::consts::ARCH == "aarch64" {
            (10u32, 0u32, 26200u32, 1u8, "aarch64")
        } else {
            (10, 0, 26100, 3, "x86_64")
        };
        if self.os_identity != fingerprint(&tuple) || a.environment_id != e.id {
            return Err("RELEASE_TUPLE_UNTESTED");
        }
        let (id, _exe) = target(self, &a.executable)?;
        if id != a.identity {
            return Err("TARGET_IDENTITY_CHANGED");
        }
        let cwd = a
            .working_directory
            .clone()
            .unwrap_or(system_directory()?.to_string_lossy().into());
        let (cwd_id, _cwd) = directory(&cwd)?;
        if a.working_directory.is_some() && a.directory_identity.as_ref() != Some(&cwd_id) {
            return Err("TARGET_CWD_CHANGED");
        }
        let command = wide(&contract::command(&a.executable, &a.arguments)?);
        let run: Run = unsafe { bind(&self.api, b"SbieDll_RunSandboxed\0")? };
        self.mutation_context()?;
        self.set(&e.name(), "Enabled", &["y".into()])?;
        self.reload()?;
        let dispatched = (|| -> R<(String, Option<ProcessIdentity>)> {
            let mut enabled = e.compiled.clone();
            enabled.section.insert("Enabled".into(), vec!["y".into()]);
            verify_readback(
                &enabled,
                &self.section(&e.name(), false)?,
                &self.section(&e.name(), true)?,
                &self.global()?,
            )?;
            self.validate_root(e)?;
            let mut si = unsafe { std::mem::zeroed::<STARTUPINFOW>() };
            si.cb = std::mem::size_of_val(&si) as u32;
            let mut pi = unsafe { std::mem::zeroed::<PROCESS_INFORMATION>() };
            if unsafe {
                run(
                    wide(&e.name()).as_ptr(),
                    command.as_ptr(),
                    wide(&cwd).as_ptr(),
                    CREATE_SUSPENDED | CREATE_NO_WINDOW,
                    &mut si,
                    &mut pi,
                )
            } == 0
            {
                return Err("ENGINE_DISPATCH_REFUSED");
            }
            let process = Handle(pi.hProcess);
            let thread = Handle(pi.hThread);
            // The pinned service marks the process boxed before returning its
            // suspended handles. Target instructions cannot run before this check.
            let member = match self.member(&process, pi.dwProcessId, e) {
                Ok(p) => p,
                Err(code) => {
                    unsafe {
                        TerminateProcess(process.0, 79);
                        WaitForSingleObject(process.0, 5000);
                    }
                    return Err(code);
                }
            };
            if unsafe { ResumeThread(thread.0) } == u32::MAX {
                unsafe {
                    TerminateProcess(process.0, 79);
                    WaitForSingleObject(process.0, 5000);
                }
                return Err("TARGET_RESUME_UNKNOWN");
            }
            // A boxed receipt is valid even if the primary exits immediately.
            checkpoint("Accepted");
            let state = if unsafe { WaitForSingleObject(process.0, 150) } == WAIT_OBJECT_0 {
                "PRIMARY_EXITED_BOXED"
            } else {
                "RUNNING_BOXED"
            };
            Ok((state.into(), Some(member)))
        })();
        // Fence external new launches after this dispatch; existing boxed
        // descendants keep their established boundary and remain observable.
        let fenced = self
            .set(&e.name(), "Enabled", &["n".into()])
            .and_then(|_| self.reload());
        if fenced.is_err() {
            return Err("DISPATCH_OUTCOME_UNKNOWN_FENCE_FAILED");
        }
        dispatched
    }
    fn stop_environment(&self, e: &OwnedEnvironment) -> R<()> {
        let _root = self.control_scope(e)?;
        self.set(&e.name(), "Enabled", &["n".into()])?;
        self.reload()?;
        for _ in 0..8 {
            let _scope = self.control_scope(e)?;
            let processes = self.api.processes(&e.name())?;
            if processes.is_empty() {
                return Ok(());
            }
            let mut held = vec![];
            for p in processes {
                let handle = unsafe {
                    OpenProcess(
                        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE | SYNCHRONIZE,
                        0,
                        p.pid,
                    )
                };
                if handle.is_null() {
                    if unsafe { GetLastError() } == ERROR_INVALID_PARAMETER {
                        continue;
                    }
                    return Err("STOP_PROCESS_HANDLE_UNAVAILABLE");
                }
                let handle = Handle(handle);
                if unsafe { WaitForSingleObject(handle.0, 0) } == WAIT_OBJECT_0 {
                    continue;
                }
                let current = self.member(&handle, p.pid, e)?;
                if current != p {
                    return Err("STOP_PROCESS_IDENTITY_CHANGED");
                }
                let mut critical = 0;
                if unsafe { IsProcessCritical(handle.0, &mut critical) } == 0 || critical != 0 {
                    return Err("STOP_CRITICAL_STATE_UNSAFE");
                }
                held.push((handle, p));
            }
            // All selected objects are authorized before any termination.
            checkpoint("StopHeld");
            for (handle, p) in held {
                if unsafe { WaitForSingleObject(handle.0, 0) } == WAIT_OBJECT_0 {
                    continue;
                }
                let _scope = self.control_scope(e)?;
                if self.member(&handle, p.pid, e)? != p {
                    return Err("STOP_PROCESS_SCOPE_CHANGED");
                }
                if unsafe { TerminateProcess(handle.0, 79) } == 0
                    && unsafe { WaitForSingleObject(handle.0, 0) } != WAIT_OBJECT_0
                {
                    return Err("STOP_DISPATCH_UNKNOWN");
                }
                if unsafe { WaitForSingleObject(handle.0, 5000) } != WAIT_OBJECT_0 {
                    return Err("STOP_COMPLETION_UNKNOWN");
                }
            }
        }
        let _scope = self.control_scope(e)?;
        self.idle(&e.name())
    }
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
        let policy_path = meta.join("policy.sqlite");
        if policy_path.exists() {
            let _ = lease(&policy_path, true)?;
        }
        let journal = Journal::open(&policy_path, &engine.owner)?;
        let all = journal.list()?;
        let path = meta.join("control.sqlite");
        if path.exists() {
            let _ = lease(&path, true)?;
        }
        let mut control = contract::Journal::open(&path, &engine.owner)?;
        let find = |id: Uuid| all.iter().find(|e| e.id == id).ok_or("OWNERSHIP_NOT_FOUND");
        match &request {
            contract::Request::List => {}
            contract::Request::Reconcile { operation_id } => {
                if control.receipt(*operation_id)?.is_none() {
                    return Err("OPERATION_NOT_FOUND");
                }
            }
            contract::Request::Register {
                environment_id,
                expected_revision,
                operation_id,
                display_name,
                executable,
                arguments,
                working_directory,
            } => {
                let e = find(*environment_id)?;
                if control
                    .reserve(*operation_id, &request, &(&e.owner_sid, &e.root_identity))?
                    .is_none()
                {
                    let registration = (|| -> R<Application> {
                        if e.revision != *expected_revision || e.stage != Stage::Verified {
                            return Err("REVISION_CONFLICT");
                        }
                        validate_owned(&engine, e, &all)?;
                        contract::command(executable, arguments)?;
                        if display_name.trim().is_empty()
                            || display_name.chars().count() > 80
                            || display_name.chars().any(char::is_control)
                        {
                            return Err("APPLICATION_NAME_INVALID");
                        }
                        let (identity, _held) = target(&engine, executable)?;
                        let directory_identity = working_directory
                            .as_ref()
                            .map(|p| directory(p).map(|(id, _)| id))
                            .transpose()?;
                        Ok(Application {
                            id: Uuid::new_v4(),
                            environment_id: *environment_id,
                            revision: *expected_revision,
                            display_name: display_name.trim().into(),
                            executable: executable.clone(),
                            identity,
                            arguments: arguments.clone(),
                            working_directory: working_directory.clone(),
                            directory_identity,
                        })
                    })();
                    let (state, reason) = match registration {
                        Ok(a) => {
                            control.register(&a)?;
                            ("REGISTERED", "APPLICATION_REGISTERED")
                        }
                        Err(code) => ("REFUSED", code),
                    };
                    control.finish(&Receipt {
                        operation_id: *operation_id,
                        environment_id: Some(*environment_id),
                        state: state.into(),
                        reason: reason.into(),
                        process: None,
                    })?;
                }
            }
            contract::Request::Launch {
                application_id,
                environment_id,
                expected_revision,
                operation_id,
            } => {
                let e = find(*environment_id)?;
                let a = control
                    .applications()?
                    .into_iter()
                    .find(|a| a.id == *application_id && a.environment_id == *environment_id)
                    .ok_or("APPLICATION_NOT_FOUND")?;
                if control
                    .reserve(
                        *operation_id,
                        &request,
                        &(&e.owner_sid, &e.root_identity, &a.identity),
                    )?
                    .is_none()
                {
                    checkpoint("Reserved");
                    let result = if e.revision != *expected_revision {
                        Err("REVISION_CONFLICT")
                    } else {
                        engine.launch_application(e, &a, &all)
                    };
                    let (state, reason, process) = match result {
                        Ok((state, p)) => (state, "ENGINE_BOXED_RECEIPT", p),
                        Err(code) => ("UNKNOWN".into(), code, None),
                    };
                    control.finish(&Receipt {
                        operation_id: *operation_id,
                        environment_id: Some(*environment_id),
                        state,
                        reason: reason.into(),
                        process,
                    })?;
                }
            }
            contract::Request::Stop {
                environment_id,
                operation_id,
            } => {
                let e = find(*environment_id)?;
                if control
                    .reserve(*operation_id, &request, &(&e.owner_sid, &e.root_identity))?
                    .is_none()
                {
                    let result = engine.stop_environment(e);
                    control.finish(&Receipt {
                        operation_id: *operation_id,
                        environment_id: Some(*environment_id),
                        state: if result.is_ok() { "STOPPED" } else { "UNKNOWN" }.into(),
                        reason: result.err().unwrap_or("COMPLETE_EMPTY_SCOPE").into(),
                        process: None,
                    })?;
                }
            }
            contract::Request::StopManaged { operation_id } => {
                let scope = all
                    .iter()
                    .map(|e| (e.id, &e.owner_sid, &e.root_identity))
                    .collect::<Vec<_>>();
                if control.reserve(*operation_id, &request, &scope)?.is_none() {
                    let mut result = Ok(());
                    for e in &all {
                        if let Err(code) = engine.stop_environment(e) {
                            result = Err(code)
                        }
                    }
                    control.finish(&Receipt {
                        operation_id: *operation_id,
                        environment_id: None,
                        state: if result.is_ok() { "STOPPED" } else { "UNKNOWN" }.into(),
                        reason: result.err().unwrap_or("ALL_MANAGED_SCOPES_EMPTY").into(),
                        process: None,
                    })?;
                }
            }
        }
        reply.applications = control
            .applications()?
            .into_iter()
            .map(Into::into)
            .collect();
        reply.receipts = control.receipts()?;
        for e in &all {
            let eligible = e.stage == Stage::Verified && validate_owned(&engine, e, &all).is_ok();
            let processes = engine
                .control_scope(e)
                .and_then(|_scope| engine.api.processes(&e.name()));
            let (activity, complete, processes, reason) = match processes {
                Ok(p) => (
                    if p.is_empty() { "IDLE" } else { "RUNNING" },
                    true,
                    p,
                    "OBSERVED",
                ),
                Err(code) => ("UNKNOWN", false, vec![], code),
            };
            reply.environments.push(ProcessView {
                environment_id: e.id,
                activity: activity.into(),
                complete,
                processes,
                launch_eligible: eligible,
                reason: reason.into(),
            });
        }
        Ok(())
    })();
    reply.reason = result.err().unwrap_or("OBSERVED").into();
    reply
}

pub fn bounded_request(request: &contract::Request) -> contract::Reply {
    let result = (|| -> R<contract::Reply> {
        let pid = unsafe { GetCurrentProcessId() };
        let created = process_birth(pid)?;
        let executable = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let _parents = ancestry(executable.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let _image = lease(&executable, false)?;
        let data = serde_json::to_vec(request).map_err(|_| "CONTROL_REQUEST_INVALID")?;
        if data.len() > 16384 {
            return Err("CONTROL_REQUEST_BOUND");
        }
        let windows = system_directory()?;
        let mut command = Command::new(executable);
        command
            .args([
                "--control-worker".into(),
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
        let bytes = capture_child(child, Duration::from_secs(120), Some(data))?;
        let reply: contract::Reply =
            serde_json::from_slice(&bytes).map_err(|_| "CONTROL_RESPONSE_INVALID")?;
        if reply.protocol != 1
            || reply.applications.len() > 128
            || reply.environments.len() > 12
            || reply.receipts.len() > 64
        {
            return Err("CONTROL_RESPONSE_INVALID");
        }
        Ok(reply)
    })();
    result.unwrap_or_else(contract::Reply::failure)
}
