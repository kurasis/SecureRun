//! A deliberately small policy family. Mandatory controls are never renderer input.
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;

pub type PolicyResult<T> = Result<T, &'static str>;
pub type Section = BTreeMap<String, Vec<String>>;
pub const FAMILY: &str = "STANDARD_V1";
pub const RAW_FLAGS: u32 = 0x70000000;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Preset {
    StandardOffline,
    StandardOnline,
    PrivacyHardenedOffline,
    PrivacyHardenedOnline,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Permission {
    Block,
    ReadOnly,
    IsolatedChanges,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Grant {
    pub path: String,
    pub permission: Permission,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DesiredPolicy {
    pub schema: u32,
    pub preset: Preset,
    pub grants: Vec<Grant>,
}
impl Default for DesiredPolicy {
    fn default() -> Self {
        Self {
            schema: 1,
            preset: Preset::StandardOffline,
            grants: vec![],
        }
    }
}
#[derive(Debug, Clone)]
pub struct Mandatory {
    pub root: String,
    pub metadata: String,
    pub code: String,
    pub siblings: Vec<String>,
    pub marker: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompiledPolicy {
    pub family: String,
    pub section: Section,
    pub desired_fingerprint: String,
    pub offline: bool,
    pub read_only_view_change: bool,
}

/// Lexical grammar precedes independent Windows handle/alias validation.
/// No expansion, selectors, UNC, wildcards, device names, streams or normalization.
pub fn literal_path(path: &str) -> PolicyResult<String> {
    if path.len() < 4 || path.encode_utf16().count() > 240
        || !path.as_bytes()[0].is_ascii_alphabetic() || &path.as_bytes()[1..3] != b":\\"
        || path.chars().any(|c| c.is_control() || matches!(c, '/'|'%'|','|'*'|'?'|'"'|'<'|'>'|'|'|'\u{202a}'..='\u{202e}'|'\u{2066}'..='\u{2069}'))
    { return Err("PATH_GRAMMAR_UNSUPPORTED"); }
    for part in path[3..].split('\\') {
        let stem = part.split('.').next().unwrap_or("").to_ascii_uppercase();
        if part.is_empty()
            || part.ends_with([' ', '.'])
            || part.contains(':')
            || matches!(
                stem.as_str(),
                "CON" | "PRN" | "AUX" | "NUL" | "CONIN$" | "CONOUT$"
            )
            || (stem.len() == 4
                && (stem.starts_with("COM") || stem.starts_with("LPT"))
                && stem.as_bytes()[3].is_ascii_digit())
        {
            return Err("PATH_GRAMMAR_UNSUPPORTED");
        }
    }
    Ok(path.to_owned())
}
pub fn overlaps(a: &str, b: &str) -> bool {
    let a = a.to_lowercase();
    let b = b.to_lowercase();
    a == b
        || a.strip_prefix(&b).is_some_and(|s| s.starts_with('\\'))
        || b.strip_prefix(&a).is_some_and(|s| s.starts_with('\\'))
}
pub fn fingerprint<T: Serialize>(value: &T) -> String {
    format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(value).expect("serializable bounded policy"))
    )
}
pub fn compile(desired: &DesiredPolicy, mandatory: &Mandatory) -> PolicyResult<CompiledPolicy> {
    if desired.schema != 1 || desired.grants.len() > 24 {
        return Err("POLICY_SCHEMA_UNSUPPORTED");
    }
    if matches!(
        desired.preset,
        Preset::PrivacyHardenedOffline | Preset::PrivacyHardenedOnline
    ) {
        return Err("PAID_PRESET_UNVERIFIED");
    }
    let offline = desired.preset == Preset::StandardOffline;
    let mut section = Section::new();
    for (key, value) in [
        ("Enabled", "n"),
        ("DropAdminRights", "y"),
        ("BlockNetworkFiles", "y"),
        ("AllowNetworkAccess", if offline { "n" } else { "y" }),
        ("BlockLocalLoop", if offline { "y" } else { "n" }),
        ("PromptForInternetAccess", "n"),
        ("AutoRecover", "n"),
        ("AutoDelete", "n"),
        ("NeverDelete", "y"),
        ("UseFileImage", "n"),
    ] {
        section.insert(key.into(), vec![value.into()]);
    }
    section.insert("FileRootPath".into(), vec![literal_path(&mandatory.root)?]);
    section.insert("SecureRunOwner".into(), vec![mandatory.marker.clone()]);
    let mut protected = vec![
        literal_path(&mandatory.metadata)?,
        literal_path(&mandatory.code)?,
    ];
    for sibling in &mandatory.siblings {
        let sibling = literal_path(sibling)?;
        if overlaps(&sibling, &mandatory.root) {
            return Err("ROOT_OVERLAP");
        }
        protected.push(sibling);
    }
    let mut closed = vec![];
    for path in &protected {
        closed.push(path.clone());
        closed.push(format!("{path}\\*"));
    }
    let mut reads = vec![];
    for (i, grant) in desired.grants.iter().enumerate() {
        let path = literal_path(&grant.path)?;
        if protected
            .iter()
            .chain(std::iter::once(&mandatory.root))
            .any(|p| overlaps(p, &path))
        {
            return Err("MANDATORY_POLICY_OVERLAP");
        }
        if desired.grants[..i].iter().any(|g| overlaps(&g.path, &path)) {
            return Err("PATH_RULE_INTERACTION_UNSUPPORTED");
        }
        match grant.permission {
            Permission::Block => {
                closed.push(path.clone());
                closed.push(format!("{path}\\*"));
            }
            Permission::ReadOnly => {
                reads.push(path.clone());
                reads.push(format!("{path}\\*"));
            }
            Permission::IsolatedChanges => {}
        }
    }
    section.insert("ClosedFilePath".into(), closed);
    if !reads.is_empty() {
        section.insert("ReadFilePath".into(), reads);
    }
    // Host brokers are distinct from sockets: block RPC endpoints in offline only.
    if offline {
        section.insert(
            "ClosedIpcPath".into(),
            vec![
                "\\RPC Control\\DNSResolver".into(),
                "\\RPC Control\\LRPC*".into(),
                "\\RPC Control\\RasmanRpc".into(),
                "\\RPC Control\\dhcpcsvc*".into(),
            ],
        );
    }
    Ok(CompiledPolicy {
        family: FAMILY.into(),
        desired_fingerprint: fingerprint(&section),
        section,
        offline,
        read_only_view_change: desired
            .grants
            .iter()
            .any(|g| g.permission == Permission::ReadOnly),
    })
}

/// Inspect all keys, including global/template input. Unknown inheritance is an error.
/// No imported or implicit template belongs to this constrained family.
pub fn validate_inheritance(global: &Section, templates: &[String]) -> PolicyResult<()> {
    if !templates.is_empty() {
        return Err("INHERITED_TEMPLATE_UNAPPROVED");
    }
    for (key, values) in global {
        match key.to_ascii_lowercase().as_str() {
            "networkenablewfp" | "editadminonly" | "filerootpath" | "keyrootpath"
            | "ipcrootpath" | "boxgroup" | "configlevel" | "msg1321" => {}
            "editpassword" => return Err("PASSWORD_PROTECTED_CONFIGURATION"),
            _ if values.is_empty() => {}
            _ => return Err("GLOBAL_SETTING_UNREVIEWED"),
        }
    }
    Ok(())
}
pub fn verify_readback(
    compiled: &CompiledPolicy,
    raw: &Section,
    effective: &Section,
    global: &Section,
) -> PolicyResult<String> {
    if raw != &compiled.section {
        return Err("CONFIGURATION_CONFLICT");
    }
    for (key, wanted) in &compiled.section {
        let observed = effective.get(key);
        let matches = if matches!(
            key.as_str(),
            "ClosedFilePath" | "ReadFilePath" | "ClosedIpcPath"
        ) {
            observed == Some(wanted)
        } else {
            observed.and_then(|v| v.first()) == wanted.first()
        };
        if !matches {
            return Err(match key.as_str() {
                "FileRootPath" => "EFFECTIVE_ROOT_MISMATCH",
                "ClosedFilePath" => "EFFECTIVE_FILE_DENIAL_MISMATCH",
                "ClosedIpcPath" => "EFFECTIVE_IPC_DENIAL_MISMATCH",
                "DropAdminRights" => "EFFECTIVE_TOKEN_MISMATCH",
                "AllowNetworkAccess" => "EFFECTIVE_NETWORK_MISMATCH",
                "Enabled" => "EFFECTIVE_FENCE_MISMATCH",
                _ => "EFFECTIVE_POLICY_MISMATCH",
            });
        }
    }
    if compiled.offline && global.get("NetworkEnableWFP") != Some(&vec!["y".into()]) {
        return Err("WFP_PREREQUISITE_MISSING");
    }
    Ok(fingerprint(&(FAMILY, raw, effective, global)))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn mandatory() -> Mandatory {
        Mandatory {
            root: "C:\\State\\boxes\\a".into(),
            metadata: "C:\\State\\metadata".into(),
            code: "C:\\Program Files\\SecureRun".into(),
            siblings: vec!["C:\\State\\boxes\\b".into()],
            marker: "owned".into(),
        }
    }
    #[test]
    fn offline_and_online_keep_mandatory_controls() {
        for preset in [Preset::StandardOffline, Preset::StandardOnline] {
            let p = compile(
                &DesiredPolicy {
                    preset,
                    ..Default::default()
                },
                &mandatory(),
            )
            .unwrap();
            assert_eq!(p.section["BlockNetworkFiles"], ["y"]);
            assert_eq!(p.section["Enabled"], ["n"]);
            assert!(p.section["ClosedFilePath"].contains(&"C:\\State\\boxes\\b\\*".into()));
        }
    }
    #[test]
    fn injection_alias_and_namespace_grammar_rejected() {
        for p in [
            "\\\\host\\share",
            "C:\\a%TEMP%",
            "C:\\a,b",
            "C:\\a\nEnabled=y",
            "C:\\a*",
            "C:\\..\\x",
            "C:\\file:ads",
            "C:\\NUL.txt",
            "C:\\a.",
            "C:\\a\\",
            "C:/a",
        ] {
            assert!(literal_path(p).is_err(), "{p}");
        }
    }
    #[test]
    fn grants_cannot_weaken_mandatory_or_create_ambiguous_interactions() {
        for path in [
            "C:\\State",
            "C:\\State\\boxes\\b\\child",
            "c:\\program files\\securerun",
            "C:\\State\\boxes\\a",
        ] {
            assert_eq!(
                compile(
                    &DesiredPolicy {
                        grants: vec![Grant {
                            path: path.into(),
                            permission: Permission::ReadOnly
                        }],
                        ..Default::default()
                    },
                    &mandatory()
                )
                .unwrap_err(),
                "MANDATORY_POLICY_OVERLAP"
            );
        }
        let p = DesiredPolicy {
            grants: vec![
                Grant {
                    path: "C:\\Input".into(),
                    permission: Permission::ReadOnly,
                },
                Grant {
                    path: "C:\\Input\\a".into(),
                    permission: Permission::Block,
                },
            ],
            ..Default::default()
        };
        assert!(compile(&p, &mandatory()).is_err());
    }
    #[test]
    fn path_specific_supported_grants_keep_family_change_fingerprint() {
        let a = compile(&DesiredPolicy::default(), &mandatory()).unwrap();
        let b = compile(
            &DesiredPolicy {
                grants: vec![Grant {
                    path: "C:\\Input".into(),
                    permission: Permission::ReadOnly,
                }],
                ..Default::default()
            },
            &mandatory(),
        )
        .unwrap();
        assert_eq!(a.family, b.family);
        assert_ne!(a.desired_fingerprint, b.desired_fingerprint);
        assert!(b.read_only_view_change);
    }
    #[test]
    fn entitlement_templates_and_unknown_globals_fail_closed() {
        assert!(
            compile(
                &DesiredPolicy {
                    preset: Preset::PrivacyHardenedOffline,
                    ..Default::default()
                },
                &mandatory()
            )
            .is_err()
        );
        assert!(validate_inheritance(&Section::new(), &["Unsafe".into()]).is_err());
        for k in [
            "OpenFilePath",
            "OnBoxDelete",
            "NoSecurityIsolation",
            "EditPassword",
        ] {
            assert!(
                validate_inheritance(&Section::from([(k.into(), vec!["x".into()])]), &[]).is_err()
            );
        }
    }
    #[test]
    fn readback_is_not_an_enforcement_oracle_or_ignore_duplicate_order() {
        let p = compile(&DesiredPolicy::default(), &mandatory()).unwrap();
        let global = Section::from([("NetworkEnableWFP".into(), vec!["y".into()])]);
        verify_readback(&p, &p.section, &p.section, &global).unwrap();
        let mut changed = p.section.clone();
        changed.get_mut("ClosedFilePath").unwrap().reverse();
        assert!(verify_readback(&p, &changed, &changed, &global).is_err());
        assert_eq!(
            verify_readback(&p, &p.section, &p.section, &Section::new()).unwrap_err(),
            "WFP_PREREQUISITE_MISSING"
        );
    }
}
