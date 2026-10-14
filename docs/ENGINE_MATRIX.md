# Engine candidate matrix

No supported production tuple exists. These are P02 feasibility candidates only.
Pinned official Plus 1.18.6 / core 5.73.6 source:
`cdba7096240b93d79c5373aa81a75a1c5c71b883`; observed core ABI `0x57230`.
[Machine-readable provenance pin](engine-candidate.json).

| Laboratory | Native engine/bridge | Actual target binaries | State |
|---|---|---|---|
| Linux cloud | No Windows driver | Repository Python stdlib tooling | Integrity/tests verified; no containment claims |
| Actions Windows Server 2025 x64 | x64 original installation | x64 and genuine x86 PE | Representative P02 gate DONE |
| Actions Windows 11 Enterprise ARM64 | Native ARM64 original installation | ARM64, emulated x64 and genuine x86 PE | Representative P02 gate DONE |
| Serviced Windows 11 x64 | x64 candidate | Native x64/x86 | NOT_TESTED: Server kernel and ARM emulation do not supply this tuple |

Exact OS build/UBR, security observations, installed PE versions, individual
signature states, component hashes, services, target PE machines and actual smoke
counts are in [the evidence manifest](evidence/p02/manifest.json). Inventory's
containment_result=NOT_RUN describes its bootstrap stage, not later smoke cases.
The P02 representative feasibility outcome is DONE. Original P01 provenance is retained separately.

The x64 installer is 24,914,432 bytes, SHA256
`3ad29e1ec18618ee9aa4ef4e21ab0548cf2188b94c05c41cb7a07b5d2d0270e2`;
ARM64 is 22,452,544 bytes, SHA256
`7d2e4ca2ed7943beacad3e1df14d3159ad7d700f12a4ca11d4a4eaa20ffd527a`.
Both official installers have Valid Windows Authenticode. Installed files are
compared to independently extracted authenticated payloads; distribution libraries
may be NotSigned and are recorded as such. This is provenance, not independent
security certification or a uniform online revocation guarantee.

| Capability | Candidate result | Product availability |
|---|---|---|
| Native engine health/self-context | Original driver/service query observed | UNKNOWN until complete release tuple/current preconditions |
| Standard virtual writes/selected reads | Native/emulated fixed probes, host canaries and controls | UNKNOWN; representative smoke does not complete policy baseline |
| Kernel offline/online sockets | WFP mechanism/flag plus actual loopback TCP/UDP v4/v6 controls | UNKNOWN; DNS/LAN/SMB/broker/raw/inbound still untested |
| Process membership/descendants | Parent/child/grandchild native and emulated probes | UNKNOWN until full production dispatch/journal checks |
| All-session enumeration | Real same-SID sessions 0/2 plus foreign SYSTEM session; truncation rejected | PROVEN feasibility; production concurrency/desktop matrix unrun |
| Root ACL/sibling separation | Second-account and same-user boxed denial with future-root alias variants | PROVEN standard-user provisioning and parent/root substitution refusal; full product variants unrun |
| Cleanup | Original narrow QSbieAPI, launch fence, namespace/DACL seal and same-root postconditions | PROVEN representative feasibility; product lifecycle/recovery/stress unrun |
| Private workspace/boxed EXE | Original mapping API and explicit logical launch spike | UNKNOWN until file-phase safe transfer and identity protocol |
| Optional paid security/privacy/encryption/proxy profiles | Original certificate-state observation; no entitlement installed | UNAVAILABLE; no certificate or INI acceptance treated as enforcement |

The hosted images' boot/VBS/code-integrity/Defender observations are preserved;
no Windows security setting is changed. P01 ARM image reported Secure Boot false,
VBS/code integrity/Defender active and no nested virtualization. P02 records each
fresh image's actual state rather than inheriting that observation as an assumption.
A hardened Secure-Boot-enabled product tuple needs separate evidence.

Final measured ARM tuple is Windows 11 Enterprise 26200.9457: Secure Boot false,
VBS status 2, code-integrity enforcement 2, Defender real-time protection true.
Server is Windows Server 2025 Datacenter 26100.33438: Secure Boot false, VBS status
2, code-integrity enforcement 2, Defender real-time protection false. These are
unchanged hosted-image states; neither runner establishes the complete hardened
Windows 11 x64 release environment. All 41 ARM and 40 x64 inventoried components
report Valid signature and authenticated payload match in this exact run.

Core/Classic GPLv3, Plus/SandMan custom terms and QSbieAPI/MiscHelpers/Qt LGPL
notices are source-pinned. No upstream implementation is copied and no engine is
redistributed. The original QSbieAPI runtime cleanup dependency is a concrete
exception assessed for the lab; distribution review remains required, not a claim that dynamic loading removes obligations.
Manager license/distribution terms remain unselected; see [licensing assessment](FEASIBILITY_REPORT.md).
