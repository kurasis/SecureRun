# Disposable lab administration only; not a product command or privileged helper.
param([string]$EngineHome,[string]$Fixture)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
$bridge=[P02Bridge]::new($EngineHome,$Fixture,[string[]]@());$bridge.EnableLabWfp()
# Exit closes the original SDK's device handles before the later unload test.
