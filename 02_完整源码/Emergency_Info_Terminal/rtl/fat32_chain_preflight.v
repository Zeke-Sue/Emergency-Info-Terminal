`timescale 1ns/1ps

module fat32_chain_preflight #(
    parameter integer IO_TIMEOUT=25000000,
    parameter integer MAX_CLUSTERS=1048576,
    parameter integer MAX_RETRIES=3
)(
    input wire clk,rst,start,
    input wire [31:0] first_cluster,file_size,fat_lba,fat_sectors,data_lba,
    input wire [2:0] cluster_shift,
    output reg sector_req,output reg [31:0] sector_lba,
    input wire [7:0] sector_data,input wire sector_valid,sector_end,
    output reg busy,done,valid,
    output reg [3:0] error_code
);
    localparam IDLE=0,ISSUE=1,RECEIVE=2,CHECK=3,RETRY_GAP=4,CACHE_PRIME=5,CACHE_READ=6;
    reg [2:0] state;
    reg [31:0] current,remaining,anchor,power,distance,watchdog;
    reg [31:0] fat_base,fat_length,data_base;
    reg [2:0] shift;
    reg [31:0] entry;
    reg [9:0] count;
    reg [2:0] retries;
    reg cache_valid;
    reg [31:0] cache_lba;
    reg [23:0] word_bytes;
    wire [31:0] cache_q;
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(7)) fat_cache(
        .clk(clk),.we(state==RECEIVE&&sector_valid&&count<512&&count[1:0]==3),
        .wa(count[8:2]),.ra(current[6:0]),.d({sector_data,word_bytes}),.q(cache_q));
    wire [8:0] entry_offset={current[6:0],2'b00};
    wire [31:0] next_cluster={4'd0,entry[27:0]};
    wire [31:0] cluster_count=((file_size-1'b1)>>(9+cluster_shift))+1'b1;
    wire [32:0] fat_address={1'b0,fat_base}+{8'd0,current[31:7]};
    wire [39:0] data_end={8'd0,data_base}+(({8'd0,current}-1'b1)<<shift)-1'b1;
    wire current_ok=current>=2&&current<32'h0ffffff0&&
        (current>>7)<fat_length&&!fat_address[32]&&data_end[39:32]==0;
    task finish;
        input [3:0] reason;
        begin busy<=0;done<=1;valid<=reason==0;error_code<=reason;sector_req<=0;state<=IDLE;end
    endtask
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;sector_req<=0;sector_lba<=0;busy<=0;done<=0;valid<=0;error_code<=0;
            current<=0;remaining<=0;anchor<=0;power<=1;distance<=0;watchdog<=0;
            fat_base<=0;fat_length<=0;data_base<=0;shift<=0;entry<=0;count<=0;retries<=0;
            cache_valid<=0;cache_lba<=0;word_bytes<=0;
        end else begin
            done<=0;
            case(state)
                IDLE:if(start)begin
                    valid<=0;error_code<=0;busy<=1;current<=first_cluster;
                    remaining<=cluster_count;anchor<=first_cluster;power<=1;distance<=0;
                    fat_base<=fat_lba;fat_length<=fat_sectors;data_base<=data_lba;
                    shift<=cluster_shift;retries<=0;cache_valid<=0;
                    if(file_size==0||cluster_count>MAX_CLUSTERS)finish(9);
                    else state<=ISSUE;
                end
                ISSUE:begin
                    if(!current_ok)finish(6);
                    else if(cache_valid&&cache_lba==fat_address[31:0])state<=CACHE_PRIME;
                    else begin
                        sector_lba<=fat_address[31:0];sector_req<=1;count<=0;
                        entry<=0;watchdog<=0;state<=RECEIVE;
                    end
                end
                RECEIVE:begin
                    watchdog<=watchdog+1'b1;
                    if(sector_valid)begin
                        word_bytes<={sector_data,word_bytes[23:8]};
                        if(count<513)count<=count+1'b1;
                        if(count==entry_offset)entry[7:0]<=sector_data;
                        if(count=={1'b0,entry_offset}+1)entry[15:8]<=sector_data;
                        if(count=={1'b0,entry_offset}+2)entry[23:16]<=sector_data;
                        if(count=={1'b0,entry_offset}+3)entry[31:24]<=sector_data;
                    end
                    if(sector_end)begin
                        sector_req<=0;
                        if(count+(sector_valid ? 10'd1 : 10'd0)!=512)begin
                            cache_valid<=0;
                            if(retries==MAX_RETRIES)finish(5);
                            else begin retries<=retries+1'b1;state<=RETRY_GAP;end
                        end else begin retries<=0;state<=CHECK;cache_valid<=1;cache_lba<=sector_lba;end
                    end else if(watchdog==IO_TIMEOUT-1)finish(4);
                end
                RETRY_GAP:state<=ISSUE;
                CACHE_PRIME:state<=CACHE_READ;
                CACHE_READ:begin entry<=cache_q;state<=CHECK;end
                CHECK:begin
                    if(remaining==1)begin
                        if(next_cluster>=32'h0ffffff8)finish(0);
                        else finish(6);
                    end else if(next_cluster<2||next_cluster>=32'h0ffffff0)finish(6);
                    else if(next_cluster==anchor)finish(7);
                    else begin
                        current<=next_cluster;remaining<=remaining-1'b1;state<=ISSUE;
                        if(distance+1'b1==power)begin
                            anchor<=next_cluster;power<=power<<1;distance<=0;
                        end else distance<=distance+1'b1;
                    end
                end
                default:finish(15);
            endcase
        end
    end
endmodule
