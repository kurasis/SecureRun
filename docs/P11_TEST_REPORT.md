# P11 installed packaging test report

Source: `dd447fec88de966fa839b03fc0fd4eb6b41776a4`. [Native run 39089078904](https://github.com/kurasis/SecureRun/actions/runs/39089078904).

**Phase gate: BLOCKED pending current-source P10 integration.** The installed
checks below are a historical successful snapshot. Checked Save input and fixture
races now have successful native proof, but ordinary ARM P09 still failed at
environments 06/08 in runs 39119547942/39120204559. The latest original-service
diagnostic run 39129208572 passed 22+101 without a reporter; its diagnostic scope
cannot establish a fault correction or replace complete P10 integration.
See the [current phase report](phases/P11_REPORT.md). This installed report does
not close that dependency or certify the later changed protected inputs.

Both owner-selected laboratories passed **28/28 installed cases**, plus the actual
foundation migration/compatibility suites (1 library +18 integration =19) and all 62
adapter tests. The manager is the normal release-profile binary with no CI features.
The installer and original manager components are **UNSIGNED DEVELOPMENT ONLY**.

| Scenario | Actual case | Server x64 | Windows 11 ARM64 |
|---|---|---|---|
| T02 | `installer_rejects_user_writable_existing_code_directory` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T02 | `installer_rejects_junction_without_touching_destination` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T01 | `official_webview_prerequisite_matches_os_baseline` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T29 | `clean_install_has_exact_reviewed_payload_and_native_architecture` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T29 | `failed_upgrade_rolls_back_files_and_retains_profile` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T29 | `upgrade_installs_candidate_without_elevated_profile_migration` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T29 | `older_package_is_refused_without_database_downgrade` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T58 | `installed_boxed_manager_and_all_workers_refuse_unboxed_parent_claim` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T48 | `uninstall_removes_only_code_and_retains_profile_engine_runtime` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T48 | `reinstall_preserves_data_before_owner_reconciliation` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/packaging-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/packaging-cases.json) |
| T02 | `seed_ordinary_user_cannot_modify_installed_code` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T01 | `seed_installed_manager_opens_real_webview_and_closes` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T08 | `installed_build_provisions_and_verifies_real_offline_policy` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T12 | `installed_offline_baseline_has_parent_child_and_server_observations` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T21 | `installed_import_export_preserves_bytes_and_provenance` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T05/T02 | `seed_installed_production_launcher_stays_boxed` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/seed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/seed-cases.json) |
| T02 | `upgrade_ordinary_user_cannot_modify_installed_code` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T01 | `upgrade_installed_manager_opens_real_webview_and_closes` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T48 | `upgrade_same_account_reopens_verified_retained_environment_and_file` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T05/T02 | `upgrade_installed_production_launcher_stays_boxed` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T28 | `future_schema_is_refused_without_downgrade` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T28 | `failed_initial_migration_is_refused_without_destroying_existing_data` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/upgrade-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/upgrade-cases.json) |
| T02 | `reinstall_ordinary_user_cannot_modify_installed_code` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/reinstall-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/reinstall-cases.json) |
| T01 | `reinstall_installed_manager_opens_real_webview_and_closes` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/reinstall-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/reinstall-cases.json) |
| T48 | `reinstall_same_account_reopens_verified_retained_environment_and_file` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/reinstall-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/reinstall-cases.json) |
| T05/T02 | `reinstall_installed_production_launcher_stays_boxed` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/reinstall-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/reinstall-cases.json) |
| T01 | `installed_stopped_engine_refuses_registered_target_without_host_fallback` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/engine_stopped-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/engine_stopped-cases.json) |
| T02 | `installed_changed_engine_binary_refuses_registered_target_without_host_fallback` | [PASSED](evidence/p11/completion-dd447fe/windows-2025/engine_changed-cases.json) | [PASSED](evidence/p11/completion-dd447fe/windows-11-arm/engine_changed-cases.json) |

T27/T47 applicable boxed-client and forged-parent portions are covered by the actual
installed boxed-manager/worker case (T58) and matching P10 production metadata/ownership
regressions. T57 has no privileged metadata authority/enrollment in this design.
T52 and helper-specific different-account UAC/enrollment subcases are N/A: no elevated
product helper exists. These exclusions do not waive installed self-context checks.

Server exercises actual absent-runtime installation through the original Microsoft
bootstrapper. Windows 11 ARM64 preserves its OS-preinstalled Microsoft-signed runtime.
A manually stripped Windows 11 ARM64 missing-runtime installation is not claimed.
Both variants check actual runtime availability and execute the installed application.

Upgrade revision10 →11 uses the same runtime/schema1. No schema1 →2 migration is invented.
Actual future/foreign database refusal leaves bytes unchanged; the original production
initial-migration transaction rollback test runs in the foundation suite. The installer
does not open profiles as administrator. Uninstall waits for its cloned process/log
completion and verifies all owned payload files and registration are gone, with exact
retained-profile digests and successful same-account reinstall/reconciliation.

The installed T01 smoke uses a stopped original service and a real registered target.
Missing-engine and unhealthy-driver installed variants remain final P12 scope.
T02 also uses a working native impostor positive control in PATH/CWD at each stage
and a changed original engine component; both fail without impostor/host dispatch.
T12 binds original native/x86/emulated-x64 parent/child/live-server observations to
the installed probe hashes. Normal import/export is correctly tagged T21.

All final installed T01–T66 acceptance entries remain **NOT_STARTED until P12**.

See [phase report](phases/P11_REPORT.md), [build](BUILD.md), [signing](SIGNING.md),
[artifact checksums](DEVELOPMENT_ARTIFACTS.md) and [retention](UPGRADE_AND_UNINSTALL.md).
