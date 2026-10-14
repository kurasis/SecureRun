[CmdletBinding()]
param([switch]$PrepareFixtures)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo 'artifacts/p01'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = @(Get-CimInstance Win32_Processor | Select-Object Architecture, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions)
$security = [ordered]@{}
try { $security.secure_boot = Confirm-SecureBootUEFI } catch { $security.secure_boot = 'UNKNOWN' }
try {
    $dg = Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard
    $security.device_guard = $dg | Select-Object VirtualizationBasedSecurityStatus, SecurityServicesConfigured, SecurityServicesRunning, CodeIntegrityPolicyEnforcementStatus
} catch { $security.device_guard = 'UNKNOWN' }
try { $security.defender = Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AMServiceEnabled } catch { $security.defender = 'UNKNOWN' }
$managerCommit = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify manager commit.' }
$inventory = [ordered]@{
    schema_version = 1; timestamp_utc = [DateTime]::UtcNow.ToString('o')
    manager_commit = $managerCommit
    os = $os | Select-Object Caption, Version, BuildNumber, OSArchitecture, ProductType
    os_update_build_revision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
    hardware = $computer | Select-Object Manufacturer, Model, HypervisorPresent
    cpu = $cpu; security = $security
    runner_kind = $(if ($env:GITHUB_ACTIONS -eq 'true') { 'GITHUB_ACTIONS' } else { 'LOCAL' })
    windows_11_x64_candidate = ($os.ProductType -eq 1 -and [int]$os.BuildNumber -ge 22000 -and [Environment]::Is64BitOperatingSystem -and ($cpu[0].Architecture -eq 9))
    windows_11_client = ($os.ProductType -eq 1 -and [int]$os.BuildNumber -ge 22000)
    fixtures_requested = $PrepareFixtures.IsPresent
    containment_result = 'NOT_RUN'
}
$inventory | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out 'inventory.json') -Encoding utf8
& (Join-Path $PSScriptRoot 'Build-Probe.ps1')
$probe = & (Join-Path $out 'lab_probe.exe')
if ($LASTEXITCODE -ne 0) { throw "Probe execution failed: $LASTEXITCODE" }
$result = $probe | ConvertFrom-Json
if ($result.result -ne 'PASS' -or $result.architecture -ne 'x64') { throw 'Unexpected probe result.' }
if (($cpu[0].Architecture -eq 12 -and $result.native_architecture -ne 'arm64') -or
    ($cpu[0].Architecture -eq 9 -and $result.native_architecture -ne 'x64')) { throw 'Probe native architecture disagrees with OS inventory.' }
$probe | Set-Content (Join-Path $out 'probe.json') -Encoding utf8
$pin = Get-Content (Join-Path $repo 'docs/engine-candidate.json') -Raw | ConvertFrom-Json
foreach ($candidate in @($pin.installer, $pin.lab_installer)) {
    $installer = Join-Path $out $candidate.name
    Invoke-WebRequest -Uri $candidate.url -OutFile $installer
    $hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $candidate.sha256 -or (Get-Item $installer).Length -ne $candidate.size) { throw 'Official installer checksum/size mismatch.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    $trust = [ordered]@{
        timestamp_utc = [DateTime]::UtcNow.ToString('o'); manager_commit = $managerCommit
        source_commit = $pin.source_commit; installer_name = $candidate.name; installer_sha256 = $hash
        signature_status = $signature.Status.ToString()
        signer_subject = $(if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null })
        signer_thumbprint = $(if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null })
        provenance_scope = 'Official pinned installer only; installed components and containment NOT_TESTED'
    }
    $trustName = if ($candidate.name -match 'ARM64') { 'installer-trust-arm64.json' } else { 'installer-trust.json' }
    $trust | ConvertTo-Json | Set-Content (Join-Path $out $trustName) -Encoding utf8
    if ($signature.Status -ne 'Valid') { throw "Installer trust unresolved: $($signature.Status). Verification is not bypassed." }
}
# Unique synthetic fixtures only. No real profile/documents, no automatic deletion.
if ($PrepareFixtures) {
    if (-not $inventory.windows_11_client) { throw 'Fixture lab must be Windows 11.' }
    $runId = [Guid]::NewGuid().ToString('N')
    $fixture = Join-Path $env:LOCALAPPDATA "SecureRunLab/runs/$runId"
    $volume = Get-Volume -FilePath ($env:LOCALAPPDATA + [IO.Path]::DirectorySeparatorChar)
    if ($volume.FileSystem -ne 'NTFS' -or $volume.DriveType -ne 'Fixed') { throw 'Fixed local NTFS fixture volume required.' }
    foreach ($dir in @('host-canaries', 'import', 'export', 'evidence')) {
        New-Item -ItemType Directory -Path (Join-Path $fixture $dir) | Out-Null
    }
    $canary = Join-Path $fixture 'host-canaries/read-write.txt'
    'SECURERUN_SYNTHETIC_CANARY_V1' | Set-Content $canary
    @{ schema_version = 1; run_id = $runId; fixture_root_relative = "SecureRunLab/runs/$runId"; volume_filesystem = $volume.FileSystem; canary_sha256 = (Get-FileHash $canary -Algorithm SHA256).Hash.ToLowerInvariant(); teardown = $(if ($env:GITHUB_ACTIONS -eq 'true') { 'DISCARD_ACTIONS_VM' } else { 'REVERT_VM_SNAPSHOT' }); status = 'PREPARED_NOT_CONTAINMENT_TESTED' } |
        ConvertTo-Json | Set-Content (Join-Path $out 'fixtures.json') -Encoding utf8
}
Write-Output 'P01 native smoke and installer trust checks passed. No containment result is implied.'
