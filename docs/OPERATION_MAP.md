# P02 operation feasibility map

Candidate: Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, source commit
`cdba7096240b93d79c5373aa81a75a1c5c71b883`. These are lab routes, not a production
API. PROVEN means the stated smoke only; remaining scope blocks the gate as
specified in [FEASIBILITY_REPORT](FEASIBILITY_REPORT.md).

| Operation | Exact upstream route | Status and remaining scope |
|---|---|---|
| `detectEngine` | Protected absolute SbieDll; `SbieApi_GetVersionEx`, `QueryProcessEx2`, `QueryDrvInfo(0)` [A, D] | PROVEN installed version/ABI, healthy native driver/service and unboxed context; installation/update reconciliation remains a product task |
| `queryCapabilities` | `SbieApi_QueryDrvInfo(0,ULONG*,4)` feature flags and class -1 certificate-state low32 [D] | PROVEN observation route; paid enforcement UNRESOLVED, optional profiles disabled. WFP flag alone never proves enforcement |
| `listBoxes` | Bounded `SbieApi_QueryConf(NULL,NULL,index\|NO_TEMPLS\|NO_EXPAND,...)` [A, C] | PROVEN section discovery; includes non-box sections, validate type without adoption. Avoid EnumBoxesEx's end/error ambiguity |
| `readEffectivePolicy` | `SbieApi_QueryConf(section,key,index,WCHAR*,bytes)` [A, C] | PROVEN lab readback/inherited automation inspection; not a universal permission oracle. Untested fields remain unknown |
| `createBox` | `SbieDll_UpdateConf('s',password,section,key,value)` then status/readback [B, E] | PROVEN unique fresh definitions and PendingRoot initializer; production ownership/journal deferred |
| `applyPolicy` | Same update; 'a' for ClosedFilePath lists; `SbieApi_ReloadConf(session,1)` for disposable WFP prerequisite [C, W] | PROVEN selected read/write/socket smoke and password IPC; full DNS/LAN/SMB/broker/raw/inbound baseline UNRESOLVED |
| `launch` | `SbieDll_RunSandboxed(box,cmd,targetCwd,flags,STARTUPINFO*,PROCESS_INFORMATION*)` [B, L] | PROVEN missing-box rejection, membership, descendants, fixed args and separate CWD; production exactly-once journal and broader target types unresolved |
| `listProcesses` | `SbieApi_EnumProcessEx(box,TRUE,-1,pids,count)` plus QueryProcessEx2 [A, P] | PROVEN bounded current-session enumeration, real session-zero different owner and rejection of successful truncation; same-SID second interactive session remains UNRESOLVED |
| `terminateBox` | Held OpenProcess handle, engine box/SID/birth match, IsProcessCritical, TerminateProcess(handle), wait and bounded re-enumeration [P] | PROVEN held-object smoke; no numeric PID fallback. Standard-user access, fault/churn variants and exclusion of external launches unresolved |
| `queryRoots` | `SbieApi_QueryBoxPath` two-pass byte lengths, `SbieDll_TranslateNtToDosPath` [A, B] | PROVEN generated root resolution, NTFS ACL and second-account denial; parent/root substitution and ordinary-user provisioning authority unresolved |
| `clearContents` | Original installed QSbieAPI `NtIo_DeleteFolderRecursively(OBJECT_ATTRIBUTES*,bool callback(const WCHAR*,void*),void*)` [N] | UNRESOLVED mandatory cleanup gate: retained-root candidate tested, hostile replacement and launch races not proven. Start.exe broad phase2 rejected; no arbitrary DeleteCommand or replacement recursive deleter |
| `removeDefinition` | `SbieDll_UpdateConf('s',password,ownedSection,"*",NULL)` [E] | PROVEN fresh never-materialized definition removal; used-definition removal BLOCKED until cleanup passes |
| `readDiagnostics` | `SbieApi_GetMessage(sequence*,session,msgId*,pid*,WCHAR*,bytes)` [A] | PROVEN bounded status/ID observation; discard text, arguments and environments |

Source references are full pinned permalinks:

