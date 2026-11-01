# Board reference clock: 50 MHz. PLL-derived paths remain timed.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks

set_clock_uncertainty -hold 0.20 [get_clocks *]

set_false_path -from [get_clocks {clocks/system_pll.clkc[0]}] -to [get_clocks {clk}]
set_false_path -from [get_clocks {clocks/video_pll.clkc[0]}] -to [get_clocks {clk}]

set_false_path -from [get_ports {key_zoom key1 key2 key3 effect_sw1 effect_sw2 overlay_sw3 grayscale_sw4 console_uart_rx}]
