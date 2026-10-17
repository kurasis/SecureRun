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
