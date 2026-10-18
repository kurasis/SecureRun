[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'P11_DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path;$out=Join-Path $repo 'artifacts/p11';$packages=Join-Path $repo 'artifacts/p11-packages'
$installRoot=Join-Path $env:ProgramFiles 'SecureRun Development';$engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus'
$cases=[Collections.Generic.List[object]]::new();$password=$null;$shareCreated=$false;$bridge=$null
$script:setupObservations=[Collections.Generic.List[object]]::new()
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Case([string]$id,[string]$name,[scriptblock]$body){
 $c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c)
 try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.line=$_.InvocationInfo.ScriptLineNumber;$c.code=if($_.Exception.GetBaseException().Message -cmatch '^[A-Z][A-Z0-9_]{3,100}$'){$_.Exception.GetBaseException().Message}else{'P11_PACKAGING_CASE_FAILED'};throw}
 finally{ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 12|Set-Content (Join-Path $out 'packaging-cases.json') -Encoding utf8}
}
function Setup([string]$File,[switch]$Fail){
 $log=Join-Path $fixture ('setup-private-'+$script:setupObservations.Count+'.log')
 $clock=[Diagnostics.Stopwatch]::StartNew()
 $p=Start-Process -FilePath $File -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/LOG="'+$log+'"')) -PassThru
 try{
  Require ($p.WaitForExit(300000)) 'P11_SETUP_TIMEOUT'
  # Inno's uninstaller can continue in its temporary cloned process after the
  # initial process exits. Wait for final log closure and then test postconditions;
  # do not replay the uninstall, read a partial log, or terminate unknown processes.
  $text=$null;$closed=$false;$lockWaits=0
  do{
   if(Test-Path $log){
    Require ((Get-Item $log).Length -le 4194304) 'P11_PRIVATE_LOG_SIZE_BOUND'
    try{$text=[IO.File]::ReadAllText($log);$closed=$true}catch [IO.IOException]{$lockWaits++}
   }
   if(-not $closed){Start-Sleep -Milliseconds 50}
  }while(-not $closed -and $clock.ElapsedMilliseconds -lt 300000)
  Require $closed 'P11_INSTALLER_COMPLETION_NOT_OBSERVED'
  $events=@([regex]::Matches($text,'\bP11_[A-Z0-9_]+(?:-[0-9]+)?\b')|ForEach-Object Value|Sort-Object -Unique)
  $script:setupObservations.Add(@{file=[IO.Path]::GetFileName($File);exit_code=$p.ExitCode;expected_failure=[bool]$Fail;events=$events;private_log_retained=$false;final_log_closed=$closed;log_close_waits=$lockWaits})
  ConvertTo-Json -InputObject @($script:setupObservations.ToArray()) -Depth 8|Set-Content (Join-Path $out 'setup-observations.json') -Encoding utf8
  if($Fail){Require ($p.ExitCode -ne 0) 'P11_SETUP_UNEXPECTEDLY_SUCCEEDED'}else{Require ($p.ExitCode -eq 0) 'P11_SETUP_FAILED'};return $p.ExitCode
 }finally{$p.Dispose()}
}
function Payload-Matches {
 $m=Get-Content (Join-Path $packages 'payload/package-manifest.json') -Raw|ConvertFrom-Json
 foreach($f in $m.files){Require ((Get-FileHash -LiteralPath (Join-Path $installRoot $f.name)).Hash.ToLowerInvariant() -eq $f.sha256) 'P11_INSTALLED_PAYLOAD_HASH_MISMATCH'}
 Require ((Get-FileHash (Join-Path $installRoot 'package-manifest.json')).Hash -eq (Get-FileHash (Join-Path $packages 'payload/package-manifest.json')).Hash) 'P11_INSTALLED_MANIFEST_CHANGED'
}
function Snapshot($state){
 # Hash private synthetic paths locally; publish only role-labelled digests/counts.
 $lines=@(Get-ChildItem -LiteralPath $state.profile -Recurse -File|Sort-Object FullName|ForEach-Object {
  ([IO.Path]::GetRelativePath($state.profile,$_.FullName))+' '+(Get-FileHash -LiteralPath $_.FullName).Hash
 })
 $bytes=[Text.Encoding]::UTF8.GetBytes(($lines -join "`n"));return @{files=$lines.Count;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
}
function Standard([string]$Mode){
 $s=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source);$s.UseShellExecute=$false;$s.WorkingDirectory=$engine;$s.UserName=$user.Name;$s.Domain=[Environment]::MachineName;$s.Password=$password;$s.LoadUserProfile=$true
 $s.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData')){$v=[Environment]::GetEnvironmentVariable($key);if($null -ne $v){$s.Environment[$key]=$v}};$s.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$s.Environment['GITHUB_ACTIONS']='true';$s.Environment['TEMP']=Join-Path $owned 'temp';$s.Environment['TMP']=$s.Environment['TEMP']
 foreach($a in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $labCode 'standard.ps1'),'-Manager',(Join-Path $installRoot 'securerun.exe'),'-EngineHome',$engine,'-Fixture',$owned,'-Mode',$Mode)){$s.ArgumentList.Add($a)}
 $p=[Diagnostics.Process]::Start($s)
 try{Require ($p.WaitForExit(1200000)) 'P11_STANDARD_ACTOR_TIMEOUT';Get-ChildItem (Join-Path $owned 'results') -Filter '*.json'|Copy-Item -Destination $out;Require ($p.ExitCode -eq 0) 'P11_STANDARD_ACTOR_FAILED'}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try{
 & (Join-Path $PSScriptRoot 'Build-P11.ps1')
 $build=Get-Content (Join-Path $out 'build.json') -Raw|ConvertFrom-Json
 $baseline=Join-Path $packages (@($build.packages|Where-Object package_version -eq '0.3.0.10')[0].name)
 $candidate=Join-Path $packages (@($build.packages|Where-Object package_version -eq '0.3.0.11')[0].name)
 Require (-not(Test-Path $installRoot)) 'P11_PREEXISTING_MANAGER_NOT_CHANGED'
 $run=[Guid]::NewGuid().ToString('N');$fixture=Join-Path $env:ProgramData "SecureRunLab/p02-p11-$run";$null=New-Item -ItemType Directory -Path $fixture -Force
 $labCode=Join-Path $env:ProgramFiles "SecureRun-P11-Lab-$run";$null=New-Item -ItemType Directory -Path $labCode
 foreach($f in @('standard.ps1','lab_native.cs')){Copy-Item (Join-Path $PSScriptRoot $f) $labCode}
 Copy-Item (Join-Path $repo 'tools/lab/Read-DiagnosticFailureMetadata.ps1') $labCode
 foreach($f in @('p05_lab.cs','p05_boxed.ps1','engine_bridge.cs','p08_initialize.ps1')){Copy-Item (Join-Path $repo "tools/probe/$f") $labCode}
 Case 'T02' 'installer_rejects_user_writable_existing_code_directory' {
  $null=New-Item -ItemType Directory -Path $installRoot
  $acl=Get-Acl $installRoot;$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),'Modify','ContainerInherit,ObjectInherit','None','Allow'));Set-Acl $installRoot $acl
  $code=Setup $baseline -Fail;Require (-not(Test-Path (Join-Path $installRoot 'securerun.exe'))) 'P11_UNSAFE_CODE_INSTALLED';[IO.Directory]::Delete($installRoot)
  @{exit_code=$code;user_writable_install_refused=$true;manager_not_installed=$true}
 }
 Case 'T02' 'installer_rejects_junction_without_touching_destination' {
  $outside=Join-Path $fixture 'junction-destination';$null=New-Item -ItemType Directory -Path $outside;[IO.File]::WriteAllText((Join-Path $outside 'canary.txt'),'P11_JUNCTION_UNCHANGED')
  $null=New-Item -ItemType Junction -Path $installRoot -Target $outside
  try{$code=Setup $baseline -Fail;Require ([IO.File]::ReadAllText((Join-Path $outside 'canary.txt')) -eq 'P11_JUNCTION_UNCHANGED') 'P11_JUNCTION_DESTINATION_CHANGED';Require (@(Get-ChildItem $outside -File).Count -eq 1) 'P11_JUNCTION_PAYLOAD_WRITTEN'}finally{[IO.Directory]::Delete($installRoot)}
  @{exit_code=$code;junction_refused=$true;destination_unchanged=$true}
 }
 Case 'T01' 'official_webview_prerequisite_matches_os_baseline' {
  $key='HKLM:/SOFTWARE/WOW6432Node/Microsoft/EdgeUpdate/Clients/{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
  $before=Get-ItemProperty $key -ErrorAction SilentlyContinue
  $beforeVersion=if($null -ne $before){[string]$before.pv}else{$null}
  $uninstallCode=$null;$isArm=($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
  # Microsoft documents WebView2 as part of Windows 11. Preserve that baseline
  # on ARM. The Server lab independently exercises actual runtime absence and
  # the common official bootstrapper path; this is not a factorial certification
  # of a manually stripped Windows 11 OS image.
  if(-not $isArm -and $null -ne $before -and $before.pv -ne '0.0.0.0'){
   Require ($before.pv -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') 'P11_RUNTIME_VERSION_UNSAFE'
   $runtimeSetup=Join-Path ${env:ProgramFiles(x86)} ('Microsoft/EdgeWebView/Application/'+$before.pv+'/Installer/setup.exe')
   $sig=Get-AuthenticodeSignature -LiteralPath $runtimeSetup;Require ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'O=Microsoft Corporation') 'P11_RUNTIME_UNINSTALLER_NOT_TRUSTED'
   $p=Start-Process -FilePath $runtimeSetup -ArgumentList @('--uninstall','--msedgewebview','--system-level','--force-uninstall','--verbose-logging') -PassThru
   try{Require ($p.WaitForExit(120000)) 'P11_RUNTIME_UNINSTALL_TIMEOUT';$uninstallCode=$p.ExitCode}finally{$p.Dispose()}
  }
  $clock=[Diagnostics.Stopwatch]::StartNew()
  do{$state=Get-ItemProperty $key -ErrorAction SilentlyContinue;$absent=($null -eq $state -or $state.pv -eq '0.0.0.0');if($isArm -or $absent){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 120000)
  if(-not $isArm){Require $absent 'P11_CLEAN_RUNTIME_NOT_ABSENT'}
  if(-not $absent){Require ($state.pv -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' -and [int]($state.pv.Split('.')[0]) -ge 120) 'P11_PREINSTALLED_RUNTIME_UNSUITABLE'}
  $mode=if($absent){'ABSENT_OFFICIAL_BOOTSTRAPPER_INSTALL'}else{'WINDOWS_11_PREINSTALLED_RUNTIME'}
  $code=Setup $baseline;Payload-Matches
  $after=Get-ItemProperty $key;Require ($after.pv -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' -and [int]($after.pv.Split('.')[0]) -ge 120) 'P11_OFFICIAL_RUNTIME_NOT_INSTALLED'
  $candidates=@(@(${env:ProgramFiles(x86)},$env:ProgramFiles)|Select-Object -Unique|ForEach-Object {Join-Path $_ ('Microsoft/EdgeWebView/Application/'+$after.pv+'/msedgewebview2.exe')}|Where-Object {Test-Path -LiteralPath $_})
  Require ($candidates.Count -eq 1) 'P11_RUNTIME_IMAGE_AMBIGUOUS'
  $runtimeSignature=Get-AuthenticodeSignature -LiteralPath $candidates[0];Require ($runtimeSignature.Status -eq 'Valid' -and $runtimeSignature.SignerCertificate.Subject -match 'O=Microsoft Corporation') 'P11_INSTALLED_RUNTIME_SIGNATURE_INVALID'
  @{tested_state=$mode;runtime_absent_before_install=$absent;previous_runtime_version=$beforeVersion;previous_runtime_uninstall_exit=$uninstallCode;runtime_uninstall_dispatched=(-not $isArm -and $null -ne $uninstallCode);setup_exit=$code;runtime_version=$after.pv;runtime_signature=$runtimeSignature.Status.ToString();runtime_sha256=(Get-FileHash -LiteralPath $candidates[0]).Hash.ToLowerInvariant();prerequisite='MICROSOFT_SIGNED_HASH_PINNED_EVERGREEN_BOOTSTRAPPER';os_inbox_runtime_preserved=$isArm;missing_runtime_arm_installation_tested=($isArm -and $absent);security_settings_modified=$false}
 }
 Case 'T29' 'clean_install_has_exact_reviewed_payload_and_native_architecture' {Payload-Matches;@{all_payload_hashes_match=$true;package='0.3.0.10';native_target=$build.target;signing='UNSIGNED_DEVELOPMENT_ONLY';engine_bundled=$false}}
 & (Join-Path $repo 'tools/lab/Initialize-P02.ps1')
 & (Join-Path $repo 'tools/lab/Build-P05-View.ps1')
 $setup=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source);$setup.UseShellExecute=$false;$setup.WorkingDirectory=$engine
 foreach($a in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $labCode 'p08_initialize.ps1'),'-EngineHome',$engine,'-Fixture',$fixture)){$setup.ArgumentList.Add($a)}
 $p=[Diagnostics.Process]::Start($setup);try{Require ($p.WaitForExit(60000) -and $p.ExitCode -eq 0) 'P11_LAB_WFP_SETUP_FAILED'}finally{$p.Dispose()}
 $share='SecureRunP05Synthetic';Require ($null -eq (Get-SmbShare $share -ErrorAction SilentlyContinue)) 'P11_PREEXISTING_SHARE_NOT_CHANGED'
 $shareRoot=Join-Path $fixture 'synthetic-network';$null=New-Item -ItemType Directory -Path $shareRoot;[IO.File]::WriteAllText((Join-Path $shareRoot 'canary.txt'),'SYNTHETIC_NETWORK_CANARY')
 $users=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value;$admins=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')).Translate([Security.Principal.NTAccount]).Value
 $null=New-SmbShare -Name $share -Path $shareRoot -ReadAccess $users -FullAccess $admins;$shareCreated=$true
 $password=ConvertTo-SecureString ('P11aA!'+[Guid]::NewGuid().ToString('N')) -AsPlainText -Force;$user=New-LocalUser -Name ('SRP11_'+$run.Substring(0,10)) -Password $password -AccountNeverExpires;Add-LocalGroupMember -Group ($users.Split('\')[-1]) -Member $user
 $owned=Join-Path $fixture 'owner';$null=New-Item -ItemType Directory -Path (Join-Path $owned 'temp') -Force;$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
 foreach($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl $owned $acl
 Standard 'seed'
 Case 'T29' 'failed_upgrade_rolls_back_files_and_retains_profile' {
  $state=Get-Content (Join-Path $owned 'private-state.json') -Raw|ConvertFrom-Json;$before=Snapshot $state
  $held=[IO.File]::Open((Join-Path $installRoot 'securerun.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{$code=Setup $candidate -Fail}finally{$held.Dispose()}
  Payload-Matches;$after=Snapshot $state;Require ($before.sha256 -eq $after.sha256) 'P11_FAILED_UPGRADE_CHANGED_DATA'
  Require ((Get-ItemProperty 'HKLM:/Software/SecureRun Development').PackageVersion -eq '0.3.0.10') 'P11_FAILED_UPGRADE_CHANGED_VERSION'
  @{exit_code=$code;actual_file_lock_failure=$true;old_payload_unchanged=$true;profile_before=$before;profile_after=$after;schema_migration_by_installer=$false}
 }
 Case 'T29' 'upgrade_installs_candidate_without_elevated_profile_migration' {
  $state=Get-Content (Join-Path $owned 'private-state.json') -Raw|ConvertFrom-Json;$before=Snapshot $state;$code=Setup $candidate;Payload-Matches;$after=Snapshot $state
  Require ($before.sha256 -eq $after.sha256) 'P11_UPGRADE_CHANGED_DATA';Require ((Get-ItemProperty 'HKLM:/Software/SecureRun Development').PackageVersion -eq '0.3.0.11') 'P11_UPGRADE_VERSION_MISSING'
  @{exit_code=$code;from='0.3.0.10';to='0.3.0.11';same_runtime_schema_1=$true;profile_before=$before;profile_after=$after;admin_migration=$false}
 }
 Standard 'upgrade'
 Case 'T29' 'older_package_is_refused_without_database_downgrade' {$code=Setup $baseline -Fail;Payload-Matches;Require ((Get-ItemProperty 'HKLM:/Software/SecureRun Development').PackageVersion -eq '0.3.0.11') 'P11_DOWNGRADE_CHANGED_VERSION';@{exit_code=$code;older_package_refused=$true;automatic_schema_downgrade=$false}}
 Case 'T58' 'installed_boxed_manager_and_all_workers_refuse_unboxed_parent_claim' {
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $labCode 'engine_bridge.cs')))
  $shell=(Get-Command pwsh -CommandType Application).Source;$app=Join-Path $installRoot 'securerun.exe';$bridge=[P02Bridge]::new($engine,$fixture,[string[]]@($shell,$app));$box='SRP02_P11_CTL_'+$run.Substring(0,12);$bridge.Register($box)
  foreach($pair in @(@('Enabled','y'),@('DropAdminRights','y'),@('AutoRecover','n'),@('AutoDelete','n'),@('UseFileImage','n'))){$bridge.Set($box,$pair[0],$pair[1])};$bridge.Set($box,'FileRootPath',(Join-Path $fixture "boxes/$box"));$root=$bridge.Root($box);$null=New-Item -ItemType Directory -Path $root -Force;$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'results') -Force;$null=$bridge.CaptureRoot($box)
  $birth=[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc());$savedPath=$env:PATH;$savedModules=$env:PSModulePath;$savedExtensions=$env:PATHEXT;[P02Bridge]::MinimizeProcessEnvironment($engine)
  $receipt=$bridge.Launch($box,$shell,[string[]]@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $labCode 'p05_boxed.ps1'),'-Manager',$app,'-Fixture',$fixture,'-HostPid',[string]$PID,'-HostBirth',$birth))
  try{Require ([P02Bridge]::Completed($receipt,90000) -and [P02Bridge]::ExitCode($receipt) -eq 43) 'P11_BOXED_WORKERS_ACCEPTED';$reports=@(Get-ChildItem $root -Recurse -File -Filter 'boxed-policy.json');Require ($reports.Count -eq 1) 'P11_BOXED_PROOF_MISSING';Copy-Item $reports[0].FullName (Join-Path $out 'boxed-policy.json')}finally{$null=$bridge.StopHeld($box);[P02Bridge]::CloseReceipt($receipt)}
  $receipt=$bridge.Launch($box,$app,[string[]]@())
  try{Require ([P02Bridge]::Completed($receipt,60000) -and [P02Bridge]::ExitCode($receipt) -eq 78) 'P11_BOXED_GUI_ACCEPTED'}finally{$null=$bridge.StopHeld($box);[P02Bridge]::CloseReceipt($receipt);$env:PATH=$savedPath;$env:PSModulePath=$savedModules;$env:PATHEXT=$savedExtensions}
  @{actual_boxed_manager_exit=78;all_worker_families_refused=$true;unboxed_parent_claim_accepted=$false;product_helper=$false}
 }
 Case 'T48' 'uninstall_removes_only_code_and_retains_profile_engine_runtime' {
  $state=Get-Content (Join-Path $owned 'private-state.json') -Raw|ConvertFrom-Json;$before=Snapshot $state
  $engineHash=(Get-FileHash (Join-Path $engine 'SbieDrv.sys')).Hash;$code=Setup (Join-Path $installRoot 'unins000.exe')
  Require (-not(Test-Path (Join-Path $installRoot 'securerun.exe'))) 'P11_CODE_REMAINS_AFTER_UNINSTALL'
  $payload=Get-Content (Join-Path $packages 'payload/package-manifest.json') -Raw|ConvertFrom-Json
  foreach($file in @($payload.files.name)+@('package-manifest.json')){Require (-not(Test-Path (Join-Path $installRoot $file))) 'P11_OWNED_PAYLOAD_REMAINS_AFTER_UNINSTALL'}
  Require (-not(Test-Path 'HKLM:/Software/SecureRun Development')) 'P11_REGISTRATION_REMAINS_AFTER_UNINSTALL'
  $after=Snapshot $state;Require ($before.sha256 -eq $after.sha256) 'P11_UNINSTALL_CHANGED_RETAINED_DATA'
  Require ((Get-Service SbieSvc).Status -eq 'Running' -and (Get-FileHash (Join-Path $engine 'SbieDrv.sys')).Hash -eq $engineHash) 'P11_UNINSTALL_CHANGED_ENGINE'
  $runtime=Get-ItemProperty 'HKLM:/SOFTWARE/WOW6432Node/Microsoft/EdgeUpdate/Clients/{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';Require ([int]($runtime.pv.Split('.')[0]) -ge 120) 'P11_UNINSTALL_REMOVED_RUNTIME'
  @{exit_code=$code;code_removed=$true;all_owned_payload_removed=$true;registration_removed=$true;profile_before=$before;profile_after=$after;engine_unchanged=$true;webview_runtime_retained=$true;environment_cleanup_dispatched=$false}
 }
 Case 'T48' 'reinstall_preserves_data_before_owner_reconciliation' {$state=Get-Content (Join-Path $owned 'private-state.json') -Raw|ConvertFrom-Json;$before=Snapshot $state;$code=Setup $candidate;Payload-Matches;$after=Snapshot $state;Require ($before.sha256 -eq $after.sha256) 'P11_REINSTALL_CHANGED_DATA';@{exit_code=$code;profile_before=$before;profile_after=$after;automatic_cleanup=$false}}
 Standard 'reinstall'
 $state=Get-Content (Join-Path $owned 'private-state.json') -Raw|ConvertFrom-Json
 # Record scoped N/A portions explicitly. No helper enrollment is manufactured.
 @{T27='APPLICABLE_BOXED_WORKER_BOUNDARY_PASSED_HELPER_SUBCASE_NA';T47='APPLICABLE_FORGED_PARENT_PASSED_HELPER_SUBCASE_NA';T52='NOT_APPLICABLE_NO_PRODUCT_HELPER';T57='NO_PRIVILEGED_METADATA_AUTHORITY_INSTALLED_MANAGER_CONTEXT_TESTED';different_account_uac='NOT_APPLICABLE_NO_PRODUCT_HELPER';all_66_final_acceptance='NOT_STARTED_P12'}|ConvertTo-Json|Set-Content (Join-Path $out 'scope.json') -Encoding utf8
 $all=@($cases.ToArray());foreach($f in @('seed','upgrade','reinstall')){$all+=@(Get-Content (Join-Path $out ($f+'-cases.json')) -Raw|ConvertFrom-Json)}
 $summary=@{phase='P11';result='PASSED';tested_commit=$build.source_commit;target=$build.target;os_build=[Environment]::OSVersion.Version.Build;cases_passed=@($all|Where-Object status -eq 'PASSED').Count;cases_failed=@($all|Where-Object status -ne 'PASSED').Count;signing='UNSIGNED_DEVELOPMENT_ONLY';webview_prerequisite_verified=$true;installed_payload_verified=$true;retention_verified=$true;installed_smoke_after_reinstall=$true;elevated_product_helper=$false;engine_bundled=$false;os_security_settings_modified=$false;final_acceptance_scenarios_passed=0;teardown='DISCARD_ACTIONS_VM'}
 Require ($summary.cases_failed -eq 0) 'P11_CASE_FAILURES';$summary|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
}finally{
 if($null -ne $password){$password.Dispose()}
 if($shareCreated){Remove-SmbShare -Name 'SecureRunP05Synthetic' -Force -ErrorAction SilentlyContinue}
}
