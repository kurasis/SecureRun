[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager,[Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$Stage,[Parameter(Mandatory)][string]$EngineHome)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';stage=$Stage;standard_user=$false;real_process_interruption=$false;automatic_replay=$false}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity)
    Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED';$result.standard_user=$true
    $env:SECURERUN_P05_PAUSE_STAGE=$Stage
    $request=@{action='CREATE';display_name='Interrupted synthetic provision';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}}
    $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=$EngineHome;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.ArgumentList.Add('--policy-worker');$start.ArgumentList.Add([string]$PID);$start.ArgumentList.Add([string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))
    $process=[Diagnostics.Process]::Start($start)
    try {
        $line=$process.StandardOutput.ReadLineAsync();$process.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 8 -Compress));$process.StandardInput.Close()
        Require ($line.Wait(45000) -and $line.Result -eq "CHECKPOINT_$Stage") 'JOURNAL_CHECKPOINT_NOT_REACHED'
        $process.Kill($true);Require ($process.WaitForExit(10000)) 'INTERRUPTED_PROCESS_STILL_RUNNING';$result.real_process_interruption=$true
    }finally{if(-not $process.HasExited){$process.Kill($true)};$process.Dispose()}
    Remove-Item Env:/SECURERUN_P05_PAUSE_STAGE
    @{checkpoint_reached=$true}|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/fault-ready.json') -Encoding utf8
    $clock=[Diagnostics.Stopwatch]::StartNew();while(-not(Test-Path (Join-Path $Fixture 'results/normal-restored.json')) -and $clock.ElapsedMilliseconds -lt 60000){Start-Sleep -Milliseconds 100}
    Require (Test-Path (Join-Path $Fixture 'results/normal-restored.json')) 'NORMAL_BINARY_RESTORE_NOT_CONFIRMED'
    $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=$EngineHome;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.ArgumentList.Add('--policy-once')
    $process=[Diagnostics.Process]::Start($start)
    try{$read=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync();$process.StandardInput.Write('{"action":"LIST"}');$process.StandardInput.Close();Require ($process.WaitForExit(45000)) 'RECOVERY_TIMEOUT';$r=$read.Result|ConvertFrom-Json;Require ($r.reason -eq 'OBSERVED' -and $r.environments.Count -eq 1) 'RECOVERY_NOT_OBSERVED';$e=$r.environments[0];Require ($e.stage -eq 'CONFLICT' -and $null -eq $e.fingerprint -and $null -eq $e.enforcement_evidence -and -not $e.production_launch_available) 'PARTIAL_OPERATION_REPLAYED';$result.conflict_after_restart=$true;$result.launch_blocked=$true;$result.status='PASSED'}finally{if(-not $process.HasExited){$process.Kill($true)};$process.Dispose()}
}catch{$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'JOURNAL_INTERRUPTION_FAILED'}}
$result|ConvertTo-Json -Depth 8|Set-Content (Join-Path $Fixture 'results/fault-result.json') -Encoding utf8
if($result.status -ne 'PASSED'){exit 1}
