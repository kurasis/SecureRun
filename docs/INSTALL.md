# Install SecureRun Development

This is an **unsigned development build**. Obtain the candidate installer,
`SHA256SUMS` and matching source/evidence from the P11 Actions artifacts linked
in the [phase report](phases/P11_REPORT.md). Select the native OS architecture:
x64 for the Server x64 laboratory, ARM64 for Windows 11 ARM64. An ARM64 manager
uses the installed native ARM64 engine and can test x86/emulated x64 targets;
the x64 installer is not the ARM64 installer. The laboratory results do not
certify an installed Windows 11 x64 release.

Verify the downloaded installer's SHA-256 against the published reviewed report:

```powershell
Get-FileHash ./SecureRun-Development-0.3.0.11-arm64.exe -Algorithm SHA256
Get-AuthenticodeSignature ./SecureRun-Development-0.3.0.11-arm64.exe
```

`NotSigned` is the expected development status of this installer and the original
manager components. A checksum identifies reviewed bytes; it does not establish
a trusted publisher. Do not disable SmartScreen, Defender, certificate validation,
Secure Boot or other Windows security settings. If local policy blocks an
unsigned installer, use an appropriately signed build approved by that policy.
No signing key or test certificate is distributed.

Install the original Sandboxie engine separately from its official publisher,
using the tested tuple in [the compatibility manifest](../packaging/compatibility.json).
SecureRun does not install or update the engine. A missing/unhealthy/unreviewed
engine remains visibly unavailable and never causes an ordinary target launch.
Do not automatically downgrade an existing engine to make the manager work.

Run the manager installer and approve Windows administrator elevation for setup.
It installs code only in the fixed native `Program Files\SecureRun Development`
directory. There is no per-user/portable writable-code installation and no custom
directory option. Unsafe owners, writable ACLs, junction/reparse paths and foreign
installation paths are refused; setup does not silently repair those permissions.
The code files and directories are read-only to ordinary users.

Setup also verifies the Microsoft C++ v14 runtimes needed by the native and
x86 probes (and emulated x64 probes on ARM64). Missing/older runtimes use
unmodified Microsoft-signed, hash-pinned redistributable installers. The
minimum version follows the actual compiler toolset; no runtime is downgraded.

If a suitable machine Microsoft WebView2 runtime is absent, setup runs its
embedded, unmodified Microsoft-signed Evergreen bootstrapper (`/silent /install`).
The bootstrapper requires internet access and Microsoft's separate terms. A
failed prerequisite prevents manager file installation; any prerequisite installed
before failure remains Microsoft's separately serviced runtime. A requested
restart is surfaced by setup rather than silently rebooting the computer.
Existing runtimes are independently serviced by Microsoft; the manager never
pins or downgrades their installed version to an older version.

Start **SecureRun Development** from the Start menu as the ordinary interactive
user. Do not routinely run the manager as administrator. There is no persistent
elevated product helper, service, scheduled task, shell extension or automatic
manager updater. Each account uses its own OS-resolved local profile and must
revalidate ownership, engine, policy and roots before protected actions.

Original manager licensing and production signing are still release prerequisites.
See [signing decision](SIGNING.md), [build status](BUILD.md), [retention](UPGRADE_AND_UNINSTALL.md) and
[license inventory](LICENSE_INVENTORY.md). Actions artifacts expire after 14 days;
the repository retains reviewed checksums/evidence and build instructions, not a
permanent signed release download. Regenerate and revalidate expired artifacts.
