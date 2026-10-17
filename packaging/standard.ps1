param([string]$Manager,[string]$EngineHome,[string]$Fixture,[ValidateSet('seed','upgrade','reinstall')][string]$Mode)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'P11_DISPOSABLE_VM_REQUIRED'}
$results=Join-Path $Fixture 'results';$null=New-Item -ItemType Directory -Path $results -Force
$cases=[Collections.Generic.List[object]]::new()
$env:USERPROFILE=[Environment]::GetFolderPath('UserProfile');$env:LOCALAPPDATA=[Environment]::GetFolderPath('LocalApplicationData');$env:APPDATA=[Environment]::GetFolderPath('ApplicationData')
$env:TEMP=Join-Path $Fixture 'temp';$env:TMP=$env:TEMP;$null=New-Item -ItemType Directory -Path $env:TEMP -Force
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Case([string]$id,[string]$name,[scriptblock]$body){
 $c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c)
 try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.code=if($_.Exception.GetBaseException().Message -cmatch '^[A-Z][A-Z0-9_]{3,100}$'){$_.Exception.GetBaseException().Message}else{'P11_CASE_FAILED'};$c.line=$_.InvocationInfo.ScriptLineNumber;throw}
 finally{ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 10|Set-Content (Join-Path $results ($Mode+'-cases.json')) -Encoding utf8}
}
function Native($request,[string]$kind='policy',[switch]$AllowFailure){
 $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add("--$kind-once");$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
 $p=[Diagnostics.Process]::Start($s)
 try{$text=$p.StandardOutput.ReadToEndAsync();$errors=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 12 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(660000)) 'P11_NATIVE_TIMEOUT';Require ($p.ExitCode -eq 0 -and $text.Result.Length -le 2097152) 'P11_NATIVE_RESPONSE_INVALID';$r=$text.Result|ConvertFrom-Json -Depth 40;if(-not $AllowFailure){Require ($r.reason -eq 'OBSERVED') $r.reason};return $r}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function Environment-View {$r=Native @{action='LIST'};return @($r.environments|Where-Object display_name -eq 'P11 retained Привет 🧪')[0]}
