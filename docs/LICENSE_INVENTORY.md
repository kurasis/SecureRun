# Dependency, binary and source inventory

The owner has not selected a license for the original SecureRun manager. This
phase does not invent one, promise a proprietary distribution model, or grant new
redistribution rights. Artifacts are labeled development only. Resolve original
manager licensing and component obligations before a production/commercial release.

Each native build generates `dependency-inventory.json` and
`THIRD_PARTY_NOTICES.txt` from its actual Windows runtime/build dependency graph
and installed locked npm packages. The inventory records package/version/SPDX,
Cargo source archive URLs/checksums, npm integrity, notice origins and notice
hashes. It includes Tauri/React and build dependencies, rather than treating
`package.json` alone as an exhaustive shipping inventory. The full original lock
files and their hashes are retained. Build-only entries are distinguished from
the bundled frontend; the combined inventory intentionally includes more than
the final linked binary alone.

Cargo registry packages missing packaged license text use reviewed upstream text
bound to their exact crate VCS commit, URL and SHA-256 in
[license supplements](../packaging/license-supplements.json). The canonical MPL2
text is supplied for Servo selectors, whose covered sources carry MPL headers.
Native npm bindings that omit duplicate license files use the matching-version,
matching-license parent package notices and record that origin. Missing or
changed unreviewed notices fail the build.

Preserve the original notices when distributing third-party code. MIT/BSD/Apache
attribution and notice requirements still apply. MPL-covered dependencies retain
their separate source obligations: the inventory supplies exact unmodified crate
source archive URLs and lockfile SHA-256 values. No MPL dependency source is
modified by this manager. Do not assume a Rust binding's MIT license relicenses
Microsoft's loader/runtime or SDK redistributables.

| Component | Handling and terms |
|---|---|
| Original manager/adapter/installer guard | Original source; owner license not selected; development only |
| Rust and npm dependencies | Exact generated target inventory and original notice texts; no advisory ignores |
| SQLite bundled via libsqlite3-sys | Bundled dependency; retain its upstream notice/public-domain statements and wrapper license |
| Microsoft WebView2 SDK 1.0.3800.47 loader | All three static libraries match the exact official NuGet package; original Microsoft license/notice bytes are pinned and installed, independently of the MIT Rust bindings |
| Official WebView2 bootstrapper/runtime | Unmodified Microsoft-signed prerequisite; separately installed and serviced under Microsoft terms |
| Microsoft C++ v14 redistributables / MSVC / Windows SDK | Original Microsoft-signed x86/x64/ARM64 installers as needed, URL/hash-bound with separate Microsoft redistribution terms; shared runtimes retained on uninstall; OS API imports are not copied engine code |
| Inno Setup 6.7.3 installer runtime | Unmodified compiler/runtime; original modified-BSD license is installed as `INNO_LICENSE.txt` |
| Sandboxie/driver/SandMan | **Not bundled**; separate official installation, upstream license/entitlement and independent updates |
| Editor/archive/browser fixtures | **Not bundled**; laboratory downloads only, separate upstream packages and licenses |

No Sandboxie GPL/Plus source or binary has been copied into the manager package.
It communicates with a separately installed engine using the reviewed integration;
this engineering choice is not a blanket legal exemption. Re-review obligations
before source reuse, engine redistribution, native integration changes or rebranding.
SecureRun does not imply Sandboxie/Xanasoft/Microsoft endorsement.

The [P10 advisory review](DEPENDENCY_SECURITY_REVIEW.md) remains separate from
licensing: zero known vulnerabilities in that pinned scan does not decide license
compatibility or clear future updates. See [build provenance](BUILD.md) and the
[actual packaging gate](phases/P11_REPORT.md).

## Actual P11 target inventories

| Target | Components | Scope |
|---|---:|---|
| windows-2025 | 266 | Actual locked Windows build/runtime graph; installed tests passed, full integration blocked |
| windows-11-arm | 266 | Actual locked Windows build/runtime graph; installed tests passed, full integration blocked |

Original reports are in [installed proof](P11_TEST_REPORT.md); artifact identities and
actual tool versions are in [development artifacts](DEVELOPMENT_ARTIFACTS.md).
The inventories include Cargo/npm, Microsoft loader/SDK, Rust standard-library and
bundled SQLite notices. These do not select a license for original manager code.

## Disposable P11 diagnostic tool

Microsoft Sysinternals ProcDump is downloaded only for isolated Windows diagnosis,
never redistributed in the manager/installer or tracked as a binary. Its original
[license terms](https://learn.microsoft.com/sysinternals/license-terms) permit
installation/use on the test device. The [archive/payload pin](../tools/lab/p11-diagnostic-tools.json)
and valid Microsoft Authenticode are mandatory; no silent tool update is accepted.
Private process dumps and raw tool output are excluded from Actions artifacts and
Git. Diagnostic debugger observations are not production containment/performance
proof and do not alter the original-manager licensing limitation.
