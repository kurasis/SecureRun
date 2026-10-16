# P09 application compatibility

Status: PASSED for the workflows and owner-selected laboratory tuples below.
Verified source: `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`;
[full run 38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449).
Both targets passed all 22 native cases and 101 UI assertions. The
[formal manifest](evidence/p09/manifest.json) binds original evidence and current
sources; independent P03–P08 regressions passed on the same exact commit.

| Official application | Exact package version | Architectures | Actual workflow | Result |
|---|---|---|---|---|
| Notepad++ | 8.9.8.1 | x64, ARM64 | Clean portable profile, native GUI edit/Save As, exact boxed bytes and unchanged host input/output | PASSED on both |
| 7-Zip | 26.04 | x64, ARM64 | Boxed file manager, official 7zG GUI create/extract, round-trip SHA-256 and absent host outputs | PASSED on both |
| Firefox ESR | 153.5.0esr | x64, ARM64 | Existing clean host instance, separate boxed profile, actual main/child HTTP attribution, reachable boxed protocol handler and effective own sandbox | All four cases PASSED on both; effective content sandbox level 9 |

Downloads and per-architecture package hashes are pinned in
[the fixture manifest](../tools/lab/p09-applications.json). Actual executable
hashes, file versions and signature status are retained in each native run.
Notepad++ and Firefox signatures must validate. The original 7-Zip package's
pinned hash is mandatory even when its executable is unsigned. Pinning/compilation
alone never establishes compatibility. No engine/application package is bundled.

The normal release manager, running as a Standard user, registered and launched
these applications through its real native controls. The manager workflow also
proved actual import/export hashes, collision rename preserving original bytes,
Archive/Unarchive/Reset with native UUID/retention confirmation, generation change,
empty reset root and unchanged host input/exports.

Browser proof requires original-driver box membership, a held live process birth
and actual socket ownership. A process tree or window title alone is insufficient.
The host profile supplies a positive-control cookie; boxed requests must not carry
it. A reviewed rule blocks reads of that host profile. An explicitly registered
synthetic protocol has an unboxed positive control; invocation through the actual
boxed browser link must run boxed and leave no host marker. Native child-link
navigation must produce its separately attributed request.

Firefox's own effective sandbox is read from actual about:support data through
its official copy control. Raw support text/JSON and clipboard content are not
persisted. Its known first-run welcome can use guarded Windows OCR only after
matching exact heading, terms, privacy notice and unique Continue on a freshly
owned window; disappearance is verified. No unknown surface receives input.
Browser preferences/arguments never disable its sandbox. Tests use synthetic
profiles, documents, requests and protocol data, not a user's private browser data.

Owner-selected targets are Server 2025 x64 build 26100 and Windows 11 ARM64 build
26200 with original Sandboxie Plus 1.18.6/core 5.73.6. Matching regressions include
actual x86 and emulated x64 binaries on ARM. Results do not certify every Windows
edition, plugin, host integration, paid capability or future app/engine update;
installed Windows 11 x64 acceptance remains P12.

Earlier failed and diagnostic-only trials remain in the manifest and
[investigation log](phases/P09_INVESTIGATION_LOG.md), including setup refusals,
archive timeouts and obstructed browser points. They are not combined to replace
the successful full final-source matrix. No reporter is killed/trusted/exempted,
unknown window hidden, OS security setting weakened or broad engine exception added.

The editor window-class convention is checked against
[pinned upstream guiclass.c](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/guiclass.c#L124).
Only the expected native member's exact box prefix is accepted. See
[UX/accessibility](PRODUCT_UX.md) and [performance/diagnostics](PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md)
for additional measured scope and limits.
