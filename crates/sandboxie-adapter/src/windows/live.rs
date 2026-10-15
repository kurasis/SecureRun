//! Bounded read-only snapshots while authenticated component objects stay held.
//! Production mutations continue to use independent fresh one-shot workers.
use super::*;
use std::io::{BufRead, BufReader, Write};
use std::sync::mpsc::{Receiver, sync_channel};
use std::time::Duration;

const FRAMES: usize = 60;

pub fn worker(manager_pid: u32, manager_birth: u64) -> i32 {
    let result = (|| -> R<()> {
        let began = Instant::now();
        let trusted = discover()?;
        let api = Api::load(&trusted.home)?;
        let mut output = std::io::stdout().lock();
        for _ in 0..FRAMES {
            if began.elapsed() >= Duration::from_secs(60) {
                break;
            }
            let frame_started = Instant::now();
            // This repeats SCM status/configuration, protected ownership/DACL,
            // retained object/link identity, current driver/version/context and
            // the complete box/process/root/configuration observation.
            let report = observe_retained(manager_pid, manager_birth, Some((&trusted, &api)));
            let okay = report.reason == "OBSERVED";
            let bytes = serde_json::to_vec(&report).map_err(|_| "BRIDGE_PROTOCOL_INVALID")?;
            if bytes.len() > RESPONSE_LIMIT {
                return Err("BRIDGE_RESPONSE_BOUND");
            }
            output.write_all(&bytes).map_err(|_| "BRIDGE_PIPE_FAILED")?;
            output.write_all(b"\n").map_err(|_| "BRIDGE_PIPE_FAILED")?;
            output.flush().map_err(|_| "BRIDGE_PIPE_FAILED")?;
            if !okay {
                return Ok(());
            }
            std::thread::sleep(Duration::from_millis(1700).saturating_sub(frame_started.elapsed()));
        }
        Ok(())
    })();
    if let Err(reason) = result {
        let mut report = Observation::failure(reason);
        report.manager_pid = manager_pid;
        report.manager_birth = manager_birth;
        if let Ok(bytes) = serde_json::to_vec(&report) {
            let mut output = std::io::stdout().lock();
            let _ = output.write_all(&bytes);
            let _ = output.write_all(b"\n");
            let _ = output.flush();
        }
        return 1;
    }
    0
}

fn read_frame(reader: &mut impl BufRead) -> R<Vec<u8>> {
    let mut bytes = Vec::new();
    let count = Read::take(reader, (RESPONSE_LIMIT + 1) as u64)
        .read_until(b'\n', &mut bytes)
        .map_err(|_| "BRIDGE_PIPE_FAILED")?;
    if count == 0 {
        return Err("BRIDGE_STREAM_ENDED");
    }
    if bytes.len() > RESPONSE_LIMIT || bytes.last() != Some(&b'\n') {
        return Err("BRIDGE_RESPONSE_BOUND");
    }
    bytes.pop();
    Ok(bytes)
}

