[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $repo 'artifacts/p05-build';$null=New-Item -ItemType Directory -Path $out -Force
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if($LASTEXITCODE -ne 0 -or -not $vs){throw 'MSVC_TOOLS_REQUIRED'}
Import-Module (Join-Path $vs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'arm64'}else{'x64'}
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=$arch -host_arch=$arch"|Out-Null
Push-Location $out
try{
    & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /MT /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/p05_view_probe.c') '/Fe:p05-view-probe.exe'
    if($LASTEXITCODE -ne 0){throw 'VIEW_FIXTURE_BUILD_FAILED'}
    & cl.exe /nologo /W4 /WX /wd4055 /wd4054 /O2 /MT /DUNICODE /D_UNICODE (Join-Path $repo 'tools/probe/p05_session_probe.c') '/Fe:p05-session-probe.exe'
    if($LASTEXITCODE -ne 0){throw 'SESSION_FIXTURE_BUILD_FAILED'}
}finally{Pop-Location}
