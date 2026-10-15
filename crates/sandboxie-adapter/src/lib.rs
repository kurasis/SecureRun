//! Trusted observation and constrained journaled policy provisioning.
pub mod control;
pub mod policy;
pub mod provision;
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};

pub const PROTOCOL: u32 = 1;
pub const RESPONSE_LIMIT: usize = 2 * 1024 * 1024;
pub const MAX_PROCESSES: usize = 1024;
pub const MAX_BOXES: usize = 128;
pub const FRESHNESS: Duration = Duration::from_secs(15);
pub const COMPATIBILITY: &str = include_str!("../compatibility-v1.json");

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Context {
    Unboxed,
    Boxed,
    Unknown,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Availability {
    Available,
    Unavailable,
    Unknown,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Capability {
    pub name: String,
    pub availability: Availability,
    pub reason: String,
    pub provenance: String,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProcessIdentity {
    pub pid: u32,
    #[serde(with = "decimal_u64")]
    pub creation_time: u64,
    pub owner_sid: String,
    pub session: u32,
    pub box_name: String,
}
mod decimal_u64 {
    use serde::{Deserialize, Deserializer, Serializer};
    pub fn serialize<S: Serializer>(value: &u64, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&value.to_string())
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<u64, D::Error> {
        let value = String::deserialize(deserializer)?;
        if value.is_empty() || !value.bytes().all(|c| c.is_ascii_digit()) {
            return Err(serde::de::Error::custom("Invalid identity timestamp"));
        }
        value.parse().map_err(serde::de::Error::custom)
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConfigurationEntry {
    pub key: String,
    pub raw: Vec<String>,
    pub effective: Vec<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RootObservation {
    pub path: Option<String>,
    pub identity: Option<String>,
    pub reason: String,
    pub scope: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BoxObservation {
    pub name: String,
    pub owned: bool,
    pub read_only: bool,
    pub activity: String,
    pub complete: bool,
    pub reason: String,
    pub processes: Vec<ProcessIdentity>,
    pub root: RootObservation,
    pub configuration: Vec<ConfigurationEntry>,
    pub configuration_fingerprint: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Observation {
    pub protocol: u32,
    pub observed_unix_ms: u64,
    pub trust: String,
    pub reason: String,
    pub manager_context: Context,
    pub bridge_context: Context,
    pub manager_pid: u32,
    pub manager_birth: u64,
    pub core_version: Option<String>,
    pub abi: Option<u32>,
    pub architecture: String,
    pub service_running: bool,
    pub driver_running: bool,
    pub service_identity: Option<String>,
    pub service_identity_complete: bool,
    pub service_identity_reason: String,
    pub installation_identity: Option<String>,
    pub restart_required: bool,
    pub resume_epoch_ms: u64,
    pub driver_flags: Option<u32>,
    pub certificate_state: Option<u32>,
    pub enumeration_complete: bool,
    pub boxes: Vec<BoxObservation>,
    pub capabilities: Vec<Capability>,
    pub release_evidence: String,
    pub production_launch_available: bool,
}
impl Observation {
    pub fn failure(reason: &str) -> Self {
        Self {
            protocol: PROTOCOL,
            observed_unix_ms: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as u64,
            trust: "UNKNOWN".into(),
            reason: reason.into(),
            manager_context: Context::Unknown,
            bridge_context: Context::Unknown,
            manager_pid: 0,
            manager_birth: 0,
            core_version: None,
            abi: None,
            architecture: std::env::consts::ARCH.into(),
            service_running: false,
            driver_running: false,
            service_identity: None,
            service_identity_complete: false,
            service_identity_reason: "NOT_OBSERVED".into(),
            installation_identity: None,
            restart_required: false,
            resume_epoch_ms: 0,
            driver_flags: None,
            certificate_state: None,
            enumeration_complete: false,
            boxes: vec![],
            capabilities: vec![
                Capability {
                    name: "read_only_observation".into(),
                    availability: Availability::Unknown,
                    reason: reason.into(),
                    provenance: "NO_FRESH_TRUSTED_OBSERVATION".into(),
                },
                Capability {
                    name: "paid_profiles".into(),
                    availability: Availability::Unknown,
                    reason: "ENTITLEMENT_UNKNOWN".into(),
                    provenance: "NO_CERTIFICATE_CONTENT_INSPECTION".into(),
                },
                Capability {
                    name: "production_launch".into(),
                    availability: Availability::Unavailable,
                    reason: "OBSERVATION_ONLY".into(),
                    provenance: "PHASE_BOUNDARY".into(),
                },
            ],
            release_evidence: "PINNED_ROUTE_EVIDENCE_ONLY".into(),
            production_launch_available: false,
        }
    }
    pub fn context_safe(&self) -> bool {
        self.trust == "VERIFIED"
            && self.manager_context == Context::Unboxed
            && self.bridge_context == Context::Unboxed
            && self.service_running
            && self.driver_running
            && self.service_identity_complete
            && self.reason == "OBSERVED"
    }
}

pub fn valid_box(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 38
        && name.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
}
pub fn enumeration_complete(before: usize, returned: usize, after: usize, capacity: usize) -> bool {
    capacity <= MAX_PROCESSES && returned < capacity && before == returned && after == returned
}
pub fn parse_response(data: &[u8], pid: u32, birth: u64) -> Result<Observation, &'static str> {
    if data.is_empty() || data.len() > RESPONSE_LIMIT {
        return Err("BRIDGE_RESPONSE_BOUND");
    }
    let value: Observation = serde_json::from_slice(data).map_err(|_| "BRIDGE_PROTOCOL_INVALID")?;
    if value.protocol != PROTOCOL
        || value.production_launch_available
        || value.boxes.len() > MAX_BOXES
        || (value.manager_pid != pid || value.manager_birth != birth)
    {
        return Err("BRIDGE_IDENTITY_INVALID");
    }
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    if now.saturating_sub(value.observed_unix_ms) > FRESHNESS.as_millis() as u64
        || value.observed_unix_ms > now.saturating_add(1000)
    {
        return Err("BRIDGE_OBSERVATION_EXPIRED");
    }
    for b in &value.boxes {
        if !valid_box(&b.name)
            || b.owned
            || !b.read_only
            || b.processes.len() >= MAX_PROCESSES
            || (!b.complete && b.activity == "IDLE")
            || b.processes
                .iter()
                .any(|p| p.box_name != b.name || p.pid == 0 || p.creation_time == 0)
        {
            return Err("BRIDGE_OBSERVATION_INVALID");
        }
    }
    if (value.manager_context != Context::Unboxed || value.bridge_context != Context::Unboxed)
        && !value.boxes.is_empty()
    {
        return Err("BRIDGE_CONTEXT_INVALID");
    }
    Ok(value)
}

#[derive(Debug, Clone, Serialize)]
pub struct HealthView {
    pub generation: u64,
    pub sequence: u64,
    pub fresh: bool,
    pub control_plane_safe: bool,
    pub observation: Observation,
}
pub struct Health {
    generation: u64,
    sequence: u64,
    ticket: u64,
    current: Observation,
    received: Option<Instant>,
}
impl Default for Health {
    fn default() -> Self {
        Self {
            generation: 1,
            sequence: 0,
            ticket: 0,
            current: Observation::failure("NOT_OBSERVED"),
            received: None,
        }
    }
}
impl Health {
    pub fn expire(&mut self, now: Instant) -> bool {
        if self
            .received
            .is_some_and(|t| now.saturating_duration_since(t) >= FRESHNESS)
        {
            self.invalidate("OBSERVATION_EXPIRED");
            true
        } else {
            false
        }
    }
    pub fn begin(&mut self, now: Instant) -> u64 {
        self.expire(now);
        self.ticket += 1;
        self.ticket
    }
    pub fn invalidate(&mut self, reason: &str) {
        self.generation += 1;
        self.sequence += 1;
        self.ticket += 1;
        self.current = Observation::failure(reason);
        self.received = None;
    }
    pub fn accept(&mut self, ticket: u64, mut report: Observation, now: Instant) -> bool {
        if ticket != self.ticket {
            return false;
        }
        if self.received.is_some()
            && (self.current.service_identity != report.service_identity
                || self.current.installation_identity != report.installation_identity
                || self
                    .current
                    .resume_epoch_ms
                    .abs_diff(report.resume_epoch_ms)
                    > 1000
                || self.current.context_safe() != report.context_safe())
        {
            self.generation += 1;
        }
        for b in &mut report.boxes {
            if let Some(old) = self.current.boxes.iter().find(|p| p.name == b.name)
                && old.root.identity.is_some()
                && old.root.identity != b.root.identity
            {
                b.complete = false;
                b.activity = "UNKNOWN".into();
                b.reason = "ROOT_IDENTITY_CHANGED".into();
            }
        }
        self.sequence += 1;
        self.current = report;
        self.received = Some(now);
        true
    }
    pub fn view(&self, now: Instant) -> HealthView {
        let fresh = self
            .received
            .is_some_and(|t| now.saturating_duration_since(t) < FRESHNESS);
        let mut observation = self.current.clone();
        if !fresh {
            observation.reason = "OBSERVATION_EXPIRED".into();
            observation.enumeration_complete = false;
            for b in &mut observation.boxes {
                b.complete = false;
                b.activity = "UNKNOWN".into();
                b.reason = "OBSERVATION_EXPIRED".into();
            }
        }
        HealthView {
            generation: self.generation,
            sequence: self.sequence,
            fresh,
            control_plane_safe: fresh && observation.context_safe(),
            observation,
        }
    }
}

#[cfg(windows)]
pub mod windows;

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn success_truncation_is_unknown() {
        assert!(!enumeration_complete(2, 1, 2, 1));
        assert!(!enumeration_complete(1024, 1024, 1024, 1024));
        assert!(!enumeration_complete(0, 0, 1, 1024));
        assert!(enumeration_complete(0, 0, 0, 1024));
    }
    #[test]
    fn invalid_namespace_is_rejected() {
        for n in ["", "../box", "a\n", "Global Settings", "a%"] {
            assert!(!valid_box(n));
        }
        assert!(valid_box("DefaultBox"));
    }
    #[test]
    fn stale_worker_and_expired_snapshot_cannot_restore_health() {
        let t = Instant::now();
        let mut h = Health::default();
        let old = h.begin(t);
        let latest = h.begin(t);
        assert!(!h.accept(old, Observation::failure("OLD"), t));
        assert!(h.accept(latest, Observation::failure("CURRENT"), t));
        assert!(!h.view(t + FRESHNESS).fresh);
        h.invalidate("RESUME");
        assert!(!h.accept(latest, Observation::failure("OLD"), t));
    }
    #[test]
    fn unknown_or_boxed_context_never_allows_controls() {
        let mut o = Observation::failure("OBSERVED");
        o.trust = "VERIFIED".into();
        o.service_running = true;
        o.driver_running = true;
        o.service_identity_complete = true;
        for c in [Context::Unknown, Context::Boxed] {
            o.manager_context = c;
            o.bridge_context = Context::Unboxed;
            assert!(!o.context_safe());
        }
        o.manager_context = Context::Unboxed;
        assert!(o.context_safe());
    }
    #[test]
    fn malformed_oversized_or_wrong_process_response_is_rejected() {
        assert!(parse_response(b"{}", 1, 2).is_err());
        assert!(parse_response(&vec![b' '; RESPONSE_LIMIT + 1], 1, 2).is_err());
        let o = Observation::failure("MISSING");
        assert_eq!(
            parse_response(&serde_json::to_vec(&o).unwrap(), 1, 2).unwrap_err(),
            "BRIDGE_IDENTITY_INVALID"
        );
    }
    #[test]
    fn compatibility_does_not_claim_policy_acceptance() {
        let m: serde_json::Value = serde_json::from_str(COMPATIBILITY).unwrap();
        assert_eq!(m["schema_version"], 1);
        assert_eq!(m["release"]["production_policy_acceptance"], false);
        assert_eq!(m["targets"].as_array().unwrap().len(), 2);
    }
    #[test]
    fn restart_changes_generation_and_cached_route_evidence_survives() {
        let t = Instant::now();
        let mut h = Health::default();
        let mut o = Observation::failure("OBSERVED");
        o.service_identity = Some("A".into());
        let a = h.begin(t);
        h.accept(a, o.clone(), t);
        let g = h.view(t).generation;
        o.service_identity = Some("B".into());
        let b = h.begin(t);
        h.accept(b, o, t);
        assert!(h.view(t).generation > g);
        assert_eq!(
            h.view(t).observation.release_evidence,
            "PINNED_ROUTE_EVIDENCE_ONLY"
        );
    }
    #[test]
    fn delayed_native_observation_is_expired_before_acceptance() {
        let mut o = Observation::failure("OBSERVED");
        o.manager_pid = 1;
        o.manager_birth = 2;
        o.observed_unix_ms = o.observed_unix_ms.saturating_sub(16000);
        assert_eq!(
            parse_response(&serde_json::to_vec(&o).unwrap(), 1, 2).unwrap_err(),
            "BRIDGE_OBSERVATION_EXPIRED"
        );
    }
    #[test]
    fn replaced_root_and_resume_invalidate_observation_without_adoption() {
        let now = Instant::now();
        let mut h = Health::default();
        let mut o = Observation::failure("OBSERVED");
        o.boxes.push(BoxObservation {
            name: "UnownedBox".into(),
            owned: false,
            read_only: true,
            activity: "IDLE".into(),
            complete: true,
            reason: "OBSERVED".into(),
            processes: vec![],
            root: RootObservation {
                path: None,
                identity: Some("original".into()),
                reason: "OBSERVED".into(),
                scope: "CURRENT_CALLER_ONLY".into(),
            },
            configuration: vec![],
            configuration_fingerprint: "fingerprint".into(),
        });
        let first = h.begin(now);
        h.accept(first, o.clone(), now);
        o.boxes[0].root.identity = Some("replacement".into());
        o.resume_epoch_ms = 2000;
        let old_generation = h.view(now).generation;
        let second = h.begin(now);
        h.accept(second, o, now);
        let view = h.view(now);
        assert!(view.generation > old_generation);
        assert_eq!(view.observation.boxes[0].activity, "UNKNOWN");
        assert!(!view.observation.boxes[0].complete);
        assert_eq!(view.observation.boxes[0].reason, "ROOT_IDENTITY_CHANGED");
    }
    #[test]
    fn filetime_identity_survives_json_beyond_javascript_integer_precision() {
        let p = ProcessIdentity {
            pid: 1,
            creation_time: 134_075_432_123_456_789,
            owner_sid: "S-1-5-21-SYNTHETIC".into(),
            session: 2,
            box_name: "Box".into(),
        };
        let json = serde_json::to_value(&p).unwrap();
        assert_eq!(json["creation_time"], "134075432123456789");
        assert_eq!(serde_json::from_value::<ProcessIdentity>(json).unwrap(), p);
    }
}
