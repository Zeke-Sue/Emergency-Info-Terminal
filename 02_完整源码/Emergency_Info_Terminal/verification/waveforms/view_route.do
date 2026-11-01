view wave
add wave -radix hexadecimal /tb_live_route/blocked
add wave /tb_live_route/request
add wave /tb_live_route/ready
add wave -radix hexadecimal /tb_live_route/payload
add wave -radix unsigned /tb_live_route/status
add wave -radix unsigned /tb_live_route/ex
add wave -radix hexadecimal /tb_live_route/edges
add wave -radix hexadecimal /tb_live_route/dirs
add wave -radix unsigned /tb_live_route/expected_cost
add wave -radix unsigned /tb_live_route/path_cost
wave zoom full
