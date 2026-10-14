[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo 'artifacts/p02'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'MSVC tools missing.' }
Import-Module (Join-Path $vs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
$native = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=$native -host_arch=$native" | Out-Null
Push-Location $out
try {
    & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/engine_inspect.c') /Fe:engine_inspect.exe
    if ($LASTEXITCODE -ne 0) { throw 'Native inspector compilation failed.' }
} finally { Pop-Location }
foreach ($arch in @($native, 'x64', 'x86') | Select-Object -Unique) {
    Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=$arch -host_arch=$native" | Out-Null
    Push-Location $out
    try {
        & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/feasibility_probe.c') "/Fe:feasibility_probe_$arch.exe"
        if ($LASTEXITCODE -ne 0) { throw "Fixed probe compilation failed: $arch" }
    } finally { Pop-Location }
}
