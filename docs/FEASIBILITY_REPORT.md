# P02 Sandboxie feasibility report

Status: BLOCKED. Research and the disposable adapter spike are implemented;
the exit gate has not passed. No production launcher, UI command, privileged
helper, engine redistribution or accepted product security scenario exists.
The [operation map](OPERATION_MAP.md) gives exact pinned routes and contracts.
The [phase report](phases/P02_REPORT.md) identifies authoritative run evidence.

## Candidate and bridge decision

Use the separately installed original native Sandboxie core through a small,
version-pinned native worker boundary. The throwaway worker is C#/PowerShell plus
original C probes, independent of the future Rust/Tauri UI. It binds only observed
source-declared exports, uses protected DLL search and rejects BOXED/UNKNOWN
before controls. Production should keep the frontend ignorant of native pointers,
box names and command construction; P05 owns its typed adapter and bounded worker.
No CLI output parser is selected for config/process authority: SbieIni utility exit
codes do not prove mutations and Start's broad cleanup is unsuitable.

Both owner-selected labs run: Windows Server 2025 x64 with real x86/x64 targets,
and Windows 11 ARM64 with native ARM64 and emulated x86/x64 targets. A hosted
Server x64 kernel is not a Windows 11 x64 support claim. The original P01 ARM lab
adjustment remains recorded; adding Server does not waive Windows security gates.
A candidate support matrix exists in [ENGINE_MATRIX](ENGINE_MATRIX.md).

