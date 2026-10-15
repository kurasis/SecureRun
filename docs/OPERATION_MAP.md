# P02 operation feasibility map

Candidate: Plus 1.18.6 / core 5.73.6 / ABI 0x57230, source commit
cdba7096240b93d79c5373aa81a75a1c5c71b883. P02 is DONE for representative feasibility.
PROVEN means the specific tested lab route; production acceptance remains unrun.
[Final raw results and tested runtime source hashes](evidence/p02/manifest.json).

All operations require a healthy pinned engine and OS-observed unboxed caller.
Ordinary user means the owning standard account with the original engine service
and writable private local NTFS storage; original admin-only/password restrictions
still apply. Installation and global WFP configuration are explicit disposable
lab administration, not elevated manager requirements.

| Operation | Exact upstream route and result contract | Privilege | Windows feasibility result |
|---|---|---|---|
| detectEngine | Protected absolute SbieDll; GetVersionEx, QueryProcessEx2, QueryDrvInfo(0); UTF-16/version/ABI, NTSTATUS [A,D] | User; installation admin | PROVEN T02: native driver/service, component trust and UNBOXED/UNKNOWN distinction |
| queryCapabilities | QueryDrvInfo(0,ULONG*,4), class -1 certificate low32; NTSTATUS/flags [D] | User | PROVEN observation; optional paid profiles unavailable without enforcement/entitlement evidence |
| listBoxes | QueryConf(NULL,NULL,index OR NO_TEMPLS OR NO_EXPAND,...); bounded UTF-16 list, only C000008B ends it [A,C] | User | PROVEN T02: section inventory; validate section type before production adoption |
| readEffectivePolicy | QueryConf(section,key,index,WCHAR*,bytes); raw and inherited views separately [A,C] | User | PROVEN readback/automation inheritance inspection; report unknown enforcement fields rather than inventing an oracle |
| createBox | UpdateConf('s',password,section,key,value); NTSTATUS=0 plus readback [B,E] | User if original config authorizes | PROVEN T55: standard-user fresh definition, disabled PendingRoot, native relative root creation, DACL and identity |
| applyPolicy | UpdateConf set/append; ReloadConf(session,1) only for disposable WFP prerequisite [B,C,W] | User; global WFP admin | PROVEN T08/T09/T12/T16/T33: baseline controls, trigger rejection and protected IPC password outcomes; full release matrix later |
| launch | RunSandboxed(box,cmd,targetCwd,flags,STARTUPINFO*,PROCESS_INFORMATION*); BOOL plus actual handles/membership [B,L] | User | PROVEN T01/T04/T05: absent-box refusal, args, descendants; T19 logical boxed EXE through trusted boxed Start stage |
| listProcesses | EnumProcessEx(box,TRUE,-1,pids,count) plus QueryProcessEx2; NTSTATUS and complete bounded membership [A,P] | User for observation | PROVEN T36: actual same-SID sessions 0/2, foreign SYSTEM session and SUCCESS truncation refusal |
| terminateBox | Held OpenProcess object; current box/SID/birth, IsProcessCritical, TerminateProcess(handle), same-object wait and re-enumeration [P,H] | Owning user; no broad elevation | PROVEN T62: standard-user all-session completion, live wrong-box refusal and natural-exit reconciliation; no numeric fallback |
| queryRoots | QueryBoxPath two-pass byte lengths and TranslateNtToDosPath; actual identity from held root [A,B,H] | User | PROVEN T55/T57: generated expected root, standard-user ACL, actual parent junction/root replacement refusal |
| clearContents | Original installed QSbieAPI NtIo_DeleteFolderRecursively(OBJECT_ATTRIBUTES*,callback,state) [N]; bounded native status plus contents/identity | Owning user with preauthorized DACL handles | PROVEN T24: Enabled=n launch fence, sealed descendants/reparse/hardlink rejection, exact empty-root postconditions and retained identity |
| removeDefinition | UpdateConf('s',password,ownedSection,"*",NULL); NTSTATUS=0 and absent readback [E] | User if original config authorizes | PROVEN T25/T24: fresh definition and standard-user used definition only after verified cleanup; known empty root retained |
| readDiagnostics | Manager-owned redacted version/ABI/flags/context and operation status [A,D]; no raw engine message fabrication | User | PROVEN T02: MANAGER_OBSERVATION; optional GetMessage stream unavailable C0000022/signed-leader requirement [P] |

All 13 mandatory operations have tested viable routes. Bounds and reconciliation
below are part of each contract; failures do not become success or automatic replay.
Source references are full pinned permalinks:

