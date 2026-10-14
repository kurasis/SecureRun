[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This installer spike is restricted to a disposable Actions VM.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo 'artifacts/p02'
New-Item -ItemType Directory -Force -Path $out | Out-Null
@{ phase = 'P02'; stage = 'BOOTSTRAP_STARTED'; timestamp_utc = [DateTime]::UtcNow.ToString('o'); security_settings_modified = $false } | ConvertTo-Json | Set-Content (Join-Path $out 'bootstrap-stage.json') -Encoding utf8
if ((Get-Service SbieSvc -ErrorAction SilentlyContinue) -or (Test-Path 'HKLM:/SYSTEM/CurrentControlSet/Services/SbieDrv')) { throw 'Pre-existing engine detected; it will not be modified.' }
$pin = Get-Content (Join-Path $repo 'docs/engine-candidate.json') -Raw | ConvertFrom-Json
$candidate = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $pin.lab_installer } else { $pin.installer }
$installer = Join-Path $out $candidate.name
Invoke-WebRequest -Uri $candidate.url -OutFile $installer
if ((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $candidate.sha256 -or (Get-Item $installer).Length -ne $candidate.size) { throw 'Installer checksum/size mismatch.' }
$signature = Get-AuthenticodeSignature -LiteralPath $installer
if ($signature.Status -ne 'Valid') { throw 'Installer signature is not valid.' }
$reference = Join-Path $out 'authenticated-payload'
$engineHome = Join-Path $env:ProgramFiles 'Sandboxie-Plus'
if (Test-Path $engineHome) { throw 'Existing installation directory will not be overwritten.' }
# Inno switches and portable mode are backed by the pinned installer source.
# No RefreshBuild, ImDisk, UI, reboot or security-setting modification.
foreach ($step in @(
    @{ destination = $reference; options = '/PORTABLE=1 /CURRENTUSER'; name = 'extract' },
    @{ destination = $engineHome; options = '/ALLUSERS'; name = 'install' }
)) {
    $arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /TASKS= `"/DIR=$($step.destination)`" $($step.options)"
    $process = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru
    if (-not $process.WaitForExit(180000)) { throw 'Installer timeout; outcome unknown, no automatic replay.' }
    if ($process.ExitCode -ne 0) { throw "Installer stage failed with code $($process.ExitCode)." }
}
$components = @()
$componentNames = @('SbieDrv.sys', 'SbieSvc.exe', 'SbieDll.dll', 'SbieIni.exe', 'Start.exe', 'SbieMsg.dll', 'KmdUtil.exe', '32/SbieDll.dll')
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $componentNames += '64/SbieDll.dll' }
foreach ($optional in @('QSbieAPI.dll','Qt6Core.dll','Qt6Concurrent.dll','MiscHelpers.dll')) {
    if (Test-Path (Join-Path $engineHome $optional)) { $componentNames += $optional }
}
$componentNames += @(Get-ChildItem -LiteralPath $engineHome -Recurse -File -Filter '*.dll' | ForEach-Object { [IO.Path]::GetRelativePath($engineHome,$_.FullName).Replace('\','/') })
$componentNames = @($componentNames | Select-Object -Unique)
foreach ($name in $componentNames) {
    $installed = Join-Path $engineHome $name
    $original = Join-Path $reference $name
    if (-not (Test-Path $installed) -or -not (Test-Path $original)) { throw 'Required distribution component missing.' }
    $hash = (Get-FileHash $installed -Algorithm SHA256).Hash.ToLowerInvariant()
    $matches = $hash -eq (Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $matches) { throw 'Installed component differs from authenticated installer payload.' }
    $trust = Get-AuthenticodeSignature -LiteralPath $installed
    $components += @{ name = $name; sha256 = $hash; file_version = (Get-Item $installed).VersionInfo.FileVersion; signature = $trust.Status.ToString(); authenticated_payload_match = $matches }
}
$os = Get-CimInstance Win32_OperatingSystem
$security = @{}
try { $security.secure_boot = Confirm-SecureBootUEFI } catch { $security.secure_boot = 'UNKNOWN' }
try { $security.device_guard = Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard | Select-Object VirtualizationBasedSecurityStatus, SecurityServicesRunning, CodeIntegrityPolicyEnforcementStatus } catch { $security.device_guard = 'UNKNOWN' }
try { $security.defender = Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled } catch { $security.defender = 'UNKNOWN' }
$services = @()
foreach ($name in @('SbieSvc', 'SbieDrv')) {
    $service = Get-Service $name -ErrorAction SilentlyContinue
    $services += @{ name = $name; state = $(if ($service) { $service.Status.ToString() } else { 'MISSING' }) }
}
$inventory = @{
    manager_commit = (& git -C $repo rev-parse HEAD).Trim(); source_commit = $pin.source_commit
    timestamp_utc = [DateTime]::UtcNow.ToString('o'); installer_name = $candidate.name
    installer_sha256 = $candidate.sha256; installer_signature = $signature.Status.ToString()
    os = $os | Select-Object Caption, Version, BuildNumber, OSArchitecture, ProductType
    os_update_build_revision = (Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion' -Name UBR).UBR
    security = $security
    components = $components; services = $services; containment_result = 'NOT_RUN'
    teardown = 'DISCARD_ACTIONS_VM'; security_settings_modified = $false
}
$inventory | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out 'installation.json') -Encoding utf8
& (Join-Path $PSScriptRoot 'Build-P02.ps1')
$qtDeletion = @{ component_present = (Test-Path (Join-Path $engineHome 'QSbieAPI.dll')); exports = @(); route = 'PINNED_NATIVE_NTIO_CANDIDATE_NOT_EXECUTED' }
if ($qtDeletion.component_present) {
    $exports = & dumpbin.exe /exports (Join-Path $engineHome 'QSbieAPI.dll')
    if ($LASTEXITCODE -ne 0) { throw 'Export inspection failed.' }
    $qtDeletion.exports = @($exports | ForEach-Object { if ($_ -match '(\?NtIo_(?:DeleteFolderRecursively|WaitForFolder)@@\S+)') { $Matches[1] } })
}
$qtDeletion | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'native-cleanup-discovery.json') -Encoding utf8
$inspection = & (Join-Path $out 'engine_inspect.exe') $engineHome
$inspectorExit = $LASTEXITCODE
$inspection | Set-Content (Join-Path $out 'engine-inspection.json') -Encoding utf8
@{ phase = 'P02'; inspector_exit = $inspectorExit; result = $(if ($inspectorExit -eq 0) { 'ENGINE_QUERY_AVAILABLE' } else { 'BLOCKED' }); containment_result = 'NOT_RUN' } |
    ConvertTo-Json | Set-Content (Join-Path $out 'bootstrap-result.json') -Encoding utf8
if ($inspectorExit -ne 0) { Write-Output 'Engine bootstrap BLOCKED; evidence retained without a security bypass.' }
