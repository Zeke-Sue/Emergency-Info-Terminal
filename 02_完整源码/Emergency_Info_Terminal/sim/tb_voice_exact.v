`timescale 1ns/1ps
module tb_voice_exact;
    reg clk=0,rst=1,tick=0,cfg=0,enq=0,urgent=0,cancel=0;
    always #5 clk=~clk;
    reg [5:0] segment=1;
    reg [15:0] length=4;
    wire [15:0] address;wire valid,playing,ready,overflow,underflow,audio;
    wire signed [15:0] sample;
    reg [3:0] nibble;
    integer count=0,n,expected,prev,target,phase;
    voice_segment_player #(.GAP_SAMPLES(3),.ENABLE_CANCEL(1)) dut(
        .clk(clk),.rst(rst),.sample_tick(tick),.enqueue_valid(enq),.enqueue_segment(segment),
        .enqueue_urgent(urgent),.enqueue_ready(ready),.cancel_queue(cancel),
        .cfg_we(cfg),.cfg_segment(6'd1),.cfg_start(16'd0),.cfg_length(length),
        .rom_address(address),.rom_nibble(nibble),.voice_valid(valid),.voice_sample(sample),
        .playing(playing),.active_audio(audio),.queue_overflow(overflow),.decode_underflow(underflow));
    always @(posedge clk)case(address)
        0:nibble<=7;1:nibble<=1;2:nibble<=15;default:nibble<=0;
    endcase
    task fail;input [799:0] message;begin
        $display("TEST_FAIL voice exact: %0s count=%d sample=%d expected=%d",message,count,sample,expected);$finish;end endtask
    task output_tick;begin
        repeat(12)@(negedge clk);tick=1;@(negedge clk);tick=0;
    end endtask
    task queue_one;begin enq=1;@(negedge clk);enq=0;@(negedge clk);end endtask
    task check_segment;begin
        count=0;
        for(n=0;n<45;n=n+1)begin
            output_tick();
            if(valid)begin
                case(count/6)
                    0:begin prev=0;target=11;end
                    1:begin prev=11;target=17;end
                    2:begin prev=17;target=-8;end
                    3:begin prev=-8;target=-5;end
                    default:fail("extra output");
                endcase
                phase=count%6+1;expected=prev+(target-prev)*phase/6;
                if(sample!==expected)fail("independent signed interpolation reference");
                count=count+1;
            end
        end
        if(count!=24||playing||underflow)fail("final nibble missing or decoder stalled");
    end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;cfg=1;@(negedge clk);cfg=0;
        queue_one();check_segment();queue_one();check_segment();
        for(n=0;n<16;n=n+1)queue_one();if(ready)fail("16 entry queue capacity");
        enq=1;@(negedge clk);if(!overflow)fail("full queue overflow not reported");enq=0;
        @(negedge clk);urgent=1;enq=1;tick=1;@(negedge clk);urgent=0;enq=0;tick=0;
        if(dut.queue_count!=1)fail("urgent collision did not replace entire queue");
        check_segment();queue_one();output_tick();cancel=1;tick=1;
        @(negedge clk);cancel=0;tick=0;repeat(15)@(negedge clk);
        if(playing||dut.queue_count!=0||dut.first_decode)fail("cancel resurrected in-flight decode");
        $display("TEST_PASS voice exact: all 24 signed samples, final nibble, seed reset, 16 entries, overflow, urgent/sample collision, cancel");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