- A: [API declarations](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbieapi.h), [API wrappers](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbieapi.c).
- B: [DLL declarations](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/sbiedll.h), [UpdateConf](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/callsvc.c#L873), [RunSandboxed](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/callsvc.c#L997).
- C: [configuration query/inheritance](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.c#L1519), [reload](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.c#L1764), [raw flags](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf.h).
- D: [driver features and entitlement state](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/api.c#L1184).
- E: [RemoveSection](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/sbieiniserver.cpp#L1059), [password authorization](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/sbieiniserver.cpp#L843).
- L: [suspended creation and binding](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L1224), [handle duplication/resume gate](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L1451).
- H: [Windows process termination and asynchronous completion](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess), [NtCreateFile](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-zwcreatefile), [OWNER RIGHTS SID](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-identifiers).
- F: [external start Enabled fence](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/process_api.c#L153), [enabled evaluation](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/conf_user.c#L365).
- P: [signed session-leader requirement](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/session.c#L334), [message-reader authorization](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/api.c#L717), [process enumeration](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/process.c), [original termination implementation](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp).
- W: [kernel WFP rules](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/wfp.c#L680), [network-file blocking](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/drv/file.c#L997).
- N: [native cleanup](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/Helpers/NtIO.cpp#L191), [upstream caller](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/QSbieAPI/Sandboxie/SandBox.cpp#L208), [Start cleanup](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/apps/start/delete.cpp).

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

Installation, global WFP setup and SYSTEM session creation use the elevated
disposable harness. Actual provisioning/configuration, root DACLs, launch,
all-session stop, sealed cleanup and definition removal also run as a standard
user. No product helper is needed for these baseline routes. If one is introduced
later, protected enrollment and OS peer identity tests become mandatory in P05;
a database UUID, marker or requested path cannot supply privileged authority.

The bridge starts in the protected engine directory with protected/System32 DLL
search. Only a separate target CWD enters RunSandboxed. That API copies the caller
environment: CI credentials are removed and a small Windows-variable allowlist
is used before dispatch. Passwords use the original service IPC, never argv or env.

Enumeration is bounded at 1024 with count observations before/after. Upstream
returns success for truncated lists: capacity reached or count discrepancy means
UNKNOWN, never Idle. Snapshots do not exclude external trusted clients. Stop
validates the retained object's engine box/SID/birth at dispatch, rejects critical
processes and waits on that same handle. No numeric-PID fallback exists.

The lab bounds normal target waits at 15–35 seconds and the standard-user worker at 90 seconds, native cleanup callback at 30 seconds,
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

The upstream termination path was traced through KillOneHandler/KillAllHandler,
session checks, KillAllHelper's current-session batches and KillProcess's numeric
API_KILL_PROCESS fallback. The selected route keeps a handle instead, validates
its actual creation time/engine owner/box at dispatch and waits on that object.
Source anchors: [KillProcess](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L129),
[KillOneHandler](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L175),
[KillAllHandler](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L248),
[KillAllHelper](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/svc/ProcessServer.cpp#L323).

Cleanup uses the original installed export and bounded Windows handle/ACL
preparation, with no generic root deleter. Enabled=n is read back and an actual
external original-engine client is rejected [F]. Ancestor/root namespace leases,
sealed creation/DACL/attribute rights and a second identity snapshot stay in force
through native dispatch. Pre-dispatch sealed mutation attempts are explicitly
labeled; no concurrent stress result is claimed. Existing junction/hardlink fixtures
are rejected before calling native cleanup. Zero or exact C0000043 is accepted
only with empty contents and retained root identity; restoration failure stays
unresolved/fenced. Used-definition removal requires those verified postconditions.
See [storage and threat-model assessment](FEASIBILITY_REPORT.md).

Automation consumers: [Start DeleteCommand](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/apps/start/delete.cpp),
[SandMan OnBoxDelete](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/SandMan/SandMan.cpp#L2544),
[OnBoxTerminate](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/SandMan/SandMan.cpp#L2774),
[AutoDelete](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/SandMan/SandMan.cpp#L2803),
[OnFileRecovery](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/SandMan/SandManRecovery.cpp#L117).
These are source review anchors only; no SandMan implementation is copied.

## P07 production boxed executable stage

The P02 `Start.exe` prototype remains historical feasibility only. Source review
of pinned `apps/start/start.cpp:1925–2092` confirms `ShellExecuteEx` and environment
expansion, unsuitable for exact production argv. P07 instead creates the
independently written protected `securerun-box-launcher.exe` through the same
original suspended `SbieDll_RunSandboxed` route. The backend verifies stage
membership before resume. The boxed stage uses explicit `CreateProcessW`, with
no inherited handles/shell/associations/expansion, and verifies its suspended
child's box/session before resume. It refuses any unboxed invocation and any
logical namespace not matching its actual `SR_<environment UUID>` membership.
Only the boxed stage resolves the imported logical EXE. Hash/file identities
and native/emulated mapping proof are retained by P07; no P02 prototype is
relabelled production evidence. See [safe files](SAFE_FILE_WORKFLOWS.md).
