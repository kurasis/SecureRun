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

The final setup guard now checks ancestor ownership and mutation/deletion ACLs,
including parent FILE_DELETE_CHILD, without changing Windows ACLs. Its Server
installed gate passed. An ARM execution at ff41537 then refused diagnostic cleanup
with DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED during actual installed provisioning;
setup/guard cases had passed. Original failed actor/setup JSON is retained in
`docs/evidence/p11/investigation-ff41537-arm-attempt-1/`. Its specific live image
was not retained, so no particular crash cause is inferred for that P11 run.
Read-only failure collection now retains bounded original image-status JSON and
minimized WER/event/CIM classification, including fixed virtualized WER locations.
No process trust/termination authority, assertion, retry or pass is added.

Repeated P09 ARM seeding refusal at integration run 39082021205 attempt 2
associated a live WerFault with SandboxieRpcSs through read-only CIM only. The
cleanup loop could wait for an unreviewed process before stopping an already
reviewed helper later in enumeration. It now holds unknown objects, completes
independently authorized stops first, then waits on the exact retained unknown
objects for the unchanged 60000 ms bound. It still refuses a live unknown and
never terminates or trusts it. The specific upstream crash cause is not claimed
fixed. Full exact-source P03–P10 and installed P11 evidence must be refreshed.
The diagnostic image check now applies to every remaining process, including
same-owner tokens. A SID match alone no longer authorizes termination of an
unreviewed image. Only the two exact protected, signed original RPC companions
can be stopped after both benign canary processes have completed; every other
remaining object is only waited on and a live unknown still refuses completion.

Upstream v1.18.8 (2026-10-17) fixes a GUI proxy MapWindowPoints request-length
out-of-bounds read. The original v1.18.6 tuple is historical; the development
compatibility candidate is being manually refreshed to original v1.18.8, source
bde0890108a563f5d72eb8e57085be2b37177218. No automatic engine update, engine
bundling or unsupported security switch is introduced. P02 is BLOCKED until
authenticated installers/components and real feasibility pass on both labs;
production adapter/cleanup hashes will only be updated from those observations.
