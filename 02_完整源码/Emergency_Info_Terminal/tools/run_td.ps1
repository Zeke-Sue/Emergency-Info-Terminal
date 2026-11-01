param(
    [string]$TdHome='D:\Anlogic\TD_6.2.1_Engineer_6.2.168.116',
    [string]$Python='python',
    [string]$BuildRoot=(Join-Path (Split-Path $PSScriptRoot -Parent) 'build\td_runs'),
    [switch]$SynthesisOnly,
    [switch]$BitGen,
    [ValidateRange(0,2147483647)][int]$PlaceSeed=0,
    [ValidateSet('standard','routability')][string]$RoutingEffort='standard'
)
$ErrorActionPreference='Stop'
if($SynthesisOnly -and $BitGen){throw 'BitGen requires the physical-design run.'}
$projectRoot=Split-Path $PSScriptRoot -Parent
$stage=Join-Path $BuildRoot ('Emergency_Info_Terminal_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
$generateArgs=@((Join-Path $PSScriptRoot 'generate_td.py'),'--staging',$stage)
$generateArgs+=@('--route-effort',$RoutingEffort)
$generateArgs+=@('--place-seed',$PlaceSeed)
if($BitGen){$generateArgs+='--bitgen'}
& $Python @generateArgs
if($LASTEXITCODE -ne 0){throw 'TD project generation failed'}
$flow=(Join-Path $TdHome 'doc\scripts\DefaultFlow.tcl').Replace('\','/')
$exe=Join-Path $TdHome 'bin\td_commands_prompt.exe'
$runs=if($SynthesisOnly){@('syn_1')}else{@('syn_1','phy_1')}
foreach($run in $runs){
    $runDir=Join-Path $stage $run
    Push-Location $runDir
    try { & $exe $flow } finally {Pop-Location}
    $expected=if($run -eq 'syn_1'){'.opt_gate.end.f'}elseif($BitGen){'.bitgen.end.f'}else{'.opt_route.end.f'}
    if(-not(Test-Path -LiteralPath (Join-Path $runDir $expected)) -or
       (Get-ChildItem -LiteralPath $runDir -Filter '*.error.f' -Force)){
        throw "TD stage failed; inspect $runDir (exit code alone is not sufficient)."
    }
}
$reportDir=Join-Path $projectRoot ('build\td\'+(Split-Path $stage -Leaf))
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
Copy-Item -LiteralPath (Join-Path $stage 'source_sha256.json') -Destination $reportDir
foreach($run in $runs){
    $dest=Join-Path $reportDir $run
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $stage $run) -File |
        Where-Object {$_.Extension -in '.log','.logw','.rpt','.area','.timing','.sdc','.cfg','.ts','.status','.bit','.f'} |
        Copy-Item -Destination $dest
}
Write-Host "Offline TD stages finished. Check timing reports; completion is NOT timing closure. Build: $stage"
if($BitGen){Write-Host 'BitGen finished; no downloader or programming command was executed.'}
Write-Host "Reports copied to: $reportDir"
if(-not $SynthesisOnly){ & (Join-Path $PSScriptRoot 'check_td_result.ps1') -BuildPath $stage }
