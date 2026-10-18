Current-source revalidation: **BLOCKED** after lab-only reporter-cleanup safety
changes to protected probe scripts. The fdad6d7 snapshot below passed; all original
component inventories, OS tuples and source lists are preserved.

Current P11 security refresh: **P02 DONE** on original Plus 1.18.8/core 5.73.8,
source `bde0890108a563f5d72eb8e57085be2b37177218`.
[Run 39110907921](https://github.com/kurasis/SecureRun/actions/runs/39110907921),
manager/lab source `fdad6d74998029ba244e7e41345a7c66a9837fc4`: Server 49 passed/2 N/A,
ARM 62 passed/2 N/A, zero failed/blocked. See [the current manifest](../evidence/p02/manifest.json)
and [engine security review](../P11_ENGINE_UPDATE.md). This is feasibility, not
final installed acceptance. The complete signed component inventories and observed
OS tuples match the prior fa9b89f security refresh byte-for-byte. Source inventory
references were refreshed from the actual newly retained originals; no pin changed.
Earlier source-specific results below are historical.

# P02 phase report

Status: DONE — representative Sandboxie feasibility. Requested scope: full P02,
using Windows Server x64 with x86 targets and Windows 11 ARM64. P01 remains DONE
with the owner's recorded lab adjustment. P03–P12 remain NOT_STARTED.

The full specification was studied beginning with 00_README; all 26 original
documents and their hashes remain unchanged. Attachment instructions describe
the product; the owner's explicit P02 request supplies the implementation scope.
Repository code, reports, commit messages and PR text are English; chat is Russian.

## Outputs and coverage

- [Operation map](../OPERATION_MAP.md): all 13 mandatory adapter operations,
  tested routes, pinned source permalinks, ABI/status, privileges and bounds.
- [Feasibility report](../FEASIBILITY_REPORT.md): enforcement, ordinary-user
  authority, session fixtures, storage seal, diagnostics and runtime licensing.
- [Candidate matrix](../ENGINE_MATRIX.md): both measured Windows laboratories
  and native/emulated PE targets; production availability remains unclaimed.
- [Workflow](../../.github/workflows/p02.yml), lab scripts and original source
  probes: native engine install/trust, explicit compilation, actual driver/service
  queries and benign containment tests. No copied SandMan code or engine binary.
- [Manifest and original JSON](../evidence/p02/manifest.json): exact tested
  checkout, current and historical outcomes, sizes/hashes and runtime source hashes.
  The retention tool verifies Actions provenance before copying bytes.

| P02 task | Completed representative result |
|---|---|
| Native adapter/pinned interfaces | Original exports, UTF-16, correct native/Win32 calling conventions, PE checks and exact statuses |
| Fail-closed creation/arguments/descendants/all sessions | Missing-box refusal, membership, exact synthetic argv, actual same-SID sessions 0/2 and rejected successful truncation |
| Network/file/read baseline | Verified kernel WFP with v4/v6 TCP/UDP controls, contained writes and selected read denials |
| Config/inheritance/root/mapping/lifecycle | Original IPC/password readback, ordinary-user PendingRoot/ACLs, parent/root replacement rejection, logical boxed EXE, sealed original-library cleanup and post-cleanup definition removal |
| Trust/entitlement/global prerequisite | Authenticated native installers/components, driver health, optional entitlement observation, fresh-lab-only WFP change |
| Mandatory operation classification | Every mandatory map operation PROVEN for the stated representative scope |
| Authority/context/stop/future roots | Ordinary-user routes without product helper, forged path refusal, boxed native/managed refusal, actual held-object dispatch boundaries and direct/junction future-sibling denial |

## Validation

Final tested source: 0cf59a67041364209d6f42ac393db3ecaa73e044.
[Actions run 38557903464](https://github.com/kurasis/SecureRun/actions/runs/38557903464),
2026-10-14 UTC: Server 49 passed and ARM 62 passed; zero failed/blocked/not-run;
two explicit NA each (optional engine access-event stream; absent product helper).
Both computed phase-result files are DONE and have empty gate_blockers.

Local commands: python tools/lab/validate_repository.py;
python -m unittest discover -s tests -v; git diff --check.
Seven tooling tests pass, including rejection of relabeled historical evidence.
Windows compile uses /W4 /WX and actual PE-machine validation. Original JSON CRLF
bytes are retained without Git normalization and bound by SHA256/size.

Representative T01/T05/T08/T09/T12/T33/T35/T36/T55/T57/T58/T60/T62 are executed,
plus additional interface/lifecycle probes. All 66 production acceptance scenarios
remain NOT_STARTED. This closes the P02 gate without claiming production launch,
full adversarial acceptance or a supported release tuple.

The previous PR #2 delivered BLOCKED research. This continuation resolves its
ordinary-user, same-SID session, root/descendant boundary, external-launch fence
and termination feasibility gaps. Manager-owned diagnostics meet the mandatory
diagnostics route; an upstream-only internal access-event stream stays unavailable.
Full network/recovery/release tests and distribution decisions remain owned by
later phases, as required by the specification.

## Publication and next phase

All project source, Markdown and reviewed JSON evidence are pushed and normally
merged as authorized by the owner; credentials and generated binaries are excluded.
Publication: [PR #3](https://github.com/kurasis/SecureRun/pull/3).
No force push, branch-check override or security-setting weakening is used.

P03 is now eligible. This request implements only P02: no production application,
helper, target launcher or installer has been added. The Windows 11 x64 native
release compatibility gap and hosted security observations remain explicit.
