# Sources, Licensing and Open Risks

Initial checks: 2026-10-13 UTC / 2026-10-14 Asia/Dubai. Targeted process and filename references checked for revision 1.3 on 2026-10-14 UTC. Live documentation may change. Implementation MUST record the exact release tag and commit actually used. These references support technical facts; product behavior and acceptance requirements in this package are proposed design decisions.

## Primary references

| ID | Source | Why it matters |
|---|---|---|
| S01 | [Official source repository](https://github.com/sandboxie-plus/Sandboxie) | Engine, utilities and component source; Plus/Classic relationship |
| S02 | [LICENSE.Classic](https://github.com/sandboxie-plus/Sandboxie/blob/master/LICENSE.Classic) | GPLv3 terms |
| S03 | [LICENSE.Plus](https://github.com/sandboxie-plus/Sandboxie/blob/master/LICENSE.Plus) | Component-specific licenses and restrictions |
| S04 | [Isolation mechanism](https://sandboxie-plus.com/sandboxie/isolationmechanism/) | Restricted tokens, driver and compatibility mechanisms |
| S05 | [Start CLI](https://sandboxie-plus.github.io/sandboxie-docs/Content/StartCommandLine/) | Launch, PID listing, termination, cleanup, reload |
| S06 | [SbieIni CLI](https://sandboxie-plus.github.io/sandboxie-docs/Content/SbieIniCommandLine/) | Configuration utility |
| S07 | [SBIE DLL API](https://sandboxie-plus.github.io/sandboxie-docs/Content/SBIEDLLAPI/) | Possible native bridge; verify ABI against source |
| S08 | [Privacy Mode](https://sandboxie-plus.github.io/sandboxie-docs/PlusContent/privacy-mode/) | Privacy semantics and templates |
| S09 | [Security Hardened Mode](https://sandboxie-plus.github.io/sandboxie-docs/PlusContent/security-mode/) | Hardening semantics and entitlement |
| S10 | [ClosedFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/ClosedFilePath/) | Read/access denial |
| S11 | [ReadFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/ReadFilePath/) | Read-only resource policy |
| S12 | [OpenFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/OpenFilePath/) | Direct resource access and applicability |
| S13 | [Feature comparison](https://sandboxie-plus.com/feature-comparison/) | Current feature tiers; recheck before release |
| S14 | [WFP support](https://sandboxie-plus.github.io/sandboxie-docs/PlusContent/WFPSupport.html) | Kernel versus user-mode enforcement and global setup |
| S15 | [NetworkAccess](https://sandboxie-plus.github.io/sandboxie-docs/Content/NetworkAccess.html) | Rule precedence and coverage |
| S16 | [Network-share files](https://sandboxie-plus.github.io/sandboxie-docs/Content/BlockNetworkFiles.html) | Separate network filesystem control |
| S17 | [LockBoxToUser](https://sandboxie-plus.github.io/sandboxie-docs/Content/LockBoxToUser.html) | Root ACLs and documented global option |
| S18 | [DeleteCommand](https://sandboxie-plus.github.io/sandboxie-docs/Content/DeleteCommand/) | Legacy deletion command behavior |
| S19 | [SandMan triggers](https://sandboxie-plus.github.io/sandboxie-docs/Content/SandManTriggers.html) | Host-side automation and consumers |
| S20 | [Deletion lifecycle](https://sandboxie-plus.github.io/sandboxie-docs/Content/SandboxRemoval.html) | Root scope, cleanup and definition removal |
| S21 | [Microsoft: named-pipe security](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights) | Explicit IPC access control |
| S22 | [Microsoft: client process identity](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeclientprocessid) | OS-reported peer PID; insufficient alone for authentication |
| S23 | [Tauri capabilities](https://v2.tauri.app/security/capabilities/) | Custom application-command permissions and merged capabilities |
| S24 | [Microsoft: CreateProcessW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw) | Explicit executable identity, environment and working directory |
| S25 | [Internet-access prompts](https://sandboxie-plus.github.io/sandboxie-docs/Content/PromptForInternetAccess.html) | Interactive exceptions are distinct from network enforcement |
| S26 | [Microsoft: process handles and identifiers](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers) | Object handles versus transient PID observations |
| S27 | [Microsoft: TerminateProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess) | Handle access rights and asynchronous completion |
| S28 | [Microsoft: naming files and namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file) | Reserved names, path aliases, streams and case behavior |


Prefer release source when current docs and installed behavior differ. Record discrepancies and test them. Do not rely on a blog/forum claim for a security guarantee.

## Licensing position

The current LICENSE.Plus identifies core components as GPLv3, SandMan as custom-licensed, and QSbieAPI/MiscHelpers/Qt as LGPL components. Source availability does not mean the whole repository has one permissive license. Its custom terms include restrictions on commercial use and public distribution of modified binaries. Preserve this distinction.

v1 avoids copying SandMan, modifying engine binaries and bundling an engine distribution. The user separately installs an official engine and obtains any necessary upstream certificates. The manager does not offer paid features merely because their configuration names are known.

Before distribution, document exactly which code/libraries/binaries are copied, linked or redistributed and their obligations. A separate process/IPC design is an engineering choice, not an automatic legal exemption. If GPL code is incorporated into a derivative distribution, account for applicable corresponding-source and licensing obligations. Do not promise a proprietary distribution model until the actual integration is reviewed. No license for the new manager itself has been selected by the user.

Revisit licensing before any commercial release, engine bundling, source reuse, native bridge linking or rebranding. Keep original notices and use an original product name; do not imply endorsement by Sandboxie/Xanasoft.

## Open engineering risks and required resolution

| Risk | Default and resolution |
|---|---|
| CLI lacks complete effective-policy/identity APIs | P02 establishes source-backed API bridge or blocks affected feature |
| Configuration is shared with SandMan and other tools | Own only new boxes; detect drift; restrict concurrent editing; never claim atomicity across uncooperative writers |
| Privacy/hardening require entitlement | Optional gated presets; baseline remains available with honest limits |
| Certificate state cannot be reliably queried | Treat as unknown; disable dependent preset rather than guessing |
| Network mechanism has global prerequisites | Verify in spike; disclose global change or disable mode |
| Sandbox storage mapping varies by version | Use validated adapter mappings; do not guess paths |
| Desktop/clipboard/device isolation varies | Advertise only verified controls; show limitations |
| Unknown engine version after update | Revalidate compatibility manifest before new protected launches |
| No Windows test runner | Build safe pure components; release remains blocked |
| Production code-signing unavailable | Deliver clearly labeled development build; do not claim signed production readiness |
| Start.exe cleanup can invoke configured host commands | Validate consumer/settings and pinned built-in deletion route before every cleanup |
| Shared SID or default root ACL mistaken for isolation | Verify root DACL, cross-box engine restrictions and protected manager metadata |
| All-session data is incomplete | Block content mutation/removal; show Unknown activity |
| Offline data path includes host brokers or shares | Test those paths independently; do not infer from failed direct sockets |

The revision's Mark-of-the-Web, no-replace transfer, NTFS-only storage and conservative restart requirements are product design choices, not claims about automatic upstream defaults. Source review narrows uncertainty; the recorded runtime gates still need Windows validation.

## Design boundaries deliberately retained

The manager is not a secure file vault, malware verdict engine, secrecy guarantee against host administrators, or a replacement for OS security updates. Export and direct user grants intentionally cross the isolation boundary. Standard write containment cannot be advertised as complete confidentiality. These limits belong in concise product help and accurate status labels, not repetitive modal warnings.

Revision 1.3's enrollment boundaries, dispatch reservation, immutable policy layer and staged export protocol are manager design requirements. The cited API documentation supports the underlying semantics, not a claim that Sandboxie already implements these protocols or contains a demonstrated vulnerability. The exact helper authority source, scoped termination handler and future-sibling policy require P02 source review and Windows evidence.
