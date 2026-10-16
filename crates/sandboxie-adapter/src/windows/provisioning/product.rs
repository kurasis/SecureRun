//! Ordinary-user, schema-only history under the existing private metadata boundary.
use super::*;
use crate::product as contract;

pub fn execute(pid: u32, birth: u64, request: contract::Request) -> contract::Reply {
    let result = (|| -> R<contract::Reply> {
        let engine = NativeEngine::new(pid, birth)?;
        let meta = engine.profile.join("metadata");
        if let contract::Request::Rename {
            environment_id,
            expected_revision,
            expected_generation,
            expected_display_name,
            display_name,
            operation_id,
        } = &request
        {
            let namespace = OpenOptions::new()
                .read(true)
                .write(true)
                .create(true)
                .truncate(false)
                .share_mode(0)
                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                .open(meta.join("policy-writer.lock"))
                .map_err(|_| "NAMESPACE_OPERATION_BUSY")?;
            identity(&namespace)?;
            let path = meta.join("policy.sqlite");
            let _db = lease(&path, true)?;
            let mut policy = Journal::open(&path, &engine.owner)?;
            let signature = fingerprint(&(
                "RENAME_METADATA",
                &engine.owner,
                environment_id,
                expected_revision,
                expected_generation,
                expected_display_name,
                display_name,
            ));
            if policy.operation(*operation_id, &signature)?.is_none() {
                validate_display_name(display_name)?;
                let mut environment = policy.get(*environment_id)?;
                let _scope = engine.control_scope(&environment)?;
                if environment.revision != *expected_revision
                    || environment.generation != *expected_generation
                    || environment.display_name != *expected_display_name
                    || environment.lifecycle_operation.is_some()
                {
                    return Err("METADATA_RENAME_STALE");
                }
                environment.display_name = display_name.clone();
                environment.operation_id = *operation_id;
                environment.operation_signature = signature;
                policy.save(&environment)?;
            }
        }

        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .share_mode(0)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(meta.join("history-writer.lock"))
            .map_err(|_| "HISTORY_BUSY")?;
        identity(&lock)?;
        let path = meta.join("history.sqlite");
        let _database = if path.exists() {
            Some(lease(&path, true)?)
        } else {
            None
        };
        let journal = contract::Journal::open(&path, &engine.owner)?;
        if let contract::Request::Record { event } = request {
            journal.record(&event)?;
        }
        let mut available = 0;
        let free = if unsafe {
            GetDiskFreeSpaceExW(
                wide(&engine.profile.to_string_lossy()).as_ptr(),
                &mut available,
                ptr::null_mut(),
                ptr::null_mut(),
            )
        } != 0
        {
            Some(available.to_string())
        } else {
            None
        };
        Ok(contract::Reply {
            reason: "OBSERVED".into(),
            events: journal.list()?,
            free_volume_bytes: free,
            retention_days: contract::RETENTION_DAYS,
            retention_limit: contract::HISTORY_LIMIT,
        })
    })();
    result.unwrap_or_else(contract::Reply::failure)
}
pub fn bounded_request(request: &contract::Request) -> contract::Reply {
    let result = (|| -> R<contract::Reply> {
        let pid = unsafe { GetCurrentProcessId() };
        let birth = process_birth(pid)?;
        let executable = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let _parents = ancestry(executable.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let _image = lease(&executable, false)?;
        let data = serde_json::to_vec(request).map_err(|_| "HISTORY_REQUEST_INVALID")?;
        if data.len() > 2048 {
            return Err("HISTORY_REQUEST_BOUND");
        }
        let windows = system_directory()?;
        let mut command = Command::new(executable);
        command
            .args([
                "--product-worker".into(),
                pid.to_string(),
                birth.to_string(),
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
        let bytes = capture_child(
            command.spawn().map_err(|_| "BRIDGE_START_FAILED")?,
            Duration::from_secs(15),
            Some(data),
        )?;
        let reply: contract::Reply =
            serde_json::from_slice(&bytes).map_err(|_| "HISTORY_RESPONSE_INVALID")?;
        if reply.events.len() > contract::HISTORY_LIMIT
            || reply.retention_days != contract::RETENTION_DAYS
            || reply.retention_limit != contract::HISTORY_LIMIT
        {
            return Err("HISTORY_RESPONSE_INVALID");
        }
        Ok(reply)
    })();
    result.unwrap_or_else(contract::Reply::failure)
}
