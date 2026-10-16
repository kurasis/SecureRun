param([string]$Manager,[string]$EngineHome,[string]$Fixture,[string]$Commit,[switch]$Focused,[switch]$LayoutOnly,[switch]$AppsOnly)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$cases=[Collections.Generic.List[object]]::new();$script:uiCases=[Collections.Generic.List[object]]::new();$script:lastUi=$null;$script:stage='INITIALIZING';$script:capturesClean=$true;$script:failureCode=$null;$script:browserGuiPid=0;$script:browserReceipt=$null
$results=Join-Path $Fixture 'results';$null=New-Item -ItemType Directory -Path $results -Force
# Derive these from this logged-on standard user's loaded OS profile, not the
# elevated parent environment. TEMP is a private fixture child with inherited ACL.
$env:USERPROFILE=[Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$env:LOCALAPPDATA=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$env:APPDATA=[Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
$env:TEMP=Join-Path $Fixture 'temp';$env:TMP=$env:TEMP
foreach($path in @($env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,$env:TEMP)){if(-not [IO.Path]::IsPathRooted($path) -or $path.StartsWith('\\')){throw 'P09_OWNER_PROFILE_UNAVAILABLE'}}
$tempCanary=Join-Path $env:TEMP ('p09-write-'+[Guid]::NewGuid().ToString('N'));[IO.File]::WriteAllText($tempCanary,'SYNTHETIC_TEMP_PROOF');[IO.File]::Delete($tempCanary)
@{os_observed_profile_environment=$true;owner_private_temp_writable=$true;parent_profile_environment_used=$false;synthetic_fixture_only=$true}|ConvertTo-Json|Set-Content (Join-Path $results 'actor-profile.json') -Encoding utf8
function Require([bool]$Ok,[string]$Code){if(-not $Ok){$script:failureCode=$Code;throw $Code}}
function Save {ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 20|Set-Content (Join-Path $results 'product-cases.json') -Encoding utf8;ConvertTo-Json -InputObject @($script:uiCases.ToArray()) -Depth 10|Set-Content (Join-Path $results 'ui-cases.json') -Encoding utf8}
function Case([string]$Id,[string]$Name,[scriptblock]$Body){$caseClock=[Diagnostics.Stopwatch]::StartNew();$script:stage=$Name;$script:failureCode=$null;$script:lastUi=$null;$record=@{id=$Id;name=$Name;status='IN_PROGRESS'};$cases.Add($record);Save;try{$record.evidence=(& $Body);$record.status='PASSED'}catch{$record.status='FAILED';$record.code=if($script:failureCode){$script:failureCode}else{'P09_CASE_FAILED'};$record.line=$_.InvocationInfo.ScriptLineNumber;$record.exception_type=$_.Exception.GetBaseException().GetType().FullName;$record.elapsed_ms=$caseClock.ElapsedMilliseconds;if($_.Exception.GetBaseException() -is [Net.Sockets.SocketException]){$record.socket_error_code=$_.Exception.GetBaseException().SocketErrorCode.ToString()};$message=$_.Exception.GetBaseException().Message;if($message -cmatch '^P09_[A-Z0-9_]{1,100}$'){$record.code=$message};if($null -ne $script:lastUi -and $script:lastUi.PSObject.Properties['stage']){$record.ui_stage=$script:lastUi.stage};};Save;Write-Host ($Name+' '+$record.status+$(if($record.ContainsKey('code')){' '+$record.code}else{''}));if($record.status -eq 'FAILED' -and $Name -notin @('normal_manager_startup_and_complete_process_group_idle_measurement','normal_manager_startup_diagnostic_only','actual_windows_display_dpi_and_bilingual_product_layouts','real_keyboard_and_windows_screen_reader_provider','official_editor_saves_boxed_document_without_host_write','official_archive_gui_and_create_extract_round_trip','browser_own_child_request_stays_boxed','browser_reachable_protocol_handler_does_not_escape','browser_own_content_sandbox_remains_enabled')){$script:failureCode=$record.code;throw 'P09_FOCUSED_CASE_FAILED'}}
function Clean([string]$Text){foreach($canary in @('P09_ARGV_SECRET_CANARY','P09_ENV_SECRET_CANARY','FORGED_EVENT')){if($Text.Contains($canary)){$script:capturesClean=$false;return $false}};return $true}
function Native-Once([hashtable]$Request,[string]$Kind='policy',[switch]$AllowFailure){
 $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=$EngineHome;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.ArgumentList.Add(('--'+$Kind+'-once'))
 $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','PATH','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['SECURERUN_P09_SECRET']='P09_ENV_SECRET_CANARY'
 $p=[Diagnostics.Process]::Start($start);$deadline=if($Kind -eq 'policy'){660000}else{180000}
 try{$output=$p.StandardOutput.ReadToEndAsync();$errors=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $Request -Depth 16 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit($deadline)) 'P09_NATIVE_REQUEST_TIMEOUT';Require ($p.ExitCode -eq 0) 'P09_NATIVE_REQUEST_EXIT_FAILED';Require (Clean $errors.Result) 'P09_SECRET_IN_LOCAL_ERROR_CAPTURE';Require ($output.Result.Length -le 2097152) 'P09_NATIVE_RESPONSE_BOUND';$r=$output.Result|ConvertFrom-Json -Depth 40;if($Kind -eq 'policy' -and $script:stage.StartsWith('SEEDING_')){$observations=@($r.environments|ForEach-Object {@{stage=$_.stage;reason=$(if($_.reason -cmatch '^[A-Z][A-Z0-9_]{2,100}$'){$_.reason}else{'WITHHELD_NOT_CODE'});revision=$_.revision;generation=$_.generation}});@{stage=$script:stage;environments=$observations}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'owned-policy-observations.json') -Encoding utf8};if($r.reason -cnotmatch '^[A-Z][A-Z0-9_]{2,100}$'){throw 'P09_NATIVE_REASON_SCHEMA_INVALID'};if($r.reason -ne 'OBSERVED'){@{kind=$Kind;request_action=$(if($Request.action -cmatch '^[A-Z][A-Z0-9_]{1,63}$'){$Request.action}else{'WITHHELD'});reason=$r.reason;stage=$script:stage}|ConvertTo-Json|Set-Content (Join-Path $results 'last-native-refusal.json') -Encoding utf8};if(-not $AllowFailure){Require ($r.reason -eq 'OBSERVED') $r.reason};return $r}finally{if(-not $p.HasExited){$p.Kill($true);$null=$p.WaitForExit(10000)};$p.Dispose()}
}
function Native([hashtable]$Request,[string]$Kind='policy',[switch]$AllowFailure){
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do{
  $reply=Native-Once $Request $Kind -AllowFailure
  # Only a readonly LIST may wait for another owner of the namespace lock.
  # Never retry mutations, uncertain dispatch or any other refusal automatically.
  if($Request.action -eq 'LIST' -and $reply.reason -eq 'NAMESPACE_OPERATION_BUSY' -and $clock.ElapsedMilliseconds -lt 4000){Start-Sleep -Milliseconds 50;continue}
  if(-not $AllowFailure){Require ($reply.reason -eq 'OBSERVED') $reply.reason};return $reply
 }while($true)
}
function Stop-Box($Environment){$null=Native @{action='STOP';environment_id=$Environment.id;operation_id=[Guid]::NewGuid().ToString()} 'control';$lab.FenceFixture(('SR_'+$Environment.id.Replace('-','')))}
function Register-App($Environment,[string]$Name,[string]$Executable,[string[]]$Arguments){
 $r=Native @{action='REGISTER';environment_id=$Environment.id;expected_revision=$Environment.revision;operation_id=[Guid]::NewGuid().ToString();display_name=$Name;executable=$Executable;arguments=@($Arguments);working_directory=$null} 'control'
 $a=@($r.applications|Where-Object {$_.environment_id -eq $Environment.id -and $_.display_name -eq $Name});Require ($a.Count -eq 1) 'P09_REGISTRATION_MISSING';return $a[0]
}
function Launch-App($Environment,$Application){$op=[Guid]::NewGuid().ToString();$r=Native @{action='LAUNCH';environment_id=$Environment.id;expected_revision=$Environment.revision;application_id=$Application.id;operation_id=$op} 'control';$receipt=@($r.receipts|Where-Object operation_id -eq $op);Require ($r.environment_scope -eq $Environment.id -and @($r.environments).Count -eq 1) 'P09_LAUNCH_RESPONSE_SCOPE_INVALID';Require ($receipt.Count -eq 1 -and $null -ne $receipt[0].process -and $receipt[0].state -ne 'REFUSED') 'P09_NATIVE_LAUNCH_NOT_OBSERVED';return $receipt[0]}
function Wait-Launched($Receipt){
 $observed=[P09Desktop]::WaitMemberExit($Receipt.process.pid,[long]$Receipt.process.creation_time,45000)
 $observed.case=$script:stage;$observed.synthetic_fixture_only=$true
 $observed|ConvertTo-Json|Set-Content (Join-Path $results 'application-exit.json') -Encoding utf8
 if($observed.exit_code_observed){Require ($observed.exit_code -eq 0) 'P09_APPLICATION_EXIT_FAILED'}
 # A process already completed/reused before a handle could be held has an
 # unknown exit code. Actual boxed output and unchanged-host checks still follow.
}
function Access([string]$Mode,[int]$ProcessId,[string]$Path='', [string]$Uri='',[switch]$Async,[int]$Scale=0,[string]$Box='',[switch]$ParentPrepared){
 $result=Join-Path $results ('access-'+$Mode.ToLowerInvariant()+'-'+[Guid]::NewGuid().ToString('N')+'.json');$ps=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$ps.UseShellExecute=$false;$ps.CreateNoWindow=$true;$ps.WorkingDirectory=$EngineHome
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $PSScriptRoot 'p09_accessibility.ps1'),'-Mode',$Mode,'-ManagerPid',[string]$ProcessId,'-ResultFile',$result)){$ps.ArgumentList.Add($arg)}
 if($Path){$ps.ArgumentList.Add($(if($Mode -eq 'CONFIRM'){'-EnvironmentId'}else{'-SelectedPath'}));$ps.ArgumentList.Add($Path)};if($Uri){$ps.ArgumentList.Add($(if($Mode -eq 'CONFIRM'){'-Intent'}else{'-ProtocolUri'}));$ps.ArgumentList.Add($Uri)}
 if($Box){$ps.ArgumentList.Add('-ExpectedBox');$ps.ArgumentList.Add($Box)}
 if($Scale){$ps.ArgumentList.Add('-Scale');$ps.ArgumentList.Add([string]$Scale)}
 $p=[Diagnostics.Process]::Start($ps);if($Async){return @{process=$p;result=$result}}
 try{Require ($p.WaitForExit($(if($Mode -eq 'DISPLAY_SCALE'){150000}else{90000}))) 'P09_ACCESSIBILITY_TIMEOUT';$r=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json;$expectedStatus=if($Mode -eq 'DESKTOP_PREPARE'){'OBSERVED'}else{'PASSED'};if($Mode -eq 'DESKTOP_PREPARE' -and -not $ParentPrepared -and $r.status -eq 'BLOCKED' -and $null -ne $r.PSObject.Properties['same_user'] -and $r.same_user -eq $false -and $r.initial_picker_window_count -ge 1){
  # Only a fixed lab action crosses the existing owner-restricted event channel.
  # The controller independently re-authenticates the Windows component as its owner.
  $request=$null;$done=$null;$failed=$null
  try{$rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify;$prefix=$env:SECURERUN_P09_DISPLAY_EVENTS;Require ($prefix -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$') 'P09_LAB_DISPLAY_CHANNEL_MISSING';$request=[Threading.EventWaitHandleAcl]::OpenExisting($prefix+'-prepare',$rights);$done=[Threading.EventWaitHandleAcl]::OpenExisting($prefix+'-done',$rights);$failed=[Threading.EventWaitHandleAcl]::OpenExisting($prefix+'-failed',$rights);$null=$request.Set();Require ([Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]@($done,$failed),90000) -eq 0) 'P09_CONTROLLER_DESKTOP_PREPARATION_FAILED'}
  finally{foreach($event in @($request,$done,$failed)){if($null -ne $event){$event.Dispose()}}}
  return Access 'DESKTOP_PREPARE' 0 -ParentPrepared
 };Require ($p.ExitCode -eq 0 -and $r.status -eq $expectedStatus) 'P09_ACCESSIBILITY_FAILED';return $r}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function Complete-Access($Pending){
 if($null -eq $Pending.process){return};$process=$Pending.process;$Pending.process=$null
 try{Require ($process.WaitForExit(90000)) 'P09_PICKER_TIMEOUT';$r=Get-Content -LiteralPath $Pending.result -Raw|ConvertFrom-Json;Require ($process.ExitCode -eq 0 -and $r.status -eq 'PASSED') 'P09_NATIVE_PICKER_FAILED';return $r}
 finally{if(-not $process.HasExited){$process.Kill($true)};$process.Dispose()}
}
function Find-BoxFile($Environment,[string]$Name){$root=$Environment.compiled.section.FileRootPath[0];$found=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $Name);Require ($found.Count -eq 1 -and $found[0].FullName.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) 'P09_BOXED_FILE_NOT_UNIQUE';return $found[0]}
function Wait-GuiPid($Environment,[string]$Executable){$clock=[Diagnostics.Stopwatch]::StartNew();do{$r=Native @{action='LIST'} 'control';$scope=@($r.environments|Where-Object environment_id -eq $Environment.id);if($scope.Count -eq 1 -and $scope[0].complete){foreach($member in $scope[0].processes){if(-not [P09Desktop]::IsExpectedMember($member.pid,[long]$member.creation_time,$Executable)){continue};try{$p=[Diagnostics.Process]::GetProcessById($member.pid);try{if($p.MainWindowHandle -ne [IntPtr]::Zero){return [int]$member.pid}}finally{$p.Dispose()}}catch [ArgumentException]{}}};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000);throw 'P09_TARGET_GUI_NOT_OBSERVED'}
$gui=$null;$hostBrowser=$null;$browserProof=$null;$held=$null;$lab=$null;$registryCreated=$false
try{
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity);Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'P09_STANDARD_USER_REQUIRED'
 $env:USERPROFILE=[Environment]::GetFolderPath('UserProfile');$env:LOCALAPPDATA=[Environment]::GetFolderPath('LocalApplicationData');$env:APPDATA=[Environment]::GetFolderPath('ApplicationData');$env:TEMP=Join-Path $Fixture 'temp';$env:TMP=$env:TEMP;$null=New-Item -ItemType Directory -Path $env:TEMP -Force
 $displayPrefix=$env:SECURERUN_P09_DISPLAY_EVENTS;Require ($displayPrefix -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$') 'P09_LAB_DISPLAY_CHANNEL_MISSING'
 $displayRights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify
 foreach($suffix in @('100','150','200','prepare','done','failed')){$event=[Threading.EventWaitHandleAcl]::OpenExisting($displayPrefix+'-'+$suffix,$displayRights);$event.Dispose()}
 @{schema=1;standard_user_event_access_verified=$true;fixed_lab_ui_actions_only=$true;event_count=6;normal_product_receives_channel=$false}|ConvertTo-Json|Set-Content (Join-Path $results 'lab-display-channel.json') -Encoding utf8
 foreach($name in @('p05_lab.cs','p09_desktop.cs','p09_browser.cs')){Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot $name)))}
 . (Join-Path $PSScriptRoot 'p09_cdp.ps1')
 $productHome=Split-Path $Manager;$lab=[P05Lab]::new($EngineHome,$Fixture,$productHome)
 $null=Access 'DESKTOP_PREPARE' 0
 $editor=Join-Path $productHome 'applications/editor/notepad++.exe';$archive=Join-Path $productHome 'applications/archive/7z.exe';$browser=Join-Path $productHome 'applications/browser/core/firefox.exe'
 $hostProfile=Join-Path $Fixture 'host-browser-profile';$boxedProfile=Join-Path $Fixture 'boxed-browser-profile';$protocolBase=Join-Path $env:LOCALAPPDATA 'SecureRunP09Protocol';foreach($path in @($hostProfile,$boxedProfile,$protocolBase)){$null=New-Item -ItemType Directory -Path $path}
 $prefs=@'
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.newtabpage.enabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("network.protocol-handler.external.securerun-p09", true);
'@
 [IO.File]::WriteAllText((Join-Path $hostProfile 'user.js'),$prefs);[IO.File]::WriteAllText((Join-Path $boxedProfile 'user.js'),$prefs)
 $all=@();$environmentCount=if($LayoutOnly){1}elseif($Focused){4}else{10};$script:stage='SEEDING_REAL_ENVIRONMENTS'
 for($i=1;$i -le $environmentCount;$i++){
  $script:stage=('SEEDING_ENVIRONMENT_{0:00}' -f $i)
  $grants=@();if($i -eq 3){$grants=@(@{path=$hostProfile;permission='BLOCK'})};$preset=if($i -eq 3){'STANDARD_ONLINE'}else{'STANDARD_OFFLINE'}
  $r=Native @{action='CREATE';display_name=('P09 reference {0:00}' -f $i);operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset=$preset;grants=$grants}}
  $e=@($r.environments|Where-Object display_name -eq ('P09 reference {0:00}' -f $i))[0];Require ($e.stage -eq 'VERIFIED') 'P09_VERIFIED_SEED_REQUIRED';$all+=,$e;$lab.Register(('SR_'+$e.id.Replace('-','')))
 }
 $script:stage='SEEDING_COMPLETE';$current=Native @{action='LIST'};$all=@($current.environments|Sort-Object display_name);$first=$all[0];$apps=$all[[Math]::Min(1,$all.Count-1)];$web=$all[[Math]::Min(2,$all.Count-1)];$seed=Join-Path $Fixture 'seed.txt';[IO.File]::WriteAllText($seed,'P09_SYNTHETIC_SEED');$null=Native @{action='IMPORT';environment_id=$first.id;expected_revision=$first.revision;operation_id=[Guid]::NewGuid().ToString();source=$seed;name='file-00000.txt'} 'files'
 $workspace=(Find-BoxFile $first 'file-00000.txt').DirectoryName
 for($i=1;$i -lt 9999;$i++){[IO.File]::WriteAllText((Join-Path $workspace ('file-{0:00000}.txt' -f $i)),'x')};[IO.File]::WriteAllText((Join-Path $workspace ("00000-report"+[char]0x202e+'fdp.exe')),'INERT_FILENAME_ONLY')
 Require (@(Get-ChildItem -LiteralPath $workspace -File).Count -eq 10000) 'P09_TEN_THOUSAND_FILE_FIXTURE_FAILED'
 [IO.File]::WriteAllText((Join-Path $Fixture 'policy-resource.txt'),'P09_POLICY_RESOURCE')
 Case 'T32' 'completed_private_diagnostics_retire_definitions_and_keep_bounded_evidence' {
  $metadata=Join-Path $env:LOCALAPPDATA 'SecureRun/metadata';$records=@(Get-ChildItem -LiteralPath $metadata -Filter 'diagnostic-*.json' -File);$retired=@(Get-ChildItem -LiteralPath $metadata -Filter 'probe-retired-*.json' -File)
  Require ($records.Count -gt $(if($Focused){0}else{64}) -and $records.Count -le 256 -and $retired.Count -eq $records.Count) 'P09_DIAGNOSTIC_RETENTION_INCOMPLETE'
  foreach($record in $retired){$proof=Get-Content -LiteralPath $record.FullName -Raw|ConvertFrom-Json;Require ($proof.completed -and $proof.definition_removed -and $proof.root_data_retained -and $proof.synthetic_report_unchanged) 'P09_DIAGNOSTIC_RETIREMENT_PROOF_INVALID'}
  foreach($record in $records){$scope=Get-Content -LiteralPath $record.FullName -Raw|ConvertFrom-Json -Depth 20;Require ($null -eq $lab.Read(('SR_'+$scope.id.Replace('-','')),'Enabled',0x70000000)) 'P09_COMPLETED_DIAGNOSTIC_DEFINITION_REMAINS';Require (Test-Path -LiteralPath $scope.compiled.section.FileRootPath[0] -PathType Container) 'P09_DIAGNOSTIC_DATA_REMOVED'}
  @{retained_diagnostics=$records.Count;retention_limit=256;completed_definition_count=0;all_successful_definitions_retired=$true;root_data_retained=$true;synthetic_reports_unchanged=$true;no_recursive_data_deletion=$true}
 }
 if(-not $Focused){
 Case 'T32' 'ten_real_idle_environments_and_populated_box' { $r=Native @{action='LIST'} 'control';Require (@($r.environments|Where-Object {$_.activity -ne 'IDLE' -or -not $_.complete}).Count -eq 0) 'P09_IDLE_SEED_SCOPE_INCOMPLETE';@{actual_environments=$all.Count;actual_files=10000;all_idle=(@($r.environments|Where-Object {$_.activity -ne 'IDLE' -or -not $_.complete}).Count -eq 0);synthetic_only=$true} }
 }
 # Prewarm the UIA provider before timing the normal manager, without an inspector.
 $null=Access 'DESKTOP_PREPARE' 0
 if(-not $AppsOnly){
 $startupCase=if($Focused){'normal_manager_startup_diagnostic_only'}else{'normal_manager_startup_and_complete_process_group_idle_measurement'}
 function Startup-Trace {
  $trace=[IO.FileStream]::new((Join-Path $Fixture 'normal-manager.log'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try{$buffer=[byte[]]::new(8192);$length=$trace.Read($buffer,0,$buffer.Length);$text=[Text.Encoding]::UTF8.GetString($buffer,0,$length)}finally{$trace.Dispose()}
  $value=@{webview_memory_target_low=$text.Contains('WEBVIEW_MEMORY_TARGET_LOW')}
  foreach($name in @('OBSERVATION','BEFORE_WEBVIEW','WINDOW_CREATED')){if($text -match ('(?m)^MANAGER_STARTUP_'+$name+'_MS=([0-9]{1,8})\r?$')){$value['native_'+$name.ToLower()+'_ms']=[long]$Matches[1]}}
  $streams=[regex]::Matches($text,'(?m)^PASSIVE_OBSERVER_FRAMES=([0-9]{1,2});CPU100NS=([0-9]{1,16})\r?$');$frames=0;$ticks=0L
  foreach($stream in $streams){$frames+=[int]$stream.Groups[1].Value;$ticks+=[long]$stream.Groups[2].Value}
  $value.completed_observer_streams=$streams.Count;$value.completed_observer_frames=$frames;$value.completed_observer_cpu_seconds=$ticks/10000000.0;$value.observer_cpu_attribution_complete=$false
  return $value
 }
 Case 'T32' $startupCase {
  $coord=Join-Path $Fixture 'startup-coordinate.json';$accessResult=Join-Path $results 'startup-accessibility.json';$ps=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$ps.UseShellExecute=$false;$ps.CreateNoWindow=$true
  foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $PSScriptRoot 'p09_accessibility.ps1'),'-Mode','READY','-Coordination',$coord,'-ResultFile',$accessResult)){$ps.ArgumentList.Add($arg)}
  $watcher=[Diagnostics.Process]::Start($ps)
  try{$clock=[Diagnostics.Stopwatch]::StartNew();while(-not(Test-Path ($coord+'.ready')) -and -not $watcher.HasExited -and $clock.ElapsedMilliseconds -lt 60000){Start-Sleep -Milliseconds 100};Require (Test-Path ($coord+'.ready')) 'P09_ACCESSIBILITY_WATCHER_NOT_READY'
   $gui=[P09Desktop]::new($Manager,$EngineHome,(Join-Path $Fixture 'normal-manager.log'),0);$body=@{pid=$gui.ProcessId;ticks=$gui.StartedTicks}|ConvertTo-Json -Compress;[IO.File]::WriteAllText($coord+'.tmp',$body);[IO.File]::Move($coord+'.tmp',$coord)
   Require ($watcher.WaitForExit(60000)) 'P09_STARTUP_INTERACTIVE_TIMEOUT';$access=Get-Content -LiteralPath $accessResult -Raw|ConvertFrom-Json;Require ($watcher.ExitCode -eq 0 -and $access.status -eq 'PASSED') 'P09_STARTUP_ACCESSIBILITY_FAILED'
   if($Focused){
    $diagnostic=@{startup_interactive_upper_bound_ms=$access.startup_interactive_upper_bound_ms;native_window_present_ms=$access.native_window_present_ms;environment_count=$environmentCount;inspector_enabled=$false;performance_exit_gate_claimed=$false;native_startup=(Startup-Trace)}
    if(-not $LayoutOnly){
     $idle=Native @{action='LIST'} 'control';Require (@($idle.environments|Where-Object {$_.activity -ne 'IDLE' -or -not $_.complete}).Count -eq 0) 'P09_DIAGNOSTIC_IDLE_SCOPE_INCOMPLETE'
     Start-Sleep -Seconds 5;$measurement=$gui.MeasureIdle();$measurement.reference_environments=$environmentCount;$measurement.product_performance_gate_claimed=$false;$measurement.native_startup=Startup-Trace
     $measurement|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'performance-diagnostic.json') -Encoding utf8;$diagnostic.native_startup=$measurement.native_startup
    }
    $diagnostic|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'startup-diagnostic.json') -Encoding utf8;return $diagnostic
   }
   Start-Sleep -Seconds 5;$metrics=$gui.MeasureIdle();$metrics.startup_interactive_upper_bound_ms=$access.startup_interactive_upper_bound_ms;$metrics.idle_environments=10;$metrics.populated_box_files=10000;$metrics.inspector_enabled=$false;$metrics.reference='GitHub hosted owner-selected runner; normal release binary'
   $metrics.native_startup=Startup-Trace;$metrics.webview_memory_target_low=$metrics.native_startup.webview_memory_target_low
   $metrics.startup_target_met=($access.startup_interactive_upper_bound_ms -le 3000);$metrics.idle_cpu_target_met=($metrics.cpu_percent -lt 1);$metrics.idle_working_set_target_met=($metrics.average_working_set_bytes -lt 250000000)
   Require ($metrics.webview_processes -ge 2 -and $metrics.duration_ms -ge 60000 -and $metrics.samples -ge 200) 'P09_PROCESS_GROUP_MEASUREMENT_INCOMPLETE'
   $metrics|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'performance.json') -Encoding utf8
   $metrics
  }finally{try{Startup-Trace|ConvertTo-Json -Depth 5|Set-Content (Join-Path $results 'startup-native-trace.json') -Encoding utf8}catch{};if($null -ne $gui){$gui.Dispose();$gui=$null};if(-not $watcher.HasExited){$watcher.Kill($true)};$watcher.Dispose()}
 }
 # Re-observe after the measured manager has closed, before the inspected GUI.
 $null=Access 'DESKTOP_PREPARE' 0
 # Normal product, real backend and real WebView. Inspector access exists only in this lab launch environment.
 $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start();$port=([Net.IPEndPoint]$listener.LocalEndpoint).Port;$listener.Stop()
 $gui=[P09Desktop]::new($Manager,$EngineHome,(Join-Path $Fixture 'inspected-manager.log'),$port);Connect-P09Cdp $port;Wait-P09Document;$null=Evaluate-P09 ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p09_ui.js')))
 Case 'T32' 'actual_normal_webview_environment_navigation' {$null=Invoke-P09Stage 'OVERVIEW' @{environment_count=$environmentCount;search_name=$all[-1].display_name};@{normal_production_binary=$true;real_backend=$true;mock_state=$false;ten_owned_environments=($environmentCount -eq 10)}}
 Case 'T32' 'metadata_rename_preserves_identity_and_never_replays' {$null=Invoke-P09Stage 'RENAME' @{environment_id=$first.id;environment_name=$first.display_name};@{actual_product_ui=$true;metadata_only=$true;permanent_replay_tombstone=$true;policy_and_generation_unchanged=$true}}
 Case 'T32' 'real_keyboard_and_windows_screen_reader_provider' {$r=Access 'KEYBOARD' $gui.ProcessId;@{real_windows_uia=$r.real_windows_uia;native_window_dpi=$r.native_window_dpi;tab_order_actual=$r.tab_order_actual;f6_navigation_actual=$r.f6_navigation_actual;accessible_labels_and_roles=$r.accessible_label_and_role;native_invoke_changed_page=$r.native_invoke_changed_real_page}}
 Case 'T32' 'english_russian_themes_and_native_webview_scaling' {
  foreach($language in @('en','ru')){foreach($theme in @('light','dark')){foreach($scale in @(100,150,200)){
   $null=Invoke-P09Stage 'LAYOUT' @{language=$language;theme=$theme;scale=$scale}
   if(($language -eq 'en' -and $theme -eq 'light' -and $scale -eq 100) -or ($language -eq 'ru' -and $theme -eq 'dark')){$shot=Send-P09Cdp 'Page.captureScreenshot' @{format='png';captureBeyondViewport=$false};[IO.File]::WriteAllBytes((Join-Path $results ("ui-$language-$theme-$scale.png")),[Convert]::FromBase64String($shot.data))}
  }}}
  $null=Invoke-P09Stage 'RESET_PRESENTATION';$ax=Send-P09Cdp 'Accessibility.getFullAXTree';$names=@($ax.nodes|Where-Object {$_.role.value -eq 'combobox' -and $_.name.value -in @('Language','Appearance','Content scale')});Require ($names.Count -eq 3) 'P09_ACCESSIBILITY_TREE_LABELS_MISSING'
  @{languages=@('en','ru');themes=@('light','dark');content_scales=@(100,150,200);actual_native_webview_zoom=$true;real_chromium_accessibility_tree=$true;labeled_comboboxes=$names.Count;os_display_setting_modified=$false}
 }
 Case 'T32' 'actual_windows_display_dpi_and_bilingual_product_layouts' {
  $observed=@()
  try{foreach($percent in @(100,150,200)){
   $r=Access 'DISPLAY_SCALE' $gui.ProcessId -Scale $percent;$observed+=@{percent=$percent;native_window_dpi=$r.native_window_dpi}
   foreach($language in @('en','ru')){foreach($theme in @('light','dark')){$null=Invoke-P09Stage 'WINDOWS_LAYOUT' @{language=$language;theme=$theme;scale=100;windows_scale=$percent}}}
   $shot=Send-P09Cdp 'Page.captureScreenshot' @{format='png';captureBeyondViewport=$false};[IO.File]::WriteAllBytes((Join-Path $results ("windows-dpi-$percent.png")),[Convert]::FromBase64String($shot.data))
  };@{actual_windows_display_changes=$true;production_manager_window_measured=$true;native_dpi_observations=$observed;content_scale_percent=100;os_security_settings_modified=$false}}
  finally{try{$null=Access 'DISPLAY_SCALE' $gui.ProcessId -Scale 100}finally{$null=Invoke-P09Stage 'RESET_PRESENTATION'}}
 }
 if($LayoutOnly){
  $failed=@($cases|Where-Object status -ne 'PASSED').Count;$uiFailed=@($script:uiCases|Where-Object {-not $_.passed}).Count
  @{status=$(if($failed -eq 0 -and $uiFailed -eq 0){'DIAGNOSTIC_ONLY'}else{'FAILED'});workload_mode='DIAGNOSTIC_ONLY';layout_only=$true;reference_environments=1;standard_user=$true;manager_commit=$Commit;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;failed=$failed;ui_cases_passed=@($script:uiCases|Where-Object passed).Count;ui_failed=$uiFailed;normal_production_binary=$true;os_security_settings_modified=$false;browser_sandbox_disabled=$false;synthetic_profiles_only=$true}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'standard-product.json') -Encoding utf8
  Save;if($failed -ne 0 -or $uiFailed -ne 0){exit 1};exit 0
 }
 try{
 Case 'T32' 'real_process_activity_update_latency' {
  $null=Invoke-P09Stage 'ACTIVITY_BEGIN' @{environment_name=$first.display_name;environment_count=$environmentCount};$lab.Register(('SR_'+$first.id.Replace('-','')));$script:held=$lab.HoldProductionProbe(('SR_'+$first.id.Replace('-','')))
  Require ($lab.HeldMemberAlive($held,('SR_'+$first.id.Replace('-','')))) 'P09_ACTIVITY_MEMBER_NOT_ALIVE';$r=Invoke-P09Stage 'ACTIVITY_END' @{environment_name=$first.display_name};$r.metrics|ConvertTo-Json|Set-Content (Join-Path $results 'process-update.json') -Encoding utf8;Require ($r.metrics.update_upper_bound_ms -gt 0) 'P09_PROCESS_UPDATE_MEASUREMENT_MISSING';$lab.FenceNewFixtureDispatch(('SR_'+$first.id.Replace('-','')));Require ($lab.HeldMemberAlive($held,('SR_'+$first.id.Replace('-','')))) 'P09_EXTERNAL_MEMBER_STOPPED_BY_FENCE';$r.metrics
 }

 Case 'T32' 'running_policy_diff_queue_requires_explicit_stopped_apply' {
  # End the activity GUI before independent CLI preparation. Its periodic
  # readonly worker legitimately holds the same namespace lock; a concurrent
  # second client is not an ordinary UI action.
  Close-P09Cdp;$gui.Dispose();$script:gui=$null
  # The external SDK activity fixture can be observed while Enabled=y. LIST
  # durably records that conflict; returning the flag never silently heals it.
  if($null -ne $held){[P05Lab]::Stop($held);$script:held=$null};Stop-Box $first
  $current=(Native @{action='LIST'}).environments|Where-Object id -eq $first.id;$repaired=$false
  if($current.stage -ne 'VERIFIED'){
   $inspected=(Native @{action='INSPECT';environment_id=$current.id}).environments|Where-Object id -eq $current.id
   Require ($inspected.reason -cmatch '^INSPECTED_BASELINE:([0-9a-f]{64})$') 'P09_EXTERNAL_CONFLICT_NOT_INSPECTED';$observed=$Matches[1]
   $repair=Native @{action='REPAIR';environment_id=$current.id;expected_revision=$current.revision;observed_fingerprint=$observed;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true}
   $current=$repair.environments|Where-Object id -eq $current.id;$repaired=$true
  }
  Require ($current.stage -eq 'VERIFIED') 'P09_EXTERNAL_FIXTURE_POLICY_NOT_VERIFIED';$script:first=$current
  $application=Register-App $first 'P09 managed running-policy target' (Join-Path $productHome 'securerun-launch-probe.exe') @('hold',(Join-Path $Fixture 'queued-policy-held.jsonl'))
  $receipt=Launch-App $first $application
  $memberAlive={
   $scopes=(Native @{action='LIST'} 'control').environments|Where-Object environment_id -eq $first.id
   return @($scopes.processes|Where-Object {$_.pid -eq $receipt.process.pid -and [string]$_.creation_time -eq [string]$receipt.process.creation_time}).Count -eq 1
  }
  Require (& $memberAlive) 'P09_MANAGED_QUEUE_MEMBER_NOT_RUNNING'
  # Reopen the same actual product/profile after independent preparation.
  # Required picker/diff/queue/Stop/Apply actions still use its real UI/backend.
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start();$port=([Net.IPEndPoint]$listener.LocalEndpoint).Port;$listener.Stop()
  $script:gui=[P09Desktop]::new($Manager,$EngineHome,(Join-Path $Fixture 'policy-manager.log'),$port);Connect-P09Cdp $port;Wait-P09Document;$null=Evaluate-P09 ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p09_ui.js')))
  $queueFlowVerified=$false;$pending=Access 'PICKER' $gui.ProcessId (Join-Path $Fixture 'policy-resource.txt') -Async
  try{$null=Invoke-P09Stage 'PERMISSION_PICK' @{environment_name=$first.display_name;environment_id=$first.id};$picker=Complete-Access $pending;$pending=$null;$null=Invoke-P09Stage 'PERMISSION_QUEUE' @{environment_id=$first.id};Require (& $memberAlive) 'P09_QUEUE_STOPPED_PROCESS';$null=Invoke-P09Stage 'STOP_AND_APPLY' @{environment_id=$first.id;environment_name=$first.display_name};$queueFlowVerified=$true;@{real_native_picker=$picker.picker.real_native_picker;queued_in_backend=$true;applied_while_running=$false;explicit_whole_box_stop=$true;independent_policy_readback=$true;managed_launch_receipt_verified=$true;external_fixture_conflict_explicitly_repaired=$repaired}}
  finally{if($null -ne $pending){$null=Complete-Access $pending};if(-not $queueFlowVerified){Stop-Box $first}}
 }
 Case 'T63' 'ten_thousand_files_bounded_ui_and_complete_pagination' {$r=Invoke-P09Stage 'FILE_LIST' @{environment_id=$first.id};$r.metrics|ConvertTo-Json|Set-Content (Join-Path $results 'file-workload.json') -Encoding utf8;$r.metrics}
 Case 'T66' 'synthetic_argv_and_environment_do_not_enter_manager_logs' {
  $pending=Access 'PICKER' $gui.ProcessId (Join-Path $productHome 'p09-protocol-probe.exe') -Async
  try{$null=Invoke-P09Stage 'SECRET_PICK';$null=Complete-Access $pending;$pending=$null;$registered=Invoke-P09Stage 'SECRET_REGISTER';Require ($registered.secret_receipt.environment_id -eq $first.id -and $null -ne $registered.secret_receipt.process) 'P09_SECRET_RECEIPT_SCOPE_INVALID';$exitProof=[P09Desktop]::WaitMemberExit($registered.secret_receipt.process.pid,[long]$registered.secret_receipt.process.creation_time,15000);$exitProof|ConvertTo-Json|Set-Content (Join-Path $results 'secret-process-exit.json') -Encoding utf8;$clock=[Diagnostics.Stopwatch]::StartNew();$markers=@()
   do{$markers=@(Get-ChildItem -LiteralPath $first.compiled.section.FileRootPath[0] -Recurse -File -Filter 'secret-result.json');if($markers.Count -gt 0){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
   @{output_count=$markers.Count;wait_ms=$clock.ElapsedMilliseconds;new_exact_scope_dispatch_observed=$true;host_marker_present=(Test-Path -LiteralPath (Join-Path $protocolBase 'secret-result.json'))}|ConvertTo-Json|Set-Content (Join-Path $results 'secret-marker-observation.json') -Encoding utf8
   Require (-not(Test-Path -LiteralPath (Join-Path $protocolBase 'secret-result.json'))) 'P09_SECRET_MARKER_REACHED_HOST';$marker=Find-BoxFile $first 'secret-result.json';$proof=Get-Content -LiteralPath $marker.FullName -Raw|ConvertFrom-Json;Require ($proof.boxed -and $proof.argv_secret_received -and $proof.inherited_environment_secret_absent) 'P09_SECRET_TARGET_PROOF_MISSING';@{real_boxed_target_executed=$true;synthetic_argv_received=$true;inherited_environment_secret_absent=$true;raw_target_errors_not_manager_events=$true}}
  finally{if($null -ne $pending){$null=Complete-Access $pending}}
 }
 Case 'T66' 'native_diagnostic_save_matches_reviewed_minimized_bytes' {
  $destination=Join-Path $Fixture 'reviewed-diagnostics.json';$pending=Access 'PICKER' $gui.ProcessId $destination -Async
  try{$null=Invoke-P09Stage 'DIAGNOSTIC_PREVIEW';$picker=Complete-Access $pending;$pending=$null;$r=Invoke-P09Stage 'DIAGNOSTIC_SAVED';Require (([IO.File]::ReadAllText($destination)) -ceq $r.reviewed_bundle) 'P09_DIAGNOSTIC_REVIEW_BYTES_CHANGED';Require (Clean ([IO.File]::ReadAllText($destination))) 'P09_SECRET_IN_SHARED_BUNDLE';Copy-Item -LiteralPath $destination -Destination (Join-Path $results 'reviewed-diagnostic-example.json');@{real_native_picker=$picker.picker.real_native_picker;explicit_review_before_save=$true;reviewed_bytes_equal_saved=$true;automatic_upload=$false;automatic_open=$false;secret_canaries_absent=$true}}
  finally{if($null -ne $pending){$null=Complete-Access $pending}}
 }
 Case 'T32' 'actual_ui_import_export_collision_archive_and_reset_workflow' {
  $workflow=(Native @{action='LIST'}).environments|Where-Object display_name -eq ('P09 reference {0:00}' -f $environmentCount);Require ($null -ne $workflow) 'P09_WORKFLOW_ENVIRONMENT_MISSING'
  $inputFile=Join-Path $Fixture 'workflow-source.txt';[IO.File]::WriteAllText($inputFile,'P09_UI_TRANSFER_CANARY');$hash=(Get-FileHash -LiteralPath $inputFile).Hash;$destination=Join-Path $Fixture 'workflow-export';$null=New-Item -ItemType Directory -Path $destination
  $pending=Access 'PICKER' $gui.ProcessId $inputFile -Async
  try{$null=Invoke-P09Stage 'TRANSFER_IMPORT_PICK' @{environment_id=$workflow.id;environment_name=$workflow.display_name};$null=Complete-Access $pending;$pending=$null}finally{if($null -ne $pending){$null=Complete-Access $pending}}
  $pending=Access 'PICKER' $gui.ProcessId $destination -Async
  try{$null=Invoke-P09Stage 'TRANSFER_EXPORT_PICK' @{environment_id=$workflow.id};$null=Complete-Access $pending;$pending=$null}finally{if($null -ne $pending){$null=Complete-Access $pending}}
  $exported=Join-Path $destination 'workflow-source.txt';$clock=[Diagnostics.Stopwatch]::StartNew();while(-not(Test-Path -LiteralPath $exported) -and $clock.ElapsedMilliseconds -lt 30000){Start-Sleep -Milliseconds 100};Require ((Get-FileHash -LiteralPath $exported).Hash -eq $hash) 'P09_UI_EXPORT_BYTES_DIFFER'
  $pending=Access 'PICKER' $gui.ProcessId $destination -Async
  try{$null=Invoke-P09Stage 'TRANSFER_COLLISION_PICK';$null=Complete-Access $pending;$pending=$null}finally{if($null -ne $pending){$null=Complete-Access $pending}}
  $pending=Access 'PICKER' $gui.ProcessId $destination -Async
  try{$null=Invoke-P09Stage 'TRANSFER_RENAME_PICK';$null=Complete-Access $pending;$pending=$null}finally{if($null -ne $pending){$null=Complete-Access $pending}}
  $renamed=Join-Path $destination 'workflow-renamed.txt';$clock.Restart();while(-not(Test-Path -LiteralPath $renamed) -and $clock.ElapsedMilliseconds -lt 30000){Start-Sleep -Milliseconds 100};Require ((Get-FileHash -LiteralPath $renamed).Hash -eq $hash -and (Get-FileHash -LiteralPath $exported).Hash -eq $hash) 'P09_UI_COLLISION_OVERWROTE_OUTPUT'
  foreach($intent in @('ARCHIVE','UNARCHIVE','RESET')){
   $pending=Access 'CONFIRM' $gui.ProcessId $workflow.id $intent -Async
   try{$null=Invoke-P09Stage 'LIFECYCLE_PICK' @{intent=$intent};$confirmation=Complete-Access $pending;$pending=$null;Require $confirmation.exact_environment_and_retention_verified 'P09_UI_CONFIRMATION_SCOPE_UNVERIFIED';$null=Invoke-P09Stage 'LIFECYCLE_CHECK' @{intent=$intent;environment_id=$workflow.id;generation=$workflow.generation}}finally{if($null -ne $pending){$null=Complete-Access $pending}}
   if($intent -eq 'ARCHIVE'){$null=Find-BoxFile $workflow 'workflow-source.txt'}
  }
  $current=(Native @{action='LIST'}).environments|Where-Object id -eq $workflow.id;Require ($current.generation -eq ($workflow.generation+1) -and @(Get-ChildItem -LiteralPath $current.compiled.section.FileRootPath[0] -Force).Count -eq 0) 'P09_UI_RESET_CONTENTS_REMAIN'
  Require ((Get-FileHash -LiteralPath $inputFile).Hash -eq $hash -and (Get-FileHash -LiteralPath $exported).Hash -eq $hash -and (Get-FileHash -LiteralPath $renamed).Hash -eq $hash) 'P09_UI_WORKFLOW_CHANGED_HOST_DATA'
  @{actual_product_ui=$true;real_native_pickers=$true;import_export_sha256_equal=$true;collision_rename_preserved_original=$true;archive_preserved_data=$true;native_confirmations_scoped=$true;reset_generation_incremented=$true;reset_root_empty=$true;host_input_and_exports_unchanged=$true;automatic_open=$false}
 }
 }catch{
  try{$diagnostic=Evaluate-P09 "({selection_error:Array.from(document.querySelectorAll('.error details code')).map(e=>e.textContent).filter(v=>/^[A-Z][A-Z0-9_]{1,100}$/.test(v)).slice(0,8),application_form_present:!!document.querySelector('#environment-panel form'),file_dialog_expected:true,application_choose_enabled:Array.from(document.querySelectorAll('#environment-panel form button')).some(e=>e.textContent==='Choose EXE'&&!e.disabled),application_environment_option_loaded:!!document.querySelector('#environment-panel form select')?.selectedOptions[0]?.value})";$diagnostic|ConvertTo-Json -Depth 5|Set-Content (Join-Path $results 'picker-command-observation.json') -Encoding utf8}catch{}
  @{status='FAILED';dependent_gui_sequence_completed=$false;code=$(if($script:failureCode){$script:failureCode}else{'P09_GUI_DEPENDENCY_FAILED'});independent_application_cases_continue=$true}|ConvertTo-Json|Set-Content (Join-Path $results 'gui-workflow.json') -Encoding utf8
 }finally{
  try{$null=Invoke-P09Stage 'RESET_PRESENTATION'}catch{}
  Close-P09Cdp;if($null -ne $gui){$gui.Dispose();$gui=$null};if($null -ne $held){[P05Lab]::Stop($held);$script:held=$null}
 }

 Case 'T66' 'local_history_and_debug_error_capture_remain_minimized' {
  $paths=@((Join-Path $Fixture 'normal-manager.log'),(Join-Path $Fixture 'inspected-manager.log'));$metadata=Join-Path $env:LOCALAPPDATA 'SecureRun/metadata';Require (Test-Path -LiteralPath (Join-Path $metadata 'history.sqlite') -PathType Leaf) 'P09_PERSISTENT_HISTORY_MISSING';foreach($name in @('history.sqlite','history.sqlite-wal','history.sqlite-shm')){if(Test-Path -LiteralPath (Join-Path $metadata $name)){$paths+=Join-Path $metadata $name}}
  $policyCapture=Join-Path $Fixture 'policy-manager.log';if(Test-Path -LiteralPath $policyCapture -PathType Leaf){$paths+=,$policyCapture}
  foreach($path in $paths){$bytes=[IO.File]::ReadAllBytes($path);Require (Clean ([Text.Encoding]::UTF8.GetString($bytes))) 'P09_SECRET_IN_LOCAL_HISTORY';Require (Clean ([Text.Encoding]::Unicode.GetString($bytes))) 'P09_SECRET_IN_LOCAL_UTF16_CAPTURE'}
  Require $script:capturesClean 'P09_SECRET_IN_NATIVE_CAPTURE';@{persistent_history_present=$true;local_history_and_wal_scanned=$true;normal_manager_stderr_scanned=$true;inspected_manager_stderr_scanned=$true;native_worker_error_capture_scanned=$true;utf8_and_utf16_scanned=$true;argv_environment_error_canaries_absent=$true;untrusted_text_cannot_add_event_fields=$true}
 }
 }
 Case 'T30' 'official_editor_saves_boxed_document_without_host_write' {
  $inputFile=Join-Path $Fixture 'editor-input.txt';$outputFile=Join-Path $Fixture 'editor-output.txt';[IO.File]::WriteAllText($inputFile,'P09_EDITOR_INPUT');$before=(Get-FileHash -LiteralPath $inputFile).Hash
  $application=Register-App $apps 'P09 official editor' $editor @('-multiInst','-nosession','-noPlugin',$inputFile);$receipt=Launch-App $apps $application;$pidValue=Wait-GuiPid $apps $editor
  $access=Access 'EDITOR' $pidValue $outputFile -Box ('SR_'+$apps.id.Replace('-',''))
  $saveClock=[Diagnostics.Stopwatch]::StartNew();$savedCandidates=@()
  do{$savedCandidates=@(Get-ChildItem -LiteralPath $apps.compiled.section.FileRootPath[0] -Recurse -File -Filter 'editor-output.txt');if($savedCandidates.Count -gt 0){break};Start-Sleep -Milliseconds 100}while($saveClock.ElapsedMilliseconds -lt 30000)
  @{output_count=$savedCandidates.Count;wait_ms=$saveClock.ElapsedMilliseconds;host_output_present=(Test-Path -LiteralPath $outputFile);real_native_picker_completed=($access.status -eq 'PASSED')}|ConvertTo-Json|Set-Content (Join-Path $results 'editor-save-observation.json') -Encoding utf8
  Require ($savedCandidates.Count -eq 1) 'P09_EDITOR_SAVE_NOT_OBSERVED';Stop-Box $apps;$null=Native @{action='RECONCILE';operation_id=$receipt.operation_id} 'control'
  $saved=Find-BoxFile $apps 'editor-output.txt';Require (([IO.File]::ReadAllText($saved.FullName)).Trim() -ceq 'P09_EDITOR_CANARY') 'P09_EDITOR_BYTES_DIFFER';Require (-not(Test-Path -LiteralPath $outputFile) -and (Get-FileHash -LiteralPath $inputFile).Hash -eq $before) 'P09_EDITOR_CHANGED_HOST'
  @{official_executable=$true;real_gui_editor=$true;actual_keyboard_edit_and_save=$access.real_keyboard_edit;original_driver_member_observed=$true;boxed_saved_bytes_verified=$true;host_input_unchanged=$true;host_output_absent=$true;clean_portable_profile=$true;plugins_and_host_update_integrations_outside_validated_workflow=$true}
 }
 Stop-Box $apps
 Case 'T30' 'official_archive_gui_and_create_extract_round_trip' {
  $guiApp=Register-App $apps 'P09 archive file manager' (Join-Path (Split-Path $archive) '7zFM.exe') @($Fixture);$guiReceipt=Launch-App $apps $guiApp;$null=Wait-GuiPid $apps (Join-Path (Split-Path $archive) '7zFM.exe');Stop-Box $apps;$null=Native @{action='RECONCILE';operation_id=$guiReceipt.operation_id} 'control'
  $inputFile=Join-Path $Fixture 'archive-source.txt';$zip=Join-Path $Fixture 'created-archive.zip';$unpack=Join-Path $Fixture 'archive-unpacked';[IO.File]::WriteAllText($inputFile,'P09_ARCHIVE_ROUND_TRIP');$hash=(Get-FileHash -LiteralPath $inputFile).Hash
  $archiveGui=Join-Path (Split-Path $archive) '7zG.exe';Require (Test-Path -LiteralPath $archiveGui -PathType Leaf) 'P09_OFFICIAL_ARCHIVE_GUI_MISSING'
  $create=Register-App $apps 'P09 archive create' $archiveGui @('a','-tzip',$zip,$inputFile,'-y');$receipt=Launch-App $apps $create
  Wait-Launched $receipt;Stop-Box $apps;$null=Native @{action='RECONCILE';operation_id=$receipt.operation_id} 'control';$created=Find-BoxFile $apps 'created-archive.zip';Require ($created.Length -gt 0 -and -not(Test-Path -LiteralPath $zip)) 'P09_ARCHIVE_NOT_BOXED'
  $extract=Register-App $apps 'P09 archive extract' $archiveGui @('x',$zip,('-o'+$unpack),'-y');$receipt=Launch-App $apps $extract
  Wait-Launched $receipt;Stop-Box $apps;$null=Native @{action='RECONCILE';operation_id=$receipt.operation_id} 'control';$output=Find-BoxFile $apps 'archive-source.txt'
  Require ((Get-FileHash -LiteralPath $output.FullName).Hash -eq $hash -and -not(Test-Path -LiteralPath $unpack) -and (Get-FileHash -LiteralPath $inputFile).Hash -eq $hash) 'P09_ARCHIVE_ROUND_TRIP_DIFFER'
  @{official_gui_observed_boxed=$true;gui_operation_executable_sha256=(Get-FileHash -LiteralPath $archiveGui).Hash.ToLowerInvariant();actual_gui_create_and_extract=$true;actual_archive_created=$true;actual_archive_extracted=$true;round_trip_sha256_matches=$true;host_input_unchanged=$true;host_zip_and_extraction_absent=$true;engine_hooks_or_security_exceptions_added=$false}
 }
 Stop-Box $apps
 Case 'T41' 'official_browser_existing_host_instance_no_url_or_cookie_handoff' {
  $nonce=[Guid]::NewGuid().ToString();$script:browserProof=[P09Browser]::new($EngineHome,('SR_'+$web.id.Replace('-','')),$nonce)
  $script:hostBrowser=[P09Desktop]::new($browser,$EngineHome,(Join-Path $Fixture 'host-browser.log'),0,[string[]]@('-no-remote','-profile',$hostProfile,('http://127.0.0.1:'+$browserProof.Port+'/host/'+$nonce)))
  $clock=[Diagnostics.Stopwatch]::StartNew();do{$records=@($browserProof.Snapshot());$hostRequests=@($records|Where-Object {$_.request_kind -eq 'HOST_POSITIVE_CONTROL'});if($hostRequests.Count -gt 0){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
  Require ($hostRequests.Count -gt 0 -and @($hostRequests|Where-Object {-not $_.source_scope_verified -or -not $_.source_unboxed}).Count -eq 0) 'P09_HOST_BROWSER_POSITIVE_CONTROL_MISSING'
  $application=Register-App $web 'P09 official browser isolated profile' $browser @('-no-remote','-profile',$boxedProfile,('http://127.0.0.1:'+$browserProof.Port+'/main/'+$nonce));$script:browserReceipt=Launch-App $web $application;$script:browserGuiPid=Wait-GuiPid $web $browser
  $clock=[Diagnostics.Stopwatch]::StartNew();do{$records=@($browserProof.Snapshot());$main=@($records|Where-Object {$_.request_kind -eq 'BOXED_MAIN'});if($main.Count -gt 0){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
  Require ($main.Count -gt 0 -and @($main|Where-Object {-not $_.source_scope_verified -or -not $_.source_boxed -or $_.host_profile_cookie_present}).Count -eq 0) 'P09_BROWSER_HANDOFF_OR_MEMBERSHIP_UNVERIFIED'
  try{$null=Access 'BROWSER_DIAGNOSTIC' $script:browserGuiPid}catch{}
  @{preexisting_host_browser_verified=$true;separate_clean_profiles=$true;explicit_profile_and_no_remote=$true;actual_http_requests=$main;socket_owner_and_held_birth_verified=$true;host_profile_cookie_absent_in_boxed_request=$true;host_profile_read_blocked_by_reviewed_rule=$true;unboxed_handoff=$false;browser_sandbox_disabled=$false}
 }
 Case 'T41' 'browser_own_child_request_stays_boxed' {
  Require ($null -ne $browserProof -and $script:browserGuiPid -gt 0) 'P09_BROWSER_PREREQUISITE_MISSING';$before=@($browserProof.Snapshot()|Where-Object request_kind -eq 'BOXED_CHILD').Count;$access=Access 'BROWSER_CHILD' $script:browserGuiPid '' $browserProof.MainUri
  $clock=[Diagnostics.Stopwatch]::StartNew();do{$records=@($browserProof.Snapshot());$child=@($records|Where-Object {$_.request_kind -eq 'BOXED_CHILD'}|Select-Object -Skip $before);if($child.Count -gt 0){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
  Require ($child.Count -gt 0 -and @($child|Where-Object {-not $_.source_scope_verified -or -not $_.source_boxed}).Count -eq 0) 'P09_BROWSER_CHILD_NOT_BOXED'
  @{actual_browser_child_action=$access.actual_browser_child_action;actual_http_requests=$child;process_tree_alone_used_as_proof=$false;host_url_handoff=$false}
 }
 Case 'T41' 'browser_reachable_protocol_handler_does_not_escape' {
  Require ($null -ne $browserProof) 'P09_BROWSER_PREREQUISITE_MISSING';$registry='HKCU:\Software\Classes\securerun-p09';Require (-not(Test-Path -LiteralPath $registry)) 'P09_PREEXISTING_PROTOCOL_NOT_CHANGED'
  $null=New-Item -Path $registry;$script:registryCreated=$true;Set-Item -LiteralPath $registry -Value 'URL:SecureRun P09 synthetic protocol';$null=New-ItemProperty -LiteralPath $registry -Name 'URL Protocol' -Value '' -PropertyType String;$null=New-Item -Path ($registry+'\shell\open\command') -Force;Set-Item -LiteralPath ($registry+'\shell\open\command') -Value ('"'+(Join-Path $productHome 'p09-protocol-probe.exe')+'" "%1"')
  $positive=[Guid]::NewGuid().ToString();$ps=[Diagnostics.ProcessStartInfo]::new(('securerun-p09:'+$positive));$ps.UseShellExecute=$true;$control=[Diagnostics.Process]::Start($ps);if($null -ne $control){$null=$control.WaitForExit(10000);$control.Dispose()}
  $clock=[Diagnostics.Stopwatch]::StartNew();$positivePath=Join-Path $protocolBase ($positive+'.json');while(-not(Test-Path -LiteralPath $positivePath) -and $clock.ElapsedMilliseconds -lt 15000){Start-Sleep -Milliseconds 100};Require (Test-Path -LiteralPath $positivePath) 'P09_HOST_PROTOCOL_POSITIVE_CONTROL_MISSING';$positiveProof=Get-Content -LiteralPath $positivePath -Raw|ConvertFrom-Json;Require ($positiveProof.invoked -and -not $positiveProof.boxed) 'P09_HOST_PROTOCOL_SCOPE_INVALID'
  $nonce=[Guid]::NewGuid().ToString();$protocolPage=$browserProof.ProtocolPage($nonce);$null=Access 'BROWSER_PROTOCOL' $script:browserGuiPid '' $protocolPage
  $pageRequests=@($browserProof.Snapshot()|Where-Object request_kind -eq 'BOXED_PROTOCOL_PAGE');Require ($pageRequests.Count -gt 0 -and @($pageRequests|Where-Object {-not $_.source_scope_verified -or -not $_.source_boxed}).Count -eq 0) 'P09_PROTOCOL_PAGE_NOT_BOXED'
  $clock=[Diagnostics.Stopwatch]::StartNew();$root=$web.compiled.section.FileRootPath[0];$matches=@()
  do{$matches=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter ($nonce+'.json'));if($matches.Count -gt 0){break};Start-Sleep -Milliseconds 200}while($clock.ElapsedMilliseconds -lt 15000)
  Require (-not(Test-Path -LiteralPath (Join-Path $protocolBase ($nonce+'.json')))) 'P09_PROTOCOL_ESCAPED_TO_HOST'
  Require ($matches.Count -eq 1) 'P09_PROTOCOL_RESULT_NOT_OBSERVED';$proof=Get-Content -LiteralPath $matches[0].FullName -Raw|ConvertFrom-Json;Require ($proof.invoked -and $proof.boxed) 'P09_PROTOCOL_HELPER_NOT_BOXED'
  @{real_browser_address_action=$true;actual_boxed_protocol_link_page=$true;host_protocol_positive_control=$true;original_registered_handler_fixture=$true;reachable_handler_executed_boxed=$true;host_marker_absent=$true;browser_sandbox_disable_flag=$false;generic_external_protocol_support_claimed=$false}
 }
 Case 'T30' 'browser_own_content_sandbox_remains_enabled' {
  $r=Access 'BROWSER_SANDBOX' $script:browserGuiPid;Require ($r.browser_own_sandbox_enabled -and $r.effective_content_sandbox_level -gt 0) 'P09_BROWSER_SANDBOX_DISABLED'
  @{real_about_support=$r.real_about_support;effective_content_sandbox_level=$r.effective_content_sandbox_level;browser_own_sandbox_enabled=$true;no_disable_sandbox_argument=$true;no_security_sandbox_preferences_changed=$true;clean_profiles=$true}
 }
 if($null -ne $browserProof){$browserProof.Snapshot()|ConvertTo-Json -Depth 8|Set-Content (Join-Path $results 'browser-http-attribution.json') -Encoding utf8}
 Stop-Box $web
 Case 'T32' 'launch_overhead_observed_against_same_fixed_original_dispatch' {
  $box='SR_'+$apps.id.Replace('-','');$lab.Register($box);$clock=[Diagnostics.Stopwatch]::StartNew();$direct=$lab.HoldProductionProbe($box);$directMs=$clock.Elapsed.TotalMilliseconds
  try{Require ($lab.HeldMemberAlive($direct,$box)) 'P09_DIRECT_BASELINE_NOT_BOXED'}finally{[P05Lab]::Stop($direct);$lab.FenceFixture($box)}
  $application=Register-App $apps 'P09 launch budget' (Join-Path $productHome 'securerun-launch-probe.exe') @('hold',(Join-Path $Fixture 'managed-launch.jsonl'));$clock.Restart();$receipt=Launch-App $apps $application;$managedMs=$clock.Elapsed.TotalMilliseconds;Stop-Box $apps;$null=Native @{action='RECONCILE';operation_id=$receipt.operation_id} 'control'
  $measurement=@{same_fixed_benign_probe=$true;original_dispatch_ms=$directMs;production_manager_dispatch_ms=$managedMs;manager_added_upper_bound_ms=[Math]::Max(0,$managedMs-$directMs);target_startup_included_in_both=$true;target_met=($managedMs-$directMs -lt 1000);no_required_check_removed=$true}
  $measurement|ConvertTo-Json|Set-Content (Join-Path $results 'launch-performance.json') -Encoding utf8;$measurement
 }
 $failed=@($cases|Where-Object status -ne 'PASSED').Count;$uiFailed=@($script:uiCases|Where-Object {-not $_.passed}).Count
 @{status=$(if($failed -eq 0 -and $uiFailed -eq 0){$(if($Focused){'DIAGNOSTIC_ONLY'}else{'PASSED'})}else{'FAILED'});workload_mode=$(if($Focused){'DIAGNOSTIC_ONLY'}else{'FULL'});apps_only=[bool]$AppsOnly;normal_gui_manager_exercised=(-not [bool]$AppsOnly);standard_user=$true;manager_commit=$Commit;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;failed=$failed;ui_cases_passed=@($script:uiCases|Where-Object passed).Count;ui_failed=$uiFailed;normal_production_binary=$true;os_security_settings_modified=$false;browser_sandbox_disabled=$false;synthetic_profiles_only=$true}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $results 'standard-product.json') -Encoding utf8
 Save;if($failed -ne 0 -or $uiFailed -ne 0){exit 1}
}catch{
 @{status='FAILED';standard_user=$true;stage=$script:stage;code=$(if($script:failureCode){$script:failureCode}else{'P09_ACTOR_FAILED'});exception_type=$_.Exception.GetBaseException().GetType().FullName;line=$_.InvocationInfo.ScriptLineNumber;manager_commit=$Commit}|ConvertTo-Json|Set-Content (Join-Path $results 'standard-product.json') -Encoding utf8;Save;exit 1
}finally{
 $metadata=Join-Path $env:LOCALAPPDATA 'SecureRun/metadata';if(Test-Path -LiteralPath $metadata){foreach($prefix in @('probe-status-','probe-result-','probe-evidence-','raw-status-','endpoint-status-','scope-status-','identity-status-','image-status-','dns-status-')){Get-ChildItem -LiteralPath $metadata -Filter ($prefix+'*.json') -File|Where-Object Length -LE 8192|Copy-Item -Destination $results}}
 if($null -ne $gui){$gui.Dispose()};if($null -ne $held){[P05Lab]::Stop($held)};if($null -ne $hostBrowser){$hostBrowser.Dispose()};if($null -ne $browserProof){$browserProof.Dispose()};if($registryCreated){Remove-Item -LiteralPath 'HKCU:\Software\Classes\securerun-p09' -Recurse -Force}
}
