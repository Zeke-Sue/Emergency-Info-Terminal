`timescale 1ns/1ps

module remote_spectrum_receiver #(
    parameter integer TIMEOUT_FRAMES=179
)(
    input wire clk,rst,frame_tick,message_valid,
    input wire [7:0] message_type,
    input wire [95:0] payload,
    input wire [6:0] query_age,
    input wire [5:0] query_bin,
    output wire [7:0] query_value,
    output reg [23:0] peak_frequency_q8,
    output reg [3:0] file_index,
    output reg [31:0] sample_position,
    output reg valid,
    output reg [15:0] dropped_columns
);
    reg [7:0] sequence_id;
    reg [3:0] expected_chunk,pending_file;
    reg [2:0] byte_index;
    reg [5:0] chunk_base;
    reg [63:0] bytes;
    reg writing,complete,flushing,flush_valid;
    reg [5:0] flush_index,flush_index_q;
    reg [6:0] newest;
    reg [7:0] column_count;
    reg [23:0] pending_peak;
    reg [31:0] pending_position;
    reg query_bank_q,query_valid_q;
    reg [$clog2(TIMEOUT_FRAMES+1)-1:0] idle_frames;
    wire [6:0] destination=newest+1'b1;
    wire [6:0] query_column=newest-query_age;
    wire [7:0] staging_q,q0,q1;
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(6)) staging(
        .clk(clk),.we(writing),.wa(chunk_base+{3'd0,byte_index}),
        .ra(flush_index),.d(bytes[63:56]),.q(staging_q));
    buffer_ram_32k ring0(.clk(clk),.we(flushing&&flush_valid&&!destination[6]),
        .wa({destination[5:0],flush_index_q}),.ra({query_column[5:0],query_bin}),
        .d(staging_q),.q(q0));
    buffer_ram_32k ring1(.clk(clk),.we(flushing&&flush_valid&&destination[6]),
        .wa({destination[5:0],flush_index_q}),.ra({query_column[5:0],query_bin}),
        .d(staging_q),.q(q1));
    assign query_value=query_valid_q ? (query_bank_q ? q1 : q0) : 8'd0;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            sequence_id<=0;expected_chunk<=0;pending_file<=0;byte_index<=0;chunk_base<=0;
            bytes<=0;writing<=0;complete<=0;flushing<=0;flush_valid<=0;
            flush_index<=0;flush_index_q<=0;newest<=127;column_count<=0;
            pending_peak<=0;pending_position<=0;peak_frequency_q8<=0;
            file_index<=0;sample_position<=0;valid<=0;dropped_columns<=0;
            query_bank_q<=0;query_valid_q<=0;
            idle_frames<=0;
        end else begin
            query_bank_q<=query_column[6];query_valid_q<=valid&&query_age<column_count;
            if(frame_tick && idle_frames<TIMEOUT_FRAMES)begin
                idle_frames<=idle_frames+1'b1;
                if(idle_frames==TIMEOUT_FRAMES-1)begin
                    valid<=0;column_count<=0;expected_chunk<=0;
                    complete<=0;writing<=0;
                end
            end
            if(writing)begin
                bytes<={bytes[55:0],8'd0};byte_index<=byte_index+1'b1;
                if(byte_index==7)writing<=0;
            end
            if(message_valid && message_type==8'h21 && !complete && !flushing && !writing)begin
                if(payload[87:80]==0 || (expected_chunk!=0 &&
                    payload[95:88]==sequence_id && payload[75:72]==pending_file &&
                    payload[87:80]=={4'd0,expected_chunk}))begin
                    if(payload[87:80]==0)begin
                        if(expected_chunk!=0)dropped_columns<=dropped_columns+1'b1;
                        sequence_id<=payload[95:88];pending_file<=payload[75:72];
                    end
                    if(payload[87:80]<8)begin
                        idle_frames<=0;
                        bytes<=payload[63:0];chunk_base<={payload[82:80],3'b0};
                        byte_index<=0;writing<=1;expected_chunk<=payload[83:80]+1'b1;
                    end
                end else begin expected_chunk<=0;dropped_columns<=dropped_columns+1'b1;end
            end
            if(message_valid && message_type==8'h22 && expected_chunk==8 &&
                !writing&&!complete&&!flushing && payload[95:88]==sequence_id &&
                payload[83:80]==pending_file)begin
                pending_peak<=payload[79:56];pending_position<=payload[55:24];complete<=1;
            end
            if(frame_tick&&complete&&!flushing)begin
                flushing<=1;flush_valid<=0;flush_index<=0;
            end else if(flushing)begin
                flush_valid<=1;flush_index_q<=flush_index;
                if(flush_index!=63)flush_index<=flush_index+1'b1;
                if(flush_valid&&flush_index_q==63)begin
                    flushing<=0;flush_valid<=0;complete<=0;expected_chunk<=0;
                    newest<=destination;

                    if(!valid || pending_file!=file_index || pending_position<=sample_position)
                        column_count<=1;
                    else if(column_count<128)column_count<=column_count+1'b1;
                    peak_frequency_q8<=pending_peak;sample_position<=pending_position;
                    file_index<=pending_file;valid<=1;idle_frames<=0;
                end
            end
        end
    end
endmodule