pub struct Stream {
    child: std::process::Child,
    _job: Handle,
    _image: File,
    _home: Vec<File>,
    frames: Receiver<R<Vec<u8>>>,
    manager_pid: u32,
    manager_birth: u64,
    count: usize,
    last_observed: u64,
    began: Instant,
}
impl Stream {
    pub fn start() -> R<Self> {
        let began = Instant::now();
        let manager_pid = unsafe { GetCurrentProcessId() };
        let manager_birth = process_birth(manager_pid)?;
        let image = std::env::current_exe().map_err(|_| "MANAGER_IMAGE_UNKNOWN")?;
        let _home = ancestry(image.parent().ok_or("MANAGER_IMAGE_UNKNOWN")?)?;
        let _image = lease(&image, false)?;
        let windows = system_directory()?;
        let mut child = Command::new(&image)
            .args([
                "--engine-stream-worker".into(),
                manager_pid.to_string(),
                manager_birth.to_string(),
            ])
            .current_dir(&windows)
            .env_clear()
            .env("SystemRoot", windows.parent().ok_or("SYSTEM_PATH_UNKNOWN")?)
            .env("WINDIR", windows.parent().unwrap())
            .env("PATH", &windows)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW)
            .spawn()
            .map_err(|_| "BRIDGE_START_FAILED")?;
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
        let stdout = child.stdout.take().ok_or("BRIDGE_PIPE_FAILED")?;
        let (sender, frames) = sync_channel(1);
        std::thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            for _ in 0..FRAMES {
                let result = read_frame(&mut reader);
                let failed = result.is_err();
                if sender.send(result).is_err() || failed {
                    break;
                }
            }
        });
        Ok(Self {
            child,
            _job: job,
            _image,
            _home,
            frames,
            manager_pid,
            manager_birth,
            count: 0,
            last_observed: 0,
            began,
        })
    }
    pub fn next_frame(&mut self) -> R<Observation> {
        if self.count >= FRAMES || self.began.elapsed() >= Duration::from_secs(60) {
            return Err("BRIDGE_STREAM_ENDED");
        }
        let wait = if self.count == 0 {
            Duration::from_secs(20)
        } else {
            Duration::from_secs(4)
        };
        let remaining = Duration::from_secs(60).saturating_sub(self.began.elapsed());
        let frame = match self.frames.recv_timeout(wait.min(remaining)) {
            Ok(frame) => frame,
            Err(_) if self.began.elapsed() >= Duration::from_secs(60) => {
                return Err("BRIDGE_STREAM_ENDED");
            }
            Err(_) => return Err("BRIDGE_PIPE_TIMEOUT"),
        };
        let bytes = match frame {
            Err("BRIDGE_STREAM_ENDED") if self.began.elapsed() < Duration::from_secs(59) => {
                return Err("BRIDGE_EXIT_FAILED");
            }
            other => other?,
        };
        let report = parse_response(&bytes, self.manager_pid, self.manager_birth)?;
        if self.count != 0 && report.observed_unix_ms <= self.last_observed {
            return Err("BRIDGE_RESPONSE_STALE");
        }
        self.last_observed = report.observed_unix_ms;
        self.count += 1;
        Ok(report)
    }
}
impl Drop for Stream {
    fn drop(&mut self) {
        let _ = self.child.kill();
        unsafe {
            WaitForSingleObject(self.child.as_raw_handle(), 5000);
            let mut created = std::mem::zeroed();
            let mut exited = std::mem::zeroed();
            let mut kernel = std::mem::zeroed::<FILETIME>();
            let mut user = std::mem::zeroed::<FILETIME>();
            if GetProcessTimes(
                self.child.as_raw_handle(),
                &mut created,
                &mut exited,
                &mut kernel,
                &mut user,
            ) != 0
            {
                let ticks = ((kernel.dwHighDateTime as u64) << 32 | kernel.dwLowDateTime as u64)
                    + ((user.dwHighDateTime as u64) << 32 | user.dwLowDateTime as u64);
                let _ = writeln!(
                    std::io::stderr().lock(),
                    "PASSIVE_OBSERVER_FRAMES={};CPU100NS={ticks}",
                    self.count
                );
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn live_frames_are_separate_bounded_and_require_a_complete_line() {
        let mut input = std::io::Cursor::new(b"{}\n{ \"placeholder\": true }\n");
        assert_eq!(read_frame(&mut input).unwrap(), b"{}");
        assert_eq!(
            read_frame(&mut input).unwrap(),
            b"{ \"placeholder\": true }"
        );
        assert_eq!(read_frame(&mut input), Err("BRIDGE_STREAM_ENDED"));
        assert_eq!(
            read_frame(&mut std::io::Cursor::new(b"{}")),
            Err("BRIDGE_RESPONSE_BOUND")
        );
        assert_eq!(
            read_frame(&mut std::io::Cursor::new(vec![b'x'; RESPONSE_LIMIT + 1])),
            Err("BRIDGE_RESPONSE_BOUND")
        );
    }
    #[test]
    fn held_payload_bytes_cannot_be_written_before_the_lease_is_released() {
        let path =
            std::env::temp_dir().join(format!("securerun-held-{}.bin", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"SYNTHETIC_PINNED_BYTES").unwrap();
        let held = lease(&path, false).unwrap();
        let error = OpenOptions::new()
            .write(true)
            .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
            .open(&path)
            .unwrap_err();
        assert_eq!(error.raw_os_error(), Some(ERROR_SHARING_VIOLATION as i32));
        assert_eq!(std::fs::read(&path).unwrap(), b"SYNTHETIC_PINNED_BYTES");
        let alias = path.with_extension("alias");
        std::fs::hard_link(&path, &alias).unwrap();
        assert_eq!(identity(&held), Err("REPARSE_OR_HARDLINK_REJECTED"));
        std::fs::remove_file(alias).unwrap();
        drop(held);
        drop(OpenOptions::new().write(true).open(&path).unwrap());
        std::fs::remove_file(path).unwrap();
    }
}
