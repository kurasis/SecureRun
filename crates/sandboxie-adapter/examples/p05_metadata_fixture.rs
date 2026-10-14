//! Disposable standard-user metadata corruption fixture; never a product command.
#[cfg(all(windows, feature = "policy-ci"))]
fn main() {
    use rusqlite::{Connection, params};
    use std::os::windows::fs::OpenOptionsExt;
    let result = (|| -> Result<(), Box<dyn std::error::Error>> {
        if std::env::var("GITHUB_ACTIONS").as_deref() != Ok("true") {
            return Err("DISPOSABLE_ACTIONS_VM_REQUIRED".into());
        }
        let profile = securerun_sandboxie_adapter::windows::provisioning::profile_path()?;
        if !profile.ancestors().any(|p| {
            p.file_name().is_some_and(|n| {
                n.to_string_lossy()
                    .to_ascii_lowercase()
                    .starts_with("srp05_meta_")
            })
        }) {
            return Err("SYNTHETIC_TEST_ACCOUNT_REQUIRED".into());
        }
        let metadata = profile.join("metadata");
        let _lock = std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .share_mode(0)
            .open(metadata.join("policy-writer.lock"))?;
        let connection = Connection::open(metadata.join("policy.sqlite"))?;
        connection.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL;")?;
        if connection.query_row("SELECT count(*) FROM owned", [], |r| r.get::<_, i64>(0))? != 1 {
            return Err("ONE_SYNTHETIC_ENVIRONMENT_REQUIRED".into());
        }
        let (id, document): (String, String) =
            connection.query_row("SELECT id,document FROM owned", [], |r| {
                Ok((r.get(0)?, r.get(1)?))
            })?;
        let backup = metadata.join("p05-fixture-original.json");
        match std::env::args().nth(1).as_deref() {
            Some("corrupt") => {
                use std::io::Write;
                let mut value: serde_json::Value = serde_json::from_str(&document)?;
                if value["display_name"] != "Synthetic metadata authority fixture" {
                    return Err("SYNTHETIC_RECORD_REQUIRED".into());
                }
                let mut file = std::fs::OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&backup)?;
                file.write_all(document.as_bytes())?;
                file.sync_all()?;
                value["compiled"]["section"]["FileRootPath"] =
                    serde_json::json!(["C:\\Windows\\System32"]);
                value["compiled"]["section"]["ClosedFilePath"] = serde_json::json!([]);
                connection.execute(
                    "UPDATE owned SET document=?1 WHERE id=?2",
                    params![serde_json::to_string(&value)?, id],
                )?;
            }
            Some("restore") => {
                let original = std::fs::read_to_string(backup)?;
                connection.execute(
                    "UPDATE owned SET document=?1 WHERE id=?2",
                    params![original, id],
                )?;
            }
            _ => return Err("FIXTURE_ACTION_REQUIRED".into()),
        }
        Ok(())
    })();
    if result.is_err() {
        eprintln!("METADATA_FIXTURE_REFUSED");
        std::process::exit(1);
    }
}
#[cfg(not(all(windows, feature = "policy-ci")))]
fn main() {
    eprintln!("The metadata fixture requires the disposable Windows CI feature.");
    std::process::exit(64);
}
