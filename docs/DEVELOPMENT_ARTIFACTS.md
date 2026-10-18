# Reviewed development artifacts

Package source: `dd447fec88de966fa839b03fc0fd4eb6b41776a4`. [Actions run 39089078904](https://github.com/kurasis/SecureRun/actions/runs/39089078904).

**Phase status: BLOCKED by P10 integration.** Installed tests passed on both targets;
these artifacts are not a completed release gate.

Product 0.3.0; candidate packaging revision 0.3.0.11. Status: **UNSIGNED DEVELOPMENT ONLY**.
No original-manager license has been selected by the owner. No engine is bundled.

| Target | Candidate filename | Bytes | SHA-256 |
|---|---|---:|---|
| windows-2025 | `SecureRun-Development-0.3.0.11-x64os.exe` | 33558613 | `ab46606ac2882a37c8fba297351b2face901b11b09aa919b87cc2cf9d125359a` |
| windows-11-arm | `SecureRun-Development-0.3.0.11-arm64.exe` | 45517163 | `a41755302999879894580efd2fa6baf97169814195ba2d4d1b6a799d5f3b6383` |

Downloads: [Server x64 installers](https://github.com/kurasis/SecureRun/actions/runs/39089078904/artifacts/12122600283),
[Windows 11 ARM64 installers](https://github.com/kurasis/SecureRun/actions/runs/39089078904/artifacts/12122356753).

The matching `p11-development-installers-<runner>-<source>` Actions artifact contains
candidate/baseline installers, SHA256SUMS and dependency notices. Baseline revision10
exists for the same-runtime upgrade test. Download candidate revision11 for development.
Actions retention is 14 days; this is not a permanent production release download.
The source repository retains reviewed original JSON/provenance and build instructions.
Rebuilding after expiry creates a new artifact requiring its own hash/install validation.

## Actual build tools

| Target | Rust | Node / npm | MSVC toolset | Windows SDK |
|---|---|---|---|---|
| windows-2025 | rustc 1.90.0 (1159e78c4 2025-09-14) | v24.19.0 / 11.17.0 | 14.51.36231 | 10.0.26100.0 |
| windows-11-arm | rustc 1.90.0 (1159e78c4 2025-09-14) | v24.19.0 / 11.17.0 | 14.51.36231 | 10.0.26100.0 |

The pinned Inno/Microsoft downloads retain their original valid signatures. Original
manager/probe/guard and final installer signatures are `NotSigned`, never reported as
production-signed. See [signing policy](SIGNING.md) and [reproducible procedure](BUILD.md).
