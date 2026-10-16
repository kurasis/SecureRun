# P08 — Lifecycle, cleanup and recovery

Current P09 dependency regression: DONE at
`f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`,
[run 38893340716](https://github.com/kurasis/SecureRun/actions/runs/38893340716).
Both targets passed all 38 actual lifecycle/recovery cases, with zero failures or actor failures. This includes interruption, native confirmation, generation, stale-root and unsafe-hook refusal checks.
All earlier dependencies passed on the same source. The
[manifest](../evidence/p08/manifest.json) binds original reports and every
protected source, including current lab tools. This closes P08 only;
complete matching full P09 proof remains pending. The sections below preserve
the original completion and historical regressions.


Status: DONE. Scope is P08 only. Matching P03–P07 regressions passed.

Runtime source: `74d86db6dc883e692dfc04c8185eee790bdcf0a9`.
Laboratories: Windows Server 2025 x64 and Windows 11 ARM64, with original Sandboxie
Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, upstream
`cdba7096240b93d79c5373aa81a75a1c5c71b883`.

## Resulting behavior

Persistent environments keep their workloads and data after manager exit.
Disposable environments keep data until an explicit Resume, Export or Delete
choice. Pending state is durable before import/dispatch and after independently
observed original-client activity. Existing data survives a mode change; no
startup/exit cleanup or host recovery is automatic.

Archive preserves the definition, data and application records and disables
managed launch/import. Unarchive revalidates current ownership, root and policy.
Reset retains the definition and application records, clears verified contents
and advances the environment generation. Boxed executable references become
unavailable until explicitly reimported. Remove clears contents before deleting
the original definition and owned application records; audit and the verified
empty root identity remain. Exact retention and archive restoration are described
in [Lifecycle and recovery](../LIFECYCLE_AND_RECOVERY.md).

The renderer supplies identifiers and intent. A native OS dialog names the
specific environment and UUID and states retention; Cancel consumes the private
plan without dispatch. The renderer cannot supply a confirmation boolean, raw
root, Prepare/Commit request or backend capability. Plans are bound to the current
owner, engine, generation, revision, roots and policy and expire after 60 seconds.

## Cleanup and recovery protocol

Only the P02-proven original QSbieAPI native deletion ABI is called. Its original
local DLL dependencies must match authenticated P02 hashes and valid signatures.
An independently owned namespace seal retains preauthorized metadata handles,
excludes existing writers, rejects hardlinks/reparse traversal and pins nonempty
directories against movement. Only kernel-confirmed delete-pending handles are
released. Bounded drain passes remain inside the active confirmed dispatch.

The ordinary-user controller survives UI exit, bounds the executor to one process
and 128 MiB and waits for its held process on every exit path before restoration.
Surviving objects retain original ACL/attribute restoration authority. COMPLETE
is published after controller restoration. There is no generic recursive root
deletion, custom shell delete, hook execution, host fallback, engine bundle or
privileged product helper.

Recovery inspects current identity and checked postconditions; it never replays
cleanup, definition deletion or launch. An uncertain partial cleanup retains and
archives data and advances its generation. A verified cleared reset or already
absent definition can reconcile metadata. UNKNOWN launch receipts remain UNKNOWN.
Old-generation import/export/cleanup operations cannot mutate new data, and
substituted staging files remain untouched. Reset preserves the exact retained
root ID on this supported upstream route; unexpected root recreation is blocked.

Scoped Stop audits current automation independently of cached eligibility,
certificates and WFP readiness. Unapproved hooks or inheritance block termination
until reviewed repair; the manager does not silently remove external settings.
Archive and disposable state govern managed workflows. Trusted external clients
remain outside the manager's atomic control; observed activity is included in
entire-box state. Full machine/power loss may remove live restoration authority;
unknown state remains blocked for explicit remediation, without a deletion or
forensic-erasure guarantee.

## Implementation map

- `crates/sandboxie-adapter/src/lifecycle.rs`: versioned contracts, retention rules,
  single-use intent and private durable operation journal.
- `crates/sandboxie-adapter/src/windows/provisioning/lifecycle.rs` and its `seal`
  module: original native cleanup, held restoration authority and recovery.
- Provisioning, control and file services plus native pickers: current lifecycle,
  generation, automation and disposable-state gates.
- `src-tauri` lifecycle commands and `ui/lifecycle.tsx`: constrained IPC, native
  confirmation and EN/RU retention/recovery controls.
- `.github/workflows/p08.yml`, `tools/lab/Invoke-P08.ps1`, `tools/probe/p08*` and
  `retain_p08_evidence.py`: actual Windows actors, interruption proof and strict
  source-bound retention. P03–P07 harnesses remain independently gated.

## Validation

All runs below use the same runtime source. Raw evidence and checksums are stored
in the corresponding phase manifests.

| Gate | Run | Native result per target |
|---|---|---|
| P03 | [38763953821](https://github.com/kurasis/SecureRun/actions/runs/38763953821) | 19 foundation, 2 normal native, 3 UI and 29 actual command-boundary cases passed |
| P04 | [38763957687](https://github.com/kurasis/SecureRun/actions/runs/38763957687) | 48 adapter tests and 19 native observation cases passed |
| P05 | [38763825315](https://github.com/kurasis/SecureRun/actions/runs/38763825315) | 48 adapter tests and 45 applicable native cases passed; one absent different-admin UAC route is Not applicable |
| P06 | [38763961970](https://github.com/kurasis/SecureRun/actions/runs/38763961970) | 21 Server / 22 ARM launch/control cases passed; zero failures |
| P07 | [38763966380](https://github.com/kurasis/SecureRun/actions/runs/38763966380) | 28 Server / 29 ARM file/boxed-EXE cases passed; zero failures or actor failures |
| P08 | [38763860037](https://github.com/kurasis/SecureRun/actions/runs/38763860037) | 38/38 native lifecycle and recovery cases passed on each target; zero failures or actor failures |

Local validation passed: 36 portable adapter tests, three UI tests/build, strict
Windows i686 metadata Clippy with `policy-ci`, PowerShell parsing/C# fixture
compilation, repository validation and 12 tooling tests. Native Windows execution
is established by Actions, not by Linux metadata compilation.
The final publication changes documentation, evidence and portable validator test
fixtures only; all recorded native runtime/harness source hashes remain exact.
Two negative tests were made independent of the prior BLOCKED phase state:
one explicitly blocks P07, and one verifies that even self-consistent altered
source checksums cannot replace the authenticated P02 cleanup inventory.

Reproduction commands:

```sh
python3 tools/lab/validate_repository.py
python3 -m unittest discover -s tests -v
cargo test --locked -p securerun-foundation
cargo test --locked -p securerun-sandboxie-adapter
npm run build
npm test
```

The native workflows execute `tools/lab/Invoke-P03.ps1` through `Invoke-P08.ps1`
on both owner-selected Windows runners. `retain_p03_evidence.py` through
`retain_p08_evidence.py` require `--download-directory`, `--tested-commit` and
`--run-id` and reject incomplete, failed or mismatched dependencies.


| Scenario | Applicable production proof |
|---|---|
| T06 | Background descendants keep the environment Running and prevent cleanup. |
| T18 | Seven Reset and eight Remove phases kill real held executors; recovery never replays deletion. |
| T24 | Native confirmation, hardlinks, junctions, existing writers and locked files fail safely; outside canaries survive. |
| T25 | Real normal-UI close/crash preserves workloads; imported and independently observed disposable state survives restart. |
| T26 | Forged/stale plans and a competing manager are refused; duplicate delivery does not mutate data. |
| T28 | Missing ownership and corrupt/foreign/future journals cannot adopt or delete an existing environment. |
| T33 | Direct/inherited automation and drift after confirmation are refused; actual host marker remains absent; unsafe Stop is blocked. |
| T34 | Moved/replaced roots are not adopted or cleared. |
| T36 | Actual same-owner session 0 and interactive-session members must both stop before cleanup. |
| T42 | Original SandMan coexists without automatic recovery/delete; independent original dispatch is refused while fenced. |
| T43 | A real imported boxed executable runs logically before Reset; its old reference cannot launch afterward. |
| T48 | Archive/Unarchive retain definition/data and revalidate restoration; packaging portions remain P11. |
| T55 | Missing/recreated roots remain blocked; provisioning regressions retain PendingRoot safeguards. |
| T56 | Old-generation requests/results cannot overwrite or mutate current state. |
| T61 | Reserved/accepted lost receipts retain UNKNOWN and never dispatch twice, including after Reset. |
| T64 | Actual post-rename export reconciles before Reset; stale recovery cannot alter the marked host file. |
| T65 | Substituted staging and stale import/export/cleanup journals leave replacement and new-generation canaries unchanged. |

## Investigations retained

Initial seal tests rejected a root with an appended empty component and disproved
restoration through root inheritance alone. Native tests established retaining
survivor authority and closing only delete-pending objects. Historical full runs
also exposed inaccessible fixture types, collapsed PowerShell worker argv and
native-dialog readiness races. Those raw reports remain under the P08
`investigation-*` directories and are not relabeled as successful current proof.

P05 run 38757785675 passed Server but refused ARM cleanup of an unreviewed
`WerFault.exe` in a fresh diagnostic scope. Its 43 passed/two failed ARM results
and safe refusal are retained under `p05/investigation-p08-2dcc0d6`. The identical-source retry (38760761111) passed standard-user provisioning but
failed the independent session setup (44 passed / one failed on ARM). Its raw
reports are retained under `p05/investigation-p08-2dcc0d6-retry`. The parent lacked
the actor failure report before session-ready; bounded diagnostic retention was
added in `74d86db6dc883e692dfc04c8185eee790bdcf0a9`. No process-image allowance or
safety gate was changed. Current-source regressions are pending.

The original 26 specification documents and all 66 final installed-candidate
acceptance entries remain unchanged. T48 packaging finishes in P11; final
installed-candidate acceptance remains P12. P09 is eligible only after this gate
closes. No P09 implementation, encrypted boxes, snapshots, root relocation or
engine uninstall is included.
