# Signing and deployment trust decision

P11 delivers **UNSIGNED DEVELOPMENT ONLY** installers and original executables.
No organization certificate, signing service account or production key is bound
to this environment. `NotSigned` is an observed limitation, not a signature
verification success. A self-signed/test certificate would not solve that trust
requirement and is not generated or installed. No Windows trust setting is changed.

The selected production design is organizational Authenticode signing with a
publicly trusted code-signing certificate and a non-exportable hardware/service
protected key. A hardware-backed signing service (for example Microsoft Artifact
Signing) or an equivalent CA-issued organizational certificate is suitable after
the owner supplies the organization/account infrastructure securely. Do not put
keys, passwords, access tokens or signing credentials in Git, artifacts or chat.

Sign the manager, all native/x86/emulated-x64 production probes, box launcher,
setup guard, generated uninstaller and final installer. Use SHA-256 content
digests and a verified RFC3161 timestamp from the signing service/CA. Configure
Inno's signed-uninstaller path before compiling the final signed installer; an
unsigned generated uninstaller is not covered merely by signing setup.exe.
Never re-sign Sandboxie or Microsoft's original packages.

Verify every signed original PE and final installer with Windows Authenticode
chain/revocation/timestamp validation under the intended target policy, then check
the expected organizational publisher/certificate identity. Reject absent,
invalid, revoked or unexpected-publisher signatures and unknown verification
results. Keep standard Windows verification and network policy; do not use
`skip`/test-root/ignore-revocation switches to manufacture a passing release.
The signature, publisher, timestamp and post-signing SHA-256/size must be recorded
in the shipping manifest. Manifest hashes identify bytes; an untrusted editable
manifest alone cannot authorize code.

Production signing changes executable bytes. Generate the final manifest only
after signing each payload, compile/sign the installer, then repeat installed
checks on those exact artifacts. Development hashes cannot certify a later
signed build. Protect the installation directory and revalidate actual engine
signatures/hashes, own unboxed context, owner/root identity and effective policy
at runtime exactly as in the reviewed adapter. A valid publisher signature does
not replace those checks or prove containment by itself.

Current development setup uses a fixed native Program Files path, privileged
owner/DACL checks, bounded no-reparse traversal and exact installed payload hashes.
It refuses unsafe pre-existing paths rather than making them trusted. The
runtime's existing protected-image/engine/context checks remain active. Original
Microsoft/Inno downloads require their valid upstream signatures plus SHA-256;
the official Microsoft prerequisites also require the Microsoft publisher.

Production signing and original-manager license selection remain visible P12
release limitations. The P11 gate permits precisely labeled development builds;
it does not claim public production distribution readiness.
