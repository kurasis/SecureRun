# P11 — Packaging, upgrades, signing and retention

Status: IN_PROGRESS. Dependency: P10, with its exact-source regression being
refreshed for the new packaging workflow and raw-evidence attributes.

Implementation is additive under `packaging/`; the production runtime and original
specification are unchanged. The candidate is explicitly an unsigned development
artifact. Original manager licensing has not been selected by the owner.

The Windows gate must prove the official missing-WebView2 prerequisite branch,
administrator-controlled installation, exact installed hashes/architectures,
standard-user installed smoke, boxed-manager/worker refusal, failed and successful
package upgrades, schema refusal/transaction rollback, retained-data uninstall
and same-account reinstall. No result is claimed before actual execution.

No privileged product helper exists: helper enrollment and different-account
helper UAC portions are N/A. Applicable installed-manager context checks remain
mandatory. No engine component is bundled, updated, downgraded or uninstalled.

P12 and final installed T01–T66 acceptance are NOT_STARTED.

Prerequisite matrix clarification: the Server x64 VM exercises actual runtime
absence and installation through the official Microsoft bootstrapper. Windows 11
ARM64 retains its OS-preinstalled Microsoft runtime and exercises the existing
runtime branch. A manually stripped Windows 11 ARM64 missing-runtime test is not
claimed. All installed manager/upgrade/uninstall/retention/context tests remain
mandatory on both laboratories. The initial attempt to force runtime absence on
ARM failed without producing passing completion evidence.

The migration test reporter now validates the actual foundation distribution
(1 library +18 integration tests =19) and all62 adapter tests. Changing the P11
workflow invalidates the broad P10 workflow-source identity, so a new complete
exact-source integration run is required; no source list is reduced to reuse it.
