`timescale 1ns/1ps
module tb_n10_packetizer_recovery;
    reg clk=0,rst=1,refresh=0;wire valid,busy,error;wire [7:0] kind;wire [95:0] payload;
    integer entries=0,begins=0,ends=0;
    always #5 clk=~clk;
    n10_route_packetizer dut(.clk(clk),.rst(rst),.refresh(refresh),.request_valid(valid),
        .request_ready(1'b1),.request_type(kind),.request_payload(payload),.busy(busy),.error(error));
    always @(posedge clk)if(!rst&&valid)begin
        if(kind==8'h23)begin begins=begins+1;entries=0;end
        if(kind==8'h24)begin
            if(payload[79:72]!=entries)begin $display("TEST_FAIL packetizer order");$finish;end
            entries=entries+1;
        end
        if(kind==8'h25)begin
            if(entries!=256)begin $display("TEST_FAIL packetizer incomplete end");$finish;end
            ends=ends+1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        wait(dut.solver_busy);@(negedge clk);

        force dut.solver.cfg_write=1'b1;
        repeat(2)@(negedge clk);release dut.solver.cfg_write;
        wait(error);@(negedge clk);
        if(busy||ends)begin $display("TEST_FAIL packetizer did not abort");$finish;end
        refresh=1;@(negedge clk);refresh=0;
        wait(ends==1);@(negedge clk);
        if(error||begins!=2)begin $display("TEST_FAIL packetizer sticky error blocked restart");$finish;end
        $display("TEST_PASS packetizer abort and complete 256-entry refresh after sticky solver error");$finish;
    end
    initial begin #50000000;$display("TEST_FAIL packetizer recovery timeout");$finish;end
endmodule
