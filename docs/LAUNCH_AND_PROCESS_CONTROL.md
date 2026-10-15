# Launch and process control

P06 implements user-owned host-EXE registration and environment Stop. P07 adds
identity-bound imported executable references through the
[safe file protocol](SAFE_FILE_WORKFLOWS.md). The application manages the
separately installed original engine; it supplies no security driver.

## Application registration and execution

The authorized main WebView selects an EXE and optional CWD using one-use native
picker capabilities bound to the operation, environment, revision and 60-second
expiry. Renderer paths and confirmation booleans are rejected. The backend stores
the canonical local PE identity/content digest, arguments and optional directory
identity privately; views and diagnostics return only registered IDs and labels.
Targets in engine or manager storage, reparses, hard-link aliases, non-PE input,
unsupported architectures and unsafe path grammar are refused. App registrations
are bound to a policy revision; register again after a policy revision changes.
Arguments are an array, bounded to 64 entries and a 24,000 UTF-16 command line;
controls/NUL are rejected. Arguments are not secret storage.

The source-pinned original `SbieDll_RunSandboxed` SDK receives a conservative
engine box name, CRT-quoted target command and separate target CWD. There is no
Start.exe command parser, shell, association, elevation or host recovery route.
An empty command is impossible. The upstream service passes a null application
parameter and parses the leading fully quoted absolute EXE command; real argument
cases exercise that separate parser. Our own host workers use an explicit
application through native process creation. Upstream `ProcessServer.cpp` keeps
`CREATE_SUSPENDED` through handle duplication; the manager verifies OS-held
birth and driver box/owner identity before `ResumeThread`. A failed check
terminates/waits only on that returned process handle. A successful receipt can
therefore describe a confirmed boxed primary which exits before the next list.
All box members are enumerated independently of primary lifetime, including
children, grandchildren and another supported Windows session.

Workers start in System32 with an OS-derived minimal environment and no inherited
credentials; the original SDK passes only that scrubbed environment. Target CWD
never becomes a host worker/DLL utility CWD. Engine DLL loading, signatures,
component hashes, original injected libraries, SCM configuration and parent/self
unboxed context use the P04/P05 validated route. ABI calling convention is WINAPI,
including real Win32 probes. The paired policy verifier and original engine must
remain protected and unchanged.

## Imported executable dispatch

A BoxExecutableRef binds the private workspace mapping, environment generation,
physical file identity/content hash and protected native boxed-stage identity.
Launch revalidates those bindings and dispatches the stage suspended through the
original SDK. The stage verifies its injected-engine box before any target I/O,
then uses explicit `CreateProcessW` with the logical EXE and structured argv. It
verifies the suspended child before resume. Shell associations and environment
expansion are absent; the physical storage path is never a host launch target.

`BOXED_STAGE_RUNNING` and `BOXED_STAGE_EXITED` describe only the stage. The
registered target outcome remains `TARGET_OUTCOME_UNOBSERVED`; stage exit is not
target completion. Current all-session driver membership and the same independent
Stop gate apply. Reset invalidation completes in P08.

## Action prerequisites

| Action | Required current evidence |
|---|---|
| Register | Trusted unboxed context; independently verified owner/root/policy; expected revision; canonical selected PE/CWD |
| Launch | Register prerequisites repeated; supported P05 policy family and exact kernel/product/engine tuple; current effective fingerprint/inheritance; root identity/ACL; current manager/verifier binding; no unresolved prior launch |
| Inspect/reconcile | Trusted unboxed context; protected components; independently validated current environment scope; complete all-session observation to acknowledge uncertainty |
| Stop selected environment | Trusted engine/context; original owner and engine binding; exact current marker/root identity; complete all-session enumeration; held noncritical process objects with current driver owner/box/birth |
| Stop managed | The Stop gate independently for every explicitly journaled managed environment; no prefix discovery/adoption |

Launch currently supports the owner-selected Server 2025 x64 build 26100 and
Windows 11 ARM64 build 26200 tuples. Baseline StandardOffline/StandardOnline
uses no optional paid entitlement. Missing entitlement never supplies a reason
to refuse a safe Stop. A different engine, unknown root, incomplete enumeration
or changed owner does block Stop; Running/Unknown remains visible.

## Dispatch, reconciliation and stopping

A WAL/FULL journal writes a permanent reservation and request/scope digest before
engine dispatch. The original reservation already says Unknown, so an abrupt
process loss cannot leave a replayable state. Duplicate operations return the
recorded receipt; changed payload or root binding is an operation conflict.
Reservations are never garbage-collected into retry permission. No PID remaining
is not evidence that the target never executed. Unknown launches block a new
launch until the user explicitly reconciles complete current state. This preserves
the old Unknown receipt and enables only a new operation, never replay.

The same cross-session `policy-writer.lock` coordinates launch, Stop and P05
mutations. Stop fences new external launches and retains authorized process
handles through dispatch and completed waits. It checks current scope and
membership again immediately before acting. Natural exit is handled through the
held object, and cannot retarget a reused PID. It repeats bounded complete
all-session enumeration for late children, then requires an empty scope. It has
no upstream KillProcess/numeric-PID fallback. Partial scope/access/timeout failure
stays Unknown. Optional certificate, network policy verification, application
registration and launch eligibility are not Stop prerequisites.

These manager locks do not serialize a trusted administrator or SandMan. Current
external configuration/root changes abort the operation; this does not claim
atomic isolation against a concurrent trusted administrator editing configuration.
Persistent workloads are not placed in the worker's kill-on-close job and do not
end just because the UI/worker exits. General reset/cleanup remains P08.

## Evidence

The P06 workflow uses normal production commands with fixed synthetic native,
x86 and (on ARM) x64 PEs. A separate `policy-ci` build supplies only disposable
Actions interruption checkpoints; the normal build contains no checkpoint
activation. Evidence distinguishes real killed workers, actual all-session Stop,
short-lived receipts and changed-scope refusal from portable tests. No raw target
arguments, environments, private paths or account credentials are collected.
See the [phase report](phases/P06_REPORT.md) for current results and limitations.
