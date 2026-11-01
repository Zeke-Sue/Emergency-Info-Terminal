`timescale 1ns/1ps

module waterfall_buffer(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire spectrum_valid,
    input wire [5:0] spectrum_bin,
    input wire [15:0] spectrum_magnitude,
    input wire [6:0] query_age,
    input wire [5:0] query_bin,
    output reg [7:0] query_value,
    output reg [6:0] newest_column
);
    reg active_bank,flush_bank,flushing,initializing;
    reg [5:0] init_index;
    reg [5:0] flush_index,flush_index_d;
    reg flush_valid;
    reg [7:0] valid_columns;
    reg query_bank_q;
    reg spectrum_valid_d,spectrum_bank_d;
    reg [5:0] spectrum_bin_d;
    reg [7:0] spectrum_magnitude_d;
    reg max0_forward_valid,max1_forward_valid;
    reg [5:0] max0_forward_addr,max1_forward_addr;
    reg [7:0] max0_forward_data,max1_forward_data;

    wire [7:0] scaled_magnitude=|spectrum_magnitude[15:12] ?
        8'hff : spectrum_magnitude[11:4];
    wire [5:0] max0_ra=(flushing && !flush_bank) ?
        flush_index : spectrum_bin;
    wire [5:0] max1_ra=(flushing && flush_bank) ?
        flush_index : spectrum_bin;
    wire [7:0] max0_q,max1_q;
    wire [7:0] spectrum_old=spectrum_bank_d ? max1_q : max0_q;
    wire [7:0] spectrum_forwarded=spectrum_bank_d ?
        (max1_forward_valid && max1_forward_addr==spectrum_bin_d ?
            max1_forward_data : spectrum_old) :
        (max0_forward_valid && max0_forward_addr==spectrum_bin_d ?
            max0_forward_data : spectrum_old);
    wire accumulation_write=spectrum_valid_d &&
        spectrum_magnitude_d>spectrum_forwarded;
    wire clear0=flushing && flush_valid && !flush_bank;
    wire clear1=flushing && flush_valid && flush_bank;
    wire max0_we=initializing || clear0 ||
        (accumulation_write && !spectrum_bank_d);
    wire max1_we=initializing || clear1 ||
        (accumulation_write && spectrum_bank_d);
    wire [5:0] max0_wa=initializing ? init_index :
        (clear0 ? flush_index_d : spectrum_bin_d);
    wire [5:0] max1_wa=initializing ? init_index :
        (clear1 ? flush_index_d : spectrum_bin_d);
    wire [7:0] max0_wd=(initializing || clear0) ? 8'd0 : spectrum_magnitude_d;
    wire [7:0] max1_wd=(initializing || clear1) ? 8'd0 : spectrum_magnitude_d;
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(6)) maxima_bank0(
        .clk(clk),.we(max0_we),.wa(max0_wa),.ra(max0_ra),.d(max0_wd),.q(max0_q));
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(6)) maxima_bank1(
        .clk(clk),.we(max1_we),.wa(max1_wa),.ra(max1_ra),.d(max1_wd),.q(max1_q));

    wire [7:0] flush_data=flush_bank ? max1_q : max0_q;
    wire [11:0] write_address={newest_column[5:0],flush_index_d};
    wire write_valid=flushing && flush_valid;
    wire [6:0] query_column=newest_column-query_age;
    wire [11:0] query_address={query_column[5:0],query_bin};
    wire [7:0] q0,q1;
    buffer_ram_32k bank0(
        .clk(clk),.we(write_valid && !newest_column[6]),.wa(write_address),
        .ra(query_address),.d(flush_data),.q(q0));
    buffer_ram_32k bank1(
        .clk(clk),.we(write_valid && newest_column[6]),.wa(write_address),
        .ra(query_address),.d(flush_data),.q(q1));
    wire [7:0] selected_query=query_bank_q ? q1 : q0;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            active_bank<=0;flush_bank<=0;flushing<=0;initializing<=1;
            init_index<=0;flush_index<=0;
            flush_index_d<=0;flush_valid<=0;newest_column<=0;
            query_value<=0;valid_columns<=0;query_bank_q<=0;
            spectrum_valid_d<=0;spectrum_bank_d<=0;spectrum_bin_d<=0;
            spectrum_magnitude_d<=0;max0_forward_valid<=0;max1_forward_valid<=0;
            max0_forward_addr<=0;max1_forward_addr<=0;
            max0_forward_data<=0;max1_forward_data<=0;
        end else begin
            query_bank_q<=query_column[6];
            query_value<=query_age<valid_columns ? selected_query : 8'd0;
            spectrum_valid_d<=spectrum_valid&&!initializing;
            spectrum_bank_d<=active_bank;
            spectrum_bin_d<=spectrum_bin;
            spectrum_magnitude_d<=scaled_magnitude;
            if(accumulation_write) begin
                if(spectrum_bank_d) begin
                    max1_forward_valid<=1;max1_forward_addr<=spectrum_bin_d;
                    max1_forward_data<=spectrum_magnitude_d;
                end else begin
                    max0_forward_valid<=1;max0_forward_addr<=spectrum_bin_d;
                    max0_forward_data<=spectrum_magnitude_d;
                end
            end
            if(initializing) begin
                max0_forward_valid<=0;max1_forward_valid<=0;
                if(init_index==63) initializing<=0;
                else init_index<=init_index+1'b1;
            end else if(frame_tick) begin
                flush_bank<=active_bank;active_bank<=!active_bank;
                flushing<=1;flush_index<=0;flush_valid<=0;
                newest_column<=newest_column+1'b1;
                max0_forward_valid<=0;max1_forward_valid<=0;
                if(valid_columns<128) valid_columns<=valid_columns+1'b1;
            end else if(flushing) begin
                flush_index_d<=flush_index;flush_valid<=1;
                if(flush_index!=63) flush_index<=flush_index+1'b1;
                if(flush_valid && flush_index_d==63) begin
                    flushing<=0;flush_valid<=0;
                end
            end
        end
    end
endmodule
