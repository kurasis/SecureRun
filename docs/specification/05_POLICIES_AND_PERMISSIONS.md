# Policies and Permissions

## Policy model

Policies are versioned declarative data, compiled by the backend using a tested engine-version adapter. Maintain both desired and observed effective values. No raw INI editor in v1. Store a fingerprint including relevant inherited settings/templates, not merely the owned section.

| Preset | Required behavior | Availability |
|---|---|---|
| Standard offline | Write virtualization, no target elevation, network blocked, configured sensitive-path exclusions | Only verified baseline capabilities |
| Standard online | Standard restrictions with network explicitly allowed | Warn that network access can disclose readable data and reach local resources |
| Privacy + hardened offline | Verified upstream privacy and hardening modes, network blocked | Eligible certificate and tested support required |
| Privacy + hardened online | Same modes with explicitly allowed network | Same eligibility; no implied LAN isolation |

Default to Standard offline and clearly disclose its read-access limitations. Recommend the stronger available preset in onboarding without requiring a purchase. Default clipboard/device behavior must follow a tested capability matrix; do not display a universal device-deny switch unless it is actually enforced.

Upstream documents separate Privacy Mode from Security Hardened Mode and mark both as certificate-dependent. Hardening alone does not establish default-deny host reads. See [Privacy Mode](https://sandboxie-plus.github.io/sandboxie-docs/PlusContent/privacy-mode/) and [Security Hardened Mode](https://sandboxie-plus.github.io/sandboxie-docs/PlusContent/security-mode/).

## Path permission meanings

| UI mode | Intended meaning |
|---|---|
| Block | Deny access to the selected resource, including reads |
| Read only | Read host contents; deny writes according to verified engine semantics |
| Isolated changes | Read allowed host contents; redirect changes into the box |
| Direct host write | Write real host data; unsupported in v1 |
| Import copy | Copy selected input into a private box workspace without a lasting host-folder grant |

`ClosedFilePath`, `ReadFilePath` and normal virtualization are distinct upstream concepts. `OpenFilePath` bypasses virtualization for matching resources and is not a synonym for safe write access. The applicability of open rules can depend on executable location. Resolve rule priority, process filters, inherited templates, wildcard semantics and path normalization from pinned source and behavioral tests. Do not translate the table to guessed INI lines.

Sources: [ClosedFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/ClosedFilePath/), [ReadFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/ReadFilePath/), [OpenFilePath](https://sandboxie-plus.github.io/sandboxie-docs/Content/OpenFilePath/).

Read-only is also a view change: `ReadFilePath` bypasses the boxed file overlay for the matching location, so previously stored boxed changes can become invisible there. Before switching a populated location to this mode, explain the view change and offer export; never delete those changes silently. Test return to the previous policy.

## Path and privacy rules

Use OS known-folder resolution, including redirected Documents/Desktop/Downloads and cloud-sync paths. Offer editable exclusions for personal documents, browser profiles and SSH/configuration secrets; changes show a policy diff. Never claim these selected exclusions cover all secrets. Manager control data, privileged code/configuration and other managed boxes are protected by a separate mandatory policy layer. A user grant, process-specific exception, imported setting or inherited template must not override that layer. Detect overlaps with executable/dependency locations and explain incompatibility without auto-granting the entire user profile.

Protect future sibling environments as well as those present at initial launch. P02 must prove a policy/storage layout that covers the managed storage namespace while preserving the active box's legitimate virtualized storage access; do not guess that a parent-path deny automatically has those semantics. If the chosen design instead requires updating existing boxes when a new root is added, creation must wait until every affected box is stopped and the new protection is applied and verified, before new private data is written. A running box must never have a window to read a newly created sibling's physical storage. Root relocation remains outside v1.

Path normalization at edit time is not permanent enforcement. Define supported alias/reparse semantics for rules, and test resolution after a directory is replaced. For grants, reject unsupported reparse or namespace indirection; for mandatory denials, require tested engine coverage across supported aliases. An inability to prove a mandatory denial blocks launch; an unsupported optional user path is rejected with a reason. Do not advertise an inode-based permission model when the adapter enforces path strings.

Reject arbitrary wildcard syntax in user-selected paths. Account for reparse points, UNC paths, device namespaces, short names, case-insensitivity and alternate streams. Reject unsupported paths instead of using a lexical prefix test. Block and grant interactions need canonical resource tests; parent/child precedence is not obvious from string order.

Standard-mode applications may retain broad host reads outside exclusions. Stronger profiles still need system/runtime exceptions; never describe them as seeing literally nothing outside the box. Browser sessions and downloaded executables must not gain new exceptions automatically.

## Network

v1 offers only `blocked` and `allowed`. Use the validated Sandboxie enforcement mechanism. Do not build a second firewall in the manager for v1. Establish exact network directive support and whether any engine-global prerequisite is needed during P02. A necessary global change requires explicit user review of its system-wide impact; if declined, disable dependent profiles.

The v1 blocked preset requires a source-reviewed kernel-enforced path. WFP is the default implementation choice. Upstream `NetworkAccess` can otherwise operate through bypassable user-mode hooks; do not equate matching syntax with equivalent enforcement. `NetworkEnableWFP` is global, and loopback/access gates are distinct. Therefore enabling WFP is an explicitly reviewed installation prerequisite when this adapter uses it, not a hidden per-box mutation. Do not change existing unmanaged rules or force-stop their workloads. See the upstream WFP and Network Access references in the source index.

Separately deny network-share file access in managed presets, including online presets, unless a future explicit feature adds it. `BlockNetworkFiles` is a filesystem control, not a firewall. Do not rely on SandMan's creation defaults when constructing boxes yourself. Verify SMB/UNC and mapped-drive access and reject opening exceptions. Online means network permitted, not permission to mount host shares.

For offline acceptance distinguish direct sockets, host-brokered requests (DNS service, COM/BITS where reachable), network filesystem requests and raw/ICMP paths allowed to an unprivileged target. DNS cache/hosts-file answers are not outbound traffic and need not fail. Use random names under a controlled test domain and server-side observation for DNS egress; host-independent background queries are not target leaks. If a tested supported path permits target-caused egress, the offline preset fails. Do not weaken its label to conceal the failure. Disable runtime Internet-approval exceptions for this preset.

The blocked profile must be tested for TCP/UDP, IPv4/IPv6, DNS, loopback, LAN and child processes. Use controlled endpoints; a failed request to an unavailable server is not evidence of blocking. Domain restrictions, IP allowlists, proxy-only networking and Internet-without-LAN are deferred.

## Applying changes

Policy changes require all environment processes stopped. Show that a restart is required; do not describe reload as retroactively securing running processes. Certificate expiration or drift blocks new launches, raises a visible status for existing processes and offers Stop. Never kill unrelated processes or claim that observing capability loss instantly revokes existing access.

Do not enable `NoSecurityIsolation`, `NoSecurityFiltering`, broad host access, unrestricted token behavior, or compartment-only modes in a security preset. Do not automatically disable browser protections to make compatibility tests pass.
