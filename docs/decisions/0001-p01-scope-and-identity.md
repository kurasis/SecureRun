# ADR 0001: P01 scope, identity and evidence

Date: 2026-10-14. Status: accepted for development.

The empty repository has no implementation to reuse. Use SecureRun as the original
working product name, without an endorsement claim. Retain Tauri 2, React,
TypeScript, Rust and SQLite as the P03 architecture; P01 does not add a UI or a
production launcher. Do not choose a redistribution license on the owner's behalf.

Reserve `SecureRun` for per-user metadata, `SecureRunLab` for disposable lab data,
and `SR_` for generated manager box names. A prefix is not authority. P02 must
verify upstream character/length limits; P05 must combine owner SID, engine state,
protected authority if needed, root identity and generation. No real boxes exist.

Future directories: `ui/`, `src-tauri/`, `crates/domain/`,
`crates/sandboxie-adapter/`, `crates/policy/`, `crates/file-transfer/`,
`tools/probe/`, `tests/windows/`. Create implementation directories when their
own phase needs them. Current C probe is lab-only, not the adapter.

The user requested GitHub Actions, then specifically Windows 11 ARM64 rather than
Windows Server. Use `windows-11-arm`, compiling a harmless x64 executable and
running it through OS emulation. This explicitly replaces P01's x64 lab default. Product support remains
unproven; the ARM64 distribution is a native lab candidate for P02. Emulation cannot validate an x64 kernel driver.
Do not install x64 Sandboxie on ARM64. Pin the official ARM64 installer separately
for lab feasibility; no engine installation or production support is claimed in P01.

All 26 uploaded specification documents are preserved unchanged. Their embedded
coding prompt asks for P02, but the current user request is limited to P01.
P02 runtime work and product implementation remain out of scope.
