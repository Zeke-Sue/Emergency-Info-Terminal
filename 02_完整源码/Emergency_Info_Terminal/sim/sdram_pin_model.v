`timescale 1ns/1ps

module EG_PHY_SDRAM_2M_32(input clk,ras_n,cas_n,we_n,input [10:0] addr,
    input [1:0] ba,inout [31:0] dq,input cs_n,dm0,dm1,dm2,dm3,cke);
    reg [31:0] memory[0:2097151];
    reg [10:0] rows[0:3];
    reg writing=0,reading=0;reg [1:0] bank;
    reg [7:0] col;reg [2:0] cas_latency=3;
    reg [2:0] read_valid=0;reg [31:0] pipe0,pipe1,pipe2;
    reg [31:0] out_data;reg output_enable=0;
    wire [2:0] command={ras_n,cas_n,we_n};
    integer a,lane;
    integer burst_length=4,left=0;
    reg [7:0] masks;
    assign dq=output_enable ? out_data : 32'bz;
    always @(posedge clk)if(cke)begin
        output_enable<=#2 read_valid[cas_latency-1];
        out_data<=#2 (cas_latency==2 ? pipe1 : pipe2);
        read_valid<={read_valid[1:0],1'b0};pipe1<=pipe0;pipe2<=pipe1;
        if(!cs_n)begin
            if(command==3'b101)begin writing=0;reading=1;bank=ba;col=addr[7:0];left=burst_length;end
            if(command==3'b100)begin writing=1;reading=0;bank=ba;col=addr[7:0];left=burst_length;end
            if(command==3'b010)begin writing=0;reading=0;end
            if(command==3'b000)begin cas_latency=addr[6:4];burst_length=1<<addr[2:0];end
            if(command==3'b011)rows[ba]=addr;
            if(command==3'b110)begin writing=0;reading=0;end
        end
        a={rows[bank],bank,col};
        if(writing)begin
            if(!dm0)memory[a][7:0]=dq[7:0];
            if(!dm1)memory[a][15:8]=dq[15:8];
            if(!dm2)memory[a][23:16]=dq[23:16];
            if(!dm3)memory[a][31:24]=dq[31:24];
        end
        if(reading)begin read_valid[0]<=1;pipe0<=memory[a];end
        if(writing||reading)begin
            col=col+1'b1;left=left-1;
            if(left==0)begin writing=0;reading=0;end
        end
    end
endmodule
