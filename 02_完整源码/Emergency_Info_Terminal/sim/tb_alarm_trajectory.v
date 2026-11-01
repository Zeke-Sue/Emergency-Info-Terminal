`timescale 1ns/1ps
module tb_alarm_trajectory;
    reg clk=0,rst=1,start=0,valid=0,done=0;
    reg [1:0] profile=0;reg [8:0] bin=0;reg [15:0] magnitude=0;
    wire failed;wire [31:0] windows,bad,first_bad;
    wire [4:0] missing;wire bad_window;
    always #5 clk=~clk;
    alarm_trajectory_checker dut(.clk(clk),.rst(rst),.start(start),.profile(profile),
        .bin_valid(valid),.bin_index(bin),.magnitude(magnitude),.window_done(done),
        .failed(failed),.windows_checked(windows),.bad_windows(bad),
        .first_bad_sample(first_bad),.missing_voices(missing),.bad_window(bad_window));
    integer file,rc,id,p,count,expected,w,b,m,total;
    task fail;input [511:0] msg;
        begin $display("TEST_FAIL tb_alarm_trajectory case=%0d %0s",id,msg);$finish;end
    endtask
    initial begin
        file=$fopen("../trajectory/vectors.txt","r");
        if(file==0)fail("run tools/check_trajectory_reference.py first");
        total=0;repeat(3)@(negedge clk);rst=0;
        while(!$feof(file))begin
            rc=$fscanf(file,"%d %d %d %d",id,p,count,expected);
            if(rc==4)begin
                @(negedge clk);start=1;profile=p;@(negedge clk);start=0;
                repeat(2)@(negedge clk);
                for(w=0;w<count;w=w+1)begin
                    for(b=0;b<257;b=b+1)begin
                        rc=$fscanf(file,"%d",m);
                        if(rc!=1)fail("truncated FFT vector");
                        valid=1;bin=b;magnitude=m;@(negedge clk);
                    end
                    valid=0;repeat(2)@(negedge clk);
                    done=1;@(negedge clk);done=0;repeat(2)@(negedge clk);
                end
                if(windows!=count || failed!==expected[0])fail("reference decision mismatch");
                $display("case %0d windows=%0d bad=%0d reject=%0b first_sample=%0d",id,windows,bad,failed,first_bad);
                total=total+1;
            end
        end
        if(total!=32)fail("missing corpus cases");
        $display("TEST_PASS tb_alarm_trajectory 32 actual-WAV independent FFT spectral vectors");$finish;
    end
    initial begin #100000000;fail("timeout");end
endmodule
