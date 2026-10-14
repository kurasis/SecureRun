[CmdletBinding()]
param([Parameter(Mandatory)][string]$RootCanary,[Parameter(Mandatory)][string]$MetadataCanary,[Parameter(Mandatory)][string]$ResultFile)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity)
$result=@{standard_user=(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator));root_denied=$false;metadata_denied=$false}
foreach($entry in @(@{path=$RootCanary;key='root_denied'},@{path=$MetadataCanary;key='metadata_denied'})){
    try{$handle=[IO.File]::OpenRead($entry.path);$handle.Dispose()}catch [UnauthorizedAccessException]{$result[$entry.key]=$true}
}
$result|ConvertTo-Json|Set-Content $ResultFile -Encoding utf8
if(-not($result.standard_user -and $result.root_denied -and $result.metadata_denied)){exit 1}