function Workspace($e){$q=@{action='LIST';environment_id=$e.id;expected_revision=$e.revision;node_id=$null;offset=0};$r=Native $q 'files';foreach($name in @('drive',$env:SystemRoot.Substring(0,1),'SecureRunWorkspace',$e.id.Replace('-',''))){$entry=$r.entries|Where-Object name -eq $name;Require ($null -ne $entry) 'P11_WORKSPACE_MAPPING_MISSING';$q.node_id=$entry.id;$r=Native $q 'files'};return $r}
try{
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();Require (-not [Security.Principal.WindowsPrincipal]::new($identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'P11_STANDARD_USER_REQUIRED'
 Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'lab_native.cs')))
 Case 'T02' ($Mode+'_ordinary_user_cannot_modify_installed_code') {
  $denied=$false;try{$f=[IO.File]::Open($Manager,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite);$f.Dispose()}catch [UnauthorizedAccessException]{$denied=$true};Require $denied 'P11_CODE_WRITABLE'
  $createDenied=$false;try{[IO.File]::WriteAllText((Join-Path (Split-Path $Manager) 'actor-must-not-create.txt'),'SYNTHETIC')}catch [UnauthorizedAccessException]{$createDenied=$true};Require $createDenied 'P11_CODE_DIRECTORY_WRITABLE'
  @{standard_user=$true;manager_write_denied=$denied;new_code_file_denied=$createDenied;product_helper=$false}
 }
 Case 'T01' ($Mode+'_installed_manager_opens_real_webview_and_closes') {
  $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=(Split-Path $Manager);$gui=[Diagnostics.Process]::Start($s)
  try{[P11Native]::NormalWindow($gui,$Manager)}finally{if(-not $gui.HasExited){$gui.Kill($true)};$gui.Dispose()}
  @{actual_installed_executable=$true;normal_features=$true;real_webview_window_observed=$true;ordinary_user=$true}
 }
 if($Mode -eq 'seed'){
  Case 'T08' 'installed_build_provisions_and_verifies_real_offline_policy' {
   $r=Native @{action='CREATE';display_name='P11 retained Привет 🧪';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}}
   $e=Environment-View;Require ($e.stage -eq 'VERIFIED' -and $null -ne $e.enforcement_evidence -and $null -ne $e.root_identity -and $e.owner_sid -eq $identity.User.Value) 'P11_INSTALLED_POLICY_UNVERIFIED'
   @{native_policy_verifier=$true;standard_offline=$true;root_identity_bound=$true;enforcement_evidence_bound=$true;owner_from_os=$true}
  }
  Case 'T12' 'installed_import_export_preserves_bytes_and_provenance' {
   $e=Environment-View;$source=Join-Path $Fixture 'retained-source.txt';[IO.File]::WriteAllText($source,'P11_SYNTHETIC_RETAINED_DATA_Привет')
   $null=Native @{action='IMPORT';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();source=$source;name='retained.txt'} 'files'
   $entry=(Workspace $e).entries|Where-Object name -eq 'retained.txt';Require ($null -ne $entry) 'P11_IMPORTED_FILE_MISSING'
   $destination=Join-Path $env:USERPROFILE 'SecureRun-P11-Exports';$null=New-Item -ItemType Directory -Path $destination
   $null=Native @{action='EXPORT';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();file_id=$entry.id;destination=$destination;name='retained-copy.txt'} 'files'
   $export=Join-Path $destination 'retained-copy.txt';Require ((Get-FileHash $source).Hash -eq (Get-FileHash $export).Hash) 'P11_EXPORTED_BYTES_CHANGED';$zone=Get-Content -LiteralPath ($export+':Zone.Identifier') -Raw;Require ($zone.Contains('ZoneId=3')) 'P11_PROVENANCE_MISSING'
   @{import_export_actual=$true;byte_hash_match=$true;internet_zone_verified=$true;host_auto_execution=$false}
  }
 }else{
  Case 'T48' ($Mode+'_same_account_reopens_verified_retained_environment_and_file') {
   $e=Environment-View;Require ($e.stage -eq 'VERIFIED' -and $null -ne $e.root_identity) 'P11_RETAINED_ENVIRONMENT_NOT_VERIFIED'
   $entry=(Workspace $e).entries|Where-Object name -eq 'retained.txt';Require ($null -ne $entry) 'P11_RETAINED_DATA_MISSING'
   $root=$e.compiled.section.FileRootPath[0];$file=@(Get-ChildItem $root -Recurse -File -Filter 'retained.txt');Require ($file.Count -eq 1 -and [IO.File]::ReadAllText($file[0].FullName) -eq 'P11_SYNTHETIC_RETAINED_DATA_Привет') 'P11_RETAINED_BYTES_CHANGED'
   @{same_account=$true;owned_environment_revalidated=$true;retained_data_unchanged=$true;automatic_cleanup=$false}
  }
 }
 Case 'T05' ($Mode+'_installed_production_launcher_stays_boxed') {
  $e=Environment-View;$leaf='p11-'+$Mode+'-launch.jsonl';$hostOutput=Join-Path $Fixture $leaf
  $q=@{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();display_name=('P11 '+$Mode);executable=(Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe');arguments=@('short',$hostOutput);working_directory=$null}
  $r=Native $q 'control';$app=@($r.applications|Where-Object {$_.environment_id -eq $e.id -and $_.display_name -eq ('P11 '+$Mode)})[0]
  $op=[Guid]::NewGuid().ToString();$r=Native @{action='LAUNCH';environment_id=$e.id;expected_revision=$e.revision;application_id=$app.id;operation_id=$op} 'control';$receipt=$r.receipts|Where-Object operation_id -eq $op;Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason
  $root=$e.compiled.section.FileRootPath[0];$clock=[Diagnostics.Stopwatch]::StartNew();do{$reports=@(Get-ChildItem $root -Recurse -File -Filter $leaf);if($reports.Count -eq 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
  Require ($reports.Count -eq 1 -and -not(Test-Path $hostOutput)) 'P11_LAUNCH_ESCAPED_OR_OUTPUT_MISSING';$data=Get-Content $reports[0].FullName -Raw|ConvertFrom-Json;Require $data.boxed 'P11_TARGET_UNBOXED'
  $null=Native @{action='STOP';environment_id=$e.id;operation_id=[Guid]::NewGuid().ToString()} 'control'
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')));$lab=[P05Lab]::new($EngineHome,$Fixture,(Split-Path $Manager));$lab.FenceFixture(('SR_'+$e.id.Replace('-','')))
  @{real_target_boxed=$true;host_output_absent=$true;installed_launcher_used=$true;scoped_stop=$true}
 }
 if($Mode -eq 'upgrade'){
  foreach($future in @($true,$false)){
   $name=if($future){'future_schema_is_refused_without_downgrade'}else{'failed_initial_migration_is_refused_without_destroying_existing_data'}
   Case 'T28' $name {
    $db=Join-Path $env:LOCALAPPDATA 'SecureRun/metadata/policy.sqlite';$backup=Join-Path $Fixture ('schema-backup-'+$future+'.sqlite');Copy-Item $db $backup
    $original=(Get-FileHash $backup).Hash;[P11Native]::FixtureSchema($db,$future);$before=(Get-FileHash $db).Hash
    try{$r=Native @{action='LIST'} 'policy' -AllowFailure;$expected=if($future){'POLICY_JOURNAL_SCHEMA_UNSUPPORTED'}else{'POLICY_JOURNAL_FOREIGN_DATABASE'};Require ($r.reason -eq $expected) 'P11_SCHEMA_REFUSAL_MISSING';Require ((Get-FileHash $db).Hash -eq $before) 'P11_REFUSAL_CHANGED_DATABASE'}
    finally{Require ((Get-FileHash $backup).Hash -eq $original) 'P11_FIXTURE_BACKUP_CHANGED';Copy-Item $backup $db -Force}
    $e=Environment-View;Require ($e.stage -eq 'VERIFIED') 'P11_FIXTURE_RESTORE_FAILED'
    @{actual_installed_worker=$true;refusal=$expected;database_hash_unchanged_on_failure=$true;schema_downgrade_attempted=$false;fixture_backup_restored_only_by_lab=$true}
   }
  }
 }
 # Private controller handoff; paths/SIDs/database bytes are never published.
 $e=Environment-View;@{profile=(Join-Path $env:LOCALAPPDATA 'SecureRun');root=$e.compiled.section.FileRootPath[0];environment_id=$e.id;root_identity=$e.root_identity;owner=$identity.User.Value;engine_box=('SR_'+$e.id.Replace('-',''))}|ConvertTo-Json|Set-Content (Join-Path $Fixture 'private-state.json') -Encoding utf8
 @{status='PASSED';mode=$Mode;cases_passed=$cases.Count;standard_user=$true;installed_manager_sha256=(Get-FileHash $Manager).Hash.ToLowerInvariant()}|ConvertTo-Json|Set-Content (Join-Path $results ($Mode+'-summary.json')) -Encoding utf8
}catch{
 @{status='FAILED';mode=$Mode;line=$_.InvocationInfo.ScriptLineNumber;code=$(if($_.Exception.GetBaseException().Message -cmatch '^[A-Z][A-Z0-9_]{3,100}$'){$_.Exception.GetBaseException().Message}else{'P11_STANDARD_ACTOR_FAILED'})}|ConvertTo-Json|Set-Content (Join-Path $results ($Mode+'-summary.json')) -Encoding utf8;exit 1
}
