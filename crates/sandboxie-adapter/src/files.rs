//! Bounded transfer protocol. Native paths never cross the renderer boundary.
use crate::policy::{PolicyResult, fingerprint};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::{
    io::{Read, Write},
    path::Path,
};
use uuid::Uuid;
pub const CHUNK: usize = 1024 * 1024;
pub const MAX_BYTES: u64 = 1024 * 1024 * 1024 * 1024;
pub const PAGE: usize = 128;

pub fn leaf(value: &str) -> PolicyResult<()> {
    if value.is_empty() || value.encode_utf16().count() > 180 || value.ends_with([' ', '.'])
        || value.chars().any(|c| c.is_control() || matches!(c, '\\'|'/'|':'|'<'|'>'|'"'|'|'|'?'|'*'|'\u{202a}'..='\u{202e}'|'\u{2066}'..='\u{2069}'|'\u{200e}'|'\u{200f}'|'\u{061c}'))
        || value == "." || value == ".." { return Err("OUTPUT_LEAF_UNSAFE"); }
    let stem = value.split('.').next().unwrap().trim_end().to_uppercase();
    if ["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"].contains(&stem.as_str())
        || ["COM", "LPT"].iter().any(|p| {
            stem.strip_prefix(p).is_some_and(|s| {
                matches!(
                    s,
                    "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "¹" | "²" | "³"
                )
            })
        })
    {
        return Err("OUTPUT_LEAF_RESERVED");
    }
    Ok(())
}
pub fn display(value: &str) -> String {
    value.chars().flat_map(|c| if c.is_control() || matches!(c,'\u{202a}'..='\u{202e}'|'\u{2066}'..='\u{2069}'|'\u{200e}'|'\u{200f}'|'\u{061c}') { format!("\\u{{{:04x}}}",c as u32).chars().collect::<Vec<_>>() } else {vec![c]}).collect()
}
pub fn marker(input: &[u8]) -> Vec<u8> {
    // Preserve only a valid, bounded zone; never propagate URLs or arbitrary ADS.
    let zone = std::str::from_utf8(input)
        .ok()
        .filter(|s| s.len() <= 4096 && !s.contains('\0'))
        .and_then(|s| {
            let lines = s.lines().collect::<Vec<_>>();
            if lines.first().copied() != Some("[ZoneTransfer]") {
                return None;
            }
            let values = lines
                .iter()
                .filter_map(|l| l.strip_prefix("ZoneId="))
                .collect::<Vec<_>>();
            if values.len() == 1 && ["0", "1", "2", "3", "4"].contains(&values[0]) {
                values[0].parse::<u8>().ok()
            } else {
                None
            }
        })
        .unwrap_or(3)
        .max(3);
    format!("[ZoneTransfer]\r\nZoneId={zone}\r\n").into_bytes()
}
pub fn copy_stream<R: Read, W: Write>(
    source: &mut R,
    destination: &mut W,
    size: u64,
    mut check: impl FnMut(u64) -> PolicyResult<()>,
) -> PolicyResult<String> {
    use sha2::{Digest, Sha256};
    if size > MAX_BYTES {
        return Err("TRANSFER_SIZE_BOUND");
    }
    let mut buffer = vec![0; CHUNK];
    let mut count = 0u64;
    let mut hash = Sha256::new();
    loop {
        check(count)?;
        let n = source.read(&mut buffer).map_err(|_| "SOURCE_READ_FAILED")?;
        if n == 0 {
            break;
        }
        count = count.checked_add(n as u64).ok_or("TRANSFER_SIZE_BOUND")?;
        if count > size {
            return Err("SOURCE_GREW");
        }
        destination
            .write_all(&buffer[..n])
            .map_err(|_| "COPY_WRITE_FAILED_OR_DISK_FULL")?;
        hash.update(&buffer[..n]);
    }
    if count != size {
        return Err("SOURCE_SIZE_CHANGED");
    }
    Ok(format!("{:x}", hash.finalize()))
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(
    tag = "action",
    rename_all = "SCREAMING_SNAKE_CASE",
    deny_unknown_fields
)]
pub enum Request {
    List {
        environment_id: Uuid,
        expected_revision: u64,
        node_id: Option<Uuid>,
        offset: u32,
    },
    Import {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        source: String,
        name: String,
    },
    Export {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        file_id: Uuid,
        destination: String,
        name: String,
    },
    Register {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
        file_id: Uuid,
        arguments: Vec<String>,
    },
    Recover {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
    },
    Discard {
        environment_id: Uuid,
        expected_revision: u64,
        operation_id: Uuid,
    },
    Cancel {
        operation_id: Uuid,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Entry {
    pub id: Uuid,
    pub name: String,
    pub directory: bool,
    pub size: String,
    pub modified_ms: String,
    pub executable: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Record {
    pub operation_id: Uuid,
    pub environment_id: Uuid,
    pub generation: String,
    pub signature: String,
    pub direction: String,
    pub stage: String,
    pub reason: String,
    pub size: String,
    pub parent: String,
    pub parent_identity: String,
    pub staging_directory: String,
    pub staging_directory_identity: Option<String>,
    pub artifact_identity: Option<String>,
    pub source_identity: String,
    pub name: String,
    pub digest: Option<String>,
    pub provenance: Vec<u8>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TransferView {
    pub operation_id: Uuid,
    pub stage: String,
    pub reason: String,
    pub size: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Node {
    pub environment_id: Uuid,
    pub generation: String,
    pub path: String,
    pub identity: String,
    pub directory: bool,
    pub logical: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reply {
    pub protocol: u32,
    pub reason: String,
    pub entries: Vec<Entry>,
    pub next_offset: Option<u32>,
    pub transfers: Vec<TransferView>,
    pub application_id: Option<Uuid>,
}
impl Reply {
    pub fn failure(reason: &str) -> Self {
        Self {
            protocol: 1,
            reason: reason.into(),
            entries: vec![],
            next_offset: None,
            transfers: vec![],
            application_id: None,
        }
    }
}
fn db_error(_: rusqlite::Error) -> &'static str {
    "TRANSFER_JOURNAL_UNAVAILABLE"
}
fn sha256_id(n: &Node) -> [u8; 16] {
    use sha2::{Digest, Sha256};
    let hash = Sha256::digest(fingerprint(n).as_bytes());
    hash[..16].try_into().unwrap()
}
pub struct Journal {
    db: Connection,
}
impl Journal {
    pub fn open(path: &Path) -> PolicyResult<Self> {
        let db = Connection::open(path).map_err(db_error)?;
        db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA synchronous=FULL; PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS transfers(id TEXT PRIMARY KEY,document TEXT NOT NULL); CREATE TABLE IF NOT EXISTS nodes(id TEXT PRIMARY KEY,document TEXT NOT NULL);").map_err(db_error)?;
        Ok(Self { db })
    }
    pub fn save(&self, r: &Record) -> PolicyResult<()> {
        self.db.execute("INSERT INTO transfers VALUES(?1,?2) ON CONFLICT(id) DO UPDATE SET document=excluded.document",params![r.operation_id.to_string(),serde_json::to_string(r).map_err(|_|"TRANSFER_RECORD_INVALID")?]).map_err(db_error)?;
        Ok(())
    }
    pub fn get(&self, id: Uuid) -> PolicyResult<Option<Record>> {
        let value: Option<String> = self
            .db
            .query_row(
                "SELECT document FROM transfers WHERE id=?1",
                [id.to_string()],
                |r| r.get(0),
            )
            .optional()
            .map_err(db_error)?;
        value
            .map(|s| serde_json::from_str(&s).map_err(|_| "TRANSFER_RECORD_INVALID"))
            .transpose()
    }
    pub fn views(&self, environment: Uuid) -> PolicyResult<Vec<TransferView>> {
        let mut q = self
            .db
            .prepare("SELECT document FROM transfers ORDER BY rowid DESC LIMIT 256")
            .map_err(db_error)?;
        let rows = q
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(db_error)?;
        let mut result = vec![];
        for row in rows {
            let r: Record = serde_json::from_str(&row.map_err(db_error)?)
                .map_err(|_| "TRANSFER_RECORD_INVALID")?;
            if r.environment_id == environment {
                result.push(TransferView {
                    operation_id: r.operation_id,
                    stage: r.stage,
                    reason: r.reason,
                    size: r.size,
                });
                if result.len() == 64 {
                    break;
                }
            }
        }
        Ok(result)
    }
    pub fn node(&self, n: &Node) -> PolicyResult<Uuid> {
        let id = Uuid::from_bytes(sha256_id(n));
        self.db
            .execute(
                "INSERT OR REPLACE INTO nodes VALUES(?1,?2)",
                params![
                    id.to_string(),
                    serde_json::to_string(n).map_err(|_| "FILE_REFERENCE_INVALID")?
                ],
            )
            .map_err(db_error)?;
        Ok(id)
    }
    pub fn resolve(&self, id: Uuid, environment: Uuid, generation: &str) -> PolicyResult<Node> {
        let text: String = self
            .db
            .query_row(
                "SELECT document FROM nodes WHERE id=?1",
                [id.to_string()],
                |r| r.get(0),
            )
            .map_err(|_| "FILE_REFERENCE_NOT_FOUND")?;
        let n: Node = serde_json::from_str(&text).map_err(|_| "FILE_REFERENCE_INVALID")?;
        if n.environment_id != environment || n.generation != generation {
            return Err("FILE_REFERENCE_GENERATION_CHANGED");
        }
        Ok(n)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn adversarial_leaf_names_and_visible_suffix() {
        for n in [
            "",
            ".",
            "..",
            "a/b",
            "a\\b",
            "C:foo",
            "foo:bar",
            "NUL.txt",
            "COM1.exe",
            "LPT².foo",
            "aux .txt",
            "a.",
            "a ",
            "a\u{202e}exe.txt",
            "a\n.html",
        ] {
            assert!(leaf(n).is_err(), "{n:?}");
        }
        for n in ["Привет 🧪.exe", "a.html.svg", "normal.txt"] {
            assert!(leaf(n).is_ok());
        }
        assert_eq!(display("a\u{202e}exe.txt"), "a\\u{202e}exe.txt");
    }
    #[test]
    fn bounded_copy_growth_cancellation_and_io_failure() {
        let mut out = vec![];
        assert_eq!(
            copy_stream(&mut &b"abc"[..], &mut out, 2, |_| Ok(())).unwrap_err(),
            "SOURCE_GREW"
        );
        assert!(out.is_empty());
        assert_eq!(
            copy_stream(&mut &b"abc"[..], &mut out, 3, |_| Err("CANCELLED")).unwrap_err(),
            "CANCELLED"
        );
        assert!(out.is_empty());
        assert_eq!(
            copy_stream(&mut &b"abc"[..], &mut std::io::sink(), 4, |_| Ok(())).unwrap_err(),
            "SOURCE_SIZE_CHANGED"
        );
    }
    #[test]
    fn provenance_is_bounded_and_never_copies_urls() {
        assert_eq!(
            marker(b"[ZoneTransfer]\nZoneId=4\nHostUrl=secret"),
            b"[ZoneTransfer]\r\nZoneId=4\r\n"
        );
        assert_eq!(marker(b"ZoneId=0"), marker(b""));
        assert_eq!(marker(b"[ZoneTransfer]\nZoneId=3\nZoneId=0"), marker(b""));
    }
}
