param(
    [ValidatePattern('^(all|quick|full|v5|extensions|usability|tb_[a-zA-Z0-9_]+)$')][string]$Test='all',
    [string]$ModelSimBin='C:\modeltech64_10.4\win64',
    [string]$BuildRoot='D:\TD\emergency_modelsim',
    [string[]]$SimulationArgs=@(),
    [switch]$RecordWaves
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$tests=@(& (Join-Path $PSScriptRoot 'run_sim.ps1') -Test $Test -ListTests)
$stage=Join-Path $BuildRoot ((Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+$Test)
if(Test-Path -LiteralPath $stage){throw 'Simulation snapshot already exists.'}
New-Item -ItemType Directory -Path $stage | Out-Null
$sources=@()
foreach($sub in @('rtl','console/rtl','console/vendor','vendor/sd','sim')){
    $sources+=@(Get-ChildItem -LiteralPath (Join-Path $projectRoot $sub) -Filter '*.v' | ForEach-Object FullName)
}
$tracked=@($sources)
$sources+=Join-Path $projectRoot 'console/board/duty_console_top.v'
$sources+=Join-Path $projectRoot 'board/status_display.v'
$tracked+=@(Join-Path $PSScriptRoot 'run_modelsim.ps1'; Join-Path $PSScriptRoot 'run_sim.ps1')
foreach($sub in @('rtl','console/rtl','sim')){
    $tracked+=@(Get-ChildItem -LiteralPath (Join-Path $projectRoot $sub) -File |
        Where-Object {$_.Extension -in '.mem','.mif'} | ForEach-Object FullName)
}
foreach($sub in @('board','console/board','constraints','console/constraints')){
    $tracked+=@(Get-ChildItem -LiteralPath (Join-Path $projectRoot $sub) -File | ForEach-Object FullName)
}
$hashes=[ordered]@{}
foreach($path in $tracked){
    $relative=$path.Substring($projectRoot.Length+1).Replace('\','/')
    $destination=Join-Path $stage $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $path -Destination $destination
    $hashes[$relative]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$evidence=Join-Path $stage 'evidence'
$workdir=Join-Path $stage 'build/sim'
New-Item -ItemType Directory -Force -Path $evidence,$workdir | Out-Null
$hashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'source_sha256.json') -Encoding utf8
@{tests=$tests;simulator=$ModelSimBin;simulation_args=$SimulationArgs;
    defines=@('__ICARUS__');memory_backend='existing synchronous behavioral RAM/ROM (same as Icarus; not vendor timing simulation)';
    started=(Get-Date).ToString('o');source_project=$projectRoot} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $evidence 'run.json') -Encoding utf8
$stageSources=@($sources | ForEach-Object {Join-Path $stage $_.Substring($projectRoot.Length+1)})
$reference=Join-Path $stage 'sim/image_quality_engine_reference.v'
$referenceText=[IO.File]::ReadAllText($reference)
$needle='    wire accumulation_write=state==ST_IDLE && pixel_valid_d;'
if(($referenceText.Split(@($needle),[StringSplitOptions]::None).Count-1) -ne 1){
    throw 'Frozen reference compatibility transform did not match exactly once.'
}
$compat=Join-Path $evidence 'image_quality_engine_reference_compat.v'
$compatText=$referenceText.Replace('    reg [12:0] sample_quotient200;',
    "    reg [12:0] sample_quotient200;`n    wire accumulation_write;").Replace(
    $needle,'    assign accumulation_write=state==ST_IDLE && pixel_valid_d;')
[IO.File]::WriteAllText($compat,$compatText,[Text.UTF8Encoding]::new($false))
$stageSources=@($stageSources | ForEach-Object {if($_ -eq $reference){$compat}else{$_}})
@{original_sha256=(Get-FileHash -LiteralPath $reference).Hash;
    derived_sha256=(Get-FileHash -LiteralPath $compat).Hash;
    transform='declaration reorder only; original golden source preserved'} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'compatibility.json') -Encoding utf8
$completed=@()
Write-Output "ModelSim snapshot: $stage"
Push-Location $workdir
try {
    & (Join-Path $ModelSimBin 'vlib.exe') work *> (Join-Path $evidence 'vlib.log')
    if($LASTEXITCODE -ne 0){throw 'ModelSim library creation failed.'}
    & (Join-Path $ModelSimBin 'vmap.exe') -c *> (Join-Path $evidence 'vmap.log')
    if($LASTEXITCODE -ne 0){throw 'ModelSim ini creation failed.'}
    & (Join-Path $ModelSimBin 'vmap.exe') work (Join-Path $workdir 'work') *>> (Join-Path $evidence 'vmap.log')
    if($LASTEXITCODE -ne 0){throw 'ModelSim library mapping failed.'}
    $ErrorActionPreference='Continue'
    $sourceList=Join-Path $evidence 'sources.f'
    $stageSources | ForEach-Object {'"'+$_.Replace('\','/')+'"'} |
        Set-Content -LiteralPath $sourceList -Encoding ascii
    & (Join-Path $ModelSimBin 'vlog.exe') -quiet '+define+__ICARUS__' -work work -f $sourceList *> (Join-Path $evidence 'compile.log')
    $compileExit=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    if($compileExit -ne 0){throw 'ModelSim compilation failed.'}
    if($RecordWaves){New-Item -ItemType Directory -Force -Path (Join-Path $evidence 'waveforms') | Out-Null}
    foreach($top in $tests){
        $log=Join-Path $evidence "$top.log"
        $ErrorActionPreference='Continue'
        $waveArgs=@()
        $runCommands='run -all; quit -f'
        if($RecordWaves){
            $waveArgs=@('-voptargs=+acc','-wlf',(Join-Path $evidence ('waveforms/'+$top+'.wlf')))
            $runCommands='log -r /*; run -all; quit -f'
        }
        & (Join-Path $ModelSimBin 'vsim.exe') -c -t 1ps -onfinish stop -lib work $top @SimulationArgs @waveArgs -do $runCommands *> $log
        $simExit=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($simExit -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'TEST_PASS' -Quiet) -or
            (Select-String -LiteralPath $log -Pattern 'TEST_FAIL|FATAL|^# \*\* Error' -Quiet)){
            throw "ModelSim self-check failed: $top"
        }
        $completed+=$top
        @{completed=$completed;updated=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $evidence 'progress.json') -Encoding utf8
        Write-Output "PASS $top ($($completed.Count)/$($tests.Count))"
    }
    foreach($entry in $hashes.GetEnumerator()){
        if((Get-FileHash -LiteralPath (Join-Path $stage $entry.Key) -Algorithm SHA256).Hash -ne $entry.Value){
            throw "Simulation snapshot changed: $($entry.Key)"
        }
        if((Get-FileHash -LiteralPath (Join-Path $projectRoot $entry.Key) -Algorithm SHA256).Hash -ne $entry.Value){
            throw "Project changed during verification: $($entry.Key)"
        }
    }
    @{result='PASS';completed=$completed;source_files=$hashes.Count;finished=(Get-Date).ToString('o')} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'result.json') -Encoding utf8
    Write-Output "All $($completed.Count) ModelSim tests passed, frozen source SHA256 unchanged. Evidence: $evidence"
} catch {
    @{result='FAIL';completed=$completed;error=$_.ToString();finished=(Get-Date).ToString('o')} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'result.json') -Encoding utf8
    throw
} finally {Pop-Location}
