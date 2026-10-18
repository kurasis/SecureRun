param([switch]$Native,[string]$PrivateDirectory)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Control-P11OriginalServiceLog.ps1')
function Require([bool]$Value){if(-not $Value){throw 'P11_SERVICE_LOG_TEST_FAILED'}}
$untrustedShape=[P11OriginalLog]::new();$untrustedShape.ParseLine([P11OriginalLog]::Marker);Require (-not $untrustedShape.calibration_confirmed)
$reader=[P11OriginalLog]::new();$reader.ParseLine('SBIE2301 '+[P11OriginalLog]::Marker)
$reader.ParseLine('SBIE2203 RPCSS_SXS - (Sandboxie RpcSs) [02/C0000022] C:\PRIVATE_CANARY\owner 98765')
$reader.ParseLine('SBIE2301 C:\PRIVATE_CANARY\secret')
$public=@{calibration=$reader.calibration_confirmed;messages=$reader.message_counts;sxs=@($reader.sxs_statuses.ToArray())}
Require ($reader.calibration_confirmed -and $reader.message_counts['SBIE2203'] -eq 1 -and $reader.message_counts['SBIE2301'] -eq 1 -and $reader.sxs_statuses[0]['status_hex'] -ceq 'c0000022')
Require (($public|ConvertTo-Json -Depth 8) -notmatch 'PRIVATE_CANARY|98765|P11_SYNTHETIC')
$privateTestFile=Join-Path ([IO.Path]::GetTempPath()) ('p11-service-log-'+[Guid]::NewGuid().ToString('N'))
try{
 [IO.File]::WriteAllText($privateTestFile,'SBIE2203 RPCSS_SXS - (Sandboxie RpcSs) [03/C0000005]',[Text.Encoding]::Unicode)
 $reader=[P11OriginalLog]::new();$reader.ReadAppend($privateTestFile);Require ($reader.message_counts.Count -eq 0)
 [IO.File]::AppendAllText($privateTestFile,"`r`n",[Text.Encoding]::Unicode);$reader.ReadAppend($privateTestFile)
 Require ($reader.message_counts['SBIE2203'] -eq 1 -and $reader.sxs_statuses[0]['status_hex'] -ceq 'c0000005')
 $reader.ReadAppend($privateTestFile);Require ($reader.message_counts['SBIE2203'] -eq 1)
}finally{Remove-Item -LiteralPath $privateTestFile -Force}
Write-Host 'PASS: source-shaped service-log codes, private-string suppression and incremental UTF16 reads'
$reader=[P11OriginalLog]::new([string[]]@('CreateProcessInternalW','NtOpenFile'))
$reader.ParseLine('SBIE2329 Failed to find FFS sequence CreateProcessInternalW (1)')
$reader.ParseLine('SBIE2329 Failed to find FFS sequence PRIVATE_CANARY (1)')
$reader.ParseLine('SBIE2224 Sandboxed program has crashed: SandboxieRpcSs.exe (0xC0000005) [PRIVATE_CANARY]')
$reader.ParseLine('SBIE2224 Sandboxed program has crashed: SandboxieRpcSs.exe [PRIVATE_CANARY]')
$reader.ParseLine('SBIE2204 Cannot start sandboxed service DcomLaunch (-4)')
$reader.ParseLine('SBIE2204 Cannot start sandboxed service RpcSs (C0000005)')
$public=@{hooks=$reader.ffs_function_counts;crashes=$reader.crash_report_counts;starts=$reader.startup_report_counts}
Require ($reader.ffs_function_counts['CreateProcessInternalW'] -eq 1 -and $reader.ffs_function_counts['WITHHELD'] -eq 1 -and $reader.crash_report_counts['SandboxieRpcSs.exe/c0000005'] -eq 1 -and $reader.crash_report_counts['SandboxieRpcSs.exe/UNAVAILABLE'] -eq 1 -and $reader.startup_report_counts['DcomLaunch/-4'] -eq 1 -and $reader.startup_report_counts['RpcSs/c0000005'] -eq 1)
Require (($public|ConvertTo-Json -Depth 8) -notmatch 'PRIVATE_CANARY')
Write-Host 'PASS: public allowlisted hook symbols, fixed crash kinds and publisher status tokens; no cause/radix guess'
if($Native){
 $repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
 $context=New-P11OriginalServiceLog $PrivateDirectory $repo
 try{Update-P11OriginalServiceLog $context}finally{Stop-P11OriginalServiceLog $context}
 $result=Get-P11OriginalServiceLogReport $context
 $out=Join-Path $repo 'artifacts/p11-diagnostics';$null=New-Item -ItemType Directory -Path $out -Force
 $result|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'original-service-log-preflight.json') -Encoding utf8
 Require (-not $result.failed -and $result.input_pins_ready -and $result.calibration_confirmed_before_actor -and $result.previous_registry_value_restored -and -not $result.bound_reached)
 Write-Host 'PASS: actual authenticated original service log write/read/calibration and registry restoration; no engine containment proof'
}
