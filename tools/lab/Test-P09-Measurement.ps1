[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$source=(Resolve-Path -LiteralPath $Manager).Path
if(-not $source.StartsWith((Join-Path $repo 'target')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'P09_BUILD_IMAGE_REQUIRED'}
$code=Join-Path $env:ProgramFiles ('SecureRun-P09-measurement-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $code
$image=Join-Path $code 'securerun.exe';Copy-Item -LiteralPath $source -Destination $image
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/p09_desktop.cs')))
$out=Join-Path $repo 'artifacts/p09-build';$null=New-Item -ItemType Directory -Path $out -Force
$gui=$null
try{
 $gui=[P09Desktop]::new($image,(Join-Path $env:SystemRoot 'System32'),(Join-Path $out 'private-manager.log'),0)
 Start-Sleep -Seconds 10
 $metrics=$gui.MeasureIdle()
 if(-not $metrics.job_group_complete -or $metrics.duration_ms -lt 60000 -or $metrics.samples -lt 200 -or $metrics.webview_processes -lt 2){throw 'P09_MEASUREMENT_FIXTURE_FAILED'}
 @{schema=1;result='PASSED';native_measurement_fixture_only=$true;product_performance_gate_claimed=$false;reference_environments=0;metrics=$metrics}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $out 'measurement-fixture.json') -Encoding utf8
}finally{if($null -ne $gui){$gui.Dispose()}}