Final exact-code run: [38550922299](https://github.com/kurasis/SecureRun/actions/runs/38550922299),
commit `2eb5fd0bb6e93921fd3ffdd415990633a79aabc0`. Server: 43 passed, zero failed,
two blocked and one helper NA; ARM: 56 passed, zero failed, two blocked and one
helper NA. The remaining protocol/race gate portions are not included as passing
smoke cases. All original JSON and hashes are retained in the manifest.

The full installer is checksum/size/signature verified before installation.
Installed core and DLL dependencies match a separately extracted authenticated
payload byte-for-byte; individual component Authenticode states are retained.
Unsigned distribution libraries are not described as signed. The original native
driver and SbieSvc must answer successfully under the unchanged hosted security
configuration. No test signing, signature bypass, reboot, Defender change or
RefreshBuild is used. The global engine setting NetworkEnableWFP=y is enabled
only in this fresh disposable installation; the OS security settings are unchanged.
Production must report an unmet global prerequisite and require a reviewed engine
configuration change rather than silently changing an existing installation.

## Operations demonstrated

Fresh unique boxes are configured through original service IPC with explicit
NTSTATUS and raw readback. Effective inherited automation is inspected separately
from raw local values. Generated root paths are queried by the driver, not inferred
from a storage convention. A fixed trusted host initializer binds fresh NTFS roots,
explicit owner/SYSTEM/Administrators DACLs and filesystem identity before targets.
A second synthetic standard account has a successful public-file read and denied
root/manager-metadata reads. Per-user ACLs are supplemented by tested engine read
denials between same-user boxes. Future storage is materialized only after affected
boxes stop and deny rules read back; direct and junction aliases are probed.

The service creates a suspended target, binds it to the box before resume, and
fails when the box does not exist. Benign targets query their actual membership
before canary operations; parents, children and grandchildren confirm the chosen
box. Fixed arguments include spaces, embedded quotes, trailing backslash, Unicode
and an option-looking value; only equality booleans are recorded. The original
RunSandboxed API copies its caller environment, so the lab removes CI credentials
before dispatch. Host CWD stays protected; target CWD is a separate parameter.

Kernel WFP source and observed driver flags establish the mechanism, while real
unboxed/online positive controls and offline TCP/UDP IPv4/IPv6 loopback results
establish representative enforcement. No external payloads or Internet endpoints
are used. DNS, brokered requests, LAN, SMB, raw/inbound paths and hostile application
escape attempts are not covered by this smoke and remain required release tests.

Enumeration requests all sessions with an explicit bounded capacity. An actual
capacity-one response returns SUCCESS with one PID even while count-only queries
observe three: the adapter rejects it, rather than authorizing Idle/cleanup.
A SYSTEM scheduled task creates a real session-zero boxed process; enumeration
sees that different owner/session while current-session enumeration excludes it.
This is partial multi-session evidence, not the same-SID interactive T36 variant.

Stop opens a retained process handle, compares engine box/SID/FILETIME with that
actual object immediately before dispatch, rejects critical processes, terminates
only the handle and waits/re-enumerates. The original engine's numeric-PID kill
fallback is not used. Transient handle/wait failures remain Unknown/blocked;
a previous positive snapshot never authorizes broad termination or cleanup.

A synthetic engine configuration password uses the source-defined salted SHA256
format. Missing/wrong password returns C000006A and leaves the key unchanged;
correct password permits a read-back mutation through original IPC, then the
synthetic protection is restored. Passwords/hashes never enter evidence, argv or
environments. Actual managed and native boxed guard probes refuse control work;
there is no self-relaunch or host-escape action.

## Storage mapping and cleanup

Boxed GetHandlePath returns a physical copy path and one-byte boxed indicator.
The prototype translates it with the original API, rejects unsafe ancestry/links,
and compares a fixed benign copied executable with the original. Direct native
service launch of a host-absent logical EXE fails: the service creates processes
outside the virtualized view. The source-backed alternative starts the original
trusted Start.exe inside the chosen box, then launches the logical EXE through its
hooked boxed view. That route is tested explicitly; physical storage is never
executed as a host EXE. Safe production transfers, retained ancestry handles,
streams, collisions, cancellation and journal recovery remain file-phase tasks.

Source review of Start.exe delete_sandbox found that phase1 renames one root, but
phase2 runs without a selected box argument and scans pending roots of all boxes.
It can consume other boxes' DeleteCommand. Therefore the spike refuses this route,
including any custom/inherited DeleteCommand and SandMan trigger settings.

A concrete native alternative exists in the authenticated installed QSbieAPI.dll:
`NtIo_DeleteFolderRecursively(OBJECT_ATTRIBUTES*,callback,state)`. Both native
architectures expose the exact decorated export recorded in the evidence. The lab
passes a retained root handle as RootDirectory with an empty relative name. A dot
name was tested and failed C0000033; it is not a supported NT relative open. The
root lease disallows delete sharing. Successful observed cleanup clears selected
contents while final unlink returns the expected C0000043; the original volume/file
identity remains and host/sibling canaries are unchanged. Zero exit/status alone is
insufficient: contents and identity are verified after dispatch.

This is a viable smoke route, not a completed hostile-cleanup proof. Preflight
rejects reparse points/multiple hard links and unsupported image/snapshot modes,
but a host actor may replace a descendant after that check. The upstream routine
can remove attributes before removing a junction, so a raced substitution could
mutate another location. Holding the top root does not pin every descendant or
exclude another engine client from launching. These are explicit release blockers;
no generic recursive deleter, arbitrary shell cleanup or broadened success status
is substituted. Used-definition removal remains unavailable until the cleanup
boundary is proven; fresh never-materialized definition removal is probed directly.

## Helper authority decision

No elevated helper exists in this spike. The installer and lab initializer are
explicit elevated disposable fixtures, not a privileged product API. Baseline
production should use owner-writable local NTFS storage and the original engine
service; engine admin-only/password restrictions must remain authoritative. A
failed normal-user operation disables that operation instead of silently elevating.
Ordinary-user provisioning/control still needs runtime proof before support.

If P05 needs a privileged provisioning helper, enrollment must originate in an
independently protected installation policy, not a user database, UUID, marker or
requested path. Enrollment binds the OS-observed unboxed peer SID/session, a fresh
nonce and exact protected root/volume identity to a fixed permitted operation.
Authenticate pipe peers from OS tokens, reject boxed/unknown callers even with the
same SID, reject replay and alternate-account UAC mismatch, and retain root/parent
and process handles at dispatch. Lower-trust metadata supplies display data only.
Permit no arbitrary commands, configurable recursive paths or permanently elevated
manager. T57 helper-specific portions stay NOT_APPLICABLE while absent; the actual
root-scope rejection is tested. Introducing a helper requires the full spoofing,
enrollment, path-swap and same-SID boxed-caller tests before availability.

Engine message reading is an additional concrete blocker. GetMessage returns
C0000022 because only the registered session leader or original service can read
the stream. Source Session_Api_Leader requires MyIsCallerSigned for enrollment and
refuses replacing another leader. A third-party unsigned bridge cannot claim this
route. The prototype records statuses and discards buffer text, performs no leader
replacement and does not disable signature enforcement. A future adapter can supply
its own redacted diagnostics while requesting a supported read-only upstream log
interface or an appropriate verified signing/integration route. Internal engine
logs remain unavailable until that interface is proven.

## Licensing assessment

No SandMan or upstream implementation was copied; the original installed engine
is not bundled. Core/Classic is GPLv3. The concrete cleanup alternative introduces
a runtime dependency on QSbieAPI, which declares LGPL 2.1 or later, and its installed
Qt/MiscHelpers dependencies; this is an explicit bridge exception driven by the
lack of a narrow core cleanup route, not a general Qt UI decision. The experiment
uses only the original free NTIO export and Windows structs, not Qt object ABI.
Pinned [license notices](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/LICENSE.Plus)
and [QSbieAPI header](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/SandBox.h)
are the provenance anchors. Dynamic loading is not an exemption from obligations.
Before production distribution, select the manager license, review linking and
user replacement/relinking requirements, preserve notices and satisfy source/offer
requirements for every component actually distributed. A commercial permission is
not inferred from installed-engine use. Bundling and license selection remain
future product decisions, with no binary redistribution in this phase.

## Blockers and proposed resolutions

| Gate | Concrete unresolved part | Proposed resolution |
|---|---|---|
| Same-SID all-session safety | Hosted runners supply one runner-user interactive session; session-zero SYSTEM is a different SID | Add an ephemeral/self-hosted Windows Actions lab with two genuine sessions for the same synthetic account; prove count/membership/Idle and stop scopes in both |
| Cleanup containment | Descendant substitution and external launch race not excluded by top-root lease/preflight | Prototype upstream native routine in a protected enrolled quarantine with stable descendant authority; inject reparse/hardlink/rename and external-launch races. Request a narrow upstream fix if the routine cannot meet the boundary |
| Stop completion | Bounded retained-handle stop can return unavailable/incomplete during process teardown; no unsafe fallback | Reconcile exited handles and source membership without numeric kill, inject exit/reuse/scope faults, prove standard-user permissions. Keep Unknown until actual completion |
| Provisioning authority | Lab is elevated; ordinary-user root/config authority is not proven | Run a standard-user fixture on owner-private NTFS roots; keep admin-only config unavailable or implement the protected enrollment design with full helper tests |
| Root identity | PendingRoot happy path tested; ancestor/root replacement at initialization not tested | Retain safe parent/root handles and inject replacement before/after identity binding; reject unexpected identity changes |
| Complete baseline | Representative sockets/read/write pass, broader network/broker and policy inheritance permutations untested | Add controlled DNS/LAN/SMB/raw/inbound endpoints and inheritance/trigger consumers; retain independent positive controls and release tuples |
| Engine message diagnostics | Unsigned bridge is not the engine-authorized signed session leader; GetMessage returns C0000022 | Obtain a supported narrow read-only upstream interface/signing route, test authorization and redaction, or explicitly limit diagnostics to manager-owned status evidence. Never change signature enforcement |
| Distribution boundary | Runtime QSbieAPI/Qt dependency and manager license need production assessment | Decide a compatible license/notice/source/replacement strategy before shipping, or obtain a narrow core upstream cleanup export |

Every mandatory operation has a proposed source-backed route; unproven portions
are not waived. P02 remains BLOCKED and P03 is not started. Passing the CI collection
job means probes completed and artifacts were uploaded, not that this gate passed.
All 66 production acceptance scenarios remain NOT_STARTED and must run in their
owning feature phases.
