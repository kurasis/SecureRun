[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $repo 'artifacts/p06';$null=New-Item -ItemType Directory -Path $out -Force
$commit=(& git -C $repo rev-parse HEAD).Trim()
@{phase='P06';stage='STARTED';manager_commit=$commit}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
$target=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64-pc-windows-msvc'}else{'x86_64-pc-windows-msvc'}
$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
if($LASTEXITCODE -ne 0){throw 'RUST_INSTALL_FAILED'}
Push-Location $repo
try {
    npm ci --ignore-scripts
    if($LASTEXITCODE -ne 0){throw 'NPM_INSTALL_FAILED'}
    npm run build
    if($LASTEXITCODE -ne 0){throw 'UI_BUILD_FAILED'}
    $tests=& cargo test --locked 2>&1;$tests|Out-Host
    if($LASTEXITCODE -ne 0){throw 'UNIT_TEST_FAILED'}
    cargo clippy --locked -p securerun-sandboxie-adapter --all-targets -- -D warnings
    if($LASTEXITCODE -ne 0){throw 'ADAPTER_LINT_FAILED'}
    npm run tauri -- build --debug --no-bundle --target $target
    if($LASTEXITCODE -ne 0){throw 'NATIVE_BUILD_FAILED'}
    $run=[Guid]::NewGuid().ToString('N');$code=Join-Path $env:ProgramFiles "SecureRun-P06-$run";$null=New-Item -ItemType Directory -Path $code
    $app=Join-Path $code 'securerun.exe';Copy-Item "target/$target/debug/securerun.exe" $app
    $normalHash=(Get-FileHash $app).Hash.ToLowerInvariant()
    $targets=@(@{target=$target;suffix=''} ,@{target='i686-pc-windows-msvc';suffix='-x86'})
    if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){$targets+=@{target='x86_64-pc-windows-msvc';suffix='-x64'}}
    foreach($item in $targets){
        rustup target add $item.target
        if($LASTEXITCODE -ne 0){throw 'TARGET_INSTALL_FAILED'}
        cargo build --locked -p securerun-sandboxie-adapter --bins --target $item.target
        if($LASTEXITCODE -ne 0){throw 'PROBE_BUILD_FAILED'}
        foreach($name in @('securerun-policy-probe','securerun-launch-probe')){Copy-Item ("target/"+$item.target+"/debug/$name.exe") (Join-Path $code ($name+$item.suffix+'.exe'))}
    }
    npm run tauri -- build --debug --no-bundle --target $target --features policy-ci
    if($LASTEXITCODE -ne 0){throw 'FAULT_BUILD_FAILED'}
    $fault=Join-Path $code 'fault';$null=New-Item -ItemType Directory -Path $fault;Copy-Item "target/$target/debug/securerun.exe" (Join-Path $fault 'securerun.exe');Get-ChildItem $code -Filter 'securerun-*-probe*.exe'|Copy-Item -Destination $fault
    & (Join-Path $PSScriptRoot 'Initialize-P02.ps1')
    $engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus';$fixture=Join-Path $env:ProgramData "SecureRunLab/p02-p06-$run";$null=New-Item -ItemType Directory -Path $fixture -Force
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/engine_bridge.cs')))
    $bridge=[P02Bridge]::new($engine,$fixture,[string[]]@());$bridge.EnableLabWfp()
    foreach($file in @('p06_standard.ps1','p05_lab.cs','engine_bridge.cs')){Copy-Item (Join-Path $repo "tools/probe/$file") $code}
    $allCases=[Collections.Generic.List[object]]::new();$failedModes=0
    foreach($mode in @('normal','reserved','accepted','scope')) {
    $name='SRP06_'+$mode+'_'+$run.Substring(0,7);$password=ConvertTo-SecureString ('P06aA!'+[Guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $user=New-LocalUser -Name $name -Password $password -AccountNeverExpires
    $group=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1];Add-LocalGroupMember -Group $group -Member $name
    $modeFixture=Join-Path $fixture $mode;$null=New-Item -ItemType Directory -Path $modeFixture
    $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
    foreach($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl $modeFixture $acl
    $shell=(Get-Command pwsh -CommandType Application).Source
    $start=[Diagnostics.ProcessStartInfo]::new($shell);$start.UseShellExecute=$false;$start.WorkingDirectory=$engine;$start.UserName=$name;$start.Domain=[Environment]::MachineName;$start.Password=$password;$start.LoadUserProfile=$true
    $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$start.Environment['GITHUB_ACTIONS']='true'
    foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $code 'p06_standard.ps1'),'-Manager',$app,'-Fixture',$modeFixture,'-Mode',$mode,'-EngineHome',$engine,'-FaultManager',(Join-Path $fault 'securerun.exe'))){$start.ArgumentList.Add($arg)}
    $p=[Diagnostics.Process]::Start($start)
    try{if(-not $p.WaitForExit(900000)){throw 'STANDARD_CONTROL_TIMEOUT'};Get-ChildItem $modeFixture -Filter '*.json'|Where-Object Name -ne 'control-cases.json'|Copy-Item -Destination $out;$modeCases=@(Get-Content (Join-Path $modeFixture 'control-cases.json') -Raw|ConvertFrom-Json);foreach($item in $modeCases){$allCases.Add($item)};if($p.ExitCode -ne 0){$failedModes++}}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose();$password.Dispose()}
    }
    ConvertTo-Json -InputObject @($allCases.ToArray()) -Depth 12|Set-Content (Join-Path $out 'control-cases.json') -Encoding utf8
    $cases=@(Get-Content (Join-Path $out 'control-cases.json') -Raw|ConvertFrom-Json)
    $data=[IO.File]::ReadAllBytes($app);$pe=[BitConverter]::ToInt32($data,0x3c)
    @{phase='P06';result=$(if($failedModes -eq 0){'PASSED'}else{'FAILED'});manager_commit=$commit;manager_binary_sha256=$normalHash;fault_binary_sha256=(Get-FileHash (Join-Path $fault 'securerun.exe')).Hash.ToLowerInvariant();pe_machine=[BitConverter]::ToUInt16($data,$pe+4).ToString('x4');os_build=[Environment]::OSVersion.Version.Build;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;failed=@($cases|Where-Object status -eq 'FAILED').Count;standard_user=$true;elevated_helper=$false;fault_feature_release_enabled=$false;os_security_settings_modified=$false}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
    if($failedModes -ne 0){throw 'NATIVE_CONTROL_FAILED'}
}finally{Pop-Location}
