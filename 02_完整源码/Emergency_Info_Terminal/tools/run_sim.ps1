param(
    [ValidatePattern('^(all|quick|full|v5|extensions|usability|tb_[a-zA-Z0-9_]+)$')]
    [string]$Test='all',
    [string]$IcarusBin='C:\iverilog\bin',
    [string[]]$SimulationArgs=@(),
    [string]$ResumeFrom='',
    [switch]$ListTests
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$outDir=Join-Path $projectRoot 'build\sim'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$tests=switch($Test) {
    'usability' {@('tb_slideshow_lookahead','tb_filming_cadence','tb_filming_profile','tb_fire_control_composition','tb_clean_presentation','tb_usability_periods','tb_daily_control','tb_status_display','tb_route_guidance','tb_wav_window','tb_audio_health','tb_health_overlay','tb_usability_map','tb_fixed_catalog_full32','tb_fixed_catalog_human','tb_fat32_root_catalog','tb_human_stage_audio','tb_single_card_streamer','tb_human_daily_follow','tb_live_route','tb_live_route_overlay','tb_remote_ui','tb_pcm_context','tb_page_tones','tb_extension_system','tb_route_console_keys','tb_extension_subtitle_scanout','tb_daily_subtitle_scroll','tb_scaler_wide','tb_scaler_downsample','tb_fit_geometry','tb_bmp_header_predicates','tb_spectrum_uart','tb_stft_512_fft','tb_event_authority_roles_link','tb_extension_manual_real','tb_route_media_pipeline')}
    'extensions' {@('tb_pcm_context','tb_remote_ui','tb_live_route','tb_live_route_overlay','tb_page_tones','tb_extension_system','tb_route_console_keys','tb_extension_subtitle_scanout','tb_daily_subtitle_scroll','tb_scaler_wide','tb_scaler_downsample','tb_fit_geometry','tb_bmp_header_predicates','tb_spectrum_uart','tb_stft_512_fft','tb_event_authority_roles_link','tb_extension_manual_real')} 
    'all' {@('tb_quality_manual_profile','tb_packed_frame_store','tb_source_line_ram','tb_stft_512_fft','tb_daily_control','tb_image_cache_16','tb_shared_keys','tb_fat_geometry','tb_fat32_root_catalog','tb_config_route_stream','tb_route_config_cdc','tb_config_fat_integration','tb_scaler','tb_scaler_wide','tb_scaler_downsample','tb_sd_reset','tb_audio','tb_p2_datapath','tb_p2_overlay','tb_quality_engine','tb_stft_512','tb_waterfall_buffer','tb_narration_timeline','tb_narration_audio_guard','tb_narration_wav_streamer','tb_p3_event_manager','tb_uart_protocol','tb_p3_uart_link','tb_p3_reply_queue','tb_console_status_proxy','tb_voice_segments','tb_l0_voice','tb_p3_integration','tb_terminal_uart_integration','tb_duty_console','tb_console_video','tb_console_log_journal','tb_console_event_log','tb_spi_nor_log_transport','tb_two_board_link','tb_n10_route','tb_n10_prototype_integration','tb_v41_resync_log','tb_v41_serial_resync','tb_v41_telemetry','tb_wav_admission','tb_wav_stream_parser','tb_media_player','tb_zoom_reload','tb_cache_stress','tb_full_resolution')}
    'quick' {@('tb_packed_frame_store','tb_source_line_ram','tb_stft_512_fft','tb_daily_control','tb_image_cache_16','tb_shared_keys','tb_fat_geometry','tb_fat32_root_catalog','tb_config_route_stream','tb_route_config_cdc','tb_config_fat_integration','tb_scaler','tb_scaler_wide','tb_scaler_downsample','tb_sd_reset','tb_audio','tb_p2_datapath','tb_p2_overlay','tb_quality_engine','tb_waterfall_buffer','tb_narration_timeline','tb_narration_audio_guard','tb_narration_wav_streamer','tb_p3_event_manager','tb_uart_protocol','tb_p3_uart_link','tb_p3_reply_queue','tb_console_status_proxy','tb_voice_segments','tb_l0_voice','tb_p3_integration','tb_terminal_uart_integration','tb_duty_console','tb_console_video','tb_console_log_journal','tb_console_event_log','tb_spi_nor_log_transport','tb_two_board_link','tb_n10_route','tb_n10_prototype_integration','tb_v41_resync_log','tb_v41_serial_resync','tb_v41_telemetry','tb_wav_admission','tb_wav_stream_parser','tb_media_player','tb_zoom_reload','tb_cache_stress')}
    'full' {@('tb_full_resolution')}
    'v5' {@('tb_operator_confirmation','tb_v5_console_confirmation','tb_confirmation_overlay',
        'tb_fat_chain_preflight','tb_fat_strict_reader','tb_console_strict_chain',
        'tb_v5_console_control','tb_duty_console','tb_console_status_proxy',
        'tb_fat_geometry','tb_fat_file_recovery','tb_fat_sorted_catalog','tb_config_fat_integration',
        'tb_local_fire_control','tb_v5_media_safety','tb_v5_daily_control',
        'tb_voice_exact','tb_voice_context','tb_source_fades','tb_site_notice_tone',
        'tb_event_permissions','tb_event_authority_roles_link','tb_v5_route_stage','tb_media_strict_chain')}
    default {@($Test)}
}
if($Test -in @('all','quick','usability','extensions')){
    $tests=@('tb_scaler_fractional','tb_scaler_portrait_down','tb_scaler_five_four','tb_scaler_three_two','tb_scaler','tb_bad_image_skip')+$tests
    $tests=@($tests | Select-Object -Unique)
}
if($Test -eq 'usability'){
    $tests=@('tb_simple_media_controls','tb_controls','tb_image_cache_16','tb_viewport_transition_pin')+$tests
    $tests=@($tests | Select-Object -Unique)
}
if($Test -in @('all','quick')){
    $tests=@('tb_daily_broadcast_media','tb_viewport_transition_pin')+$tests
    $tests=@('tb_simple_media_controls','tb_simple_alarm_scanout','tb_simple_console_keys','tb_panel_test_control','tb_explicit_test_release','tb_alarm_disaster_ticker','tb_windows_fixed_catalog','tb_drill_republish','tb_proxy_glyph_bounds',
        'tb_preloaded_pan_scanout','tb_fast_viewport_cache','tb_preloaded_scanout_pixels',
        'tb_test_tone_40k','tb_waveform_capture','tb_console_acceptance_keys','tb_waveform_ui','tb_alarm_waveform_scanout',
        'tb_diagnostic_media_integration')+$tests
    $tests=@('tb_single_card_streamer','tb_single_card_serial','tb_single_card_console','tb_single_card_media')+$tests
    $tests=@('tb_mixer_pipeline')+$tests
    $tests=@('tb_bmp_header_predicates','tb_human_daily_follow')+$tests
    $tests=@('tb_subtitle_packed','tb_human_stage_audio','tb_fixed_catalog_human','tb_human_catalog_mount',
        'tb_human_media_pipeline','tb_alarm_subtitle_scanout','tb_narration_shared_metadata','tb_v41_serial_resync15','tb_compact_video_effects')+$tests
    $tests=@('tb_bypass_config','tb_media_board_route_profile')+$tests
    $tests=@('tb_audio_output_flags','tb_demo_sprites_compact','tb_wav_canonical','tb_narration_canonical','tb_quality_frame_parameters')+$tests
    $tests=@('tb_status_text_equivalence','tb_fat_address_bound','tb_fixed_catalog_nohash')+$tests
    $tests=@('tb_fat_sorted_catalog_compact','tb_catalog_name_limit','tb_sprite_blend_equivalence',
        'tb_fixed_catalog','tb_packed_nibble_rom','tb_wav_pcm_profile','tb_wav_pcm_reject_ima',
        'tb_source_fades_power2','tb_alarm_scene_compact')+$tests
    $tests=@('tb_scaler_crop_native','tb_scaler_crop_bilinear','tb_scaler_crop_four',
        'tb_viewport_cache','tb_demo_playlist','tb_demo_playlist_guard','tb_demo_sprites','tb_detail_controls')+$tests
    $tests=@('tb_operator_confirmation','tb_v5_console_confirmation','tb_fat_chain_preflight',
        'tb_fat_strict_reader','tb_console_strict_chain','tb_media_strict_chain','tb_confirmation_overlay')+$tests
    $tests=@('tb_local_fire_control','tb_voice_exact','tb_voice_context','tb_source_fades','tb_v5_daily_control',
        'tb_event_permissions','tb_event_authority_roles_link','tb_fat_sorted_catalog',
        'tb_v5_route_stage','tb_v5_media_safety','tb_v5_console_control','tb_site_notice_tone')+$tests
    $tests=@('tb_wav_ima_adpcm','tb_console_ima_fat_pipeline','tb_console_wav_fail_closed',
        'tb_media_ima_pipeline','tb_media_sentence_resume')+$tests
    $tests=@('tb_status_framer_stable_session','tb_event_authority_link','tb_quality_multiplier_equivalence')+$tests
    $tests=@('tb_event_resource_equivalence','tb_earthquake_restart','tb_quality_shared_smoother')+$tests
    $tests=@('tb_fit_geometry','tb_n10_arrows')+$tests
    $tests=@('tb_cancel_priority','tb_n10_scanout','tb_n10_graph_bounds','tb_n10_packetizer_recovery','tb_n10_demo_map','tb_n10_graph_solver','tb_n10_route_link','tb_certificate_transaction','tb_alarm_scene_scanout','tb_bad_image_skip','tb_fat_file_recovery')+$tests
    $tests=@('tb_reset_release_falling','tb_sdram_audio_ring','tb_transition_phase_pipeline','tb_media_audio_pipeline','tb_sd_init_bounds','tb_audio_status_osd','tb_alarm_flash_timing','tb_spectrum_banks','tb_sd_response','tb_sd_addressing','tb_narration_length','tb_audio_sample_fifo','tb_audio_output_stage','tb_sine_rom','tb_media_audio_requests','tb_alarm_mix_sources','tb_v41_serial_resync12',
        'tb_earthquake_tone','tb_segment_map_pixels','tb_pixel_arithmetic','tb_frame_parameter_smoother','tb_certificate_bram',
        'tb_dual_scanout_audio','tb_dual_scanout','tb_dual_transition','tb_remote_spectrum','tb_spectrum_uart','tb_console_wav_fat_pipeline','tb_controls',
        'tb_video_effects','tb_extensions')+$tests
}
if($Test -eq 'all'){$tests+=@('tb_human_wav_admission','tb_human_media_real','tb_single_card_media_real','tb_daily_broadcast_real')}
if($ListTests){$tests;return}
$sources=@(Get-ChildItem (Join-Path $projectRoot 'rtl') -Filter '*.v' | ForEach-Object FullName)
$sources+=@(Get-ChildItem (Join-Path $projectRoot 'console\rtl') -Filter '*.v' | ForEach-Object FullName)
$sources+=@(Get-ChildItem (Join-Path $projectRoot 'console\vendor') -Filter '*.v' | ForEach-Object FullName)
$sources+=@(Get-ChildItem (Join-Path $projectRoot 'vendor\sd') -Filter '*.v' | ForEach-Object FullName)
$sources+=Join-Path $projectRoot 'console/board/duty_console_top.v'
$sources+=Join-Path $projectRoot 'board/status_display.v'
$benches=@(Get-ChildItem (Join-Path $projectRoot 'sim') -Filter '*.v' | ForEach-Object FullName)
$evidenceDir=if($ResumeFrom){(Resolve-Path -LiteralPath $ResumeFrom).Path}else{
    Join-Path $projectRoot ('build\sim_runs\'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+$Test)}
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$tracked=@($sources)+@($benches)+@(
    Get-ChildItem (Join-Path $projectRoot 'rtl'),(Join-Path $projectRoot 'console\rtl'),(Join-Path $projectRoot 'sim') -File |
        Where-Object {$_.Extension -in '.mem','.mif'} | ForEach-Object FullName)
$tracked+=@(Get-ChildItem (Join-Path $projectRoot 'board'),(Join-Path $projectRoot 'console\board'),
    (Join-Path $projectRoot 'constraints'),(Join-Path $projectRoot 'console\constraints') -File |
    ForEach-Object FullName)
$hashes=[ordered]@{}
foreach($path in $tracked){$hashes[$path.Substring($projectRoot.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
$reusable=@{}
if($ResumeFrom){
    $priorHashes=Get-Content -LiteralPath (Join-Path $evidenceDir 'source_sha256.json') -Raw | ConvertFrom-Json
    if(@($priorHashes.PSObject.Properties).Count -ne $hashes.Count){throw 'Resume source set differs.'}
    foreach($entry in $priorHashes.PSObject.Properties){
        if(-not $hashes.Contains($entry.Name) -or $hashes[$entry.Name] -ne $entry.Value){
            throw "Cannot resume changed source: $($entry.Name)"
        }
    }
    $priorRun=Get-Content -LiteralPath (Join-Path $evidenceDir 'run.json') -Raw | ConvertFrom-Json
    if(($priorRun.tests -join '|') -ne ($tests -join '|') -or
       ($priorRun.simulation_args -join '|') -ne ($SimulationArgs -join '|') -or
       $priorRun.icarus_bin -ne $IcarusBin){throw 'Resume test plan or runtime differs.'}
    $lastStarted=-1
    for($index=0;$index -lt $tests.Count;$index++){
        if(Test-Path -LiteralPath (Join-Path $evidenceDir ($tests[$index]+'.compile.log'))){$lastStarted=$index}
    }
    for($index=0;$index -lt $lastStarted;$index++){
        $name=$tests[$index]
        $log=Join-Path $evidenceDir ($name+'.log')
        if((Test-Path -LiteralPath $log) -and
           (Select-String -LiteralPath $log -SimpleMatch 'TEST_PASS' -Quiet) -and
           -not (Select-String -LiteralPath $log -Pattern 'TEST_FAIL|FATAL' -Quiet)){
            $reusable[$name]=$true
        }
    }
    @{resumed=(Get-Date).ToString('o');reused=@($tests | Where-Object {$reusable.ContainsKey($_)});
      source_files=$hashes.Count} | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $evidenceDir ('resume_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')) -Encoding utf8
}else{
    $hashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidenceDir 'source_sha256.json') -Encoding utf8
    @{tests=$tests;simulation_args=$SimulationArgs;icarus_bin=$IcarusBin;started=(Get-Date).ToString('o')} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDir 'run.json') -Encoding utf8
}
$completed=@()
Push-Location $outDir
try {
    foreach($top in $tests) {
        if($reusable.ContainsKey($top)){
            $completed+=$top
            Write-Host "Reused verified pre-interruption PASS: $top"
            continue
        }
        $output=Join-Path $outDir "$top.vvp"
        $compileLog=Join-Path $evidenceDir "$top.compile.log"
        $simulationLog=Join-Path $evidenceDir "$top.log"
        Set-Content -LiteralPath $compileLog -Value ''
        Set-Content -LiteralPath $simulationLog -Value ''
        $ErrorActionPreference='Continue'
        & (Join-Path $IcarusBin 'iverilog.exe') -g2005 -Wall -s $top -o $output @sources @benches 2>&1 |
            ForEach-Object {$_.ToString()} |
            Tee-Object -FilePath $compileLog
        $compileExit=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($compileExit -ne 0) {throw "Compilation failed: $top"}
        $ErrorActionPreference='Continue'
        & (Join-Path $IcarusBin 'vvp.exe') -i $output @SimulationArgs 2>&1 |
            ForEach-Object {$_.ToString()} | Tee-Object -FilePath $simulationLog
        $simExit=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($simExit -ne 0) {throw "Simulation failed: $top"}
        Copy-Item -LiteralPath $compileLog,$simulationLog -Destination $outDir
        if(Select-String -LiteralPath $simulationLog -SimpleMatch 'TEST_FAIL') {throw "Self-check failure: $top"}
        if(-not(Select-String -LiteralPath $simulationLog -SimpleMatch 'TEST_PASS')) {throw "Missing self-check PASS: $top"}
        $completed+= $top
        @{completed=$completed;updated=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $evidenceDir 'progress.json') -Encoding utf8
    }
    foreach($entry in $hashes.GetEnumerator()){
        if((Get-FileHash -LiteralPath (Join-Path $projectRoot $entry.Key) -Algorithm SHA256).Hash -ne $entry.Value){
            throw "Source changed during regression: $($entry.Key). Results are not a frozen-source signoff."
        }
    }
    @{result='PASS';completed=$completed;source_files=$hashes.Count;finished=(Get-Date).ToString('o')} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDir 'result.json') -Encoding utf8
    Write-Host "All $($completed.Count) selected self-checks passed; source SHA256 unchanged. Artifacts: $evidenceDir"
} catch {
    @{result='FAIL';completed=$completed;error=$_.ToString();finished=(Get-Date).ToString('o')} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDir 'result.json') -Encoding utf8
    throw
} finally {Pop-Location}

