create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
set_clock_uncertainty -hold 0.50 [get_clocks {clk}]
set_false_path -from [get_ports {key1 key2 key3 key4 sw1 sw2 sw3 sw4 console_uart_rx extension_pcm_rx sd_miso}]
