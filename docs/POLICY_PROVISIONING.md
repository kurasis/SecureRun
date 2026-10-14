# Policy and provisioning contract

P05 implementation; native verification is in progress. This document describes
the implemented contract, not a claim of completed containment acceptance.

The engine remains authoritative. The manager accepts schema 1 Standard offline
and Standard online policies with at most 24 literal local path grants: Block,
Read only, or Isolated changes. Paid presets are unavailable without verified
entitlement. The renderer supplies one-use native-picker selections bound to an
operation, environment, revision and 60-second lifetime, rather than raw paths.
The backend rejects unsupported encodings, directives, streams, UNC paths,
wildcards, reparse points, DOS device aliases, case-sensitive directories and
overlapping grants. Native canonicalization and held objects supplement lexical
checks; an apparently harmless spelling is not sufficient authority.

Mandatory rules are generated separately from editable grants. They protect the
manager executable, metadata and every other owned root, retain administrator
token dropping, registry/file virtualization and AppContainer protections, block
network files, disable recovery/deletion automation, and keep definitions disabled
for production target launch. Standard reads ordinary nonexcluded host files.
Online also allows network access, including local resources, and can disclose
readable host information. Neither label promises privacy-grade isolation.

The compiler's family identifier identifies supported rules and probe behavior.
Its desired fingerprint includes every generated ordered setting. An applied
fingerprint additionally binds complete effective settings, raw global settings,
verified default inheritance and WFP state. Readback alone cannot establish
enforcement: an independent fresh diagnostic must also pass.

The pinned original SDK uses `SbieDll_UpdateConf` with a null password and
single-setting service IPC. Its API is not an atomic multi-key transaction. A
separate SQLite journal therefore commits intent, fencing, writing, readback,
PendingRoot, bound-root identity and verification stages with full synchronization.
Operation identifiers are permanently bound to their request signatures; retries
return the recorded outcome without redispatch. Revision or current-baseline
changes fail. A restart changes every incomplete operation to an inspect-only
conflict, with no valid fingerprint or enforcement status. Recovery never replays
effects automatically. Explicit repair binds the observed current fingerprint,
ownership marker, OS owner and existing root identity, and requires disclosure of
Read only view changes. External automation values are withheld from displayed
and persisted observations.

Names and roots derive from backend-generated UUIDs and the OS token's original
LocalAppData folder. Roots use fixed local NTFS storage with no reparse ancestry,
no overlap and an explicit protected DACL for the owner, SYSTEM and Administrators.
Relative `NtCreateFile(FILE_CREATE)` supplies that DACL at creation. An existing
directory is never adopted as a newly provisioned root. Volume/file identity is
bound in the journal before verification; substitution invalidates the binding.
These checks do not claim protection against a hostile administrator or kernel.

Sibling creation requires complete stopped observations across all sessions.
Every affected sibling is fenced, updated and independently verified before the
new root is materialized. The manager generates explicit future-root and descendant
denials, rather than assuming a parent namespace denial covers future children.
Any incomplete rollout prevents creation and remains visible for reconciliation.

Offline requires explicitly configured original-engine WFP, a running BFE service
and the pinned driver capability flag. The product does not enable WFP globally,
modify Windows firewall/BFE/security settings, accept hooks-only fallback or grant
SMB exceptions. Disposable Actions fixtures separately enable the documented
engine prerequisite in a fresh lab installation and record that distinction.

The original default template file and exact default template list are pinned to
upstream source. Raw section enumeration excludes template metadata; effective
enumeration includes reviewed inheritance. A hash of unexpanded inherited global
settings and explicit expanded multivalue tails detects unexpected defaults.
Original NT-to-DOS translation is used only for source-reviewed path-valued keys.
Unknown globals, user-selected templates, inherited lifecycle commands, password
protection and unreviewed overlays fail rather than being silently overwritten.

The compiler declares `ConfigLevel=10` before a new section gains `Enabled`. The
pinned original `CSandBox` constructor automatically migrates lower levels and
adds recovery/template settings; this explicit format version prevents that
migration from rewriting an already complete policy. It does not accept unknown
templates or import the original GUI's implementation.

Diagnostics use a different generated box and fresh root for every attempt.
The probe is a fixed protected paired executable, never a user target, and refuses
unboxed execution. SDK components, injected architecture libraries and templates
are signature/hash checked and leased before dispatch. The worker obtains parent
process birth, owner SID and both self/parent box context from the OS and original
driver. Credentials are removed from its environment before probe launch. A bounded
worker job, bounded input/output and held process receipt limit failures; an
unknown result blocks verification. The private journal records diagnostic scope
before effects; failed probes are fenced. Retained diagnostics have a quota of 64;
no generic recursive deletion is introduced ahead of the lifecycle phase.

Original RPC support can outlive the fixed probe. The private diagnostic stop
validates this worker's generated box, exact current section, marker and held
root identity, then checks held process birth, driver box SID/membership, actual
token owner and critical state before termination. The original service chooses
SYSTEM or a WTS session token, and the driver's token restriction can substitute
Anonymous Logon in the primary token. These support identities are separate from
the manager's original user and storage authority. Only the exact signed protected
original RpcSs and DcomLaunch images are accepted for such diagnostic companions;
driver box SID, held process birth and current membership must still match.
There is no caller-selected process stop or product Stop command in P05.
Stored verification binds the current manager/probe binaries and original engine;
updating code invalidates cached proof rather than retaining a Verified label.

Current probes check actual file and registry virtualization, explicit read/write
denials, metadata/sibling denials, ordinary host visibility and controlled IPv4/
IPv6 TCP/UDP handshakes with independent host server positive controls. Minimized
fresh listener tests also check unsolicited incoming TCP/UDP on both address
families. Raw ICMP uses a valid checksummed unique synthetic request and reply,
with independent host echo observations; a socket handle alone is not egress.
Unboxed raw controls explicitly distinguish ordinary-user denial from an
available transport. Minimized
probe results, verified receipts and numeric failed exit statuses contain no paths, arguments, SIDs,
environment variables or configuration passwords. The phase report must identify
remaining DNS/broker, SMB/mapped-drive, ICMP, alias and interruption coverage until
their actual production-path tests pass. User targets remain unavailable until
P06.

Source review is pinned to Sandboxie commit
`cdba7096240b93d79c5373aa81a75a1c5c71b883`:
[SDK dispatch](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/callsvc.c),
[configuration](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/config.c),
[templates](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/install/Templates.ini),
[driver flags](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/api_flags.h).
No SandMan implementation or engine binary is copied or bundled.
