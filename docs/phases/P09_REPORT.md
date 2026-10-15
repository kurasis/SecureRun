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

A subsequent run `38787517417` at `53410943b28f54b8dfb2859446f0a5bf1950ee6d`
identified Server refusal `SIBLING_RECONCILIATION_REQUIRED` at environment 06 and
ARM refusal `NETWORK_ENFORCEMENT_FAILED` at environment 03. Both raw structured
investigations are retained. The fixture now retains existing minimized native
probe result/status/evidence reports for the network investigation.

A deterministic portable regression reproduced different mandatory sibling denial
ordering during rollout and after the SQLite UUID-ordered listing. Canonical
ordering fixes it without changing rule membership or granting access. A second
regression creates ten environments and revalidates every existing policy after
each creation. The adapter's 40 portable tests pass; native validation is pending.
The reference workload also requires more than 64 architecture-specific retained
diagnostics. The bound is now 256. Successfully verified private diagnostic
definitions retire after fresh identity/configuration/automation/idle checks;
root data and audit records remain, and the saved synthetic report is checked
unchanged. Failed diagnostics stay fenced. P09 verifies these actual boundaries.

Intermediate P03 run `38786046681` at `8b71cae6d9188e9d16986486893b1f5ce4c2ff74`
passed on both targets: 19 foundation tests, 3 normal native tests, 3 foundation UI
tests and 32 actual command-boundary cases. It is historical, not matching final
source proof. Current product/native jobs are running at
`c5cd614f7b98485a287cc6d489b649e095dd4157` (`38789783607` and `38789783651`).

Both native product builds at `c5cd614f7b98485a287cc6d489b649e095dd4157`
passed 52 adapter tests per target. The full run `38789783651` reached environment
08 on Server, then hit the 120-second policy deadline. ARM environment 03 failed
an unboxed endpoint positive control before that canary was dispatched. Original
minimized numeric/boolean probe reports remain in `investigation-c5cd614`.
No product UX case completed. The next run uses a bounded 600-second full-rollout
deadline, a three-second unboxed control handshake with no request retry, and
safe endpoint-kind/stage/numeric failure evidence. Partial actor results are now
retained even on an actor timeout. Current runs at
`ce6098f1cad4cc36aa1dacaf96aaeb0628c94bae` are `38792628918` (build) and
`38792629133` (full native lab).

## Validation pending

Required native P09 proof: T30, T32, T41, T63 and T66; actual app versions and hashes;
keyboard/screen-reader semantics, themes, scaling and measured manager resource
budgets across Rust/UI/WebView processes. Matching P03/P04 regressions passed on both targets at `ce6098f`;
P05–P08 remain pending. Compile-only checks do not close the production phase gate.

P10 is eligible only after P09 closes. Packaging remains P11 and installed-candidate
acceptance remains P12. Original specification and acceptance entries are unchanged.

## Native display-scaling investigation

The actual Windows Settings provider exists on both hosted runners. Initial
discovery run `38794729595` passed. Run `38794886663` selected 100 percent and
observed 96 DPI, but the initial visible dropdown exposed only 100/125 percent.
It therefore failed to establish required Windows 150/200 percent coverage.
The next read/select-only public-provider investigation (`38795120675`) checks
advertised display resolutions before selecting scale. These disposable display
changes do not modify Windows security settings. WebView content zoom remains
separate and does not satisfy this missing native DPI evidence.

All 212 retained P09 investigation files were checked against their committed
Git blob bytes and manifest SHA-256 hashes after publication.

## Product sampler and display investigation update

Server run `38792629133` at `ce6098f` successfully seeded ten real verified, idle
environments and 10,000 files, with 110 successful diagnostic definitions retired
while retaining all synthetic reports and root data. The sampler then encountered
an InvalidOperationException; the next version distinguishes a verified exited
process from an unmeasurable live process, which still fails. The UIA startup
upper bound was 6349.9831 ms, above the 3000 ms target; no timing success is claimed.
The next watcher prewarms the actual desktop provider before starting the clock
and records native-window appearance separately. Required checks remain intact.

A local real-WebSocket transport reproduction proved that PowerShell emitted
VoidTaskResult alongside the CDP reply. Suppressing the void return restores a
single typed reply. This is transport verification, not Windows product evidence.

Display run `38795996049` observed 96/144/192 DPI on both runners after selecting
the advertised 1600x1200 mode. Returning to 100 percent passed on Server but failed
on ARM due to a virtualized dropdown item. Public ItemContainer/VirtualizedItem/
ScrollItem patterns now handle that case. Product-window DPI proof is still
required. The full gate now requires all twelve real DPI layouts separately
from content zoom. Four-box focused diagnostics cannot be retained as DONE.

P07 regression `38793653374` passed both targets. P06 `38793649785` passed Server
but ARM sessions prerequisites failed with ENDPOINT_POSITIVE_CONTROL_FAILED.
Full matching dependency evidence therefore remains blocked.
