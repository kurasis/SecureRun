param([string]$EngineHome,[string]$Fixture)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
$rejected = $false
try { $null = [P02Bridge]::new($EngineHome,$Fixture,[string[]]@()) }
catch { $rejected = $_.Exception.Message.Contains('MANAGER_CONTEXT_UNSAFE') }
@{ actual_managed_bridge = $true; boxed_context_rejected = $rejected; mutation_or_elevation_dispatched = $false } |
    ConvertTo-Json | Set-Content (Join-Path $Fixture 'results/managed-guard.json') -Encoding utf8
if ($rejected) { exit 43 }
exit 44
