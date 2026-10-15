# Development status

Specification: 1.3. Updated: 2026-10-15 UTC. Requested scope: full P07.

| Phase | Status | Evidence |
|---|---|---|
| P01 | DONE — owner-selected Windows 11 ARM64 lab | [P01 report](phases/P01_REPORT.md) |
| P02 | DONE — representative feasibility gate | [P02 report](phases/P02_REPORT.md), [operation map](OPERATION_MAP.md) |
| P03 | DONE — current P07 dependency regression | [P03 report](phases/P03_REPORT.md), [manifest](evidence/p03/manifest.json) |
| P04 | DONE — current P07 dependency regression | [P04 report](phases/P04_REPORT.md), [manifest](evidence/p04/manifest.json) |
| P05 | DONE — current P07 dependency regression | [P05 report](phases/P05_REPORT.md), [manifest](evidence/p05/manifest.json) |
| P06 | DONE — current P07 dependency regression | [P06 report](phases/P06_REPORT.md), [manifest](evidence/p06/manifest.json) |
| P07 | DONE | [Safe file protocol](SAFE_FILE_WORKFLOWS.md), [P07 report](phases/P07_REPORT.md), [manifest](evidence/p07/manifest.json) |
| P08–P12 | NOT_STARTED | Next eligible phase: P08 |

Current tested runtime: `bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68`.
All P03–P07 gates bind this same commit and current runtime-file hashes.
Reviewed original JSON, binary provenance and failed investigations are retained
with checksums; historical reports are never relabeled as current proof.

## Current verification

| Gate | Actions run | Result on each owner-selected target |
|---|---|---|
| P03 | [38729076831](https://github.com/kurasis/SecureRun/actions/runs/38729076831) | 19 foundation, 2 normal native, 3 UI and 27 actual command-boundary cases passed |
| P04 | [38729079754](https://github.com/kurasis/SecureRun/actions/runs/38729079754) | 38 adapter tests and 19 native observation cases passed |
| P05 | [38730156869](https://github.com/kurasis/SecureRun/actions/runs/38730156869) | 38 adapter tests and 45 applicable native cases passed; one absent different-admin UAC route is Not applicable |
| P06 | [38729083037](https://github.com/kurasis/SecureRun/actions/runs/38729083037) | 21 Server / 22 ARM launch/control cases passed; zero failures |
| P07 | [38729086335](https://github.com/kurasis/SecureRun/actions/runs/38729086335) | 28 Server / 29 ARM file/boxed-EXE cases passed; zero failures or actor failures |

Laboratories: Windows Server 2025 x64, build 26100, with actual x64/x86 target PEs;
Windows 11 ARM64, build 26200, with ARM64 and emulated x86/x64 target PEs.
Original Sandboxie Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, pinned upstream
`cdba7096240b93d79c5373aa81a75a1c5c71b883`.

P07 supplies inert bounded file browsing, explicit regular-file import/export,
boxed-EXE registration and validated logical launch, marker-before-payload,
streaming no-replace publication, cancellation, inspect-only recovery and explicit
identity/generation-bound staging discard. Native proof includes five real crash
windows, a 4,296,015,873-byte sparse transfer with matching SHA-256, real disk
exhaustion, actual case/8.3 collisions and independently launched live external
engine activity. P06 launch/receipt/Stop safeguards remain independently gated.
No Windows security setting is weakened and no engine binary is bundled.

The original 26-document specification is unchanged. All T01–T66 final installed-
candidate acceptance entries remain NOT_STARTED until P12. Phase proof does not
complete release acceptance. Reset generation advancement and the reset portion
of T43 finish in P08; packaging remains P11. No Windows 11 x64 release tuple,
paid entitlement or release certification is claimed by Server/ARM laboratory proof.

The owner authorizes publication of every project change, including Markdown and
reviewed JSON evidence, followed by normal merge after validation. Credentials,
private inventories and generated binaries remain excluded.
