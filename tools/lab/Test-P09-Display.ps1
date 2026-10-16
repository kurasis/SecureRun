[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path;$out=Join-Path $repo 'artifacts/p09-display';$null=New-Item -ItemType Directory -Path $out -Force
$prefix='Local\SecureRunP09Display-'+[Guid]::NewGuid().ToString('N');$events=@();$controller=$null
$report=@{schema=1;status='FAILED';fixture_only=$true;product_dpi_gate_claimed=$false;controller_completed=$false;controller_exit_code=$null;requests=@()}
try{
 $acl=[Security.AccessControl.EventWaitHandleSecurity]::new();$acl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.AccessControl.EventWaitHandleRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
 foreach($suffix in @('100','150','200','prepare','done','failed')){$created=$false;$events+=,[Threading.EventWaitHandleAcl]::Create($false,[Threading.EventResetMode]::AutoReset,$prefix+'-'+$suffix,[ref]$created,$acl);if(-not $created){throw 'P09_PREEXISTING_DISPLAY_EVENT'}}
 $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'));$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=Join-Path $env:SystemRoot 'System32'
 foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-STA','-File',(Join-Path $repo 'tools/probe/p09_accessibility.ps1'),'-Mode','DISPLAY_SERVER','-DisplayEvents',$prefix,'-ResultFile',(Join-Path $out 'controller'))){$start.ArgumentList.Add($arg)}
 $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','PATH','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','ProgramFiles','ProgramW6432')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['GITHUB_ACTIONS']='true'
 $controller=[Diagnostics.Process]::Start($start)
 if([Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$events[4..5],90000) -ne 0 -or $controller.HasExited){throw 'P09_DISPLAY_SERVER_NOT_READY'}
 $null=$events[3].Set();$report.initial_desktop_preparation_passed=([Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$events[4..5],90000) -eq 0);if(-not $report.initial_desktop_preparation_passed){throw 'P09_DISPLAY_INITIAL_PREPARATION_FAILED'}
 foreach($percent in @(100,150,200,100)){
  $index=@(100,150,200).IndexOf($percent);$null=$events[$index].Set();$response=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$events[4..5],90000)
  $report.requests+=@{requested_percent=$percent;controller_passed=($response -eq 0)}
  if($response -ne 0){throw 'P09_DISPLAY_FIXED_REQUEST_FAILED'}
 }
 $report.status='PASSED'
}catch{$message=$_.Exception.GetBaseException().Message;$report.code=if($message -cmatch '^P09_[A-Z0-9_]{1,100}$'){$message}else{'P09_DISPLAY_FIXTURE_FAILED'};$report.exception_type=$_.Exception.GetBaseException().GetType().FullName;$report.line=$_.InvocationInfo.ScriptLineNumber}
finally{
 if($null -ne $controller){$report.controller_completed=$controller.HasExited;if($controller.HasExited){$report.controller_exit_code=$controller.ExitCode}else{$controller.Kill($true);$null=$controller.WaitForExit(10000)};$controller.Dispose()}
 foreach($event in $events){$event.Dispose()}
 $report|ConvertTo-Json -Depth 6|Set-Content (Join-Path $out 'fixture.json') -Encoding UTF8
}
if($report.status -ne 'PASSED'){throw 'P09_DISPLAY_FIXTURE_FAILED'}
