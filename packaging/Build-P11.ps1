[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
foreach($name in @('RUSTFLAGS','CARGO_ENCODED_RUSTFLAGS','VITE_FOUNDATION_CI','TAURI_CONFIG')){
 if([Environment]::GetEnvironmentVariable($name)){throw 'P11_UNREVIEWED_BUILD_OVERRIDE_PRESENT'}
}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out=Join-Path $repo 'artifacts/p11';$packages=Join-Path $repo 'artifacts/p11-packages'
foreach($p in @($out,$packages)){ $null=New-Item -ItemType Directory -Path $p -Force }
$native=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'arm64'}else{'x64'}
$target=if($native -eq 'arm64'){'aarch64-pc-windows-msvc'}else{'x86_64-pc-windows-msvc'}
$innoArch=if($native -eq 'arm64'){'arm64'}else{'x64os'}
$pin=Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw|ConvertFrom-Json
$downloads=Join-Path $packages 'downloads';$null=New-Item -ItemType Directory -Path $downloads -Force
$trust=@()
$items=@(@{kind='inno';file='inno.exe'},@{kind='webview2';file='MicrosoftEdgeWebview2Setup.exe'})
$crtArchitectures=@('x86','x64');if($native -eq 'arm64'){$crtArchitectures+='arm64'}
foreach($arch in $crtArchitectures){$items+=@{kind='vcredist';architecture=$arch;file=('vc_redist.'+$arch+'.exe')}}
foreach($item in $items){
 $entry=if($item.kind -eq 'vcredist'){$pin.vcredist.($item.architecture)}else{$pin.($item.kind)};$path=Join-Path $downloads $item.file
 Invoke-WebRequest -Uri $entry.url -OutFile $path
 $hash=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
 if($hash -ne $entry.sha256){throw 'P11_TOOL_DOWNLOAD_HASH_MISMATCH'}
 $sig=Get-AuthenticodeSignature -LiteralPath $path
 if($sig.Status -ne 'Valid'){throw 'P11_TOOL_SIGNATURE_INVALID'}
 if($item.kind -ne 'inno' -and $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw 'P11_MICROSOFT_PUBLISHER_REQUIRED'}
 if($item.kind -ne 'inno' -and (Get-Item $path).Length -ne $entry.size){throw 'P11_PREREQUISITE_SIZE_MISMATCH'}
 $trust+=@{kind=$item.kind;sha256=$hash;signature=$sig.Status.ToString();publisher=$sig.SignerCertificate.Subject;size=(Get-Item $path).Length;file_version=(Get-Item $path).VersionInfo.FileVersion}
}
$compilerHome=Join-Path $packages 'inno'
$p=Start-Process -FilePath (Join-Path $downloads 'inno.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR="'+$compilerHome+'"')) -PassThru -Wait
if($p.ExitCode -ne 0){throw 'P11_COMPILER_INSTALL_FAILED'};$p.Dispose()
$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
Push-Location $repo
try{
 rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
 if($LASTEXITCODE -ne 0){throw 'P11_RUST_SETUP_FAILED'}
 & (Join-Path $repo 'tools/lab/Install-P09-Node.ps1')
 npm run tauri -- build --no-bundle --target $target
 if($LASTEXITCODE -ne 0){throw 'P11_RELEASE_BUILD_FAILED'}
 $payload=Join-Path $packages 'payload';$null=New-Item -ItemType Directory -Path $payload -Force
 Copy-Item "target/$target/release/securerun.exe" $payload
 # These fixed probes/launcher are production policy components, not the lab's C probes.
 $targets=@(@{target=$target;suffix=''},@{target='i686-pc-windows-msvc';suffix='-x86'})
 if($native -eq 'arm64'){$targets+=@{target='x86_64-pc-windows-msvc';suffix='-x64'}}
 foreach($item in $targets){
  rustup target add $item.target
  if($LASTEXITCODE -ne 0){throw 'P11_TARGET_SETUP_FAILED'}
  cargo build --locked --release -p securerun-sandboxie-adapter --bins --target $item.target
  if($LASTEXITCODE -ne 0){throw 'P11_PROBE_BUILD_FAILED'}
  foreach($bin in @('securerun-policy-probe','securerun-launch-probe')){Copy-Item ("target/"+$item.target+"/release/$bin.exe") (Join-Path $payload ($bin+$item.suffix+'.exe'))}
 }
 Copy-Item "target/$target/release/securerun-box-launcher.exe" $payload
 $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
 $vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
 if($LASTEXITCODE -ne 0 -or -not $vs){throw 'P11_MSVC_REQUIRED'}
 Import-Module (Join-Path $vs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
 Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=$native -host_arch=$native"|Out-Null
 Push-Location $packages
 try{& cl.exe /nologo /W4 /WX /O2 /MT /DUNICODE /D_UNICODE (Join-Path $PSScriptRoot 'install-guard.c') ('/Fe:'+(Join-Path $payload 'install-guard.exe'))
 if($LASTEXITCODE -ne 0){throw 'P11_GUARD_BUILD_FAILED'}}finally{Pop-Location}
 python (Join-Path $PSScriptRoot 'inventory.py') --target $target --output $payload
 if($LASTEXITCODE -ne 0){throw 'P11_LICENSE_INVENTORY_FAILED'}
 Copy-Item (Join-Path $compilerHome 'License.txt') (Join-Path $payload 'INNO_LICENSE.txt')
 Copy-Item (Join-Path $PSScriptRoot 'DEVELOPMENT.txt'),(Join-Path $PSScriptRoot 'RETENTION.txt') $payload
 Copy-Item (Join-Path $PSScriptRoot 'notices/*.txt') $payload
 Copy-Item (Join-Path $PSScriptRoot 'compatibility.json') $payload
 Copy-Item (Join-Path $repo 'crates/sandboxie-adapter/compatibility-v1.json'),(Join-Path $repo 'crates/sandboxie-adapter/cleanup-compatibility-v1.json') $payload
 $files=@(Get-ChildItem $payload -File|Sort-Object Name|ForEach-Object {
  $record=@{name=$_.Name;size=$_.Length;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}
  if($_.Extension -eq '.exe'){$bytes=[IO.File]::ReadAllBytes($_.FullName);$pe=[BitConverter]::ToInt32($bytes,0x3c);$record.pe_machine=('{0:x4}' -f [BitConverter]::ToUInt16($bytes,$pe+4));$record.signature=(Get-AuthenticodeSignature $_.FullName).Status.ToString()}
  $record
 })
 $source=(& git rev-parse HEAD).Trim()
 @{schema=1;phase='P11';source_commit=$source;target=$target;product_version='0.3.0';payload_revision='P11_SOURCE_BOUND_RUNTIME_SCHEMA_1';signing_status='UNSIGNED_DEVELOPMENT_ONLY';features=@();engine_bundled=$false;files=$files;prerequisite_trust=$trust}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $payload 'package-manifest.json') -Encoding utf8
 $compiled=@()
 $imports=@{}
 foreach($file in Get-ChildItem $payload -Filter '*.exe'){
  $dump=& dumpbin.exe /dependents $file.FullName
  if($LASTEXITCODE -ne 0){throw 'P11_IMPORT_INSPECTION_FAILED'}
  $imports[$file.Name]=@($dump|ForEach-Object {if($_ -match '^\s+([A-Za-z0-9_.-]+\.dll)\s*$'){$Matches[1].ToLowerInvariant()}}|Sort-Object -Unique)
 }
 $versions=@{rust=(& rustc --version);node=(& node --version);npm=(& npm --version);msvc_toolset=$env:VCToolsVersion;windows_sdk=$env:WindowsSDKVersion.TrimEnd('\')}
 # Compile the exact guard into BOTH setup and uninstaller script bytecode.
 # Uninstall must not execute a directory-resident guard before trusting it.
 $guardBytes=[IO.File]::ReadAllBytes((Join-Path $payload 'install-guard.exe'))
 if($guardBytes.Length -gt 2097152){throw 'P11_EMBEDDED_GUARD_SIZE_BOUND'}
 $hex=[Convert]::ToHexString($guardBytes);$lines=[Collections.Generic.List[string]]::new()
 $lines.Add('function EmbeddedGuardHex(): String;');$lines.Add('begin');$lines.Add('  Result := '''';')
 for($i=0;$i -lt $hex.Length;$i+=2048){$lines.Add('  Result := Result + '''+$hex.Substring($i,[Math]::Min(2048,$hex.Length-$i))+''';')}
 $lines.Add('end;');$guardData=Join-Path $packages 'guard-data.iss';[IO.File]::WriteAllLines($guardData,$lines,[Text.UTF8Encoding]::new($false))
 $guardHash=(Get-FileHash (Join-Path $payload 'install-guard.exe')).Hash.ToLowerInvariant()
 foreach($version in @('0.3.0.10','0.3.0.11')){
  & (Join-Path $compilerHome 'ISCC.exe') ("/DPayload=$payload") ("/DOutput=$packages") ("/DArchitecture=$innoArch") ("/DMinimumCRT="+$env:VCToolsVersion.TrimEnd('\')+'.0') ("/DPackageVersion=$version") ("/DGuardDataFile=$guardData") ("/DGuardSHA256=$guardHash") ("/DBootstrapper="+(Join-Path $downloads 'MicrosoftEdgeWebview2Setup.exe')) ("/DCRTDirectory=$downloads") (Join-Path $PSScriptRoot 'securerun.iss')
  if($LASTEXITCODE -ne 0){throw 'P11_INSTALLER_COMPILE_FAILED'}
  $name="SecureRun-Development-$version-$innoArch.exe";$path=Join-Path $packages $name
  $compiled+=@{name=$name;package_version=$version;sha256=(Get-FileHash $path).Hash.ToLowerInvariant();size=(Get-Item $path).Length;signature=(Get-AuthenticodeSignature $path).Status.ToString()}
 }
 Copy-Item (Join-Path $payload 'package-manifest.json'),(Join-Path $payload 'dependency-inventory.json') $out
 @{phase='P11';source_commit=$source;target=$target;signing_status='UNSIGNED_DEVELOPMENT_ONLY';packages=$compiled;prerequisite_trust=$trust;tool_versions=$versions;pe_dll_imports=$imports;engine_bundled=$false;baseline='SAME_REVIEWED_RUNTIME_SCHEMA_1_PACKAGING_REVISION_10';candidate='PACKAGING_REVISION_11'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $out 'build.json') -Encoding utf8
 $compiled|ForEach-Object {($_.sha256+'  '+$_.name)}|Set-Content (Join-Path $packages 'SHA256SUMS') -Encoding ascii
}finally{Pop-Location}
