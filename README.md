# SecureRun

An original Windows application isolation manager for a separately installed
official Sandboxie engine. SecureRun is not affiliated with Sandboxie or Xanasoft.

P01 and P02 feasibility are complete. The repository contains the Windows lab,
source-pinned native adapter spike and retained evidence; a production sandbox
manager is not implemented yet. Read [STATUS](docs/STATUS.md) for the phase boundaries.

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