- A: [API declarations](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbieapi.h), [API wrappers](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbieapi.c).
- B: [DLL declarations](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbiedll.h), [UpdateConf](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/callsvc.c#L873), [RunSandboxed](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/callsvc.c#L997).
- C: [configuration query/inheritance](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.c#L1519), [reload](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.c#L1764), [raw flags](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.h).
- D: [driver features and entitlement state](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/api.c#L1184).
- E: [RemoveSection](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/sbieiniserver.cpp#L1059), [password authorization](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/sbieiniserver.cpp#L843).
- L: [suspended creation and binding](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L1224), [handle duplication/resume gate](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L1451).
- P: [process enumeration](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/process.c), [original termination implementation](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp).
- W: [kernel WFP rules](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/wfp.c#L680), [network-file blocking](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/file.c#L997).
- N: [native cleanup](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/Helpers/NtIO.cpp#L191), [upstream caller](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/SandBox.cpp#L208), [Start cleanup](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/apps/start/delete.cpp).

## ABI and result contract

Complete native prototypes are implemented in [engine_bridge.cs](../tools/probe/engine_bridge.cs)
and [feasibility_probe.c](../tools/probe/feasibility_probe.c), independently from upstream
implementation. The host uses native 64-bit C#/PowerShell for this experiment.
Windows x64/ARM64 calling conventions are unified. The pinned Win32 DLL uses /Gz:
its .def aliases legacy five-argument SbieApi_QueryProcess and SbieDll_GetHandlePath;
the x86 probe uses WINAPI instead of guessing an undecorated Ex2 alias.

All text is UTF-16. Version output: WCHAR[16], ABI ULONG*. QueryProcessEx2:
HANDLE PID, ULONG imageChars, box WCHAR[40], image or NULL, SID WCHAR[96],
ULONG* session, ULONG64* FILETIME birth. EnumProcessEx: WCHAR[40] box, U1 BOOLEAN
allSessions, ULONG session, ULONG* PID buffer and in/out ULONG* count. Names are
nonempty alphanumeric/underscore with maximum 38 characters. QueryBoxPath:
WCHAR[40] box, file/key/ipc WCHAR* and corresponding ULONG* byte lengths; unused
buffers/length pointers are NULL. QueryConf copies section/key to WCHAR[66], takes
ULONG index/flags, WCHAR* result and ULONG byte capacity. Raw flags: 0x70000000;
inherited unexpanded: 0x20000000; expanded: 0. GetHandlePath takes HANDLE,
8192-byte WCHAR output and BOOLEAN*, not BOOL*. TranslateNtToDosPath returns U1
BOOLEAN. RunSandboxed returns four-byte BOOL and actual process/thread handles.
Other results are native NTSTATUS: success exactly zero in this spike.

Healthy pinned self-query C000000B (STATUS_INVALID_CID) means UNBOXED. Other
failures mean UNKNOWN and prohibit controls. C000008B is the only QueryConf list
terminator; other errors are not absent settings. Missing/wrong configuration
password returns C000006A without mutation. Utility exit zero cannot replace
status/readback/postconditions. Explicit compiler/library paths, /MACHINE and PE
machine checks prove the compiled architecture; /WX stays enabled.

## Privileges, dispatch and reconciliation

Installation, explicit DACL provisioning and SYSTEM-session fixtures use the
elevated disposable lab. This does not prove an elevated production manager is
acceptable. Ordinary-user operation and any narrowly scoped provisioning broker
must be resolved before P05 using the authority design in the feasibility report.

The bridge starts in the protected engine directory with protected/System32 DLL
search. Only a separate target CWD enters RunSandboxed. That API copies the caller
environment: CI credentials are removed and a small Windows-variable allowlist
is used before dispatch. Passwords use the original service IPC, never argv or env.

Enumeration is bounded at 1024 with count observations before/after. Upstream
returns success for truncated lists: capacity reached or count discrepancy means
UNKNOWN, never Idle. Snapshots do not exclude external trusted clients. Stop
validates the retained object's engine box/SID/birth at dispatch, rejects critical
processes and waits on that same handle. No numeric-PID fallback exists.

The lab bounds target waits at 15–35 seconds, native cleanup callback at 30 seconds,
installer stages at three minutes and smoke step at ten minutes. Native IPC can
itself block: the production route requires an externally bounded worker process.
Timeout or cancellation after acceptance means unknown outcome. Reconcile using
membership, recorded identities and operation intent; never automatically replay.

Private workspace mapping uses boxed SbieDll_GetHandlePath and its boxed flag,
then the original NT-to-DOS translation. A fixed benign EXE is hash-checked in the
resolved root and launched through its logical path; its physical storage path is
never executed as a host EXE. This is mapping feasibility, not a safe transfer
primitive. Handle ancestry, replacement, streams, collisions and journaling remain
owned by the file phases.
