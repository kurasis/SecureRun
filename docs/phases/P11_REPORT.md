# P11 — Packaging, upgrades, signing and retention

Status: **BLOCKED pending P10 integration**, 2026-10-18 UTC.

The actual installed gate succeeded on both Server x64 and Windows 11 ARM64:
**28/28 installed cases plus 81 production tests (1+18+62) each**, package source
`dd447fec88de966fa839b03fc0fd4eb6b41776a4`,
[run 39089078904](https://github.com/kurasis/SecureRun/actions/runs/39089078904).
Four downloaded baseline/candidate installer sizes and SHA-256 values match the
original build reports. See [actual test matrix](../P11_TEST_REPORT.md),
[development downloads/checksums](../DEVELOPMENT_ARTIFACTS.md) and
[download-byte verification](../evidence/p11/installer-download-verification.json).

The full P10 run at `ffdaeb60bd8c9d707959435b910c6a1027ecb770`
(39087328157) passed P03–P08 on both runners but ARM P09 failed at
SEEDING_ENVIRONMENT_09: an unreviewed WerFault remained alive after the unchanged
60000 ms natural-completion bound. Read-only metadata found no surviving target
or fixed-component WER report/event. Its cause remains undetermined.
[Original failed evidence](../evidence/p11/investigation-ffdaeb6-arm-p09-attempt-1/review.json)
is preserved separately. Server P09 passed 21/22 native and all 101 UI checks,
but its actual Firefox about:support observation failed P09_CLIPBOARD_BUSY.
No effective browser sandbox level was obtained or inferred; its
[original failed observations](../evidence/p11/investigation-ffdaeb6-server-p09-attempt-1/review.json)
are also retained. One targeted unchanged-source clean-runner repeat of both
failed P09 jobs is running. No assertion, workload, timeout or trust boundary
changed. P11 cannot be DONE until its dependency passes.

Packaging is additive under `packaging/`. Runtime changes authenticate every
remaining diagnostic image, defer natural waits until independently authorized
helper stops, and include the protected OS UBR in verification/launch identity.
Original Plus 1.18.8/core 5.73.8 pins were independently reauthenticated through
P02; this is a manual security refresh, not a product updater. All 26 original
specification documents are unchanged. The candidate is explicitly an unsigned development
artifact. Original manager licensing has not been selected by the owner.

The Windows gate must prove the official missing-WebView2 prerequisite branch,
administrator-controlled installation, exact installed hashes/architectures,
standard-user installed smoke, boxed-manager/worker refusal, failed and successful
package upgrades, schema refusal/transaction rollback, retained-data uninstall
and same-account reinstall. Actual results are now linked above; these do not waive the P10 dependency.

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

The original 1.18.8 candidate passed P02 on both labs (49/62 passed cases plus
2 N/A each), run 39086050127/source fa9b89f. Production component and full cleanup
DLL pins now derive only from those authenticated originals. Independent current
P02 inventory paths/hashes, exact observed export and full component lists remain
mandatory. The substitution test also rejects identical inventory bytes at an
unbound path. The complete P10 source inventory adds the installer pin and shared
read-only metadata module. OS enforcement identity now includes the protected UBR
for cumulative-update cache invalidation. See [manual engine review](../P11_ENGINE_UPDATE.md).

Source f26e6a3 Server installed seed passed provisioning/import-export but its
launcher failed closed with RELEASE_TUPLE_UNTESTED: UBR had been added to the
actual OS identity while launch still compared the old tuple format. Original
failed JSON is retained under investigation-f26e6a3-server-tuple. The launch
comparison now derives the matching tuple from the immutable compiled pin;
base version, update revision and product type are independently checked against
current authenticated P02 observations. The test also rejects a self-declared
revision change even when source hash records are edited consistently.

Installed smoke traceability was expanded before phase closure. The original
25-case suite opened the real GUI but lacked an explicit stopped-engine refusal.
The current 28-case suite additionally launches a real registered target with
the original service stopped and with a changed original Start.exe byte; both
must refuse before receipts or host output. Lab fixtures restore the original
service and exact authenticated component bytes/signature. Each ordinary launch
also faces a working native fake Start.exe in PATH/CWD, with an unboxed positive
canary control and no host or boxed impostor execution. That fixture is never
shipped. The separate installed T12 case binds original native/x86/emulated-x64
parent/child/server reports to the installed probe hashes. Import/export is tagged
T21 rather than being mislabeled as the T12 network scenario. These additions are
packaging-only and preserve all 155 protected P10 inputs byte-for-byte. Full
installed T01 missing-engine/driver-unhealthy variants remain final P12 scope;
P11's installed T01 smoke is the stopped-service variant.

Expanded-suite source d73e352 Server built the installers and canary but failed
before installed cases because .NET resolved a relative fixture path against the
process current directory. Original partial build JSON is preserved separately.
The lab now uses the same absolute fixture path for compiler output, copy, PE
inspection and hashing; no product or required security assertion was changed.
