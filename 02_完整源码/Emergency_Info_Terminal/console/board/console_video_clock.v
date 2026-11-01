`timescale 1ns/1ps
module console_video_clock(
    input wire clk,output wire pixel_clk,output wire serial_clk,
    output wire locked,output wire pixel_rst
);
    wire feedback;wire [4:0] clocks;
    EG_LOGIC_BUFG feedback_buf(.i(feedback),.o(pixel_clk));
    assign feedback=clocks[0];assign serial_clk=clocks[1];
    EG_PHY_PLL #(.DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),
        .FIN("50.000000"),.FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC0_EXT"),
        .STDBY_ENABLE("DISABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
        .GMC_GAIN(2),.ICP_CURRENT(9),.KVCO(2),.LPF_CAPACITOR(1),.LPF_RESISTOR(8),
        .REFCLK_DIV(2),.FBCLK_DIV(1),.CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(40),
        .CLKC0_CPHASE(39),.CLKC0_FPHASE(0),.CLKC1_ENABLE("ENABLE"),
        .CLKC1_DIV(8),.CLKC1_CPHASE(7),.CLKC1_FPHASE(0)) video_pll(
        .refclk(clk),.reset(1'b0),.stdby(1'b0),.extlock(locked),
        .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),
        .psclksel(3'b000),.psdone(),.dclk(1'b0),.dcs(1'b0),.dwe(1'b0),
        .di(8'd0),.daddr(6'd0),.do(),.fbclk(pixel_clk),.clkc(clocks));
    reg [19:0] hold_count;
    reg reset_q;
    always @(posedge pixel_clk or negedge locked)begin
        if(!locked)begin hold_count<=0;reset_q<=1;end
        else if(hold_count!=20'hfffff)begin hold_count<=hold_count+1'b1;reset_q<=1;end
        else reset_q<=0;
    end
    assign pixel_rst=reset_q;
endmodule
