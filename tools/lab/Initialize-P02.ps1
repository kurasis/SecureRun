[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This installer spike is restricted to a disposable Actions VM.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo 'artifacts/p02'
New-Item -ItemType Directory -Force -Path $out | Out-Null
if ((Get-Service SbieSvc -ErrorAction SilentlyContinue) -or (Test-Path 'HKLM:/SYSTEM/CurrentControlSet/Services/SbieDrv')) { throw 'Pre-existing engine detected; it will not be modified.' }
$pin = Get-Content (Join-Path $repo 'docs/engine-candidate.json') -Raw | ConvertFrom-Json
$candidate = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $pin.lab_installer } else { $pin.installer }
$installer = Join-Path $out $candidate.name
Invoke-WebRequest -Uri $candidate.url -OutFile $installer
if ((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $candidate.sha256 -or (Get-Item $installer).Length -ne $candidate.size) { throw 'Installer checksum/size mismatch.' }
$signature = Get-AuthenticodeSignature -LiteralPath $installer
if ($signature.Status -ne 'Valid') { throw 'Installer signature is not valid.' }
$reference = Join-Path $out 'authenticated-payload'
$home = Join-Path $env:ProgramFiles 'Sandboxie-Plus'
if (Test-Path $home) { throw 'Existing installation directory will not be overwritten.' }
# Inno switches and portable mode are backed by the pinned installer source.
# No RefreshBuild, ImDisk, UI, reboot or security-setting modification.
foreach ($step in @(
    @{ destination = $reference; options = '/PORTABLE=1 /CURRENTUSER'; name = 'extract' },
    @{ destination = $home; options = '/ALLUSERS'; name = 'install' }
)) {
    $arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /TASKS= `"/DIR=$($step.destination)`" $($step.options)"
    $process = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru
    if (-not $process.WaitForExit(180000)) { throw 'Installer timeout; outcome unknown, no automatic replay.' }
    if ($process.ExitCode -ne 0) { throw "Installer stage failed with code $($process.ExitCode)." }
}
$components = @()
foreach ($name in @('SbieDrv.sys', 'SbieSvc.exe', 'SbieDll.dll', 'SbieIni.exe', 'Start.exe', 'SbieMsg.dll', 'KmdUtil.exe')) {
    $installed = Join-Path $home $name
    $original = Join-Path $reference $name
    if (-not (Test-Path $installed) -or -not (Test-Path $original)) { throw 'Required distribution component missing.' }
    $hash = (Get-FileHash $installed -Algorithm SHA256).Hash.ToLowerInvariant()
    $matches = $hash -eq (Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $matches) { throw 'Installed component differs from authenticated installer payload.' }
    $trust = Get-AuthenticodeSignature -LiteralPath $installed
    $components += @{ name = $name; sha256 = $hash; file_version = (Get-Item $installed).VersionInfo.FileVersion; signature = $trust.Status.ToString(); authenticated_payload_match = $matches }
}
$os = Get-CimInstance Win32_OperatingSystem
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
    components = $components; services = $services; containment_result = 'NOT_RUN'
    teardown = 'DISCARD_ACTIONS_VM'; security_settings_modified = $false
}
$inventory | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out 'installation.json') -Encoding utf8
& (Join-Path $PSScriptRoot 'Build-P02.ps1')
$inspection = & (Join-Path $out 'engine_inspect.exe') $home
$inspectorExit = $LASTEXITCODE
$inspection | Set-Content (Join-Path $out 'engine-inspection.json') -Encoding utf8
@{ phase = 'P02'; inspector_exit = $inspectorExit; result = $(if ($inspectorExit -eq 0) { 'ENGINE_QUERY_AVAILABLE' } else { 'BLOCKED' }); containment_result = 'NOT_RUN' } |
    ConvertTo-Json | Set-Content (Join-Path $out 'bootstrap-result.json') -Encoding utf8
if ($inspectorExit -ne 0) { Write-Output 'Engine bootstrap BLOCKED; evidence retained without a security bypass.' }
