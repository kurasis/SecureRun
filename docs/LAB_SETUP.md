# Disposable Windows lab — P01

## Current runner and exact boundary

Per the owner's instruction, `.github/workflows/p01.yml` uses the public GitHub
`windows-11-arm` hosted runner. It is a fresh Windows 11 ARM64 job, not Windows
Server. The script builds an x64 probe using the installed Visual Studio C++
tools and runs it via Windows application emulation. No extra emulator, x86
sandbox, VM download, engine installer execution or driver workaround is needed.
The native ARM64 distribution from the same official release is pinned as the
lab candidate; both installers are checked without installation.
Exact build, architecture, hypervisor observations, security observations, source
commit and timestamps are emitted to `inventory.json`. Unknown observations
remain UNKNOWN. Workflow artifacts contain the probe and JSON evidence only.

Official runner reference:
https://docs.github.com/en/actions/reference/runners/github-hosted-runners
and image inventory:
https://github.com/actions/runner-images/blob/main/images/windows/Windows11-Arm64-Readme.md

**This is a tooling lab.** It cannot load the pinned x64 Sandboxie driver through
user-mode emulation. Per the explicit user request, Windows 11 ARM64 replaces the
P01 x64 lab default. Native ARM64 Sandboxie is a P02 feasibility candidate, not a
supported product tuple. P02 must source-review and test its native driver and
x64-emulated targets before production ARM64 support can be claimed. Original
Windows 11 x64 product compatibility still requires its own native x64 evidence.
The first hosted inventory reports Secure Boot disabled by the image; no setting
was changed. Treat production security-setting parity as unresolved in P02.

## Reproduce the hosted checks

Push changes or use the `P01 validation` workflow dispatch. The workflow checks
out the exact manager commit, validates source-only outputs, then runs:

```powershell
./tools/lab/Invoke-P01.ps1 -PrepareFixtures
```

Equivalent local prerequisites: Windows 11 ARM64 or x64, PowerShell 7, Git,
Visual Studio 2022 C++ tools for the x64 target and the Windows SDK. In the
repository, run the same command. It builds only lab_probe.exe, runs it, downloads
the pinned x64 and ARM64 installers over verified HTTPS and checks size, SHA256 and Windows
Authenticode status. It never executes either installer. A bad or unknown signature
fails the check; do not bypass it. The Windows trust result is platform validation,
not independent proof of every distribution component. Installed component trust,
including catalog trust for the driver, belongs to P02/P04.

Retain `artifacts/p01/{inventory,probe,installer-trust,installer-trust-arm64,fixtures}.json` with exact workflow
run/job URL. Artifacts are retained for 14 days; commit reviewed non-sensitive
JSON results and links to docs/evidence before expiration. Do not commit binaries,
certificates, machine names, usernames, SIDs, real paths or credential values.
No diagnostic environment dump is performed.

## Later native engine validation

For the original x64 compatibility target, provision a disposable Windows 11 x64 VM with 4 vCPU, 8 GiB RAM, 40 GiB disk,
local fixed NTFS, a serviced OS build, normal Secure Boot, driver signature
checks, Defender and existing HVCI settings preserved. No real host shared
folders, clipboard sync, personal accounts or production credentials. Record the
hypervisor/version and a clean snapshot ID manually in local evidence. A PC is
acceptable only with dedicated synthetic accounts and a restorable backup.

Install Visual Studio C++ tools/Windows SDK, Git, PowerShell 7 and official
WebView2. Run `./tools/lab/Invoke-P01.ps1 -PrepareFixtures`. Fixture preparation requires
Windows client build >=22000 and fixed local NTFS; the probe supports native
AMD64 and ARM64 with an x64 process. It creates a unique
`%LOCALAPPDATA%\SecureRunLab\runs\<random UUID>` with host-canaries, import,
export and evidence directories, and one synthetic marker. This is not an ACL
or containment pass. Review the captured security state, attach backup/snapshot
identity and hash the probe. A required protection reported UNKNOWN needs a
read-only administrative observation; never change settings just to pass.

Download/install only the official pinned engine, after installer trust succeeds,
inside an appropriate native-architecture disposable VM during P02. Record actual component file versions, hashes, embedded
or catalog signatures, service/driver health and reboot state. P01 records the
candidate; P02 source review decides which fixed benign operations can run.
Never attempt to load an x64 kernel driver on Linux or ARM64; do not install any
engine during P01. ARM64 native-driver installation/testing belongs to P02.
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

## P02 disposable engine laboratory

The owner selected both Actions images: `windows-2025` (x64 OS, genuine x86 and
x64 target probes) and `windows-11-arm` (native ARM64 driver/bridge, ARM64 and
emulated x86/x64 target probes). Modern hosted Server images are x64, not x86 OSes.
Workflow: [p02.yml](../.github/workflows/p02.yml). Manually dispatch with
`gh workflow run p02.yml --ref p02/engine-feasibility` while developing, or `main`
after publication. Never run these mutating lab scripts on an existing engine or
on a workstation containing real box data. GITHUB_ACTIONS is an accident guard,
not a security boundary or proof of disposable ownership.

On the fresh VM, Initialize-P02 rejects preexisting services/installations, verifies
the pinned native installer, separately extracts its authenticated payload, installs
without reboot/security changes, verifies installed components/dependencies, builds
explicit MSVC targets with /WX and inspects the original driver. Invoke-P02 creates
unique synthetic boxes, owner-protected NTFS roots, inert canaries, local v4/v6 TCP/
UDP echo endpoints, a synthetic standard account and a temporary SYSTEM scheduled
task for real session-zero enumeration. No external target payload is downloaded.
Only original engine service IPC, observed native exports and fixed benign probe
executables are used. CI credentials are removed from the dispatching worker's
environment before any boxed target. Synthetic passwords never appear in artifacts.

The WFP engine global setting is changed only in this newly installed disposable
engine. Do not transfer that mutation into production startup or cloud install
scripts. OS boot/security/Defender settings are observed and preserved. The VM is
discarded after the job; no generic recursive cleanup or engine uninstall is run.

Structured artifacts are collected even when smoke cases fail; a green collection
job is not a P02 gate pass. Download with `gh run download RUN_ID`; compare
installation.manager_commit and probe PE machines before using evidence. Artifacts
have 14-day retention, so phase evidence is also retained under docs/evidence/p02.
The phase result keeps failures, blocked portions and absent-helper NA distinct.
Same-SID second interactive session is not supplied by the hosted-runner setup;
SYSTEM session zero is explicitly different-owner partial evidence.

The Linux cloud needs only Python stdlib/Git/GitHub CLI for repository validation
and Actions orchestration; no Windows services or app server run locally. No generic
install_script/start_skill is needed for this phase. Windows VM lifecycle and tool
activation are reproduced by the pinned workflow and lab scripts. A temporarily
expired GitHub connection was refreshed through environment settings; no credentials
were copied into scripts, repository files or a second secret binding.
