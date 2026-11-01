param(
    [Parameter(Mandatory=$true)][string]$BuildPath,
    [ValidatePattern('^phy_[A-Za-z0-9_]+$')][string]$PhysicalRun='phy_1',
    [switch]$CheckCurrentSources
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$physicalPath=Join-Path $BuildPath $PhysicalRun
if(-not(Test-Path -LiteralPath (Join-Path $physicalPath '.opt_route.end.f')) -or
        (Get-ChildItem -LiteralPath $physicalPath -Filter '*.error.f' -Force)){
    throw "Physical implementation did not complete cleanly: $physicalPath"
}
$statusPath=Join-Path $physicalPath 'route_flow.status'
if(-not(Test-Path -LiteralPath $statusPath)){throw "Missing final routed status: $statusPath"}
$statusText=Get-Content -LiteralPath $statusPath -Raw
if($statusText -notmatch 'Timing Mode\s*:\s*final'){throw 'Timing report is not final.'}
foreach($kind in @('Setup','Hold')){
    $pattern=$kind+'\s*:\s*WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps\s+NUM_FEPS\s+(\d+)'
    if($statusText -notmatch $pattern){throw "Missing $kind timing metrics."}
    $slack=[long]$Matches[1]
    $total=[long]$Matches[2]
    $endpoints=[long]$Matches[3]
    if($slack -lt 0 -or $total -lt 0 -or $endpoints -ne 0){
        throw "$kind timing failed: WNS ${slack}ps, TNS ${total}ps, endpoints $endpoints."
    }
    Write-Host "$kind PASS: WNS ${slack}ps, endpoints $endpoints"
}
if($CheckCurrentSources){
    $manifest=Get-Content -LiteralPath (Join-Path $BuildPath 'source_sha256.json') -Raw | ConvertFrom-Json
    $checked=0
    foreach($entry in $manifest.PSObject.Properties){
        $relative=$entry.Name
        if($relative.StartsWith('shared/')){$relative='rtl/'+$relative.Substring(7)}
        $source=Join-Path $projectRoot $relative
        if(-not(Test-Path -LiteralPath $source)){throw "Source no longer exists: $source"}
        $actual=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if($actual -ne $entry.Value){throw "Build is stale: $($entry.Name)"}
        $checked++
    }
    Write-Host "Source SHA256 PASS: $checked files"
}
Write-Host "Final routed timing accepted: $BuildPath"
