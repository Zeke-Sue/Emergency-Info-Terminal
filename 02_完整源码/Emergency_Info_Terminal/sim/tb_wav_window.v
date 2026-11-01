`timescale 1ns/1ps
module tb_wav_window;
 reg clk=0,rst=1,request=0,stop=0,busy=0,opened=0,valid=0,ended=0,ready=1;
 reg [7:0] data=0;reg [31:0] start_sample=2,limit=3;
 always #5 clk=~clk;
 wire open_req,take,sv,abort_file,flush;wire signed [15:0] sample;
 wire [31:0] samples;wire [3:0] error;
 integer count=0,flush_after=0;reg armed=0;
 narration_wav_streamer #(.CANONICAL_PCM(1),.DIRECT_PLAY(1),.ENABLE_RESUME(1),
 .ENABLE_STOP(1),.ENABLE_WINDOW(1),.TIMEOUT_CYCLES(1000)) dut(
 .clk(clk),.rst(rst),.play_request(request),.stop_request(stop),.file_abort(abort_file),
 .requested_index(4'd15),.external_allowed(1'b1),.requested_start_sample(start_sample),
 .requested_sample_limit(limit),.loop_enable(1'b0),.file_error(4'd0),.file_io_progress(1'b0),
 .file_open_req(open_req),.file_busy(busy),.file_open_done(opened),.file_not_found(1'b0),
 .file_size(32'd60),.file_data(data),.file_valid(valid),.file_ready(take),.file_end(ended),
 .asset_samples(samples),.sample_valid(sv),.sample(sample),.sample_ready(ready),.fifo_flush(flush),.error_code(error));
 always @(posedge clk)begin
  if(armed&&flush)flush_after=flush_after+1;
  if(sv)begin if(sample!==1002+count)$fatal(1,"window PCM got %d count %d",sample,count);count=count+1;end
 end
 task byte;input [7:0] b;begin @(negedge clk);while(!take)@(negedge clk);data=b;valid=1;@(negedge clk);valid=0;end endtask
 task word;input [31:0] w;begin byte(w[7:0]);byte(w[15:8]);byte(w[23:16]);byte(w[31:24]);end endtask
 task pcm;input [15:0] s;begin byte(s[7:0]);byte(s[15:8]);end endtask
 task header;begin
 byte("R");byte("I");byte("F");byte("F");word(52);byte("W");byte("A");byte("V");byte("E");
 byte("f");byte("m");byte("t");byte(" ");word(16);pcm(1);pcm(1);word(48000);word(96000);pcm(2);pcm(16);
 byte("d");byte("a");byte("t");byte("a");word(16);
 end endtask
 task start;begin
 @(negedge clk);request=1;@(negedge clk);request=0;wait(open_req);@(negedge clk);busy=1;
 repeat(2)@(negedge clk);opened=1;@(negedge clk);opened=0;header();
 end endtask
 initial begin
 repeat(4)@(negedge clk);rst=0;start();armed=1;
 pcm(1000);pcm(1001);ready=0;repeat(8)@(negedge clk);ready=1;
 pcm(1002);pcm(1003);pcm(1004);wait(abort_file);repeat(4)@(negedge clk);
 if(count!=3||samples!=3||error!=0||flush_after!=0)$fatal(1,"window count/flush/error %d %d %d %d",count,samples,error,flush_after);

 pcm(9999);pcm(9999);@(negedge clk);busy=0;repeat(4)@(negedge clk);
 if(count!=3)$fatal(1,"next voice leaked across boundary");
 armed=0;start_sample=6;limit=3;start();repeat(8)@(negedge clk);
 if(error==0||!abort_file)$fatal(1,"out-of-bounds voice window accepted");
 busy=0;repeat(5)@(negedge clk);start_sample=2;limit=3;start();
 stop=1;@(negedge clk);stop=0;#1;if(!abort_file||!flush)$fatal(1,"explicit stop did not flush");
 $display("TEST_PASS bounded PCM window exact skip/count, backpressure, no buffered-tail flush, no next-clip leak, bounds and stop");$finish;
 end
 initial begin #1000000;$fatal(1,"WAV window timeout");end
endmodule
