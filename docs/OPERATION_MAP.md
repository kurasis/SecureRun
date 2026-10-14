# Initial operation map — P01

This is a research backlog, not an implemented API. All operations are UNRESOLVED.
P02 must fill exact executable/API, full source permalink/signature, privilege,
encoding, success/failure, timeout/cancellation, preconditions/postconditions and
Windows evidence. No ABI or engine setting is inferred from a logical name.

| Logical operation | Exact upstream route / privilege / encoding | Status | Required investigation |
|---|---|---|---|
| `detectEngine` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `queryCapabilities` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `listBoxes` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `readEffectivePolicy` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `createBox` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `applyPolicy` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `launch` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `listProcesses` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `terminateBox` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `queryRoots` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `clearContents` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `removeDefinition` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |
| `readDiagnostics` | Unresolved | NOT_STARTED | P02 pinned-source review and Windows probe |

[Integration contract](specification/04_SANDBOXIE_INTEGRATION.md) contains documented
CLI anchors only. Start/SbieIni source candidate:
https://github.com/sandboxie-plus/Sandboxie/tree/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/apps

Cross-cutting research: component trust/catalog handling, unboxed self-context,
all-session coverage, trusted host CWD and DLL search, password handling,
helper enrollment/protected authority if required, termination binding at dispatch,
future-sibling storage protection, effective policy inheritance, source-reviewed
kernel network blocking, fixed safe cleanup and virtual/physical file mapping.

Timeout means unknown outcome until reconciliation. No automatic launch replay,
host fallback, arbitrary shell API, numeric-PID kill fallback or path-based
recursive cleanup is implemented. Observe/mutate only verified owned resources.
