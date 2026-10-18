# P11 manual engine security and compatibility refresh

The current development candidate uses original Sandboxie Plus 1.18.8/core 5.73.8,
source `bde0890108a563f5d72eb8e57085be2b37177218`. The publisher released it on
2026-10-17 at 20:38:42 UTC. The prior 1.18.6 tuple and its evidence are historical.
See the [official release](https://github.com/sandboxie-plus/Sandboxie/releases/tag/v1.18.8)
and [reviewed changes](https://github.com/sandboxie-plus/Sandboxie/compare/cdba7096240b93d79c5373aa81a75a1c5c71b883...bde0890108a563f5d72eb8e57085be2b37177218).

The release fixes a request-buffer out-of-bounds read in the GUI proxy's
MapWindowPoints handler: the new service checks that the claimed point count fits
the received request before copying. It also changes AppContainer/event security,
root protection and API_RENAME_FILE behavior. These changes require full native
regressions; unchanged public ABI alone does not prove containment. No permissive
engine option or disabled browser sandbox is introduced. The update is not claimed
to fix the undetermined RpcSs fault that produced orphan reporters in earlier ARM
runs. Their failed original evidence remains under the P11 investigation records.

Both official installer byte counts/SHA-256 values were independently downloaded
and verified. The original Classic/Plus license bytes are unchanged and hash-checked.
[Candidate review](evidence/p11/investigation-engine-1.18.8/candidate-review.json)
records those observations; Windows signatures and installed payload identities
are independently captured by the subsequent native P02 proof.

[Run 39086050127](https://github.com/kurasis/SecureRun/actions/runs/39086050127),
source `fa9b89faef79363c6f03bd972949e4c3eb257343`, passed representative P02
feasibility: Server x64 49 passed/2 N/A; Windows 11 ARM64 62 passed/2 N/A.
The two exclusions are the optional native engine event stream and elevated
product-helper authority, whose reasons remain in the original case records.
Both installers and required components have original valid signatures and match
the authenticated original installer payload. Actual native/x86/emulated-x64
probes retain the original source-backed routes; no result was generated from a
mock. This feasibility gate does not replace P03–P11 or close P12 acceptance.

The original header and actual driver both report ABI `0x57230`. The native cleanup
exports were observed in both original distributions. The production engine and
injected-DLL pins are derived from the new P02 originals. The cleanup manifest
includes the complete top-level DLL graph and independently hash-bound current
P02 inventory references. Validation rejects component substitution and identical
inventory bytes placed at an unbound path; no protected source inventory was reduced.
The P10 source inventory additionally covers the installer pin and shared passive
lab metadata collector.

Observed P02 OS tuples: Server 2025 build 26100/UBR 33438; Windows 11 ARM64 build
26200/UBR 9457. The runtime's OS enforcement identity includes the protected machine
update revision as well as kernel/base build and architecture, so a cumulative
update invalidates retained verification even when the base build stays unchanged.
The launch gate derives the same tuple format from the immutable compiled
compatibility pin. Validation binds its base version, update revision and product
type to the independent current P02 observations. An unreviewed OS tuple still
refuses launch. No registry value or OS security setting is modified to obtain
that identity.

SecureRun still requires a separate original engine installation and independent
updates by its owner. No engine binary, SandMan code, automatic engine update,
downgrade or uninstall is added to the manager installer. An unreviewed installed
engine fails closed. Consult [current status](STATUS.md), [compatibility](../packaging/compatibility.json)
and [P11 results](phases/P11_REPORT.md) for the final production-path gate state.
