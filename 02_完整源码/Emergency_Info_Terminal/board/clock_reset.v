// 独立视频与系统PLL；各时钟域等待锁定后同步释放复位。
`timescale 1ns/1ps

module clock_reset(
    input wire clk, rst_n,
    output wire pixel_clk, serial_clk, sys_clk, mem_shift_clk,
    output wire video_locked, system_locked,
    output wire sys_rst, pixel_rst
);
    wire video_feedback;
    wire [4:0] video_clocks;
    EG_LOGIC_BUFG video_feedback_buf(.i(video_feedback),.o(pixel_clk));
    assign video_feedback=video_clocks[0];
    assign serial_clk=video_clocks[1];

    EG_PHY_PLL #(
        .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.FIN("50.000000"),
        .FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC0_EXT"),
        .STDBY_ENABLE("DISABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
        .GMC_GAIN(2),.ICP_CURRENT(9),.KVCO(2),.LPF_CAPACITOR(1),.LPF_RESISTOR(8),
        .REFCLK_DIV(2),.FBCLK_DIV(1),
        .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(40),.CLKC0_CPHASE(39),.CLKC0_FPHASE(0),
        .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(8),.CLKC1_CPHASE(7),.CLKC1_FPHASE(0)
    ) video_pll(
        .refclk(clk),.reset(1'b0),.stdby(1'b0),.extlock(video_locked),
        .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b000),.psdone(),
        .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'd0),.daddr(6'd0),.do(),
        .fbclk(pixel_clk),.clkc(video_clocks));

    wire system_feedback;
    wire [4:0] system_clocks;
    EG_LOGIC_BUFG system_feedback_buf(.i(system_feedback),.o(sys_clk));
    assign system_feedback=system_clocks[0];
    assign mem_shift_clk=system_clocks[1];

    EG_PHY_PLL #(
        .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.FIN("50.000000"),
        .FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC0_EXT"),
        .STDBY_ENABLE("DISABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
        .GMC_GAIN(4),.ICP_CURRENT(29),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(2),
        .REFCLK_DIV(1),.FBCLK_DIV(1),
        .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(20),.CLKC0_CPHASE(19),.CLKC0_FPHASE(0),
        .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(20),.CLKC1_CPHASE(7),.CLKC1_FPHASE(0)
    ) system_pll(
        .refclk(clk),.reset(1'b0),.stdby(1'b0),.extlock(system_locked),
        .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b000),.psdone(),
        .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'd0),.daddr(6'd0),.do(),
        .fbclk(sys_clk),.clkc(system_clocks));

    wire sys_reset_async=!rst_n || !system_locked;
    clock_startup_reset #(.SETTLE_BITS(20)) sys_release(
        .clk(sys_clk),.async_reset(sys_reset_async),
        .reset_out(sys_rst));

    wire video_reset_async=!rst_n || !video_locked;
    clock_startup_reset #(.SETTLE_BITS(19)) pixel_release(
        .clk(pixel_clk),.async_reset(video_reset_async),
        .reset_out(pixel_rst));
endmodule
