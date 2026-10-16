# Read-only minimized crash metadata. Never authority to trust or terminate a process.
param([datetime]$Since,[string]$ActorSid='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$known=@('securerun.exe','securerun-policy-probe.exe','securerun-policy-probe-x86.exe','securerun-policy-probe-x64.exe','securerun-launch-probe.exe','securerun-launch-probe-x86.exe','securerun-launch-probe-x64.exe','SandboxieRpcSs.exe','SandboxieDcomLaunch.exe','SandboxieCrypto.exe','SandboxieBITS.exe','SbieSvc.exe','firefox.exe','notepad++.exe','7zG.exe','dllhost.exe','taskhostw.exe','rundll32.exe','svchost.exe')
$modules=@('SbieDll.dll','ntdll.dll','KERNELBASE.dll','kernel32.dll','ucrtbase.dll','ole32.dll','combase.dll','rpcrt4.dll','mozglue.dll','xul.dll')
$roots=[Collections.Generic.List[object]]::new();$roots.Add(@{kind='MACHINE';path=(Join-Path $env:ProgramData 'Microsoft/Windows/WER')})
$available=$true;$records=[Collections.Generic.List[object]]::new();$scanned=0
try{
 if($ActorSid -cmatch '^S-1-5-21-[0-9-]{3,100}$'){
  $profile=Get-CimInstance -ClassName Win32_UserProfile -Filter ("SID='"+$ActorSid+"'") -OperationTimeoutSec 5
  if($null -ne $profile -and $profile.LocalPath){$roots.Add(@{kind='ACTOR';path=(Join-Path $profile.LocalPath 'AppData/Local/Microsoft/Windows/WER')})}
 }
 foreach($root in $roots){foreach($queue in @('ReportQueue','ReportArchive')){
  $base=Join-Path $root.path $queue;if(-not(Test-Path -LiteralPath $base -PathType Container)){continue}
  if((Get-Item -LiteralPath $base).Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
  foreach($directory in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction Stop|Select-Object -First 64)){
   if($directory.Attributes -band [IO.FileAttributes]::ReparsePoint){continue};$file=Join-Path $directory.FullName 'Report.wer';if(-not(Test-Path -LiteralPath $file -PathType Leaf)){continue}
   $entry=Get-Item -LiteralPath $file;if($entry.CreationTimeUtc -lt $Since.ToUniversalTime() -or $entry.Length -gt 262144 -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
   $scanned++;$text=[IO.File]::ReadAllText($file);$fields=@{};foreach($line in $text -split '\r?\n'){if($line -match '^([^=]{1,100})=(.*)$'){$fields[$Matches[1]]=$Matches[2]}}
   $app=if($fields.ContainsKey('AppPath')){[IO.Path]::GetFileName($fields.AppPath)}elseif($fields.ContainsKey('AppName')){$fields.AppName}else{''};if($app -notin $known){continue}
   $module='WITHHELD';$exception='WITHHELD'
   foreach($key in @($fields.Keys)){if($key -match '^Sig\[([0-9]{1,2})\]\.Name$'){$index=$Matches[1];$value=$fields['Sig['+$index+'].Value'];if($fields[$key] -eq 'Fault Module Name' -and $value -in $modules){$module=$modules|Where-Object {$_ -ieq $value}|Select-Object -First 1};if($fields[$key] -eq 'Exception Code' -and $value -cmatch '^(?:0x)?[0-9a-fA-F]{8}$'){$exception=$value.ToLowerInvariant()}}}
   $kind=if($fields.ContainsKey('EventType') -and $fields.EventType -in @('APPCRASH','BEX','BEX64','AppHangB1','MoAppCrash')){$fields.EventType}else{'WITHHELD'}
   $records.Add(@{application_kind=($known|Where-Object {$_ -ieq $app}|Select-Object -First 1);fault_module_kind=$module;exception_code_hex=$exception;report_kind=$kind;metadata_source=$root.kind;association_authorizes_no_action=$true});if($records.Count -ge 8){break}
  };if($records.Count -ge 8){break}
 };if($records.Count -ge 8){break}}
}catch{$available=$false}
@{schema=1;read_only_wer_metadata_available=$available;metadata_files_scanned=$scanned;records=@($records.ToArray());raw_report_content_retained=$false;raw_paths_arguments_ids_retained=$false;os_error_reporting_modified=$false;termination_dispatched=$false}
