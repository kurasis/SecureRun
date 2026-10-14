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
$vcRoot = $env:VCToolsInstallDir
$sdkRoot = $env:WindowsSdkDir
$sdkVersion = $env:WindowsSDKVersion.TrimEnd('\','/')
$builds = [System.Collections.Generic.List[object]]::new()
function Build-Native([string]$arch,[string]$source,[string]$name) {
    # Explicit compiler/library paths avoid reuse of a previous DevShell target.
    $compiler = Join-Path $vcRoot "bin/Host$native/$arch/cl.exe"
    if (-not (Test-Path $compiler)) { throw "Target compiler unavailable: $arch" }
    $env:LIB = @((Join-Path $vcRoot "lib/$arch"),(Join-Path $sdkRoot "Lib/$sdkVersion/ucrt/$arch"),(Join-Path $sdkRoot "Lib/$sdkVersion/um/$arch")) -join ';'
    Push-Location $out
    try {
        & $compiler /nologo /W4 /WX /wd4055 /wd4054 /O2 /DUNICODE /D_UNICODE (Join-Path $repo $source) "/Fe:$name" /link "/MACHINE:$($arch.ToUpperInvariant())"
        if ($LASTEXITCODE -ne 0) { throw "Fixed probe compilation failed: $arch" }
        $bytes = [IO.File]::ReadAllBytes((Join-Path $out $name))
        $pe = [BitConverter]::ToInt32($bytes,0x3c)
        $machine = [BitConverter]::ToUInt16($bytes,$pe+4)
        $expected = @{ x86 = 0x014c; x64 = 0x8664; arm64 = 0xaa64 }[$arch]
        if ($machine -ne $expected) { throw "Compiled PE architecture mismatch: $arch" }
        $builds.Add(@{ name = $name; declared_architecture = $arch; observed_pe_machine = ('{0:x4}' -f $machine); architecture_verified = $true; sha256 = (Get-FileHash (Join-Path $out $name)).Hash.ToLowerInvariant() })
    } finally { Pop-Location }
}
Push-Location $out
try {
    Build-Native $native 'tools/probe/engine_inspect.c' 'engine_inspect.exe'
} finally { Pop-Location }
foreach ($arch in @($native, 'x64', 'x86') | Select-Object -Unique) {
    Build-Native $arch 'tools/probe/feasibility_probe.c' "feasibility_probe_$arch.exe"
}
ConvertTo-Json -InputObject @($builds.ToArray()) -Depth 5 | Set-Content (Join-Path $out 'probe-builds.json') -Encoding utf8
