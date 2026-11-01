// SDRAM读写控制器接口，使用相移时钟满足外部存储器时序。
`timescale 1ns/1ps

module memory_phy(
    input wire clk, shifted_clk, rst,
    output wire initialized, busy,
    input wire wr_en,
    input wire [20:0] wr_addr,
    input wire [31:0] wr_data,
    input wire rd_en,
    input wire [20:0] rd_addr,
    output wire rd_valid,
    output wire [31:0] rd_data
);
    wire sdram_clk, ras_n, cas_n, we_n;
    wire [1:0] bank;
    wire [10:0] address;
    wire [3:0] dm;
    wire [31:0] dq;
    sdr_as_ram #(.self_refresh_open(1'b1)) controller(
        .Sdr_clk(clk),.Sdr_clk_sft(shifted_clk),.Rst(rst),
        .Sdr_init_done(initialized),.Sdr_init_ref_vld(),.Sdr_busy(busy),.App_ref_req(1'b0),
        .App_wr_en(wr_en),.App_wr_addr(wr_addr),.App_wr_dm(4'b0000),.App_wr_din(wr_data),
        .App_rd_en(rd_en),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data),
        .SDRAM_CLK(sdram_clk),.SDR_RAS(ras_n),.SDR_CAS(cas_n),.SDR_WE(we_n),
        .SDR_BA(bank),.SDR_ADDR(address),.SDR_DM(dm),.SDR_DQ(dq));
    EG_PHY_SDRAM_2M_32 ram(
        .clk(sdram_clk),.ras_n(ras_n),.cas_n(cas_n),.we_n(we_n),
        .addr(address),.ba(bank),.dq(dq),.cs_n(1'b0),
        .dm0(dm[0]),.dm1(dm[1]),.dm2(dm[2]),.dm3(dm[3]),.cke(1'b1));
endmodule
