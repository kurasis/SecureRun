# P10 dependency advisory review

Source/lockfiles: `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`.
This read-only local advisory scan supplements the implementation/native review;
it does not prove containment or replace Windows tests.

| Check | Actual result |
|---|---|
| npm 11.9.0, Node 24.19.0; `npm audit --json` | Zero known vulnerabilities in the complete locked dependency graph |
| `npm audit --omit=dev --json` | Zero known vulnerabilities in production dependencies |
| cargo-audit 0.22.2; full Cargo.lock | 484 packages, 1338 database advisories, zero vulnerability findings; five informational warnings retained below |
| Production Windows dependency graphs | 234 distinct package/version pairs each for x86_64-pc-windows-msvc and aarch64-pc-windows-msvc; none of the five warning packages is selected |

RustSec database source: official `RustSec/advisory-db`, exact commit
`999ec89d5d3f10f20be14750ec8c2d8b44e0ac9b`. The audit used `--db` and
`--no-fetch` against that checkout; cargo-audit's JSON leaves last-commit/date
null in this mode, so the separately observed Git commit is preserved explicitly.
No advisory, package, severity or target was ignored during the full lock scan.

| Retained full-lock warning | Advisory | Assessment |
|---|---|---|
| proc-macro-error 1.0.4 unmaintained | RUSTSEC-2024-0370 | Absent from both actual production Windows dependency graphs |
| zbus_names 4.3.4 unmaintained | RUSTSEC-2026-0371 | Absent from both actual production Windows dependency graphs |
| zvariant 5.15.0 unmaintained | RUSTSEC-2026-0370 | Absent from both actual production Windows dependency graphs |
| zvariant_derive 5.15.0 unmaintained | RUSTSEC-2026-0372 | Absent from both actual production Windows dependency graphs |
| glib 0.18.5 iterator unsoundness warning | RUSTSEC-2024-0429 | Absent from both actual production Windows dependency graphs; no claim that this warning is fixed or universally harmless |

These platform-dependent lock entries are not silently removed, upgraded or
suppressed. A future dependency/feature/platform change must repeat reachability
and advisory checks. The product is a Windows application; this review does not
authorize a Linux desktop release using the affected optional platform stack.
Known-advisory databases are incomplete and time-dependent; a clean vulnerability
count is not an independent dependency/source audit.

The [review manifest](evidence/p10/dependencies/manifest.json) binds exact raw JSON,
lockfile hashes and normalized package/version graphs. Original graph output's
local build paths are excluded. No credentials, binaries or private machine
inventory are retained. Reviewed file sizes and SHA-256 hashes were checked
before publication.

Reproduction from the existing checkout:

```sh
npm audit --json
npm audit --omit=dev --json
cargo install cargo-audit --version 0.22.2 --locked --no-default-features
git clone https://github.com/RustSec/advisory-db.git /tmp/securerun-rustsec-review
git -C /tmp/securerun-rustsec-review checkout 999ec89d5d3f10f20be14750ec8c2d8b44e0ac9b
cargo audit --db /tmp/securerun-rustsec-review --no-fetch --json
cargo tree --locked -p securerun --target x86_64-pc-windows-msvc --prefix none --format '{p}'
cargo tree --locked -p securerun --target aarch64-pc-windows-msvc --prefix none --format '{p}'
```

The cargo-audit build disabled only its optional binary-scanning feature because
this check scans Cargo.lock, not installed binaries. Cargo registry checksums/TLS
and official advisory source verification remained enabled. No product dependency,
lockfile, compiler, runtime security setting or source pin changed for this scan.
