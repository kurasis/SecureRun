# Threat Model and Security Invariants

## Trust boundaries

Trusted components: supported Windows installation and kernel, original Sandboxie service/driver and validated utilities, the manager's Rust backend and any narrow helper, approved dependencies. The frontend is a lower-trust command client. Box contents, target executables, filenames, process metadata and engine diagnostics are untrusted input.

Sandboxed code may deliberately attack exposed host resources, child-process handling, IPC, file export and cleanup. The manager must not become a privileged deputy for such code.

The host kernel is shared. This design does not promise resistance to kernel/driver exploits, an already compromised host administrator, physical access, all side channels or every GUI interaction. Ordinary desktop integration is not a guarantee against screenshots, input capture or every clipboard path. Unsupported isolation claims must not appear in the UI.

## Required invariants

| ID | Invariant |
|---|---|
| SEC-01 | Never launch an intended sandbox target outside the selected box, including on timeout, missing engine or certificate failure |
| SEC-02 | Apply and verify required policy before target execution; post-launch inspection is diagnostic, not the isolation mechanism |
| SEC-03 | Run UI and normal manager operations as the interactive user, never permanently as administrator |
| SEC-04 | Never execute commands, hooks or scripts derived from box contents, filenames, profiles or diagnostics on the host |
| SEC-05 | Never silently weaken restrictions for compatibility |
| SEC-06 | Limit configuration mutation, termination and deletion to verified manager-owned boxes |
| SEC-07 | Treat read protection, write virtualization and direct host write access as different properties |
| SEC-08 | The manager must not expose arbitrary filesystem, process-spawn or shell commands to the WebView |
| SEC-09 | Do not bypass upstream certificate checks or modify official binaries |
| SEC-10 | Do not use recursively deleting a user-provided path as sandbox cleanup |
| SEC-11 | Unknown enforcement state means unavailable, not enabled |
| SEC-12 | Exporting a file never implies that the file is safe |
| SEC-13 | Verify ownership, root identity, session coverage and lifecycle settings before every destructive action |
| SEC-14 | Never enable a hooks-only networking policy as a security-grade offline preset |
| SEC-15 | User-editable metadata and policies cannot expand privileged authority or remove mandatory isolation controls |
| SEC-16 | An ambiguous operation outcome never authorizes automatic launch replay, file replacement or path-based recovery deletion |

## Frontend containment

Use bundled local UI assets, a restrictive CSP, no remote executable content and no general shell plugin. Define narrowly scoped Tauri capabilities and typed backend commands. Deny new windows and external navigation by default; allow only approved documentation/download links opened through a dedicated URL validator. Render untrusted strings as text, not HTML. Do not load HTML, SVG scripts, thumbnails, file association handlers or Explorer preview extensions from a box.

Explicitly scope custom application commands, not only plugin commands. Upstream Tauri documentation notes that registered application commands are accessible to application windows/webviews by default unless application-command ACL configuration is added. Audit the merged effective capabilities and test every invoking window/origin; a restrictive plugin list alone is insufficient. See S23.

Frontend requests use registered application/environment IDs, expected revisions and backend-issued operation IDs, not arbitrary executable, root or destination paths. Resolve and authorize them again in Rust. File selections are captured by a backend-mediated native picker and bound to one operation with an expiry; a frontend boolean named `confirmed` is not proof of an authorized path. This reduces confused-deputy exposure but does not claim that a fully compromised authorized renderer cannot abuse all commands still intentionally granted to it.

## Privilege boundary

Prefer existing upstream utilities at user privilege. If configuration ownership or ACLs require elevation, use a short-lived signed helper invoked via ordinary Windows UAC. The elevated helper MUST accept a fixed schema of operations, authenticate the initiating user/session through an OS-protected IPC channel, reject sandboxed callers, validate ownership, and independently resolve trusted paths. A secret string alone is insufficient authentication. It must not accept arbitrary commands, DLL paths, INI keys or output paths from the caller. Minimize inherited handles and environment variables. No target EXE is ever launched by the elevated helper.

Do not introduce a permanent privileged service just to avoid prompts. If a helper is unnecessary for the validated backend, omit it. Denying UAC must leave configuration unchanged or visibly incomplete and nonlaunchable.

