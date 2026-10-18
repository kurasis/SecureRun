# Disposable diagnostic observer only. Names/associations never grant authority.
param([Parameter(Mandatory)][string]$ResultFile,[Parameter(Mandatory)][string]$StopFile,[Parameter(Mandatory)][string]$MetadataScript,[string]$DebugToolHome='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$sinceUtc=[DateTime]::UtcNow
# Start-Job -FilePath transports the script body without its source directory.
# Resolve this trusted repository support path in the caller before transport.
. $MetadataScript
$labScripts=Split-Path $MetadataScript -Parent
. (Join-Path $labScripts 'Read-P11ExceptionDump.ps1')
. (Join-Path $labScripts 'Invoke-P11ExceptionCapture.ps1')
Add-Type @'
using System;using System.Runtime.InteropServices;using System.Text;
public sealed class P11ObservedProcess : IDisposable {
 private IntPtr handle;
 public long Birth {get;private set;}
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,uint id);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")]static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetProcessTimes(IntPtr process,out long created,out long exited,out long kernel,out long user);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool QueryFullProcessImageNameW(IntPtr process,uint flags,StringBuilder path,ref uint length);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool IsProcessCritical(IntPtr process,[MarshalAs(UnmanagedType.Bool)]out bool critical);
 public static P11ObservedProcess Open(uint id){
  // QUERY_LIMITED_INFORMATION | SYNCHRONIZE. No terminate, debug or VM access.
  IntPtr h=OpenProcess(0x00101000,false,id);if(h==IntPtr.Zero)return null;
  long c,e,k,u;if(!GetProcessTimes(h,out c,out e,out k,out u)||c==0){CloseHandle(h);return null;}
  return new P11ObservedProcess{handle=h,Birth=c};
 }
 public bool HasExited {get{return WaitForSingleObject(handle,0)==0;}}
 public uint ExitCode {get{uint code;if(!GetExitCodeProcess(handle,out code))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return code;}}
 public bool ReadNoncriticalImage(out string path){path=null;bool critical;long c,e,k,u;uint length=32768;var value=new StringBuilder((int)length);if(HasExited||!GetProcessTimes(handle,out c,out e,out k,out u)||c!=Birth||!IsProcessCritical(handle,out critical)||critical||!QueryFullProcessImageNameW(handle,0,value,ref length))return false;path=value.ToString();return true;}
 public void Dispose(){if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;}}
}
'@
$known=@('SandboxieRpcSs','SandboxieDcomLaunch','SandboxieCrypto','SandboxieBITS','SbieSvc','WerFault','securerun-policy-probe','securerun-policy-probe-x86','securerun-policy-probe-x64')
$held=@{};$history=@{};$events=[Collections.Generic.List[object]]::new();$reporters=[Collections.Generic.List[object]]::new();$pendingMetadata=[Collections.Generic.List[object]]::new();$clock=[Diagnostics.Stopwatch]::StartNew();$samples=0;$failures=0;$bounded=$false;$firstBoundMs=$null
# Ten environments reverify earlier siblings (55 environment verifications),
# each with native/x86/emulated-x64 parent/child probes and RPC companions.
# Reporter capacity is independent: normal workload events cannot starve it.
$knownEventLimit=2048;$reporterEventLimit=128;$knownEventCount=0;$reporterEventCount=0
$capture=New-P11ExceptionCapture -ToolHome $DebugToolHome -Repo (Split-Path (Split-Path $labScripts -Parent) -Parent) -Since $sinceUtc
function Save-Observer {
 $debug=$null;if($null -ne $capture){$debug=@{};foreach($key in $capture.public.Keys){if($key -eq 'exceptions'){$debug[$key]=@($capture.public.exceptions.ToArray())}else{$debug[$key]=$capture.public[$key]}}}
 @{schema=1;classification='DIAGNOSTIC_ONLY_NO_PHASE_GATE';observer_active_during_workload=$true;name_observations_are_not_authentication=$true;termination_dispatched=$false;debugger_mode_enabled=($null -ne $capture);debugger_attachment_assumption=$(if($null -eq $capture){'NONE_REQUESTED'}else{'AUTHENTICATED_SCOPE_REQUESTS_ONLY'});exception_capture=$debug;windows_security_or_wer_settings_modified=$false;raw_paths_arguments_ids_and_absolute_times_retained=$false;samples=$samples;observation_failures=$failures;record_bound_reached=$bounded;record_bound_first_reached_ms=$firstBoundMs;known_process_event_limit=$knownEventLimit;reporter_event_limit=$reporterEventLimit;known_process_event_count=$knownEventCount;reporter_event_count=$reporterEventCount;process_events=@($events.ToArray());reporters=@($reporters.ToArray())}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultFile -Encoding utf8
}
try{
 Save-Observer
 while(-not(Test-Path -LiteralPath $StopFile)){
  $samples++
  Update-P11ExceptionCapture $capture $clock.ElapsedMilliseconds
  foreach($process in [Diagnostics.Process]::GetProcesses()){
   $keep=$false;$watched=$null
   try{
    $kind=$process.ProcessName;if($kind -notin $known){continue};$id=[int]$process.Id
    if($held.ContainsKey($id)){continue}
    $watched=[P11ObservedProcess]::Open([uint32]$id);if($null -eq $watched -or $watched.HasExited){continue};$birth=$watched.Birth
    $isReporter=$kind -ieq 'WerFault'
    if(($isReporter -and $reporterEventCount -ge $reporterEventLimit) -or (-not $isReporter -and $knownEventCount -ge $knownEventLimit)){
     $bounded=$true;if($null -eq $firstBoundMs){$firstBoundMs=[long]$clock.ElapsedMilliseconds};continue
    }
    if($isReporter){$reporterEventCount++}else{$knownEventCount++}
    $event=@{kind=$kind+'.exe';started_observation_ms=[long]$clock.ElapsedMilliseconds;completed=$false;exit_code_hex=$null}
    $events.Add($event);$entry=@{process=$watched;birth=$birth;kind=$event.kind;event=$event};$held[$id]=$entry;$history[$id]=$entry;$keep=$true
    if($kind -ieq 'SandboxieRpcSs'){Start-P11KnownHelperCapture $capture ([uint32]$id) $watched}
    if($kind -ieq 'WerFault'){
     $record=@{reporter_kind='WerFault.exe';observed_ms=[long]$clock.ElapsedMilliseconds;numeric_target_switch_observed=$false;target_kind='WITHHELD';target_birth_revalidated=$false;target_was_previously_observed=$false;target_exit_code_hex=$null;association_authorizes_no_action=$true}
     # The command line and numeric identifiers stay in memory only. Authenticate
     # a live association with both retained and fresh kernel-object birth times.
     try{
      $cim=Get-CimInstance Win32_Process -Filter ('ProcessId='+$id) -OperationTimeoutSec 5
      if($null -ne $cim -and $cim.CommandLine -match '(?i)(?:^|\s)-p\s+([0-9]{1,10})(?:\s|$)'){
       $record.numeric_target_switch_observed=$true;$targetId=[uint32]0
       if([uint32]::TryParse($Matches[1],[ref]$targetId) -and $history.ContainsKey([int]$targetId)){
        $candidate=$history[[int]$targetId];$record.target_was_previously_observed=$true
        if($candidate.birth -le $birth){
         $record.target_kind=$candidate.kind;$record.target_exit_code_hex=$candidate.event.exit_code_hex;$record.observed_target_lifetime=$candidate.event
         if($held.ContainsKey([int]$targetId)){
          $fresh=$null
          try{$fresh=[P11ObservedProcess]::Open($targetId);$record.target_birth_revalidated=($null -ne $fresh -and $fresh.Birth -eq $candidate.birth -and -not $fresh.HasExited)}finally{if($null -ne $fresh){$fresh.Dispose()}}
         }
        }
       }
      }
     }catch{$failures++}
     $reporters.Add($record);$pendingMetadata.Add(@{record=$record;attempts=0;next_ms=0});Save-Observer
    }
   }catch{$failures++}finally{$process.Dispose();if(-not $keep -and $null -ne $watched){$watched.Dispose()}}
  }
  foreach($id in @($held.Keys)){
   $entry=$held[$id]
   try{
    if($entry.process.HasExited){
     $entry.event.completed=$true;$entry.event.completed_observation_ms=[long]$clock.ElapsedMilliseconds;$entry.event.exit_code_hex=$entry.process.ExitCode.ToString('x8')
     $entry.process.Dispose();$held.Remove($id)
    }
   }catch{$failures++}
  }
  foreach($pending in $pendingMetadata){
   if($pending.attempts -ge 4 -or $clock.ElapsedMilliseconds -lt $pending.next_ms){continue}
   if($pending.record.ContainsKey('live_fault_metadata') -and @($pending.record.live_fault_metadata.reports).Count -gt 0){continue}
   $pending.attempts++;$pending.record.live_metadata_attempts=$pending.attempts
   try{$pending.record.live_fault_metadata=Get-P11LiveFaultMetadata -Since $sinceUtc}catch{$failures++}
   $pending.next_ms=[long]$clock.ElapsedMilliseconds+500;Save-Observer
  }
  if($samples % 20 -eq 0){Save-Observer}
  Start-Sleep -Milliseconds 100
 }
}finally{
 try{Stop-P11ExceptionCapture $capture}catch{if($null -ne $capture){$capture.public.capture_cleanup_failed=$true;Add-P11CaptureCode $capture.public.dump_parser_failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_CLEANUP_FAILED'}}
 foreach($entry in $held.Values){$entry.process.Dispose()}
 Save-Observer
}
