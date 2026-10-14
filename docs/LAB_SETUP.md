# Disposable Windows lab — P01

## Current runner and exact boundary

Per the owner's instruction, `.github/workflows/p01.yml` uses the public GitHub
`windows-11-arm` hosted runner. It is a fresh Windows 11 ARM64 job, not Windows
Server. The script builds an x64 probe using the installed Visual Studio C++
tools and runs it via Windows application emulation. No extra emulator, x86
sandbox, VM download, engine installer execution or driver workaround is needed.
Exact build, architecture, hypervisor observations, security observations, source
commit and timestamps are emitted to `inventory.json`. Unknown observations
remain UNKNOWN. Workflow artifacts contain the probe and JSON evidence only.

Official runner reference:
https://docs.github.com/en/actions/reference/runners/github-hosted-runners
and image inventory:
https://github.com/actions/runner-images/blob/main/images/windows/Windows11-Arm64-Readme.md

**This is a tooling lab.** It cannot load the pinned x64 Sandboxie driver through
user-mode emulation. It is not a supported Windows/engine tuple and cannot close
P02 containment tests. Windows 11 x64 disposable VM/PC remains the runtime lab
prerequisite. An ARM64 engine would require a separately approved platform design
and new source/trust/ABI evidence, not silent substitution.

## Reproduce the hosted checks

Push changes or use the `P01 validation` workflow dispatch. The workflow checks
out the exact manager commit, validates source-only outputs, then runs:

```powershell
./tools/lab/Invoke-P01.ps1
```

Equivalent local prerequisites: Windows 11 ARM64 or x64, PowerShell 7, Git,
Visual Studio 2022 C++ tools for the x64 target and the Windows SDK. In the
repository, run the same command. It builds only lab_probe.exe, runs it, downloads
the pinned installer over verified HTTPS and checks size, SHA256 and Windows
Authenticode status. It never executes that installer. A bad or unknown signature
fails the check; do not bypass it. The Windows trust result is platform validation,
not independent proof of every distribution component. Installed component trust,
including catalog trust for the driver, belongs to P02/P04.

Retain `artifacts/p01/{inventory,probe,installer-trust}.json` with exact workflow
run/job URL. Artifacts are retained for 14 days; commit reviewed non-sensitive
JSON results and links to docs/evidence before expiration. Do not commit binaries,
certificates, machine names, usernames, SIDs, real paths or credential values.
No diagnostic environment dump is performed.

## Required x64 engine lab

Provision a disposable Windows 11 x64 VM with 4 vCPU, 8 GiB RAM, 40 GiB disk,
local fixed NTFS, a serviced OS build, normal Secure Boot, driver signature
checks, Defender and existing HVCI settings preserved. No real host shared
folders, clipboard sync, personal accounts or production credentials. Record the
hypervisor/version and a clean snapshot ID manually in local evidence. A PC is
acceptable only with dedicated synthetic accounts and a restorable backup.

Install Visual Studio C++ tools/Windows SDK, Git, PowerShell 7 and official
WebView2. Run `./tools/lab/Invoke-P01.ps1 -DedicatedLab`. The dedicated switch
requires Windows client build >=22000, native AMD64 and NTFS. It creates a unique
`%LOCALAPPDATA%\SecureRunLab\runs\<random UUID>` with host-canaries, import,
export and evidence directories, and one synthetic marker. This is not an ACL
or containment pass. Review the captured security state, attach backup/snapshot
identity and hash the probe. A required protection reported UNKNOWN needs a
read-only administrative observation; never change settings just to pass.

Download/install only the official pinned engine, after installer trust succeeds,
inside that dedicated VM. Record actual component file versions, hashes, embedded
or catalog signatures, service/driver health and reboot state. P01 records the
candidate; P02 source review decides which fixed benign operations can run.
Never install a kernel driver on the cloud Linux machine or ARM emulation runner.
No WFP/global engine setting changes are part of P01.

## Fixture contract for P02

All fixture identifiers are generated per run. Never derive deletion authority
from these names. Do not run arbitrary probes in previously used boxed state.

| Fixture | Definition and bound | Teardown |
|---|---|---|
| Host file canaries | Unique lab run root, UTF-8 synthetic marker, hash before/after; no real Documents | Revert snapshot |
| Registry | HKCU\Software\SecureRunLab\<run UUID>, synthetic values only | Revert snapshot |
| Boxes | Fresh diagnostic namespace SR_LAB_, no unmanaged box modification; upstream limits unresolved | P02 reviewed cleanup or revert |
| Second user/session | Local standard accounts SRLabA/SRLabB, two concurrent sessions where supported; no production login | Revert snapshot |
| Loopback TCP/UDP | 127.0.0.1 and ::1 port 38081, dedicated echo listener, positive unboxed control | Stop only owned listeners |
| LAN TCP/UDP | Isolated companion VM, port 38081, private VLAN/virtual switch, record actual IPv4/IPv6 | Revert both VMs |
| DNS/egress | Companion controlled resolver and authoritative test domain (reserved `.test` on isolated lab network); unique nonce query and server capture | Stop owned services, revert |
| Incoming traffic | Companion listener/client, positive reachable control before denial case | Stop owned services |
| Disk full | Separate 512 MiB disposable NTFS VHD; never fill system disk | Revert snapshot |
| Large file | Separate >=8 GiB test volume, sparse >4 GiB fixture, logical-space checks; no payload in memory | Revert snapshot |
| Process stress | <=32 concurrent children, <=60 seconds, tracked handles | Stop only owned processes, revert |
| Logs/listing | <=20 MiB logs, 10,000 synthetic files; 120-second enumeration timeout | Revert snapshot |

Endpoints are defined, not yet running or reachability-tested. No external
Internet/DNS test calls occur during normal P01 smoke. Second-user/session,
network positive controls, ACL and bounded VHD evidence remain unexecuted.
Only synthetic credentials may be entered locally if an account is created;
never send passwords in chat or evidence.

## Teardown and failure handling

Hosted Actions destroys the job VM; no real user state is retained. Local lab:
review/save non-sensitive evidence, stop only processes/listeners created by the
run, then restore the known clean VM snapshot. Revert is the default teardown,
not recursive deletion of an arbitrary root. Interrupted runs remain incomplete;
never infer safe cleanup from a prefix or an empty process query. Dedicated-PC
teardown must wait for P02's identity-bound cleanup or restore its backup.
