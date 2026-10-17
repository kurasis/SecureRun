# SecureRun

An original Windows application isolation manager for a separately installed
official Sandboxie engine. SecureRun is not affiliated with Sandboxie or Xanasoft.

P01–P10 are complete on the owner-selected laboratories. P10 closes the internal
adversarial integration review: native diagnostic writes require fresh unboxed
context, all 17 commands are tested from forbidden origins, and boxed worker
families reject claimed host authority. The entire P03–P09 suite passed again on
Server 2025 x64 and Windows 11 ARM64 at the same verified runtime/lab source
`75b6c0bab24e7ea0edd86a3be2adea6648456a6b`.

Both full product runs passed 22 native scenarios and 101 UI assertions, including
actual diagnostic Save, file/policy/retention workflows, editor/archive/browser
compatibility and complete ten-environment/10000-file resource samples.

See [STATUS](docs/STATUS.md), [P10 report](docs/phases/P10_REPORT.md),
[internal security review](docs/SECURITY_REVIEW.md), [scoped T01–T66 results](docs/P10_TEST_REPORT.md),
[requirement traceability](docs/REQUIREMENT_TRACEABILITY.md) and
[measured budgets](docs/PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md). Server startup/CPU
and ARM CPU deviations retain their original targets and user-impact explanations.
Packaging and installed acceptance remain P11/P12. These laboratories do not
certify a Windows 11 x64 installed release or an independent security audit.

The interface builds on [lifecycle/recovery](docs/LIFECYCLE_AND_RECOVERY.md),
[safe files](docs/SAFE_FILE_WORKFLOWS.md), [launch/control](docs/LAUNCH_AND_PROCESS_CONTROL.md)
and [policy/provisioning](docs/POLICY_PROVISIONING.md). Archive/Unarchive,
confirmed Reset/Remove and inspect-only journal recovery preserve explicit user
intent and never resume work automatically.

The complete, unchanged specification is in
[docs/specification/00_README.md](docs/specification/00_README.md).
Development follows P01–P12. Production target launch is forbidden before P05 passes.

## Validate the repository

Python 3.12 or newer, no third-party packages:

```sh
python tools/lab/validate_repository.py
python -m unittest discover -s tests -v
```

## Windows lab

[Lab setup](docs/LAB_SETUP.md) covers GitHub Actions and a disposable Windows 11
x64 machine. The `P01 validation` workflow builds and executes a harmless native
probe and verifies the pinned official installer without installing a driver.
The Windows 11 ARM64 runner executes the x64 probe through Windows emulation.
P02 additionally installs the authenticated original native engine on Windows
Server 2025 x64 and Windows 11 ARM64, runs genuine native/emulated target probes
and computes the representative feasibility gate. [P02 report](docs/phases/P02_REPORT.md)
and [operation map](docs/OPERATION_MAP.md) describe the proven routes. This does
not declare native Windows 11 x64 release compatibility or product acceptance.

No manager license has been selected. No engine source or binaries are included.

## Application foundation

Windows prerequisites: Node 24.19+, Rust 1.90.0, MSVC C++ tools/Windows SDK and
Microsoft WebView2 Runtime. Use the existing checkout, then run:

```sh
npm ci --ignore-scripts
npm run tauri -- dev
```

For a bundled-assets executable without an installer:

```sh
npm run tauri -- build --debug --no-bundle
```

The normal configuration includes only the bundled main-window capability.
It exposes constrained policy/provisioning, safe file, lifecycle and registered application/Stop commands,
with fresh native authorization. It grants no generic shell/filesystem API or
test-report command. Engine control requires a protected application installation
and matching validated prerequisites; a development checkout is not trusted as
an installed manager.
The separately compiled foundation test feature is not a release build.
See [IPC contract](docs/IPC_CONTRACT.md) and [persistence](docs/PERSISTENCE.md).

Portable checks (no Windows driver or native GUI claim):

```sh
cargo test --locked -p securerun-foundation
cargo test --locked -p securerun-sandboxie-adapter
cargo clippy --locked -p securerun-foundation --all-targets -- -D warnings
cargo clippy --locked -p securerun-sandboxie-adapter --all-targets -- -D warnings
npm run build
npm test
```

The Linux cloud uses [setup-cloud.sh](tools/setup-cloud.sh); it pins and verifies
Rust installation, activates workspace-local caches and executes these checks.
Native Windows validation is reproduced by the P03–P09 Actions workflows on
Server 2025 x64 and Windows 11 ARM64, with actual x86/x64 target PEs.
The [observation contract](docs/ENGINE_OBSERVATION.md) describes the versioned
compatibility manifest, trust/context gates, private local diagnostics and bounded
native worker. Its observation-only interface cannot authorize launch; P06
uses the separate registration/dispatch service and durable operation journal.

Lifecycle implementation and current validation: [retention and recovery](docs/LIFECYCLE_AND_RECOVERY.md), [P08 report](docs/phases/P08_REPORT.md).
