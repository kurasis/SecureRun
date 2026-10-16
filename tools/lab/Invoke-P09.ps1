[CmdletBinding()]
param([switch]$Focused,[switch]$LayoutOnly,[switch]$AppsOnly)
if($LayoutOnly -and $AppsOnly){throw 'P09_DIAGNOSTIC_MODE_CONFLICT'}
if($LayoutOnly -or $AppsOnly){$Focused=$true}
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path;$out=Join-Path $repo 'artifacts/p09';$null=New-Item -ItemType Directory -Path $out -Force;$commit=(& git -C $repo rev-parse HEAD).Trim();$labStarted=[DateTime]::UtcNow
@{phase='P09';stage='STARTED';manager_commit=$commit}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
$target=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64-pc-windows-msvc'}else{'x86_64-pc-windows-msvc'};$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
$controller=$null;$actor=$null;$password=$null;$name=$null;$owned=$null;$shareCreated=$false;$displayEvents=@()
Push-Location $repo
try {
 rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
 if($LASTEXITCODE -ne 0){throw 'P09_TOOLCHAIN_FAILED'}
 & (Join-Path $PSScriptRoot 'Install-P09-Node.ps1')
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
 if(-not $LayoutOnly){
 $protocolBuild=Join-Path $repo 'artifacts/p05-build/p09-protocol-probe.exe'
 & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /MT /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/p09_protocol_probe.c') ("/Fe:"+$protocolBuild)
 if($LASTEXITCODE -ne 0){throw 'P09_PROTOCOL_FIXTURE_BUILD_FAILED'}
 Copy-Item -LiteralPath $protocolBuild -Destination $productHome
 $executables=& (Join-Path $PSScriptRoot 'Initialize-P09-Applications.ps1') -ProductHome $productHome -Out $out
 }
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
 # Lab-only fixed display and initial-desktop actions. No actor-supplied paths, scripts or data cross
 # this boundary. The normal product never receives these event names.
 $displayPrefix='Local\SecureRunP09Display-'+$run;$eventAcl=[Security.AccessControl.EventWaitHandleSecurity]::new()
 $eventAcl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.AccessControl.EventWaitHandleRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
 $eventAcl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new($user.SID,([Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify),[Security.AccessControl.AccessControlType]::Allow))
 foreach($suffix in @('100','150','200','prepare','done','failed')){$created=$false;$event=[Threading.EventWaitHandleAcl]::Create($false,[Threading.EventResetMode]::AutoReset,$displayPrefix+'-'+$suffix,[ref]$created,$eventAcl);if(-not $created){$event.Dispose();throw 'P09_PREEXISTING_DISPLAY_EVENT'};$displayEvents+=,$event}
 $start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source);$start.UseShellExecute=$false;$start.WorkingDirectory=$engine;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$start.UserName=$name;$start.Domain=[Environment]::MachineName;$start.Password=$password;$start.LoadUserProfile=$true
 $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$start.Environment['GITHUB_ACTIONS']='true'
 $actorTemp=Join-Path $owned 'temp';$null=New-Item -ItemType Directory -Path $actorTemp;$start.Environment['TEMP']=$actorTemp;$start.Environment['TMP']=$actorTemp
 $start.Environment['SECURERUN_P09_DISPLAY_EVENTS']=$displayPrefix
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $productHome 'p09_standard.ps1'),'-Manager',$app,'-Fixture',$owned,'-EngineHome',$engine,'-Commit',$commit)){$start.ArgumentList.Add($arg)}
 if($Focused){$start.ArgumentList.Add('-Focused')}
 if($LayoutOnly){$start.ArgumentList.Add('-LayoutOnly')}
 if($AppsOnly){$start.ArgumentList.Add('-AppsOnly')}
 $display=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$display.UseShellExecute=$false;$display.CreateNoWindow=$true;$display.WorkingDirectory=Join-Path $env:SystemRoot 'System32'
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $productHome 'p09_accessibility.ps1'),'-Mode','DISPLAY_SERVER','-DisplayEvents',$displayPrefix,'-ResultFile',(Join-Path $out 'display-controller'))){$display.ArgumentList.Add($arg)}
 $display.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','PATH','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','ProgramFiles','ProgramW6432')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$display.Environment[$key]=$value}};$display.Environment['GITHUB_ACTIONS']='true'
 $controller=[Diagnostics.Process]::Start($display)
 $readyClock=[Diagnostics.Stopwatch]::StartNew();$readyIndex=258
 do{$readyIndex=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$displayEvents[4..5],250);if($readyIndex -lt 2 -or $controller.HasExited){break}}while($readyClock.ElapsedMilliseconds -lt 90000)
 $controllerReady=($readyIndex -eq 0 -and -not $controller.HasExited)
 if(-not $controllerReady -and -not $controller.HasExited){$controller.Kill($true);$null=$controller.WaitForExit(10000)}
 @{startup_ready=$controllerReady;process_completed=$controller.HasExited;exit_code=$(if($controller.HasExited){$controller.ExitCode}else{$null});fixture_only=$true;independent_product_cases_continue=$true}|ConvertTo-Json|Set-Content (Join-Path $out 'display-controller.lifecycle.json') -Encoding utf8
 # Cancel only the initial authenticated same-user Windows app chooser before
 # any product GUI/target starts. Never select an application or change defaults.
 $prepare=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$prepare.UseShellExecute=$false;$prepare.CreateNoWindow=$true;$prepare.WorkingDirectory=Join-Path $env:SystemRoot 'System32'
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $productHome 'p09_accessibility.ps1'),'-Mode','DESKTOP_PREPARE','-ResultFile',(Join-Path $out 'initial-desktop-preparation.json'))){$prepare.ArgumentList.Add($arg)}
 $prepare.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','PATH','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','ProgramFiles','ProgramW6432')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$prepare.Environment[$key]=$value}};$prepare.Environment['GITHUB_ACTIONS']='true'
 $preparer=[Diagnostics.Process]::Start($prepare);try{if(-not $preparer.WaitForExit(90000) -or $preparer.ExitCode -ne 0){throw 'P09_INITIAL_DESKTOP_PREPARATION_FAILED'}}finally{if(-not $preparer.HasExited){$preparer.Kill($true)};$preparer.Dispose()}
 # Enroll initial hidden process instances in the long-lived controller itself;
 # the separate initial cleaner cannot transfer its process identity set.
 if($controllerReady){$null=$displayEvents[3].Set();if([Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$displayEvents[4..5],90000) -ne 0){throw 'P09_INITIAL_CONTROLLER_ENROLLMENT_FAILED'}}
 $actor=[Diagnostics.Process]::Start($start);$actorClock=[Diagnostics.Stopwatch]::StartNew()
 while(-not $actor.WaitForExit(250)){
  if($actorClock.ElapsedMilliseconds -ge 2700000){throw 'P09_PRODUCT_ACTOR_TIMEOUT'}
  if($controller.HasExited){$controllerReady=$false}
  if(-not $controllerReady){$index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$displayEvents[0..3],0);if($index -lt 4){$null=$displayEvents[5].Set()}}
 }
 $resultHome=Join-Path $owned 'results';if(Test-Path -LiteralPath $resultHome){Get-ChildItem -LiteralPath $resultHome -File|Where-Object {$_.Extension -in @('.json','.png')}|Copy-Item -Destination $out}
 if(-not(Test-Path -LiteralPath (Join-Path $out 'standard-product.json'))){throw 'P09_ACTOR_REPORT_MISSING'}
 $result=Get-Content (Join-Path $out 'standard-product.json') -Raw|ConvertFrom-Json
 $budgetStatus='NOT_MEASURED'
 if(-not $Focused -and (Test-Path (Join-Path $out 'performance.json')) -and (Test-Path (Join-Path $out 'process-update.json')) -and (Test-Path (Join-Path $out 'launch-performance.json'))){
  & python (Join-Path $PSScriptRoot 'retain_p09_evidence.py') --assess-budget-directory $out
  if($LASTEXITCODE -ne 0){throw 'P09_BUDGET_MEASUREMENT_INVALID'}
  $budgetStatus=(Get-Content (Join-Path $out 'performance-budget-assessment.json') -Raw|ConvertFrom-Json).status
 }
 if(-not $Focused -and $result.status -eq 'PASSED' -and $budgetStatus -eq 'NOT_MEASURED'){throw 'P09_PERFORMANCE_PROOF_MISSING'}
 $summary=@{phase='P09';result=$(if($actor.ExitCode -eq 0 -and $result.status -eq 'PASSED'){'PASSED'}else{'FAILED'});manager_commit=$commit;manager_binary_sha256=$managerHash;build='release';pe_machine=$(if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aa64'}else{'8664'});os_build=[Environment]::OSVersion.Version.Build;engineering_budget_status=$budgetStatus;standard_user=$true;real_normal_webview=(-not [bool]$AppsOnly);apps_only=[bool]$AppsOnly;synthetic_profiles_only=$true;browser_sandbox_disabled=$false;os_security_settings_modified=$false;elevated_product_helper=$false}
 foreach($field in @('native_cases_passed','failed','ui_cases_passed','ui_failed')){$summary[$field]=if($result.PSObject.Properties[$field]){$result.$field}else{-1}}
 $summary|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
 $summary.workload_mode=if($Focused){'DIAGNOSTIC_ONLY'}else{'FULL'}
 if($Focused -and $actor.ExitCode -eq 0 -and $result.status -eq 'DIAGNOSTIC_ONLY'){$summary.result='DIAGNOSTIC_ONLY'}
 $summary|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
 if($summary.result -ne 'PASSED' -and -not($Focused -and $summary.result -eq 'DIAGNOSTIC_ONLY')){throw 'P09_NATIVE_PRODUCT_GATE_FAILED'}
 @{phase='P09';stage='COMPLETE';manager_commit=$commit}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
}finally{
 if($null -ne $actor){if(-not $actor.HasExited){$actor.Kill($true);$null=$actor.WaitForExit(10000)};$actor.Dispose()}
 if($null -ne $controller){if(-not $controller.HasExited){$controller.Kill($true);$null=$controller.WaitForExit(10000)};$controller.Dispose()}
 foreach($event in $displayEvents){$event.Dispose()}
 if($owned){$partial=Join-Path $owned 'results';if(Test-Path -LiteralPath $partial){Get-ChildItem -LiteralPath $partial -File|Where-Object {$_.Extension -in @('.json','.png')}|Copy-Item -Destination $out}}
 # Read-only diagnosis of crashes in the fixed synthetic/engine components.
 # Never retain event messages, command lines, paths, SIDs or arbitrary app names.
 $faults=[Collections.Generic.List[object]]::new();$faultLogAvailable=$true
 try{
  $known=@('securerun-policy-probe.exe','securerun-policy-probe-x86.exe','securerun-policy-probe-x64.exe','securerun-launch-probe.exe','SandboxieRpcSs.exe','SandboxieDcomLaunch.exe','SandboxieCrypto.exe','SandboxieBITS.exe','SbieSvc.exe')
  $modules=@('SbieDll.dll','ntdll.dll','KERNELBASE.dll','kernel32.dll','ucrtbase.dll','wow64.dll','wow64win.dll','wow64cpu.dll')+$known
  foreach($event in @(Get-WinEvent -FilterHashtable @{LogName='Application';Id=@(1000,1001);StartTime=$labStarted} -MaxEvents 256 -ErrorAction SilentlyContinue)){
   $xml=[xml]$event.ToXml();$fields=@{};foreach($item in $xml.Event.EventData.Data){$fields[$item.GetAttribute('Name')]=$item.InnerText}
   $app=if($fields.ContainsKey('AppName')){$fields['AppName']}elseif($fields.ContainsKey('P1')){$fields['P1']}else{''}
   if($app -notin $known){continue};$module=if($fields.ContainsKey('ModuleName') -and $fields['ModuleName'] -in $modules){$fields['ModuleName']}else{'WITHHELD'}
   $exception=if($fields.ContainsKey('ExceptionCode') -and $fields['ExceptionCode'] -cmatch '^(0x)?[0-9a-fA-F]{8}$'){$fields['ExceptionCode'].ToLowerInvariant()}else{'WITHHELD'}
   $faults.Add(@{event_id=$event.Id;application_kind=$app;fault_module_kind=$module;exception_code_hex=$exception});if($faults.Count -ge 64){break}
  }
 }catch{$faultLogAvailable=$false}
 @{schema=1;read_only_fault_log_available=$faultLogAvailable;fixed_component_events=@($faults.ToArray());raw_event_messages_retained=$false;os_error_reporting_modified=$false}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'component-faults.json') -Encoding utf8
 # Optional readonly classification while a reporter is still alive. Event
 # 1000/1001 may not exist until reporting completes. CIM association is only
 # diagnostic: never authority to terminate, trust, or pass a boxed result.
 $liveFaults=[Collections.Generic.List[object]]::new();$liveFaultAvailable=$true
 try{
  $components=@('securerun-policy-probe.exe','securerun-policy-probe-x86.exe','securerun-policy-probe-x64.exe','securerun-launch-probe.exe','securerun-launch-probe-x86.exe','securerun-launch-probe-x64.exe','SandboxieRpcSs.exe','SandboxieDcomLaunch.exe','SandboxieCrypto.exe','SandboxieBITS.exe','SbieSvc.exe','dllhost.exe','taskhostw.exe','rundll32.exe','svchost.exe')
  $processes=@(Get-CimInstance -ClassName Win32_Process -OperationTimeoutSec 10 -ErrorAction Stop)
  foreach($reporter in @($processes|Where-Object Name -IEQ 'WerFault.exe'|Select-Object -First 16)){
   $kind='WITHHELD';$observed=$false
   if($reporter.CommandLine -match '(?i)(?:^|\s)-p\s+([0-9]{1,10})(?:\s|$)'){
    $targetId=[uint32]0
    if([uint32]::TryParse($Matches[1],[ref]$targetId)){
     $targetProcess=@($processes|Where-Object ProcessId -EQ $targetId)
     if($targetProcess.Count -eq 1){$observed=$true;if($targetProcess[0].Name -in $components){$kind=$components|Where-Object {$_ -ieq $targetProcess[0].Name}|Select-Object -First 1}}
    }
   }
   $liveFaults.Add(@{reporter_kind='WerFault.exe';associated_component_kind=$kind;cim_target_present=$observed;association_authorizes_no_action=$true})
  }
 }catch{$liveFaultAvailable=$false}
 @{schema=1;readonly_cim_available=$liveFaultAvailable;records=@($liveFaults.ToArray());raw_arguments_paths_and_ids_retained=$false;termination_dispatched=$false;os_error_reporting_modified=$false}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'live-fault-reporters.json') -Encoding utf8
 if($null -ne $password){$password.Dispose()};if($name){Disable-LocalUser -Name $name -ErrorAction SilentlyContinue};if($shareCreated){Remove-SmbShare -Name 'SecureRunP05Synthetic' -Force -Confirm:$false};Pop-Location
}
