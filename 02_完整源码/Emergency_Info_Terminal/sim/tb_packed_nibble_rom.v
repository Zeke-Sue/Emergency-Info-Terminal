`timescale 1ns/1ps
module tb_packed_nibble_rom;
    reg clk=0;always #5 clk=~clk;
    reg [15:0] address=0;
    wire [3:0] voice,sprite0,sprite1;
    reg [3:0] original[0:49151],pixels0[0:8191],pixels1[0:8191];
    integer i;
    l0_voice_rom dut(.clk(clk),.address(address),.nibble(voice));
    packed_nibble_rom s0(.clk(clk),.address(address[12:0]),.nibble(sprite0));
    packed_nibble_rom #(.MEM_FILE("../../rtl/demo_sprite1.packed.mem")) s1(
        .clk(clk),.address(address[12:0]),.nibble(sprite1));
    initial begin
        $readmemh("../../rtl/l0_voice_bank0.mem",original,0,8191);
        $readmemh("../../rtl/l0_voice_bank1.mem",original,8192,16383);
        $readmemh("../../rtl/l0_voice_bank2.mem",original,16384,24575);
        $readmemh("../../rtl/l0_voice_bank3.mem",original,24576,32767);
        $readmemh("../../rtl/l0_voice_bank4.mem",original,32768,40959);
        $readmemh("../../rtl/l0_voice_bank5.mem",original,40960,49151);
        $readmemh("../../rtl/demo_sprite0.mem",pixels0);
        $readmemh("../../rtl/demo_sprite1.mem",pixels1);
        for(i=0;i<65536;i=i+1)begin
            @(negedge clk);address=i;@(posedge clk);#1;
            if(voice!==(i<49152 ? original[i] : 4'd0))$fatal(1,"voice ROM mismatch %d",i);
            if(i<8192&&(sprite0!==pixels0[i]||sprite1!==pixels1[i]))$fatal(1,"sprite ROM mismatch %d",i);
        end
        $display("TEST_PASS packed ROM: all 65536 original nibbles, bank boundaries, odd/even selection and invalid banks");$finish;
    end
endmodule
