`timescale 1ns/1ps
module tb_audio;
    reg clk=0,rst=1,enable=1,test_mode=0;
    reg [3:0] image_index=0;
    always #20 clk=~clk;
    wire sample_valid,acr_valid;
    wire [15:0] sample_left,sample_right;
    wire [19:0] acr_n,acr_cts;
    pcm_audio dut(
        .clk(clk),.rst(rst),.enable(enable),.test_mode(test_mode),.image_index(image_index),
        .sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
        .acr_valid(acr_valid),.acr_n(acr_n),.acr_cts(acr_cts));
    integer cycles=0,last_sample=0,samples=0,acr_packets=0,crossings=0;
    integer note,k,expected_crossings;
    reg signed [15:0] previous=0;
    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_audio: %0s",reason);
            $finish;
        end
    endtask
    initial begin
        $dumpfile("tb_audio.vcd");$dumpvars(1,dut);
        repeat(5)@(negedge clk);rst=0;
        for(note=0;note<9;note=note+1)begin
            test_mode=(note==8);
            image_index=note;samples=0;crossings=0;acr_packets=0;
            for(k=0;k<2500000;k=k+1)begin
                @(posedge clk);#1;cycles=cycles+1;
                if(cycles==200000)$dumpoff;
                if(sample_valid)begin
                    if((^sample_left)===1'bx || (^sample_right)===1'bx)fail("unknown PCM sample");
                    if(last_sample!=0 && cycles-last_sample!=520 && cycles-last_sample!=521)fail("invalid sample spacing");
                    last_sample=cycles;samples=samples+1;
                    if(sample_left!==sample_right)fail("stereo mismatch");
                    if($signed(sample_left)>8192||$signed(sample_left)<-8192)fail("PCM clipping");
                    if(previous<0 && $signed(sample_left)>=0)crossings=crossings+1;
                    previous=sample_left;
                end
                if(acr_valid)begin
                    if(!sample_valid)fail("ACR not aligned to sample");
                    acr_packets=acr_packets+1;
                end
            end
            case(note)
                0:expected_crossings=44;1:expected_crossings=49;
                2:expected_crossings=52;3:expected_crossings=59;
                4:expected_crossings=66;5:expected_crossings=70;
                6:expected_crossings=78;7:expected_crossings=88;
                default:expected_crossings=100;
            endcase
            if(samples!=4800)begin
                $display("sample rate not exactly 48 kHz: %0d",samples);
                fail("sample count mismatch");
            end
            if(crossings<expected_crossings-1||crossings>expected_crossings+1)begin
                $display("tone frequency mismatch note=%0d crossings=%0d",note,crossings);
                fail("tone frequency mismatch");
            end
            if(acr_packets<37||acr_packets>38||acr_n!=6144||acr_cts!=25000)fail("ACR cadence/constants");
            $display("PASS: note%0d 4800 samples/100ms, positive crossings=%0d ACR=%0d",note,crossings,acr_packets);
            @(negedge clk);
        end
        enable=0;repeat(1100)begin wait(sample_valid);@(negedge clk);wait(!sample_valid);end
        if(sample_left!=0||sample_right!=0)fail("mute ramp failed");
        $display("TEST_PASS tb_audio exact 48kHz, eight image tones, 1kHz maintenance tone, signed stereo, ACR and mute ramp");$finish;
    end
    initial begin #1200000000;fail("audio timeout");end
endmodule
