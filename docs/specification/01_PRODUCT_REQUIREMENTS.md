# Product Requirements

## User experience

A user creates an environment, chooses a tested policy, adds an executable, and launches it inside that environment. Persistent environments retain their isolated state. Disposable environments have separate engine identities and can be cleared after the entire environment stops. Applications inside one environment may share its data; separate applications needing separation require separate environments.

## Mandatory scope

| ID | Requirement | Acceptance |
|---|---|---|
| PR-01 | Detect the installed engine, version, installation path, driver/service health and available operations | Missing, unhealthy, untested and usable installations have distinct states |
| PR-02 | Create, rename display labels, inspect and remove manager-owned environments | Stable internal identities; unrelated boxes remain untouched |
| PR-03 | Register local EXEs, structured arguments and working directory | No command shell interpretation; Unicode and spaces work |
| PR-04 | Launch only through the validated Sandboxie backend | Engine failure never launches the target normally |
| PR-05 | Show engine-reported processes and environment state | Child processes included; stale information labeled |
| PR-06 | Stop a selected environment or all manager-owned environments | No global termination of other Sandboxie users' boxes |
| PR-07 | Persistent and disposable modes | Disposable cleanup waits for all processes and pending export decisions |
| PR-08 | File permissions and network on/off with effective-state reporting | Denied operations verified with benign probes |
| PR-09 | Import selected files, list isolated files, export selected files | No host-side execution, previews, or automatic export |
| PR-10 | Reset environment contents independently from deleting its definition | Visible destructive confirmation and postcondition check |
| PR-11 | Maintain local operations/error history and diagnostics | Explicitly distinguish manager events from engine access events |
| PR-12 | Recover from restart, incomplete configuration and failed cleanup | Reconcile with engine state before enabling actions |
| PR-13 | Detect configuration drift and capability loss | Affected launches blocked until resolved |
| PR-14 | Installation, upgrades and uninstall preserve user data by default | Upgrade rollback and retention behavior tested |
| PR-15 | Accessibility and localization | Keyboard access, readable contrast, non-color status labels, EN/RU strings |
| PR-16 | Protect manager-owned storage and separate environments | Root ACLs, root identity and cross-box access tested |
| PR-17 | Inspect all relevant Windows sessions before content operations | Partial enumeration never authorizes deletion or policy mutation |
| PR-18 | Show bounded resource/storage observations and low-space conditions | Large files/logs do not exhaust the manager; no invented hard quotas |

## Initial compatibility targets

Prove the engine adapter with a purpose-built benign Windows probe first. Then validate one portable text editor, one archive utility and one browser from official distributions. Record exact versions and hashes in the implementation's compatibility matrix. Browser testing uses a new isolated profile; do not import the user's real cookies, passwords, or sessions. Keep the browser's own sandbox enabled.

Applications requiring kernel drivers, anti-cheat, DRM, system-wide services, elevated installation, hardware control or host shell extensions are outside v1 support. A failed application must remain visibly unsupported. Do not promise that every EXE will run.

## Release tiers

For browser and single-instance applications, test with an existing unsandboxed instance already open. A launcher must not hand a URL or document to that instance. Host updater services, COM brokers, external protocol handlers and native-messaging integrations need explicit compatibility evaluation. A process tree alone is not proof that a brokered action stayed inside the box.

- **Standard isolation:** isolated changes, configured blocked locations, network policy, process controls. Explicitly state that general host read access can remain.
- **Privacy + hardened:** optional certificate-dependent preset, available only after support and enforcement are verified. Failure to activate must not fall back to Standard.

A user without an eligible certificate must still be able to use supported Standard features. Do not display Standard as full personal-data protection.

## Deferred features

Engine bundling, custom drivers, SandMan forks, encrypted boxes, snapshots/restore, full registry diff, domain allowlists, proxy injection, forced launching of arbitrary host programs, kernel-level file audit, external APIs, multi-user administration and shell extensions are deferred. Add them only after independent design and acceptance criteria.

## Performance targets

Measure the manager budget across its own Rust/UI/WebView2 process group, excluding Sandboxie and target applications; disclose those separately. Measure on 10 idle environments and with at least one populated box containing 10,000 files. Stream files larger than 4 GiB with 64-bit sizes; do not read them into memory. Use bounded queues, output capture and log retention. Disk-space monitoring is advisory and cannot guarantee a hard box quota; display that limitation. Host resource exhaustion is outside the containment guarantee.

Targets apply on a documented reference Windows machine and are engineering budgets, not engine guarantees: manager startup to interactive within 3 seconds, idle CPU below 1% average over 60 seconds, idle working set below 250 MB, process updates within 2 seconds, ordinary manager-added launch overhead below 1 second excluding engine/application startup. File lists use pagination or virtualization and cancellable background enumeration. Avoid scanning complete boxes on every refresh. Do not trade required checks for performance.
