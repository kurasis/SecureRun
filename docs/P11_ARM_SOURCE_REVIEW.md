# P11 ARM fault: source and issue review

Review date: 2026-10-18 UTC. **Static review only; P11 remains BLOCKED.**
No new Actions run or test program was started. The owner-cancelled isolated
reproduction remains NOT_RUN. Existing Windows security, engine pins, policy
allowlists, architecture coverage and mandatory workloads remain unchanged.

## Old ARM fixes are already present

Upstream [#4422](https://github.com/sandboxie-plus/Sandboxie/issues/4422) describes
WerFault on Windows 11 ARM64 with Sandboxie 1.15.3. Related
[#4415](https://github.com/sandboxie-plus/Sandboxie/issues/4415) reports x64-on-ARM
startup problems, including a stack-overflow exception. The original changelog
lists both as fixed in 1.15.5/5.70.5, released 2025-01-27.

The [1.15.5 change](https://github.com/sandboxie-plus/Sandboxie/commit/91b70a8e58cedd1cef2913476f82522530165e13)
is an ancestor of the pinned 1.18.8 source
`bde0890108a563f5d72eb8e57085be2b37177218`. Inspection of the current code also
confirms the following changes remain, rather than inferring this only from ancestry:

| Pinned source | Retained change |
|---|---|
| [dllhook.c:1059](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/dllhook.c#L1059) | ARM hook protection starts at the target and spans 16 bytes |
| [gdi.c:866](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/gdi.c#L866) | ARM/ARM64EC GdiDllInitialize lookup uses gdi32full.dll |
| [file.c:2963](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/file.c#L2963) | Existing ARM64EC xtajit64 handling in NtOpenFile remains |
| [ldr.c:455](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/ldr.c#L455) | The old problematic Ldr NtTerminateProcess hook remains disabled |

These are source observations, not proof that the current Windows tuple has no
new regression. The earlier issue's stack-overflow code cannot be assigned to
our fault: our original exception code/module remains unavailable.

At checked upstream tip `596bfa802f6fe69d3edf2aa56c294523ce4d6881`, the
[changes after the pin](https://github.com/sandboxie-plus/Sandboxie/compare/bde0890108a563f5d72eb8e57085be2b37177218...596bfa802f6fe69d3edf2aa56c294523ce4d6881)
affect translations, documentation and SbieSettings.ini; no core runtime file
changed. The latest official release checked is still 1.18.8. No newer published
core fix for this fault was identified. No old replacement DLL or downgrade is used.

## Architecture observations are not a complete explanation

The retained passive traces show these temporal overlaps:

| Run | Active probe name when the reporter appeared | Delay after RpcSs-named lifetime first observed |
|---|---|---|
| [39111501581](evidence/p11/investigation-96483f3-observer/review.json) | x86 probe | 219 ms |
| [39119544472](evidence/p11/investigation-0d2600c-debug/review.json) | x64 probe on ARM | 251 ms |
| [39126844625](evidence/p11/investigation-f6e1042-service-log-failed/review.json) | x64 probe on ARM | 216 ms |

Names and matched birth times alone do not authenticate image bytes or identify
the crashing instruction. These overlaps justify inspecting startup for emulated
callers; they do not establish emulation as the sole cause.

Another [failed diagnostic run](evidence/p11/investigation-f374409-observer/review.json)
timed out during ARCHIVE_EXTRACT. Its independently re-downloaded original
[application inventory](evidence/p11/investigation-f374409-observer/windows-11-arm/official-applications.json)
identifies the ARM64 7-Zip 26.04 distribution. This is not an observed faulting
thread architecture or proof that every failure shares one cause. It prevents
reducing the investigation to emulated probes alone or dropping an architecture.

The x86 calling-convention hypothesis also lacks support:
[Sandbox32.props:18](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/Sandbox32.props#L18)
sets StdCall, matching current Rust `extern "system"` imports. C declarations
without an explicit convention are insufficient grounds to change those bindings.

## What remains unresolved

The original exception code and fault module are still needed to distinguish a
new engine/Windows regression from a manager-triggered startup interaction.
FFS warnings alone are insufficient: 112 NtCreateLowBoxToken warnings also occurred
in a successful full diagnostic sample. Cleanup exit 0x4f is not the exception.
The native original-filter synthetic control succeeded, but the cancelled
reproduction provides no actual RpcSs fault dump. No source-level runtime fix is
claimed from this review, and no phase gate is promoted.

[Structured review and source hashes](evidence/p11/investigation-static-arm-source-review/review.json)
retain the checked commits, files and evidence references.
