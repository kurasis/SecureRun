# P02 Sandboxie feasibility

P02 is DONE for representative feasibility on the owner-selected Windows Server
2025 x64 and Windows 11 ARM64 laboratories. Every mandatory adapter operation has
a tested viable route; see the [operation map](OPERATION_MAP.md). This is a lab-only
spike, with no production UI command or user-target launcher.

Candidate: original Plus 1.18.6 / core 5.73.6 / ABI 0x57230, pinned source
cdba7096240b93d79c5373aa81a75a1c5c71b883. Final tested manager source 0cf59a67041364209d6f42ac393db3ecaa73e044;
[Actions run 38557903464](https://github.com/kurasis/SecureRun/actions/runs/38557903464).
Server: 49 passed; ARM: 62 passed. Both: zero failed/blocked/not-run, two explicit NA.
The [manifest](evidence/p02/manifest.json) binds raw Windows JSON bytes and runtime
source hashes to this exact checkout. Earlier BLOCKED evidence remains historical.

## Trust, scope and bridge choice

The native installer is checked for exact size, SHA256 and Windows Authenticode
before installation. Installed components and DLL dependencies match a separately
extracted authenticated payload; individual signature states are retained. Native
SbieSvc/driver health, installed PE architectures, version and ABI are observed.
No TLS, certificate, driver signing, boot, VBS or Defender bypass is used.

Documented CLI routes were source-reviewed first. A narrow native DLL adapter is
necessary for reliable configuration/readback, process identity and physical/logical
file mapping. The spike uses original exports and independently written Windows
interop, without copying SandMan. Production should isolate version-sensitive FFI
in a bounded worker process; a timeout after acceptance is Unknown and requires
reconciliation, never automatic replay. Fragile native calls need process-level
timeouts rather than assuming an in-process cancellation can interrupt them.

The WFP engine prerequisite is enabled only in a newly installed disposable engine.
A production manager must observe it and report a missing prerequisite instead of
silently changing an existing global configuration. The source-backed kernel WFP
path, observed flags and actual unboxed/online positive controls accompany offline
loopback TCP/UDP IPv4/IPv6 denials. File writes remain virtualized and selected host
secrets, metadata and same-user sibling contents are denied with positive controls.

## Configuration, ownership and provisioning

Original SbieDll_UpdateConf supplies service authorization, explicit NTSTATUS and
raw readback. Duplicate list entries use append; effective inherited automation is
read separately. DeleteCommand, OnBoxDelete, OnBoxTerminate and OnFileRecovery
consumers are source-reviewed and rejected before dispatch. Native password IPC
returns C000006A without mutation for missing/wrong synthetic passwords; the correct
password permits a verified change and restoration. Passwords never enter argv,
environment, JSON or persisted profiles. Admin-only/protected engine configuration
remains authoritative; ordinary-user success in the tested default installation is
not permission to bypass restrictions in other installations.

A real standard-user worker creates its own definition and private local NTFS root,
applies the DACL and controls its own targets without an elevated product helper.
PendingRoot creation retains non-reparse ancestor handles without delete sharing,
uses NtCreateFile FILE_CREATE relative to the held parent, and applies the explicit
owner/SYSTEM/Administrators DACL before releasing the new root handle. Preexisting
objects are never adopted. The identity comes from that created object.

An actual substituted parent junction is rejected before creation outside the
enrolled location. Rename while a root lease is held fails; an unexpected replacement
identity is rejected, then the original synthetic object is restored without
rebinding. A forged Windows-root configuration value is rejected before mutation.
Second-account public reads succeed while root and metadata reads receive access
denied. These are concrete ownership/provisioning feasibility checks; durable
generation records, journals and production enrollment belong to P05/P08.

## Launch, enumeration, stop and context

The original service creates the target suspended, binds it to the selected box
before resume and refuses an absent box. Benign parent, child and grandchild
processes query actual membership before canary operations. Real x86/x64/ARM64
target PEs are verified with explicit MSVC/library targets, /W4 /WX and PE-machine
checks. Fixed arguments cover spaces, quotes, trailing backslash, Unicode and an
option-like value; evidence records equality, not raw arguments. Host CWD is
protected and separate from target CWD. Dispatch workers remove CI credentials
from their environments because original RunSandboxed inherits the caller environment.

All-session enumeration uses TRUE and an explicit 1024-entry bound with count
observations. Actual capacity-one SUCCESS truncation is rejected and never
authorizes Idle. The standard user's same SID is observed concurrently in actual
Windows sessions 0 and 2, with box/SID validation for every reported process and
current-session exclusion confirmed. A separate SYSTEM-owner fixture also proves
foreign-session/owner visibility. This does not claim two RDP desktops or UI tests.

The hosted image denies synthetic-account batch logon (C000015B). The lab leaves
that policy unchanged. A disposable SYSTEM task receives synthetic logon data over
a local first-instance pipe restricted to SYSTEM/Administrators. Its live peer
token SID, unboxed engine context and protected fixed executable path are checked
through OS APIs before data is sent. It uses an allowed interactive logon token
to create only the fixed unboxed standard-user facade in session zero. That
standard facade requests the boxed target through the original service. The task
is a test harness, not a privileged product helper or arbitrary launch API.

Stop retains the actual process handle, checks engine box/current owner/creation
FILETIME against that OS object, rejects critical processes, terminates only the
held object and waits/re-enumerates. Tests exercise the same dispatch function
against a live wrong-box object (rejected and still alive) and an already naturally
exited object (no redispatch). Standard-user stop completes across both sessions.
No numeric-PID fallback or broad privileged termination is used. Incomplete
enumeration, inaccessible objects or unreconciled churn remain Unknown.

Native and actual managed bridge instances refuse controls when boxed; healthy
pinned self-query C000000B is the sole UNBOXED result. Unknown self-context refuses
mutation. Future sibling storage is deferred while affected boxes run, deny rules
are read back after stop and before materialization, and direct/junction alias
access is denied. Production entrypoints must repeat these checks.

## Mapping, cleanup and definition removal

The original boxed GetHandlePath/TranslateNtToDosPath route establishes private
workspace physical mapping and the one-byte boxed flag. A fixed benign copied EXE
is hash-checked. Direct service creation cannot see an absent-host logical EXE;
the tested source-backed route first boxes original trusted Start.exe, whose
hooked view launches the logical EXE. Actual image membership is observed.
Physical boxed storage is never executed as a host EXE.

Start.exe delete_sandbox phase2 scans pending roots of all boxes and may consume
another box's DeleteCommand, so it is rejected. The selected narrow original
installed QSbieAPI export is NtIo_DeleteFolderRecursively with OBJECT_ATTRIBUTES
and a cdecl Boolean callback. The exact export and dependency inventory are
observed on both native architectures. No Qt object ABI is passed.

Cleanup first requires trustworthy owner/root identity, zero complete all-session
membership and absence of unsafe automation/images. It sets Enabled=n through
original IPC and reads it back; the driver checks Conf_IsBoxEnabled on external
start. An actual direct original-engine client request is rejected under this
fence. Failure leaves launch fenced and requires reconciliation.

The storage seal retains every ancestor and root namespace lease, rejects reparse
points and multiple hard links, captures bounded descendant identities and DACLs,
then denies creation, content/attribute writes and DACL/ownership changes for the
owner. OWNER RIGHTS prevents the owner's implicit WRITE_DAC from undoing the seal.
Existing authorized handles prepare only verified objects' DOS attributes and
retain root restoration authority; ownership and OS privileges are unchanged.
A second full snapshot verifies identities before releasing descendant handles.

Actual pre-dispatch attacks against the sealed state test new-file creation,
fresh WRITE_DAC and FILE_WRITE_ATTRIBUTES-only junction creation. All are denied;
the same sealed state persists throughout native dispatch. Existing synthetic
junctions and multiple hard links are rejected before native dispatch, with an
outside canary unchanged. These checks are explicitly pre-dispatch boundary
tests, not a claim that a concurrent stress harness ran inside the native call.
Stopped boxed attackers have no live handles; compromised unboxed same-user
processes and administrators are outside the specification's threat model.

The original routine receives the retained root as RootDirectory and an empty NT
relative name. Root delete sharing is deliberately excluded, so final unlink
returns the observed C0000043 while contents are empty and the exact root identity
remains. Only zero or that exact status with verified postconditions is accepted.
The root DACL is restored through its preauthorized handle; surviving descendants
are restored only after identity checks. No generic recursive deleter, arbitrary
DeleteCommand or permissive success-code range is substituted.

Both elevated and ordinary-user fixtures pass cleanup. Used-definition removal
requires the successful native cleanup record, unchanged enrolled identity, empty
contents, disabled launch and zero membership; original '*' section deletion is
read back as absent. The known empty retained root is preserved for future journaled
reconciliation, never recursively removed or silently rebound.

## Diagnostics, entitlement and licensing

readDiagnostics has a tested redacted manager-owned health/operation route:
original version, ABI, flags and self-context observations are labeled
MANAGER_OBSERVATION and retain no arguments/environment. Original engine access
events remain unavailable: GetMessage returns C0000022 and Session_Api_Leader
requires an upstream-authorized signed caller. This stream is optional; it is
explicit NA, with no synthesized events, leader replacement or signature bypass.

The original certificate-state query is proven observation only. Paid security,
privacy, encryption and proxy profiles remain disabled without valid entitlement
and enforcement evidence. Their optional availability is not required for the
tested baseline routes.

Core/Classic is GPLv3. The original QSbieAPI/MiscHelpers/Qt runtime dependency is
an explicit bridge exception: narrow cleanup is unavailable in the tested core
CLI route. QSbieAPI declares LGPL 2.1 or later; dynamic loading does not eliminate
license obligations. This phase distributes no engine binary or copied source.
Before distribution, P11 must select the manager license, review combined-work
terms, preserve component notices, satisfy source/offer and user replacement/
relinking requirements, and retest any replaced runtime against the trust/ABI pin.
Commercial permission or redistribution rights are not inferred.
Pinned [license](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/LICENSE.Plus)
and [QSbieAPI header](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/Sandboxie/SandBox.h)
anchor this assessment.

## Handoff boundaries

P02's required representative smoke variants have viable tested routes; there is
no unresolved mandatory P02 operation. Full production tests remain NOT_STARTED:
DNS/LAN/SMB/broker/raw/inbound coverage, arbitrary target/parser matrices, transfer
handle/stream/collision rules, cancellation and recovery, concurrent stress,
production helper entrypoints if introduced, and release security tuples. These
are repeated in their owning P05–P12 phases and cannot be claimed from this spike.
Windows Server x64 and ARM emulation do not prove Windows 11 x64 kernel support.
Next eligible phase is P03; it is not started automatically by this request.
