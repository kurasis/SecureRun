# Development status

Specification: 1.3. Updated: 2026-10-15 UTC. Requested scope: full P07.

| Phase | Status | Evidence / dependency |
|---|---|---|
| P01 | DONE — owner-selected Windows 11 ARM64 lab | [P01 report](phases/P01_REPORT.md), retained provenance |
| P02 | DONE — representative feasibility gate | [P02 report](phases/P02_REPORT.md), [operation map](OPERATION_MAP.md) |
| P03 | BLOCKED — P07 regression pending | [P03 report](phases/P03_REPORT.md), [current evidence](evidence/p03/manifest.json) |
| P04 | BLOCKED — P07 regression pending | [P04 report](phases/P04_REPORT.md), [current evidence](evidence/p04/manifest.json) |
| P05 | BLOCKED — P07 regression pending | [P05 report](phases/P05_REPORT.md), [evidence](evidence/p05/manifest.json) |
| P06 | BLOCKED — P07 regression pending | [P06 report](phases/P06_REPORT.md), [raw evidence](evidence/p06/manifest.json) |
| P07 | IN_PROGRESS | Safe file workflows; native implementation and verification in progress |
| P08–P12 | NOT_STARTED | Depend on P07 |

Final checked runtime: `c8d135da5ce403148e3e903036951ab9c947d8c1`.
All current phase gates must bind that same source and runtime-file hashes.
Historical raw evidence is immutable and remains separately retained.

## Current verification

| Phase | Actions run | Result on each owner-selected target |
|---|---|---|
| P03 | [38705476301](https://github.com/kurasis/SecureRun/actions/runs/38705476301) | 19 foundation, 2 normal native, 3 UI and 25 actual command-boundary cases passed |
| P04 | [38705479692](https://github.com/kurasis/SecureRun/actions/runs/38705479692) | 31 adapter tests and 19 native observation cases passed |
| P05 | [38705482872](https://github.com/kurasis/SecureRun/actions/runs/38705482872) | 31 adapter tests and 45 applicable native policy/provisioning cases passed; one absent different-admin UAC route is Not applicable |
| P06 | [38705476091](https://github.com/kurasis/SecureRun/actions/runs/38705476091) | 21 Server / 22 ARM production launch/control cases passed; zero failed/blocked/skipped |

Laboratories: Windows Server 2025 x64, build 26100, with actual x64/x86 target PEs;
Windows 11 ARM64, build 26200, with ARM64 and emulated x86/x64 target PEs.
Original installed Sandboxie Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, pinned
upstream `cdba7096240b93d79c5373aa81a75a1c5c71b883`.

P06 supplies native application selection/registration, structured argv/CWD,
prevalidated isolated launch, durable receipts without uncertain replay,
all-session process views and independently gated held-object Stop/Stop managed.
Both real interruption points, short-lived/background outcomes, PID-object races,
changed scope, unmanaged workload survival and actual session 0/2 Stop are proven.
The normal application contains no CI checkpoint activation or product privileged
helper. No Windows security setting is weakened and no engine binary is bundled.

The complete original 26-document specification is unchanged. All T01–T66 final
installed-candidate acceptance entries remain NOT_STARTED. Phase proof does not
complete P12. No Windows 11 x64 final release tuple, paid entitlement, general
export/reset/cleanup, installer or release compatibility certification is claimed.
Import/boxed-EXE mapping belongs to P07; lifecycle/recovery belongs to P08.

The owner authorizes publication of every project change, including Markdown and
reviewed JSON evidence, followed by normal merge after validation. Credentials,
private inventories and generated binaries remain excluded.
