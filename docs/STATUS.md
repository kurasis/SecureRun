# Development status

Specification: 1.3. Updated: 2026-10-15 UTC. Requested scope: full P06.

| Phase | Status | Evidence / dependency |
|---|---|---|
| P01 | DONE (owner-selected Windows 11 ARM64 lab) | [P01 report](phases/P01_REPORT.md), retained provenance |
| P02 | DONE — representative feasibility gate | [P02 report](phases/P02_REPORT.md), [feasibility](FEASIBILITY_REPORT.md), [operation map](OPERATION_MAP.md) |
| P03 | BLOCKED — P06 regression pending | [P03 report](phases/P03_REPORT.md), [IPC contract](IPC_CONTRACT.md), retained native evidence |
| P04 | BLOCKED — P06 regression pending | [P04 report](phases/P04_REPORT.md), [observation contract](ENGINE_OBSERVATION.md), retained native evidence |
| P05 | BLOCKED — P06 regression pending | [P05 report](phases/P05_REPORT.md), [policy/provisioning contract](POLICY_PROVISIONING.md), retained complete native evidence |
| P06 | IN_PROGRESS | Production launch/control implementation; native exit gate pending |
| P07–P12 | NOT_STARTED | Depends on P06 |

The complete 26-document specification remains byte-for-byte unchanged.
Every mandatory adapter operation has a tested viable route on the owner-selected
disposable Actions laboratories: Windows Server 2025 x64 with actual x86/x64
target PEs, and Windows 11 ARM64 with native ARM64 and emulated x86/x64 target PEs.
Final source 0cf59a67041364209d6f42ac393db3ecaa73e044, run [38557903464](https://github.com/kurasis/SecureRun/actions/runs/38557903464):
49 Server and 62 ARM smoke cases passed; zero failed, blocked or not-run; two
explicit not-applicable cases per platform.

New evidence proves ordinary-user provisioning, parent/root replacement refusal,
same-SID processes concurrently in real Windows sessions 0 and 2, held-object stop,
future-sibling protection and sealed original-library cleanup. Used-definition
removal follows confirmed cleanup. No elevated product helper is needed for these
baseline routes. Redacted manager-owned diagnostics are proven; the optional native
engine access-event stream remains unavailable to an unsigned session reader.

These results complete P02 feasibility, not production acceptance. All T01–T66
remain NOT_STARTED and must run on the production paths in their owning phases.
No Windows 11 x64 production tuple is declared. Full network/broker, transfer,
recovery, stress and release security matrices belong to later phases. Paid
features remain disabled without verified entitlement. Original QSbieAPI cleanup
requires the documented runtime dependency/license assessment before distribution.

P03 adds the native application shell, typed domain/SQLite foundation and explicitly
scoped IPC. P04 adds trusted read-only observation while the ordinary shell remains
observation-only. At the completed P04 gate no production engine mutation, helper, user-target
launcher or installer was implemented. P05 now adds constrained user-owned
provisioning; its native gate is complete on both owner-selected laboratories. Target launch and installation
remain unavailable.
No SandMan implementation or engine binary is copied or bundled. All project
source, Markdown and reviewed JSON evidence are published as authorized by the
owner. Historical BLOCKED evidence is preserved separately in the [manifest](evidence/p02/manifest.json).

P03 final source 333e59cb6641fbcb3577c50f651fb9568df82140,
[run 38571221105](https://github.com/kurasis/SecureRun/actions/runs/38571221105):
both native Windows targets pass 19 foundation, 2 normal-configuration, 3 UI and
21 real command-boundary cases. [Raw reports/generated ACLs](evidence/p03/manifest.json)
are checksum-bound to the tested runtime sources. No required P03 gate remains
blocked; full production acceptance still belongs to later phases.

P04 final runtime source 682c3a346a46bca4fb4dfbbe07cf538d2afa8adb,
[run 38586140093](https://github.com/kurasis/SecureRun/actions/runs/38586140093):
both native targets pass 12 adapter tests and 19 production read-only scenarios.
The same source passes full P03 regression in [run 38586144696](https://github.com/kurasis/SecureRun/actions/runs/38586144696).
The ordinary desktop observes verified installed components and unowned boxes; it
exits before metadata when boxed, retains explicit Unknown service-process identity
for ordinary users, and exposes no product mutation or target launch. P05 is eligible.

P05 final runtime source a6cdbd1d8c5f3630d7a0b2c1d2426fdd042f5636,
[run 38648135812](https://github.com/kurasis/SecureRun/actions/runs/38648135812):
both targets pass 28 adapter tests and 45 applicable production policy/provisioning
scenarios with zero failed/blocked/skipped; one absent different-administrator UAC
route is accurately Not applicable per target. Fresh diagnostics use native and
genuine/emulated x86/x64 PEs. Ordinary-user provisioning/ACLs, real sessions 0/2,
future-sibling denial, metadata authority, incoming/outgoing network controls,
BITS denial and all seven real interruption checkpoints pass. No product helper,
user-target launcher or Windows security relaxation is introduced.

The same source passes complete P03 regression in
[run 38649287239](https://github.com/kurasis/SecureRun/actions/runs/38649287239):
19 foundation, 2 normal, 3 UI and 23 real command-boundary cases per native target.
It passes P04 regression in
[run 38649290153](https://github.com/kurasis/SecureRun/actions/runs/38649290153):
28 adapter tests and 19 production read-only observation cases per target.
Historical evidence remains immutable; all three current manifests bind the same
runtime sources. P06 implementation is now in progress. Its native gate and matching P03–P05
regressions must complete before P07 becomes eligible.
