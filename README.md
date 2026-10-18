# SecureRun

An original Windows application isolation manager for a separately installed
official Sandboxie engine. SecureRun is not affiliated with Sandboxie or Xanasoft.

P11 native development installers passed **28 installed cases and 81 production
tests on each of Server 2025 x64 and Windows 11 ARM64**. Their exact source is
`dd447fec88de966fa839b03fc0fd4eb6b41776a4` (run 39089078904).
The artifacts are **UNSIGNED DEVELOPMENT ONLY**; original-manager licensing has
not been selected. No engine or persistent elevated product helper is bundled.

**The P11 phase gate remains BLOCKED by current full P10 integration.** At source
`ffdaeb60bd8c9d707959435b910c6a1027ecb770`, run 39087328157 attempt 1 passed
P03–P08 on both runners but failed both P09 jobs: ARM refused an unreviewed live
WerFault during diagnostic cleanup; Server could not read actual Firefox
about:support sandbox state because the clipboard remained busy. Both original
failures are retained. One unchanged-source repeat reproduced the ARM refusal at
environment five; Server's repeat failed diagnostic Save filename readback before
Save confirmation (actual Firefox sandbox level 9 was observed). Full integration
finished with 13 successful jobs and 2 failed P09 jobs. No third blind repeat is planned. No final acceptance or successful dependency is inferred.

See [status](docs/STATUS.md), [installed test matrix](docs/P11_TEST_REPORT.md),
[development downloads/checksums](docs/DEVELOPMENT_ARTIFACTS.md),
[phase report](docs/phases/P11_REPORT.md), [build](docs/BUILD.md),
[install](docs/INSTALL.md), [retention](docs/UPGRADE_AND_UNINSTALL.md) and
[signing](docs/SIGNING.md). P12 and all final installed T01–T66 acceptance remain
NOT_STARTED. The laboratories do not certify a Windows 11 x64 installed release.

The complete, unchanged specification is in
[docs/specification/00_README.md](docs/specification/00_README.md).

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
