# Source-backed service LogFile setting, not a GetMessage/signed-leader bypass.
. (Join-Path $PSScriptRoot 'Read-P11OriginalServiceLog.ps1')
. (Join-Path $PSScriptRoot 'Invoke-P11ExceptionCapture.ps1')
if(-not('P11OriginalLogPublisher' -as [type])){Add-Type @'
using System;using System.Runtime.InteropServices;
public sealed class P11OriginalLogPublisher {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr LoadLibraryExW(string name,IntPtr reserved,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)]static extern IntPtr GetProcAddress(IntPtr module,string name);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)]delegate int Log(uint session,uint code,string data,ushort bytes);
 readonly Log write;
 public P11OriginalLogPublisher(string pinnedDll){IntPtr module=LoadLibraryExW(pinnedDll,IntPtr.Zero,0x100|0x800);if(module==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_LOG_LIBRARY_UNAVAILABLE");IntPtr entry=GetProcAddress(module,"SbieApi_LogMsgEx");if(entry==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_LOG_EXPORT_UNAVAILABLE");write=Marshal.GetDelegateForFunctionPointer<Log>(entry);}
 public int Calibrate(uint session){string marker="P11_SYNTHETIC_DIAGNOSTIC_LOG_CALIBRATION";string payload=marker+"\0\0";return write(session,2301,payload,checked((ushort)(payload.Length*2)));}
}
'@}
function New-P11OriginalServiceLog([string]$PrivateDirectory,[string]$Repo){
 if($env:GITHUB_ACTIONS -ne 'true' -or $env:PROCESSOR_ARCHITECTURE -ne 'ARM64'){throw 'DISPOSABLE_ARM_ACTIONS_VM_REQUIRED'}
 if($PrivateDirectory -ine (Join-Path $env:ProgramFiles ('SecureRun-P11-ServiceLog-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT))){throw 'DIAGNOSTIC_LOG_HOME_INVALID'}
 $release=Get-Content (Join-Path $Repo 'docs/engine-candidate.json') -Raw|ConvertFrom-Json
 $symbols=Get-Content (Join-Path $Repo 'tools/lab/p11-public-hook-symbols.json') -Raw|ConvertFrom-Json
 if($symbols.source_commit -cne $release.source_commit){throw 'DIAGNOSTIC_LOG_SYMBOL_SOURCE_MISMATCH'}
 $pin=$release.lab_installer
 $compat=Get-Content (Join-Path $Repo 'crates/sandboxie-adapter/compatibility-v1.json') -Raw|ConvertFrom-Json
 $target=@($compat.targets|Where-Object architecture -CEQ 'aarch64')[0]
 return @{repo=$Repo;home=$PrivateDirectory;pin=$pin;components=$target.components;key=$null;prior_present=$false;prior_value=$null;prior_kind=$null;our_value=$null;configured=$false;ready=$false;failed=$false;stopped=$false;leases=[Collections.Generic.List[object]]::new();reader=[P11OriginalLog]::new([string[]]$symbols.symbols);log=(Join-Path $PrivateDirectory 'original-engine.log');public=@{classification='ORIGINAL_SERVICE_LOG_DIAGNOSTIC_ONLY_NO_PHASE_GATE';observer_debugger_attachment_requested=$false;observer_engine_memory_dump_requested=$false;windows_security_wer_or_containment_policy_modified=$false;original_service_log_registry_temporarily_configured=$false;previous_registry_value_restored=$false;raw_log_upload_allowed=$false;raw_paths_ids_arguments_messages_and_times_retained=$false;message_names_do_not_authenticate_targets=$true;calibration_confirmed_before_actor=$false;input_pins_ready=$false;collection_failures=0;failure_codes=@{}}}
}
function Update-P11OriginalServiceLog($Context){
 if($Context.failed){return}
 try{
  if(-not $Context.ready){
   if(-not(Test-Path -LiteralPath (Join-Path $Context.repo 'artifacts/p02/installation.json'))){return}
   if(@(Get-LocalUser|Where-Object Name -CMatch '^SRP09_[0-9a-f]{10}$').Count -gt 0){throw 'DIAGNOSTIC_LOG_PREPARATION_AFTER_ACTOR_REFUSED'}
   $installer=Join-Path $Context.repo ('artifacts/p02/'+$Context.pin.name);$lease=Open-P11PinnedFile $installer;$Context.leases.Add($lease)
   if($lease.Length -ne $Context.pin.size -or (Get-P11StreamHash $lease) -cne $Context.pin.sha256 -or (Get-AuthenticodeSignature $installer).Status -ne 'Valid'){throw 'DIAGNOSTIC_LOG_INSTALLER_PIN_FAILED'}
   foreach($name in @('SbieSvc.exe','SbieDll.dll')){
    $installed=Join-Path $env:ProgramFiles ('Sandboxie-Plus/'+$name);$reference=Join-Path $Context.repo ('artifacts/p02/authenticated-payload/'+$name)
    $original=Open-P11PinnedFile $reference;$Context.leases.Add($original);$held=Open-P11PinnedFile $installed;$Context.leases.Add($held)
    $expected=(@($Context.components|Where-Object name -CEQ $name)[0]).sha256
    if((Get-P11StreamHash $held) -cne $expected -or (Get-P11StreamHash $original) -cne $expected -or (Get-AuthenticodeSignature $installed).Status -ne 'Valid'){throw 'DIAGNOSTIC_LOG_COMPONENT_PIN_FAILED'}
   }
   if(@(Get-LocalUser|Where-Object Name -CMatch '^SRP09_[0-9a-f]{10}$').Count -gt 0){throw 'DIAGNOSTIC_LOG_PREPARATION_AFTER_ACTOR_REFUSED'}
   $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
   try{$Context.key=$base.OpenSubKey('SYSTEM\CurrentControlSet\Services\SbieSvc',$true)}finally{$base.Dispose()}
   if($null -eq $Context.key){throw 'DIAGNOSTIC_LOG_ORIGINAL_SERVICE_KEY_MISSING'}
   $Context.prior_present=$Context.key.GetValueNames() -contains 'LogFile'
   if($Context.prior_present){$Context.prior_kind=$Context.key.GetValueKind('LogFile');$Context.prior_value=$Context.key.GetValue('LogFile',$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
   if(Test-Path -LiteralPath $Context.log){throw 'DIAGNOSTIC_LOG_PREEXISTING_OUTPUT_REFUSED'}
   $Context.our_value='1;'+$Context.log;$Context.key.SetValue('LogFile',$Context.our_value,[Microsoft.Win32.RegistryValueKind]::String);$Context.configured=$true;$Context.public.original_service_log_registry_temporarily_configured=$true
   $publisher=[P11OriginalLogPublisher]::new((Join-Path $env:ProgramFiles 'Sandboxie-Plus/SbieDll.dll'))
   $status=$publisher.Calibrate([uint32][Diagnostics.Process]::GetCurrentProcess().SessionId)
   if($status -ne 0){$Context.public.calibration_status_hex=([uint32]($status -band 0xffffffffL)).ToString('x8');throw 'DIAGNOSTIC_LOG_CALIBRATION_SEND_FAILED'}
   $clock=[Diagnostics.Stopwatch]::StartNew()
   do{if(Test-Path -LiteralPath $Context.log){$Context.reader.ReadAppend($Context.log)};if($Context.reader.calibration_confirmed){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 10000)
   if(-not $Context.reader.calibration_confirmed){throw 'DIAGNOSTIC_LOG_CALIBRATION_OUTPUT_MISSING'}
   if(@(Get-LocalUser|Where-Object Name -CMatch '^SRP09_[0-9a-f]{10}$').Count -gt 0){throw 'DIAGNOSTIC_LOG_CALIBRATION_AFTER_ACTOR_REFUSED'}
   $Context.ready=$true;$Context.public.calibration_confirmed_before_actor=$true;$Context.public.input_pins_ready=$true
  }
  if(Test-Path -LiteralPath $Context.log){$Context.reader.ReadAppend($Context.log)}
  if($Context.reader.bound_reached){throw 'DIAGNOSTIC_LOG_READ_BOUND_REACHED'}
 }catch{$Context.failed=$true;$Context.public.collection_failures++;Add-P11CaptureCode $Context.public.failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_LOG_READ_FAILED';Stop-P11OriginalServiceLog $Context}
}
function Stop-P11OriginalServiceLog($Context){
 if($Context.stopped){return};$Context.stopped=$true
 try{
  if($Context.configured){
   if($Context.key.GetValueKind('LogFile') -ne [Microsoft.Win32.RegistryValueKind]::String -or $Context.key.GetValue('LogFile') -cne $Context.our_value){throw 'DIAGNOSTIC_LOG_CONCURRENT_REGISTRY_CHANGE_REFUSED'}
   if($Context.prior_present){$Context.key.SetValue('LogFile',$Context.prior_value,$Context.prior_kind)}else{$Context.key.DeleteValue('LogFile',$true)}
   $Context.public.previous_registry_value_restored=$true
  }
  if(Test-Path -LiteralPath $Context.log){for($n=0;$n -lt 128;$n++){ $previous=$Context.reader.bytes_read;$Context.reader.ReadAppend($Context.log);if($Context.reader.bytes_read -eq $previous -or $Context.reader.bound_reached){break}}}
 }catch{$Context.failed=$true;$Context.public.collection_failures++;Add-P11CaptureCode $Context.public.failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_LOG_RESTORE_FAILED'}finally{if($null -ne $Context.key){$Context.key.Dispose()};foreach($lease in $Context.leases){$lease.Dispose()}}
}
function Get-P11OriginalServiceLogReport($Context){
 $report=@{};foreach($key in $Context.public.Keys){$report[$key]=$Context.public[$key]}
 $report.failed=$Context.failed;$report.calibration_confirmed=$Context.reader.calibration_confirmed;$report.bytes_read=$Context.reader.bytes_read;$report.bound_reached=$Context.reader.bound_reached;$report.overlong_lines=$Context.reader.overlong_lines;$report.message_counts=$Context.reader.message_counts;$report.ffs_function_counts=$Context.reader.ffs_function_counts;$report.crash_report_counts=$Context.reader.crash_report_counts;$report.startup_report_counts=$Context.reader.startup_report_counts;$report.startup_code_radix_not_guessed=$true;$report.message_fields_are_not_exception_or_root_cause_proof=$true;$report.sxs_statuses=@($Context.reader.sxs_statuses.ToArray())
 return $report
}
