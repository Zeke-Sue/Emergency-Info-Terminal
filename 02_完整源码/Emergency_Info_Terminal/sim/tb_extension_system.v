`timescale 1ns/1ps

module tb_extension_system;
 reg aclk=0,bclk=0,rst=1;always #20 aclk=~aclk;always #10 bclk=~bclk;
 reg [9:0] div=0;wire tick=div==520;
 always @(posedge aclk)if(rst)div<=0;else div<=tick ? 0 : div+1'b1;
 wire [15:0] pcm;wire native_valid,tx,overrun,btx;
 page_test_tone_48k tone(.clk(aclk),.rst(rst),.enable(1'b1),.output_tick(tick),.page(5'd4),
 .native_valid(native_valid),.native_sample(pcm),.output_sample());
 pcm_context_tx source(.clk(aclk),.rst(rst),.sample_valid(tick),.sample(pcm),
 .context(128'h00000000000024000100c04000000000),.tx(tx),.overrun(overrun));
 duty_console_top #(.RESET_CYCLES(8),.DEBOUNCE_CYCLES(4)) board_b(.clk(bclk),
 .key1(1'b1),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sw4(1'b0),
 .extension_pcm_rx(tx),.console_uart_rx(1'b1),.console_uart_tx(btx),.sd_miso(1'b1),.flash_miso(1'b1),.HDMI_DDC_SDA());
 wire [7:0] byte_data,kind;wire byte_valid,framing,service,crc_error,frame_error;
 wire [95:0] payload;
 uart_rx_8n1 #(.CLK_HZ(25000000),.BAUD(115200)) serial(.clk(aclk),.rst(rst),.rx(btx),
 .data(byte_data),.valid(byte_valid),.framing_error(framing));
 uart_protocol_parser parser(.clk(aclk),.rst(rst),.byte_valid(byte_valid),.byte_data(byte_data),
 .us_tick(1'b0),.service_valid(service),.service_type(kind),.service_payload(payload),.crc_error(crc_error),.frame_error(frame_error));
 reg [18:0] frame_div=0;wire frame=frame_div==416666;
 always @(posedge aclk)if(rst)frame_div<=0;else frame_div<=frame ? 0 : frame_div+1'b1;
 wire [23:0] peak;wire spectrum_valid;wire [7:0] magnitude;
 remote_spectrum_receiver spectrum(.clk(aclk),.rst(rst),.frame_tick(frame),.message_valid(service),
 .message_type(kind),.payload(payload),.query_age(7'd0),.query_bin(6'd16),.query_value(magnitude),
 .peak_frequency_q8(peak),.file_index(),.sample_position(),.valid(spectrum_valid),.dropped_columns());
 wire [103:0] rows;wire rows_valid;
 remote_status_rows ui(.clk(aclk),.rst(rst),.frame_tick(frame),.message_valid(service),.message_type(kind),.payload(payload),.rows(rows),.valid(rows_valid));
 integer ui_count=0,route_count=0,spec_count=0,health_count=0;
 reg health_pass=0;
 always @(posedge aclk)if(!rst)begin
  if(framing||crc_error||frame_error||overrun)begin $display("TEST_FAIL system link error %b%b%b%b",framing,crc_error,frame_error,overrun);$finish;end
  if(service)case(kind)8'h27:ui_count=ui_count+1;8'h29:route_count=route_count+1;8'h22:spec_count=spec_count+1;8'h2a:begin health_count=health_count+1;if(payload[31:24]==1&&payload[71:56]==16'h1500&&payload[55:40]==16'h1500)health_pass=1;end endcase
 end
 initial begin
  repeat(20)@(negedge aclk);rst=0;
  #330000000;
  if(!health_pass||health_count<1||!spectrum_valid||peak<1490*256||peak>1510*256||magnitude==0||!rows_valid||route_count<1||spec_count<2||ui_count<4)begin
   $display("TEST_FAIL system peak=%d magnitude=%d ui=%d route=%d spectrum=%d valid=%b%b",peak>>8,magnitude,ui_count,route_count,spec_count,rows_valid,spectrum_valid);$finish;end
  $display("TEST_PASS tb_extension_system actual PCM -> B FFT/route/UI -> UART -> A receivers, peak=%d Hz",peak>>8);$finish;
 end
endmodule
