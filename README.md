# SecureRun

An original Windows application isolation manager for a separately installed
official Sandboxie engine. SecureRun is not affiliated with Sandboxie or Xanasoft.

P01 and P02 feasibility are complete; P03 adds the native application foundation,
SQLite persistence and a scoped IPC boundary. The shell currently offers read-only
setup until trusted engine observation is implemented. Read [STATUS](docs/STATUS.md)
for the exact phase evidence. No production user-target launcher exists yet.

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
It has no engine execution, generic shell/filesystem API or test-report grant.
The separately compiled foundation test feature is not a release build.
See [IPC contract](docs/IPC_CONTRACT.md) and [persistence](docs/PERSISTENCE.md).

Portable checks (no Windows driver or native GUI claim):

```sh
cargo test --locked -p securerun-foundation
cargo clippy --locked -p securerun-foundation --all-targets -- -D warnings
npm run build
npm test
```

The Linux cloud uses [setup-cloud.sh](tools/setup-cloud.sh); it pins and verifies
Rust installation, activates workspace-local caches and executes these checks.
Native Windows validation is reproduced by the P03 Actions workflow.
