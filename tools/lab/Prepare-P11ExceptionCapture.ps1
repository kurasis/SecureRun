$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true' -or $env:PROCESSOR_ARCHITECTURE -ne 'ARM64'){throw 'DISPOSABLE_ARM_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $PSScriptRoot 'Invoke-P11ExceptionCapture.ps1')
$sourceCheck=Open-P11PinnedFile (Join-Path $repo 'docs/engine-candidate.json');$sourceCheck.Dispose()
$pin=(Get-Content (Join-Path $PSScriptRoot 'p11-diagnostic-tools.json') -Raw|ConvertFrom-Json).procdump
$download=Join-Path $env:RUNNER_TEMP ('p11-procdump-'+[Guid]::NewGuid().ToString('N')+'.zip')
Invoke-WebRequest -Uri $pin.url -OutFile $download
if((Get-Item $download).Length -ne $pin.zip_size -or (Get-FileHash $download).Hash.ToLowerInvariant() -cne $pin.zip_sha256){throw 'DIAGNOSTIC_TOOL_ARCHIVE_PIN_FAILED'}
if($env:GITHUB_RUN_ID -cnotmatch '^\d{1,20}$' -or $env:GITHUB_RUN_ATTEMPT -cnotmatch '^\d{1,6}$'){throw 'DIAGNOSTIC_RUN_ID_INVALID'}
$toolHome=Join-Path $env:ProgramFiles ('SecureRun-P11-Diagnostics-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT)
if(Test-Path -LiteralPath $toolHome){throw 'PREEXISTING_DIAGNOSTIC_TOOL_DIRECTORY_REFUSED'}
$null=New-Item -ItemType Directory -Path $toolHome
$acl=[Security.AccessControl.DirectorySecurity]::new();$admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544');$acl.SetOwner($admins);$acl.SetAccessRuleProtection($true,$false)
foreach($sid in @($admins,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl -LiteralPath $toolHome -AclObject $acl
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($download)
try{foreach($name in @($pin.arm64_name,'Eula.txt')){
 $entry=$archive.GetEntry($name);if($null -eq $entry -or $entry.FullName -cne $name){throw 'DIAGNOSTIC_TOOL_ARCHIVE_ENTRY_INVALID'}
 [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $toolHome $name),$false)
}}finally{$archive.Dispose()}
$exe=Join-Path $toolHome $pin.arm64_name
if((Get-Item $exe).Length -ne $pin.arm64_size -or (Get-FileHash $exe).Hash.ToLowerInvariant() -cne $pin.arm64_sha256 -or (Get-FileHash (Join-Path $toolHome 'Eula.txt')).Hash.ToLowerInvariant() -cne $pin.license_sha256){throw 'DIAGNOSTIC_TOOL_PAYLOAD_PIN_FAILED'}
$signature=Get-AuthenticodeSignature -LiteralPath $exe
if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=Microsoft Corporation(?:,|$)'){throw 'DIAGNOSTIC_TOOL_MICROSOFT_SIGNATURE_REQUIRED'}
$out=Join-Path $repo 'artifacts/p11-diagnostics';$null=New-Item -ItemType Directory -Path $out -Force
$version=[Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion;if($version -cnotmatch '^\d{1,5}(?:\.\d{1,5}){1,3}$'){$version='WITHHELD'}
@{classification='DIAGNOSTIC_ONLY_NOT_SHIPPED';archive_sha256=$pin.zip_sha256;tool_sha256=$pin.arm64_sha256;tool_authenticode='Valid';tool_version=$version;publisher='Microsoft Corporation';protected_admin_system_code=$true;dump_upload_allowed=$false;windows_security_settings_modified=$false}|ConvertTo-Json|Set-Content (Join-Path $out 'debug-tool-verification.json') -Encoding utf8
"home=$toolHome"|Out-File -LiteralPath $env:GITHUB_OUTPUT -Append -Encoding utf8
