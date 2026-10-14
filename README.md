# SecureRun

An original Windows application isolation manager for a separately installed
official Sandboxie engine. SecureRun is not affiliated with Sandboxie or Xanasoft.

This repository currently contains the P01 repository and lab foundation, not a
working sandbox manager. Read [STATUS](docs/STATUS.md) for exact evidence and blockers.

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
This does not validate the x64 Sandboxie kernel driver or x64 engine compatibility.

No manager license has been selected. No engine source or binaries are included.
