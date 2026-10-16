# P09 application compatibility

The following official packages are pinned in
[the application fixture manifest](../tools/lab/p09-applications.json). Download
integrity is checked before installation or extraction. Exact executable hashes,
file versions and signature status are retained by each native run. Pinning and
compilation alone do not establish compatibility.

| Application | Exact package version | Architectures | Required actual workflow | Current result |
|---|---|---|---|---|
| Notepad++ | 8.9.8.1 | x64, ARM64 | Clean portable profile, real GUI edit and Save As, verify boxed bytes and unchanged host input | Passed on Server at `f9b719d`: actual keyboard edit, native Save As, exact boxed bytes and unchanged host data. Repeated on Server at `99abd22`; ARM and final matching full run remain pending. |
| 7-Zip | 26.04 | x64, ARM64 | Boxed file manager, official 7zG GUI create/extract, compare round-trip SHA-256 and absent host outputs | Actual workflow passed on both targets in focused run 38826425388; final matching full run pending |
| Firefox ESR | 153.5.0esr | x64, ARM64 | Separate clean host/boxed profiles, existing host instance, actual main/child HTTP attribution, reachable protocol handler, effective content sandbox | Partial: Server passed actual main/child HTTP attribution and the reachable boxed protocol handler at `9111127` after the recognized first-run welcome was dismissed. Effective content-sandbox observation, ARM and the final matching full run remain pending |

Owner-selected targets are Windows Server 2025 x64 and Windows 11 ARM64. The
matching P03–P08 production regressions also exercise x86 and, on ARM64, emulated
x64 target binaries. Native application results are reported per runner; they do
not certify every Windows edition, plugin, browser integration or future update.

Browser proof requires original-driver box membership, held process identity and
actual loopback socket ownership for requests. A process tree alone is not
containment proof. The synthetic host profile sets a positive-control cookie;
the boxed request must not carry it. A reviewed exclusion protects that host
profile. An explicitly registered synthetic protocol supplies an unboxed positive
control; the browser-reachable invocation must execute boxed and leave no host
marker. Firefox's own effective content sandbox must remain enabled. The lab
adds no browser sandbox-disable flag, privileged product helper or broad engine
exception. Only synthetic documents, profiles, requests and protocol data are used.

No engine binary or official application package is redistributed by the product.
The official 7-Zip package's pinned hash is mandatory even when its executable is
unsigned; Notepad++ and Firefox executable signatures must validate.

The authoritative result is the [P09 manifest](evidence/p09/manifest.json), which
must reference successful immutable evidence on both targets and matching source.

The window-class convention used by the editor fixture is verified against
[pinned upstream guiclass.c](https://github.com/sandboxie-plus/Sandboxie/blob/cdba7096240b93d79c5373aa81a75a1c5c71b883/Sandboxie/core/dll/guiclass.c#L124).
Only the expected native member's exact box prefix is accepted. The browser
protocol fixture activates a real HTTP canary link, and its own sandbox level is
read from actual about:support JSON or rendered text. Raw support content is not
retained. These automation corrections still require actual successful results.

Earlier diagnostic profiles forced Firefox accessibility, but neither the address
provider nor native navigation passed. That experiment is reverted. The current
browser fixture reads only native window captions, delivers real keyboard input
and observes synthetic address readback through a cleared clipboard before
navigation. Clipboard visibility is diagnostic only; fresh native page titles and
actual attributed requests remain mandatory. Only the known first-run welcome attempts UIA, with guarded native Windows OCR when that provider exposes no heading: the exact heading, terms, privacy notice and unique enabled Continue must match before interaction; diagnostic choices are observed off when available. The welcome must disappear before native navigation continues. Both targets exposed no welcome controls through UIA at `7a4000a`; Windows OCR positively recognized and dismissed the welcome on Server at `9111127`. Its actual child/protocol containment then passed; the own-sandbox and ARM gates remain pending. The same modal is observed in the reviewed real visible screenshots on both targets at `7ccda2b`. Manager
screen-reader/UIA checks remain mandatory. Actual requests, held driver membership,
protocol output and a positive observed about:support sandbox level remain required.
Server run 38862241469 had no observed browser GUI and retained a live WerFault
associated with SandboxieRpcSs.exe; no causal claim or successful browser workflow
is inferred from that failed run, and no reporter is killed or exempted.
