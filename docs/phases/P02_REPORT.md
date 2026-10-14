# P02 phase report

Status: BLOCKED. Requested scope: full P02 on Windows Server x64/x86 target probes
and Windows 11 ARM64 with native/emulated target probes. Dependency P01 remains
DONE with its recorded owner-selected lab adjustment. P03–P12 are NOT_STARTED.

The complete attached specification was read beginning with 00_README; its
26 original documents/hashes remain unchanged. Attached coding instructions are
product material; the owner's explicit P02 request supplies this phase's scope.
Repository prose/code/commits are English; user communication is Russian.

## Deliverables

- [Operation map](../OPERATION_MAP.md): every mandatory operation, full pinned
  source routes, signatures/ABI, statuses, privileges, bounds and reconciliation.
- [Feasibility report](../FEASIBILITY_REPORT.md): selected worker strategy,
  enforcement evidence, cleanup/storage findings, helper authority and licensing.
- [Candidate matrix](../ENGINE_MATRIX.md): actual tested OS/engine/target tuples;
  no supported production tuple is declared.
- [Windows lab workflow](../../.github/workflows/p02.yml) and original source-only
  probes in tools/lab and tools/probe; no SandMan code or engine binaries copied.
- [Evidence manifest](../evidence/p02/manifest.json): exact checkout/run provenance,
  file checksums and original structured Windows evidence.

## Task coverage

| P02 task | Result |
|---|---|
| Disposable native adapter and pinned interfaces | Implemented; true PE architecture checks, original DLL ABI and source-reviewed outcomes |
| Fail-closed launch/arguments/descendants/all-session enumeration | Positive native/emulated probes; successful truncation rejected; same-SID second interactive session BLOCKED |
| Kernel network/file/read baseline | Representative loopback IPv4/IPv6 TCP/UDP controls, virtual writes and selected read denials; broader baseline tests UNRUN |
| Config/inheritance/roots/mapping/cleanup | Native IPC/readback, private root ACLs, mapping and narrow native cleanup spike; hostile cleanup/root race proof BLOCKED |
| Trust/entitlement/WFP/password | Authenticated installer/components, native health, original entitlement-state query with optional profiles disabled, disposable WFP prerequisite, synthetic private-IPC password test |
| Mandatory operation classification | Every map entry has observed evidence or explicit unresolved scope and resolution |
| Helper/context/stop/future roots | Actual boxed bridge refusal, fixed-root authority rejection, retained-object stop, stop-before-materialization with junction alias; helper absent, authority/hostile-race variants BLOCKED |

## Validation and evidence interpretation

Run locally: `python tools/lab/validate_repository.py`,
`python -m unittest discover -s tests -v`, `git diff --check`.
Tooling tests: six executed, six passed. These verify repository integrity, not
Windows containment. Windows uses MSVC /W4 /WX and explicit target/library paths.
The tested runs, exact source SHAs, per-run smoke counts and raw files are recorded
in the manifest and [test report](../TEST_REPORT.md).

T01/T05/T08/T09/T12/T33/T35/T36/T55 and T57/T58/T60/T62 are represented by actual
feasibility cases, with partial/blocked variants retained. Additional T02/T04/T16/
T19/T24/T25 probes establish concrete interface routes; none is product acceptance.
The canonical T01–T66 catalog remains NOT_STARTED. A successful Actions job means
collection completed; phase-result.json remains BLOCKED even if representative
cases pass because the required unresolved variants are not silently waived.

Earlier architecture mislabeling, wrong Win32 alias/calling convention, Boolean
width, raw config readback, empty-string removal, unboxed mapping and NT relative
root-name errors were corrected and rerun. They are not supported-engine failures
or evidence for the final code. Only exact current code/run provenance is used for
current smoke claims. The missing GitHub connection interrupted publication; it
was refreshed, not bypassed. No credential values were exposed.

## Exit gate and handoff

P02 is not DONE. Concrete blockers and proposed resolutions are in the feasibility
report: same-SID interactive sessions; protected ordinary-user provisioning;
root/descendant replacement and external launch exclusion; hostile cleanup and
termination fault variants; complete baseline release coverage, engine-signed log-reader integration and runtime-library
licensing decision. Happy-path native cleanup cannot waive those boundaries.

Next eligible work is to resolve the remaining P02 lab/protocol gates. A standard
hosted Server job plus an ARM emulator does not establish Windows 11 x64 kernel
compatibility. No P03 scaffolding, production user-target launch or release occurs.
Publication is authorized automatically by the owner and must preserve normal
branch checks; push/merge references are recorded after successful publication.
