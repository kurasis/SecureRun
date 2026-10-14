# Engine candidate matrix

No supported tuple exists. P01 provenance does not establish enforcement.

| Platform | Engine candidate | State | Evidence |
|---|---|---|---|
| Current Linux cloud | Not installed | Source/checksum checks only | [provenance](evidence/p01/linux-provenance.json) |
| GitHub Windows 11 ARM64 | Plus x64 1.18.6 installer, not installed | Tooling-only; x64 probe emulated; CI result pending | [lab](LAB_SETUP.md) |
| Serviced Windows 11 x64 | Plus 1.18.6 / core 5.73.6 | BLOCKED: disposable runtime runner unavailable | P02 required |

Pinned source: `cdba7096240b93d79c5373aa81a75a1c5c71b883` at official
[tag v1.18.6](https://github.com/sandboxie-plus/Sandboxie/releases/tag/v1.18.6),
published 2026-10-11. [Machine-readable pin](engine-candidate.json).

Source-declared core versions for Start.exe, SbieIni.exe, SbieSvc.exe, SbieDll.dll
and SbieDrv.sys use
[my_version.h](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/common/my_version.h)
(5.73.6); Plus uses
[version.h](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/SandboxiePlus/version.h)
(1.18.6). These are declarations, not observed installed PE versions.

Installer size: 24,914,432 bytes. SHA256:
`3ad29e1ec18618ee9aa4ef4e21ab0548cf2188b94c05c41cb7a07b5d2d0270e2`.
HTTPS download matched official GitHub release asset digest on Linux.
Authenticode, signer identity, installed component/cat signatures, architecture,
service/driver health, enforcement and entitlement must be recorded on Windows.
A digest served with a binary is not independent authenticity evidence.

All presets/capabilities are UNKNOWN/unavailable for product use, including
Standard offline/online. Optional paid presets are disabled; no certificates
are requested. No P01 production adapter version exists. A helper decision is
UNRESOLVED, not absent-by-design; helper tests are not waived prematurely.

## Licensing and provenance

Pinned LICENSE.Classic is GPLv3; LICENSE.Plus describes core GPLv3, SandMan custom
terms, QSbieAPI/MiscHelpers/Qt LGPL and other component-specific notices.
Full commit-addressed URLs and license hashes are in the candidate pin.
This repository copies no upstream implementation, links no upstream library
and redistributes no engine binary. Reassess obligations before native linking,
commercial distribution or bundling. The new manager's license is unselected.
