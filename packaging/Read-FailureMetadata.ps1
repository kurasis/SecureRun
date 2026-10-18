# Disposable lab diagnosis only. Never authority to trust, terminate or pass a process.
param([datetime]$Since,[string]$Profile)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$known=@('securerun-policy-probe.exe','securerun-policy-probe-x86.exe','securerun-policy-probe-x64.exe','SandboxieRpcSs.exe','SandboxieDcomLaunch.exe','SandboxieCrypto.exe','SandboxieBITS.exe','SbieSvc.exe','dllhost.exe','taskhostw.exe','rundll32.exe','svchost.exe')
$modules=@('SbieDll.dll','ntdll.dll','KERNELBASE.dll','kernel32.dll','ucrtbase.dll','ole32.dll','combase.dll','rpcrt4.dll','wow64.dll','wow64win.dll','wow64cpu.dll','wowarmhw.dll','xtajit.dll')+$known
$reports=[Collections.Generic.List[object]]::new();$live=[Collections.Generic.List[object]]::new();$events=[Collections.Generic.List[object]]::new();$roots=[Collections.Generic.List[string]]::new()
$werAvailable=$true;$cimAvailable=$true;$eventsAvailable=$true;$scanned=0
function PlainDirectory([string]$Path){$item=Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue;return ($null -ne $item -and $item.PSIsContainer -and -not($item.Attributes -band [IO.FileAttributes]::ReparsePoint))}
function Canonical([string]$Value,$Allow){return @($Allow|Where-Object {$_ -ieq $Value}|Select-Object -First 1)[0]}
try{
 $roots.Add((Join-Path $env:ProgramData 'Microsoft/Windows/WER'));$roots.Add((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft/Windows/WER'))
 # WER itself may write into the diagnostic box's virtualized profile. Read only
 # fixed known WER locations, not arbitrary profile files or raw event messages.
 $boxes=Join-Path $Profile 'boxes'
 if(PlainDirectory $boxes){foreach($box in @(Get-ChildItem -LiteralPath $boxes -Directory|Select-Object -First 64)){
  if($box.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
  foreach($relative in @('user/current/AppData/Local/Microsoft/Windows/WER','user/current/Local Settings/Application Data/Microsoft/Windows/WER',('drive/'+$env:SystemDrive.Substring(0,1)+'/ProgramData/Microsoft/Windows/WER'))){
   $candidate=$box.FullName;$plain=$true
   foreach($part in $relative.Split('/')){$candidate=Join-Path $candidate $part;if(-not(PlainDirectory $candidate)){$plain=$false;break}}
   if($plain){$roots.Add($candidate)}
  }
 }}
 foreach($root in $roots){if(-not(PlainDirectory $root)){continue};foreach($queue in @('ReportQueue','ReportArchive')){
  $base=Join-Path $root $queue;if(-not(PlainDirectory $base)){continue}
  foreach($directory in @(Get-ChildItem -LiteralPath $base -Directory|Select-Object -First 64)){
   if($directory.Attributes -band [IO.FileAttributes]::ReparsePoint){continue};$file=Join-Path $directory.FullName 'Report.wer';$entry=Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
   if($null -eq $entry -or $entry.PSIsContainer -or $entry.CreationTimeUtc -lt $Since.ToUniversalTime() -or $entry.Length -gt 262144 -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
   $scanned++;$fields=@{};foreach($line in [IO.File]::ReadAllText($file) -split '\r?\n'){if($line -match '^([^=]{1,100})=(.*)$'){$fields[$Matches[1]]=$Matches[2]}}
   $app=if($fields.ContainsKey('AppPath')){[IO.Path]::GetFileName($fields.AppPath)}elseif($fields.ContainsKey('AppName')){$fields.AppName}else{''};if($app -notin $known){continue}
   $module='WITHHELD';$exception='WITHHELD';$version='WITHHELD'
   foreach($key in @($fields.Keys)){if($key -match '^Sig\[([0-9]{1,2})\]\.Name$'){$index=$Matches[1];$value=$fields['Sig['+$index+'].Value'];switch($fields[$key]){
    'Fault Module Name' {if($value -in $modules){$module=Canonical $value $modules}}
    'Exception Code' {if($value -cmatch '^(?:0x)?[0-9a-fA-F]{8}$'){$exception=$value.ToLowerInvariant()}}
    'Application Version' {if($value -cmatch '^\d{1,10}\.\d{1,10}\.\d{1,10}\.\d{1,10}$'){$version=$value}}
   }}}
   $reports.Add(@{application_kind=(Canonical $app $known);fault_module_kind=$module;exception_code_hex=$exception;application_version=$version;association_authorizes_no_action=$true});if($reports.Count -ge 8){break}
  };if($reports.Count -ge 8){break}
 };if($reports.Count -ge 8){break}}
}catch{$werAvailable=$false}
try{
 $processes=@(Get-CimInstance Win32_Process -OperationTimeoutSec 10)
 foreach($reporter in @($processes|Where-Object Name -IEQ 'WerFault.exe'|Select-Object -First 16)){
  $kind='WITHHELD';$targetPresent=$false;$targetSwitch=$false
  if($reporter.CommandLine -match '(?i)(?:^|\s)-p\s+([0-9]{1,10})(?:\s|$)'){$targetSwitch=$true;$targetId=[uint32]0;if([uint32]::TryParse($Matches[1],[ref]$targetId)){$target=@($processes|Where-Object ProcessId -EQ $targetId);if($target.Count -eq 1){$targetPresent=$true;if($target[0].Name -in $known){$kind=Canonical $target[0].Name $known}}}}
  $live.Add(@{reporter_kind='WerFault.exe';numeric_target_switch_observed=$targetSwitch;cim_target_present=$targetPresent;associated_component_kind=$kind;association_authorizes_no_action=$true})
 }
}catch{$cimAvailable=$false}
try{
 foreach($event in @(Get-WinEvent -FilterHashtable @{LogName='Application';Id=@(1000,1001);StartTime=$Since} -MaxEvents 128 -ErrorAction SilentlyContinue)){
  $xml=[xml]$event.ToXml();$fields=@{};foreach($item in $xml.Event.EventData.Data){$fields[$item.GetAttribute('Name')]=$item.InnerText}
  $app=if($fields.ContainsKey('AppName')){$fields.AppName}elseif($fields.ContainsKey('P1')){$fields.P1}else{''};if($app -notin $known){continue}
  $module=if($fields.ContainsKey('ModuleName') -and $fields.ModuleName -in $modules){Canonical $fields.ModuleName $modules}else{'WITHHELD'}
  $exception=if($fields.ContainsKey('ExceptionCode') -and $fields.ExceptionCode -cmatch '^(?:0x)?[0-9a-fA-F]{8}$'){$fields.ExceptionCode.ToLowerInvariant()}else{'WITHHELD'}
  $events.Add(@{application_kind=(Canonical $app $known);event_id=$event.Id;fault_module_kind=$module;exception_code_hex=$exception});if($events.Count -ge 16){break}
 }
}catch{$eventsAvailable=$false}
@{schema=1;read_only_wer_metadata_available=$werAvailable;readonly_cim_available=$cimAvailable;read_only_fault_log_available=$eventsAvailable;metadata_files_scanned=$scanned;reports=@($reports.ToArray());live_reporters=@($live.ToArray());fixed_component_events=@($events.ToArray());raw_paths_arguments_ids_and_reports_retained=$false;termination_dispatched=$false;os_error_reporting_modified=$false}
