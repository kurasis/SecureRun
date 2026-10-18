# Build the Windows development installer

The P11 artifact is **UNSIGNED DEVELOPMENT ONLY**, product 0.3.0, packaging revision
0.3.0.11. It is not a signed production release. The original manager license is
not selected. See [licensing](LICENSE_INVENTORY.md) and [phase evidence](phases/P11_REPORT.md).

Use a clean checkout of the exact published source commit on Windows with Git,
Python 3.12+, native PowerShell 7, Visual Studio 2022 C++ desktop tools (including
x86 and the native x64/ARM64 compiler and Windows SDK), Rust 1.90.0 and Node
24.19.0/npm 11.9.0. ARM64 builds also require x64 cross-target libraries.
Use the existing checkout; no worktree is needed. Do not enable `foundation-ci`,
`policy-ci`, `VITE_FOUNDATION_CI`, or arbitrary Rust flags in a distributable build.

```powershell
git switch --detach <published-full-source-commit>
git status --short
./packaging/Build-P11.ps1
```

The script uses locked npm installation with scripts disabled and locked Cargo
builds. It builds the bundled React frontend and release manager with the pinned
Tauri CLI and no CI features. It includes the native policy/launch probes and box
launcher, x86 policy/launch probes, and on ARM64 the emulated x64 probes. These
fixed production components must remain together in a protected code directory.
The setup preflight is compiled natively with MSVC `/O2 /MT /W4 /WX`.

The unmodified official Inno Setup compiler, Microsoft C++ v14 redistributables
and Microsoft WebView2 bootstrapper
are HTTPS/SHA-256 pinned in [toolchain.json](../packaging/toolchain.json). Windows
Authenticode verification must succeed; the Microsoft prerequisite publishers must be
Microsoft. A changed upstream download fails the build. Update pins only through
an explicit reviewed compatibility change; do not disable TLS/signature/hash
checks. Network access to official GitHub/Microsoft endpoints, crates.io, npm,
Rust distribution servers and the pinned license-text sources is required.

Outputs are under ignored `artifacts/p11-packages/`: the baseline revision10 and
candidate revision11 installers, `SHA256SUMS`, private build tools/downloads and
the exact staged payload. Only the candidate is the current development package;
the baseline exists to test packaging upgrades of the same runtime/schema1.
`artifacts/p11/` contains publishable structured build/test reports. Generated
executables are published as Actions artifacts, never committed as source.

`package-manifest.json` records the source commit, architecture, feature set and
every payload file's SHA-256/size/PE machine/signature status. It excludes its own
hash to avoid circularity; the installed manifest is compared with the staged
manifest separately. `build.json` and `SHA256SUMS` bind each final installer.

These instructions reproduce the locked build procedure and contents. They do
not promise byte-identical installer output across different MSVC/SDK versions,
compiler timestamps or build directories. Record tool versions, source commit and
actual output hashes for each build. A rebuild is a new artifact requiring its
own installed validation; an old checksum is not an expected result to force.

Run portable checks with:

```powershell
python tools/lab/validate_repository.py
python -m unittest discover -s tests -v
python -m unittest discover -s packaging/tests -v
```

The disposable Actions-only `packaging/Invoke-P11.ps1` additionally installs and
tests the real package. It creates synthetic users/data, performs an official
WebView2 uninstall/reinstall on Server x64 to test the missing prerequisite,
preserves the Windows 11 ARM64 preinstalled runtime, and installs the
separately pinned Sandboxie engine for containment tests. Run it only on the
owner-selected throwaway laboratories; discard the VM afterwards. It is not an
end-user installation script. P12 owns final candidate acceptance.
