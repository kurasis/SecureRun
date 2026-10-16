[CmdletBinding()]
param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try{
 # npm can silently omit an optional native package after a failed download.
 # Repeat only the exact locked, script-free installation; never regenerate pins.
 for($attempt=0;$attempt -lt 2;$attempt++){
  npm ci --ignore-scripts --include=optional
  if($LASTEXITCODE -ne 0){throw 'P09_NODE_DEPENDENCIES_FAILED'}
  node --eval 'if(process.platform!=="win32")process.exit(0);try{require.resolve("@rolldown/binding-win32-"+process.arch+"-msvc");require.resolve("@tauri-apps/cli-win32-"+process.arch+"-msvc")}catch{process.exit(1)}'
  if($LASTEXITCODE -eq 0){return}
  Write-Host 'P09_LOCKED_NATIVE_DEPENDENCY_INCOMPLETE'
 }
 throw 'P09_LOCKED_NATIVE_DEPENDENCY_MISSING'
}finally{Pop-Location}
