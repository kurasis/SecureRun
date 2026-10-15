[CmdletBinding()]
param([switch]$Focused)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path;$out=Join-Path $repo 'artifacts/p09';$null=New-Item -ItemType Directory -Path $out -Force;$commit=(& git -C $repo rev-parse HEAD).Trim()
@{phase='P09';stage='STARTED';manager_commit=$commit}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
$target=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64-pc-windows-msvc'}else{'x86_64-pc-windows-msvc'};$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
$actor=$null;$password=$null;$name=$null;$owned=$null;$shareCreated=$false;$displayEvents=@()
Push-Location $repo
try {
 rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
 if($LASTEXITCODE -ne 0){throw 'P09_TOOLCHAIN_FAILED'}
 npm ci --ignore-scripts
 if($LASTEXITCODE -ne 0){throw 'P09_DEPENDENCIES_FAILED'}
 npm run build
 if($LASTEXITCODE -ne 0){throw 'P09_FRONTEND_BUILD_FAILED'}
 npm test
 if($LASTEXITCODE -ne 0){throw 'P09_FOUNDATION_UI_TESTS_FAILED'}
 npm run test:product
 if($LASTEXITCODE -ne 0){throw 'P09_PRODUCT_UI_TESTS_FAILED'}
 $unit=& cargo test --locked 2>&1;$unit|Out-Host
 if($LASTEXITCODE -ne 0){throw 'P09_NATIVE_UNIT_TESTS_FAILED'}
 cargo test --locked -p securerun
 if($LASTEXITCODE -ne 0){throw 'P09_PRODUCT_NATIVE_TESTS_FAILED'}
 cargo clippy --locked -p securerun --all-targets -- -D warnings
 if($LASTEXITCODE -ne 0){throw 'P09_NATIVE_LINT_FAILED'}
 npm run tauri -- build --no-bundle --target $target
 if($LASTEXITCODE -ne 0){throw 'P09_RELEASE_BUILD_FAILED'}
 $run=[Guid]::NewGuid().ToString('N');$productHome=Join-Path $env:ProgramFiles "SecureRun-P09-$run";$null=New-Item -ItemType Directory -Path $productHome;$app=Join-Path $productHome 'securerun.exe';Copy-Item ("target/$target/release/securerun.exe") $app;$managerHash=(Get-FileHash -LiteralPath $app).Hash.ToLowerInvariant()
 $targets=@(@{target=$target;suffix=''},@{target='i686-pc-windows-msvc';suffix='-x86'});if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){$targets+=@{target='x86_64-pc-windows-msvc';suffix='-x64'}}
 foreach($item in $targets){
  rustup target add $item.target
  if($LASTEXITCODE -ne 0){throw 'P09_PROBE_TARGET_FAILED'}
  cargo build --release --locked -p securerun-sandboxie-adapter --bins --target $item.target
  if($LASTEXITCODE -ne 0){throw 'P09_PROBE_BUILD_FAILED'}
  foreach($bin in @('securerun-policy-probe','securerun-launch-probe')){Copy-Item ("target/"+$item.target+"/release/$bin.exe") (Join-Path $productHome ($bin+$item.suffix+'.exe'))}
 }
 Copy-Item ("target/$target/release/securerun-box-launcher.exe") $productHome
 & (Join-Path $PSScriptRoot 'Initialize-P02.ps1')
 & (Join-Path $PSScriptRoot 'Build-P05-View.ps1')
 $protocolBuild=Join-Path $repo 'artifacts/p05-build/p09-protocol-probe.exe'
 & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /MT /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/p09_protocol_probe.c') ("/Fe:"+$protocolBuild)
 if($LASTEXITCODE -ne 0){throw 'P09_PROTOCOL_FIXTURE_BUILD_FAILED'}
 Copy-Item -LiteralPath $protocolBuild -Destination $productHome
 $executables=& (Join-Path $PSScriptRoot 'Initialize-P09-Applications.ps1') -ProductHome $productHome -Out $out
 $engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus';$fixture=Join-Path $env:ProgramData "SecureRunLab/p02-p09-$run";$null=New-Item -ItemType Directory -Path $fixture -Force
 foreach($file in @('p09_standard.ps1','p09_accessibility.ps1','p09_desktop.cs','p09_browser.cs','p09_cdp.ps1','p09_ui.js','p05_lab.cs','engine_bridge.cs','p08_initialize.ps1')){Copy-Item (Join-Path $repo "tools/probe/$file") $productHome}
 $setup=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source);$setup.UseShellExecute=$false;$setup.WorkingDirectory=$engine
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $productHome 'p08_initialize.ps1'),'-EngineHome',$engine,'-Fixture',$fixture)){$setup.ArgumentList.Add($arg)}
 $setup.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$setup.Environment[$key]=$value}};$setup.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$setup.Environment['GITHUB_ACTIONS']='true'
 $p=[Diagnostics.Process]::Start($setup);try{if(-not $p.WaitForExit(60000) -or $p.ExitCode -ne 0){throw 'P09_LAB_WFP_SETUP_FAILED'}}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
 $share='SecureRunP05Synthetic';if($null -ne(Get-SmbShare -Name $share -ErrorAction SilentlyContinue)){throw 'P09_PREEXISTING_SHARE_NOT_CHANGED'}
 $shareRoot=Join-Path $fixture 'synthetic-network';$null=New-Item -ItemType Directory -Path $shareRoot;[IO.File]::WriteAllText((Join-Path $shareRoot 'canary.txt'),'SYNTHETIC_NETWORK_CANARY')
 $users=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value;$admins=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')).Translate([Security.Principal.NTAccount]).Value
 $null=New-SmbShare -Name $share -Path $shareRoot -ReadAccess $users -FullAccess $admins;$shareCreated=$true
 $name='SRP09_'+$run.Substring(0,10);$password=ConvertTo-SecureString ('P09aA!'+[Guid]::NewGuid().ToString('N')) -AsPlainText -Force;$user=New-LocalUser -Name $name -Password $password -AccountNeverExpires;$group=$users.Split('\')[-1];Add-LocalGroupMember -Group $group -Member $name
 $owned=Join-Path $fixture 'owner';$null=New-Item -ItemType Directory -Path $owned;$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
 foreach($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl $owned $acl
 # Lab-only fixed display actions. No actor-supplied paths, scripts or data cross
 # this boundary. The normal product never receives these event names.
 $displayPrefix='Local\SecureRunP09Display-'+$run;$eventAcl=[Security.AccessControl.EventWaitHandleSecurity]::new()
 $eventAcl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.AccessControl.EventWaitHandleRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
 $eventAcl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new($user.SID,([Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify),[Security.AccessControl.AccessControlType]::Allow))
 foreach($suffix in @('100','150','200','done','failed')){$created=$false;$event=[Threading.EventWaitHandleAcl]::Create($false,[Threading.EventResetMode]::AutoReset,$displayPrefix+'-'+$suffix,[ref]$created,$eventAcl);if(-not $created){$event.Dispose();throw 'P09_PREEXISTING_DISPLAY_EVENT'};$displayEvents+=,$event}
 $start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source);$start.UseShellExecute=$false;$start.WorkingDirectory=$engine;$start.UserName=$name;$start.Domain=[Environment]::MachineName;$start.Password=$password;$start.LoadUserProfile=$true
 $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$start.Environment['GITHUB_ACTIONS']='true'
 $start.Environment['SECURERUN_P09_DISPLAY_EVENTS']=$displayPrefix
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $productHome 'p09_standard.ps1'),'-Manager',$app,'-Fixture',$owned,'-EngineHome',$engine,'-Commit',$commit)){$start.ArgumentList.Add($arg)}
 if($Focused){$start.ArgumentList.Add('-Focused')}
 $actor=[Diagnostics.Process]::Start($start);$actorClock=[Diagnostics.Stopwatch]::StartNew();$displayRequests=0
 while(-not $actor.WaitForExit(250)){
  if($actorClock.ElapsedMilliseconds -ge 2700000){throw 'P09_PRODUCT_ACTOR_TIMEOUT'}
  $index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$displayEvents[0..2],0)
  if($index -lt 3){
   $displayRequests++;if($displayRequests -gt 8){$null=$displayEvents[4].Set();throw 'P09_DISPLAY_REQUEST_BOUND'}
   $display=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$display.UseShellExecute=$false;$display.WorkingDirectory=Join-Path $env:SystemRoot 'System32'
   foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $productHome 'p09_accessibility.ps1'),'-Mode','DISPLAY_CONTROLLER','-Scale',[string]@(100,150,200)[$index])){$display.ArgumentList.Add($arg)}
   $display.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','PATH','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$display.Environment[$key]=$value}};$display.Environment['GITHUB_ACTIONS']='true'
   $controller=[Diagnostics.Process]::Start($display)
   try{$completed=$controller.WaitForExit(90000);if($completed -and $controller.ExitCode -eq 0){$null=$displayEvents[3].Set()}else{$null=$displayEvents[4].Set()}}finally{if(-not $controller.HasExited){$controller.Kill($true)};$controller.Dispose()}
  }
 }
 $resultHome=Join-Path $owned 'results';if(Test-Path -LiteralPath $resultHome){Get-ChildItem -LiteralPath $resultHome -File|Where-Object {$_.Extension -in @('.json','.png')}|Copy-Item -Destination $out}
 if(-not(Test-Path -LiteralPath (Join-Path $out 'standard-product.json'))){throw 'P09_ACTOR_REPORT_MISSING'}
 $result=Get-Content (Join-Path $out 'standard-product.json') -Raw|ConvertFrom-Json
 $summary=@{phase='P09';result=$(if($actor.ExitCode -eq 0 -and $result.status -eq 'PASSED'){'PASSED'}else{'FAILED'});manager_commit=$commit;manager_binary_sha256=$managerHash;build='release';pe_machine=$(if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aa64'}else{'8664'});os_build=[Environment]::OSVersion.Version.Build;standard_user=$true;real_normal_webview=$true;synthetic_profiles_only=$true;browser_sandbox_disabled=$false;os_security_settings_modified=$false;elevated_product_helper=$false}
 foreach($field in @('native_cases_passed','failed','ui_cases_passed','ui_failed')){$summary[$field]=if($result.PSObject.Properties[$field]){$result.$field}else{-1}}
 $summary|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
 $summary.workload_mode=if($Focused){'DIAGNOSTIC_ONLY'}else{'FULL'}
 if($Focused -and $actor.ExitCode -eq 0 -and $result.status -eq 'DIAGNOSTIC_ONLY'){$summary.result='DIAGNOSTIC_ONLY'}
 $summary|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
 if($summary.result -ne 'PASSED' -and -not($Focused -and $summary.result -eq 'DIAGNOSTIC_ONLY')){throw 'P09_NATIVE_PRODUCT_GATE_FAILED'}
 @{phase='P09';stage='COMPLETE';manager_commit=$commit}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
}finally{
 if($null -ne $actor){if(-not $actor.HasExited){$actor.Kill($true);$null=$actor.WaitForExit(10000)};$actor.Dispose()}
 foreach($event in $displayEvents){$event.Dispose()}
 if($owned){$partial=Join-Path $owned 'results';if(Test-Path -LiteralPath $partial){Get-ChildItem -LiteralPath $partial -File|Where-Object {$_.Extension -in @('.json','.png')}|Copy-Item -Destination $out}}
 if($null -ne $password){$password.Dispose()};if($name){Disable-LocalUser -Name $name -ErrorAction SilentlyContinue};if($shareCreated){Remove-SmbShare -Name 'SecureRunP05Synthetic' -Force -Confirm:$false};Pop-Location
}
