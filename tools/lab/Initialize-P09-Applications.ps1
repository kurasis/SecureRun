# Disposable official application fixtures; this is not product installation code.
param([Parameter(Mandatory)][string]$Home,[Parameter(Mandatory)][string]$Out)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true' -or $Home -notmatch '^C:\\Program Files\\SecureRun-P09-[0-9a-f]{32}$'){throw 'P09_DISPOSABLE_SCOPE_REQUIRED'}
$pins=Get-Content (Join-Path $PSScriptRoot 'p09-applications.json') -Raw|ConvertFrom-Json
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'arm64'}else{'x64'}
$downloads=Join-Path $env:RUNNER_TEMP ('SecureRunP09Downloads-'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $downloads
$records=@()
foreach($kind in @('editor','archive','browser')){
 $pin=$pins.$kind;$package=Join-Path $downloads ($kind+$(if($kind -eq 'editor'){'.zip'}else{'.exe'}))
 Invoke-WebRequest -Uri $pin.$arch.url -OutFile $package
 $hash=(Get-FileHash -LiteralPath $package -Algorithm $pin.algorithm).Hash.ToLowerInvariant()
 if($hash -cne $pin.$arch.hash){throw 'OFFICIAL_APP_HASH_MISMATCH'}
 $records+=@{kind=$kind;product=$pin.product;version=$pin.version;architecture=$arch;source=$pin.source;url=$pin.$arch.url;hash_algorithm=$pin.algorithm;package_hash=$hash;bytes=(Get-Item -LiteralPath $package).Length}
}
$archiveHome=Join-Path $Home 'applications/archive';$editorHome=Join-Path $Home 'applications/editor';$browserHome=Join-Path $Home 'applications/browser'
$start=[Diagnostics.ProcessStartInfo]::new((Join-Path $downloads 'archive.exe'));$start.UseShellExecute=$false;$start.ArgumentList.Add('/S');$start.ArgumentList.Add('/D='+$archiveHome)
$p=[Diagnostics.Process]::Start($start);try{if(-not $p.WaitForExit(60000) -or $p.ExitCode -ne 0){throw 'ARCHIVE_FIXTURE_INSTALL_FAILED'}}finally{$p.Dispose()}
if(-not(Test-Path -LiteralPath (Join-Path $archiveHome '7z.exe'))){throw 'ARCHIVE_EXECUTABLE_MISSING'}
Expand-Archive -LiteralPath (Join-Path $downloads 'editor.zip') -DestinationPath $editorHome
$null=New-Item -ItemType Directory -Path $browserHome -Force
& (Join-Path $archiveHome '7z.exe') x -y ('-o'+$browserHome) (Join-Path $downloads 'browser.exe') | Out-Null
if($LASTEXITCODE -ne 0){throw 'BROWSER_FIXTURE_EXTRACT_FAILED'}
$executables=@{editor=(Join-Path $editorHome 'notepad++.exe');archive=(Join-Path $archiveHome '7z.exe');browser=(Join-Path $browserHome 'core/firefox.exe')}
foreach($record in $records){
 $exe=$executables[$record.kind];if(-not(Test-Path -LiteralPath $exe)){throw 'OFFICIAL_APP_EXECUTABLE_MISSING'}
 $signature=Get-AuthenticodeSignature -LiteralPath $exe
 if($record.kind -ne 'archive' -and $signature.Status -ne 'Valid'){throw 'OFFICIAL_APP_SIGNATURE_NOT_VALID'}
 if($record.kind -eq 'archive' -and $signature.Status -notin @('Valid','NotSigned')){throw 'OFFICIAL_ARCHIVE_SIGNATURE_INVALID'}
 $record.executable_sha256=(Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant();$record.signature_status=[string]$signature.Status;$record.file_version=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion
}
$records|ConvertTo-Json -Depth 6|Set-Content (Join-Path $Out 'official-applications.json') -Encoding utf8
return $executables
