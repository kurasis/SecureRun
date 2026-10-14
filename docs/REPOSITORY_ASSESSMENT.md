# Repository assessment — P01

Assessment date: 2026-10-14 UTC. Repository: kurasis/SecureRun (public).

## Baseline and reuse

Initial checkout `/workspace/SecureRun` had a valid unborn `work` branch,
zero objects, no tracked/untracked files, no AGENTS.md, manifests, lockfiles,
application, CI or build scripts. `git ls-remote --symref origin` succeeded with
no references; `git ls-remote --exit-code origin refs/heads/main` returned 2.
There was no source or user work to overwrite. Initial development creates main.

Reuse the full uploaded specification unchanged under `docs/specification/`.
Its 26 documents were read in README order, followed by all 12 phase files.
The original content hashes are recorded in `docs/specification/SHA256SUMS`.
No SandMan/engine code or binaries are imported into this repository.

## Architecture and tool availability

[ADR 0001](decisions/0001-p01-scope-and-identity.md) reserves identity/namespaces
and retains the default Tauri 2 / React / TypeScript / Rust / SQLite architecture.
P03 owns application scaffolding, dependency selection and lockfiles. P01 only
needs Python 3.12 stdlib, Windows PowerShell 7, MSVC C++ x64 build tools and the
Windows SDK. GitHub Actions dependencies are pinned to full source commits.

Current cloud host: Linux; Python 3.12.14, Node 24.19.0, npm 11.9.0,
GCC and GitHub CLI present. Rust/Cargo, PowerShell, QEMU and `/dev/kvm` absent.
No Windows host/user binding exists. Linux cannot run the required kernel tests.
Native Git read and GitHub API read work; no extra GitHub secret is needed.
The Actions settings endpoint returned 403 but Actions run reads work: an admin
API denial is not a reason to request a new token. Actual CI availability is
established by push and run evidence, not by permissions metadata.

## New modules

- `tools/probe/lab_probe.c`: harmless Windows process/architecture smoke probe.
- `tools/lab/Build-Probe.ps1`: MSVC x64 build with warnings treated as errors.
- `tools/lab/Invoke-P01.ps1`: OS/security inventory, native smoke, installer trust,
  opt-in disposable Windows 11 fixture preparation; no Sandboxie installation/mutation.
- `tools/lab/validate_repository.py`, `tests/test_lab_tools.py`: source integrity
  and evidence structure tooling, independent of Windows security behavior.
- `.github/workflows/p01.yml`: Linux tooling plus Windows 11 ARM64 smoke.

No production IPC, helper, policy, target launch, recursive cleanup or feature UI.
See [status](STATUS.md) and [test report](TEST_REPORT.md) for current results.