UAC may use a different administrator account. Preserve the original initiating SID/session and reject unexpected identity changes rather than resolving profile directories from the elevated helper's environment. Scope elevated operations to verified manager-owned resources for that initiator. Never launch the user's target, create its profile under the administrator's home, or treat an elevated helper's SID as the environment owner.

User-writable SQLite records, journal entries, UUIDs and ownership marker files are requests or observations, never independent authority for elevation. The helper must derive its allowed operations and resource scope from protected installation policy and independently verified engine/OS state. If persisted privileged ownership records are needed, create them under administrator-controlled ACLs through a constrained enrollment operation; never import their authority from the user's database. P02 must document a concrete enrollment design without arbitrary root selection, ACL templates or recursive ownership changes. P05 must implement it before elevated operations are enabled. A signed helper executable alone does not authenticate its inputs.

For privileged file/configuration operations, revalidate initiator, allowed resource identity and non-reparse ancestry at use, retaining safe handles where possible. Do not validate a path and later reopen it with broader privilege. Root substitution, replayed enrollment and forged metadata must not cause writes, deletion or ACL changes outside the authorized scope. The exclusion of a compromised unboxed same-user process from ordinary confidentiality guarantees does not permit user-controlled records to confer administrator authority.

The manager backend, native bridge and elevated helper must establish their own unboxed execution context through the trusted adapter before control-plane operations. A boxed instance must refuse mutation, target launch, export, cleanup and elevation; do not attempt to escape its box or relaunch itself on the host. Unknown context permits only static setup/error information and the minimum trusted read-only checks needed to resolve context. Check the IPC peer's context separately; the helper's own status is not evidence about its caller.

## Host-side manager data

Per-user ACLs do not distinguish a boxed process from an unboxed process sharing the same user SID. Protect manager database/WAL files, logs, UI assets and helper IPC with engine policy as well as filesystem ACLs; verify denied access from a boxed probe. A compromised unboxed same-user process is outside the baseline threat model; do not claim these ACLs isolate it.

For a named-pipe helper, use an explicit restrictive DACL, reject remote clients, validate the OS-reported peer process identity/creation time and user/session, and check its sandbox membership through the trusted adapter. Fail closed if identity cannot be established. Bind the request to the initiating manager operation; use bounded framing and replay rejection. Mutual peer verification matters: the manager must also reject a substituted helper endpoint. Never use caller-provided PID/SID as evidence. Do not elevate a request just because it came from the same SID. See the Microsoft references in the source index.

Manager metadata is not a vault. Protect it with appropriate per-user filesystem ACLs and do not expose it to boxed programs through exceptions. Store no target application secrets. Do not treat a UUID or box-name prefix as authentication. Record ownership with Windows user SID, local application metadata and verified engine identity; uncertain boxes are read-only.

Do not log raw target arguments, environment blocks, file contents, certificate payloads or configuration credentials, including in local debug logs, subprocess error captures and crash reports. Capture only bounded, allowlisted structured diagnostics and sanitize control characters before display or log serialization. Shared-bundle redaction is an additional control, not the first time secrets are removed. The arguments editor must disclose that command lines are not secret storage; warn against entering credentials. Automatic crash uploads are disabled.

## Launch and trust

Validate the original engine location and signature, including an appropriate catalog trust path for drivers where needed. Do not find executable utilities using PATH or a writable working directory. Hash/version mismatches trigger revalidation. Clear inherited credential-bearing variables from target environments by policy; never pass manager IPC tokens to targets.

Establish trust per component: an official distribution does not imply every ancillary file has an embedded signature. Require the driver to satisfy Windows code-integrity requirements; validate signed binaries normally and other necessary files against a trusted, pinned distribution manifest. A checksum fetched beside an untrusted binary is not independent authenticity evidence. Online certificate revocation checks may be unavailable; represent cached/offline trust accurately. Never tell users to disable Secure Boot, HVCI or signature enforcement. Install production manager/helper code in an administrator-controlled location if elevation is supported.

The engine's launch path must establish isolation before running target code. Confirm this during the adapter spike from source and tests. A subsequent PID check cannot repair an unsafe launch. If this property cannot be established, do not ship that adapter.

Network-off must prevent external and local network access in tested paths, including IPv4/IPv6 and child processes. Do not claim a global exfiltration guarantee: explicit export, user interaction and permitted IPC are separate channels.
