# Development status

Specification: 1.3. Updated: 2026-10-14 UTC. Requested scope: P01 only.

| Phase | Status | Evidence / dependency |
|---|---|---|
| P01 | DONE (owner-selected Windows 11 ARM64 lab) | [phase report](phases/P01_REPORT.md), [verified run](evidence/p01/windows-arm64/run-summary.json) |
| P02 | NOT_STARTED | Next phase; native ARM64 engine feasibility and original x64 coverage unresolved |
| P03–P12 | NOT_STARTED | Follow the canonical phase dependency table |

P01's original x64 lab default was replaced by the owner's explicit Windows 11
ARM64 Actions request. This is a documented platform adjustment, not a security
waiver. Completed: repository assessment/ADR, unchanged 26-document specification,
pinned official x64 and native ARM64 engine candidates, isolated synthetic fixture
contract and NTFS canary, initial matrices, native smoke tools and CI.

Verified: repository integrity, 6/6 tooling tests, real x64 EXE execution on Windows
11 Enterprise ARM64 26200.9457, both installer SHA256/size and Valid Authenticode.
[Windows evidence](evidence/p01/windows-arm64/run-summary.json),
[Linux provenance](evidence/p01/linux-provenance.json),
[test report](TEST_REPORT.md). All T01–T66 remain NOT_STARTED.

No engine is installed, no policy is enforced and no product requirement is
accepted as complete. There is no production app, helper, launcher or installer.
P01 establishes the selected lab; P02 must prove a native ARM64 adapter route,
x64-emulated target semantics and normal-security parity before its gate passes.
The hosted image reports Secure Boot false (unchanged), VBS/code integrity active,
Defender active and no exposed nested virtualization. Native Windows 11 x64
product compatibility needs a separate x64 run; emulator results cannot supply it.

Next eligible task: P02 source-backed feasibility on the explicitly selected lab,
with these platform/security limitations retained. P02 has not been started.
