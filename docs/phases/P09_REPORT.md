# P09 — Product UX and application compatibility

Status: IN_PROGRESS. Requested scope: full P09 only.
Dependency: P08 passed on both owner-selected Windows targets; its exact-source
proof remains historical while P09 changes are validated.

## Implementation underway

The product groups real owned environments into Applications, Processes, Files,
Permissions, Activity and a separate Retention/recovery area. Activity and current
launch eligibility remain independent. Onboarding distinguishes missing,
untrusted, unavailable, restart-required, untested and verified engine states.
EN/RU appearance preferences remain presentation-only and grant no engine rights.

A bounded private history stores typed manager actions/outcomes, timestamps and
diagnostic IDs, with optional local environment identities. Shared diagnostics
exclude those environment identities and all paths, arguments, external error
text, certificate data and file contents. The exact bundle is shown before a
single-use, 60-second native Save choice; existing output is never replaced.
History retains at most 512 events for 30 days. Engine access auditing is not
claimed. Unverified context exposes session history without opening a persistent
production profile.

Permission edits can be queued in backend memory with their native selection
leases. They remain unapplied until an explicit fresh apply, complete stopped
scope and original policy checks. Selections expire after 60 seconds and are not
restored after restart. No automatic policy apply or launch replay is introduced.

## Implemented outputs

- [Product UX and accessibility](../PRODUCT_UX.md).
- [Application compatibility matrix](../APPLICATION_COMPATIBILITY.md).
- [Performance and minimized diagnostics](../PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md).
- Normal release Windows lab: `.github/workflows/p09.yml`, `Invoke-P09.ps1`,
  official hashed application fixtures and actual UIA/browser/job-accounting probes.
- Strict evidence retainer and repository gate reject missing cases, wrong native
  architectures, stale sources, exceeded budgets and missing matching regressions.

## Checks so far

Local frontend build, three foundation UI tests and four product helper tests pass.
The repository validator and 13 tooling tests pass. Portable Rust tests, Windows
adapter metadata Clippy and PowerShell/C# compile checks are recorded separately
from native execution. Earlier product builds passed on both Windows targets at
`ef2c4bd85830b6e1a486c0646e4e2e045f74a811` (Actions `38773439542`).
Full native product lab `38782723570` was submitted at
`53c8e58c1e4866fa02a417b44697e65443cbc2b9`; both release builds passed, then fixture setup failed because a script variable
conflicted with PowerShell HOME. No native product case executed. Original stage
JSON is retained under `investigation-53c8e58`; the fixture variable is renamed.

The subsequent run `38785005254` at `8a396083d79403ccca35a623beb5cef99ad7305f`
verified official application packages/signatures and prepared normal release
binaries on both targets. Each standard-user actor was refused by the backend
during fixture environment seeding. No product UX case completed. The immutable
structured results remain in `investigation-8a39608`; fixture diagnostics now
retain only the bounded backend refusal code and numeric seed position.

## Validation pending

Required native P09 proof: T30, T32, T41, T63 and T66; actual app versions and hashes;
keyboard/screen-reader semantics, themes, scaling and measured manager resource
budgets across Rust/UI/WebView processes. Full matching P03–P08 regressions remain
pending. Compile-only checks do not close the production phase gate.

P10 is eligible only after P09 closes. Packaging remains P11 and installed-candidate
acceptance remains P12. Original specification and acceptance entries are unchanged.
