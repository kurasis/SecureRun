param([Parameter(Mandatory)][string]$ResultFile,[Parameter(Mandatory)][string]$StopFile,[Parameter(Mandatory)][string]$ControlScript,[Parameter(Mandatory)][string]$PrivateDirectory,[Parameter(Mandatory)][string]$Repo)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
# Start-Job transports script text without PSScriptRoot; caller supplies support.
. $ControlScript
$context=New-P11OriginalServiceLog $PrivateDirectory $Repo
try{
 Get-P11OriginalServiceLogReport $context|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultFile -Encoding utf8
 while(-not(Test-Path -LiteralPath $StopFile)){
  Update-P11OriginalServiceLog $context
  Get-P11OriginalServiceLogReport $context|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultFile -Encoding utf8
  Start-Sleep -Milliseconds 250
 }
}finally{
 Stop-P11OriginalServiceLog $context
 Get-P11OriginalServiceLogReport $context|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultFile -Encoding utf8
}
