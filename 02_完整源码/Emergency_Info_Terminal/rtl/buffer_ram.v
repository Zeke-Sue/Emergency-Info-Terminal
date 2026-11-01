`timescale 1ns/1ps

module buffer_ram #(parameter DATA_WIDTH=8, ADDR_WIDTH=9)(
    input wire clk, we,
    input wire [ADDR_WIDTH-1:0] wa, ra,
    input wire [DATA_WIDTH-1:0] d,
    output wire [DATA_WIDTH-1:0] q
);
`ifdef __ICARUS__
    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] read_q;
    always @(posedge clk) begin
        if(we) memory[wa]<=d;
        read_q<=memory[ra];
    end
    assign q=read_q;
`else
    EG_LOGIC_BRAM #(.DATA_WIDTH_A(DATA_WIDTH),.DATA_WIDTH_B(DATA_WIDTH),
        .ADDR_WIDTH_A(ADDR_WIDTH),.ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(1<<ADDR_WIDTH),.DATA_DEPTH_B(1<<ADDR_WIDTH),
        .MODE("DP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"),.WRITEMODE_B("READBEFOREWRITE"),
        .IMPLEMENT("9K")) ram(
        .dia(d),.addra(wa),.cea(1'b1),.ocea(1'b1),.clka(clk),
        .wea(we),.rsta(1'b0),.bea(1'b1),
        .dib({DATA_WIDTH{1'b0}}),.addrb(ra),.ceb(1'b1),.oceb(1'b1),
        .clkb(clk),.web(1'b0),.rstb(1'b0),.beb(1'b1),.doa(),.dob(q));
`endif
endmodule
